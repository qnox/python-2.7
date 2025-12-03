#!/usr/bin/env bash
# Build ncurses for musl
set -e

INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
BUILD_DIR="${BUILD_DIR:-/tmp/musl-deps-build}"

echo "Building ncurses..."
cd "${BUILD_DIR}"

if [ -f "${INSTALL_PREFIX}/lib/libncursesw.a" ]; then
    echo "ncurses already installed"
    exit 0
fi

curl -LO https://invisible-mirror.net/archives/ncurses/ncurses-6.4.tar.gz
tar xzf ncurses-6.4.tar.gz
cd ncurses-6.4

CC=musl-clang CFLAGS="-fPIC" ./configure \
    --prefix="${INSTALL_PREFIX}" \
    --enable-static \
    --disable-shared \
    --enable-widec \
    --without-cxx \
    --without-cxx-binding \
    --without-ada \
    --without-manpages \
    --without-tests \
    --disable-stripping

make -j$(nproc)
sudo make install

cd ..
rm -rf ncurses-6.4 ncurses-6.4.tar.gz

echo "ncurses built successfully"
