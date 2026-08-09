ARG POSTGRES_BASE_IMAGE=pgvector/pgvector:pg17
FROM ${POSTGRES_BASE_IMAGE}

# AdventureWorks contains geography columns. pgvector provides the vector
# extension; PostGIS supplies the geography/geometry types used by the sample.
RUN apt-get update \
    && apt-get install -y --no-install-recommends postgresql-17-postgis-3 postgis \
    && rm -rf /var/lib/apt/lists/*

