from pythonforandroid.util import current_directory
from pythonforandroid.recipe import NDKRecipe
from pythonforandroid.logger import shprint
from os.path import join
import shutil
import sh


class LibusbRecipe(NDKRecipe):
    version = '1.0.26'
    url = 'https://github.com/libusb/libusb/archive/refs/tags/v{version}.tar.gz'
    site_packages_name = 'libusb'
    name = 'libusb'
    generated_libraries = ['libusb1.0.so']

    def should_build(self, arch):
        return True

    def get_recipe_env(self, arch):
        env = super().get_recipe_env(arch)

        env['LOCAL_C_INCLUDES'] = ' $(LIBUSB_ROOT_ABS)'
        env['LOCAL_SHARED_LIBRARIES'] = ' libusb1.0'
        return env

    def get_lib_dir(self, arch):
        return join(self.get_build_dir(arch.arch), 'android', 'obj', 'local', arch.arch)

    def get_jni_dir(self, arch):
        return join(self.get_build_dir(arch.arch), 'android', 'jni')

    def build_arch(self, arch, *extra_args):
        env = self.get_recipe_env(arch)
        with current_directory(self.get_build_dir(arch.arch)):
            shprint(
                sh.Command(join(self.ctx.ndk_dir, "ndk-build")),
                'NDK_PROJECT_PATH=' + self.get_build_dir(arch.arch) + '/android',
                'NDK='+self.ctx.ndk_dir,
                'APP_PLATFORM=android-' + str(self.ctx.ndk_api),
                'APP_ABI=' + arch.arch,
                *extra_args, _env=env
            )

        shutil.copyfile(join(self.get_build_dir(arch.arch), 'android', 'libs', arch.arch, 'libusb1.0.so'), join(self.ctx.get_libs_dir(arch.arch), 'libusb1.0.so'))


recipe = LibusbRecipe()
