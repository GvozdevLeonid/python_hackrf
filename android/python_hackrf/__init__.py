# ruff: noqa: RUF012
import os
from typing import Any

from pythonforandroid.archs import Arch
from pythonforandroid.recipe import (
    PyProjectRecipe,
    Recipe,
)


class PythonHackrfRecipe(PyProjectRecipe):
    url = 'https://github.com/GvozdevLeonid/python_hackrf/releases/download/v.{version}/python_hackrf-{version}.tar.gz'
    depends = ['python3', 'setuptools', 'numpy', 'pyjnius', 'libhackrf']
    hostpython_prerequisites = ['Cython>=3.1.0,<3.2']
    site_packages_name = 'python_hackrf'
    name = 'python_hackrf'
    version = '1.4.0'

    def get_recipe_env(self, arch: Arch, **kwargs) -> dict[str, Any]:
        env: dict[str, Any] = super().get_recipe_env(arch, **kwargs)

        libhackrf_recipe = Recipe.get_recipe('libhackrf', arch)
        libhackrf_h_dir = os.path.join(libhackrf_recipe.get_build_dir(arch), 'host', 'libhackrf', 'src')

        env['LDFLAGS'] = env['LDFLAGS'] + f' -L{self.ctx.get_libs_dir(arch.arch)} -lhackrf'
        env['CFLAGS'] = env['CFLAGS'] + f' -I{libhackrf_h_dir}'

        env['PYTHON_BLADERF_LIBBLADERF_H_PATH'] = libhackrf_h_dir
        env['LDSHARED'] = env['CC'] + ' -shared'
        env['LIBLINK'] = 'NOTNONE'

        return env


recipe = PythonHackrfRecipe()
