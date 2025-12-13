#!/bin/bash
set -euo pipefail

# Python 2.7 portable build script for Linux
# Supports both glibc and musl, x86_64 and i686

PYTHON_VERSION="2.7.18"
BUILD_DIR="${PWD}/build"
INSTALL_PREFIX="${BUILD_DIR}/python-install"
SOURCE_DIR="${PWD}/Python-${PYTHON_VERSION}"
DEPS_DIR="${BUILD_DIR}/deps"

echo "=== Building Python ${PYTHON_VERSION} for ${TARGET_TRIPLE} ==="

# Build libffi first
echo "Building libffi dependency..."
bash scripts/deps/build-libffi.sh

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

# Apply portable configuration
# This makes Python relocatable by using relative paths
# Use $$ to escape $ for make, \$$ for shell

# Use bundled libffi from deps
LIBFFI_PREFIX="${DEPS_DIR}/libffi"

# Set up compiler and linker flags with libffi
export CFLAGS="-fPIC -I${LIBFFI_PREFIX}/lib/libffi-3.4.6/include"
export LDFLAGS="-Wl,-rpath,\$ORIGIN/../lib -L${LIBFFI_PREFIX}/lib"
export CPPFLAGS="${CFLAGS}"

# Set PKG_CONFIG_PATH for libffi (required for _ctypes module)
export PKG_CONFIG_PATH="${LIBFFI_PREFIX}/lib/pkgconfig"

if [ "${TARGET_LIBC}" = "musl" ]; then
    # Check if we're on a true musl system (Alpine) or using musl-clang wrapper
    if [ -f /etc/alpine-release ]; then
        # Alpine - native musl, use default gcc
        echo "Building on Alpine (native musl)"
        EXTRA_CONFIG_ARGS="--disable-ipv6"
    elif command -v musl-clang >/dev/null 2>&1; then
        # Using musl-clang wrapper (built from source via setup-musl.sh)
        # This is the python-build-standalone approach
        export CC="musl-clang"
        export CXX="clang++"
        echo "Using musl-clang for musl build"

        # Find Python for cross-compilation (setup.py needs a host Python)
        if command -v python2.7 >/dev/null 2>&1; then
            PYTHON_FOR_BUILD="python2.7"
        elif command -v python2 >/dev/null 2>&1; then
            PYTHON_FOR_BUILD="python2"
        elif command -v python3 >/dev/null 2>&1; then
            PYTHON_FOR_BUILD="python3"
        else
            PYTHON_FOR_BUILD="python"
        fi

        EXTRA_CONFIG_ARGS="--disable-ipv6 PYTHON_FOR_BUILD=${PYTHON_FOR_BUILD}"
    else
        echo "ERROR: musl build requested but musl-clang not found"
        echo "Run setup-linux.sh first to build musl from source"
        exit 1
    fi
elif [ "${TARGET_ARCH}" = "i686" ]; then
    export CFLAGS="${CFLAGS} -m32"
    export LDFLAGS="-m32 -Wl,-rpath,\$ORIGIN/../lib -L${LIBFFI_PREFIX}/lib"
    # Find Python for cross-compilation
    if command -v python2.7 >/dev/null 2>&1; then
        PYTHON_FOR_BUILD="python2.7"
    elif command -v python2 >/dev/null 2>&1; then
        PYTHON_FOR_BUILD="python2"
    elif command -v python3 >/dev/null 2>&1; then
        PYTHON_FOR_BUILD="python3"
    else
        PYTHON_FOR_BUILD="python"
    fi
    EXTRA_CONFIG_ARGS="--disable-ipv6 --build=x86_64-pc-linux-gnu --host=i686-pc-linux-gnu PYTHON_FOR_BUILD=${PYTHON_FOR_BUILD}"
elif [ "${TARGET_ARCH}" = "aarch64" ] || [ "${TARGET_ARCH}" = "arm64" ]; then
    # ARM64 native build - no special flags needed
    EXTRA_CONFIG_ARGS=""
else
    # Default for x86_64 and other architectures
    EXTRA_CONFIG_ARGS=""
fi

# Configure Python for portable installation
./configure \
    --prefix="/python" \
    --enable-shared \
    --enable-unicode=ucs4 \
    --with-system-ffi \
    ${EXTRA_CONFIG_ARGS:-}

# Build
make -j$(nproc)

# Install to temporary location
rm -rf "${INSTALL_PREFIX}"
# Use sharedinstall first to install extension modules, then install everything else
# This approach is used by python-build-standalone to avoid PYTHONPATH issues
make -j$(nproc) sharedinstall DESTDIR="${INSTALL_PREFIX}"
make -j$(nproc) install DESTDIR="${INSTALL_PREFIX}"

echo "=== Creating portable Python distribution ==="

# Create portable structure
PORTABLE_DIR="${BUILD_DIR}/python-${PYTHON_VERSION}-${TARGET_TRIPLE}"
rm -rf "${PORTABLE_DIR}"
mkdir -p "${PORTABLE_DIR}"

# Copy installed files
cp -r "${INSTALL_PREFIX}/python"/* "${PORTABLE_DIR}/"

# Create portable launcher script
cat > "${PORTABLE_DIR}/bin/python-portable" << 'EOF'
#!/bin/bash
# Portable Python launcher
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_HOME="$(dirname "${SCRIPT_DIR}")"
export LD_LIBRARY_PATH="${PYTHON_HOME}/lib:${LD_LIBRARY_PATH:-}"
export PYTHONHOME="${PYTHON_HOME}"
exec "${PYTHON_HOME}/bin/python" "$@"
EOF

chmod +x "${PORTABLE_DIR}/bin/python-portable"

# Create README for portable usage
cat > "${PORTABLE_DIR}/README.txt" << EOF
Python ${PYTHON_VERSION} Portable Build
Target: ${TARGET_TRIPLE}

This is a portable Python installation that can be placed in any directory.

Usage:
1. Extract this archive to any location
2. Use ./bin/python-portable to run Python with correct paths
3. Or set environment variables:
   export PYTHONHOME="\$(pwd)"
   export LD_LIBRARY_PATH="\${PYTHONHOME}/lib:\${LD_LIBRARY_PATH}"
   ./bin/python

Features:
- Relocatable installation
- Shared library included
- Standard library included
- Full development headers included

Build info:
- Architecture: ${TARGET_ARCH}
- C Library: ${TARGET_LIBC}
- Built on: $(date)
EOF

echo "=== Build complete ==="
echo "Portable Python location: ${PORTABLE_DIR}"
