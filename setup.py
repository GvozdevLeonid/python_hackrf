import subprocess
import sys
from os import environ, getenv

import numpy
from setuptools import Extension, find_packages, setup
from setuptools.command.build_ext import build_ext

libraries = ['hackrf']

LIBHACKRF_FILES = ['python_hackrf/pylibhackrf/pyhackrf.pyx', 'python_hackrf/pylibhackrf/chackrf.pxd']

INSTALL_REQUIRES = []
SETUP_REQUIRES = []

PLATFORM = sys.platform

if getenv('LIBLINK'):
    PLATFORM = 'android'

if PLATFORM != 'android':
    SETUP_REQUIRES.append('Cython==0.29.37')
    INSTALL_REQUIRES.append('Cython==0.29.37')

    SETUP_REQUIRES.append('numpy')
    INSTALL_REQUIRES.append('numpy')

    cflags = environ.get('CFLAGS', '')
    ldflags = environ.get('LDFLAGS', '')

    if PLATFORM in {'linux', 'darwin'}:
        if environ.get('PYTHON_HACKRF_CFLAGS', None) is None:
            try:
                new_cflags = subprocess.check_output(['pkg-config', '--cflags', 'libhackrf']).decode('utf-8').strip()
            except Exception:
                raise RuntimeError('Unable to run pkg-config. Set cflags manually export PYTHON_HACKRF_CFLAGS=') from None
        else:
            new_cflags = environ.get('PYTHON_HACKRF_CFLAGS', '')

        if environ.get('PYTHON_HACKRF_LDFLAGS', None) is None:
            try:
                new_ldflags = subprocess.check_output(['pkg-config', '--libs', 'libhackrf']).decode('utf-8').strip()
            except Exception:
                raise RuntimeError('Unable to run pkg-config. Set libs manually export PYTHON_HACKRF_LDFLAGS=') from None
        else:
            new_ldflags = environ.get('PYTHON_HACKRF_LDFLAGS', '')

    elif PLATFORM == 'win32':
        pass

    environ['CFLAGS'] = f'{cflags} {new_cflags}'.strip()
    environ['LDFLAGS'] = f'{ldflags} {new_ldflags}'.strip()

else:
    LIBHACKRF_FILES = ['python_hackrf/pylibhackrf/pyhackrf_android.pyx', 'python_hackrf/pylibhackrf/chackrf_android.pxd']

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
            sources=['python_hackrf/pyhackrf_tools/pyhackrf_sweep.pyx'],
            include_dirs=['python_hackrf/pyhackrf_tools', numpy.get_include()],
            extra_compile_args=['-w'],
        ),
        Extension(
            name='python_hackrf.pyhackrf_tools.pyhackrf_transfer',
            sources=['python_hackrf/pyhackrf_tools/pyhackrf_transfer.pyx'],
            include_dirs=['python_hackrf/pyhackrf_tools', numpy.get_include()],
            extra_compile_args=['-w'],
        ),
    ],
    packages=find_packages(),
    package_dir={'': '.'},
    include_package_data=True,
)
