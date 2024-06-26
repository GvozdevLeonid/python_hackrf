from pathlib import Path
from os import getenv, environ
import sys

from setuptools import setup, Extension, find_packages
from setuptools.command.build_ext import build_ext
import numpy

libraries = ['usb-1.0']

LIBHACKRF_FILES = list(Path('python_hackrf/pylibhackrf').rglob('*.pyx'))
PYHACKRF_TOOLS_FILES = list(Path('python_hackrf/pyhackrf_tools').rglob('*.pyx'))

INSTALL_REQUIRES = []
SETUP_REQUIRES = []
LIBRARY_RELEASE = '2024.02.1'
LIBRARY_VERSION = '0.9'

PLATFORM = sys.platform

if getenv('LIBLINK'):
    PLATFORM = 'android'

# detect cython
if PLATFORM != 'android':
    SETUP_REQUIRES.append('cython==0.29.36')
    INSTALL_REQUIRES.append('cython==0.29.36')
    INSTALL_REQUIRES.append('numpy>=1.26')

    cflags = environ.get('CFLAGS', '')
    ldflags = environ.get('LDFLAGS', '')

    if PLATFORM == 'darwin':
        new_cflags = '-I/opt/homebrew/include/libusb-1.0'
        new_ldflags = '-L/opt/homebrew/lib'
    elif PLATFORM.startswith('linux'):
        new_cflags = '-I/usr/include/libusb-1.0'
        new_ldflags = '-L/usr/lib64 -L/usr/lib'
    elif PLATFORM == 'win32':
        pass

    environ['CFLAGS'] = f'{cflags} {new_cflags}'.strip()
    environ['LDFLAGS'] = f'{ldflags} {new_ldflags}'.strip()

else:
    libraries = ['usb1.0']
    LIBHACKRF_FILES = [fn.with_suffix('.c') for fn in LIBHACKRF_FILES]

source_files = [str(fn) for fn in LIBHACKRF_FILES]
source_files.append('python_hackrf/pylibhackrf/hackrf.c')

setup(
    name='python_hackrf',
    cmdclass={'build_ext': build_ext},
    install_requires=INSTALL_REQUIRES,
    setup_requires=SETUP_REQUIRES,
    ext_modules=[
        Extension(
            name='python_hackrf.pylibhackrf.pyhackrf',
            sources=source_files,
            libraries=libraries,
            include_dirs=['python_hackrf/pylibhackrf', numpy.get_include()],
            define_macros=[("LIBRARY_VERSION", f'"{LIBRARY_VERSION}"'), ("LIBRARY_RELEASE", f'"{LIBRARY_RELEASE}"')],
            extra_compile_args=['-w'],
        ),
        Extension(
            name='python_hackrf.pyhackrf_tools.pyhackrf_sweep',
            sources=[str(fn) for fn in PYHACKRF_TOOLS_FILES],
            include_dirs=['python_hackrf/pyhackrf_tools', numpy.get_include()],
            extra_compile_args=['-w'],
        )
    ],
    packages=find_packages(),
    package_dir={'': '.'},
    include_package_data=True,
)
