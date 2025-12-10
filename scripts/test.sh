#!/bin/bash
set -euo pipefail

# Test Python portable distribution from packaged archive
# This script unpacks the distribution to a temporary directory and runs tests

PYTHON_VERSION="2.7.18"
DIST_DIR="${PWD}/dist"

# Get current date in YYYYMMDD format (should match what package.sh created)
RELEASE_DATE=$(date +%Y%m%d)

# Test flavor (can be overridden via FLAVOR env var, defaults to install_only)
FLAVOR="${FLAVOR:-install_only}"

# Follow python-build-standalone naming: cpython-VERSION+DATE-TRIPLE-FLAVOR
ARCHIVE_NAME="cpython-${PYTHON_VERSION}+${RELEASE_DATE}-${TARGET_TRIPLE}-${FLAVOR}"

echo "=== Testing Python ${PYTHON_VERSION} portable distribution ==="
echo "Target: ${TARGET_TRIPLE}"
echo "Platform: ${TARGET_PLATFORM:-unknown}"
echo "Flavor: ${FLAVOR}"

# Find the distribution archive
ARCHIVE=""
if [ -f "${DIST_DIR}/${ARCHIVE_NAME}.tar.gz" ]; then
    ARCHIVE="${DIST_DIR}/${ARCHIVE_NAME}.tar.gz"
    EXTRACT_CMD="tar xzf"
else
    echo "Error: No distribution archive found at ${DIST_DIR}/${ARCHIVE_NAME}.tar.gz"
    echo "Available files in ${DIST_DIR}:"
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

# The new archives extract directly to bin/, lib/, etc. (no wrapper directory)
# Check if we have bin/ directly in TEST_DIR
if [ -d "${TEST_DIR}/bin" ]; then
    PORTABLE_DIR="${TEST_DIR}"
    echo "Archive extracted to flat structure"
else
    # Fallback: look for a subdirectory (old format compatibility)
    PORTABLE_DIR=$(find "${TEST_DIR}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -n 1)
    echo "Archive has directory wrapper: ${PORTABLE_DIR}"
fi

echo "Python directory: '${PORTABLE_DIR}'"

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

# Test 2: Test python binary
echo ""
echo "=== Test 2: Test python binary ==="
# Version check
echo "Running: ${PORTABLE_DIR}/bin/python --version"
VERSION_OUTPUT=$("${PORTABLE_DIR}/bin/python" --version 2>&1) || {
    EXIT_CODE=$?
    echo "ERROR: Python crashed with exit code ${EXIT_CODE}"
    echo "Output: ${VERSION_OUTPUT}"

    # Try running the binary directly to see library issues
    echo "Checking library dependencies:"
    if command -v otool >/dev/null 2>&1; then
        otool -L "${PORTABLE_DIR}/bin/python" || true
    elif command -v ldd >/dev/null 2>&1; then
        ldd "${PORTABLE_DIR}/bin/python" || true
    fi

    exit 1
}
echo "Version: ${VERSION_OUTPUT}"
if [[ ! "${VERSION_OUTPUT}" =~ "2.7.18" ]]; then
    echo "FAIL: Version check failed"
    exit 1
fi

# Basic execution
"${PORTABLE_DIR}/bin/python" -c "print('Python binary: OK')"

# Check paths are relative
EXECUTABLE=$("${PORTABLE_DIR}/bin/python" -c "import sys; print(sys.executable)")
echo "Python executable: ${EXECUTABLE}"

echo "PASS: Python binary works"

# Test 3: Test python2 symlink
echo ""
echo "=== Test 3: Test python2 symlink ==="
"${PORTABLE_DIR}/bin/python2" --version 2>&1
"${PORTABLE_DIR}/bin/python2" -c "print('python2 symlink: OK')"
echo "PASS: python2 symlink works"

# Test 4: Standard library imports
echo ""
echo "=== Test 4: Test standard library imports ==="
# Core modules (must work) - common across Unix/macOS/Windows
"${PORTABLE_DIR}/bin/python" -c "import sys; print('sys: OK')"
"${PORTABLE_DIR}/bin/python" -c "import os; print('os: OK')"
"${PORTABLE_DIR}/bin/python" -c "import json; print('json: OK')"
"${PORTABLE_DIR}/bin/python" -c "import re; print('re: OK')"
"${PORTABLE_DIR}/bin/python" -c "import io; print('io: OK')"
"${PORTABLE_DIR}/bin/python" -c "import struct; print('struct: OK')"
"${PORTABLE_DIR}/bin/python" -c "import array; print('array: OK')"
"${PORTABLE_DIR}/bin/python" -c "import math; print('math: OK')"
"${PORTABLE_DIR}/bin/python" -c "import cmath; print('cmath: OK')"
"${PORTABLE_DIR}/bin/python" -c "import itertools; print('itertools: OK')"
"${PORTABLE_DIR}/bin/python" -c "import functools; print('functools: OK')"
"${PORTABLE_DIR}/bin/python" -c "import collections; print('collections: OK')"
"${PORTABLE_DIR}/bin/python" -c "import datetime; print('datetime: OK')"
"${PORTABLE_DIR}/bin/python" -c "import time; print('time: OK')"
"${PORTABLE_DIR}/bin/python" -c "import random; print('random: OK')"
"${PORTABLE_DIR}/bin/python" -c "import hashlib; print('hashlib: OK')"
"${PORTABLE_DIR}/bin/python" -c "import binascii; print('binascii: OK')"
"${PORTABLE_DIR}/bin/python" -c "import base64; print('base64: OK')"
"${PORTABLE_DIR}/bin/python" -c "import pickle; print('pickle: OK')"
"${PORTABLE_DIR}/bin/python" -c "import csv; print('csv: OK')"
"${PORTABLE_DIR}/bin/python" -c "import xml.etree.ElementTree; print('xml.etree.ElementTree: OK')"
"${PORTABLE_DIR}/bin/python" -c "import sqlite3; print('sqlite3: OK')"
"${PORTABLE_DIR}/bin/python" -c "import zlib; print('zlib: OK')"
"${PORTABLE_DIR}/bin/python" -c "import gzip; print('gzip: OK')"
"${PORTABLE_DIR}/bin/python" -c "import zipfile; print('zipfile: OK')"
"${PORTABLE_DIR}/bin/python" -c "import tarfile; print('tarfile: OK')"
"${PORTABLE_DIR}/bin/python" -c "import socket; print('socket: OK')"
"${PORTABLE_DIR}/bin/python" -c "import select; print('select: OK')"
"${PORTABLE_DIR}/bin/python" -c "import threading; print('threading: OK')"
"${PORTABLE_DIR}/bin/python" -c "import subprocess; print('subprocess: OK')"
"${PORTABLE_DIR}/bin/python" -c "import unicodedata; print('unicodedata: OK')"
"${PORTABLE_DIR}/bin/python" -c "import codecs; print('codecs: OK')"
"${PORTABLE_DIR}/bin/python" -c "import locale; print('locale: OK')"
"${PORTABLE_DIR}/bin/python" -c "import tempfile; print('tempfile: OK')"
"${PORTABLE_DIR}/bin/python" -c "import shutil; print('shutil: OK')"
"${PORTABLE_DIR}/bin/python" -c "import glob; print('glob: OK')"
"${PORTABLE_DIR}/bin/python" -c "import fnmatch; print('fnmatch: OK')"
"${PORTABLE_DIR}/bin/python" -c "import logging; print('logging: OK')"
"${PORTABLE_DIR}/bin/python" -c "import traceback; print('traceback: OK')"
"${PORTABLE_DIR}/bin/python" -c "import errno; print('errno: OK')"
"${PORTABLE_DIR}/bin/python" -c "import signal; print('signal: OK')"

# C extension modules that should be available
"${PORTABLE_DIR}/bin/python" -c "import _collections; print('_collections: OK')"
"${PORTABLE_DIR}/bin/python" -c "import _functools; print('_functools: OK')"
"${PORTABLE_DIR}/bin/python" -c "import _random; print('_random: OK')"
"${PORTABLE_DIR}/bin/python" -c "import _socket; print('_socket: OK')"
"${PORTABLE_DIR}/bin/python" -c "import _struct; print('_struct: OK')"
"${PORTABLE_DIR}/bin/python" -c "import binascii; print('binascii: OK')"
"${PORTABLE_DIR}/bin/python" -c "import cPickle; print('cPickle: OK')"
"${PORTABLE_DIR}/bin/python" -c "import cStringIO; print('cStringIO: OK')"
"${PORTABLE_DIR}/bin/python" -c "import strop; print('strop: OK')"

# Optional modules (nice to have, but may not be available on all platforms)
"${PORTABLE_DIR}/bin/python" -c "import bz2; print('bz2: OK')" || echo "WARNING: bz2 module not available"
"${PORTABLE_DIR}/bin/python" -c "import ssl; print('ssl: OK')" || echo "WARNING: ssl module not available"
"${PORTABLE_DIR}/bin/python" -c "import readline; print('readline: OK')" || echo "WARNING: readline module not available"

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

# Create a new location outside TEST_DIR
MOVED_DIR=$(mktemp -d -t python-moved-XXXXXX)
echo "Moving Python to new location: ${MOVED_DIR}"

# Copy (not move) to preserve original for other tests
cp -R "${PORTABLE_DIR}/." "${MOVED_DIR}/"

# Test from the new location
echo "Testing from: ${MOVED_DIR}"
"${MOVED_DIR}/bin/python" --version
"${MOVED_DIR}/bin/python" -c "print('Relocatability: OK')"
echo "PASS: Python is relocatable"

# Clean up moved directory
rm -rf "${MOVED_DIR}"

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
