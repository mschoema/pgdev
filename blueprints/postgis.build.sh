#!/bin/bash
set -e

echo "--- Building PostGIS 3.6.0 ---"

cd "$PGDEV_SRC_DIR/postgis-3.6.0"

make -j$(nproc)
make install
