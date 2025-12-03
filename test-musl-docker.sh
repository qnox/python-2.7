#!/bin/bash
set -e

# Test Python 2.7 musl build in Docker (mimics GitHub Actions)

docker run --rm \
  -v "$(pwd):/workspace" \
  -w /workspace \
  ubuntu:20.04 \
  bash -c '
    set -e
    echo "=== Installing dependencies ==="
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
      curl gcc g++ make \
      musl-tools musl-dev \
      libssl-dev libffi-dev libsqlite3-dev \
      libbz2-dev libreadline-dev zlib1g-dev \
      > /dev/null 2>&1

    echo "=== Setting up build environment ==="
    export TARGET_PLATFORM=linux
    export TARGET_ARCH=x86_64
    export TARGET_LIBC=musl
    export TARGET_TRIPLE=x86_64-unknown-linux-musl

    echo "=== Cleaning previous build ==="
    rm -rf Python-2.7.18 build

    echo "=== Running build ==="
    bash scripts/build-linux.sh

    echo "=== Testing built Python ==="
    cd build/python-2.7.18-x86_64-unknown-linux-musl
    ./bin/python --version
    ./bin/python -c "import sys, _struct, datetime; print(\"SUCCESS: Python \" + sys.version.split()[0] + \" works with musl!\")"

    echo "=== Build and test completed successfully! ==="
  '
