@echo off
REM Python 2.7 build script for Windows
REM Supports x86_64 and x86 with MSVC
REM Based on python-build-standalone architecture

setlocal enabledelayedexpansion

set PYTHON_VERSION=2.7.18
set PROJECT_ROOT=%CD%
set BUILD_DIR=%PROJECT_ROOT%\build
set SOURCE_DIR=%PROJECT_ROOT%\Python-%PYTHON_VERSION%

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
            REM Copy DLLs without 't' suffix for compatibility with legacy build system
            if exist "%TCLTK_DIR%\bin\tcl86t.dll" copy /Y "%TCLTK_DIR%\bin\tcl86t.dll" "%TCLTK_DIR%\bin\tcl86.dll"
            if exist "%TCLTK_DIR%\bin\tk86t.dll" copy /Y "%TCLTK_DIR%\bin\tk86t.dll" "%TCLTK_DIR%\bin\tk86.dll"
            if exist "%TCLTK_DIR%\lib\tcl86t.lib" copy /Y "%TCLTK_DIR%\lib\tcl86t.lib" "%TCLTK_DIR%\lib\tcl86.lib"
            if exist "%TCLTK_DIR%\lib\tk86t.lib" copy /Y "%TCLTK_DIR%\lib\tk86t.lib" "%TCLTK_DIR%\lib\tk86.lib"
        )
    )
    echo Tcl/Tk binaries ready
) else (
    echo Using existing Tcl/Tk binaries
)

REM Build Berkeley DB for ARM64 from source
if "%ARCH_DIR%"=="arm64" (
    echo.
    echo [4.4/6] Building Berkeley DB from source for ARM64...
    call "%PROJECT_ROOT%\scripts\deps\build-bdb-arm64.bat"
    if errorlevel 1 (
        echo WARNING: Failed to build Berkeley DB for ARM64
        echo Continuing without bsddb module support
        set BDB_FAILED=1
    ) else (
        echo [4.4/6] Berkeley DB built successfully for ARM64

        REM Copy Berkeley DB libraries to externals directory
        set BDB_INSTALL=%PROJECT_ROOT%\build\bdb-arm64-install
        set BDB_EXTERNALS=%SOURCE_DIR%\externals\db-6.0.19
        if not exist "!BDB_EXTERNALS!" mkdir "!BDB_EXTERNALS!"
        if not exist "!BDB_EXTERNALS!\include" mkdir "!BDB_EXTERNALS!\include"
        if not exist "!BDB_EXTERNALS!\lib" mkdir "!BDB_EXTERNALS!\lib"

        REM Copy include files
        xcopy /Y "!BDB_INSTALL!\include\*.h" "!BDB_EXTERNALS!\include\"

        REM Copy library files
        xcopy /Y "!BDB_INSTALL!\lib\*.lib" "!BDB_EXTERNALS!\lib\"

        echo Berkeley DB libraries copied to Python externals directory
        set BDB_FAILED=0
    )
)

REM Build OpenSSL for ARM64 from source using Perl Configure
if "%ARCH_DIR%"=="arm64" (
    echo.
    echo [4.5/6] Building OpenSSL from source for ARM64...
    call "%PROJECT_ROOT%\scripts\deps\build-openssl-arm64.bat"
    if errorlevel 1 (
        echo ERROR: Failed to build OpenSSL for ARM64
        exit /b 1
    )
    echo [4.5/6] OpenSSL built successfully for ARM64

    REM Copy OpenSSL libraries from build directory to externals
    set OPENSSL_BUILD=%PROJECT_ROOT%\build\openssl-arm64\openssl-1.1.1w
    set OPENSSL_EXTERNALS=%SOURCE_DIR%\externals\openssl-1.1.1w
    if not exist "!OPENSSL_EXTERNALS!" mkdir "!OPENSSL_EXTERNALS!"
    if not exist "!OPENSSL_EXTERNALS!\inc32" mkdir "!OPENSSL_EXTERNALS!\inc32"
    if not exist "!OPENSSL_EXTERNALS!\out32" mkdir "!OPENSSL_EXTERNALS!\out32"

    REM Copy include files from build directory
    xcopy /E /I /Y "!OPENSSL_BUILD!\include\openssl" "!OPENSSL_EXTERNALS!\inc32\openssl"

    REM Copy library files from build directory
    xcopy /Y "!OPENSSL_BUILD!\libcrypto.lib" "!OPENSSL_EXTERNALS!\out32\"
    xcopy /Y "!OPENSSL_BUILD!\libssl.lib" "!OPENSSL_EXTERNALS!\out32\"

    REM Copy with old OpenSSL 1.0.2 names for compatibility
    copy /Y "!OPENSSL_BUILD!\libcrypto.lib" "!OPENSSL_EXTERNALS!\out32\libeay.lib"
    copy /Y "!OPENSSL_BUILD!\libssl.lib" "!OPENSSL_EXTERNALS!\out32\ssleay.lib"

    echo OpenSSL libraries copied to Python externals directory
)

REM Build external dependencies
echo.
echo [5/6] Building external dependencies...
echo This may take several minutes...
REM Skip bsddb for all platforms (old bsddb 4.7.25 has build issues with modern toolchains)
if "%ARCH_DIR%"=="arm64" (
    if "%BDB_FAILED%"=="1" (
        echo Skipping bsddb module ^(Berkeley DB build failed^)
        call "%SOURCE_DIR%\PCbuild\build.bat" -e -p %PLATFORM% --no-bsddb
    ) else (
        call "%SOURCE_DIR%\PCbuild\build.bat" -e -p %PLATFORM%
    )
) else (
    echo Skipping bsddb module for %ARCH_DIR% ^(legacy bsddb has compatibility issues^)
    call "%SOURCE_DIR%\PCbuild\build.bat" -e -p %PLATFORM% --no-bsddb
)
if errorlevel 1 (
    echo ERROR: Failed to build external dependencies
    exit /b 1
)
echo [5/6] External dependencies built successfully

REM Build Python with Release configuration
echo.
echo [6/6] Building Python %PYTHON_VERSION% ^(Release configuration^)...
echo This may take several minutes...
REM Skip bsddb for all platforms (old bsddb 4.7.25 has build issues with modern toolchains)
if "%ARCH_DIR%"=="arm64" (
    if "%BDB_FAILED%"=="1" (
        echo Skipping bsddb module ^(Berkeley DB build failed^)
        call "%SOURCE_DIR%\PCbuild\build.bat" -p %PLATFORM% -c Release --no-bsddb
    ) else (
        call "%SOURCE_DIR%\PCbuild\build.bat" -p %PLATFORM% -c Release
    )
) else (
    call "%SOURCE_DIR%\PCbuild\build.bat" -p %PLATFORM% -c Release --no-bsddb
)
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

REM Prepare installation directory
echo.
echo ========================================
echo === Creating Distribution ===
echo ========================================
set PYTHON_DIST_DIR=%BUILD_DIR%\python-%PYTHON_VERSION%-%TARGET_TRIPLE%
if exist "%PYTHON_DIST_DIR%" (
    echo Removing existing directory...
    rmdir /s /q "%PYTHON_DIST_DIR%"
)
mkdir "%PYTHON_DIST_DIR%"
mkdir "%PYTHON_DIST_DIR%\DLLs"
mkdir "%PYTHON_DIST_DIR%\Scripts"
mkdir "%PYTHON_DIST_DIR%\include"
mkdir "%PYTHON_DIST_DIR%\libs"
echo Distribution directory: %PYTHON_DIST_DIR%

echo.
echo Copying Python executables and DLLs...
REM Following python-build-standalone layout: python.exe and python27.dll in root
xcopy /Y /I "%ARCH_DIR%\python.exe" "%PYTHON_DIST_DIR%\" >nul
if errorlevel 1 (
    echo ERROR: Failed to copy python.exe
    exit /b 1
)
xcopy /Y /I "%ARCH_DIR%\pythonw.exe" "%PYTHON_DIST_DIR%\" >nul
xcopy /Y /I "%ARCH_DIR%\python27.dll" "%PYTHON_DIST_DIR%\" >nul
if errorlevel 1 (
    echo ERROR: Failed to copy python27.dll
    exit /b 1
)

echo Copying Python extension modules ^(.pyd files^)...
if not exist "%PYTHON_DIST_DIR%\DLLs" mkdir "%PYTHON_DIST_DIR%\DLLs"
xcopy /Y /I "%ARCH_DIR%\*.pyd" "%PYTHON_DIST_DIR%\DLLs\" >nul
if errorlevel 1 (
    echo WARNING: Some .pyd files may not have been copied
)

echo Copying Tcl/Tk DLLs and libraries for Tkinter support...
REM Following python-build-standalone: core Tcl/Tk DLLs go to root, libs to tcl/
if exist "%TCLTK_DIR%\bin\tcl86.dll" (
    xcopy /Y "%TCLTK_DIR%\bin\tcl*.dll" "%PYTHON_DIST_DIR%\" >nul
    xcopy /Y "%TCLTK_DIR%\bin\tk*.dll" "%PYTHON_DIST_DIR%\" >nul
    if exist "%TCLTK_DIR%\lib" (
        xcopy /E /I /Y "%TCLTK_DIR%\lib" "%PYTHON_DIST_DIR%\tcl\" >nul
        echo Tcl/Tk runtime files copied
    )
) else (
    echo WARNING: Tcl/Tk binaries not found - Tkinter may not work in distribution
)

echo Copying standard library...
xcopy /E /I /Y "%SOURCE_DIR%\Lib\*" "%PYTHON_DIST_DIR%\Lib\" >nul
if errorlevel 1 (
    echo ERROR: Failed to copy standard library
    exit /b 1
)

echo Copying development headers...
xcopy /E /I /Y "%SOURCE_DIR%\Include\*" "%PYTHON_DIST_DIR%\include\" >nul
xcopy /Y /I "%SOURCE_DIR%\PC\pyconfig.h" "%PYTHON_DIST_DIR%\include\" >nul
if errorlevel 1 (x
    echo ERROR: Failed to copy development headers
    exit /b 1
)

echo Copying import libraries for C extension development...
if not exist "%PYTHON_DIST_DIR%\libs" mkdir "%PYTHON_DIST_DIR%\libs"
xcopy /Y /I "%ARCH_DIR%\python27.lib" "%PYTHON_DIST_DIR%\libs\" >nul
if errorlevel 1 (
    echo ERROR: Failed to copy python27.lib
    exit /b 1
)

echo Creating README.txt...
(
echo Python %PYTHON_VERSION% Build for Windows
echo ========================================
echo.
echo Target: %TARGET_TRIPLE%
echo Architecture: %TARGET_ARCH%
echo.
echo This is a self-contained Python installation that can be placed in any directory ^(portable^).
echo.
echo USAGE
echo -----
echo 1. Extract this archive to any location
echo 2. ^(Optional^) Set PYTHONHOME for standard library location:
echo    set PYTHONHOME=^<path-to-this-directory^>
echo.
echo 3. Run Python directly:
echo    python.exe --version
echo    python.exe script.py
echo.
echo NOTE: python.exe and python27.dll are in the same directory, so no PATH
echo       setup is required for basic operation. PYTHONHOME is only needed if
echo       Python cannot auto-detect the standard library location.
echo.
echo FEATURES
echo --------
echo - Self-contained and relocatable - works from any directory
echo - python.exe finds python27.dll automatically ^(same directory^)
echo - All DLLs included - no external dependencies
echo - Complete standard library included
echo - Tkinter/GUI support with Tcl/Tk 8.6.12
echo - Full development headers included
echo - Import libraries for C extension development
echo - Built with modern MSVC v143 ^(Visual Studio 2022^)
echo.
echo DIRECTORY STRUCTURE ^(matches python-build-standalone^)
echo -------------------
echo python.exe, pythonw.exe     - Python executables ^(root^)
echo python27.dll                - Python runtime library ^(root^)
echo tcl86.dll, tk86.dll         - Tcl/Tk runtime DLLs ^(root^)
echo DLLs/                       - Python extension modules ^(.pyd files^)
echo Lib/                        - Python standard library
echo Scripts/                    - Python scripts directory
echo tcl/                        - Tcl/Tk libraries
echo include/                    - C/C++ headers for extension development
echo libs/                       - Import libraries for linking
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
) > "%PYTHON_DIST_DIR%\README.txt"

echo.
echo ========================================
echo === BUILD COMPLETED SUCCESSFULLY ===
echo ========================================
echo.
echo Python Version: %PYTHON_VERSION%
echo Target Triple: %TARGET_TRIPLE%
echo Architecture: %TARGET_ARCH%
echo Distribution Location: %PYTHON_DIST_DIR%
echo.
echo Next steps:
echo 1. Run: scripts\package.bat    ^(to create distributable archive^)
echo 2. Run: scripts\test.bat       ^(to test the build^)
echo.

endlocal
