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

# cython: language_level=3str
from python_hackrf import __version__
from libc.stdint cimport uint8_t, uint16_t, uint32_t, uint64_t, uintptr_t
from libc.stdlib cimport malloc, free
from libc.string cimport memcpy
from enum import IntEnum
from ctypes import c_int
from . cimport chackrf
import numpy as np
cimport cython


cdef dict global_callbacks = {}

PY_BYTES_PER_BLOCK = chackrf.BYTES_PER_BLOCK
PY_MAX_SWEEP_RANGES = chackrf.MAX_SWEEP_RANGES
PY_HACKRF_OPERACAKE_ADDRESS_INVALID = chackrf.HACKRF_OPERACAKE_ADDRESS_INVALID
PY_HACKRF_OPERACAKE_MAX_BOARDS = chackrf.HACKRF_OPERACAKE_MAX_BOARDS
PY_HACKRF_OPERACAKE_MAX_DWELL_TIMES = chackrf.HACKRF_OPERACAKE_MAX_DWELL_TIMES
PY_HACKRF_OPERACAKE_MAX_FREQ_RANGES = chackrf.HACKRF_OPERACAKE_MAX_FREQ_RANGES

class py_rf_path_filter(IntEnum):
    RF_PATH_FILTER_BYPASS = chackrf.rf_path_filter.RF_PATH_FILTER_BYPASS
    RF_PATH_FILTER_LOW_PASS = chackrf.rf_path_filter.RF_PATH_FILTER_LOW_PASS
    RF_PATH_FILTER_HIGH_PASS = chackrf.rf_path_filter.RF_PATH_FILTER_HIGH_PASS

    def __str__(self) -> str:
        return self.name

class py_sweep_style(IntEnum):
    LINEAR = chackrf.sweep_style.LINEAR
    INTERLEAVED = chackrf.sweep_style.INTERLEAVED

    def __str__(self) -> str:
        return self.name

class py_operacake_switching_mode(IntEnum):
    OPERACAKE_MODE_MANUAL = chackrf.operacake_switching_mode.OPERACAKE_MODE_MANUAL
    OPERACAKE_MODE_FREQUENCY = chackrf.operacake_switching_mode.OPERACAKE_MODE_FREQUENCY
    OPERACAKE_MODE_TIME = chackrf.operacake_switching_mode.OPERACAKE_MODE_TIME

    def __str__(self) -> str:
        return self.name

class py_operacake_ports(IntEnum):
    A1: 0
    A2: 1
    A3: 2
    A4: 3
    B1: 4
    B2: 5
    B3: 6
    B4: 7

    def __str__(self) -> str:
        return self.name

    @classmethod
    def __contains__(cls, item):
        if isinstance(item, str):
            return item in cls.__members__
        elif isinstance(item, cls):
            return item in cls
        return False

@cython.boundscheck(False)
@cython.wraparound(False)
cdef int __rx_callback(chackrf.hackrf_transfer *transfer) noexcept nogil:
    global global_callbacks
    cdef uint8_t* buffer_ptr = transfer.buffer
    cdef uint8_t* np_buffer_ptr
    cdef int result = -1

    with gil:
        np_buffer = np.empty(transfer.buffer_length, dtype=np.int8)
        np_buffer_ptr = <uint8_t*> <uintptr_t> np_buffer.ctypes.data

        memcpy(
            np_buffer_ptr,
            buffer_ptr,
            transfer.valid_length,
        )

        if global_callbacks[<size_t> transfer.device]['__rx_callback'] is not None:
            result = global_callbacks[<size_t> transfer.device]['__rx_callback'](global_callbacks[<size_t> transfer.device]['device'], np_buffer, transfer.buffer_length, transfer.valid_length)

    return result

@cython.boundscheck(False)
@cython.wraparound(False)
cdef int __tx_callback(chackrf.hackrf_transfer *transfer) noexcept nogil:
    global global_callbacks
    cdef uint8_t* buffer_ptr = transfer.buffer
    cdef uint8_t* np_buffer_ptr
    cdef int result = -1

    with gil:
        np_buffer = np.empty(transfer.buffer_length, dtype=np.int8)
        valid_length = c_int(transfer.valid_length)
        np_buffer_ptr = <uint8_t*> <uintptr_t> np_buffer.ctypes.data

        if global_callbacks[<size_t> transfer.device]['__tx_callback'] is not None:
            result = global_callbacks[<size_t> transfer.device]['__tx_callback'](global_callbacks[<size_t> transfer.device]['device'], np_buffer, transfer.buffer_length, valid_length)
            transfer.valid_length = valid_length.value
        else:
            transfer.valid_length = 0

    memcpy(
        buffer_ptr,
        np_buffer_ptr,
        transfer.valid_length
    )

    return result

@cython.boundscheck(False)
@cython.wraparound(False)
cdef int __sweep_callback(chackrf.hackrf_transfer *transfer) noexcept nogil:
    global global_callbacks
    cdef uint8_t* buffer_ptr = transfer.buffer
    cdef uint8_t* np_buffer_ptr
    cdef int result = -1

    with gil:
        np_buffer = np.empty(transfer.buffer_length, dtype=np.int8)
        np_buffer_ptr = <uint8_t*> <uintptr_t> np_buffer.ctypes.data

        memcpy(
            np_buffer_ptr,
            buffer_ptr,
            transfer.valid_length,
        )

        if global_callbacks[<size_t> transfer.device]['__sweep_callback'] is not None:
            result = global_callbacks[<size_t> transfer.device]['__sweep_callback'](global_callbacks[<size_t> transfer.device]['device'], np_buffer, transfer.buffer_length, transfer.valid_length)

    return result

@cython.boundscheck(False)
@cython.wraparound(False)
cdef void __tx_complete_callback(chackrf.hackrf_transfer *transfer, int success) noexcept nogil:
    global global_callbacks
    cdef uint8_t* buffer_ptr = transfer.buffer
    cdef uint8_t* np_buffer_ptr

    with gil:
        np_buffer = np.empty(transfer.buffer_length, dtype=np.int8)
        np_buffer_ptr = <uint8_t*> <uintptr_t> np_buffer.ctypes.data

        memcpy(
            np_buffer_ptr,
            buffer_ptr,
            transfer.valid_length,
        )

        if global_callbacks[<size_t> transfer.device]['__tx_complete_callback'] is not None:
            global_callbacks[<size_t> transfer.device]['__tx_complete_callback'](global_callbacks[<size_t> transfer.device]['device'], np_buffer, transfer.buffer_length, transfer.valid_length, success)

cdef void __tx_flush_callback(void *flush_ctx, int success) noexcept nogil:
    global global_callbacks
    cdef size_t device_ptr = <size_t> flush_ctx

    with gil:
        if global_callbacks[device_ptr]['__tx_flush_callback'] is not None:
            global_callbacks[device_ptr]['__tx_flush_callback'](global_callbacks[device_ptr]['device'], success)

cdef class PyHackRFDeviceList:
    cdef chackrf.hackrf_device_list_t *__hackrf_device_list

    cdef chackrf.hackrf_device_list_t *get_hackrf_device_list_ptr(self):
        return self.__hackrf_device_list

    def __cinit__(self):
        self.__hackrf_device_list = chackrf.hackrf_device_list()

    def __dealloc__(self):
        if self.__hackrf_device_list is not NULL:
            chackrf.hackrf_device_list_free(self.__hackrf_device_list)

    property device_count:
        def __get__(self):
            if self.__hackrf_device_list is not NULL:
                return self.__hackrf_device_list[0].devicecount
            return 0

    property serial_numbers:
        def __get__(self):
            return [self.__hackrf_device_list[0].serial_numbers[i].decode('utf-8') for i in range(self.device_count)]

    property usb_board_ids:
        def __get__(self):
            return [self.__hackrf_device_list[0].usb_board_ids[i] for i in range(self.device_count)]

    def pyhackrf_board_id_name(self, index: int) -> str:
        if self.__hackrf_device_list is not NULL:
            return chackrf.hackrf_board_id_name(self.__hackrf_device_list[0].usb_board_ids[index]).decode('utf-8')

cdef class PyHackrfDevice:

    cdef chackrf.hackrf_device *__hackrf_device
    cdef list __pyoperacakes
    cdef public str serialno

    def __cinit__(self):
        self.__hackrf_device = NULL
        self.__pyoperacakes = []

    def __dealloc__(self):
        global global_callbacks
        if self.__hackrf_device is not NULL:
            if <size_t> self.__hackrf_device in global_callbacks.keys():
                global_callbacks.pop(<size_t> self.__hackrf_device)

            result = chackrf.hackrf_close(self.__hackrf_device)
            self.__hackrf_device = NULL

            if result != chackrf.hackrf_error.HACKRF_SUCCESS:
                raise RuntimeError(f'__dealloc__ failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    # ---- inner functions ---- #
    cdef chackrf.hackrf_device *get_hackrf_device_ptr(self):
        return self.__hackrf_device

    cdef chackrf.hackrf_device **get_hackrf_device_double_ptr(self):
        return &self.__hackrf_device

    cdef _setup_device(self):
        global global_callbacks

        if self.__hackrf_device is not NULL:
            self.serialno = self.pyhackrf_serialno_read()

            global_callbacks[<size_t> self.__hackrf_device] = {
                '__rx_callback': None,
                '__tx_callback': None,
                '__sweep_callback': None,
                '__tx_complete_callback': None,
                '__tx_flush_callback': None,
                'device': self,
            }
            return

        raise RuntimeError(f'_setup_device() failed: Device not initialized!')

    # ---- device ---- #
    def pyhackrf_close(self) -> None:
        global global_callbacks
        if self.__hackrf_device is not NULL:
            if <size_t> self.__hackrf_device in global_callbacks.keys():
                global_callbacks.pop(<size_t> self.__hackrf_device)

            result = chackrf.hackrf_close(self.__hackrf_device)
            self.__hackrf_device = NULL

            if result != chackrf.hackrf_error.HACKRF_SUCCESS:
                raise RuntimeError(f'pyhackrf_close() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_reset(self) -> None:
        result = chackrf.hackrf_reset(self.__hackrf_device)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_reset() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_board_id_read(self) -> tuple[int, str]:
        cdef uint8_t value
        result = chackrf.hackrf_board_id_read(self.__hackrf_device, &value)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_board_id_read() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')
        return value, chackrf.hackrf_board_id_name(value).decode('utf-8')

    def pyhackrf_board_rev_read(self) -> tuple[int, str]:
        cdef uint8_t value
        result = chackrf.hackrf_board_rev_read(self.__hackrf_device, &value)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_board_rev_read() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

        if value == chackrf.BOARD_REV_UNDETECTED:
            return 'Error: Hardware revision not yet detected by firmware.'
        elif value == chackrf.BOARD_REV_UNRECOGNIZED:
            return 'Warning: Hardware revision not recognized by firmware.'
        else:
            return value, chackrf.hackrf_board_rev_name(value).decode('utf-8')

    def pyhackrf_version_string_read(self) -> str:
        cdef char[255] version
        result = chackrf.hackrf_version_string_read(self.__hackrf_device, version, 255)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_version_string_read() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')
        return version.decode('utf-8')

    def pyhackrf_usb_api_version_read(self) -> str:
        cdef uint16_t version
        result = chackrf.hackrf_usb_api_version_read(self.__hackrf_device, &version)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_usb_api_version_read() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')
        return 'API:{:x}.{:02x}'.format((version >> 8) & 0xFF, version & 0xFF)

    def pyhackrf_board_partid_serialno_read(self) -> tuple[tuple[int, int], tuple[int, int, int, int]]:
        cdef chackrf.read_partid_serialno_t read_partid_serialno
        result = chackrf.hackrf_board_partid_serialno_read(self.__hackrf_device, &read_partid_serialno)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_board_partid_serialno_read() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

        return (
            (
                read_partid_serialno.part_id[0],
                read_partid_serialno.part_id[1],
            ),
            (
                read_partid_serialno.serial_no[0],
                read_partid_serialno.serial_no[1],
                read_partid_serialno.serial_no[2],
                read_partid_serialno.serial_no[3],
            )
        )

    def pyhackrf_serialno_read(self) -> str:
        cdef chackrf.read_partid_serialno_t read_partid_serialno
        result = chackrf.hackrf_board_partid_serialno_read(self.__hackrf_device, &read_partid_serialno)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_serialno_read() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

        return '{0:08x}{1:08x}{2:08x}{3:08x}'.format(
            read_partid_serialno.serial_no[0],
            read_partid_serialno.serial_no[1],
            read_partid_serialno.serial_no[2],
            read_partid_serialno.serial_no[3],
        )

    def pyhackrf_set_ui_enable(self, value: bool) -> None:
        result = chackrf.hackrf_set_ui_enable(self.__hackrf_device, <uint8_t> 1 if value else 0)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_ui_enable() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_leds(self, state: str) -> None:
        result = chackrf.hackrf_set_leds(self.__hackrf_device, <uint8_t> int(state, 2))
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_leds() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_user_bias_t_opts(self, rx: tuple[bool, bool, bool], tx: tuple[bool, bool, bool], off: tuple[bool, bool, bool]) -> None:
        cdef chackrf.hackrf_bias_t_user_settting_req req

        req.rx.do_update = rx[0]
        req.rx.change_on_mode_entry = rx[1]
        req.rx.enabled = rx[2]

        req.rx.do_update = tx[0]
        req.rx.change_on_mode_entry = tx[0]
        req.rx.enabled = tx[0]

        req.rx.do_update = off[0]
        req.rx.change_on_mode_entry = off[0]
        req.rx.enabled = off[0]

        result = chackrf.hackrf_set_user_bias_t_opts(self.__hackrf_device, &req)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_user_bias_t_opts() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    # ---- configuration ---- #
    def pyhackrf_set_baseband_filter_bandwidth(self, bandwidth_hz: int) -> None:
        result = chackrf.hackrf_set_baseband_filter_bandwidth(self.__hackrf_device, <uint32_t> bandwidth_hz)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_baseband_filter_bandwidth() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_freq(self, freq_hz: int) -> None:
        result = chackrf.hackrf_set_freq(self.__hackrf_device, <uint64_t> freq_hz)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_freq() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_freq_explicit(self, i_freq_hz: int, lo_freq_hz: int, path: py_rf_path_filter) -> None:
        result = chackrf.hackrf_set_freq_explicit(self.__hackrf_device, <uint64_t> i_freq_hz, <uint64_t> lo_freq_hz, path)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_freq_explicit() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_sample_rate_manual(self, freq_hz: int, divider: int) -> None:
        result = chackrf.hackrf_set_sample_rate_manual(self.__hackrf_device, <uint32_t> freq_hz, <uint32_t> divider)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_sample_rate_manual() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_sample_rate(self, freq_hz: float) -> None:
        result = chackrf.hackrf_set_sample_rate(self.__hackrf_device, <double> freq_hz)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_sample_rate() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_amp_enable(self, value: bool) -> None:
        result = chackrf.hackrf_set_amp_enable(self.__hackrf_device, <uint8_t> 1 if value else 0)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_amp_enable() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_lna_gain(self, value: int) -> None:
        value = int(max(0, min(40, value)) / 8) * 8
        result = chackrf.hackrf_set_lna_gain(self.__hackrf_device, <uint32_t> value)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_lna_gain() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_vga_gain(self, value: int) -> None:
        value = int(max(0, min(62, value)) / 2) * 2
        result = chackrf.hackrf_set_vga_gain(self.__hackrf_device, <uint32_t> value)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_vga_gain() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_txvga_gain(self, value: int) -> None:
        value = int(max(0, min(47, value)))
        result = chackrf.hackrf_set_txvga_gain(self.__hackrf_device, <uint32_t> value)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_txvga_gain() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_antenna_enable(self, value: bool) -> None:
        result = chackrf.hackrf_set_antenna_enable(self.__hackrf_device, <uint8_t> 1 if value else 0)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_antenna_enable() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_clkout_enable(self, value: bool) -> None:
        result = chackrf.hackrf_set_clkout_enable(self.__hackrf_device, <uint8_t> 1 if value else 0)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_clkout_enable() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_get_clkin_status(self) -> int:
        cdef uint8_t status
        result = chackrf.hackrf_get_clkin_status(self.__hackrf_device, &status)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_clkout_enable() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')
        return status

    # ---- streaming ---- #
    def pyhackrf_is_streaming(self) -> bool:
        result = chackrf.hackrf_is_streaming(self.__hackrf_device)
        if result == chackrf.hackrf_error.HACKRF_TRUE:
            return True
        elif result in (chackrf.hackrf_error.HACKRF_ERROR_STREAMING_THREAD_ERR, chackrf.hackrf_error.HACKRF_ERROR_STREAMING_STOPPED, chackrf.hackrf_error.HACKRF_ERROR_STREAMING_EXIT_CALLED):
            return False
        raise RuntimeError(f'pyhackrf_is_streaming() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_init_sweep(self,
                            frequency_list: list,
                            num_ranges: int,
                            num_bytes: int,
                            step_width: int,
                            offset: int,
                            style: py_sweep_style,
                            ) -> None:

        cdef uint16_t *frequencies = <uint16_t*> malloc(chackrf.MAX_SWEEP_RANGES * 2 * sizeof(uint16_t))

        for index, frequency in enumerate(frequency_list):
            frequencies[index] = frequency

        result = chackrf.hackrf_init_sweep(
            self.__hackrf_device,
            frequencies,
            num_ranges,
            <uint32_t> num_bytes,
            <uint32_t> step_width,
            <uint32_t> offset,
            style,
        )

        free(frequencies)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_init_sweep() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_start_rx_sweep(self) -> None:
        result = chackrf.hackrf_start_rx_sweep(self.__hackrf_device, __sweep_callback, NULL)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_start_rx_sweep() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_start_rx(self) -> None:
        result = chackrf.hackrf_start_rx(self.__hackrf_device, __rx_callback, NULL)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_start_rx() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_stop_rx(self) -> None:
        result = chackrf.hackrf_stop_rx(self.__hackrf_device)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_stop_rx() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_start_tx(self) -> None:
        result = chackrf.hackrf_start_tx(self.__hackrf_device, __tx_callback, NULL)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_start_tx() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_stop_tx(self) -> None:
        result = chackrf.hackrf_stop_tx(self.__hackrf_device)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_stop_tx() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_enable_tx_block_complete_callback(self) -> None:
        result = chackrf.hackrf_set_tx_block_complete_callback(self.__hackrf_device, __tx_complete_callback)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_tx_block_complete_callback() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_enable_tx_flush(self) -> None:
        result = chackrf.hackrf_enable_tx_flush(self.__hackrf_device, __tx_flush_callback, <void*> self.__hackrf_device)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_enable_tx_flush() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_tx_underrun_limit(self, value: int) -> None:
        result = chackrf.hackrf_set_tx_underrun_limit(self.__hackrf_device, <uint32_t> value)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_tx_underrun_limit() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_rx_overrun_limit(self, value: int) -> None:
        result = chackrf.hackrf_set_rx_overrun_limit(self.__hackrf_device, <uint32_t> value)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_rx_overrun_limit() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_hw_sync_mode(self, value: bool) -> None:
        result = chackrf.hackrf_set_hw_sync_mode(self.__hackrf_device, <uint8_t> 1 if value else 0)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_hw_sync_mode() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    # ---- debug ---- #
    def pyhackrf_get_m0_state(self) -> dict:
        cdef chackrf.hackrf_m0_state hackrf_m0_state
        result = chackrf.hackrf_get_m0_state(self.__hackrf_device, &hackrf_m0_state)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_get_m0_state() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

        return {
            'requested_mode': hackrf_m0_state.requested_mode,
            'request_flag': hackrf_m0_state.request_flag,
            'active_mode': hackrf_m0_state.active_mode,
            'm0_count': hackrf_m0_state.m0_count,
            'm4_count': hackrf_m0_state.m4_count,
            'num_shortfalls': hackrf_m0_state.num_shortfalls,
            'longest_shortfall': hackrf_m0_state.longest_shortfall,
            'shortfall_limit': hackrf_m0_state.shortfall_limit,
            'threshold': hackrf_m0_state.threshold,
            'next_mode': hackrf_m0_state.next_mode,
            'error': hackrf_m0_state.error,
        }

    def pyhackrf_max2837_read(self, register_number: int) -> int:
        cdef uint16_t value
        result = chackrf.hackrf_max2837_read(self.__hackrf_device, <uint8_t> register_number, &value)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_max2837_read() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')
        return value

    def pyhackrf_max2837_write(self, register_number: int, value: int) -> None:
        result = chackrf.hackrf_max2837_write(self.__hackrf_device, <uint8_t> register_number, <uint16_t> value)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_max2837_write() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_si5351c_read(self, register_number: int) -> int:
        cdef uint16_t value
        result = chackrf.hackrf_si5351c_read(self.__hackrf_device, <uint16_t> register_number, &value)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_si5351c_read() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')
        return value

    def pyhackrf_si5351c_write(self, register_number: int, value: int) -> None:
        result = chackrf.hackrf_max2837_write(self.__hackrf_device, <uint16_t> register_number, <uint16_t> value)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_si5351c_write() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_rffc5071_read(self, register_number: int) -> int:
        cdef uint16_t value
        result = chackrf.hackrf_rffc5071_read(self.__hackrf_device, <uint8_t> register_number, &value)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_rffc5071_read() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')
        return value

    def pyhackrf_rffc5071_write(self, register_number: int, value: int) -> None:
        result = chackrf.hackrf_rffc5071_write(self.__hackrf_device, <uint8_t> register_number, <uint16_t> value)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_rffc5071_write() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    # ---- python callbacks setters ---- #
    def set_rx_callback(self, rx_callback_function) -> None:
        global global_callbacks

        if self.__hackrf_device is not NULL:
            global_callbacks[<size_t> self.__hackrf_device]['__rx_callback'] = rx_callback_function
            return

        raise RuntimeError(f'set_rx_callback() failed: Device not initialized!')

    def set_tx_callback(self, tx_callback_function) -> None:
        global global_callbacks

        if self.__hackrf_device is not NULL:
            global_callbacks[<size_t> self.__hackrf_device]['__tx_callback'] = tx_callback_function
            return

        raise RuntimeError(f'set_tx_callback() failed: Device not initialized!')

    def set_sweep_callback(self, sweep_callback_function) -> None:
        global global_callbacks

        if self.__hackrf_device is not NULL:
            global_callbacks[<size_t> self.__hackrf_device]['__sweep_callback'] = sweep_callback_function
            return

        raise RuntimeError(f'set_sweep_callback() failed: Device not initialized!')

    def set_tx_complete_callback(self, tx_complete_callback_function) -> None:
        global global_callbacks

        if self.__hackrf_device is not NULL:
            global_callbacks[<size_t> self.__hackrf_device]['__tx_complete_callback'] = tx_complete_callback_function
            return

        raise RuntimeError(f'set_tx_complete_callback() failed: Device not initialized!')

    def set_tx_flush_callback(self, tx_flush_callback_function) -> None:
        global global_callbacks

        if self.__hackrf_device is not NULL:
            global_callbacks[<size_t> self.__hackrf_device]['__tx_flush_callback'] = tx_flush_callback_function
            return

        raise RuntimeError(f'set_tx_flush_callback() failed: Device not initialized!')

    # ---- library ---- #
    def pyhackrf_get_transfer_buffer_size(self) -> int:
        return chackrf.hackrf_get_transfer_buffer_size(self.__hackrf_device)

    def pyhackrf_get_transfer_queue_depth(self) -> int:
        return chackrf.hackrf_get_transfer_queue_depth(self.__hackrf_device)

    # ---- operacake ---- #
    def pyhackrf_get_operacake_boards(self) -> list:
        self.__pyoperacakes.clear()
        cdef uint8_t *operacakes = <uint8_t*> malloc(PY_HACKRF_OPERACAKE_MAX_BOARDS * sizeof(uint8_t))
        result = chackrf.hackrf_get_operacake_boards(self.__hackrf_device, &operacakes[0])

        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_get_operacake_boards() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')
        for i in range(PY_HACKRF_OPERACAKE_MAX_BOARDS):
            if operacakes[i] == PY_HACKRF_OPERACAKE_ADDRESS_INVALID:
                break
            self.__pyoperacakes.append(operacakes[i])

        free(operacakes)
        return self.__pyoperacakes

    def pyhackrf_set_operacake_mode(self, address: int, mode: py_operacake_switching_mode) -> None:
        result = chackrf.hackrf_set_operacake_mode(self.__hackrf_device, <uint8_t> address, mode)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_operacake_mode() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_get_operacake_mode(self, address: int) -> py_operacake_switching_mode:
        cdef chackrf.operacake_switching_mode mode
        result = chackrf.hackrf_get_operacake_mode(self.__hackrf_device, <uint8_t> address, &mode)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_get_operacake_mode() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')
        return py_operacake_switching_mode(mode)

    def pyhackrf_set_operacake_ports(self, address: int, port_a: str, port_b: str) -> None:
        result = chackrf.hackrf_set_operacake_ports(self.__hackrf_device, <uint8_t> address, <uint8_t> py_operacake_ports[port_a], <uint8_t> py_operacake_ports[port_b])
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_operacake_ports() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_operacake_dwell_times(self, dwell_times: list) -> None:
        cdef chackrf.hackrf_operacake_dwell_time *_dwell_times = <chackrf.hackrf_operacake_dwell_time*> malloc(PY_HACKRF_OPERACAKE_MAX_DWELL_TIMES * sizeof(chackrf.hackrf_operacake_dwell_time))
        for index, (dwell, port) in enumerate(dwell_times):
            _dwell_times[index].dwell = dwell
            _dwell_times[index].port = <uint8_t> py_operacake_ports[port]

        result = chackrf.hackrf_set_operacake_dwell_times(self.__hackrf_device, _dwell_times, <uint8_t> len(dwell_times))

        free(_dwell_times)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_operacake_dwell_times() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_operacake_freq_ranges(self, freq_ranges: list) -> None:
        cdef chackrf.hackrf_operacake_freq_range *_freq_ranges = <chackrf.hackrf_operacake_freq_range*> malloc(PY_HACKRF_OPERACAKE_MAX_FREQ_RANGES * sizeof(chackrf.hackrf_operacake_freq_range))
        for index, (port, freq_min, freq_max) in enumerate(freq_ranges):
            _freq_ranges[index].freq_min = freq_min
            _freq_ranges[index].freq_max = freq_max
            _freq_ranges[index].port = <uint8_t> py_operacake_ports[port]

        result = chackrf.hackrf_set_operacake_freq_ranges(self.__hackrf_device, _freq_ranges, <uint8_t> len(freq_ranges))

        free(_freq_ranges)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_operacake_freq_ranges() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_operacake_gpio_test(self, address: int) -> int:
        cdef uint16_t test_result
        result = chackrf.hackrf_operacake_gpio_test(self.__hackrf_device, <uint8_t> address, &test_result)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_operacake_gpio_test() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')
        return test_result

# ---- initialization and exit ---- #
def pyhackrf_init() -> None:
    result = chackrf.hackrf_init()
    if result != chackrf.hackrf_error.HACKRF_SUCCESS:
        raise RuntimeError(f'pyhackrf_init() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

def pyhackrf_exit() -> None:
    result = chackrf.hackrf_exit()
    if result != chackrf.hackrf_error.HACKRF_SUCCESS:
        raise RuntimeError(f'pyhackrf_exit() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

# ---- version ---- #
def python_hackrf_library_version() -> str:
    return __version__

def pyhackrf_library_version() -> str:
    return chackrf.hackrf_library_version().decode('utf-8')

def pyhackrf_library_release() -> str:
    return chackrf.hackrf_library_release().decode('utf-8')

# ---- device ---- #
def pyhackrf_device_list() -> PyHackRFDeviceList:
    return PyHackRFDeviceList()

def pyhackrf_device_list_open(pyhackrf_device_list: PyHackRFDeviceList, index: int) -> PyHackrfDevice | None:
    pyhackrf_device = PyHackrfDevice()
    result = chackrf.hackrf_device_list_open(pyhackrf_device_list.get_hackrf_device_list_ptr(), index, pyhackrf_device.get_hackrf_device_double_ptr())

    if result == chackrf.hackrf_error.HACKRF_SUCCESS:
        pyhackrf_device._setup_device()
        return pyhackrf_device

    raise RuntimeError(f'pyhackrf_device_list_open() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

def pyhackrf_open() -> PyHackrfDevice | None:
    pyhackrf_device = PyHackrfDevice()

    result = chackrf.hackrf_open(pyhackrf_device.get_hackrf_device_double_ptr())

    if result == chackrf.hackrf_error.HACKRF_SUCCESS:
        pyhackrf_device._setup_device()
        return pyhackrf_device

    raise RuntimeError(f'pyhackrf_open() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

def pyhackrf_open_by_serial(desired_serial_number: str) -> PyHackrfDevice | None:
    if desired_serial_number in (None, ''):
        return pyhackrf_open()

    pyhackrf_device = PyHackrfDevice()
    result = chackrf.hackrf_open_by_serial(desired_serial_number.encode('utf-8'), pyhackrf_device.get_hackrf_device_double_ptr())

    if result == chackrf.hackrf_error.HACKRF_SUCCESS:
        pyhackrf_device._setup_device()
        return pyhackrf_device

    raise RuntimeError(f'pyhackrf_open_by_serial() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

# ---- baseband filter bandwidth ---- #
def pyhackrf_compute_baseband_filter_bw_round_down_lt(bandwidth_hz: int) -> int:
    return chackrf.hackrf_compute_baseband_filter_bw_round_down_lt(<uint32_t> bandwidth_hz)

def pyhackrf_compute_baseband_filter_bw(bandwidth_hz: int) -> int:
    return chackrf.hackrf_compute_baseband_filter_bw(<uint32_t> bandwidth_hz)
