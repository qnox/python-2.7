#!/usr/bin/env bash
# Build gdbm for musl
set -e

INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
BUILD_DIR="${BUILD_DIR:-/tmp/musl-deps-build}"

echo "Building gdbm..."
cd "${BUILD_DIR}"

if [ -f "${INSTALL_PREFIX}/lib/libgdbm.a" ]; then
    echo "gdbm already installed"
    exit 0
fi

curl -LO https://ftp.gnu.org/gnu/gdbm/gdbm-1.23.tar.gz
tar xzf gdbm-1.23.tar.gz
cd gdbm-1.23

CC=musl-clang CFLAGS="-fPIC" ./configure \
    --prefix="${INSTALL_PREFIX}" \
    --enable-static \
    --disable-shared \
    --enable-libgdbm-compat

make -j$(nproc)
sudo make install

cd ..
rm -rf gdbm-1.23 gdbm-1.23.tar.gz

echo "gdbm built successfully"
