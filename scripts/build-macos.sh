#!/bin/bash
set -euo pipefail

# Python 2.7 portable build script for macOS
# Supports x86_64 and arm64 (Apple Silicon)

PYTHON_VERSION="2.7.18"
BUILD_DIR="${PWD}/build"
INSTALL_PREFIX="${BUILD_DIR}/python-install"
SOURCE_DIR="${PWD}/Python-${PYTHON_VERSION}"

echo "=== Building Python ${PYTHON_VERSION} for ${TARGET_TRIPLE} ==="

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

# Configure compiler flags for portable build
export MACOSX_DEPLOYMENT_TARGET="10.9"
export CFLAGS="-I${OPENSSL_PREFIX}/include -I${READLINE_PREFIX}/include -I${SQLITE_PREFIX}/include"
export LDFLAGS="-L${OPENSSL_PREFIX}/lib -L${READLINE_PREFIX}/lib -L${SQLITE_PREFIX}/lib -Wl,-rpath,@loader_path/../lib"
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
    --with-system-ffi \
    --with-system-expat \
    --enable-optimizations \
    --with-ensurepip=install

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
cp -r "${INSTALL_PREFIX}/python"/* "${PORTABLE_DIR}/"

# Fix library paths to be relocatable using install_name_tool
find "${PORTABLE_DIR}" -name "*.so" -o -name "*.dylib" | while read lib; do
    # Get current library paths
    otool -L "$lib" | grep -o "/.*\.dylib" | while read dep; do
        depname=$(basename "$dep")
        # Change absolute paths to relative paths
        install_name_tool -change "$dep" "@loader_path/../lib/$depname" "$lib" 2>/dev/null || true
    done
done

# Fix Python binary
if [ -f "${PORTABLE_DIR}/bin/python" ]; then
    install_name_tool -add_rpath "@loader_path/../lib" "${PORTABLE_DIR}/bin/python" 2>/dev/null || true
fi

# Create portable launcher script
cat > "${PORTABLE_DIR}/bin/python-portable" << 'EOF'
#!/bin/bash
# Portable Python launcher for macOS
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_HOME="$(dirname "${SCRIPT_DIR}")"
export DYLD_LIBRARY_PATH="${PYTHON_HOME}/lib:${DYLD_LIBRARY_PATH:-}"
export PYTHONHOME="${PYTHON_HOME}"
exec "${PYTHON_HOME}/bin/python" "$@"
EOF

chmod +x "${PORTABLE_DIR}/bin/python-portable"

# Create README for portable usage
cat > "${PORTABLE_DIR}/README.txt" << EOF
Python ${PYTHON_VERSION} Portable Build for macOS
Target: ${TARGET_TRIPLE}

This is a portable Python installation that can be placed in any directory.

Usage:
1. Extract this archive to any location
2. Use ./bin/python-portable to run Python with correct paths
3. Or set environment variables:
   export PYTHONHOME="\$(pwd)"
   export DYLD_LIBRARY_PATH="\${PYTHONHOME}/lib:\${DYLD_LIBRARY_PATH}"
   ./bin/python

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
