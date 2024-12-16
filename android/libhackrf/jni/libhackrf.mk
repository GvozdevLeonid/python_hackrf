# MIT License

# Copyright (c) 2023-2024 GvozdevLeonid

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

LOCAL_PATH := $(call my-dir)
LIBHACKRF_ROOT_REL := ../..
LIBHACKRF_ROOT_ABS := $(LOCAL_PATH)/../..

# LIBHACKRF

include $(CLEAR_VARS)

LOCAL_SRC_FILES := $(LIBHACKRF_ROOT_REL)/host/libhackrf/src/hackrf.c
LOCAL_EXPORT_C_INCLUDES := $(LIBUSB_ROOT_ABS)/host/libhackrf/src

LOCAL_CFLAGS := \
	-I$(LIBHACKRF_ROOT_ABS)/android/libusb \
	-DLIBRARY_VERSION=\"$(LIBRARY_VERSION)\" \
    -DLIBRARY_RELEASE=\"$(LIBRARY_RELEASE)\" \
	-pthread

LOCAL_LDLIBS := -L$(LOCAL_PATH) -lusb1.0 -llog

LOCAL_MODULE := libhackrf

include $(BUILD_SHARED_LIBRARY)
