#!/usr/bin/env bash
# Build dependencies for musl Python builds following python-build-standalone approach
# All dependencies are built statically with musl-clang
# This orchestrator script calls individual dependency build scripts

set -euo pipefail

# Environment setup
export BUILD_DIR="/tmp/musl-deps-build"
export INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"

mkdir -p "${BUILD_DIR}"

echo "=== Building musl dependencies for Python ==="

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPS_DIR="${SCRIPT_DIR}/deps"

# Copy stdatomic.h from clang (needed by OpenSSL and others)
if [ ! -f "${INSTALL_PREFIX}/include/stdatomic.h" ]; then
    CLANG_ATOMICS=$(find /usr/lib/clang /usr/lib/llvm* -name "stdatomic.h" 2>/dev/null | head -1)
    if [ -n "$CLANG_ATOMICS" ]; then
        echo "Copying stdatomic.h from clang..."
        sudo cp "$CLANG_ATOMICS" "${INSTALL_PREFIX}/include/"
    fi
fi

# Build dependencies in order (some have dependencies on others)
echo ""
echo "Building zlib..."
bash "${DEPS_DIR}/build-zlib.sh"

echo ""
echo "Building bzip2..."
bash "${DEPS_DIR}/build-bzip2.sh"

echo ""
echo "Building xz..."
bash "${DEPS_DIR}/build-xz.sh"

echo ""
echo "Building sqlite3..."
bash "${DEPS_DIR}/build-sqlite3.sh"

echo ""
echo "Building libffi..."
bash "${DEPS_DIR}/build-libffi.sh"

echo ""
echo "Building ncurses (required by readline)..."
bash "${DEPS_DIR}/build-ncurses.sh"

echo ""
echo "Building readline (requires ncurses)..."
bash "${DEPS_DIR}/build-readline.sh"

echo ""
echo "Building OpenSSL..."
bash "${DEPS_DIR}/build-openssl.sh"

echo ""
echo "Building gdbm..."
bash "${DEPS_DIR}/build-gdbm.sh"

echo ""
echo "=== All musl dependencies built successfully ==="
