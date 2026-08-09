FROM postgres:17-bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 python3-venv ca-certificates \
    && python3 -m venv /opt/loader-venv \
    && /opt/loader-venv/bin/pip install --no-cache-dir "psycopg[binary]>=3.2,<4" "pyarrow>=19,<23" "requests>=2.32,<3" \
    && rm -rf /var/lib/apt/lists/*

COPY docker/sample-loader/load_samples.py /app/load_samples.py
ENTRYPOINT ["/opt/loader-venv/bin/python", "/app/load_samples.py"]

