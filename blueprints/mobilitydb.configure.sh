#!/bin/bash
set -e

echo "--- Configuring MobilityDB v1.3.0-alpha ---"

MOBILITYDB_VERSION="1.3.0-alpha"
MOBILITYDB_URL="https://github.com/MobilityDB/MobilityDB/archive/refs/tags/v$MOBILITYDB_VERSION.tar.gz"

cd "$PGDEV_SRC_DIR"

# Download source (GitHub does not provide MD5 checksums for tarballs)
wget -O "mobilitydb-$MOBILITYDB_VERSION.tar.gz" "$MOBILITYDB_URL"
tar -xzf "mobilitydb-$MOBILITYDB_VERSION.tar.gz"

# The uncompressed folder name includes the project name
cd "MobilityDB-$MOBILITYDB_VERSION"

# MobilityDB uses CMake, so we create a separate build directory
mkdir -p build && cd build

# Configure using CMake in Release mode
cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DPG_CONFIG_PATH="$PGDEV_INSTALL_DIR/bin/pg_config" \
  -DCMAKE_INSTALL_PREFIX="$PGDEV_INSTALL_DIR"

# Register the runtime requirement that postgis must be preloaded
# for MobilityDB to work correctly.
echo "[MobilityDB]" >> "$PGDEV_INSTANCE_DIR/pgdev.manifest"
echo "requires_preload=postgis-3" >> "$PGDEV_INSTANCE_DIR/pgdev.manifest"
