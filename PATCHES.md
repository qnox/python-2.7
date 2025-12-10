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
├── README.md              # Patch documentation
├── common/                # Patches applied to all builds
├── linux/                 # Linux-specific patches
│   ├── glibc/            # Patches for glibc builds
│   └── musl/             # Patches for musl builds
├── macos/                 # macOS-specific patches
│   ├── x86_64/           # Intel Mac patches
│   └── arm64/            # Apple Silicon patches
└── windows/               # Windows-specific patches
```

## Patch Application Order

Patches are applied in order of increasing specificity:

1. **Common patches** (`patches/common/`) - Applied to all builds
2. **Platform patches** (`patches/linux/`, `patches/macos/`, `patches/windows/`)
3. **Sub-platform patches** (e.g., `patches/linux/musl/`, `patches/macos/arm64/`)

This allows general fixes to be overridden by more specific ones.

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

### macOS (All Architectures)

#### `01-configure-arch-detection.patch`

**Problem**: Python 2.7's configure script doesn't recognize ARM64 and x86_64 architectures:
```
configure: error: Unexpected output of 'arch' on OSX
```

**Solution**: Patches the configure script to detect `arm64` and `x86_64` architectures properly.

**Affected file**: `configure` (lines ~3151-3157)

**Changes**:
- Adds detection for `uname -p` returning `arm` or `uname -m` returning `arm64`
- Sets `MACOSX_DEFAULT_ARCH` to `arm64` for Apple Silicon
- Sets `MACOSX_DEFAULT_ARCH` to `x86_64` for Intel Macs
- Maintains error handling for unknown architectures

### Windows (All Architectures)

#### `01-upgrade-vs2019-toolset.patch`

**Problem**: Python 2.7 uses Visual Studio 2008 (v90) platform toolset which is not available in modern Visual Studio installations:
```
error MSB8020: The build tools for Visual Studio 2008 (Platform Toolset = 'v90') cannot be found.
```

**Solution**: Updates MSBuild project files to use modern Visual Studio toolsets (v142 for VS2019, v141 for VS2017, v140 for VS2015).

**Affected file**: `PCbuild/pyproject.props`

**Changes**:
- Replaces hardcoded `<PlatformToolset>v90</PlatformToolset>` with conditional selection
- Automatically detects Visual Studio version and uses appropriate toolset
- Adds Windows 10 SDK support
- Adds `PreferredToolArchitecture` for better build performance
- Fixes MSBuild condition syntax for modern MSBuild

**Note**: This patch is applied programmatically via PowerShell in the Windows build script to handle Windows path conventions.

#### `02-fix-msbuild-conditions.patch`

**Problem**: Modern MSBuild requires proper quoting in condition expressions.

**Solution**: Adds proper quotes around MSBuild variables in conditions.

**Affected file**: `PCbuild/pyd.props`

**Changes**:
- Updates `Condition="$(Platform)"` to `Condition="'$(Platform)'"`
- Ensures compatibility with MSBuild 16.0+

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
