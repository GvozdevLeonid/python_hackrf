from pythonforandroid.recipe import CythonRecipe  # type: ignore
from pythonforandroid.recipe import Recipe  # type: ignore
import shutil
import os


class PythonHackrfRecipe(CythonRecipe):
    url = 'https://github.com/GvozdevLeonid/python_hackrf/releases/download/v.{version}/python_hackrf-{version}.tar.gz'
    depends = ['python3', 'setuptools', 'numpy', 'libusb', 'libhackrf']
    site_packages_name = 'python_hackrf'
    name = 'python_hackrf'
    version = '1.1.1'

    def get_recipe_env(self, arch):
        env = super().get_recipe_env(arch)

        libhackrf_recipe = Recipe.get_recipe('libhackrf', arch)
        libusb_recipe = Recipe.get_recipe('libusb', arch)

        libhackrf_h_dir = os.path.join(libhackrf_recipe.get_build_dir(arch), 'host', 'libhackrf', 'src')
        libusb_h_dir = os.path.join(libusb_recipe.get_build_dir(arch), 'libusb')

        env['LDFLAGS'] += f' -L{self.ctx.get_libs_dir(arch.arch)}'
        env['CFLAGS'] += f' -I{libusb_h_dir} -I{libhackrf_h_dir}'

        return env

    def prebuild_arch(self, arch):
        super().prebuild_arch(arch)

        if not os.path.exists(os.path.join(self.get_build_dir(arch.arch), 'python_hackrf', 'pylibhackrf', 'hackrf.c')):
            libhackrf_recipe = Recipe.get_recipe('libhackrf', arch)

            shutil.copy(os.path.join(libhackrf_recipe.get_build_dir(arch), 'host', 'libhackrf', 'src', 'hackrf.h'), os.path.join(self.get_build_dir(arch.arch), 'python_hackrf', 'pylibhackrf'))
            shutil.copy(os.path.join(libhackrf_recipe.get_build_dir(arch), 'host', 'libhackrf', 'src', 'hackrf.c'), os.path.join(self.get_build_dir(arch.arch), 'python_hackrf', 'pylibhackrf'))


recipe = PythonHackrfRecipe()
