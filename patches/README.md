# Python 2.7 Patches

This directory contains patches for Python 2.7.18 to support modern platforms and fix build issues.

## Patch Organization

Patches are organized by platform and applied automatically during the build process:

```
patches/
├── common/           # Patches for all platforms
├── linux/            # Linux-specific patches
│   ├── glibc/       # glibc-specific
│   └── musl/        # musl-specific
├── macos/            # macOS-specific patches
│   ├── x86_64/      # Intel Mac patches
│   └── arm64/       # Apple Silicon patches
└── windows/          # Windows-specific patches
```

## Patch Format

All patches are in unified diff format (created with `diff -u` or `git diff`).

## Creating Patches

1. Download and extract Python 2.7.18 source
2. Make your changes
3. Create a patch:
   ```bash
   diff -Naur Python-2.7.18.orig/ Python-2.7.18/ > patches/<platform>/<name>.patch
   ```

## Applying Patches

Patches are automatically applied by the build scripts using the patch harness system.

The harness applies patches in this order:
1. Common patches (all platforms)
2. Platform-specific patches (linux/macos/windows)
3. Architecture-specific patches (x86_64/arm64/i686)
4. Environment-specific patches (glibc/musl/msvc)

## Available Patches

### macOS ARM64 (Apple Silicon)

- **`macos/arm64/01-configure-arch-detection.patch`**: Fixes configure script to properly detect ARM64 architecture on macOS. Python 2.7 doesn't natively support Apple Silicon.

### Common Patches

(Add more patches here as needed)

## Patch Guidelines

1. **One fix per patch**: Each patch should address one specific issue
2. **Descriptive names**: Use format `NN-description.patch` where NN is sequence number
3. **Documentation**: Add a comment at the top of each patch explaining what it fixes
4. **Testing**: Test patches on target platform before committing
5. **Upstream**: If possible, reference upstream bug reports or discussions
