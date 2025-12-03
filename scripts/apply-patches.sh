#!/bin/bash
set -euo pipefail

# Patch harness for Python 2.7 builds
# Applies patches based on platform, architecture, and environment

PATCHES_DIR="${PWD}/patches"
SOURCE_DIR="${1:-}"

if [ -z "${SOURCE_DIR}" ]; then
    echo "Error: Source directory not specified"
    echo "Usage: $0 <source-directory>"
    exit 1
fi

if [ ! -d "${SOURCE_DIR}" ]; then
    echo "Error: Source directory does not exist: ${SOURCE_DIR}"
    exit 1
fi

echo "=== Python 2.7 Patch Harness ==="
echo "Source directory: ${SOURCE_DIR}"
echo "Target platform: ${TARGET_PLATFORM:-unknown}"
echo "Target arch: ${TARGET_ARCH:-unknown}"
echo "Target libc: ${TARGET_LIBC:-unknown}"

# Function to apply patches from a directory
apply_patches_from_dir() {
    local patch_dir="$1"
    local description="$2"

    if [ ! -d "${patch_dir}" ]; then
        return 0
    fi

    local patches=($(find "${patch_dir}" -maxdepth 1 -name "*.patch" -type f | sort))

    if [ ${#patches[@]} -eq 0 ]; then
        return 0
    fi

    echo ""
    echo "Applying ${description}..."

    for patch in "${patches[@]}"; do
        echo "  - $(basename ${patch})"

        # Try to apply patch
        if patch -d "${SOURCE_DIR}" -p0 -N --dry-run -s < "${patch}" >/dev/null 2>&1; then
            patch -d "${SOURCE_DIR}" -p0 -N < "${patch}"
            echo "    ✓ Applied successfully"
        elif patch -d "${SOURCE_DIR}" -p1 -N --dry-run -s < "${patch}" >/dev/null 2>&1; then
            patch -d "${SOURCE_DIR}" -p1 -N < "${patch}"
            echo "    ✓ Applied successfully (with -p1)"
        else
            echo "    ⚠ Patch already applied or does not apply cleanly, skipping"
        fi
    done
}

# Apply patches in order of specificity
# 1. Common patches (all platforms)
apply_patches_from_dir "${PATCHES_DIR}/common" "common patches"

# 2. Platform-specific patches
case "${TARGET_PLATFORM:-unknown}" in
    linux)
        apply_patches_from_dir "${PATCHES_DIR}/linux" "Linux patches"

        # Apply libc-specific patches
        if [ -n "${TARGET_LIBC:-}" ]; then
            apply_patches_from_dir "${PATCHES_DIR}/linux/${TARGET_LIBC}" "Linux ${TARGET_LIBC} patches"
        fi
        ;;

    macos)
        apply_patches_from_dir "${PATCHES_DIR}/macos" "macOS patches"

        # Apply architecture-specific patches
        if [ -n "${TARGET_ARCH:-}" ]; then
            apply_patches_from_dir "${PATCHES_DIR}/macos/${TARGET_ARCH}" "macOS ${TARGET_ARCH} patches"
        fi
        ;;

    windows)
        apply_patches_from_dir "${PATCHES_DIR}/windows" "Windows patches"
        ;;

    *)
        echo "Warning: Unknown platform: ${TARGET_PLATFORM}"
        ;;
esac

echo ""
echo "=== Patch application complete ==="
