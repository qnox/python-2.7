# Patch System Documentation

This document describes the patch harness system used to apply platform-specific fixes to Python 2.7.18.

## Overview

Python 2.7.18 was released in April 2020 and does not natively support modern platforms like Apple Silicon. The patch harness system provides a flexible way to apply patches based on:

- **Platform** (linux, macos, windows)
- **Architecture** (x86_64, i686, arm64)
- **Environment** (glibc, musl, msvc)

## Directory Structure

```
patches/
├── common/                # Patches applied to all builds (after platform patches)
├── linux/                 # Linux-specific patches
├── macos/                 # macOS-specific patches (all architectures)
├── windows/               # Windows-specific patches
│   └── arm64/            # Windows ARM64-specific patches
```

Note: Only directories that contain patches are shown. Sub-platform directories (like `linux/glibc/` or `macos/arm64/`) are created only when needed.

## Patch Application Order

Patches are applied in this specific order:

1. **Platform patches** (`patches/linux/`, `patches/macos/`, `patches/windows/`)
2. **Sub-platform patches** (e.g., `patches/linux/musl/`, `patches/windows/arm64/`)
3. **Common patches** (`patches/common/`) - Applied LAST to all builds

**Important**: Platform patches are applied FIRST because some patches (like pyenv's macOS patches) modify files that common patches may also touch. Common patches are applied last to ensure they can override platform-specific behavior when needed.

## Using the Patch Harness

### Automatic Application (during build)

The build scripts automatically apply patches:

```bash
# Patches are applied after source download
bash scripts/build-linux.sh   # or build-macos.sh
```

### Manual Application

```bash
# Apply patches to a source directory
TARGET_PLATFORM=macos TARGET_ARCH=arm64 \
  bash scripts/apply-patches.sh Python-2.7.18/
```

### Environment Variables

The patch harness uses these environment variables:

- `TARGET_PLATFORM` - Platform: `linux`, `macos`, or `windows`
- `TARGET_ARCH` - Architecture: `x86_64`, `i686`, `arm64`
- `TARGET_LIBC` - C library (Linux only): `glibc` or `musl`

## Creating New Patches

### Step 1: Prepare Source

```bash
# Download Python source
curl -LO https://www.python.org/ftp/python/2.7.18/Python-2.7.18.tgz
tar xzf Python-2.7.18.tgz

# Create a backup copy
cp -r Python-2.7.18 Python-2.7.18.orig
```

### Step 2: Make Changes

Edit files in `Python-2.7.18/` to fix the issue.

### Step 3: Generate Patch

```bash
# Create unified diff patch
diff -Naur Python-2.7.18.orig/ Python-2.7.18/ > my-fix.patch
```

### Step 4: Place Patch

Move patch to appropriate directory:

```bash
# Example: macOS ARM64 specific patch
mv my-fix.patch patches/macos/arm64/02-my-fix.patch
```

### Naming Convention

Patches should be named: `NN-description.patch`

- `NN` - Two-digit sequence number (01, 02, 03, ...)
- `description` - Short kebab-case description
- Examples:
  - `01-configure-arch-detection.patch`
  - `02-ssl-openssl3-support.patch`
  - `03-sqlite-modern-version.patch`

## Current Patches

### Common Patches (All Platforms)

Applied after platform-specific patches to all builds.

#### `disable-multiarch-musl.patch`
Disables multiarch configuration for musl builds to avoid compatibility issues.

#### `skip-system-paths-musl.patch`
Prevents Python from searching system paths on musl systems, ensuring self-contained builds.

### Linux Patches

#### `fix-config-args-none.patch`
Fixes configure argument handling when arguments are None/empty.

### macOS Patches (All Architectures)

These patches are primarily from the [pyenv project](https://github.com/pyenv/pyenv) and enable Python 2.7 on modern macOS, including Apple Silicon.

#### `0001-Detect-arm64-in-configure.patch`
Adds ARM64 (Apple Silicon) architecture detection to the configure script.

#### `0002-Fix-macOS-_tkinter-use-of-Tck-Tk-in-Library-Framewor.patch`
Fixes tkinter to properly use Tcl/Tk from system frameworks.

#### `0003-Support-arm64-in-Mac-Tools-pythonw.patch`
Adds ARM64 support to the pythonw executable wrapper.

#### `0004-Use-system-libffi-for-Mac-OS-10.15-and-up.patch`
Configures Python to use system libffi on macOS 10.15+ (required for ARM64 support).

#### `0005-ctypes-use-the-correct-ABI-for-variadic-functions.patch`
Fixes ctypes ABI handling for variadic functions on modern architectures.

#### `0006-ctypes-probe-libffi-for-ffi_closure_alloc-and-ffi_pr.patch`
Adds runtime probing for libffi functions to support different libffi versions.

#### `0007-Remove-QuickTime-from-link-args.patch`
Removes deprecated QuickTime framework from linker arguments (not available on modern macOS).

### Windows Patches (x86_64 and i686)

#### `01-upgrade-vs2019-toolset.patch` / `01-upgrade-vs2022-toolset.patch`
Updates MSBuild project files from Visual Studio 2008 (v90) toolset to modern toolsets (v142/v143). Enables building with Visual Studio 2019 or 2022.

#### `02-fix-msbuild-conditions.patch`
Fixes MSBuild condition syntax for compatibility with modern MSBuild versions.

#### `02-fix-timemodule-msvc.patch`
Fixes time module compilation with modern MSVC compilers.

#### `03-fix-posixmodule-msvc.patch`
Fixes POSIX module compilation with modern MSVC compilers.

#### `04-upgrade-tcltk-to-8.6.12.patch`
Updates Tcl/Tk version references from 8.5 to 8.6.12 for compatibility with available binaries.

### Windows ARM64 Patches

These patches enable Python 2.7 on Windows ARM64 (experimental):

#### `01-python-props.patch`
Adds ARM64 platform support to Python build properties.

#### `02-pyproject-props.patch`
Adds ARM64 configuration to MSBuild project files.

#### `03-tcltk-props.patch`
Configures Tcl/Tk for ARM64 builds.

#### `04-pythoncore-baseaddr.patch`
Sets appropriate base address for pythoncore DLL on ARM64.

#### `05-add-arm64-support.patch`
Adds core ARM64 architecture support to Python source.

#### `06-add-arm64-configs.patch`
Adds ARM64 project configurations to MSBuild files.

#### `07-disable-ctypes-arm64.patch`
Disables ctypes module on ARM64 (libffi not fully supported on Windows ARM64).

#### `08-openssl-1.1.1w-for-arm64.patch`
Updates OpenSSL version for ARM64 compatibility.

#### `09-disable-tcltk-arm64.patch`
Disables Tcl/Tk on ARM64 (prebuilt binaries configuration).

## Testing Patches

### Test patch application

```bash
# Dry run (doesn't modify files)
patch -p0 -N --dry-run < patches/macos/01-configure-arch-detection.patch

# Check if patch applies cleanly
cd Python-2.7.18
patch -p0 --dry-run < ../patches/macos/01-configure-arch-detection.patch
```

### Test build with patches

```bash
export TARGET_PLATFORM=macos
export TARGET_ARCH=arm64
export TARGET_TRIPLE=arm64-apple-darwin

bash scripts/build-macos.sh
```

## Patch Guidelines

1. **One fix per patch** - Each patch should address a single issue
2. **Minimal changes** - Only modify what's necessary
3. **Portable** - Patches should work across different Python 2.7.18 sources
4. **Documented** - Add comments in patch explaining the fix
5. **Tested** - Verify patch on target platform before committing
6. **Idempotent** - Running patch twice should be safe (use `-N` flag)

## Troubleshooting

### Patch doesn't apply

```bash
# Try with -p1 instead of -p0
patch -p1 < my-patch.patch

# Check patch format
file my-patch.patch

# View patch contents
cat my-patch.patch
```

### Patch applies but build fails

1. Check if patch modified correct file
2. Verify line numbers match source
3. Test on clean Python 2.7.18 source
4. Check for conflicting patches

### Creating patches with Git

If working in a git repository:

```bash
# Make changes to Python source
cd Python-2.7.18
# ... edit files ...

# Create patch from git diff
git diff > ../patches/macos/arm64/02-my-fix.patch
```

## Additional Resources

- [Python 2.7.18 Release](https://www.python.org/downloads/release/python-2718/)
- [GNU Patch Manual](https://www.gnu.org/software/patch/manual/)
- [Creating Patches with diff](https://www.gnu.org/software/diffutils/manual/html_node/Unified-Format.html)

## Contributing Patches

When contributing new patches:

1. Test on target platform
2. Document the issue being fixed
3. Use clear, descriptive naming
4. Place in appropriate directory
5. Update this documentation
6. Submit via pull request
