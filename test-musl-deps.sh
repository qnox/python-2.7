#!/bin/bash
# Quick test for musl dependencies build
# Use this to quickly test if all dependencies build correctly

set -e

PLATFORM=${1:-linux/arm64}

echo "=== Quick test: Building musl dependencies ==="
echo "Platform: $PLATFORM"

docker run --rm --platform $PLATFORM \
    -v $(pwd):/work -w /work \
    ubuntu:24.04 bash -c "
    set -e
    export DEBIAN_FRONTEND=noninteractive

    echo '1. Installing build tools...'
    apt-get update -qq
    apt-get install -y -qq build-essential curl clang sudo

    echo '2. Building musl-clang...'
    bash /work/scripts/setup-musl.sh

    echo '3. Testing musl-clang...'
    which musl-clang
    musl-clang --version

    echo '4. Building dependencies (this may take 10-15 minutes)...'
    bash /work/scripts/build-musl-deps.sh

    echo '5. Verifying all libraries exist...'
    LIBS=(libz.a libbz2.a liblzma.a libsqlite3.a libssl.a libcrypto.a libffi.a libncursesw.a libreadline.a libgdbm.a)
    for lib in \${LIBS[@]}; do
        if [ -f /usr/local/lib/\$lib ]; then
            echo \"  ✓ \$lib\"
        else
            echo \"  ✗ \$lib NOT FOUND\"
            exit 1
        fi
    done

    echo ''
    echo '=== All dependencies built successfully ==='
    echo 'Built libraries:'
    ls -lh /usr/local/lib/*.a
"

echo ""
echo "✓ Dependencies test passed!"
