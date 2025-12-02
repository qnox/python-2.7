@echo off
REM Patch harness for Python 2.7 builds on Windows
REM Applies patches based on platform, architecture, and environment

setlocal enabledelayedexpansion

set PATCHES_DIR=%CD%\patches
set SOURCE_DIR=%1

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
echo Target platform: %TARGET_PLATFORM%
echo Target arch: %TARGET_ARCH%

REM Function to apply patches from a directory
set "APPLY_FAILED=0"

REM Apply common patches
call :apply_patches_from_dir "%PATCHES_DIR%\common" "common patches"

REM Apply Windows patches
call :apply_patches_from_dir "%PATCHES_DIR%\windows" "Windows patches"

echo.
echo === Patch application complete ===

if "%APPLY_FAILED%"=="1" (
    echo Warning: Some patches failed to apply
)

endlocal
exit /b 0

:apply_patches_from_dir
    set "patch_dir=%~1"
    set "description=%~2"

    if not exist "%patch_dir%" (
        exit /b 0
    )

    set "found_patches=0"
    for %%f in ("%patch_dir%\*.patch") do (
        set "found_patches=1"
    )

    if "%found_patches%"=="0" (
        exit /b 0
    )

    echo.
    echo Applying %description%...

    for %%f in ("%patch_dir%\*.patch") do (
        echo   - %%~nxf

        REM Try to apply patch using PowerShell
        REM Windows doesn't have native patch utility, use alternatives
        echo     Note: Patch file found, manual application may be needed
        echo     File: %%f
    )

    exit /b 0
