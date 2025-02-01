import os

from pythonforandroid.archs import Arch
from pythonforandroid.recipe import (
    CythonRecipe,
    Recipe,
)


class PythonHackrfRecipe(CythonRecipe):
    url = 'https://github.com/GvozdevLeonid/python_hackrf/releases/download/v.{version}/python_hackrf-{version}.tar.gz'
    depends = ('python3', 'setuptools', 'numpy', 'pyjnius', 'libhackrf')
    site_packages_name = 'python_hackrf'
    name = 'python_hackrf'
    version = '1.2.7'

    def get_recipe_env(self, arch: Arch) -> dict:
        env = super().get_recipe_env(arch)

        libhackrf_recipe = Recipe.get_recipe('libhackrf', arch)

        libhackrf_h_dir = os.path.join(libhackrf_recipe.get_build_dir(arch), 'host', 'libhackrf', 'src')

        env['LDFLAGS'] += f' -L{self.ctx.get_libs_dir(arch.arch)}'
        env['CFLAGS'] += f' -I{libhackrf_h_dir}'

        return env


recipe = PythonHackrfRecipe()
