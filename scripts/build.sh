#!/bin/bash
set -euo pipefail

# Unified build script for Python 2.7 portable builds
# Automatically detects platform and calls appropriate platform-specific script

PYTHON_VERSION="2.7.18"

# Detect platform
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    DETECTED_PLATFORM="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    DETECTED_PLATFORM="macos"
else
    echo "Error: Unsupported platform: $OSTYPE"
    exit 1
fi

# Use TARGET_PLATFORM if set, otherwise use detected
PLATFORM="${TARGET_PLATFORM:-$DETECTED_PLATFORM}"

echo "=== Python ${PYTHON_VERSION} Unified Build Script ==="
echo "Platform: ${PLATFORM}"
echo "Target: ${TARGET_TRIPLE:-auto}"
echo "Architecture: ${TARGET_ARCH:-auto}"

# Call platform-specific build script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "${PLATFORM}" in
    linux)
        echo "Calling Linux build script..."
        bash "${SCRIPT_DIR}/build-linux.sh"
        ;;
    macos)
        echo "Calling macOS build script..."
        bash "${SCRIPT_DIR}/build-macos.sh"
        ;;
    *)
        echo "Error: Unknown platform: ${PLATFORM}"
        exit 1
        ;;
esac

echo "=== Build complete ==="
