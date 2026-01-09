#!/usr/bin/env python3
"""
Create tar.gz archive with python/ prefix.
Based on python-build-standalone's approach.
"""

import argparse
import os
import sys
import tarfile


def create_tar_from_directory(fh, base_path, path_prefix=None):
    """
    Create a tar archive from a directory with optional path prefix.

    This is the same approach used by python-build-standalone.

    Args:
        fh: File handle to write the tar archive to
        base_path: Source directory to archive
        path_prefix: Optional prefix to prepend to each file path in archive
    """
    with tarfile.open(fileobj=fh, mode='w:gz') as tf:
        for root, dirs, files in os.walk(base_path):
            dirs.sort()

            for f in sorted(files):
                full = os.path.join(root, f)
                rel = os.path.relpath(full, base_path)

                if path_prefix:
                    arcname = os.path.join(path_prefix, rel)
                else:
                    arcname = rel

                tf.add(full, arcname=arcname)


def main():
    parser = argparse.ArgumentParser(
        description='Create tar.gz archive with optional path prefix'
    )
    parser.add_argument(
        'source_dir',
        help='Source directory to archive'
    )
    parser.add_argument(
        'output_file',
        help='Output tar.gz file path'
    )
    parser.add_argument(
        '--prefix',
        default=None,
        help='Path prefix to add to all files in archive (e.g., "python")'
    )

    args = parser.parse_args()

    # Validate source directory exists
    if not os.path.isdir(args.source_dir):
        print(f"ERROR: Source directory does not exist: {args.source_dir}", file=sys.stderr)
        return 1

    # Create output directory if needed
    output_dir = os.path.dirname(args.output_file)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)

    # Create the archive
    print(f"Creating archive: {args.output_file}")
    print(f"  Source: {args.source_dir}")
    if args.prefix:
        print(f"  Prefix: {args.prefix}/")

    try:
        with open(args.output_file, 'wb') as fh:
            create_tar_from_directory(fh, args.source_dir, path_prefix=args.prefix)
        print(f"✓ Archive created successfully")

        # Show size
        size = os.path.getsize(args.output_file)
        size_mb = size / (1024 * 1024)
        print(f"  Size: {size_mb:.2f} MB")

        return 0
    except Exception as e:
        print(f"ERROR: Failed to create archive: {e}", file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
