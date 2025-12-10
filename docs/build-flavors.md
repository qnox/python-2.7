# Python 2.7 Build Flavors

Based on analysis of the python-build-standalone project and UV's requirements, this document outlines the different build flavors we can support for Python 2.7 distributions.

## Current Status

Currently, we build a single flavor that is closest to `install_only` - a complete, relocatable Python installation.

## Possible Build Flavors

### 1. **install_only** (Current - Default)
- **What it is**: Complete Python installation with all files needed to run Python
- **Includes**:
  - Python interpreter binaries (python, python2, python2.7)
  - Standard library (`.py` files and compiled `.pyc` files)
  - Dynamic libraries (`.so` on Unix, `.dylib` on macOS, `.dll` on Windows)
  - C extension modules
  - Include headers for embedding/extending Python
  - Configuration files
- **Size**: ~30-50 MB compressed
- **Use case**: General-purpose Python installation, can be used for development and running Python code
- **Status**: ✅ Currently implemented

### 2. **install_only_stripped** (Recommended Next)
- **What it is**: Same as `install_only` but with debug symbols removed from binaries
- **Differences from install_only**:
  - Binaries are stripped (`strip` command on Unix, `/RELEASE` on Windows)
  - No debug symbols (smaller file size)
  - Cannot debug C extensions or Python interpreter itself
- **Size**: ~20-30 MB compressed (30-40% smaller)
- **Use case**: Production deployments where smaller size matters more than debugging
- **Implementation**: Add `strip` step after build for Unix, use `/RELEASE` for Windows
- **Status**: ⏳ Not implemented

### 3. **shared-pgo** (Profile-Guided Optimization)
- **What it is**: Python built with Profile-Guided Optimizations for better performance
- **Build process**:
  1. Build Python with instrumentation enabled (`--enable-optimizations`)
  2. Run test suite to generate profiling data
  3. Rebuild Python using profiling data to optimize hot paths
- **Benefits**:
  - 10-20% faster execution for typical workloads
  - Better instruction cache utilization
  - Optimized branch predictions
- **Drawbacks**:
  - Much longer build time (3-4x normal build)
  - Slightly larger binaries
- **Size**: ~35-55 MB compressed
- **Use case**: Production environments where performance matters
- **Status**: ❌ Not implemented (requires significant build changes)

### 4. **shared-noopt** (No Optimizations)
- **What it is**: Python built without compiler optimizations (`-O0`)
- **Benefits**:
  - Faster compilation
  - Better for debugging (more accurate stack traces, step through code)
- **Drawbacks**:
  - Slower runtime performance (2-3x slower)
- **Size**: ~40-60 MB compressed (larger due to no optimization)
- **Use case**: Development, debugging Python interpreter issues
- **Status**: ❌ Not implemented

### 5. **static-noopt** (Statically Linked)
- **What it is**: Python with all dependencies statically linked into binaries
- **Benefits**:
  - No external library dependencies
  - Works on systems with different libc versions
  - Truly portable single-file binaries
- **Drawbacks**:
  - Much larger binaries
  - Cannot load C extension modules dynamically
  - Limited extensibility
- **Size**: ~60-100 MB compressed
- **Use case**: Embedded systems, containers where minimal dependencies are critical
- **Status**: ❌ Not implemented (requires major build changes)

### 6. **debug-full** (Debug Build)
- **What it is**: Python built with debug symbols and runtime checks
- **Build flags**: `--with-pydebug`, `-g -O0`
- **Includes**:
  - Debug assertions enabled
  - Reference counting checks
  - Memory allocation tracking
  - Detailed debug symbols
- **Size**: ~80-120 MB compressed
- **Use case**: CPython core development, debugging interpreter bugs
- **Status**: ❌ Not implemented

## Recommended Implementation Priority

### Phase 1: Essential (Next Steps)
1. **install_only_stripped** - Most requested, easy to implement
   - Add strip step to build scripts
   - Test that stripping doesn't break functionality
   - Update packaging to create separate archives

### Phase 2: Performance (Future)
2. **shared-pgo** - Significant performance benefit for production use
   - Requires modifying configure flags
   - Need to run test suite during build
   - Longer CI build times

### Phase 3: Specialized (Optional)
3. **shared-noopt** - Useful for debugging
4. **debug-full** - Only for Python core developers
5. **static-noopt** - Complex, limited use cases

## Implementation Notes

### Flavor Naming Convention
Follow python-build-standalone convention:
```
cpython-2.7.18+{date}-{triple}-{flavor}.tar.gz
```

Examples:
- `cpython-2.7.18+20241204-x86_64-unknown-linux-gnu-install_only.tar.gz`
- `cpython-2.7.18+20241204-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz`
- `cpython-2.7.18+20241204-x86_64-unknown-linux-gnu-pgo.tar.gz`

### Build Matrix Expansion
Current: 8 platform builds × 1 flavor = 8 artifacts
With 2 flavors: 8 platform builds × 2 flavors = 16 artifacts

### Storage Considerations
GitHub has 500 MB per file limit and reasonable storage for releases.
With 2 flavors at ~30 MB each: 8 platforms × 2 × 30 MB = ~480 MB per release (acceptable)

## Compatibility with UV/uv-python

UV provides these flavors for Python 3:
- `install_only` ✅ We support this
- `install_only_stripped` ⏳ Easy to add
- `shared-pgo` ❌ Complex to add
- `shared-noopt` ❌ Complex to add
- `static-noopt` ❌ Very complex

For Python 2.7 compatibility with UV's ecosystem, we should prioritize:
1. `install_only` (done)
2. `install_only_stripped` (next)

## References

- [python-build-standalone distributions](https://github.com/indygreg/python-build-standalone/blob/main/docs/distributions.rst)
- [python-build-standalone building](https://github.com/indygreg/python-build-standalone/blob/main/docs/building.rst)
- [UV Python distributions](https://github.com/astral-sh/uv)
