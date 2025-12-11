@echo off
REM Python 2.7 portable build script for Windows
REM Supports x86_64 and x86 with MSVC
REM Based on python-build-standalone architecture

setlocal enabledelayedexpansion

set PYTHON_VERSION=2.7.18
set BUILD_DIR=%CD%\build
set SOURCE_DIR=%CD%\Python-%PYTHON_VERSION%

REM Detect architecture if not set
if "%TARGET_ARCH%"=="" (
    if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
        set TARGET_ARCH=x86_64
        set TARGET_TRIPLE=x86_64-pc-windows-msvc
    ) else if "%PROCESSOR_ARCHITECTURE%"=="ARM64" (
        set TARGET_ARCH=aarch64
        set TARGET_TRIPLE=aarch64-pc-windows-msvc
    ) else if "%PROCESSOR_ARCHITECTURE%"=="x86" (
        set TARGET_ARCH=x86
        set TARGET_TRIPLE=i686-pc-windows-msvc
    ) else (
        echo ERROR: Could not detect architecture
        echo Please set TARGET_ARCH environment variable to: x86_64, aarch64, or x86
        exit /b 1
    )
    echo Auto-detected architecture: %TARGET_ARCH%
)

echo ========================================
echo === Building Python %PYTHON_VERSION% ===
echo ========================================
echo Target: %TARGET_TRIPLE%
echo Architecture: %TARGET_ARCH%
echo Build Directory: %BUILD_DIR%
echo ========================================
echo.

REM Always use fresh Python source to avoid patch conflicts
if exist "%SOURCE_DIR%" (
    echo [1/6] Removing existing Python source...
    rmdir /s /q "%SOURCE_DIR%"
)

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

echo.
echo [2/6] Applying patches...
call scripts\apply-patches.bat "%SOURCE_DIR%"
if errorlevel 1 (
    echo ERROR: Failed to apply patches via patch harness
    exit /b 1
)
echo [2/6] Patches applied successfully

echo.
echo [3/6] Configuring build environment...
echo Changing to directory: %SOURCE_DIR%\PCbuild
if not exist "%SOURCE_DIR%\PCbuild" (
    echo ERROR: PCbuild directory not found: %SOURCE_DIR%\PCbuild
    exit /b 1
)
cd "%SOURCE_DIR%\PCbuild"
if errorlevel 1 (
    echo ERROR: Failed to change to PCbuild directory
    exit /b 1
)
echo Current directory: %CD%

REM Normalize and validate TARGET_ARCH, and set defaults if necessary
REM Remove all spaces from TARGET_ARCH to avoid comparison issues
set "TARGET_ARCH=%TARGET_ARCH: =%"
REM Map common synonyms to our canonical names
if /I "%TARGET_ARCH%"=="amd64" set TARGET_ARCH=x86_64
if /I "%TARGET_ARCH%"=="x64" set TARGET_ARCH=x86_64
if /I "%TARGET_ARCH%"=="win32" set TARGET_ARCH=x86
if /I "%TARGET_ARCH%"=="arm64" set TARGET_ARCH=aarch64

REM Set architecture based on TARGET_ARCH
set ARCH_SET=
if /I "%TARGET_ARCH%"=="x86_64" (
    set PLATFORM=x64
    set ARCH_DIR=amd64
    set ARCH_SET=1
    echo [3/6] Architecture: x64 ^(amd64^)
)
if /I "%TARGET_ARCH%"=="aarch64" (
    set PLATFORM=ARM64
    set ARCH_DIR=arm64
    set ARCH_SET=1
    echo [3/6] Architecture: ARM64 ^(aarch64^)
)
if /I "%TARGET_ARCH%"=="x86" (
    set PLATFORM=Win32
    set ARCH_DIR=win32
    set ARCH_SET=1
    echo [3/6] Architecture: Win32 ^(x86^)
)
if not defined ARCH_SET (
    echo ERROR: Unknown architecture: %TARGET_ARCH%
    echo Supported architectures: x86_64, aarch64, x86
    exit /b 1
)

REM If TARGET_TRIPLE is not set, derive it from TARGET_ARCH
if "%TARGET_TRIPLE%"=="" (
    if "%TARGET_ARCH%"=="x86_64" set TARGET_TRIPLE=x86_64-pc-windows-msvc
    if "%TARGET_ARCH%"=="aarch64" set TARGET_TRIPLE=aarch64-pc-windows-msvc
    if "%TARGET_ARCH%"=="x86" set TARGET_TRIPLE=i686-pc-windows-msvc
)

REM Verify MSVC environment is set up
if not defined VSINSTALLDIR (
    echo ERROR: MSVC environment not set up
    echo Please ensure ilammy/msvc-dev-cmd@v1 was run in GitHub Actions
    echo Or run vcvarsall.bat manually
    exit /b 1
)
echo [3/6] MSVC Environment: %VSINSTALLDIR%

REM ARM64 project configurations are provided by a static patch: patches\windows\arm64\06-add-arm64-configs.patch

REM Download prebuilt Tcl/Tk binaries instead of building from source
REM This avoids compilation issues with modern Windows SDK
echo.
echo [4/6] Setting up prebuilt Tcl/Tk binaries...
REM Use Tcl/Tk 8.6.14 for ARM64 (has ARM64 binaries), 8.6.12 for x86/x64
if "%ARCH_DIR%"=="arm64" (
    set TCLTK_URL=https://github.com/python/cpython-bin-deps/archive/c624cc881bd0e5071dec9de4b120cbe9985d8c14.tar.gz
    set TCLTK_VERSION=8.6.14
) else (
    set TCLTK_URL=https://github.com/python/cpython-bin-deps/archive/e3c3e9a2856124aa32b608632a52742d479eb7a9.tar.gz
    set TCLTK_VERSION=8.6.12
)
set TCLTK_DIR=%SOURCE_DIR%\externals\tcltk
if "%ARCH_DIR%"=="amd64" set TCLTK_DIR=%SOURCE_DIR%\externals\tcltk64
if "%ARCH_DIR%"=="arm64" set TCLTK_DIR=%SOURCE_DIR%\externals\tcltk-arm64

REM Create externals directory if it doesn't exist
if not exist "%SOURCE_DIR%\externals" mkdir "%SOURCE_DIR%\externals"

REM ARM64 uses tcl86t.dll (threaded), others use tcl86.dll
set TCLTK_CHECK_DLL=tcl86.dll
if "%ARCH_DIR%"=="arm64" set TCLTK_CHECK_DLL=tcl86t.dll

if not exist "%TCLTK_DIR%\bin\%TCLTK_CHECK_DLL%" (
    echo Downloading prebuilt Tcl/Tk binaries...
    curl -L -o "%SOURCE_DIR%\externals\tcltk-bin.tar.gz" "%TCLTK_URL%"
    if errorlevel 1 (
        echo ERROR: Failed to download Tcl/Tk binaries
        exit /b 1
    )
    echo Extracting Tcl/Tk binaries...
    powershell -ExecutionPolicy Bypass -Command "cd '%SOURCE_DIR%\externals'; tar -xzf tcltk-bin.tar.gz"
    if errorlevel 1 (
        echo ERROR: Failed to extract Tcl/Tk binaries
        exit /b 1
    )
    REM Copy from extracted directory to expected location
    for /d %%D in ("%SOURCE_DIR%\externals\cpython-bin-deps-*") do (
        if exist "%%D\%ARCH_DIR%" (
            xcopy /E /I /Y "%%D\%ARCH_DIR%" "%TCLTK_DIR%\"
        )
    )
    echo Tcl/Tk binaries ready
) else (
    echo Using existing Tcl/Tk binaries
)

REM Build external dependencies
echo.
echo [5/6] Building external dependencies...
echo This may take several minutes...
call "%SOURCE_DIR%\PCbuild\build.bat" -e -p %PLATFORM%
if errorlevel 1 (
    echo ERROR: Failed to build external dependencies
    exit /b 1
)
echo [5/6] External dependencies built successfully

REM Build Python with Release configuration
echo.
echo [6/6] Building Python %PYTHON_VERSION% ^(Release configuration^)...
echo This may take several minutes...
call "%SOURCE_DIR%\PCbuild\build.bat" -p %PLATFORM% -c Release
if errorlevel 1 (
    echo ERROR: Failed to build Python
    exit /b 1
)
echo [6/6] Python built successfully

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

REM Test Tkinter availability
echo.
echo ========================================
echo === Testing Tkinter Support ===
echo ========================================
"%ARCH_DIR%\python.exe" -c "import Tkinter; print('Tkinter version: ' + Tkinter.TkVersion.__str__()); print('Tcl version: ' + Tkinter.TclVersion.__str__())"
if errorlevel 1 (
    echo WARNING: Tkinter test failed - GUI support may not be available
    echo This is not a critical error, continuing with build...
) else (
    echo Tkinter test: OK
)

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
mkdir "%PORTABLE_DIR%\bin"
mkdir "%PORTABLE_DIR%\DLLs"
mkdir "%PORTABLE_DIR%\include"
mkdir "%PORTABLE_DIR%\libs"
echo Portable directory: %PORTABLE_DIR%

echo.
echo Copying Python executables and DLLs...
xcopy /Y /I "%ARCH_DIR%\python.exe" "%PORTABLE_DIR%\bin\" >nul
if errorlevel 1 (
    echo ERROR: Failed to copy python.exe
    exit /b 1
)
xcopy /Y /I "%ARCH_DIR%\pythonw.exe" "%PORTABLE_DIR%\bin\" >nul
xcopy /Y /I "%ARCH_DIR%\python27.dll" "%PORTABLE_DIR%\DLLs\" >nul
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

echo Copying Tcl/Tk DLLs and libraries for Tkinter support...
if exist "%TCLTK_DIR%\bin\*.dll" (
    xcopy /Y "%TCLTK_DIR%\bin\*.dll" "%PORTABLE_DIR%\DLLs\" >nul
    if exist "%TCLTK_DIR%\lib" (
        xcopy /E /I /Y "%TCLTK_DIR%\lib" "%PORTABLE_DIR%\tcl\" >nul
        echo Tcl/Tk runtime files copied
    )
) else (
    echo WARNING: Tcl/Tk binaries not found - Tkinter may not work in portable distribution
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
echo set SCRIPT_DIR=%%~dp0
echo for %%I in ("%%SCRIPT_DIR%%.") do set PYTHON_HOME=%%~dpI\..
echo set PYTHON_HOME=%%PYTHON_HOME:~0,-1%%
echo set PATH=%%PYTHON_HOME%%\bin;%%PYTHON_HOME%%\DLLs;%%PATH%%
echo set PYTHONHOME=%%PYTHON_HOME%%
echo set TCL_LIBRARY=%%PYTHON_HOME%%\tcl\tcl8.6
echo set TK_LIBRARY=%%PYTHON_HOME%%\tcl\tk8.6
echo "%%PYTHON_HOME%%\bin\python.exe" %%*
echo endlocal
) > "%PORTABLE_DIR%\bin\python-portable.bat"

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
echo 2. Use bin\python-portable.bat to run Python with correct paths:
echo    bin\python-portable.bat --version
echo    bin\python-portable.bat script.py
echo.
echo 3. Or set environment variables manually:
echo    set PYTHONHOME=^<path-to-this-directory^>
echo    set PATH=%%PYTHONHOME%%\bin;%%PYTHONHOME%%\DLLs;%%PATH%%
echo    bin\python.exe
echo.
echo FEATURES
echo --------
echo - Relocatable installation - works from any directory
echo - All DLLs included - no external dependencies
echo - Complete standard library included
echo - Tkinter/GUI support with Tcl/Tk 8.6.12
echo - Full development headers included
echo - Import libraries for C extension development
echo - Built with modern MSVC v143 ^(Visual Studio 2022^)
echo.
echo DIRECTORY STRUCTURE
echo -------------------
echo python.exe, pythonw.exe    - Python executables
echo python27.dll               - Python runtime library
echo DLLs/                      - Python extension modules ^(.pyd files^) and Tcl/Tk DLLs
echo Lib/                       - Python standard library
echo tcl/                       - Tcl/Tk runtime libraries
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
