#!/bin/bash
set -e

pg_version="${PG_VERSION:-18.0}"

echo "--- Building PostgreSQL $pg_version ---"

cd "$PGDEV_SRC_DIR/postgresql-$pg_version/build"

# Build and install PostgreSQL and its bundled extensions
ninja
ninja install
