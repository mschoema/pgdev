#!/bin/bash
set -e

echo "--- Configuring PostGIS 3.6.0 ---"

POSTGIS_VERSION="3.6.0"
POSTGIS_URL="https://download.osgeo.org/postgis/source/postgis-$POSTGIS_VERSION.tar.gz"
MD5_URL="https://postgis.net/stuff/postgis-$POSTGIS_VERSION.tar.gz.md5"

cd "$PGDEV_SRC_DIR"

# Download source and checksum
wget "$POSTGIS_URL"
wget -O "postgis-$POSTGIS_VERSION.tar.gz.md5" "$MD5_URL"

# Verify checksum and untar
echo "Verifying checksum..."
md5sum -c "postgis-$POSTGIS_VERSION.tar.gz.md5"
tar -xzf "postgis-$POSTGIS_VERSION.tar.gz"

cd "postgis-$POSTGIS_VERSION"

export CFLAGS="-O2 -g -pipe -march=native"

# Point to the pg_config of our newly built PostgreSQL instance
./configure --prefix="$PGDEV_INSTALL_DIR" --with-pgconfig="$PGDEV_INSTALL_DIR/bin/pg_config"
