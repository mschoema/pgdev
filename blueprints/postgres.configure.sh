#!/bin/bash
set -e

echo "--- Configuring PostgreSQL 18.0 ---"

PG_VERSION="18.0"
PG_URL="https://ftp.postgresql.org/pub/source/v$PG_VERSION/postgresql-$PG_VERSION.tar.gz"

cd "$PGDEV_SRC_DIR"

# Download source and checksum
wget "$PG_URL"
wget "$PG_URL.md5"

# Verify checksum and untar
echo "Verifying checksum..."
md5sum -c "postgresql-$PG_VERSION.tar.gz.md5"
tar -xzf "postgresql-$PG_VERSION.tar.gz"

cd "postgresql-$PG_VERSION"

# Set flags for a release build. -g is included for useful backtraces.
export CFLAGS="-O2 -g -pipe -march=native"

./configure --prefix="$PGDEV_INSTALL_DIR" --enable-debug

# Unset flags to avoid affecting subsequent components
unset CFLAGS
