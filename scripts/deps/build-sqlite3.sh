#!/usr/bin/env bash
# Build sqlite3 for musl
set -euo pipefail

INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
BUILD_DIR="${BUILD_DIR:-/tmp/musl-deps-build}"

echo "Building sqlite3..."
cd "${BUILD_DIR}"


curl -LO https://www.sqlite.org/2024/sqlite-autoconf-3450100.tar.gz
tar xzf sqlite-autoconf-3450100.tar.gz
cd sqlite-autoconf-3450100

CC=musl-clang CFLAGS="-fPIC" ./configure \
    --prefix="${INSTALL_PREFIX}" \
    --enable-static \
    --disable-shared

make -j$(nproc)
sudo make install

cd ..
rm -rf sqlite-autoconf-3450100 sqlite-autoconf-3450100.tar.gz

echo "sqlite3 built successfully"
