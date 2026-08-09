#!/usr/bin/env python3
"""Load PostgreSQL-native AdventureWorks and Microsoft's WWI DW Parquet data."""

from __future__ import annotations

import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict
from io import BytesIO
from urllib.parse import urlparse

import pyarrow as pa
import pyarrow.parquet as pq
import psycopg
import requests
from psycopg import sql

TARGET_DSN = os.environ["TARGET_DSN"]
ADVENTUREWORKS_DSN = os.environ["ADVENTUREWORKS_DSN"]
AZURE_CONTAINER = "https://azuresynapsestorage.blob.core.windows.net/sampledata"
WWI_PREFIX = "WideWorldImportersDW/tables/"


def is_loaded(dataset: str) -> bool:
    with psycopg.connect(TARGET_DSN) as conn, conn.cursor() as cur:
        cur.execute("SELECT EXISTS (SELECT 1 FROM kingo_meta.sample_loads WHERE dataset = %s)", (dataset,))
        return bool(cur.fetchone()[0])


def mark_loaded(dataset: str, details: dict[str, object]) -> None:
    with psycopg.connect(TARGET_DSN) as conn, conn.cursor() as cur:
        cur.execute(
            "INSERT INTO kingo_meta.sample_loads(dataset, details) VALUES (%s, %s) "
            "ON CONFLICT (dataset) DO UPDATE SET loaded_at = now(), details = EXCLUDED.details",
            (dataset, psycopg.types.json.Jsonb(details)),
        )


def grant_warehouse_read_access() -> None:
    roles = sql.SQL(", ").join(map(sql.Identifier, ["metabase", "cloudbeaver", "jupyter", "langflow", "langgraph", "n8n", "student"]))
    with psycopg.connect(TARGET_DSN) as conn, conn.cursor() as cur:
        cur.execute(
            "SELECT schema_name FROM information_schema.schemata "
            "WHERE schema_name NOT IN ('pg_catalog', 'information_schema', 'kingo_meta') "
            "AND schema_name NOT LIKE 'pg_toast%' AND schema_name NOT LIKE 'pg_temp%'"
        )
        for (schema_name,) in cur.fetchall():
            schema = sql.Identifier(schema_name)
            cur.execute(sql.SQL("GRANT USAGE ON SCHEMA {} TO {}").format(schema, roles))
            cur.execute(sql.SQL("GRANT SELECT ON ALL TABLES IN SCHEMA {} TO {}").format(schema, roles))
            cur.execute(sql.SQL("GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA {} TO {}").format(schema, roles))


def load_adventureworks() -> None:
    if is_loaded("adventureworks"):
        print("AdventureWorks is already loaded; skipping.", flush=True)
        return

    print("Loading AdventureWorks into the warehouse database...", flush=True)
    source = urlparse(ADVENTUREWORKS_DSN)
    target = urlparse(TARGET_DSN)
    dump_env = os.environ | {"PGPASSWORD": source.password or ""}
    restore_env = os.environ | {"PGPASSWORD": target.password or ""}
    dump = subprocess.Popen(
        [
            "pg_dump", "--host", source.hostname or "adventureworks-source",
            "--port", str(source.port or 5432), "--username", source.username or "postgres",
            "--dbname", (source.path or "/postgres").lstrip("/"),
            "--no-owner", "--no-privileges", "--clean", "--if-exists",
            # Dump only the AdventureWorks domains. The source image's public
            # schema contains PostGIS implementation objects; the target has
            # its own PostgreSQL-17 PostGIS extension and must not receive a
            # second copy of those functions.
            "--schema", '"HumanResources"', "--schema", '"Person"',
            "--schema", '"Production"', "--schema", '"Purchasing"', "--schema", '"Sales"',
        ],
        stdout=subprocess.PIPE,
        env=dump_env,
    )
    assert dump.stdout is not None
    restore = subprocess.run(
        [
            "psql", "--host", target.hostname or "postgres", "--port", str(target.port or 5432),
            "--username", target.username or "postgres", "--dbname", (target.path or "/warehouse").lstrip("/"),
            "--set", "ON_ERROR_STOP=1",
        ],
        stdin=dump.stdout,
        stdout=subprocess.DEVNULL,
        env=restore_env,
        check=False,
    )
    dump.stdout.close()
    dump_code = dump.wait()
    if dump_code or restore.returncode:
        raise RuntimeError(f"AdventureWorks transfer failed (dump={dump_code}, restore={restore.returncode})")
    grant_warehouse_read_access()
    mark_loaded("adventureworks", {"source": "chriseaton/adventureworks:postgres-16"})


def list_wwi_blobs() -> dict[str, list[str]]:
    tables: dict[str, list[str]] = defaultdict(list)
    marker = ""
    while True:
        response = requests.get(
            AZURE_CONTAINER,
            params={"restype": "container", "comp": "list", "prefix": WWI_PREFIX, "marker": marker},
            timeout=60,
        )
        response.raise_for_status()
        root = ET.fromstring(response.content)
        for node in root.findall("./Blobs/Blob/Name"):
            if node.text and node.text.endswith(".parquet"):
                relative = node.text[len(WWI_PREFIX):]
                table = relative.split("/", 1)[0]
                tables[table].append(f"{AZURE_CONTAINER}/{node.text}")
        marker = root.findtext("NextMarker") or ""
        if not marker:
            return dict(tables)


def clean_name(value: str) -> str:
    value = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", "_", value)
    value = re.sub(r"[^a-zA-Z0-9]+", "_", value).strip("_").lower()
    return value or "unnamed"


def pg_type(dtype: pa.DataType) -> str:
    if pa.types.is_int8(dtype) or pa.types.is_int16(dtype):
        return "smallint"
    if pa.types.is_int32(dtype) or pa.types.is_uint8(dtype) or pa.types.is_uint16(dtype):
        return "integer"
    if pa.types.is_integer(dtype):
        return "bigint"
    if pa.types.is_floating(dtype):
        return "double precision"
    if pa.types.is_decimal(dtype):
        return f"numeric({dtype.precision},{dtype.scale})"
    if pa.types.is_boolean(dtype):
        return "boolean"
    if pa.types.is_date(dtype):
        return "date"
    if pa.types.is_timestamp(dtype):
        return "timestamptz" if dtype.tz else "timestamp"
    if pa.types.is_time(dtype):
        return "time"
    if pa.types.is_binary(dtype) or pa.types.is_large_binary(dtype):
        return "bytea"
    return "text"


def load_arrow_table(conn: psycopg.Connection, table_name: str, arrow_table: pa.Table, create: bool) -> int:
    columns = [clean_name(name) for name in arrow_table.column_names]
    with conn.cursor() as cur:
        if create:
            definitions = sql.SQL(", ").join(
                sql.SQL("{} {}").format(sql.Identifier(name), sql.SQL(pg_type(field.type)))
                for name, field in zip(columns, arrow_table.schema)
            )
            cur.execute(sql.SQL("DROP TABLE IF EXISTS wwi.{} CASCADE").format(sql.Identifier(table_name)))
            cur.execute(sql.SQL("CREATE TABLE wwi.{} ({})").format(sql.Identifier(table_name), definitions))
        copy_stmt = sql.SQL("COPY wwi.{} ({}) FROM STDIN").format(
            sql.Identifier(table_name), sql.SQL(", ").join(map(sql.Identifier, columns))
        )
        with cur.copy(copy_stmt) as copy:
            for batch in arrow_table.to_batches(max_chunksize=5000):
                for row in batch.to_pylist():
                    copy.write_row([row[original] for original in arrow_table.column_names])
    return arrow_table.num_rows


def load_wwi() -> None:
    if is_loaded("wide_world_importers_dw"):
        print("WideWorldImportersDW is already loaded; skipping.", flush=True)
        return

    print("Discovering Microsoft's WideWorldImportersDW Parquet files...", flush=True)
    tables = list_wwi_blobs()
    if not tables:
        raise RuntimeError("No WWI Parquet files were found in Microsoft's sample-data container")

    counts: dict[str, int] = {}
    with psycopg.connect(TARGET_DSN) as conn:
        for raw_name, urls in sorted(tables.items()):
            table_name = clean_name(raw_name)
            total = 0
            print(f"  {table_name}: {len(urls)} file(s)", flush=True)
            for index, url in enumerate(sorted(urls)):
                response = requests.get(url, timeout=180)
                response.raise_for_status()
                arrow_table = pq.read_table(BytesIO(response.content))
                total += load_arrow_table(conn, table_name, arrow_table, create=index == 0)
            counts[table_name] = total
        with conn.cursor() as cur:
            cur.execute("GRANT USAGE ON SCHEMA wwi TO metabase, cloudbeaver, jupyter, langflow, langgraph, n8n, student")
            cur.execute("GRANT SELECT ON ALL TABLES IN SCHEMA wwi TO metabase, cloudbeaver, jupyter, langflow, langgraph, n8n, student")
    mark_loaded("wide_world_importers_dw", {"source": AZURE_CONTAINER, "rows": counts})


def main() -> int:
    try:
        load_adventureworks()
        load_wwi()
    except Exception as exc:
        print(f"Sample loading failed: {exc}", file=sys.stderr, flush=True)
        return 1
    print("All sample databases are ready.", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
