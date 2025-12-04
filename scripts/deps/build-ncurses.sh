#!/usr/bin/env bash
# Build ncurses for musl
set -euo pipefail

INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
BUILD_DIR="${BUILD_DIR:-/tmp/musl-deps-build}"

echo "Building ncurses..."
cd "${BUILD_DIR}"


curl -LO https://invisible-mirror.net/archives/ncurses/ncurses-6.4.tar.gz
tar xzf ncurses-6.4.tar.gz
cd ncurses-6.4

CC=musl-clang CFLAGS="-fPIC" ./configure \
    --prefix="${INSTALL_PREFIX}" \
    --enable-static \
    --disable-shared \
    --enable-widec \
    --without-cxx \
    --without-cxx-binding \
    --without-ada \
    --without-manpages \
    --without-tests \
    --disable-stripping

# Build libraries only - skip progs which fails with libgcc quad-precision issues
make -j$(nproc) libs
sudo make install.libs

cd ..
rm -rf ncurses-6.4 ncurses-6.4.tar.gz

echo "ncurses built successfully"
