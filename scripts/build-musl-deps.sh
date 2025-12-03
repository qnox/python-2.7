#!/usr/bin/env bash
# Build dependencies for musl Python builds following python-build-standalone approach
# All dependencies are built statically with musl-clang
# This orchestrator script calls individual dependency build scripts

set -e

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

# Verify all libraries were created
echo ""
echo "=== Verifying all dependencies were built ==="
MISSING_LIBS=0

check_lib() {
    if [ -f "$1" ]; then
        echo "✓ $1"
    else
        echo "✗ MISSING: $1"
        MISSING_LIBS=1
    fi
}

check_lib "${INSTALL_PREFIX}/lib/libz.a"
check_lib "${INSTALL_PREFIX}/lib/libbz2.a"
check_lib "${INSTALL_PREFIX}/lib/liblzma.a"
check_lib "${INSTALL_PREFIX}/lib/libsqlite3.a"
check_lib "${INSTALL_PREFIX}/lib/libffi.a"
check_lib "${INSTALL_PREFIX}/lib/libncursesw.a"
check_lib "${INSTALL_PREFIX}/lib/libreadline.a"
check_lib "${INSTALL_PREFIX}/lib/libssl.a"
check_lib "${INSTALL_PREFIX}/lib/libcrypto.a"
check_lib "${INSTALL_PREFIX}/lib/libgdbm.a"

if [ $MISSING_LIBS -eq 1 ]; then
    echo ""
    echo "ERROR: Some libraries are missing!"
    exit 1
fi

echo ""
echo "=== All musl dependencies built successfully ==="
