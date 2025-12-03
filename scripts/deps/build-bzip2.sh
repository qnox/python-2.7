#!/usr/bin/env bash
# Build bzip2 for musl
set -e

INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
BUILD_DIR="${BUILD_DIR:-/tmp/musl-deps-build}"

echo "Building bzip2..."
cd "${BUILD_DIR}"

if [ -f "${INSTALL_PREFIX}/lib/libbz2.a" ]; then
    echo "bzip2 already installed"
    exit 0
fi

curl -LO https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz
tar xzf bzip2-1.0.8.tar.gz
cd bzip2-1.0.8

make -j$(nproc) CC=musl-clang AR=ar RANLIB=ranlib
sudo make install PREFIX="${INSTALL_PREFIX}"

cd ..
rm -rf bzip2-1.0.8 bzip2-1.0.8.tar.gz

echo "bzip2 built successfully"
