from pythonforandroid.recipe import CythonRecipe  # type: ignore
from pythonforandroid.recipe import Recipe  # type: ignore
import shutil
import os


class PythonHackrfRecipe(CythonRecipe):
    version = '1.1.0'
    url = 'https://github.com/GvozdevLeonid/python_hackrf/releases/download/v.{version}/python_hackrf-{version}.tar.gz'
    depends = ['python3', 'setuptools', 'libusb', 'numpy']
    site_packages_name = 'python_hackrf'
    name = 'python_hackrf'

    def get_recipe_env(self, arch):
        env = super().get_recipe_env(arch)

        libusb_recipe = Recipe.get_recipe('libusb', arch)
        h_dir = os.path.join(libusb_recipe.get_build_dir(arch), 'libusb')
        so_dir = libusb_recipe.get_lib_dir(arch)

        env['CFLAGS'] += ' -I' + h_dir
        env['LDFLAGS'] += ' -L' + so_dir
        return env

    def postbuild_arch(self, arch):
        super().postbuild_arch(arch)

        python_hackrf_dir = os.path.join(self.ctx.get_python_install_dir(arch.arch), 'python_hackrf')
        os.makedirs(python_hackrf_dir, exist_ok=True)
        try:
            shutil.move(os.path.join(self.ctx.get_python_install_dir(arch.arch), 'pylibhackrf'), os.path.join(python_hackrf_dir, 'pylibhackrf'))
            shutil.move(os.path.join(self.ctx.get_python_install_dir(arch.arch), 'pyhackrf_tools'), os.path.join(python_hackrf_dir, 'pyhackrf_tools'))

            shutil.copy(os.path.join(self.get_build_dir(arch.arch), '__init__.py'), python_hackrf_dir)
            shutil.copy(os.path.join(self.get_build_dir(arch.arch), '__main__.py'), python_hackrf_dir)
        except FileNotFoundError:
            pass


recipe = PythonHackrfRecipe()
