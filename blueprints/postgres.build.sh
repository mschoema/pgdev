#!/bin/bash
set -e

echo "--- Building PostgreSQL 18.0 ---"

cd "$PGDEV_SRC_DIR/postgresql-18.0"

# Build and install PostgreSQL and its bundled extensions
make -j$(nproc) world-bin
make install-world-bin
