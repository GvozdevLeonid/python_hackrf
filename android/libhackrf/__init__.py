import os
import shutil

import sh
from pythonforandroid.archs import Arch
from pythonforandroid.logger import shprint
from pythonforandroid.recipe import NDKRecipe, Recipe
from pythonforandroid.util import current_directory


class LibhackrfRecipe(NDKRecipe):

    url = 'https://github.com/greatscottgadgets/hackrf/releases/download/v{version}/hackrf-{version}.tar.xz'
    patches = ('hackrf_android.patch', )
    generated_libraries = ('libhackrf.so', )
    site_packages_name = 'libhackrf'
    version = '2024.02.1'
    library_release = '2024.02.1'
    library_version = '0.9'
    depends = ('libusb', )
    name = 'libhackrf'

    def should_build(self, arch: Arch) -> bool:
        return not os.path.exists(os.path.join(self.ctx.get_libs_dir(arch.arch), 'libhackrf.so'))

    def prebuild_arch(self, arch: Arch) -> None:
        super().prebuild_arch(arch)

        if not os.path.exists(os.path.join(self.get_build_dir(arch.arch), 'android')):
            libusb_recipe = Recipe.get_recipe('libusb', arch)

            os.mkdir(os.path.join(self.get_build_dir(arch.arch), 'android'))
            os.mkdir(os.path.join(self.get_build_dir(arch.arch), 'android', 'jni'))
            os.mkdir(os.path.join(self.get_build_dir(arch.arch), 'android', 'libusb'))

            shutil.copy(os.path.join(self.get_recipe_dir(), 'jni', 'Application.mk'), os.path.join(self.get_build_dir(arch.arch), 'android', 'jni'))
            shutil.copy(os.path.join(self.get_recipe_dir(), 'jni', 'libhackrf.mk'), os.path.join(self.get_build_dir(arch.arch), 'android', 'jni'))
            shutil.copy(os.path.join(self.get_recipe_dir(), 'jni', 'Android.mk'), os.path.join(self.get_build_dir(arch.arch), 'android', 'jni'))

            shutil.copy(os.path.join(libusb_recipe.get_build_dir(arch), 'libusb', 'libusb.h'), os.path.join(self.get_build_dir(arch.arch), 'android', 'libusb'))

    def get_recipe_env(self, arch: Arch) -> dict:
        env = super().get_recipe_env(arch)
        env['LDFLAGS'] += f'-L{self.ctx.get_libs_dir(arch.arch)}'

        return env

    def get_jni_dir(self, arch: Arch) -> str:
        return os.path.join(self.get_build_dir(arch.arch), 'android', 'jni')

    def get_lib_dir(self, arch: Arch) -> str:
        return os.path.join(self.get_build_dir(arch.arch), 'android', 'obj', 'local', arch.arch)

    def build_arch(self, arch: Arch, *extra_args) -> None:
        env = self.get_recipe_env(arch)

        shutil.copyfile(os.path.join(self.ctx.get_libs_dir(arch.arch), 'libusb1.0.so'), os.path.join(self.get_build_dir(arch.arch), 'android', 'jni', 'libusb1.0.so'))

        with current_directory(self.get_build_dir(arch.arch)):
            shprint(
                sh.Command(os.path.join(self.ctx.ndk_dir, 'ndk-build')),
                'NDK_PROJECT_PATH=' + self.get_build_dir(arch.arch) + '/android',
                'APP_PLATFORM=android-' + str(self.ctx.ndk_api),
                'LIBRARY_VERSION=' + self.library_version,
                'LIBRARY_RELEASE=' + self.library_release,
                'NDK=' + self.ctx.ndk_dir,
                'APP_ABI=' + arch.arch,
                *extra_args,
                _env=env,
            )

        shutil.copyfile(os.path.join(self.get_build_dir(arch.arch), 'android', 'libs', arch.arch, 'libhackrf.so'), os.path.join(self.ctx.get_libs_dir(arch.arch), 'libhackrf.so'))


recipe = LibhackrfRecipe()
