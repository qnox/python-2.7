#!/usr/bin/env bash
# Build readline for musl
# Requires: ncurses
set -euo pipefail

INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
BUILD_DIR="${BUILD_DIR:-/tmp/musl-deps-build}"

echo "Building readline..."
cd "${BUILD_DIR}"


curl -LO https://ftp.gnu.org/gnu/readline/readline-8.2.tar.gz
tar xzf readline-8.2.tar.gz
cd readline-8.2

CC=musl-clang CFLAGS="-fPIC" ./configure \
    --prefix="${INSTALL_PREFIX}" \
    --enable-static \
    --disable-shared

make -j$(nproc)
sudo make install

cd ..
rm -rf readline-8.2 readline-8.2.tar.gz

echo "readline built successfully"
