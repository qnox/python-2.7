#!/bin/bash
set -euo pipefail

# Python 2.7 portable build script for Linux
# Supports both glibc and musl, x86_64 and i686

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

# Apply portable configuration
# This makes Python relocatable by using relative paths
export LDFLAGS='-Wl,-rpath,$ORIGIN/../lib'
export CFLAGS="-fPIC"

if [ "${TARGET_LIBC}" = "musl" ]; then
    if [ "${TARGET_ARCH}" = "x86_64" ]; then
        export CC="musl-gcc"
        export CXX="musl-g++"
        EXTRA_CONFIG_ARGS="--disable-ipv6"
    elif [ "${TARGET_ARCH}" = "i686" ]; then
        # musl-gcc doesn't support -m32 for cross-compilation
        # This requires a proper i686-linux-musl cross-compilation toolchain
        echo "ERROR: musl i686 cross-compilation requires a dedicated toolchain"
        echo "musl-gcc does not support multilib (-m32) compilation"
        echo "This target should be built in a container with i686-linux-musl-gcc"
        exit 1
    else
        echo "Cross-compilation for musl ${TARGET_ARCH} not implemented yet"
        exit 1
    fi
elif [ "${TARGET_ARCH}" = "i686" ]; then
    export CFLAGS="${CFLAGS} -m32"
    export LDFLAGS="${LDFLAGS} -m32"
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
else
    EXTRA_CONFIG_ARGS=""
fi

# Configure Python for portable installation
./configure \
    --prefix="/python" \
    --enable-shared \
    --enable-unicode=ucs4 \
    ${EXTRA_CONFIG_ARGS:-}

# Build
make -j$(nproc)

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
