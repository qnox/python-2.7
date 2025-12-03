#!/usr/bin/env bash
# Build musl libc and create musl-clang wrapper
# Based on python-build-standalone approach

set -e

MUSL_VERSION="1.2.2"
MUSL_URL="https://musl.libc.org/releases/musl-${MUSL_VERSION}.tar.gz"
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"

echo "=== Building musl ${MUSL_VERSION} ==="

# Download musl
cd /tmp
if [ ! -f "musl-${MUSL_VERSION}.tar.gz" ]; then
    echo "Downloading musl ${MUSL_VERSION}..."
    curl -LO "${MUSL_URL}"
fi

# Extract
rm -rf "musl-${MUSL_VERSION}"
tar xzf "musl-${MUSL_VERSION}.tar.gz"
cd "musl-${MUSL_VERSION}"

# Apply compatibility patch to avoid newer symbol dependencies
# This removes reallocarray() which was added in musl 1.2.2
echo "Applying compatibility patch..."
patch -p1 <<'EOF'
diff --git a/include/stdlib.h b/include/stdlib.h
index b54a051f..194c2033 100644
--- a/include/stdlib.h
+++ b/include/stdlib.h
@@ -145,7 +145,6 @@ int getloadavg(double *, int);
 int clearenv(void);
 #define WCOREDUMP(s) ((s) & 0x80)
 #define WIFCONTINUED(s) ((s) == 0xffff)
-void *reallocarray (void *, size_t, size_t);
 #endif

 #ifdef _GNU_SOURCE
diff --git a/src/malloc/reallocarray.c b/src/malloc/reallocarray.c
deleted file mode 100644
index 4a6ebe46..00000000
--- a/src/malloc/reallocarray.c
+++ /dev/null
@@ -1,13 +0,0 @@
-#define _BSD_SOURCE
-#include <errno.h>
-#include <stdlib.h>
-
-void *reallocarray(void *ptr, size_t m, size_t n)
-{
-	if (n && m > -1 / n) {
-		errno = ENOMEM;
-		return 0;
-	}
-
-	return realloc(ptr, m * n);
-}
EOF

# Configure with clang
echo "Configuring musl..."
CC=clang CFLAGS="-fPIC" CPPFLAGS="-fPIC" ./configure \
    --prefix="${INSTALL_PREFIX}" \
    --enable-shared

# Build and install
echo "Building musl..."
make -j$(nproc)

echo "Installing musl to ${INSTALL_PREFIX}..."
sudo make install

echo "=== musl installation complete ==="
echo "musl-clang wrapper installed to ${INSTALL_PREFIX}/bin/musl-clang"
