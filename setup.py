import subprocess
import sys
from os import environ, getenv, path

import numpy
from setuptools import Extension, find_packages, setup
from setuptools.command.build_ext import build_ext
from setuptools.command.install import install
from Cython.Build import cythonize

libraries = ['hackrf']

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

    elif PLATFORM.startswith('win'):
        include_path = 'C:\\Program Files\\HackRF\\include'
        lib_path = 'C:\\Program Files\\HackRF\\lib'

        if environ.get('PYTHON_HACKRF_CFLAGS', None) is None:
            new_cflags = f'-I"{include_path}"'
        else:
            new_cflags = environ.get('PYTHON_HACKRF_CFLAGS', '')

        if environ.get('PYTHON_HACKRF_LDFLAGS', None) is None:
            new_ldflags = f'-L"{lib_path}" -lhackrf'
        else:
            new_ldflags = environ.get('PYTHON_HACKRF_LDFLAGS', '')

        environ['CL'] = f'/I"{include_path}"'
        environ['LINK'] = f'/LIBPATH:"{lib_path}" hackrf.lib'

    environ['CFLAGS'] = f'{cflags} {new_cflags}'.strip()
    environ['LDFLAGS'] = f'{ldflags} {new_ldflags}'.strip()


class CustomBuildExt(build_ext):
    def run(self) -> None:
        compile_env = {'ANDROID': PLATFORM == 'android'}
        self.distribution.ext_modules = cythonize(
            self.distribution.ext_modules,
            compile_time_env=compile_env,
        )
        super().run()


class InstallWithPth(install):
    def run(self) -> None:
        super().run()

        if PLATFORM.startswith('win'):
            pth_code = (
                'import os; '
                'os.add_dll_directory(os.getenv("HACKRF_LIB_DIR", r"C:\\Program Files\\HackRF\\lib"))'
            )
            with open(path.join(self.install_lib, "python_hackrf.pth"), mode='w', encoding='utf-8') as file:
                file.write(pth_code)


setup(
    name='python_hackrf',
    cmdclass={'build_ext': CustomBuildExt, 'install': InstallWithPth},
    install_requires=INSTALL_REQUIRES,
    setup_requires=SETUP_REQUIRES,
    ext_modules=[
        Extension(
            name='python_hackrf.pylibhackrf.pyhackrf',
            sources=['python_hackrf/pylibhackrf/pyhackrf.pyx', 'python_hackrf/pylibhackrf/chackrf.pxd'],
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
    include_package_data=True,
    packages=find_packages(),
    package_dir={'': '.'},
    zip_safe=False,
)
