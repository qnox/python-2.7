#!/bin/bash
set -euo pipefail

# Package Python portable distribution
# Supports creating multiple flavors: install_only and install_only_stripped

PYTHON_VERSION="2.7.18"
BUILD_DIR="${PWD}/build"
DIST_DIR="${PWD}/dist"
PORTABLE_DIR="${BUILD_DIR}/python-${PYTHON_VERSION}-${TARGET_TRIPLE}"

# Get current date in YYYYMMDD format for release tag
RELEASE_DATE=$(date +%Y%m%d)

echo "=== Packaging Python ${PYTHON_VERSION} for ${TARGET_TRIPLE} ==="

# Create dist directory
mkdir -p "${DIST_DIR}"

# Function to create an archive for a specific flavor
create_archive() {
    local FLAVOR=$1
    local SOURCE_DIR=$2

    # Follow python-build-standalone naming: cpython-VERSION+DATE-TRIPLE-FLAVOR
    local ARCHIVE_NAME="cpython-${PYTHON_VERSION}+${RELEASE_DATE}-${TARGET_TRIPLE}-${FLAVOR}"

    echo ""
    echo "=== Creating ${FLAVOR} archive ==="

    cd "${BUILD_DIR}"

    # Create tar.gz (for compatibility)
    echo "Creating ${ARCHIVE_NAME}.tar.gz..."
    tar czf "${DIST_DIR}/${ARCHIVE_NAME}.tar.gz" -C "${SOURCE_DIR}" .

    # Generate checksum
    cd "${DIST_DIR}"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "${ARCHIVE_NAME}.tar.gz" > "${ARCHIVE_NAME}.tar.gz.sha256"
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "${ARCHIVE_NAME}.tar.gz" > "${ARCHIVE_NAME}.tar.gz.sha256"
    else
        echo "WARNING: No SHA256 utility found, skipping checksum for ${FLAVOR}"
    fi

    echo "✓ Created ${ARCHIVE_NAME}.tar.gz"
    ls -lh "${DIST_DIR}/${ARCHIVE_NAME}.tar.gz"
}

# Function to strip binaries in a directory tree
strip_binaries() {
    local DIR=$1

    echo "Stripping binaries in ${DIR}..."

    if [[ "$OSTYPE" == "darwin"* ]] || uname -s | grep -q "Darwin"; then
        # macOS: strip binaries and shared libraries
        find "${DIR}" -type f \( -name "*.so" -o -name "*.dylib" -o -perm +111 \) -exec file {} \; | \
            grep -E "Mach-O.*executable|Mach-O.*dynamically linked shared library" | \
            cut -d: -f1 | \
            while read -r binary; do
                echo "  Stripping: $(basename "$binary")"
                strip -x "$binary" 2>/dev/null || true
            done
    else
        # Linux: strip binaries and shared objects
        find "${DIR}" -type f \( -name "*.so*" -o -perm /111 \) -exec file {} \; | \
            grep -E "ELF.*executable|ELF.*shared object" | \
            cut -d: -f1 | \
            while read -r binary; do
                echo "  Stripping: $(basename "$binary")"
                strip "$binary" 2>/dev/null || true
            done
    fi

    echo "✓ Stripping complete"
}

# Create install_only flavor (unstripped)
echo ""
echo "=== Creating install_only flavor ==="
create_archive "install_only" "${PORTABLE_DIR}"

# Create install_only_stripped flavor
echo ""
echo "=== Creating install_only_stripped flavor ==="

# Create a temporary copy for stripping
STRIPPED_DIR="${BUILD_DIR}/python-${PYTHON_VERSION}-${TARGET_TRIPLE}-stripped"
echo "Creating stripped copy at: ${STRIPPED_DIR}"
rm -rf "${STRIPPED_DIR}"
cp -R "${PORTABLE_DIR}" "${STRIPPED_DIR}"

# Strip the binaries
strip_binaries "${STRIPPED_DIR}"

# Create the stripped archive
create_archive "install_only_stripped" "${STRIPPED_DIR}"

# Clean up stripped directory
rm -rf "${STRIPPED_DIR}"

echo ""
echo "=== Packaging complete ==="
echo "Archives created in: ${DIST_DIR}"
ls -lh "${DIST_DIR}"

# Verify the packaged binary has correct library paths (macOS only)
if [[ "$OSTYPE" == "darwin"* ]] || uname -s | grep -q "Darwin"; then
    echo ""
    echo "=== Verifying packaged binaries ==="
    echo "OS: $(uname -s), OSTYPE: ${OSTYPE:-not set}"

    for FLAVOR in "install_only" "install_only_stripped"; do
        echo ""
        echo "--- Verifying ${FLAVOR} ---"

        ARCHIVE_NAME="cpython-${PYTHON_VERSION}+${RELEASE_DATE}-${TARGET_TRIPLE}-${FLAVOR}"
        TEMP_VERIFY=$(mktemp -d)
        cd "${TEMP_VERIFY}"

        tar xzf "${DIST_DIR}/${ARCHIVE_NAME}.tar.gz" "bin/python2.7" 2>&1 || {
            echo "ERROR: Failed to extract binary from ${FLAVOR} archive"
            rm -rf "${TEMP_VERIFY}"
            exit 1
        }

        BINARY_PATH="bin/python2.7"
        echo "Extracted binary: $BINARY_PATH"
        ls -la "$BINARY_PATH"

        LIB_PATHS=$(otool -L "$BINARY_PATH" | grep libpython || echo "")

        if [ -z "$LIB_PATHS" ]; then
            echo "✓ VERIFIED: ${FLAVOR} binary is statically linked (no libpython dependency)"
        else
            echo "⚠ WARNING: ${FLAVOR} binary has libpython dependency (should be static):"
            echo "$LIB_PATHS"
            echo "This may cause issues with virtualenv"
        fi

        rm -rf "${TEMP_VERIFY}"
    done

    cd "${DIST_DIR}"
else
    echo "Skipping verification (not macOS): OS=$(uname -s), OSTYPE=${OSTYPE:-not set}"
fi

echo ""
echo "=== Summary ==="
echo "Flavors created:"
echo "  - install_only: Full installation with debug symbols"
echo "  - install_only_stripped: Smaller, debug symbols removed"
