@echo off
REM Build OpenSSL for Windows ARM64 using Perl Configure
REM Based on python-build-standalone approach
setlocal enabledelayedexpansion

REM OpenSSL 1.1.1 is the first version with proper ARM64 Windows support
REM Using 1.1.1w (final 1.1.1 release with LTS support until 2023-09-11)
set OPENSSL_VERSION=1.1.1w

REM Get absolute paths - %~dp0 is the directory of this script
set SCRIPT_DIR=%~dp0
REM Go up two levels from scripts\deps\ to project root
for %%I in ("%SCRIPT_DIR%..\..") do set PROJECT_ROOT=%%~fI
set BUILD_DIR=%PROJECT_ROOT%\build\openssl-arm64
set INSTALL_DIR=%PROJECT_ROOT%\build\openssl-arm64-install
set SOURCE_DIR=%BUILD_DIR%\openssl-%OPENSSL_VERSION%

echo Building OpenSSL %OPENSSL_VERSION% for ARM64...
echo Project root: %PROJECT_ROOT%
echo Build directory: %BUILD_DIR%

REM Create build directory
if not exist "%BUILD_DIR%" (
    echo Creating build directory: %BUILD_DIR%
    mkdir "%BUILD_DIR%"
)
cd /d "%BUILD_DIR%"
if errorlevel 1 (
    echo ERROR: Failed to change to build directory: %BUILD_DIR%
    exit /b 1
)

REM Use system-installed Strawberry Perl (required for OpenSSL Configure)
REM Git Bash Perl uses MSYS paths which OpenSSL Configure doesn't support
REM Check for system-installed Strawberry Perl first, fall back to portable download
set SYSTEM_PERL=C:\Strawberry\perl\bin\perl.exe
if exist "%SYSTEM_PERL%" (
    set PERL_EXE=%SYSTEM_PERL%
    echo Using system-installed Strawberry Perl: %PERL_EXE%
) else (
    REM Fall back to portable version
    set PERL_VERSION=5.38.2.2
    set PERL_RELEASE=SP_53822_64bit
    set PERL_ZIP=strawberry-perl-%PERL_VERSION%-64bit-portable.zip
    set PERL_DIR=%BUILD_DIR%\strawberry-perl
    set PERL_EXE=%PERL_DIR%\perl\bin\perl.exe

    if not exist "%PERL_EXE%" (
        echo Downloading Strawberry Perl portable %PERL_VERSION%...
        curl -LO "https://github.com/StrawberryPerl/Perl-Dist-Strawberry/releases/download/%PERL_RELEASE%/%PERL_ZIP%"
        if errorlevel 1 (
            echo ERROR: Failed to download Strawberry Perl
            exit /b 1
        )

        echo Extracting Strawberry Perl...
        powershell -Command "Expand-Archive -Path '%PERL_ZIP%' -DestinationPath '%PERL_DIR%' -Force"
        if errorlevel 1 (
            echo ERROR: Failed to extract Strawberry Perl
            exit /b 1
        )
        echo Strawberry Perl ready
    )
    echo Using portable Strawberry Perl: %PERL_EXE%
)

REM Download OpenSSL if not present
if not exist "openssl-%OPENSSL_VERSION%.tar.gz" (
    echo Downloading OpenSSL %OPENSSL_VERSION%...
    curl -LO https://www.openssl.org/source/openssl-%OPENSSL_VERSION%.tar.gz
    if errorlevel 1 (
        echo ERROR: Failed to download OpenSSL
        exit /b 1
    )
)

REM Extract OpenSSL
if not exist "%SOURCE_DIR%" (
    echo Extracting OpenSSL...
    tar -xzf openssl-%OPENSSL_VERSION%.tar.gz
    if errorlevel 1 (
        echo ERROR: Failed to extract OpenSSL
        exit /b 1
    )
)

cd /d "%SOURCE_DIR%"

REM Check if OpenSSL is already built
if exist "%SOURCE_DIR%\libcrypto.lib" (
    if exist "%SOURCE_DIR%\libssl.lib" (
        echo OpenSSL already built, skipping build
        echo Build directory: %SOURCE_DIR%
        exit /b 0
    )
)

REM The MSVC environment should already be set up by the main build script
REM Just verify the PATH has the correct tools
echo Current PATH: %PATH%
where nmake cl 2>nul
if errorlevel 1 (
    echo ERROR: MSVC tools not found in PATH
    echo Please ensure vcvarsall.bat arm64 was called before running this script
    exit /b 1
)

REM Configure OpenSSL for ARM64 using Perl
REM VC-WIN64-ARM is the configuration for Windows ARM64
REM no-asm: Disable assembly optimizations (use C-only implementations)
REM no-shared: Build static libraries only
REM no-idea, no-mdc2: Disable patented algorithms
REM --prefix: Installation prefix
REM --debug: Build without optimization to avoid PDB issues
echo Configuring OpenSSL for ARM64...
"%PERL_EXE%" Configure VC-WIN64-ARM no-asm no-shared no-idea no-mdc2 --prefix=%INSTALL_DIR% --debug
if errorlevel 1 (
    echo ERROR: Failed to configure OpenSSL
    exit /b 1
)

REM Modify makefile to remove /Zi flag to avoid PDB issues
echo Removing debug symbols flag to avoid PDB API errors...
powershell -Command "(Get-Content makefile) -replace '/Zi ', '' | Set-Content makefile"
powershell -Command "(Get-Content makefile) -replace '/Fd\S+', '' | Set-Content makefile"

REM Build OpenSSL using nmake (OpenSSL 1.1.1 uses modern build system)
echo Building OpenSSL...
nmake
if errorlevel 1 (
    echo ERROR: Failed to build OpenSSL
    exit /b 1
)

REM Verify libraries were built
if not exist "%SOURCE_DIR%\libcrypto.lib" (
    echo ERROR: libcrypto.lib not found after build
    exit /b 1
)
if not exist "%SOURCE_DIR%\libssl.lib" (
    echo ERROR: libssl.lib not found after build
    exit /b 1
)

echo OpenSSL built successfully for ARM64
echo Build directory: %SOURCE_DIR%
exit /b 0
