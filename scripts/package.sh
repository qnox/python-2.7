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
sha256sum "${ARCHIVE_NAME}.tar.gz" > "${ARCHIVE_NAME}.tar.gz.sha256"
sha256sum "${ARCHIVE_NAME}.tar.xz" > "${ARCHIVE_NAME}.tar.xz.sha256"

echo "=== Packaging complete ==="
echo "Archives created in: ${DIST_DIR}"
ls -lh "${DIST_DIR}"
