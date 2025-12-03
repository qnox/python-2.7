#!/bin/bash
set -euo pipefail

# Package Python portable distribution
PYTHON_VERSION="2.7.18"
BUILD_DIR="${PWD}/build"
DIST_DIR="${PWD}/dist"
PORTABLE_DIR="${BUILD_DIR}/python-${PYTHON_VERSION}-${TARGET_TRIPLE}"

echo "=== Packaging Python ${PYTHON_VERSION} for ${TARGET_TRIPLE} ==="

# Create dist directory
mkdir -p "${DIST_DIR}"

# Create archive name
ARCHIVE_NAME="python-${PYTHON_VERSION}-${TARGET_TRIPLE}-portable"

# Package as tar.gz
echo "Creating ${ARCHIVE_NAME}.tar.gz..."
cd "${BUILD_DIR}"
tar czf "${DIST_DIR}/${ARCHIVE_NAME}.tar.gz" "python-${PYTHON_VERSION}-${TARGET_TRIPLE}"

# Package as tar.xz for better compression
echo "Creating ${ARCHIVE_NAME}.tar.xz..."
tar cJf "${DIST_DIR}/${ARCHIVE_NAME}.tar.xz" "python-${PYTHON_VERSION}-${TARGET_TRIPLE}"

# Generate checksums
cd "${DIST_DIR}"
# Use shasum on macOS, sha256sum on Linux
if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${ARCHIVE_NAME}.tar.gz" > "${ARCHIVE_NAME}.tar.gz.sha256"
    sha256sum "${ARCHIVE_NAME}.tar.xz" > "${ARCHIVE_NAME}.tar.xz.sha256"
elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "${ARCHIVE_NAME}.tar.gz" > "${ARCHIVE_NAME}.tar.gz.sha256"
    shasum -a 256 "${ARCHIVE_NAME}.tar.xz" > "${ARCHIVE_NAME}.tar.xz.sha256"
else
    echo "WARNING: No SHA256 utility found, skipping checksums"
fi

echo "=== Packaging complete ==="
echo "Archives created in: ${DIST_DIR}"
ls -lh "${DIST_DIR}"

# Verify the packaged binary has correct library paths (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo ""
    echo "=== Verifying packaged binary ==="
    TEMP_VERIFY=$(mktemp -d)
    cd "${TEMP_VERIFY}"
    tar xzf "${DIST_DIR}/${ARCHIVE_NAME}.tar.gz" "python-${PYTHON_VERSION}-${TARGET_TRIPLE}/bin/python2.7"

    echo "Checking library paths in packaged python2.7:"
    LIB_PATHS=$(otool -L "python-${PYTHON_VERSION}-${TARGET_TRIPLE}/bin/python2.7" | grep libpython)
    echo "$LIB_PATHS"

    if echo "$LIB_PATHS" | grep -q "@rpath/libpython"; then
        echo "✓ VERIFIED: Packaged binary uses @rpath (correct)"
    else
        echo "✗ ERROR: Packaged binary does NOT use @rpath!"
        echo "Full library paths:"
        otool -L "python-${PYTHON_VERSION}-${TARGET_TRIPLE}/bin/python2.7"
        rm -rf "${TEMP_VERIFY}"
        exit 1
    fi

    rm -rf "${TEMP_VERIFY}"
    cd "${DIST_DIR}"
fi
