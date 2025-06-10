import subprocess  # noqa I001
import sys
from os import environ, getenv, path

import numpy
from setuptools import Extension, find_packages, setup
from setuptools.command.build_ext import build_ext
from setuptools.command.install import install
from Cython.Build import cythonize

INSTALL_REQUIRES = ['Cython>=3.1.0,<3.2', 'numpy']
SETUP_REQUIRES = ['Cython>=3.1.0,<3.2', 'numpy']
libhackrf_h_paths = []

PLATFORM = sys.platform

if getenv('LIBLINK'):
    PLATFORM = 'android'

if PLATFORM != 'android':
    cflags = environ.get('CFLAGS', '')
    ldflags = environ.get('LDFLAGS', '')
    new_cflags = ''
    new_ldflags = ''

    if PLATFORM in {'linux', 'darwin'}:
        if environ.get('PYTHON_HACKRF_CFLAGS', None) is None:
            try:
                new_cflags = subprocess.check_output(['pkg-config', '--cflags', 'libhackrf']).decode('utf-8').strip()
                libhackrf_h_paths = [new_cflag[2:] for new_cflag in new_cflags.split()]
            except Exception:
                raise RuntimeError('Unable to run pkg-config. Set cflags manually export PYTHON_HACKRF_CFLAGS=') from None
        else:
            new_cflags = environ.get('PYTHON_HACKRF_CFLAGS', '')
            libhackrf_h_paths = [new_cflag[2:] for new_cflag in new_cflags.split()]

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
        libhackrf_h_paths = [include_path]

        if environ.get('PYTHON_HACKRF_INCLUDE_PATH', None) is None:
            new_cflags = f'-I"{include_path}"'
        else:
            include_path = environ.get('PYTHON_HACKRF_INCLUDE_PATH', '')
            libhackrf_h_paths = [include_path]
            new_cflags = f'-I"{include_path}"'

        if environ.get('PYTHON_HACKRF_LIB_PATH', None) is None:
            new_ldflags = f'-L"{lib_path}" -lhackrf'
        else:
            lib_path = environ.get('PYTHON_HACKRF_LIB_PATH', '')
            new_ldflags = f'-L"{lib_path}" -lhackrf'

        environ['CL'] = f'/I"{include_path}"'
        environ['LINK'] = f'/LIBPATH:"{lib_path}" hackrf.lib'

    environ['CFLAGS'] = f'{cflags} {new_cflags}'.strip()
    environ['LDFLAGS'] = f'{ldflags} {new_ldflags}'.strip()

else:
    libhackrf_h_paths = [environ.get('PYTHON_HACKRF_LIBHACKRF_H_PATH', '')]


class CustomBuildExt(build_ext):
    def run(self) -> None:  # type: ignore
        compile_env = {'ANDROID': PLATFORM == 'android'}
        self.distribution.ext_modules = cythonize(  # type: ignore
            self.distribution.ext_modules,
            compile_time_env=compile_env,
        )
        super().run()  # type: ignore


class InstallWithPth(install):
    def run(self) -> None:  # type: ignore
        super().run()  # type: ignore

        if PLATFORM.startswith('win'):
            pth_code = (
                'import os; '
                'os.add_dll_directory(os.getenv("HACKRF_LIB_DIR", r"C:\\Program Files\\HackRF\\lib"))'
            )
            with open(path.join(self.install_lib, "python_hackrf.pth"), mode='w', encoding='utf-8') as file:  # type: ignore
                file.write(pth_code)


setup(  # type: ignore
    name='python_hackrf',
    cmdclass={'build_ext': CustomBuildExt, 'install': InstallWithPth},
    install_requires=INSTALL_REQUIRES,
    setup_requires=SETUP_REQUIRES,
    ext_modules=[
        Extension(  # type: ignore
            name='python_hackrf.pylibhackrf.pyhackrf',
            sources=['python_hackrf/pylibhackrf/pyhackrf.pyx'],
            include_dirs=['python_hackrf/pylibhackrf', *libhackrf_h_paths, numpy.get_include()],
            extra_compile_args=['-w'],
            language='c++',
        ),
        Extension(  # type: ignore
            name='python_hackrf.pyhackrf_tools.pyhackrf_sweep',
            sources=['python_hackrf/pyhackrf_tools/pyhackrf_sweep.pyx'],
            include_dirs=['python_hackrf/pylibhackrf', 'python_hackrf/pyhackrf_tools', *libhackrf_h_paths, numpy.get_include()],
            extra_compile_args=['-w'],
            language='c++',
        ),
        Extension(  # type: ignore
            name='python_hackrf.pyhackrf_tools.pyhackrf_transfer',
            sources=['python_hackrf/pyhackrf_tools/pyhackrf_transfer.pyx'],
            include_dirs=['python_hackrf/pylibhackrf', 'python_hackrf/pyhackrf_tools', *libhackrf_h_paths, numpy.get_include()],
            extra_compile_args=['-w'],
            language='c++',
        ),
    ],
    include_package_data=True,
    packages=find_packages(),
    package_dir={'': '.'},
    zip_safe=False,
)
