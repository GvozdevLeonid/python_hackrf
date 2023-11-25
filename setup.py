from pathlib import Path
from os import getenv, environ
import sys

from setuptools import setup, Extension, find_packages
from setuptools.command.build_ext import build_ext

libraries = ['usb-1.0']

FILES = list(Path('python_hackrf/libhackrf').rglob('*.pyx'))

INSTALL_REQUIRES = []
SETUP_REQUIRES = []
LIBRARY_RELEASE = '2023.01.1'
LIBRARY_VERSION = '0.8'

PLATFORM = sys.platform

if getenv('LIBLINK'):
    PLATFORM = 'android'

# detect cython
if PLATFORM != 'android':
    SETUP_REQUIRES.append('cython==0.29.36')
    INSTALL_REQUIRES.append('cython==0.29.36')
    INSTALL_REQUIRES.append('numpy>=1.26')

    if PLATFORM == 'darwin':
        environ["CFLAGS"] = "-I/opt/homebrew/include/libusb-1.0"
        environ["LDFLAGS"] = "-L/opt/homebrew/Cellar/libusb/1.0.26/lib"
    elif PLATFORM.startswith('linux'):
        environ["CFLAGS"] = "-I/usr/include/libusb-1.0"
        environ["LDFLAGS"] = "-L/usr/lib64"
        environ["LDFLAGS"] = "-L/usr/lib"
    elif PLATFORM == 'win32':
        pass
else:
    libraries = ['usb1.0']
    FILES = [fn.with_suffix('.c') for fn in FILES]

source_files = [str(fn) for fn in FILES]
source_files.append('python_hackrf/libhackrf/hackrf.c')

setup(
    name='python_hackrf',
    author='Leonid Gvozdev',
    author_email='leo.gvozdev.dev@gmail.com',
    version='1.0.2',
    cmdclass={'build_ext': build_ext},
    install_requires=INSTALL_REQUIRES,
    setup_requires=SETUP_REQUIRES,
    ext_modules=[
        Extension(
            name='python_hackrf.libhackrf.pyhackrf',
            sources=source_files,
            libraries=libraries,
            include_dirs=['python_hackrf/libhackrf'],
            define_macros=[("LIBRARY_VERSION", f'"{LIBRARY_VERSION}"'), ("LIBRARY_RELEASE", f'"{LIBRARY_RELEASE}"')],
            extra_compile_args=['-w'],
        )
    ],
    packages=find_packages(),
    package_dir={'': '.'}
)
