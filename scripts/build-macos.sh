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
    --with-ensurepip=no

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
# Fix the actual python2.7 binary (python and python2 are just symlinks to it)
echo "=== Fixing Python binary library paths ==="
echo "Checking for python binaries in ${PORTABLE_DIR}/bin/"
ls -la "${PORTABLE_DIR}/bin/python"* || echo "ERROR: No python binaries found!"

if [ -f "${PORTABLE_DIR}/bin/python2.7" ]; then
    echo "Found python2.7 binary"
    echo "BEFORE fix - Library paths for python2.7:"
    otool -L "${PORTABLE_DIR}/bin/python2.7" | head -5
    echo "BEFORE fix - Rpaths for python2.7:"
    otool -l "${PORTABLE_DIR}/bin/python2.7" | grep -A 2 "cmd LC_RPATH" || echo "No rpath found"

    # Change libpython path to use @rpath
    PYTHON_LIB=$(otool -L "${PORTABLE_DIR}/bin/python2.7" | grep "libpython" | grep -o "/.*\.dylib" | head -1) || true
    if [ -n "$PYTHON_LIB" ]; then
        echo "Changing libpython path: $PYTHON_LIB -> @rpath/$(basename $PYTHON_LIB)"
        if install_name_tool -change "$PYTHON_LIB" "@rpath/$(basename $PYTHON_LIB)" "${PORTABLE_DIR}/bin/python2.7" 2>&1; then
            echo "install_name_tool -change: SUCCESS"
        else
            CHANGE_RESULT=$?
            echo "install_name_tool -change: FAILED with exit code $CHANGE_RESULT"
            exit 1
        fi
    else
        echo "ERROR: No libpython found in python2.7 dependencies"
        echo "Full otool output:"
        otool -L "${PORTABLE_DIR}/bin/python2.7"
        exit 1
    fi

    echo "Adding rpath @loader_path/../lib"
    # Check if rpath already exists
    if otool -l "${PORTABLE_DIR}/bin/python2.7" | grep -q "@loader_path/../lib"; then
        echo "Rpath @loader_path/../lib already exists, skipping"
    else
        install_name_tool -add_rpath "@loader_path/../lib" "${PORTABLE_DIR}/bin/python2.7"
        RPATH_RESULT=$?
        echo "install_name_tool -add_rpath exit code: $RPATH_RESULT"
    fi

    echo "AFTER fix - Library paths for python2.7:"
    otool -L "${PORTABLE_DIR}/bin/python2.7" | head -5
    echo "AFTER fix - Rpaths for python2.7:"
    otool -l "${PORTABLE_DIR}/bin/python2.7" | grep -A 2 "cmd LC_RPATH"

    # Verify the fix was applied
    FINAL_LIB=$(otool -L "${PORTABLE_DIR}/bin/python2.7" | grep "libpython" | head -1)
    if echo "$FINAL_LIB" | grep -q "@rpath"; then
        echo "SUCCESS: Library path successfully changed to use @rpath"
    else
        echo "ERROR: Library path still not using @rpath: $FINAL_LIB"
        exit 1
    fi
else
    echo "ERROR: ${PORTABLE_DIR}/bin/python2.7 not found!"
    exit 1
fi
echo "=== Library paths fixed ==="

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
