#!/bin/bash
set -e

echo "--- Building MobilityDB v1.3.0-alpha ---"

cd "$PGDEV_SRC_DIR/MobilityDB-1.3.0-alpha/build"

make -j$(nproc)
make install

# Register the runtime requirement that postgis must be preloaded
# for MobilityDB to work correctly.
echo "requires_preload=postgis-3" >> "$PGDEV_INSTANCE_DIR/pgdev.manifest"
