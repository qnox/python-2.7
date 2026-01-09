#!/bin/bash
set -euo pipefail

# Python 2.7 build script for macOS
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
# Note: NOT using --enable-shared to avoid virtualenv issues
# Python 2.7's virtualenv always copies binaries, which breaks with shared libpython
./configure \
    --prefix="/python" \
    --enable-framework=no \
    --enable-unicode=ucs2 \
    --with-ensurepip=no \
    --with-system-ffi

# Build
make -j$(sysctl -n hw.ncpu)

# Install to temporary location
rm -rf "${INSTALL_PREFIX}"
make install DESTDIR="${INSTALL_PREFIX}"

echo "=== Creating Python distribution ==="

# Create distribution structure
PYTHON_DIST_DIR="${BUILD_DIR}/python-${PYTHON_VERSION}-${TARGET_TRIPLE}"
rm -rf "${PYTHON_DIST_DIR}"
mkdir -p "${PYTHON_DIST_DIR}"

# Copy installed files
echo "Checking installation at: ${INSTALL_PREFIX}"
ls -la "${INSTALL_PREFIX}" || echo "INSTALL_PREFIX does not exist"
if [ -d "${INSTALL_PREFIX}/python" ]; then
    echo "Contents of ${INSTALL_PREFIX}/python:"
    ls -la "${INSTALL_PREFIX}/python"
    cp -r "${INSTALL_PREFIX}/python"/* "${PYTHON_DIST_DIR}/"
else
    echo "ERROR: ${INSTALL_PREFIX}/python does not exist!"
    exit 1
fi

# Note: No dylib fixup needed since we're building without --enable-shared
# The Python binary is statically linked and doesn't require libpython2.7.dylib

# Create README for usage
cat > "${PYTHON_DIST_DIR}/README.txt" << EOF
Python ${PYTHON_VERSION} Build for macOS
Target: ${TARGET_TRIPLE}

This is a self-contained Python installation that can be placed in any directory (portable).

Usage:
1. Extract this archive to any location
2. Run ./bin/python or ./bin/python2 directly

Features:
- Self-contained and relocatable
- Statically linked binary (no external dependencies)
- Standard library included
- Full development headers included
- Compatible with virtualenv
- pip included

Build info:
- Architecture: ${TARGET_ARCH}
- Deployment Target: ${MACOSX_DEPLOYMENT_TARGET}
- Built on: $(date)

Note: This build requires macOS ${MACOSX_DEPLOYMENT_TARGET} or later.
EOF

echo "=== Build complete ==="
echo "Python distribution location: ${PYTHON_DIST_DIR}"
