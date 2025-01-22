/*
MIT License

Copyright (c) 2023-2024 GvozdevLeonid

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

#include "hackrf_android.h"
#include <libusb.h>

int hackrf_init_on_android(void) {

    int libusb_error;
    if (g_libusb_context != NULL) {
        return HACKRF_SUCCESS;
    }

    libusb_error = libusb_set_option(NULL, LIBUSB_OPTION_WEAK_AUTHORITY, NULL);
    if (libusb_error != LIBUSB_SUCCESS) {
        last_libusb_error = libusb_error;
        return HACKRF_ERROR_LIBUSB;
    }

    libusb_error = libusb_init(&g_libusb_context);
    if (libusb_error != 0) {
        last_libusb_error = libusb_error;
        return HACKRF_ERROR_LIBUSB;
    }
    else {
        return HACKRF_SUCCESS;
    }

}

int hackrf_open_on_android(int fileDescriptor, hackrf_device **device) {

    int libusb_error;
    if (device == NULL) {
        return HACKRF_ERROR_INVALID_PARAM;
    }
    libusb_device_handle *usb_device;

    libusb_error = libusb_wrap_sys_device(g_libusb_context, (intptr_t)fileDescriptor, &usb_device);
    if (libusb_error < 0) {
        last_libusb_error = libusb_error;
        return HACKRF_ERROR_LIBUSB;
    }

    if (usb_device == NULL) {
        return HACKRF_ERROR_NOT_FOUND;
    }

    return hackrf_open_setup(usb_device, device);

}
