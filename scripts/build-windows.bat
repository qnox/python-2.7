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

REM Apply patches for modern Visual Studio
echo Applying patches for VS2019 compatibility...
powershell -Command "Get-Content patches\windows\01-upgrade-vs2019-toolset.patch | ForEach-Object { $_ -replace '/', '\' } | Set-Content patches\windows\01-upgrade-vs2019-toolset-win.patch"

REM Apply patch to upgrade toolset
echo Patching pyproject.props for VS2019...
if exist "%SOURCE_DIR%\PCbuild\pyproject.props" (
    powershell -Command ^
    "$content = Get-Content '%SOURCE_DIR%\PCbuild\pyproject.props' -Raw; ^
    $content = $content -replace '<PlatformToolset>v90</PlatformToolset>', ^
    '<PlatformToolset Condition=''\"$(VisualStudioVersion)\"'' == ''\"16.0\"''>v142</PlatformToolset>^
    <PlatformToolset Condition=''\"$(VisualStudioVersion)\"'' == ''\"15.0\"''>v141</PlatformToolset>^
    <PlatformToolset Condition=''\"$(VisualStudioVersion)\"'' == ''\"14.0\"''>v140</PlatformToolset>^
    <PlatformToolset Condition=''\"$(PlatformToolset)\"'' == ''\"\">v142</PlatformToolset>'; ^
    $content = $content -replace '(<CharacterSet>NotSet</CharacterSet>)', '$1^
    <PreferredToolArchitecture>x64</PreferredToolArchitecture>^
    <WindowsTargetPlatformVersion Condition=''\"$(WindowsTargetPlatformVersion)\"'' == ''\"\">10.0</WindowsTargetPlatformVersion>'; ^
    $content = $content -replace 'Condition=\"\$\(Configuration\)\"', 'Condition=\"''$$(Configuration)''\"'; ^
    Set-Content '%SOURCE_DIR%\PCbuild\pyproject.props' -Value $content"
)

REM Fix MSBuild conditions in pyd.props
if exist "%SOURCE_DIR%\PCbuild\pyd.props" (
    powershell -Command ^
    "$content = Get-Content '%SOURCE_DIR%\PCbuild\pyd.props' -Raw; ^
    $content = $content -replace 'Condition=\"\$\(Platform\)\"', 'Condition=\"''$$(Platform)''\"'; ^
    Set-Content '%SOURCE_DIR%\PCbuild\pyd.props' -Value $content"
)

echo Patches applied successfully

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
echo - Compiler: MSVC v142 (VS2019) >> "%PORTABLE_DIR%\README.txt"
echo - Built on: %DATE% %TIME% >> "%PORTABLE_DIR%\README.txt"

echo === Build complete ===
echo Portable Python location: %PORTABLE_DIR%

endlocal
