#!/usr/bin/env python3
"""
Test Python distribution.
Based on python-build-standalone's testing approach.
Works across Linux, macOS, and Windows.
"""

import argparse
import os
import platform
import shutil
import subprocess
import sys
import tempfile


class DistributionTester:
    def __init__(self, python_dir):
        self.python_dir = python_dir
        self.is_windows = platform.system() == 'Windows'
        self.passed_tests = 0
        self.total_tests = 0

        # Determine Python executable path
        if self.is_windows:
            # Windows: python.exe is in root (python-build-standalone layout)
            self.python_exe = os.path.join(python_dir, 'python.exe')
            if not os.path.exists(self.python_exe):
                raise FileNotFoundError(f"python.exe not found at {self.python_exe}")
        else:
            # Unix: python is in bin/
            self.python_exe = os.path.join(python_dir, 'bin', 'python')
            if not os.path.exists(self.python_exe):
                raise FileNotFoundError(f"python binary not found at {self.python_exe}")

    def run_test(self, test_name, test_func):
        """Run a test and track results."""
        self.total_tests += 1
        print(f"\n=== Test {self.total_tests}: {test_name} ===")
        try:
            test_func()
            print(f"PASS: {test_name}")
            self.passed_tests += 1
            return True
        except Exception as e:
            print(f"FAIL: {test_name}")
            print(f"Error: {e}")
            return False

    def run_python(self, *args, check=True, capture_output=True):
        """Run Python with given arguments."""
        # Set up environment for Windows
        env = os.environ.copy()
        if self.is_windows:
            # Add DLLs directory to PATH for .pyd extension modules
            # Note: python27.dll is now in root with python.exe, so no PATH needed for that
            dlls_dir = os.path.join(self.python_dir, 'DLLs')
            if os.path.exists(dlls_dir):
                env['PATH'] = dlls_dir + os.pathsep + env.get('PATH', '')

            # Set PYTHONHOME to the distribution directory (usually auto-detected)
            env['PYTHONHOME'] = self.python_dir

            # Set Tcl/Tk library paths if they exist
            tcl_dir = os.path.join(self.python_dir, 'tcl')
            if os.path.exists(tcl_dir):
                env['TCL_LIBRARY'] = os.path.join(tcl_dir, 'tcl8.6')
                env['TK_LIBRARY'] = os.path.join(tcl_dir, 'tk8.6')

        result = subprocess.run(
            [self.python_exe] + list(args),
            capture_output=capture_output,
            text=True,
            check=False,
            env=env
        )
        if check and result.returncode != 0:
            raise RuntimeError(
                f"Python command failed with exit code {result.returncode}\n"
                f"stdout: {result.stdout}\n"
                f"stderr: {result.stderr}"
            )
        return result

    def test_directory_structure(self):
        """Test that all required directories exist."""
        if self.is_windows:
            # Windows structure (python-build-standalone layout)
            required_dirs = {
                'Lib': 'Lib',
                'DLLs': 'DLLs',
                'Scripts': 'Scripts',
                'include': 'include',
                'libs': 'libs',
            }
        else:
            # Unix structure
            required_dirs = {
                'bin': 'bin',
                'lib': 'lib',
                'include': 'include',
            }

        for name, dirname in required_dirs.items():
            if dirname is None:
                continue
            path = os.path.join(self.python_dir, dirname)
            if not os.path.isdir(path):
                raise AssertionError(f"{name} directory not found at {path}")

    def test_python_version(self):
        """Test Python binary and version."""
        result = self.run_python('--version')
        version_output = result.stdout + result.stderr

        if '2.7.18' not in version_output:
            raise AssertionError(f"Expected version 2.7.18, got: {version_output}")

        # Test basic execution
        result = self.run_python('-c', "print('Python binary: OK')")
        if 'Python binary: OK' not in result.stdout:
            raise AssertionError("Basic Python execution failed")

    def test_python_symlinks(self):
        """Test Python symlinks (Unix only)."""
        if self.is_windows:
            print("Skipping symlink test on Windows")
            return

        python2_path = os.path.join(self.python_dir, 'bin', 'python2')
        if os.path.exists(python2_path):
            result = subprocess.run(
                [python2_path, '--version'],
                capture_output=True,
                text=True
            )
            if result.returncode != 0:
                raise AssertionError("python2 symlink is broken")
        else:
            print("INFO: python2 symlink not found (optional)")

    def test_standard_library(self):
        """Test standard library module imports."""
        # Core modules that must work on all platforms
        core_modules = [
            'sys', 'os', 'json', 're', 'io', 'struct', 'array',
            'math', 'cmath', 'itertools', 'functools', 'collections',
            'datetime', 'time', 'random', 'hashlib', 'binascii',
            'base64', 'pickle', 'csv', 'xml.etree.ElementTree',
            'sqlite3', 'zlib', 'gzip', 'zipfile', 'tarfile',
            'socket', 'threading', 'subprocess', 'unicodedata',
            'codecs', 'locale', 'tempfile', 'shutil', 'glob',
            'fnmatch', 'logging', 'traceback', 'errno',
        ]

        # Add platform-specific modules
        if not self.is_windows:
            core_modules.extend(['select', 'signal'])

        failed_modules = []
        for module in core_modules:
            result = self.run_python(
                '-c', f"import {module}; print('{module}: OK')",
                check=False
            )
            if result.returncode != 0:
                failed_modules.append(module)
            else:
                print(f"  {module}: OK")

        if failed_modules:
            raise AssertionError(f"Failed to import modules: {', '.join(failed_modules)}")

        # Test optional modules
        optional_modules = ['bz2', 'ssl', 'readline']
        for module in optional_modules:
            result = self.run_python(
                '-c', f"import {module}; print('{module}: OK')",
                check=False
            )
            if result.returncode != 0:
                print(f"  WARNING: {module} module not available (optional)")

    def test_c_extensions(self):
        """Test that critical C extension modules work."""
        # Test _ctypes (critical for many packages)
        result = self.run_python('-c', "import _ctypes; print('_ctypes: OK')")
        if '_ctypes: OK' not in result.stdout:
            raise AssertionError("_ctypes module not available")

        # Test ctypes functionality
        test_code = """
import ctypes
c_int = ctypes.c_int(42)
assert c_int.value == 42, 'ctypes.c_int failed'
print('ctypes functionality: OK')
"""
        result = self.run_python('-c', test_code)
        if 'ctypes functionality: OK' not in result.stdout:
            raise AssertionError("ctypes functionality test failed")

    def test_python_paths(self):
        """Test Python paths are set correctly."""
        test_code = """
import sys
print('sys.executable:', sys.executable)
print('sys.prefix:', sys.prefix)
print('sys.exec_prefix:', sys.exec_prefix)
print('sys.path:')
for p in sys.path:
    print('  ', p)
"""
        self.run_python('-c', test_code, capture_output=False)

    def test_relocatability(self):
        """Test that Python works when moved to a different location."""
        # Create temporary directory for testing
        moved_dir = tempfile.mkdtemp(prefix='python-moved-')

        try:
            print(f"Copying Python to new location: {moved_dir}")

            # Copy entire directory
            if self.is_windows:
                # Use shutil.copytree on Windows
                dest = os.path.join(moved_dir, 'python')
                shutil.copytree(self.python_dir, dest)
            else:
                # Use shutil.copytree on Unix too
                dest = os.path.join(moved_dir, 'python')
                shutil.copytree(self.python_dir, dest)

            # Determine Python executable in new location
            if self.is_windows:
                # Windows: python.exe in root
                moved_python = os.path.join(dest, 'python.exe')
            else:
                # Unix: python in bin/
                moved_python = os.path.join(dest, 'bin', 'python')

            # Test from new location
            print(f"Testing from: {dest}")

            # Set up environment for Windows
            env = os.environ.copy()
            if self.is_windows:
                dlls_dir = os.path.join(dest, 'DLLs')
                if os.path.exists(dlls_dir):
                    env['PATH'] = dlls_dir + os.pathsep + env.get('PATH', '')
                env['PYTHONHOME'] = dest
                tcl_dir = os.path.join(dest, 'tcl')
                if os.path.exists(tcl_dir):
                    env['TCL_LIBRARY'] = os.path.join(tcl_dir, 'tcl8.6')
                    env['TK_LIBRARY'] = os.path.join(tcl_dir, 'tk8.6')

            result = subprocess.run(
                [moved_python, '--version'],
                capture_output=True,
                text=True,
                env=env
            )
            if result.returncode != 0:
                raise AssertionError(f"Python failed in new location: {result.stderr}")

            result = subprocess.run(
                [moved_python, '-c', "print('Relocatability: OK')"],
                capture_output=True,
                text=True,
                env=env
            )
            if 'Relocatability: OK' not in result.stdout:
                raise AssertionError("Relocatability test failed")

            print("Python works correctly from new location")
        finally:
            # Cleanup
            shutil.rmtree(moved_dir, ignore_errors=True)

    def test_static_linking(self):
        """Test that Python binary is statically linked (Unix/macOS only)."""
        if self.is_windows:
            print("Skipping static linking test on Windows")
            return

        if platform.system() == 'Darwin':
            # macOS - use otool
            result = subprocess.run(
                ['otool', '-L', self.python_exe],
                capture_output=True,
                text=True
            )
            if 'libpython' in result.stdout:
                print("WARNING: Python binary references libpython (dynamically linked)")
                print("This may cause issues with virtualenv")
                for line in result.stdout.splitlines():
                    if 'libpython' in line:
                        print(f"  {line.strip()}")
            else:
                print("Python binary is statically linked (no libpython dependency)")
        else:
            # Linux - use ldd
            result = subprocess.run(
                ['ldd', self.python_exe],
                capture_output=True,
                text=True
            )
            if 'libpython' in result.stdout:
                print("WARNING: Python binary references libpython (dynamically linked)")
                print("This may cause issues with relocatability")
                for line in result.stdout.splitlines():
                    if 'libpython' in line:
                        print(f"  {line.strip()}")
            else:
                print("Python binary is statically linked (no libpython dependency)")

    def test_c_headers(self):
        """Test that C extension development headers are present."""
        if self.is_windows:
            header_path = os.path.join(self.python_dir, 'include', 'Python.h')
        else:
            header_path = os.path.join(self.python_dir, 'include', 'python2.7', 'Python.h')

        if os.path.exists(header_path):
            print(f"Python.h found at {header_path}")
            print("C extension development is supported")
        else:
            print("WARNING: Python.h not found")
            print("C extension development may not be supported")

    def test_script_execution(self):
        """Test executing a Python script."""
        # Create a test script
        script_content = """#!/usr/bin/env python
# -*- coding: utf-8 -*-
import sys
import os
import json

def main():
    print("Python Test Script")
    print("Python version:", sys.version)
    print("Platform:", sys.platform)

    # Test basic functionality
    data = {"test": "success", "version": list(sys.version_info[:2])}
    json_str = json.dumps(data, indent=2)
    print("JSON test:", json_str)

    # Test file I/O
    test_file = os.path.join(os.path.dirname(__file__), "test_output.txt")
    with open(test_file, "w") as f:
        f.write("Test output\\n")

    with open(test_file, "r") as f:
        content = f.read()

    print("File I/O test: OK")
    os.remove(test_file)

    print("\\nAll script tests passed!")
    return 0

if __name__ == "__main__":
    sys.exit(main())
"""

        # Write test script
        script_path = os.path.join(tempfile.gettempdir(), 'test_script.py')
        with open(script_path, 'w') as f:
            f.write(script_content)

        try:
            # Execute script
            result = self.run_python(script_path, capture_output=False)
            if result.returncode != 0:
                raise AssertionError("Test script execution failed")
        finally:
            # Cleanup
            if os.path.exists(script_path):
                os.remove(script_path)

    def run_all_tests(self):
        """Run all tests and return success status."""
        tests = [
            ("Verify directory structure", self.test_directory_structure),
            ("Test Python version", self.test_python_version),
            ("Test Python symlinks", self.test_python_symlinks),
            ("Test standard library imports", self.test_standard_library),
            ("Test C extensions", self.test_c_extensions),
            ("Check Python paths", self.test_python_paths),
            ("Test relocatability", self.test_relocatability),
            ("Check static linking", self.test_static_linking),
            ("Test C extension headers", self.test_c_headers),
            ("Run test script", self.test_script_execution),
        ]

        for test_name, test_func in tests:
            self.run_test(test_name, test_func)

        # Print summary
        print("\n" + "=" * 50)
        if self.passed_tests == self.total_tests:
            print("=== ALL TESTS PASSED SUCCESSFULLY ===")
            print("=" * 50)
            print(f"\nPassed: {self.passed_tests}/{self.total_tests}")
            print(f"Python directory: {self.python_dir}")
            print("\nThe Python distribution is working correctly!")
            return 0
        else:
            print("=== SOME TESTS FAILED ===")
            print("=" * 50)
            print(f"\nPassed: {self.passed_tests}/{self.total_tests}")
            print(f"Failed: {self.total_tests - self.passed_tests}/{self.total_tests}")
            return 1


def main():
    parser = argparse.ArgumentParser(
        description='Test Python distribution'
    )
    parser.add_argument(
        'python_dir',
        help='Path to extracted Python directory'
    )

    args = parser.parse_args()

    # Validate directory exists
    if not os.path.isdir(args.python_dir):
        print(f"ERROR: Directory does not exist: {args.python_dir}", file=sys.stderr)
        return 1

    print("=" * 50)
    print("Testing Python Distribution")
    print("=" * 50)
    print(f"Directory: {args.python_dir}")
    print(f"Platform: {platform.system()}")
    print(f"Architecture: {platform.machine()}")

    try:
        tester = DistributionTester(args.python_dir)
        return tester.run_all_tests()
    except Exception as e:
        print(f"\nERROR: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return 1


if __name__ == '__main__':
    sys.exit(main())
