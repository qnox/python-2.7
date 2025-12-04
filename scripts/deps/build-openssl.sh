#!/usr/bin/env bash
# Build OpenSSL for musl
# Based on python-build-standalone approach
set -euo pipefail

INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
BUILD_DIR="${BUILD_DIR:-/tmp/musl-deps-build}"

echo "Building OpenSSL..."
cd "${BUILD_DIR}"


# Copy stdatomic.h from clang (needed by OpenSSL)
if [ ! -f "${INSTALL_PREFIX}/include/stdatomic.h" ]; then
    CLANG_ATOMICS=$(find /usr/lib/clang /usr/lib/llvm* -name "stdatomic.h" 2>/dev/null | head -1)
    if [ -n "$CLANG_ATOMICS" ]; then
        echo "Copying stdatomic.h from clang..."
        sudo cp "$CLANG_ATOMICS" "${INSTALL_PREFIX}/include/"
    fi
fi

curl -LO https://www.openssl.org/source/openssl-1.1.1w.tar.gz
tar xzf openssl-1.1.1w.tar.gz
cd openssl-1.1.1w

# Use python-build-standalone flags for musl compatibility:
# - no-async: Async operations need Linux-specific features
# - no-engine: Disables all engines (including AF_ALG which needs linux/version.h)
# - OPENSSL_NO_SECURE_MEMORY: Secure memory needs linux/mman.h
# - __STDC_NO_ATOMICS__: Disable atomics
CC=musl-clang ./config \
    --prefix="${INSTALL_PREFIX}" \
    no-shared \
    no-async \
    -DOPENSSL_NO_ASYNC \
    -D__STDC_NO_ATOMICS__=1 \
    no-engine \
    -DOPENSSL_NO_SECURE_MEMORY

# Only build libraries, not apps/tests which try to link libgcc
make -j$(nproc) build_libs
sudo make install_dev

cd ..
rm -rf openssl-1.1.1w openssl-1.1.1w.tar.gz

echo "OpenSSL built successfully"
