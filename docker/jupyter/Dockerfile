ARG JUPYTER_BASE_IMAGE=quay.io/jupyter/minimal-notebook:python-3.12
FROM ${JUPYTER_BASE_IMAGE}

RUN pip install --no-cache-dir \
      "pandas>=2.2,<3" \
      "polars>=1.0,<2" \
      "sqlalchemy>=2.0,<3" \
      "psycopg[binary]>=3.2,<4" \
      "pgvector>=0.3,<1" \
      "matplotlib>=3.9,<4" \
      "seaborn>=0.13,<1" \
      "scikit-learn>=1.5,<2" \
      "duckdb>=1.2,<2"

