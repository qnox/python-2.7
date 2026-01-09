#!/bin/bash
set -euo pipefail

# Test Python portable distribution from packaged archive
# This script unpacks the distribution to a temporary directory and runs tests

PYTHON_VERSION="2.7.18"
DIST_DIR="${PWD}/dist"

# Get script directory (must be before any cd commands)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get current date in YYYYMMDD format (should match what package.sh created)
RELEASE_DATE="${RELEASE_DATE:-$(date +%Y%m%d)}"

# Test flavor (can be overridden via FLAVOR env var, defaults to install_only)
FLAVOR="${FLAVOR:-install_only}"

# Follow python-build-standalone naming: cpython-VERSION+DATE-TRIPLE-FLAVOR
ARCHIVE_NAME="cpython-${PYTHON_VERSION}+${RELEASE_DATE}-${TARGET_TRIPLE}-${FLAVOR}"

echo "=== Testing Python ${PYTHON_VERSION} portable distribution ==="
echo "Target: ${TARGET_TRIPLE}"
echo "Platform: ${TARGET_PLATFORM:-unknown}"
echo "Flavor: ${FLAVOR}"

# Find the distribution archive
ARCHIVE=""
if [ -f "${DIST_DIR}/${ARCHIVE_NAME}.tar.gz" ]; then
    ARCHIVE="${DIST_DIR}/${ARCHIVE_NAME}.tar.gz"
    EXTRACT_CMD="tar xzf"
else
    echo "Error: No distribution archive found at ${DIST_DIR}/${ARCHIVE_NAME}.tar.gz"
    echo "Available files in ${DIST_DIR}:"
    ls -la "${DIST_DIR}/" || true
    exit 1
fi

echo "Found archive: ${ARCHIVE}"

# Create temporary test directory
TEST_DIR=$(mktemp -d -t python-test-XXXXXX)
echo "Test directory: ${TEST_DIR}"

# Cleanup on exit
trap "rm -rf ${TEST_DIR}" EXIT

# Extract archive to test directory
echo "Extracting archive..."
cd "${TEST_DIR}"
${EXTRACT_CMD} "${ARCHIVE}"

# Debug: what did we extract?
echo "Contents after extraction:"
ls -la "${TEST_DIR}"

# Archives extract to python/ subdirectory (python-build-standalone format)
PORTABLE_DIR="${TEST_DIR}/python"

if [ ! -d "${PORTABLE_DIR}" ]; then
    echo "Error: Expected python/ directory not found in archive"
    echo "Contents of ${TEST_DIR}:"
    ls -la "${TEST_DIR}"
    exit 1
fi

echo "Extracted to: ${PORTABLE_DIR}"

# Run tests using Python test script
echo ""
python3 "${SCRIPT_DIR}/test_distribution.py" "${PORTABLE_DIR}"
