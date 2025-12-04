#!/usr/bin/env bash
# Build zlib for musl
set -e

INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
BUILD_DIR="${BUILD_DIR:-/tmp/musl-deps-build}"

echo "Building zlib..."
cd "${BUILD_DIR}"

if [ -f "${INSTALL_PREFIX}/lib/libz.a" ]; then
    echo "zlib already installed"
    exit 0
fi

curl -L https://github.com/madler/zlib/releases/download/v1.3/zlib-1.3.tar.gz -o zlib-1.3.tar.gz
tar xzf zlib-1.3.tar.gz
cd zlib-1.3

CC=musl-clang CFLAGS="-fPIC" ./configure --prefix="${INSTALL_PREFIX}" --static

make -j$(nproc)
sudo make install

cd ..
rm -rf zlib-1.3 zlib-1.3.tar.gz

echo "zlib built successfully"
