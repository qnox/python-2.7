@echo off
REM Test Python portable distribution from packaged archive
REM This script unpacks the distribution to a temporary directory and runs tests

setlocal enabledelayedexpansion

REM Trim whitespace from TARGET_TRIPLE and FLAVOR
set "TARGET_TRIPLE=%TARGET_TRIPLE: =%"

set PYTHON_VERSION=2.7.18
set DIST_DIR=%CD%\dist

REM Get current date in YYYYMMDD format
for /f %%i in ('powershell -Command "Get-Date -Format yyyyMMdd"') do set RELEASE_DATE=%%i

REM Test flavor (can be overridden via FLAVOR env var, defaults to install_only)
if not defined FLAVOR set FLAVOR=install_only
set "FLAVOR=%FLAVOR: =%"

REM Follow python-build-standalone naming: cpython-VERSION+DATE-TRIPLE-FLAVOR
set ARCHIVE_NAME=cpython-%PYTHON_VERSION%+%RELEASE_DATE%-%TARGET_TRIPLE%-%FLAVOR%

echo === Testing Python %PYTHON_VERSION% portable distribution ===
echo Target: %TARGET_TRIPLE%
echo Platform: %TARGET_PLATFORM%
echo Flavor: %FLAVOR%
echo.

REM Find the distribution archive
set ARCHIVE=
if exist "%DIST_DIR%\%ARCHIVE_NAME%.tar.gz" (
    set ARCHIVE=%DIST_DIR%\%ARCHIVE_NAME%.tar.gz
) else (
    echo Error: No distribution archive found at %DIST_DIR%\%ARCHIVE_NAME%.tar.gz
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
tar -xzf "%ARCHIVE%" -C "%TEST_DIR%"
if errorlevel 1 (
    echo ERROR: Failed to extract tar.gz archive
    echo Note: tar is required. Install Git for Windows or use Windows 10+
    rmdir /s /q "%TEST_DIR%"
    exit /b 1
)

REM Debug: what did we extract?
echo Contents after extraction:
dir "%TEST_DIR%"

REM Archives now extract to python/ subdirectory (python-build-standalone format)
if exist "%TEST_DIR%\python" (
    set PORTABLE_DIR=%TEST_DIR%\python
    echo Archive extracted with python/ prefix
) else if exist "%TEST_DIR%\python.exe" (
    REM Old format: extracted directly to python.exe, Lib/, etc.
    set PORTABLE_DIR=%TEST_DIR%
    echo Archive extracted to flat structure (old format)
) else if exist "%TEST_DIR%\bin\python.exe" (
    REM Old format: Windows install layout with bin/
    set PORTABLE_DIR=%TEST_DIR%
    echo Archive extracted with bin/ subdirectory (old format)
) else (
    REM Fallback: look for a subdirectory
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
echo Extracted to: %PORTABLE_DIR%

REM Run tests using Python test script
set SCRIPT_DIR=%~dp0
echo.
python "%SCRIPT_DIR%test_distribution.py" "%PORTABLE_DIR%"
set TEST_RESULT=%ERRORLEVEL%

REM Cleanup
rmdir /s /q "%TEST_DIR%"

exit /b %TEST_RESULT%

endlocal
