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
    echo "Installing musl tools..."
    sudo apt-get install -y musl-tools musl-dev
fi

# 32-bit architecture setup
if [ "${TARGET_ARCH}" = "i686" ]; then
    echo "Installing 32-bit build tools..."
    sudo dpkg --add-architecture i386
    sudo apt-get update
    sudo apt-get install -y gcc-multilib g++-multilib
fi

echo "=== Linux build environment setup complete ==="
