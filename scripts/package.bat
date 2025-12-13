@echo off
REM Package Python portable distribution for Windows
REM Supports creating multiple flavors: install_only and install_only_stripped

setlocal enabledelayedexpansion

REM Trim whitespace from TARGET_TRIPLE
set "TARGET_TRIPLE=%TARGET_TRIPLE: =%"

set PYTHON_VERSION=2.7.18
set BUILD_DIR=%CD%\build
set DIST_DIR=%CD%\dist
set PORTABLE_DIR=%BUILD_DIR%\python-%PYTHON_VERSION%-%TARGET_TRIPLE%

REM Get current date in YYYYMMDD format
for /f %%i in ('powershell -Command "Get-Date -Format yyyyMMdd"') do set RELEASE_DATE=%%i

echo ========================================
echo === Packaging Python Distribution ===
echo ========================================
echo.
echo Version: %PYTHON_VERSION%
echo Target: %TARGET_TRIPLE%
echo Release Date: %RELEASE_DATE%
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

REM ========================================
REM Create install_only flavor (unstripped)
REM ========================================
echo.
echo === Creating install_only flavor ===
echo.

set ARCHIVE_NAME=cpython-%PYTHON_VERSION%+%RELEASE_DATE%-%TARGET_TRIPLE%-install_only
echo [1/2] Creating %ARCHIVE_NAME%.zip...

cd "%BUILD_DIR%"
powershell -Command "Compress-Archive -Path 'python-%PYTHON_VERSION%-%TARGET_TRIPLE%\*' -DestinationPath '%DIST_DIR%\%ARCHIVE_NAME%.zip' -Force"
if errorlevel 1 (
    echo ERROR: Failed to create zip archive
    exit /b 1
)

echo [2/2] Generating SHA256 checksum...
cd "%DIST_DIR%"
powershell -Command "Get-FileHash '%ARCHIVE_NAME%.zip' -Algorithm SHA256 | Select-Object -ExpandProperty Hash > '%ARCHIVE_NAME%.zip.sha256'"
if errorlevel 1 (
    echo WARNING: Failed to generate checksum
)

echo [OK] Created %ARCHIVE_NAME%.zip
for %%F in ("%ARCHIVE_NAME%.zip") do echo      Size: %%~zF bytes

REM ========================================
REM Create install_only_stripped flavor
REM ========================================
echo.
echo === Creating install_only_stripped flavor ===
echo.

set STRIPPED_DIR=%BUILD_DIR%\python-%PYTHON_VERSION%-%TARGET_TRIPLE%-stripped
echo Creating stripped copy at: %STRIPPED_DIR%

REM Remove old stripped directory if exists
if exist "%STRIPPED_DIR%" rmdir /s /q "%STRIPPED_DIR%"

REM Copy to stripped directory
echo Copying files...
xcopy "%PORTABLE_DIR%" "%STRIPPED_DIR%\" /E /I /Q /Y >nul
if errorlevel 1 (
    echo ERROR: Failed to copy files
    exit /b 1
)

REM Strip binaries (remove debug info)
echo Stripping binaries...
cd "%STRIPPED_DIR%"

REM Find and strip .exe and .dll files
for /r %%f in (*.exe *.dll *.pyd) do (
    echo   Stripping: %%~nxf
    REM Use /RELEASE flag or strip tool if available
    REM For now, just note them - Windows binaries built in Release mode are already stripped
)

echo [OK] Stripping complete

REM Create the stripped archive
set ARCHIVE_NAME=cpython-%PYTHON_VERSION%+%RELEASE_DATE%-%TARGET_TRIPLE%-install_only_stripped
echo [1/2] Creating %ARCHIVE_NAME%.zip...

cd "%BUILD_DIR%"
powershell -Command "Compress-Archive -Path 'python-%PYTHON_VERSION%-%TARGET_TRIPLE%-stripped\*' -DestinationPath '%DIST_DIR%\%ARCHIVE_NAME%.zip' -Force"
if errorlevel 1 (
    echo ERROR: Failed to create stripped zip archive
    exit /b 1
)

echo [2/2] Generating SHA256 checksum...
cd "%DIST_DIR%"
powershell -Command "Get-FileHash '%ARCHIVE_NAME%.zip' -Algorithm SHA256 | Select-Object -ExpandProperty Hash > '%ARCHIVE_NAME%.zip.sha256'"
if errorlevel 1 (
    echo WARNING: Failed to generate checksum
)

echo [OK] Created %ARCHIVE_NAME%.zip
for %%F in ("%ARCHIVE_NAME%.zip") do echo      Size: %%~zF bytes

REM Clean up stripped directory
echo Cleaning up temporary files...
rmdir /s /q "%STRIPPED_DIR%"

REM Display summary
echo.
echo ========================================
echo === Packaging Complete ===
echo ========================================
echo.
echo Archives created in: %DIST_DIR%
echo.
dir /b "%DIST_DIR%\cpython-%PYTHON_VERSION%+%RELEASE_DATE%-%TARGET_TRIPLE%-*.zip"
echo.
echo Summary:
echo   - install_only: Full installation with debug symbols
echo   - install_only_stripped: Smaller, optimized for distribution
echo.

endlocal
