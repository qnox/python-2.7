#!/bin/bash
set -euo pipefail

# Setup Linux build environment for Python 2.7
# This script installs all required dependencies

echo "=== Setting up Linux build environment ==="
echo "Architecture: ${TARGET_ARCH}"
echo "C Library: ${TARGET_LIBC}"

# Update package lists
sudo apt-get update

# Install base build dependencies
echo "Installing base dependencies..."
sudo apt-get install -y \
    build-essential \
    gdb \
    lcov \
    pkg-config \
    libbz2-dev \
    libffi-dev \
    libgdbm-dev \
    libgdbm-compat-dev \
    liblzma-dev \
    libncurses5-dev \
    libreadline6-dev \
    libsqlite3-dev \
    libssl-dev \
    lzma \
    lzma-dev \
    tk-dev \
    uuid-dev \
    zlib1g-dev

# musl-specific setup
if [ "${TARGET_LIBC}" = "musl" ]; then
    echo "Setting up musl build environment..."
    # Install clang for building musl
    sudo apt-get install -y clang

    # Build and install musl from source with musl-clang wrapper
    # This approach is used by python-build-standalone
    bash "$(dirname "$0")/setup-musl.sh"

    # Build all Python dependencies from source with musl-clang
    echo "Building Python dependencies from source..."
    bash "$(dirname "$0")/build-musl-deps.sh"
fi

# 32-bit architecture setup
if [ "${TARGET_ARCH}" = "i686" ]; then
    echo "Installing 32-bit build tools..."
    sudo dpkg --add-architecture i386
    sudo apt-get update
    sudo apt-get install -y \
        gcc-multilib \
        g++-multilib \
        libc6-dev-i386 \
        lib32z1-dev \
        lib32ncurses-dev

    # For musl i686, we need additional setup
    if [ "${TARGET_LIBC}" = "musl" ]; then
        echo "Note: musl i686 cross-compilation requires musl-gcc with multilib support"
        echo "This may not work on all systems. Consider building natively or in a container."
    fi
fi

echo "=== Linux build environment setup complete ==="
