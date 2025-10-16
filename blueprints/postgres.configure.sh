#!/bin/bash
set -e

pg_version="${PG_VERSION:-18.0}"
pg_url="https://ftp.postgresql.org/pub/source/v$pg_version/postgresql-$pg_version.tar.gz"

echo "--- Configuring PostgreSQL $pg_version ---"

cd "$PGDEV_SRC_DIR"

# Download source and checksum
wget "$pg_url"
wget "$pg_url.md5"

# Verify checksum and untar
echo "Verifying checksum..."
md5sum -c "postgresql-$pg_version.tar.gz.md5"
tar -xzf "postgresql-$pg_version.tar.gz"

cd "postgresql-$pg_version"

# Link to llvm 20, because postgres doesn't compile with 21 yet
export LLVM_CONFIG='/opt/homebrew/opt/llvm@20/bin/llvm-config'

# Link to readline manually
export LDFLAGS="-L$(brew --prefix readline)/lib"
export CPPFLAGS="-I$(brew --prefix readline)/include"

# Set flags for a release build. -g is included for useful backtraces.
export CFLAGS="-O2 -g -pipe -march=native"

./configure --prefix="$PGDEV_INSTALL_DIR" --with-lz4 --with-llvm
