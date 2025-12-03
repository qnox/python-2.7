#!/usr/bin/env bash
# Build libffi for musl
set -e

INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
BUILD_DIR="${BUILD_DIR:-/tmp/musl-deps-build}"

echo "Building libffi..."
cd "${BUILD_DIR}"

if [ -f "${INSTALL_PREFIX}/lib/libffi.a" ]; then
    echo "libffi already installed"
    exit 0
fi

curl -LO https://github.com/libffi/libffi/releases/download/v3.4.4/libffi-3.4.4.tar.gz
tar xzf libffi-3.4.4.tar.gz
cd libffi-3.4.4

CC=musl-clang CFLAGS="-fPIC" ./configure \
    --prefix="${INSTALL_PREFIX}" \
    --enable-static \
    --disable-shared

make -j$(nproc)
sudo make install

cd ..
rm -rf libffi-3.4.4 libffi-3.4.4.tar.gz

echo "libffi built successfully"
