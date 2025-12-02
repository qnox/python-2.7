@echo off
REM Python 2.7 portable build script for Windows
REM Supports x86_64 and x86 with MSVC

setlocal enabledelayedexpansion

set PYTHON_VERSION=2.7.18
set BUILD_DIR=%CD%\build
set SOURCE_DIR=%CD%\Python-%PYTHON_VERSION%

echo === Building Python %PYTHON_VERSION% for %TARGET_TRIPLE% ===

REM Download Python source if not present
if not exist "%SOURCE_DIR%" (
    echo Downloading Python %PYTHON_VERSION%...
    curl -LO "https://www.python.org/ftp/python/%PYTHON_VERSION%/Python-%PYTHON_VERSION%.tgz"
    tar xzf "Python-%PYTHON_VERSION%.tgz"
    del "Python-%PYTHON_VERSION%.tgz"
)

REM Apply patches for VS2022 compatibility
echo Applying patches for VS2022 compatibility...

REM Check if patches exist
if not exist "patches\windows\01-upgrade-vs2022-toolset.patch" (
    echo ERROR: Patch file 01-upgrade-vs2022-toolset.patch not found!
    dir patches\windows\
    exit /b 1
)
if not exist "patches\windows\02-fix-timemodule-msvc.patch" (
    echo ERROR: Patch file 02-fix-timemodule-msvc.patch not found!
    dir patches\windows\
    exit /b 1
)

echo Applying VS2022 toolset upgrade patch...
if exist "C:\Program Files\Git\usr\bin\patch.exe" (
    "C:\Program Files\Git\usr\bin\patch.exe" -d "%SOURCE_DIR%" -p1 -N --binary < patches\windows\01-upgrade-vs2022-toolset.patch
    if errorlevel 1 (
        echo ERROR: VS2022 toolset patch failed to apply!
        exit /b 1
    )
) else (
    echo ERROR: Git patch utility not found!
    exit /b 1
)

echo Applying timemodule.c fix for modern MSVC...
echo Checking patch file:
type patches\windows\02-fix-timemodule-msvc.patch | head -20
echo.
echo Checking source file line endings:
file "%SOURCE_DIR%\Modules\timemodule.c" 2>nul || echo File command not available
echo.
echo Applying patch with verbose output:
"C:\Program Files\Git\usr\bin\patch.exe" -d "%SOURCE_DIR%" -p0 -N --binary --ignore-whitespace --verbose < patches\windows\02-fix-timemodule-msvc.patch 2>&1
if errorlevel 1 (
    echo ERROR: timemodule.c patch failed to apply!
    echo Showing reject file if it exists:
    type "%SOURCE_DIR%\Modules\timemodule.c.rej" 2>nul
    echo.
    echo Showing first 30 lines of timemodule.c around line 808:
    powershell "Get-Content '%SOURCE_DIR%\Modules\timemodule.c' | Select-Object -Skip 805 -First 30"
    exit /b 1
)
echo timemodule.c patched successfully

echo Applying posixmodule.c fix for modern MSVC...
"C:\Program Files\Git\usr\bin\patch.exe" -d "%SOURCE_DIR%" -p0 -N --binary --ignore-whitespace < patches\windows\03-fix-posixmodule-msvc.patch
if errorlevel 1 (
    echo ERROR: posixmodule.c patch failed to apply!
    exit /b 1
)
echo posixmodule.c patched successfully

cd "%SOURCE_DIR%\PCbuild"

REM Set architecture
if "%TARGET_ARCH%"=="x86_64" (
    set PLATFORM=x64
    set ARCH_DIR=amd64
) else if "%TARGET_ARCH%"=="x86" (
    set PLATFORM=Win32
    set ARCH_DIR=win32
) else (
    echo Unknown architecture: %TARGET_ARCH%
    exit /b 1
)

REM Build external dependencies
echo Building external dependencies...
call build.bat -e -p %PLATFORM%
if errorlevel 1 exit /b 1

REM Build Python
echo Building Python...
call build.bat -p %PLATFORM% -c Release
if errorlevel 1 exit /b 1

echo Checking build output...
if not exist "%ARCH_DIR%\python.exe" (
    echo ERROR: python.exe not found in %ARCH_DIR%
    echo Build may have failed or files are in a different location
    dir /b
    exit /b 1
)

REM Prepare portable installation
set PORTABLE_DIR=%BUILD_DIR%\python-%PYTHON_VERSION%-%TARGET_TRIPLE%
if exist "%PORTABLE_DIR%" rmdir /s /q "%PORTABLE_DIR%"
mkdir "%PORTABLE_DIR%"

echo === Creating portable Python distribution ===

REM Copy Python executable and DLLs
xcopy /Y /I "%ARCH_DIR%\python.exe" "%PORTABLE_DIR%\"
xcopy /Y /I "%ARCH_DIR%\pythonw.exe" "%PORTABLE_DIR%\"
xcopy /Y /I "%ARCH_DIR%\python27.dll" "%PORTABLE_DIR%\"
xcopy /Y /I "%ARCH_DIR%\*.pyd" "%PORTABLE_DIR%\DLLs\"

REM Copy standard library
xcopy /E /I /Y "..\..\Lib\*" "%PORTABLE_DIR%\Lib\"

REM Copy include files for development
xcopy /E /I /Y "..\..\Include\*" "%PORTABLE_DIR%\include\"
xcopy /Y /I "..\..\PC\pyconfig.h" "%PORTABLE_DIR%\include\"

REM Copy import library for linking
xcopy /Y /I "%ARCH_DIR%\python27.lib" "%PORTABLE_DIR%\libs\"

REM Create portable launcher script
echo @echo off > "%PORTABLE_DIR%\python-portable.bat"
echo REM Portable Python launcher for Windows >> "%PORTABLE_DIR%\python-portable.bat"
echo set PYTHON_HOME=%%~dp0 >> "%PORTABLE_DIR%\python-portable.bat"
echo set PATH=%%PYTHON_HOME%%;%%PYTHON_HOME%%\DLLs;%%PATH%% >> "%PORTABLE_DIR%\python-portable.bat"
echo set PYTHONHOME=%%PYTHON_HOME%% >> "%PORTABLE_DIR%\python-portable.bat"
echo "%%PYTHON_HOME%%\python.exe" %%* >> "%PORTABLE_DIR%\python-portable.bat"

REM Create README
echo Python %PYTHON_VERSION% Portable Build for Windows > "%PORTABLE_DIR%\README.txt"
echo Target: %TARGET_TRIPLE% >> "%PORTABLE_DIR%\README.txt"
echo. >> "%PORTABLE_DIR%\README.txt"
echo This is a portable Python installation that can be placed in any directory. >> "%PORTABLE_DIR%\README.txt"
echo. >> "%PORTABLE_DIR%\README.txt"
echo Usage: >> "%PORTABLE_DIR%\README.txt"
echo 1. Extract this archive to any location >> "%PORTABLE_DIR%\README.txt"
echo 2. Use python-portable.bat to run Python with correct paths >> "%PORTABLE_DIR%\README.txt"
echo 3. Or set environment variables: >> "%PORTABLE_DIR%\README.txt"
echo    set PYTHONHOME=^<path-to-this-directory^> >> "%PORTABLE_DIR%\README.txt"
echo    set PATH=%%PYTHONHOME%%;%%PYTHONHOME%%\DLLs;%%PATH%% >> "%PORTABLE_DIR%\README.txt"
echo    python.exe >> "%PORTABLE_DIR%\README.txt"
echo. >> "%PORTABLE_DIR%\README.txt"
echo Features: >> "%PORTABLE_DIR%\README.txt"
echo - Relocatable installation >> "%PORTABLE_DIR%\README.txt"
echo - All DLLs included >> "%PORTABLE_DIR%\README.txt"
echo - Standard library included >> "%PORTABLE_DIR%\README.txt"
echo - Full development headers included >> "%PORTABLE_DIR%\README.txt"
echo - Import libraries for C extension development >> "%PORTABLE_DIR%\README.txt"
echo. >> "%PORTABLE_DIR%\README.txt"
echo Build info: >> "%PORTABLE_DIR%\README.txt"
echo - Architecture: %TARGET_ARCH% >> "%PORTABLE_DIR%\README.txt"
echo - Compiler: MSVC v143 (VS2022) >> "%PORTABLE_DIR%\README.txt"
echo - Built on: %DATE% %TIME% >> "%PORTABLE_DIR%\README.txt"

echo === Build complete ===
echo Portable Python location: %PORTABLE_DIR%

endlocal
