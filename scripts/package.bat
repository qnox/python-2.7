@echo off
REM Package Python portable distribution for Windows

setlocal enabledelayedexpansion

set PYTHON_VERSION=2.7.18
set BUILD_DIR=%CD%\build
set DIST_DIR=%CD%\dist
set PORTABLE_DIR=%BUILD_DIR%\python-%PYTHON_VERSION%-%TARGET_TRIPLE%

echo ========================================
echo === Packaging Python Distribution ===
echo ========================================
echo.
echo Version: %PYTHON_VERSION%
echo Target: %TARGET_TRIPLE%
echo Source: %PORTABLE_DIR%
echo.

REM Verify portable directory exists
if not exist "%PORTABLE_DIR%" (
    echo ERROR: Portable directory not found: %PORTABLE_DIR%
    echo Please run build-windows.bat first
    exit /b 1
)

REM Create dist directory
if not exist "%DIST_DIR%" mkdir "%DIST_DIR%"

REM Create archive name
set ARCHIVE_NAME=python-%PYTHON_VERSION%-%TARGET_TRIPLE%-portable

REM Package as zip
echo [1/3] Creating %ARCHIVE_NAME%.zip...
cd "%BUILD_DIR%"
powershell -Command "Compress-Archive -Path 'python-%PYTHON_VERSION%-%TARGET_TRIPLE%' -DestinationPath '%DIST_DIR%\%ARCHIVE_NAME%.zip' -Force"
if errorlevel 1 (
    echo ERROR: Failed to create zip archive
    exit /b 1
)
echo [1/3] Archive created successfully

REM Generate SHA256 checksum
echo [2/3] Generating SHA256 checksum...
cd "%DIST_DIR%"
powershell -Command "Get-FileHash '%ARCHIVE_NAME%.zip' -Algorithm SHA256 | Select-Object -ExpandProperty Hash > '%ARCHIVE_NAME%.zip.sha256'"
if errorlevel 1 (
    echo ERROR: Failed to generate checksum
    exit /b 1
)
echo [2/3] Checksum generated

REM Display results
echo.
echo [3/3] Package complete!
echo.
echo ========================================
echo === Package Summary ===
echo ========================================
for %%F in ("%ARCHIVE_NAME%.zip") do (
    echo Archive: %%~nxF
    echo Size: %%~zF bytes
)
echo Location: %DIST_DIR%
echo.
echo Files created:
dir /b "%DIST_DIR%\%ARCHIVE_NAME%.*"
echo.
echo Checksum:
type "%ARCHIVE_NAME%.zip.sha256"
echo.

endlocal
