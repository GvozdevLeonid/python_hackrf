import os
import shutil

import sh
from pythonforandroid.archs import Arch
from pythonforandroid.logger import shprint
from pythonforandroid.recipe import NDKRecipe
from pythonforandroid.util import current_directory


class LibusbRecipe(NDKRecipe):

    url = 'https://github.com/libusb/libusb/archive/refs/tags/v{version}.tar.gz'
    generated_libraries = ('libusb-1.0.so', )
    site_packages_name = 'libusb'
    version = '1.0.26'
    name = 'libusb'

    def should_build(self, arch: Arch) -> bool:
        return not os.path.exists(os.path.join(self.ctx.get_libs_dir(arch.arch), 'libusb1.0.so'))

    def get_jni_dir(self, arch: Arch) -> str:
        return os.path.join(self.get_build_dir(arch.arch), 'android', 'jni')

    def get_lib_dir(self, arch: Arch) -> str:
        return os.path.join(self.get_build_dir(arch.arch), 'android', 'obj', 'local', arch.arch)

    def build_arch(self, arch: Arch, *extra_args) -> None:
        env = self.get_recipe_env(arch)
        with current_directory(self.get_build_dir(arch.arch)):
            shprint(
                sh.Command(os.path.join(self.ctx.ndk_dir, 'ndk-build')),
                'NDK_PROJECT_PATH=' + self.get_build_dir(arch.arch) + '/android',
                'APP_PLATFORM=android-' + str(self.ctx.ndk_api),
                'NDK=' + self.ctx.ndk_dir,
                'APP_ABI=' + arch.arch,
                *extra_args,
                _env=env,
            )

        shutil.copyfile(os.path.join(self.get_build_dir(arch.arch), 'android', 'libs', arch.arch, 'libusb1.0.so'), os.path.join(self.ctx.get_libs_dir(arch.arch), 'libusb1.0.so'))


recipe = LibusbRecipe()
