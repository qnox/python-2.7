#!/bin/bash
# Local test script for musl builds
# This tests the entire musl build pipeline locally in Docker

set -e

echo "=== Testing musl build pipeline locally ==="

PLATFORM=${1:-linux/arm64}
ARCH=${2:-aarch64}

echo "Testing on platform: $PLATFORM"
echo "Architecture: $ARCH"

# Test 1: Setup musl-clang
echo ""
echo "=== Test 1: Build and install musl-clang ==="
docker run --rm --platform $PLATFORM \
    -v $(pwd):/work -w /work \
    ubuntu:24.04 bash -c "
    export DEBIAN_FRONTEND=noninteractive &&
    apt-get update -qq &&
    apt-get install -y -qq build-essential curl clang sudo > /dev/null 2>&1 &&
    bash scripts/setup-musl.sh &&
    echo 'Verifying musl-clang installation...' &&
    which musl-clang &&
    musl-clang --version
"

echo "✓ Test 1 passed: musl-clang installed"

# Test 2: Build dependencies
echo ""
echo "=== Test 2: Build all musl dependencies ==="
docker run --rm --platform $PLATFORM \
    -v $(pwd):/work -w /work \
    ubuntu:24.04 bash -c "
    export DEBIAN_FRONTEND=noninteractive &&
    apt-get update -qq &&
    apt-get install -y -qq build-essential curl clang sudo > /dev/null 2>&1 &&
    bash scripts/setup-musl.sh > /dev/null 2>&1 &&
    echo 'Building dependencies...' &&
    bash scripts/build-musl-deps.sh 2>&1 | tee /tmp/deps-build.log &&
    echo '' &&
    echo 'Verifying libraries were built:' &&
    ls -lh /usr/local/lib/libz.a &&
    ls -lh /usr/local/lib/libbz2.a &&
    ls -lh /usr/local/lib/libsqlite3.a &&
    ls -lh /usr/local/lib/libssl.a &&
    ls -lh /usr/local/lib/libffi.a &&
    ls -lh /usr/local/lib/libncursesw.a &&
    ls -lh /usr/local/lib/libreadline.a &&
    ls -lh /usr/local/lib/libgdbm.a
"

echo "✓ Test 2 passed: All dependencies built"

# Test 3: Build Python
echo ""
echo "=== Test 3: Build Python 2.7 with musl ==="
docker run --rm --platform $PLATFORM \
    -v $(pwd):/work -w /work \
    -e TARGET_ARCH=$ARCH \
    -e TARGET_LIBC=musl \
    -e TARGET_TRIPLE=${ARCH}-unknown-linux-musl \
    ubuntu:24.04 bash -c "
    export DEBIAN_FRONTEND=noninteractive &&
    apt-get update -qq &&
    apt-get install -y -qq build-essential curl clang sudo > /dev/null 2>&1 &&
    bash scripts/setup-musl.sh > /dev/null 2>&1 &&
    bash scripts/build-musl-deps.sh > /dev/null 2>&1 &&
    echo 'Building Python...' &&
    rm -rf Python-2.7.18 build &&
    bash scripts/build-linux.sh 2>&1 | tee /tmp/python-build.log
"

echo "✓ Test 3 passed: Python built successfully"

# Test 4: Test the built Python on Alpine (true musl)
echo ""
echo "=== Test 4: Test Python binary on Alpine (pure musl) ==="
docker run --rm --platform $PLATFORM \
    -v $(pwd):/work -w /work \
    alpine:latest sh -c "
    apk add --no-cache bash > /dev/null 2>&1 &&
    PYTHON_BIN=\$(find /work/build -name 'python-2.7.18-*-musl' -type d | head -1) &&
    echo \"Testing Python at: \$PYTHON_BIN\" &&
    \$PYTHON_BIN/bin/python --version &&
    echo 'Testing core modules:' &&
    \$PYTHON_BIN/bin/python -c 'import sys; print(\"sys: OK\")' &&
    \$PYTHON_BIN/bin/python -c 'import os; print(\"os: OK\")' &&
    \$PYTHON_BIN/bin/python -c 'import struct; print(\"struct: OK\")' &&
    \$PYTHON_BIN/bin/python -c 'import socket; print(\"socket: OK\")' &&
    \$PYTHON_BIN/bin/python -c 'import zlib; print(\"zlib: OK\")' &&
    \$PYTHON_BIN/bin/python -c 'import bz2; print(\"bz2: OK\")' &&
    \$PYTHON_BIN/bin/python -c 'import sqlite3; print(\"sqlite3: OK\")' &&
    \$PYTHON_BIN/bin/python -c 'import ssl; print(\"ssl: OK\")' &&
    \$PYTHON_BIN/bin/python -c 'import readline; print(\"readline: OK\")' &&
    echo 'All critical modules working!'
"

echo "✓ Test 4 passed: Python works on Alpine"

echo ""
echo "========================================"
echo "=== ALL TESTS PASSED SUCCESSFULLY ==="
echo "========================================"
echo ""
echo "The musl build pipeline is working correctly!"
