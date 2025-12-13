#!/bin/bash
set -euo pipefail

# Python 2.7 portable build script for macOS
# Supports x86_64 and arm64 (Apple Silicon)

PYTHON_VERSION="2.7.18"
BUILD_DIR="${PWD}/build"
INSTALL_PREFIX="${BUILD_DIR}/python-install"
SOURCE_DIR="${PWD}/Python-${PYTHON_VERSION}"
DEPS_DIR="${BUILD_DIR}/deps"

echo "=== Building Python ${PYTHON_VERSION} for ${TARGET_TRIPLE} ==="

# On macOS 10.15+ (Catalina), use system libffi which has proper support for
# closures on ARM64 via libffi-trampolines.dylib. This is what pyenv does.
# The pyenv patches (0004 and 0006) configure Python to use system libffi automatically.
echo "Note: Using system libffi on macOS (not building custom libffi)"

# Download Python source if not present
if [ ! -d "${SOURCE_DIR}" ]; then
    echo "Downloading Python ${PYTHON_VERSION}..."
    curl -LO "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz"
    tar xzf "Python-${PYTHON_VERSION}.tgz"
    rm "Python-${PYTHON_VERSION}.tgz"
fi

# Apply patches
echo "Applying patches..."
bash scripts/apply-patches.sh "${SOURCE_DIR}"

cd "${SOURCE_DIR}"

# Set up homebrew paths for dependencies
OPENSSL_PREFIX="/usr/local/opt/openssl@1.1"
if [ ! -d "${OPENSSL_PREFIX}" ]; then
    OPENSSL_PREFIX="/opt/homebrew/opt/openssl@1.1"
fi

READLINE_PREFIX="/usr/local/opt/readline"
if [ ! -d "${READLINE_PREFIX}" ]; then
    READLINE_PREFIX="/opt/homebrew/opt/readline"
fi

SQLITE_PREFIX="/usr/local/opt/sqlite"
if [ ! -d "${SQLITE_PREFIX}" ]; then
    SQLITE_PREFIX="/opt/homebrew/opt/sqlite"
fi

ZLIB_PREFIX="/usr/local/opt/zlib"
if [ ! -d "${ZLIB_PREFIX}" ]; then
    ZLIB_PREFIX="/opt/homebrew/opt/zlib"
fi

# Configure compiler flags for portable build
# Note: NOT setting libffi paths - using system libffi on macOS 10.15+
export MACOSX_DEPLOYMENT_TARGET="10.9"
export CFLAGS="-I${OPENSSL_PREFIX}/include -I${READLINE_PREFIX}/include -I${SQLITE_PREFIX}/include -I${ZLIB_PREFIX}/include"
export LDFLAGS="-L${OPENSSL_PREFIX}/lib -L${READLINE_PREFIX}/lib -L${SQLITE_PREFIX}/lib -L${ZLIB_PREFIX}/lib -Wl,-rpath,@loader_path/../lib"
export CPPFLAGS="${CFLAGS}"

# Architecture-specific settings
if [ "${TARGET_ARCH}" = "arm64" ]; then
    export MACOSX_DEPLOYMENT_TARGET="11.0"
    ARCH_FLAGS="-arch arm64"
elif [ "${TARGET_ARCH}" = "x86_64" ]; then
    ARCH_FLAGS="-arch x86_64"
else
    echo "Unknown architecture: ${TARGET_ARCH}"
    exit 1
fi

export CFLAGS="${CFLAGS} ${ARCH_FLAGS}"
export LDFLAGS="${LDFLAGS} ${ARCH_FLAGS}"

# Configure Python for portable installation
./configure \
    --prefix="/python" \
    --enable-framework=no \
    --enable-shared \
    --enable-unicode=ucs2 \
    --with-ensurepip=no \
    --with-system-ffi

# Build
make -j$(sysctl -n hw.ncpu)

# Install to temporary location
rm -rf "${INSTALL_PREFIX}"
make install DESTDIR="${INSTALL_PREFIX}"

echo "=== Creating portable Python distribution ==="

# Create portable structure
PORTABLE_DIR="${BUILD_DIR}/python-${PYTHON_VERSION}-${TARGET_TRIPLE}"
rm -rf "${PORTABLE_DIR}"
mkdir -p "${PORTABLE_DIR}"

# Copy installed files
echo "Checking installation at: ${INSTALL_PREFIX}"
ls -la "${INSTALL_PREFIX}" || echo "INSTALL_PREFIX does not exist"
if [ -d "${INSTALL_PREFIX}/python" ]; then
    echo "Contents of ${INSTALL_PREFIX}/python:"
    ls -la "${INSTALL_PREFIX}/python"
    cp -r "${INSTALL_PREFIX}/python"/* "${PORTABLE_DIR}/"
else
    echo "ERROR: ${INSTALL_PREFIX}/python does not exist!"
    exit 1
fi

# Fix library paths to be relocatable using install_name_tool
# Only change paths to libpython, not system libraries
find "${PORTABLE_DIR}" \( -name "*.so" -o -name "*.dylib" \) | while read lib; do
    # Get current library paths and only fix libpython references
    # Use || true to prevent grep from failing the script when no matches are found
    otool -L "$lib" 2>/dev/null | grep "libpython" | grep -o "/.*\.dylib" | while read dep; do
        depname=$(basename "$dep")
        # Change absolute paths to relative paths
        install_name_tool -change "$dep" "@loader_path/../lib/$depname" "$lib" 2>/dev/null || true
    done || true
done

# Fix Python binary - change libpython path and add rpath
# Need to fix ALL python binaries because they are hardlinks, not symlinks
# When tar creates archives, it preserves hardlinks so they all need fixing
echo "=== Fixing Python binary library paths ==="
echo "Checking for python binaries in ${PORTABLE_DIR}/bin/"
ls -la "${PORTABLE_DIR}/bin/python"* || echo "ERROR: No python binaries found!"

# Function to fix a binary
fix_binary() {
    local BINARY_PATH="$1"
    local BINARY_NAME=$(basename "$BINARY_PATH")

    echo ""
    echo "--- Fixing $BINARY_NAME ---"
    echo "BEFORE fix:"
    otool -L "$BINARY_PATH" | head -5

    # Change libpython path to use @rpath
    PYTHON_LIB=$(otool -L "$BINARY_PATH" | grep "libpython" | grep -o "/.*\.dylib" | head -1) || true
    if [ -n "$PYTHON_LIB" ]; then
        echo "Changing: $PYTHON_LIB -> @rpath/$(basename $PYTHON_LIB)"
        install_name_tool -change "$PYTHON_LIB" "@rpath/$(basename $PYTHON_LIB)" "$BINARY_PATH" || exit 1
    fi

    # Add rpath if not exists
    if ! otool -l "$BINARY_PATH" | grep -q "@loader_path/../lib"; then
        install_name_tool -add_rpath "@loader_path/../lib" "$BINARY_PATH" || exit 1
    fi

    echo "AFTER fix:"
    otool -L "$BINARY_PATH" | head -5

    # Verify
    FINAL_LIB=$(otool -L "$BINARY_PATH" | grep "libpython" | head -1)
    if echo "$FINAL_LIB" | grep -q "@rpath"; then
        echo "✓ $BINARY_NAME: SUCCESS"
    else
        echo "✗ ERROR: $BINARY_NAME failed: $FINAL_LIB"
        exit 1
    fi
}

# Fix all python binaries (they are hardlinks, all need fixing)
for BINARY in python python2 python2.7; do
    if [ -f "${PORTABLE_DIR}/bin/$BINARY" ]; then
        fix_binary "${PORTABLE_DIR}/bin/$BINARY"
    fi
done

echo ""
echo "=== All Python binaries fixed ==="

# Create README for portable usage
cat > "${PORTABLE_DIR}/README.txt" << EOF
Python ${PYTHON_VERSION} Portable Build for macOS
Target: ${TARGET_TRIPLE}

This is a portable Python installation that can be placed in any directory.

Usage:
1. Extract this archive to any location
2. Run ./bin/python or ./bin/python2 directly

Features:
- Relocatable installation
- Shared libraries with @rpath for portability
- Standard library included
- Full development headers included
- pip included

Build info:
- Architecture: ${TARGET_ARCH}
- Deployment Target: ${MACOSX_DEPLOYMENT_TARGET}
- Built on: $(date)

Note: This build requires macOS ${MACOSX_DEPLOYMENT_TARGET} or later.
EOF

echo "=== Build complete ==="
echo "Portable Python location: ${PORTABLE_DIR}"
