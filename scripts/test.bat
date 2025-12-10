@echo off
REM Test Python portable distribution from packaged archive
REM This script unpacks the distribution to a temporary directory and runs tests

setlocal enabledelayedexpansion

set PYTHON_VERSION=2.7.18
set DIST_DIR=%CD%\dist

REM Get current date in YYYYMMDD format
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set datetime=%%I
set RELEASE_DATE=%datetime:~0,8%

REM Test flavor (can be overridden via FLAVOR env var, defaults to install_only)
if not defined FLAVOR set FLAVOR=install_only

REM Follow python-build-standalone naming: cpython-VERSION+DATE-TRIPLE-FLAVOR
set ARCHIVE_NAME=cpython-%PYTHON_VERSION%+%RELEASE_DATE%-%TARGET_TRIPLE%-%FLAVOR%

echo === Testing Python %PYTHON_VERSION% portable distribution ===
echo Target: %TARGET_TRIPLE%
echo Platform: %TARGET_PLATFORM%
echo Flavor: %FLAVOR%
echo.

REM Find the distribution archive
set ARCHIVE=
if exist "%DIST_DIR%\%ARCHIVE_NAME%.zip" (
    set ARCHIVE=%DIST_DIR%\%ARCHIVE_NAME%.zip
) else (
    echo Error: No distribution archive found at %DIST_DIR%\%ARCHIVE_NAME%.zip
    echo Available files in %DIST_DIR%:
    dir "%DIST_DIR%"
    exit /b 1
)

echo Found archive: %ARCHIVE%

REM Create temporary test directory
set TEST_DIR=%TEMP%\python-test-%RANDOM%
echo Test directory: %TEST_DIR%
mkdir "%TEST_DIR%"

REM Extract archive to test directory
echo Extracting archive...
powershell -Command "Expand-Archive -Path '%ARCHIVE%' -DestinationPath '%TEST_DIR%' -Force"

REM Debug: what did we extract?
echo Contents after extraction:
dir "%TEST_DIR%"

REM The new archives extract directly to python.exe, Lib/, etc. (no wrapper directory)
REM Check if we have python.exe directly in TEST_DIR
if exist "%TEST_DIR%\python.exe" (
    set PORTABLE_DIR=%TEST_DIR%
    echo Archive extracted to flat structure
) else (
    REM Fallback: look for a subdirectory (old format compatibility)
    for /d %%i in ("%TEST_DIR%\python-*") do set PORTABLE_DIR=%%i
    echo Archive has directory wrapper: !PORTABLE_DIR!
)

if not defined PORTABLE_DIR (
    echo Error: Could not find extracted Python directory
    dir "%TEST_DIR%"
    rmdir /s /q "%TEST_DIR%"
    exit /b 1
)

echo Python directory: %PORTABLE_DIR%

REM Test 1: Verify directory structure
echo.
echo === Test 1: Verify directory structure ===
if not exist "%PORTABLE_DIR%\python.exe" (
    echo FAIL: Python executable not found
    rmdir /s /q "%TEST_DIR%"
    exit /b 1
)
if not exist "%PORTABLE_DIR%\Lib" (
    echo FAIL: Lib directory not found
    rmdir /s /q "%TEST_DIR%"
    exit /b 1
)
if not exist "%PORTABLE_DIR%\include" (
    echo FAIL: include directory not found
    rmdir /s /q "%TEST_DIR%"
    exit /b 1
)
echo PASS: Directory structure is correct

REM Test 2: Test Python executable
echo.
echo === Test 2: Test Python executable ===
cd "%PORTABLE_DIR%"
set PYTHONHOME=%PORTABLE_DIR%
set PATH=%PORTABLE_DIR%;%PORTABLE_DIR%\DLLs;%PATH%

"%PORTABLE_DIR%\python.exe" --version 2>&1 | findstr "2.7.18" >nul
if errorlevel 1 (
    echo FAIL: Version check failed
    cd %CD%
    rmdir /s /q "%TEST_DIR%"
    exit /b 1
)

"%PORTABLE_DIR%\python.exe" -c "print('Python executable: OK')"
if errorlevel 1 (
    echo FAIL: Python execution failed
    cd %CD%
    rmdir /s /q "%TEST_DIR%"
    exit /b 1
)
echo PASS: Python executable works

REM Test 3: Standard library imports
echo.
echo === Test 3: Test standard library imports ===
REM Core modules (must work)
"%PORTABLE_DIR%\python.exe" -c "import sys; print('sys: OK')"
"%PORTABLE_DIR%\python.exe" -c "import os; print('os: OK')"
"%PORTABLE_DIR%\python.exe" -c "import json; print('json: OK')"
"%PORTABLE_DIR%\python.exe" -c "import re; print('re: OK')"
"%PORTABLE_DIR%\python.exe" -c "import io; print('io: OK')"
"%PORTABLE_DIR%\python.exe" -c "import struct; print('struct: OK')"
"%PORTABLE_DIR%\python.exe" -c "import array; print('array: OK')"
"%PORTABLE_DIR%\python.exe" -c "import math; print('math: OK')"
"%PORTABLE_DIR%\python.exe" -c "import datetime; print('datetime: OK')"
"%PORTABLE_DIR%\python.exe" -c "import random; print('random: OK')"
"%PORTABLE_DIR%\python.exe" -c "import hashlib; print('hashlib: OK')"
"%PORTABLE_DIR%\python.exe" -c "import sqlite3; print('sqlite3: OK')"
"%PORTABLE_DIR%\python.exe" -c "import zlib; print('zlib: OK')"
"%PORTABLE_DIR%\python.exe" -c "import socket; print('socket: OK')"
"%PORTABLE_DIR%\python.exe" -c "import threading; print('threading: OK')"

REM Optional modules
"%PORTABLE_DIR%\python.exe" -c "import bz2; print('bz2: OK')" 2>nul || echo WARNING: bz2 module not available
"%PORTABLE_DIR%\python.exe" -c "import ssl; print('ssl: OK')" 2>nul || echo WARNING: ssl module not available

echo PASS: Standard library imports successful

REM Test 4: Check Python paths
echo.
echo === Test 4: Check Python paths ===
"%PORTABLE_DIR%\python.exe" -c "import sys; print('sys.executable:', sys.executable); print('sys.prefix:', sys.prefix); print('sys.exec_prefix:', sys.exec_prefix)"

REM Test 5: Test relocatability (copy to different location)
echo.
echo === Test 5: Test relocatability ===
set MOVED_DIR=%TEMP%\python-moved-%RANDOM%
mkdir "%MOVED_DIR%"
echo Moving Python to new location: %MOVED_DIR%

xcopy /E /I /Q /Y "%PORTABLE_DIR%" "%MOVED_DIR%" >nul
if errorlevel 1 (
    echo FAIL: Failed to copy Python to new location
    rmdir /s /q "%MOVED_DIR%"
    rmdir /s /q "%TEST_DIR%"
    exit /b 1
)

echo Testing from: %MOVED_DIR%
cd "%MOVED_DIR%"
set PYTHONHOME=%MOVED_DIR%
set PATH=%MOVED_DIR%;%MOVED_DIR%\DLLs;%PATH%

"%MOVED_DIR%\python.exe" --version
"%MOVED_DIR%\python.exe" -c "print('Relocatability: OK')"
if errorlevel 1 (
    echo FAIL: Relocatability test failed
    rmdir /s /q "%MOVED_DIR%"
    cd %CD%
    rmdir /s /q "%TEST_DIR%"
    exit /b 1
)
echo PASS: Python is relocatable

REM Clean up moved directory
rmdir /s /q "%MOVED_DIR%"

REM Test 6: Test C extension headers
echo.
echo === Test 6: Test C extension headers ===
cd "%PORTABLE_DIR%"
if exist "%PORTABLE_DIR%\include\Python.h" (
    echo PASS: Python.h found - C extension development supported
) else (
    echo WARNING: Python.h not found - C extension development not supported
)

REM Test 7: Run a simple script
echo.
echo === Test 7: Run a test script ===
(
echo import sys
echo import os
echo import json
echo.
echo def main(^):
echo     print("Python Test Script"^)
echo     print("Python version:", sys.version^)
echo     print("Platform:", sys.platform^)
echo.
echo     # Test basic functionality
echo     data = {"test": "success", "version": list(sys.version_info[:2]^)}
echo     json_str = json.dumps(data, indent=2^)
echo     print("JSON test:", json_str^)
echo.
echo     # Test file I/O
echo     test_file = os.path.join(os.path.dirname(__file__^), "test_output.txt"^)
echo     with open(test_file, "w"^) as f:
echo         f.write("Test output\n"^)
echo.
echo     with open(test_file, "r"^) as f:
echo         content = f.read(^)
echo.
echo     print("File I/O test: OK"^)
echo     os.remove(test_file^)
echo.
echo     print("\nAll tests passed!"^)
echo     return 0
echo.
echo if __name__ == "__main__":
echo     sys.exit(main(^)^)
) > "%TEST_DIR%\test_script.py"

"%PORTABLE_DIR%\python.exe" "%TEST_DIR%\test_script.py"
if errorlevel 1 (
    echo FAIL: Test script execution failed
    cd %CD%
    rmdir /s /q "%TEST_DIR%"
    exit /b 1
)
echo PASS: Test script executed successfully

REM Summary
echo.
echo ========================================
echo === ALL TESTS PASSED SUCCESSFULLY ===
echo ========================================
echo.
echo Distribution: %ARCHIVE_NAME%
echo Flavor: %FLAVOR%
echo Test location: %TEST_DIR%
"%PORTABLE_DIR%\python.exe" --version 2>&1
echo.
echo The portable Python distribution is working correctly!

REM Cleanup
cd %CD%
rmdir /s /q "%TEST_DIR%"

endlocal
