#!/usr/bin/env bash
# Build xz (lzma) for musl
set -e

INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
BUILD_DIR="${BUILD_DIR:-/tmp/musl-deps-build}"

echo "Building xz..."
cd "${BUILD_DIR}"

if [ -f "${INSTALL_PREFIX}/lib/liblzma.a" ]; then
    echo "xz already installed"
    exit 0
fi

curl -LO https://github.com/tukaani-project/xz/releases/download/v5.6.3/xz-5.6.3.tar.gz
tar xzf xz-5.6.3.tar.gz
cd xz-5.6.3

CC=musl-clang CFLAGS="-fPIC" ./configure \
    --prefix="${INSTALL_PREFIX}" \
    --enable-static \
    --disable-shared

make -j$(nproc)
sudo make install

cd ..
rm -rf xz-5.6.3 xz-5.6.3.tar.gz

echo "xz built successfully"
