@echo off
REM Build Berkeley DB 6.0.19 for Windows ARM64
REM Based on python-build-standalone approach
setlocal enabledelayedexpansion

set BDB_VERSION=6.0.19
REM Get absolute paths
set SCRIPT_DIR=%~dp0
for %%I in ("%SCRIPT_DIR%..\..") do set PROJECT_ROOT=%%~fI
set BUILD_DIR=%PROJECT_ROOT%\build\bdb-arm64
set INSTALL_DIR=%PROJECT_ROOT%\build\bdb-arm64-install
set SOURCE_DIR=%BUILD_DIR%\db-%BDB_VERSION%

echo Building Berkeley DB %BDB_VERSION% for ARM64...
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

REM Download Berkeley DB if not present
if not exist "db-%BDB_VERSION%.tar.gz" (
    echo Downloading Berkeley DB %BDB_VERSION%...
    curl -LO "https://ftp.osuosl.org/pub/blfs/conglomeration/db/db-%BDB_VERSION%.tar.gz"
    if errorlevel 1 (
        echo ERROR: Failed to download Berkeley DB
        exit /b 1
    )
)

REM Extract Berkeley DB
if not exist "%SOURCE_DIR%" (
    echo Extracting Berkeley DB...
    tar -xzf db-%BDB_VERSION%.tar.gz
    if errorlevel 1 (
        echo ERROR: Failed to extract Berkeley DB
        exit /b 1
    )
)

REM Berkeley DB has Visual Studio project files in build_windows directory
cd /d "%SOURCE_DIR%\build_windows"
if errorlevel 1 (
    echo ERROR: Failed to change to build_windows directory
    exit /b 1
)

echo Building Berkeley DB using MSBuild...
REM Build the db_dll project which creates the DLL and LIB files
REM Using /p:Platform=ARM64 for ARM64 architecture
echo Note: Berkeley DB 6.0.19 does not include ARM64 configurations by default
echo Attempting to build with ARM64 platform...
msbuild Berkeley_DB.sln /p:Configuration=Release /p:Platform=ARM64 /t:db_dll /m 2>nul
if errorlevel 1 (
    echo WARNING: Berkeley DB does not support ARM64 platform configurations
    echo This is expected for Berkeley DB 6.0.19
    echo Python will be built without bsddb module support
    echo.
    echo Note: bsddb is deprecated and was removed in Python 3.x
    exit /b 1
)

REM Create install directory structure
if not exist "%INSTALL_DIR%\include" mkdir "%INSTALL_DIR%\include"
if not exist "%INSTALL_DIR%\lib" mkdir "%INSTALL_DIR%\lib"
if not exist "%INSTALL_DIR%\bin" mkdir "%INSTALL_DIR%\bin"

REM Copy headers
echo Installing Berkeley DB to %INSTALL_DIR%...
xcopy /Y "%SOURCE_DIR%\*.h" "%INSTALL_DIR%\include\"

REM Copy libraries and DLLs (they'll be in ARM64\Release after build)
if exist "ARM64\Release\libdb60.lib" (
    xcopy /Y "ARM64\Release\libdb60.lib" "%INSTALL_DIR%\lib\"
    xcopy /Y "ARM64\Release\libdb60.dll" "%INSTALL_DIR%\bin\"
) else (
    echo ERROR: Berkeley DB ARM64 libraries not found
    echo Expected: ARM64\Release\libdb60.lib
    exit /b 1
)

echo Berkeley DB built successfully for ARM64
echo Installation directory: %INSTALL_DIR%
exit /b 0
