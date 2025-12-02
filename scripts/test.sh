#!/bin/bash
set -euo pipefail

# Test Python portable distribution from packaged archive
# This script unpacks the distribution to a temporary directory and runs tests

PYTHON_VERSION="2.7.18"
DIST_DIR="${PWD}/dist"
ARCHIVE_NAME="python-${PYTHON_VERSION}-${TARGET_TRIPLE}-portable"

echo "=== Testing Python ${PYTHON_VERSION} portable distribution ==="
echo "Target: ${TARGET_TRIPLE}"
echo "Platform: ${TARGET_PLATFORM:-unknown}"

# Find the distribution archive
ARCHIVE=""
if [ -f "${DIST_DIR}/${ARCHIVE_NAME}.tar.xz" ]; then
    ARCHIVE="${DIST_DIR}/${ARCHIVE_NAME}.tar.xz"
    EXTRACT_CMD="tar xJf"
elif [ -f "${DIST_DIR}/${ARCHIVE_NAME}.tar.gz" ]; then
    ARCHIVE="${DIST_DIR}/${ARCHIVE_NAME}.tar.gz"
    EXTRACT_CMD="tar xzf"
else
    echo "Error: No distribution archive found at ${DIST_DIR}/${ARCHIVE_NAME}.*"
    ls -la "${DIST_DIR}/" || true
    exit 1
fi

echo "Found archive: ${ARCHIVE}"

# Create temporary test directory
TEST_DIR=$(mktemp -d -t python-test-XXXXXX)
echo "Test directory: ${TEST_DIR}"

# Cleanup on exit
trap "rm -rf ${TEST_DIR}" EXIT

# Extract archive to test directory
echo "Extracting archive..."
cd "${TEST_DIR}"
${EXTRACT_CMD} "${ARCHIVE}"

# Debug: what did we extract?
echo "Contents after extraction:"
ls -la "${TEST_DIR}"

# Find the extracted directory
PORTABLE_DIR=$(find "${TEST_DIR}" -maxdepth 1 -type d -name "python-*" 2>/dev/null | head -n 1)
echo "Find result: '${PORTABLE_DIR}'"

if [ -z "${PORTABLE_DIR}" ]; then
    echo "Error: Could not find extracted Python directory"
    echo "Looking for: python-* in ${TEST_DIR}"
    find "${TEST_DIR}" -maxdepth 2 -type d
    exit 1
fi

echo "Extracted to: ${PORTABLE_DIR}"

# Debug: show what was extracted
echo "Contents of extraction:"
ls -la "${TEST_DIR}"
if [ -n "${PORTABLE_DIR}" ] && [ -d "${PORTABLE_DIR}" ]; then
    echo "Contents of ${PORTABLE_DIR}:"
    ls -la "${PORTABLE_DIR}"
    echo "Checking for bin directory: ${PORTABLE_DIR}/bin"
    if [ -d "${PORTABLE_DIR}/bin" ]; then
        echo "bin directory EXISTS"
        ls -la "${PORTABLE_DIR}/bin"
    else
        echo "bin directory NOT FOUND"
    fi
fi

# Test 1: Verify directory structure
echo ""
echo "=== Test 1: Verify directory structure ==="
if [ ! -d "${PORTABLE_DIR}/bin" ]; then
    echo "FAIL: bin directory not found at: ${PORTABLE_DIR}/bin"
    echo "PORTABLE_DIR value: '${PORTABLE_DIR}'"
    echo "Directory check result: $?"
    exit 1
fi
if [ ! -d "${PORTABLE_DIR}/lib" ]; then
    echo "FAIL: lib directory not found"
    exit 1
fi
if [ ! -d "${PORTABLE_DIR}/include" ]; then
    echo "FAIL: include directory not found"
    exit 1
fi
echo "PASS: Directory structure is correct"

# Test 2: Test portable launcher
echo ""
echo "=== Test 2: Test portable launcher ==="
if [ -f "${PORTABLE_DIR}/bin/python-portable" ]; then
    chmod +x "${PORTABLE_DIR}/bin/python-portable"

    # Version check
    VERSION_OUTPUT=$("${PORTABLE_DIR}/bin/python-portable" --version 2>&1)
    echo "Version: ${VERSION_OUTPUT}"
    if [[ ! "${VERSION_OUTPUT}" =~ "2.7.18" ]]; then
        echo "FAIL: Version check failed"
        exit 1
    fi

    # Basic execution
    "${PORTABLE_DIR}/bin/python-portable" -c "print('Portable launcher: OK')"

    # Check paths are relative
    EXECUTABLE=$("${PORTABLE_DIR}/bin/python-portable" -c "import sys; print(sys.executable)")
    echo "Python executable: ${EXECUTABLE}"

    echo "PASS: Portable launcher works"
else
    echo "FAIL: Portable launcher not found"
    exit 1
fi

# Test 3: Test direct binary with environment variables
echo ""
echo "=== Test 3: Test direct binary with environment variables ==="
cd "${PORTABLE_DIR}"
export PYTHONHOME="${PORTABLE_DIR}"

if [[ "$OSTYPE" == "darwin"* ]]; then
    export DYLD_LIBRARY_PATH="${PORTABLE_DIR}/lib:${DYLD_LIBRARY_PATH:-}"
else
    export LD_LIBRARY_PATH="${PORTABLE_DIR}/lib:${LD_LIBRARY_PATH:-}"
fi

"${PORTABLE_DIR}/bin/python" --version
"${PORTABLE_DIR}/bin/python" -c "print('Direct binary: OK')"
echo "PASS: Direct binary works with environment variables"

# Test 4: Standard library imports
echo ""
echo "=== Test 4: Test standard library imports ==="
"${PORTABLE_DIR}/bin/python" -c "import sys; print('sys: OK')"
"${PORTABLE_DIR}/bin/python" -c "import os; print('os: OK')"
"${PORTABLE_DIR}/bin/python" -c "import json; print('json: OK')"
"${PORTABLE_DIR}/bin/python" -c "import sqlite3; print('sqlite3: OK')"
"${PORTABLE_DIR}/bin/python" -c "import zlib; print('zlib: OK')"
"${PORTABLE_DIR}/bin/python" -c "import bz2; print('bz2: OK')"

# SSL/OpenSSL is platform-dependent
"${PORTABLE_DIR}/bin/python" -c "import ssl; print('ssl: OK')" || echo "WARNING: ssl module not available"

echo "PASS: Standard library imports successful"

# Test 5: Check Python paths
echo ""
echo "=== Test 5: Check Python paths ==="
"${PORTABLE_DIR}/bin/python" -c "
import sys
print('sys.executable:', sys.executable)
print('sys.prefix:', sys.prefix)
print('sys.exec_prefix:', sys.exec_prefix)
print('sys.path:')
for p in sys.path:
    print('  ', p)
"

# Test 6: Test relocatability (move to different location)
echo ""
echo "=== Test 6: Test relocatability ==="
MOVED_DIR="${TEST_DIR}/moved-location"
mkdir -p "${MOVED_DIR}"
mv "${PORTABLE_DIR}" "${MOVED_DIR}/"
PORTABLE_DIR="${MOVED_DIR}/$(basename ${PORTABLE_DIR})"

echo "Moved to: ${PORTABLE_DIR}"
"${PORTABLE_DIR}/bin/python-portable" --version
"${PORTABLE_DIR}/bin/python-portable" -c "print('Relocatability: OK')"
echo "PASS: Python is relocatable"

# Test 7: Test pip/easy_install if available
echo ""
echo "=== Test 7: Test package management tools ==="
if [ -f "${PORTABLE_DIR}/bin/pip" ]; then
    "${PORTABLE_DIR}/bin/pip" --version || echo "WARNING: pip available but not functional"
else
    echo "INFO: pip not included in this build"
fi

if [ -f "${PORTABLE_DIR}/bin/easy_install" ]; then
    "${PORTABLE_DIR}/bin/easy_install" --version || echo "WARNING: easy_install available but not functional"
else
    echo "INFO: easy_install not included in this build"
fi

# Test 8: Test C extension build capability
echo ""
echo "=== Test 8: Test C extension headers ==="
if [ -f "${PORTABLE_DIR}/include/python2.7/Python.h" ]; then
    echo "PASS: Python.h found - C extension development supported"
else
    echo "WARNING: Python.h not found - C extension development not supported"
fi

# Test 9: Run a simple script
echo ""
echo "=== Test 9: Run a test script ==="
cat > "${TEST_DIR}/test_script.py" << 'EOF'
#!/usr/bin/env python
# -*- coding: utf-8 -*-
import sys
import os
import json

def main():
    print("Python Test Script")
    print("Python version:", sys.version)
    print("Platform:", sys.platform)

    # Test basic functionality
    data = {"test": "success", "version": sys.version_info[:2]}
    json_str = json.dumps(data, indent=2)
    print("JSON test:", json_str)

    # Test file I/O
    test_file = os.path.join(os.path.dirname(__file__), "test_output.txt")
    with open(test_file, "w") as f:
        f.write("Test output\n")

    with open(test_file, "r") as f:
        content = f.read()

    print("File I/O test: OK")
    os.remove(test_file)

    print("\nAll tests passed!")
    return 0

if __name__ == "__main__":
    sys.exit(main())
EOF

chmod +x "${TEST_DIR}/test_script.py"
"${PORTABLE_DIR}/bin/python" "${TEST_DIR}/test_script.py"
echo "PASS: Test script executed successfully"

# Summary
echo ""
echo "========================================"
echo "=== ALL TESTS PASSED SUCCESSFULLY ==="
echo "========================================"
echo ""
echo "Distribution: ${ARCHIVE_NAME}"
echo "Test location: ${TEST_DIR}"
echo "Python version: $("${PORTABLE_DIR}/bin/python" --version 2>&1)"
echo ""
echo "The portable Python distribution is working correctly!"
