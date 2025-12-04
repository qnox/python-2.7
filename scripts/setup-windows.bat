@echo off
REM Setup Windows build environment for Python 2.7
REM MSVC environment is set up separately via GitHub Actions

setlocal enabledelayedexpansion

set PYTHON_VERSION=2.7.18

echo ========================================
echo === Windows Build Environment Setup ===
echo ========================================
echo.

REM Display environment variables
echo Target Architecture: %TARGET_ARCH%
echo Target Triple: %TARGET_TRIPLE%
echo Target Platform: %TARGET_PLATFORM%
echo.

REM Verify MSVC environment
where cl.exe >nul 2>&1
if errorlevel 1 (
    echo WARNING: MSVC compiler not found in PATH
    echo This is expected if running locally - will be set up via GitHub Actions
) else (
    echo MSVC Environment: Configured
    for /f "delims=" %%i in ('where cl.exe') do echo MSVC Compiler: %%i
)

REM Verify required tools
echo.
echo Checking for required build tools...

where cl.exe >nul 2>&1
if errorlevel 1 (
    echo WARNING: MSVC compiler ^(cl.exe^) not found in PATH
) else (
    echo [OK] MSVC compiler found
)

where msbuild.exe >nul 2>&1
if errorlevel 1 (
    echo WARNING: MSBuild not found in PATH
) else (
    echo [OK] MSBuild found
)

where curl.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: curl not found - required for downloading Python source
    exit /b 1
) else (
    echo [OK] curl found
)

where tar.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: tar not found - required for extracting Python source
    exit /b 1
) else (
    echo [OK] tar found
)

if exist "C:\Program Files\Git\usr\bin\patch.exe" (
    echo [OK] Git patch utility found
) else (
    echo ERROR: Git patch utility not found
    echo Please install Git for Windows
    exit /b 1
)

where powershell.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: PowerShell not found - required for build scripts
    exit /b 1
) else (
    echo [OK] PowerShell found
)

echo.
echo ========================================
echo === Setup Complete ===
echo ========================================
echo.
echo Ready to build Python %PYTHON_VERSION% for %TARGET_TRIPLE%
echo Run: scripts\build-windows.bat
echo.

endlocal
