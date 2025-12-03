#!/usr/bin/env bash
# Build dependencies for musl Python builds following python-build-standalone approach
# All dependencies are built statically with musl-clang

set -e

BUILD_DIR="/tmp/musl-deps-build"
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"

mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

echo "=== Building musl dependencies for Python ==="

# Copy stdatomic.h from clang (needed by OpenSSL and others)
if [ ! -f "${INSTALL_PREFIX}/include/stdatomic.h" ]; then
    CLANG_ATOMICS=$(find /usr/lib/clang /usr/lib/llvm* -name "stdatomic.h" 2>/dev/null | head -1)
    if [ -n "$CLANG_ATOMICS" ]; then
        echo "Copying stdatomic.h from clang..."
        sudo cp "$CLANG_ATOMICS" "${INSTALL_PREFIX}/include/"
    fi
fi

# zlib
echo "Building zlib..."
if [ ! -f "${INSTALL_PREFIX}/lib/libz.a" ]; then
    curl -L https://github.com/madler/zlib/releases/download/v1.3/zlib-1.3.tar.gz -o zlib-1.3.tar.gz
    tar xzf zlib-1.3.tar.gz
    cd zlib-1.3
    CC=musl-clang ./configure --prefix="${INSTALL_PREFIX}" --static
    make -j$(nproc)
    sudo make install
    cd ..
    rm -rf zlib-1.3 zlib-1.3.tar.gz
fi

# bzip2
echo "Building bzip2..."
if [ ! -f "${INSTALL_PREFIX}/lib/libbz2.a" ]; then
    curl -LO https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz
    tar xzf bzip2-1.0.8.tar.gz
    cd bzip2-1.0.8
    make -j$(nproc) CC=musl-clang AR=ar RANLIB=ranlib
    sudo make install PREFIX="${INSTALL_PREFIX}"
    cd ..
    rm -rf bzip2-1.0.8 bzip2-1.0.8.tar.gz
fi

# xz
echo "Building xz..."
if [ ! -f "${INSTALL_PREFIX}/lib/liblzma.a" ]; then
    curl -LO https://github.com/tukaani-project/xz/releases/download/v5.6.3/xz-5.6.3.tar.gz
    tar xzf xz-5.6.3.tar.gz
    cd xz-5.6.3
    CC=musl-clang CFLAGS="-fPIC" ./configure --prefix="${INSTALL_PREFIX}" --enable-static --disable-shared
    make -j$(nproc)
    sudo make install
    cd ..
    rm -rf xz-5.6.3 xz-5.6.3.tar.gz
fi

# sqlite3
echo "Building sqlite3..."
if [ ! -f "${INSTALL_PREFIX}/lib/libsqlite3.a" ]; then
    curl -LO https://www.sqlite.org/2024/sqlite-autoconf-3450100.tar.gz
    tar xzf sqlite-autoconf-3450100.tar.gz
    cd sqlite-autoconf-3450100
    CC=musl-clang CFLAGS="-fPIC" ./configure --prefix="${INSTALL_PREFIX}" --enable-static --disable-shared
    make -j$(nproc)
    sudo make install
    cd ..
    rm -rf sqlite-autoconf-3450100 sqlite-autoconf-3450100.tar.gz
fi

# OpenSSL
echo "Building OpenSSL..."
if [ ! -f "${INSTALL_PREFIX}/lib/libssl.a" ]; then
    curl -LO https://www.openssl.org/source/openssl-1.1.1w.tar.gz
    tar xzf openssl-1.1.1w.tar.gz
    cd openssl-1.1.1w
    CC=musl-clang ./config --prefix="${INSTALL_PREFIX}" no-shared no-async
    make -j$(nproc)
    sudo make install_sw
    cd ..
    rm -rf openssl-1.1.1w openssl-1.1.1w.tar.gz
fi

# libffi
echo "Building libffi..."
if [ ! -f "${INSTALL_PREFIX}/lib/libffi.a" ]; then
    curl -LO https://github.com/libffi/libffi/releases/download/v3.4.4/libffi-3.4.4.tar.gz
    tar xzf libffi-3.4.4.tar.gz
    cd libffi-3.4.4
    CC=musl-clang CFLAGS="-fPIC" ./configure --prefix="${INSTALL_PREFIX}" --enable-static --disable-shared
    make -j$(nproc)
    sudo make install
    cd ..
    rm -rf libffi-3.4.4 libffi-3.4.4.tar.gz
fi

# ncurses (needed by readline)
echo "Building ncurses..."
if [ ! -f "${INSTALL_PREFIX}/lib/libncursesw.a" ]; then
    curl -LO https://invisible-mirror.net/archives/ncurses/ncurses-6.4.tar.gz
    tar xzf ncurses-6.4.tar.gz
    cd ncurses-6.4
    CC=musl-clang CFLAGS="-fPIC" ./configure \
        --prefix="${INSTALL_PREFIX}" \
        --enable-static --disable-shared \
        --enable-widec \
        --without-cxx --without-cxx-binding \
        --without-ada --without-manpages --without-tests \
        --disable-stripping
    make -j$(nproc)
    sudo make install
    cd ..
    rm -rf ncurses-6.4 ncurses-6.4.tar.gz
fi

# readline
echo "Building readline..."
if [ ! -f "${INSTALL_PREFIX}/lib/libreadline.a" ]; then
    curl -LO https://ftp.gnu.org/gnu/readline/readline-8.2.tar.gz
    tar xzf readline-8.2.tar.gz
    cd readline-8.2
    CC=musl-clang CFLAGS="-fPIC" ./configure --prefix="${INSTALL_PREFIX}" --enable-static --disable-shared
    make -j$(nproc)
    sudo make install
    cd ..
    rm -rf readline-8.2 readline-8.2.tar.gz
fi

# gdbm
echo "Building gdbm..."
if [ ! -f "${INSTALL_PREFIX}/lib/libgdbm.a" ]; then
    curl -LO https://ftp.gnu.org/gnu/gdbm/gdbm-1.23.tar.gz
    tar xzf gdbm-1.23.tar.gz
    cd gdbm-1.23
    CC=musl-clang CFLAGS="-fPIC" ./configure --prefix="${INSTALL_PREFIX}" --enable-static --disable-shared --enable-libgdbm-compat
    make -j$(nproc)
    sudo make install
    cd ..
    rm -rf gdbm-1.23 gdbm-1.23.tar.gz
fi

echo "=== All musl dependencies built successfully ==="
