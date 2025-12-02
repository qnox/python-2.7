#!/bin/bash
set -euo pipefail

# Setup macOS build environment for Python 2.7
# This script installs all required dependencies via Homebrew

echo "=== Setting up macOS build environment ==="
echo "Architecture: ${TARGET_ARCH}"

# Install dependencies via Homebrew
echo "Installing dependencies via Homebrew..."
brew install \
    openssl@1.1 \
    readline \
    sqlite3 \
    xz \
    zlib \
    tcl-tk

echo "=== macOS build environment setup complete ==="
