from os import getenv, environ
import subprocess
import sys

from setuptools import setup, Extension, find_packages
from setuptools.command.build_ext import build_ext
import numpy

libraries = ['hackrf']

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

    if PLATFORM in ('linux', 'darwin'):
        if environ.get('PYTHON_HACKRF_CFLAGS', None) is None:
            try:
                new_cflags = subprocess.check_output(['pkg-config', '--cflags', 'libhackrf']).decode('utf-8').strip()
            except Exception:
                new_cflags = ''
        else:
            new_cflags = environ.get('PYTHON_HACKRF_CFLAGS', '')

        if environ.get('PYTHON_HACKRF_LDFLAGS', None) is None:
            try:
                new_ldflags = subprocess.check_output(['pkg-config', '--libs', 'libhackrf']).decode('utf-8').strip()
            except Exception:
                new_ldflags = ''
        else:
            new_ldflags = environ.get('PYTHON_HACKRF_LDFLAGS', '')

    elif PLATFORM == 'win32':
        if environ.get('PYTHON_HACKRF_CFLAGS', None) is None:
            new_cflags = '/I"C:\\Program Files\\Hackrf\\include"'
        else:
            new_cflags = environ.get('PYTHON_HACKRF_CFLAGS', '')

        if environ.get('PYTHON_HACKRF_LDFLAGS', None) is None:
            new_ldflags = '/LIBPATH"C:\\Program Files\\Hackrf\\lib"'
        else:
            new_ldflags = environ.get('PYTHON_HACKRF_LDFLAGS', '')

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
            sources=PYHACKRF_TOOLS_FILES,
            include_dirs=['python_hackrf/pyhackrf_tools', numpy.get_include()],
            extra_compile_args=['-w'],
        )
    ],
    packages=find_packages(),
    package_dir={'': '.'},
    include_package_data=True,
)
