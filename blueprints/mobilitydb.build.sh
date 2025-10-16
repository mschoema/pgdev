#!/bin/bash
set -e

echo "--- Building MobilityDB v1.3.0-alpha ---"

cd "$PGDEV_SRC_DIR/MobilityDB-1.3.0-alpha/build"

make -j$(nproc)
make install
