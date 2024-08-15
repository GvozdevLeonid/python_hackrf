from os import getenv, environ
import sys

from setuptools import setup, Extension, find_packages
from setuptools.command.build_ext import build_ext
import numpy

libraries = ['usb-1.0', 'hackrf']

LIBHACKRF_FILES = ['python_hackrf/pylibhackrf/pyhackrf.pyx', 'python_hackrf/pylibhackrf/chackrf.pxd']
PYHACKRF_TOOLS_FILES = ['python_hackrf/pyhackrf_tools/pyhackrf_sweep.pyx']

INSTALL_REQUIRES = []
SETUP_REQUIRES = []

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
        new_cflags = '-I/opt/homebrew/include/libusb-1.0 -I/opt/homebrew/include/libhackrf'
        new_ldflags = '-L/opt/homebrew/lib'
    elif PLATFORM.startswith('linux'):
        new_cflags = '-I/usr/include/libusb-1.0 -I/usr/include/libhackrf'
        new_ldflags = '-L/usr/lib64 -L/usr/lib'
    elif PLATFORM == 'win32':
        pass

    environ['CFLAGS'] = f'{cflags} {new_cflags}'.strip()
    environ['LDFLAGS'] = f'{ldflags} {new_ldflags}'.strip()

else:
    libraries = ['usb1.0', 'hackrf']
    LIBHACKRF_FILES = ['python_hackrf/pylibhackrf/pyhackrf_android.pyx', 'python_hackrf/pylibhackrf/chackrf_android.pxd', 'python_hackrf/pylibhackrf/hackrf.c']

setup(
    name='python_hackrf',
    cmdclass={'build_ext': build_ext},
    install_requires=INSTALL_REQUIRES,
    setup_requires=SETUP_REQUIRES,
    ext_modules=[
        Extension(
            name='python_hackrf.pylibhackrf.pyhackrf',
            sources=LIBHACKRF_FILES,
            libraries=libraries,
            include_dirs=['python_hackrf/pylibhackrf', numpy.get_include()],
            extra_compile_args=['-w'],
        ),
        Extension(
            name='python_hackrf.pyhackrf_tools.pyhackrf_sweep',
            sources=PYHACKRF_TOOLS_FILES,
            include_dirs=['python_hackrf/pyhackrf_tools', numpy.get_include()],
            extra_compile_args=['-w'],
        )
    ],
    packages=find_packages(),
    package_dir={'': '.'},
    include_package_data=True,
)
