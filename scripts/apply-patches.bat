@echo off
REM Patch harness for Python 2.7 builds on Windows
REM Applies patches based on platform, architecture, and environment

setlocal enabledelayedexpansion

set PATCHES_DIR=%CD%\patches
set SOURCE_DIR=%~1

if "%SOURCE_DIR%"=="" (
    echo Error: Source directory not specified
    echo Usage: %0 ^<source-directory^>
    exit /b 1
)

if not exist "%SOURCE_DIR%" (
    echo Error: Source directory does not exist: %SOURCE_DIR%
    exit /b 1
)

echo === Python 2.7 Patch Harness ===
echo Source directory: %SOURCE_DIR%
echo Target arch: %TARGET_ARCH%

REM Detect Git patch utility
set "PATCH_EXE=C:\Program Files\Git\usr\bin\patch.exe"
if not exist "%PATCH_EXE%" (
    echo ERROR: patch.exe not found at "%PATCH_EXE%"
    echo Please install Git for Windows or ensure patch.exe is in PATH.
    exit /b 1
)

REM Apply common patches (p1)
if exist "%PATCHES_DIR%\common" (
    echo.
    echo Applying common patches...
    for %%f in ("%PATCHES_DIR%\common\*.patch") do (
        echo   - %%~nxf
        "%PATCH_EXE%" -d "%SOURCE_DIR%" -p1 -N --binary < "%%f"
        if errorlevel 1 (
            echo ERROR: Failed to apply patch %%~nxf
            exit /b 1
        )
    )
)

REM Apply Windows patches (most are p0)
if exist "%PATCHES_DIR%\windows\01-upgrade-vs2022-toolset.patch" (
    echo Applying Windows: 01-upgrade-vs2022-toolset.patch
    "%PATCH_EXE%" -d "%SOURCE_DIR%" -p1 -N --binary < "%PATCHES_DIR%\windows\01-upgrade-vs2022-toolset.patch"
    if errorlevel 1 exit /b 1
)
if exist "%PATCHES_DIR%\windows\02-fix-timemodule-msvc.patch" (
    echo Applying Windows: 02-fix-timemodule-msvc.patch
    "%PATCH_EXE%" -d "%SOURCE_DIR%" -p0 -N --binary < "%PATCHES_DIR%\windows\02-fix-timemodule-msvc.patch"
    if errorlevel 1 exit /b 1
)
if exist "%PATCHES_DIR%\windows\03-fix-posixmodule-msvc.patch" (
    echo Applying Windows: 03-fix-posixmodule-msvc.patch
    "%PATCH_EXE%" -d "%SOURCE_DIR%" -p0 -N --binary < "%PATCHES_DIR%\windows\03-fix-posixmodule-msvc.patch"
    if errorlevel 1 exit /b 1
)
if exist "%PATCHES_DIR%\windows\04-upgrade-tcltk-to-8.6.12.patch" (
    echo Applying Windows: 04-upgrade-tcltk-to-8.6.12.patch
    "%PATCH_EXE%" -d "%SOURCE_DIR%" -p0 -N --binary < "%PATCHES_DIR%\windows\04-upgrade-tcltk-to-8.6.12.patch"
    if errorlevel 1 exit /b 1
)

REM ARM64 specific patches (if requested)
set "_arch=%TARGET_ARCH%"
if /I "%_arch%"=="arm64" set _arch=aarch64
if /I "%_arch%"=="aarch64" (
    if exist "%PATCHES_DIR%\windows\arm64\01-python-props.patch" (
        echo Applying ARM64: 01-python-props.patch
        "%PATCH_EXE%" -d "%SOURCE_DIR%" -p0 -N --binary < "%PATCHES_DIR%\windows\arm64\01-python-props.patch"
        if errorlevel 1 exit /b 1
    )
    if exist "%PATCHES_DIR%\windows\arm64\02-pyproject-props.patch" (
        echo Applying ARM64: 02-pyproject-props.patch
        "%PATCH_EXE%" -d "%SOURCE_DIR%" -p0 -N --binary < "%PATCHES_DIR%\windows\arm64\02-pyproject-props.patch"
        if errorlevel 1 exit /b 1
    )
    if exist "%PATCHES_DIR%\windows\arm64\03-tcltk-props.patch" (
        echo Applying ARM64: 03-tcltk-props.patch
        "%PATCH_EXE%" -d "%SOURCE_DIR%" -p0 -N --binary < "%PATCHES_DIR%\windows\arm64\03-tcltk-props.patch"
        if errorlevel 1 exit /b 1
    )
    if exist "%PATCHES_DIR%\windows\arm64\04-pythoncore-baseaddr.patch" (
        echo Applying ARM64: 04-pythoncore-baseaddr.patch
        "%PATCH_EXE%" -d "%SOURCE_DIR%" -p0 -N --binary < "%PATCHES_DIR%\windows\arm64\04-pythoncore-baseaddr.patch"
        if errorlevel 1 exit /b 1
    )
    if exist "%PATCHES_DIR%\windows\arm64\05-add-arm64-support.patch" (
        echo Applying ARM64: 05-add-arm64-support.patch
        REM This patch is generated against Python-2.7.18/* paths. Apply from inside that dir with -p1
        set "__PY27_DIR=%SOURCE_DIR%\Python-2.7.18"
        if exist "%__PY27_DIR%" (
            "%PATCH_EXE%" -d "%__PY27_DIR%" -p1 -N --binary < "%PATCHES_DIR%\windows\arm64\05-add-arm64-support.patch"
        ) else (
            "%PATCH_EXE%" -d "%SOURCE_DIR%" -p1 -N --binary < "%PATCHES_DIR%\windows\arm64\05-add-arm64-support.patch"
        )
        if errorlevel 1 exit /b 1
    )
    if exist "%PATCHES_DIR%\windows\arm64\06-add-arm64-configs.patch" (
        echo Applying ARM64: 06-add-arm64-configs.patch
        REM Normalized git-style patch: paths start with Python-2.7.18/...
        REM Apply from repo root with -p1 so files map to %SOURCE_DIR%\Python-2.7.18\...
        "%PATCH_EXE%" -d "%SOURCE_DIR%" -p1 -N --binary < "%PATCHES_DIR%\windows\arm64\06-add-arm64-configs.patch"
        if errorlevel 1 exit /b 1
    )
)

echo.
echo === Patch application complete ===

endlocal
exit /b 0
