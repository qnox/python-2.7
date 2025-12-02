@echo off
REM Package Python portable distribution for Windows

setlocal enabledelayedexpansion

set PYTHON_VERSION=2.7.18
set BUILD_DIR=%CD%\build
set DIST_DIR=%CD%\dist
set PORTABLE_DIR=%BUILD_DIR%\python-%PYTHON_VERSION%-%TARGET_TRIPLE%

echo === Packaging Python %PYTHON_VERSION% for %TARGET_TRIPLE% ===

REM Create dist directory
if not exist "%DIST_DIR%" mkdir "%DIST_DIR%"

REM Create archive name
set ARCHIVE_NAME=python-%PYTHON_VERSION%-%TARGET_TRIPLE%-portable

REM Package as zip
echo Creating %ARCHIVE_NAME%.zip...
cd "%BUILD_DIR%"
powershell -Command "Compress-Archive -Path 'python-%PYTHON_VERSION%-%TARGET_TRIPLE%' -DestinationPath '%DIST_DIR%\%ARCHIVE_NAME%.zip' -Force"

REM Generate checksum
cd "%DIST_DIR%"
powershell -Command "Get-FileHash '%ARCHIVE_NAME%.zip' -Algorithm SHA256 | Select-Object -ExpandProperty Hash > '%ARCHIVE_NAME%.zip.sha256'"

echo === Packaging complete ===
echo Archive created in: %DIST_DIR%
dir "%DIST_DIR%"

endlocal
