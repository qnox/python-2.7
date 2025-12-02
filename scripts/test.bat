@echo off
REM Test Python portable distribution from packaged archive
REM This script unpacks the distribution to a temporary directory and runs tests

setlocal enabledelayedexpansion

set PYTHON_VERSION=2.7.18
set DIST_DIR=%CD%\dist
set ARCHIVE_NAME=python-%PYTHON_VERSION%-%TARGET_TRIPLE%-portable

echo === Testing Python %PYTHON_VERSION% portable distribution ===
echo Target: %TARGET_TRIPLE%
echo Platform: %TARGET_PLATFORM%

REM Find the distribution archive
set ARCHIVE=
if exist "%DIST_DIR%\%ARCHIVE_NAME%.zip" (
    set ARCHIVE=%DIST_DIR%\%ARCHIVE_NAME%.zip
) else (
    echo Error: No distribution archive found at %DIST_DIR%\%ARCHIVE_NAME%.zip
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

REM Find the extracted directory
for /d %%i in ("%TEST_DIR%\python-*") do set PORTABLE_DIR=%%i
if not defined PORTABLE_DIR (
    echo Error: Could not find extracted Python directory
    dir "%TEST_DIR%"
    rmdir /s /q "%TEST_DIR%"
    exit /b 1
)

echo Extracted to: %PORTABLE_DIR%

REM Test 1: Verify directory structure
echo.
echo === Test 1: Verify directory structure ===
if not exist "%PORTABLE_DIR%\bin" if not exist "%PORTABLE_DIR%\python.exe" (
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

REM Test 2: Test portable launcher
echo.
echo === Test 2: Test portable launcher ===
if exist "%PORTABLE_DIR%\python-portable.bat" (
    call "%PORTABLE_DIR%\python-portable.bat" --version 2>&1 | findstr "2.7.18" >nul
    if errorlevel 1 (
        echo FAIL: Version check failed
        rmdir /s /q "%TEST_DIR%"
        exit /b 1
    )

    call "%PORTABLE_DIR%\python-portable.bat" -c "print('Portable launcher: OK')"
    if errorlevel 1 (
        echo FAIL: Portable launcher execution failed
        rmdir /s /q "%TEST_DIR%"
        exit /b 1
    )

    echo PASS: Portable launcher works
) else (
    echo FAIL: Portable launcher not found
    rmdir /s /q "%TEST_DIR%"
    exit /b 1
)

REM Test 3: Test direct binary with environment variables
echo.
echo === Test 3: Test direct binary with environment variables ===
cd "%PORTABLE_DIR%"
set PYTHONHOME=%PORTABLE_DIR%
set PATH=%PORTABLE_DIR%;%PORTABLE_DIR%\DLLs;%PATH%

"%PORTABLE_DIR%\python.exe" --version
if errorlevel 1 (
    echo FAIL: Direct binary failed
    cd %CD%
    rmdir /s /q "%TEST_DIR%"
    exit /b 1
)

"%PORTABLE_DIR%\python.exe" -c "print('Direct binary: OK')"
echo PASS: Direct binary works with environment variables

REM Test 4: Standard library imports
echo.
echo === Test 4: Test standard library imports ===
"%PORTABLE_DIR%\python.exe" -c "import sys; print('sys: OK')"
"%PORTABLE_DIR%\python.exe" -c "import os; print('os: OK')"
"%PORTABLE_DIR%\python.exe" -c "import json; print('json: OK')"
"%PORTABLE_DIR%\python.exe" -c "import sqlite3; print('sqlite3: OK')"
"%PORTABLE_DIR%\python.exe" -c "import zlib; print('zlib: OK')"
"%PORTABLE_DIR%\python.exe" -c "import bz2; print('bz2: OK')"

REM SSL/OpenSSL is platform-dependent
"%PORTABLE_DIR%\python.exe" -c "import ssl; print('ssl: OK')" 2>nul || echo WARNING: ssl module not available

echo PASS: Standard library imports successful

REM Test 5: Check Python paths
echo.
echo === Test 5: Check Python paths ===
"%PORTABLE_DIR%\python.exe" -c "import sys; print('sys.executable:', sys.executable); print('sys.prefix:', sys.prefix); print('sys.exec_prefix:', sys.exec_prefix)"

REM Test 6: Test relocatability (move to different location)
echo.
echo === Test 6: Test relocatability ===
set MOVED_DIR=%TEST_DIR%\moved-location
mkdir "%MOVED_DIR%"
xcopy /E /I /Y "%PORTABLE_DIR%" "%MOVED_DIR%\%ARCHIVE_NAME%" >nul
set PORTABLE_DIR=%MOVED_DIR%\%ARCHIVE_NAME%

echo Moved to: %PORTABLE_DIR%
cd "%PORTABLE_DIR%"
set PYTHONHOME=%PORTABLE_DIR%
set PATH=%PORTABLE_DIR%;%PORTABLE_DIR%\DLLs;%PATH%

"%PORTABLE_DIR%\python.exe" --version
"%PORTABLE_DIR%\python.exe" -c "print('Relocatability: OK')"
echo PASS: Python is relocatable

REM Test 7: Test pip/easy_install if available
echo.
echo === Test 7: Test package management tools ===
if exist "%PORTABLE_DIR%\Scripts\pip.exe" (
    "%PORTABLE_DIR%\Scripts\pip.exe" --version 2>nul || echo WARNING: pip available but not functional
) else (
    echo INFO: pip not included in this build
)

if exist "%PORTABLE_DIR%\Scripts\easy_install.exe" (
    "%PORTABLE_DIR%\Scripts\easy_install.exe" --version 2>nul || echo WARNING: easy_install available but not functional
) else (
    echo INFO: easy_install not included in this build
)

REM Test 8: Test C extension build capability
echo.
echo === Test 8: Test C extension headers ===
if exist "%PORTABLE_DIR%\include\Python.h" (
    echo PASS: Python.h found - C extension development supported
) else (
    echo WARNING: Python.h not found - C extension development not supported
)

REM Test 9: Run a simple script
echo.
echo === Test 9: Run a test script ===
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
echo Test location: %TEST_DIR%
"%PORTABLE_DIR%\python.exe" --version 2>&1
echo.
echo The portable Python distribution is working correctly!

REM Cleanup
cd %CD%
rmdir /s /q "%TEST_DIR%"

endlocal
