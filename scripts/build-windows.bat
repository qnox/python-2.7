@echo off
REM Python 2.7 portable build script for Windows
REM Supports x86_64 and x86 with MSVC
REM Based on python-build-standalone architecture

setlocal enabledelayedexpansion

set PYTHON_VERSION=2.7.18
set BUILD_DIR=%CD%\build
set SOURCE_DIR=%CD%\Python-%PYTHON_VERSION%

echo ========================================
echo === Building Python %PYTHON_VERSION% ===
echo ========================================
echo Target: %TARGET_TRIPLE%
echo Architecture: %TARGET_ARCH%
echo Build Directory: %BUILD_DIR%
echo ========================================
echo.

REM Download Python source if not present
if not exist "%SOURCE_DIR%" (
    echo [1/6] Downloading Python source...
    curl -LO "https://www.python.org/ftp/python/%PYTHON_VERSION%/Python-%PYTHON_VERSION%.tgz"
    if errorlevel 1 (
        echo ERROR: Failed to download Python source
        exit /b 1
    )
    echo [1/6] Extracting Python source...
    tar xzf "Python-%PYTHON_VERSION%.tgz"
    if errorlevel 1 (
        echo ERROR: Failed to extract Python source
        exit /b 1
    )
    del "Python-%PYTHON_VERSION%.tgz"
    echo [1/6] Python source ready
) else (
    echo [1/6] Using existing Python source
)

echo.
echo [2/6] Applying patches for VS2022 compatibility...

REM Check if Git patch utility is available
if not exist "C:\Program Files\Git\usr\bin\patch.exe" (
    echo ERROR: Git patch utility not found at "C:\Program Files\Git\usr\bin\patch.exe"
    echo Please install Git for Windows or ensure patch.exe is in PATH
    exit /b 1
)

set PATCH_EXE="C:\Program Files\Git\usr\bin\patch.exe"

REM Check if patches exist
if not exist "patches\windows\01-upgrade-vs2022-toolset.patch" (
    echo ERROR: Patch file 01-upgrade-vs2022-toolset.patch not found!
    dir patches\windows\
    exit /b 1
)

REM Apply VS2022 toolset upgrade patch
echo [2/6] Applying VS2022 toolset upgrade patch...
%PATCH_EXE% -d "%SOURCE_DIR%" -p1 -N --binary < patches\windows\01-upgrade-vs2022-toolset.patch
if errorlevel 1 (
    echo ERROR: Failed to apply VS2022 toolset patch
    exit /b 1
)

REM Apply timemodule.c fix for modern MSVC
if exist "patches\windows\02-fix-timemodule-msvc.patch" (
    echo [2/6] Applying timemodule.c fix for modern MSVC...
    %PATCH_EXE% -d "%SOURCE_DIR%" -p0 -N --binary < patches\windows\02-fix-timemodule-msvc.patch
    if errorlevel 1 (
        echo ERROR: Failed to apply timemodule.c patch
        exit /b 1
    )
)

REM Apply posixmodule.c fix for modern MSVC
if exist "patches\windows\03-fix-posixmodule-msvc.patch" (
    echo [2/6] Applying posixmodule.c fix for modern MSVC...
    %PATCH_EXE% -d "%SOURCE_DIR%" -p0 -N --binary < patches\windows\03-fix-posixmodule-msvc.patch
    if errorlevel 1 (
        echo ERROR: Failed to apply posixmodule.c patch
        exit /b 1
    )
)

echo [2/6] Patches applied successfully

echo.
echo [3/6] Configuring build environment...
cd "%SOURCE_DIR%\PCbuild"

REM Set architecture based on TARGET_ARCH
if "%TARGET_ARCH%"=="x86_64" (
    set PLATFORM=x64
    set ARCH_DIR=amd64
    echo [3/6] Architecture: x64 ^(amd64^)
) else if "%TARGET_ARCH%"=="aarch64" (
    set PLATFORM=ARM64
    set ARCH_DIR=arm64
    echo [3/6] Architecture: ARM64 ^(aarch64^)
) else if "%TARGET_ARCH%"=="x86" (
    set PLATFORM=Win32
    set ARCH_DIR=win32
    echo [3/6] Architecture: Win32 ^(x86^)
) else (
    echo ERROR: Unknown architecture: %TARGET_ARCH%
    echo Supported architectures: x86_64, aarch64, x86
    exit /b 1
)

REM Verify MSVC environment is set up
if not defined VSINSTALLDIR (
    echo ERROR: MSVC environment not set up
    echo Please ensure ilammy/msvc-dev-cmd@v1 was run in GitHub Actions
    echo Or run vcvarsall.bat manually
    exit /b 1
)
echo [3/6] MSVC Environment: %VSINSTALLDIR%

REM Build external dependencies
echo.
echo [4/6] Building external dependencies...
echo This may take several minutes...
call "%SOURCE_DIR%\PCbuild\build.bat" -e -p %PLATFORM%
if errorlevel 1 (
    echo ERROR: Failed to build external dependencies
    exit /b 1
)
echo [4/6] External dependencies built successfully

REM Build Python with Release configuration
echo.
echo [5/6] Building Python %PYTHON_VERSION% ^(Release configuration^)...
echo This may take several minutes...
call "%SOURCE_DIR%\PCbuild\build.bat" -p %PLATFORM% -c Release
if errorlevel 1 (
    echo ERROR: Failed to build Python
    exit /b 1
)
echo [5/6] Python built successfully

echo.
echo ========================================
echo === Verifying Build Output ===
echo ========================================
if not exist "%ARCH_DIR%\python.exe" (
    echo ERROR: python.exe not found in %ARCH_DIR%
    echo Build may have failed or files are in a different location
    echo Directory contents:
    dir /b
    exit /b 1
)
if not exist "%ARCH_DIR%\python27.dll" (
    echo ERROR: python27.dll not found in %ARCH_DIR%
    exit /b 1
)
echo Build verification: OK
echo Python executable: %ARCH_DIR%\python.exe
echo Python DLL: %ARCH_DIR%\python27.dll

REM Prepare portable installation directory
echo.
echo ========================================
echo === Creating Portable Distribution ===
echo ========================================
set PORTABLE_DIR=%BUILD_DIR%\python-%PYTHON_VERSION%-%TARGET_TRIPLE%
if exist "%PORTABLE_DIR%" (
    echo Removing existing portable directory...
    rmdir /s /q "%PORTABLE_DIR%"
)
mkdir "%PORTABLE_DIR%"
echo Portable directory: %PORTABLE_DIR%

echo.
echo Copying Python executables and DLLs...
xcopy /Y /I "%ARCH_DIR%\python.exe" "%PORTABLE_DIR%\" >nul
if errorlevel 1 (
    echo ERROR: Failed to copy python.exe
    exit /b 1
)
xcopy /Y /I "%ARCH_DIR%\pythonw.exe" "%PORTABLE_DIR%\" >nul
xcopy /Y /I "%ARCH_DIR%\python27.dll" "%PORTABLE_DIR%\" >nul
if errorlevel 1 (
    echo ERROR: Failed to copy python27.dll
    exit /b 1
)

echo Copying Python extension modules ^(.pyd files^)...
if not exist "%PORTABLE_DIR%\DLLs" mkdir "%PORTABLE_DIR%\DLLs"
xcopy /Y /I "%ARCH_DIR%\*.pyd" "%PORTABLE_DIR%\DLLs\" >nul
if errorlevel 1 (
    echo WARNING: Some .pyd files may not have been copied
)

echo Copying standard library...
xcopy /E /I /Y "..\..\Lib\*" "%PORTABLE_DIR%\Lib\" >nul
if errorlevel 1 (
    echo ERROR: Failed to copy standard library
    exit /b 1
)

echo Copying development headers...
xcopy /E /I /Y "..\..\Include\*" "%PORTABLE_DIR%\include\" >nul
xcopy /Y /I "..\..\PC\pyconfig.h" "%PORTABLE_DIR%\include\" >nul
if errorlevel 1 (
    echo ERROR: Failed to copy development headers
    exit /b 1
)

echo Copying import libraries for C extension development...
if not exist "%PORTABLE_DIR%\libs" mkdir "%PORTABLE_DIR%\libs"
xcopy /Y /I "%ARCH_DIR%\python27.lib" "%PORTABLE_DIR%\libs\" >nul
if errorlevel 1 (
    echo ERROR: Failed to copy python27.lib
    exit /b 1
)

echo.
echo Creating portable launcher script...
(
echo @echo off
echo REM Portable Python launcher for Windows
echo REM Automatically sets up environment variables
echo setlocal
echo set PYTHON_HOME=%%~dp0
echo set PATH=%%PYTHON_HOME%%;%%PYTHON_HOME%%\DLLs;%%PATH%%
echo set PYTHONHOME=%%PYTHON_HOME%%
echo "%%PYTHON_HOME%%\python.exe" %%*
echo endlocal
) > "%PORTABLE_DIR%\python-portable.bat"

echo Creating README.txt...
(
echo Python %PYTHON_VERSION% Portable Build for Windows
echo ========================================
echo.
echo Target: %TARGET_TRIPLE%
echo Architecture: %TARGET_ARCH%
echo.
echo This is a portable Python installation that can be placed in any directory.
echo.
echo USAGE
echo -----
echo 1. Extract this archive to any location
echo 2. Use python-portable.bat to run Python with correct paths:
echo    python-portable.bat --version
echo    python-portable.bat script.py
echo.
echo 3. Or set environment variables manually:
echo    set PYTHONHOME=^<path-to-this-directory^>
echo    set PATH=%%PYTHONHOME%%;%%PYTHONHOME%%\DLLs;%%PATH%%
echo    python.exe
echo.
echo FEATURES
echo --------
echo - Relocatable installation - works from any directory
echo - All DLLs included - no external dependencies
echo - Complete standard library included
echo - Full development headers included
echo - Import libraries for C extension development
echo - Built with modern MSVC v143 ^(Visual Studio 2022^)
echo.
echo DIRECTORY STRUCTURE
echo -------------------
echo python.exe, pythonw.exe    - Python executables
echo python27.dll               - Python runtime library
echo DLLs/                      - Python extension modules ^(.pyd files^)
echo Lib/                       - Python standard library
echo include/                   - C/C++ headers for extension development
echo libs/                      - Import libraries for linking
echo python-portable.bat        - Portable launcher script
echo.
echo BUILD INFO
echo ----------
echo Version: %PYTHON_VERSION%
echo Target: %TARGET_TRIPLE%
echo Architecture: %TARGET_ARCH%
echo Compiler: MSVC v143 ^(Visual Studio 2022^)
echo Built: %DATE% %TIME%
echo.
echo For more information, visit:
echo https://github.com/yourusername/python-2.7
) > "%PORTABLE_DIR%\README.txt"

echo.
echo ========================================
echo === BUILD COMPLETED SUCCESSFULLY ===
echo ========================================
echo.
echo Python Version: %PYTHON_VERSION%
echo Target Triple: %TARGET_TRIPLE%
echo Architecture: %TARGET_ARCH%
echo Portable Location: %PORTABLE_DIR%
echo.
echo Next steps:
echo 1. Run: scripts\package.bat    ^(to create distributable archive^)
echo 2. Run: scripts\test.bat       ^(to test the build^)
echo.

endlocal
