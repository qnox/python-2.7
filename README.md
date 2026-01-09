# Python 2.7 Builds

Automated builds of Python 2.7.18 for multiple platforms, architectures, and C libraries.

## Features

- **Self-Contained & Relocatable**: Can be placed in any directory without modification (portable)
- **Multiple Platforms**: Windows, Linux (glibc/musl), macOS
- **Multiple Architectures**: x86_64, i686/x86, ARM64 (Apple Silicon)
- **All Dependencies Included**: No system-wide installation required
- **Development Ready**: Includes headers and libraries for C extension development
- **Build Flavors**: `install_only` (complete installation with debug symbols) and `install_only_stripped` (smaller, optimized for distribution)

## Supported Platforms

### Linux
- **x86_64-unknown-linux-gnu**: 64-bit Linux with glibc
- **i686-unknown-linux-gnu**: 32-bit Linux with glibc
- **x86_64-unknown-linux-musl**: 64-bit Linux with musl libc (Alpine, static-friendly)
- **i686-unknown-linux-musl**: 32-bit Linux with musl libc

### macOS
- **x86_64-apple-darwin**: Intel Macs (macOS 10.9+)
- **arm64-apple-darwin**: Apple Silicon (macOS 11.0+)

### Windows
- **x86_64-pc-windows-msvc**: 64-bit Windows
- **i686-pc-windows-msvc**: 32-bit Windows

## Download

Download pre-built binaries from the [Releases](../../releases) page.

## Usage

### Linux / macOS

1. Download and extract the archive:
   ```bash
   tar xf cpython-2.7.18+YYYYMMDD-<target-triple>-install_only.tar.gz
   cd python
   ```

2. Run Python directly:
   ```bash
   ./bin/python --version
   ./bin/python script.py
   ```

   The distribution is self-contained and relocatable - no environment variables needed.

### Windows

1. Download and extract the archive:
   ```cmd
   tar -xzf cpython-2.7.18+YYYYMMDD-<target-triple>-install_only.tar.gz
   cd python
   ```

2. Run Python directly (no environment setup required):
   ```cmd
   python.exe --version
   python.exe script.py
   ```

   **Note**: The distribution follows python-build-standalone layout with `python.exe` and `python27.dll` in the same directory, so Python works immediately without PATH setup. PYTHONHOME is usually auto-detected, but can be set manually if needed:

   ```cmd
   set PYTHONHOME=%CD%
   ```

## Building from Source

### Prerequisites

#### Linux (glibc builds)
```bash
sudo apt-get install build-essential libssl-dev libffi-dev \
    libsqlite3-dev libbz2-dev libreadline-dev zlib1g-dev
```

#### Linux (musl builds)
```bash
# musl builds compile ALL dependencies from source
sudo apt-get install build-essential curl clang
bash scripts/setup-musl.sh      # Builds musl-clang from source
bash scripts/build-musl-deps.sh # Builds all dependencies
```

#### macOS
```bash
brew install openssl@1.1 readline sqlite3 xz zlib
```

#### Windows
- Visual Studio 2019 or later
- Cygwin (for build tools)

### Build Commands

#### Linux
```bash
export TARGET_ARCH=x86_64        # or i686
export TARGET_LIBC=glibc         # or musl
export TARGET_TRIPLE=x86_64-unknown-linux-gnu
bash scripts/build-linux.sh
bash scripts/package.sh
```

#### macOS
```bash
export TARGET_ARCH=x86_64        # or arm64
export TARGET_TRIPLE=x86_64-apple-darwin
bash scripts/build-macos.sh
bash scripts/package.sh
```

#### Windows
```cmd
REM Supported: x86_64, i686 (x86)
set TARGET_ARCH=x86_64
set TARGET_TRIPLE=x86_64-pc-windows-msvc
scripts\build-windows.bat
scripts\package.bat
```

## GitHub Actions Workflow

This project uses a **unified matrix build strategy** in GitHub Actions to automatically build Python 2.7 for all supported platforms.

### Triggering Builds

- **Push to main/master**: Builds all platforms
- **Pull Request**: Builds all platforms for testing
- **Tag push** (v*): Builds and creates a GitHub release
- **Manual trigger**: Via workflow_dispatch

### Unified Matrix Strategy

The workflow uses a **single matrix job** that builds all platforms, similar to python-build-standalone:

```yaml
jobs:
  build:
    strategy:
      matrix:
        include:
          # 4 Linux variants (glibc + musl)
          # 2 macOS variants (Intel + ARM)
          # 2 Windows variants (x64 + x86)
```

**Benefits of unified matrix:**
- Single job definition for all platforms
- Consistent build/test/package workflow
- Easier to maintain and extend
- Platform-specific steps use conditionals (`if: matrix.platform == 'linux'`)

**Matrix includes 8 targets:**
- Linux: x86_64 & i686 with glibc and musl (4 targets)
- macOS: x86_64 & arm64 (2 targets)
- Windows: x86_64 & i686 (2 targets)

All builds use **free GitHub runners**:
- `ubuntu-20.04` for all Linux builds
- `macos-12` for Intel Mac builds
- `macos-14` for Apple Silicon builds
- `windows-2019` for all Windows builds

## Project Structure

```
python-2.7/
├── .github/
│   └── workflows/
│       └── build.yml          # Unified matrix CI/CD workflow
├── scripts/
│   ├── setup-linux.sh         # Linux environment setup
│   ├── setup-macos.sh         # macOS environment setup
│   ├── setup-windows.bat      # Windows environment setup
│   ├── apply-patches.sh       # Patch harness system (Unix)
│   ├── apply-patches.bat      # Patch harness system (Windows)
│   ├── build.sh               # Unified build dispatcher
│   ├── build-linux.sh         # Linux build script
│   ├── build-macos.sh         # macOS build script
│   ├── build-windows.bat      # Windows build script
│   ├── create_archive.py      # Archive creation utility
│   ├── package.sh             # Packaging script (Unix)
│   ├── package.bat            # Packaging script (Windows)
│   ├── test.sh                # Test script (Unix)
│   ├── test.bat               # Test script (Windows)
│   ├── test_distribution.py   # Distribution testing utility
│   └── deps/                  # Dependency build scripts
├── patches/                   # Platform-specific patches
│   ├── common/               # Patches for all platforms
│   ├── linux/                # Linux-specific patches
│   ├── macos/                # macOS-specific patches
│   │   └── arm64/           # Apple Silicon patches
│   └── windows/              # Windows-specific patches
├── build-targets.yml          # Build configuration (targets, runners, deps)
├── PATCHES.md                 # Patch system documentation
├── main.py                    # Example Python script
└── README.md                  # This file
```

## Technical Details

### Relocatable Distribution Features

#### Linux
- Uses `$ORIGIN` relative rpath for shared libraries
- Libraries located relative to executable
- No hardcoded paths

#### macOS
- Uses `@loader_path` for library paths
- `install_name_tool` adjusts all dylib references
- Compatible with SIP (System Integrity Protection)

#### Windows
- Self-contained DLLs in application directory
- Uses relative paths via `PYTHONHOME`
- No registry dependencies

### Build Configuration

- **Static Python binary**: The main Python executable is statically linked (does not depend on libpython.so/dylib)
- **Shared extension modules**: Python extension modules (.so/.pyd) are built as shared libraries
- **Release configuration**: All builds use optimized Release configuration (MSVC on Windows, default compiler optimizations on Unix)
- **Relocatable**: No hardcoded paths, uses relative rpath on Linux/macOS

## Patch System

Python 2.7.18 doesn't natively support modern platforms like Apple Silicon. This project includes a **patch harness system** that automatically applies platform-specific fixes:

- **Apple Silicon Support**: Patches configure script to recognize ARM64 architecture
- **Modern Platform Compatibility**: Fixes for newer compilers and libraries
- **Organized by Platform**: Patches are separated by platform, architecture, and environment

See [PATCHES.md](PATCHES.md) for detailed documentation on the patch system.

### Adding Custom Patches

```bash
# Create patch from modified source
diff -Naur Python-2.7.18.orig/ Python-2.7.18/ > patches/platform/arch/fix.patch

# Patches are automatically applied during build
bash scripts/build-linux.sh
```

## Platform-Specific Notes

### Windows ARM64 (Experimental)

Windows ARM64 support is experimental with the following known limitations:

- ❌ **ctypes module unavailable** - libffi does not support ARM64 on Windows
- ❌ **sqlite3 module unavailable** - Requires additional ARM64 build configuration
- ❌ **tkinter unavailable** - Tcl/Tk ARM64 binaries not yet configured
- ✅ Core Python and most standard library modules work correctly

These limitations are due to missing third-party dependencies for ARM64 Windows, not Python itself.

## Why Python 2.7?

While Python 2.7 reached end-of-life in 2020, many legacy applications still depend on it. This project provides:

- Secure, reproducible builds
- Modern build infrastructure
- Easy distribution and deployment
- Support for legacy codebases during migration
- **Modern platform support** (including Apple Silicon)

**Note**: Python 2.7 no longer receives security updates. Please migrate to Python 3.x for new projects.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

### Build System Philosophy

**FAIL FAST - NO TOLERANCE FOR ERRORS**

All build scripts use `set -euo pipefail` and fail immediately on ANY error:
- No defensive checks or warnings
- No "already installed" guards
- No partial failures tolerated
- Scripts stop at the FIRST error

This ensures build errors are IMPOSSIBLE to miss and forces immediate fixing of issues.

### Areas for Improvement

- Optimize build times
- Add more comprehensive tests
- Support additional Python versions
- Fix _ssl module runtime linking on Alpine musl

## License

This project builds Python 2.7, which is licensed under the PSF License. Build scripts and configuration are provided as-is.

See Python's official license: https://docs.python.org/2.7/license.html

## Acknowledgments

This project is inspired by and references [python-build-standalone](https://github.com/astral-sh/python-build-standalone) by Astral.

## Support

For issues, questions, or contributions, please use the [GitHub Issues](../../issues) page.
