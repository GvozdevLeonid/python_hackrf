# MIT License

# Copyright (c) 2023 GvozdevLeonid

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
from libc.stdint cimport uint8_t, uint16_t, uint32_t, uint64_t
from libc.stdlib cimport malloc, free
from . cimport chackrf


from enum import IntEnum
import numpy as np

PY_BYTES_PER_BLOCK = chackrf.BYTES_PER_BLOCK
PY_SAMPLES_PER_BLOCK = chackrf.SAMPLES_PER_BLOCK
PY_MAX_SWEEP_RANGES = chackrf.MAX_SWEEP_RANGES
PY_HACKRF_OPERACAKE_ADDRESS_INVALID = chackrf.HACKRF_OPERACAKE_ADDRESS_INVALID
PY_HACKRF_OPERACAKE_MAX_BOARDS = chackrf.HACKRF_OPERACAKE_MAX_BOARDS
PY_HACKRF_OPERACAKE_MAX_DWELL_TIMES = chackrf.HACKRF_OPERACAKE_MAX_DWELL_TIMES
PY_HACKRF_OPERACAKE_MAX_FREQ_RANGES = chackrf.HACKRF_OPERACAKE_MAX_FREQ_RANGES

class py_rf_path_filter(IntEnum):
    RF_PATH_FILTER_BYPASS = 0
    RF_PATH_FILTER_LOW_PASS = 1
    RF_PATH_FILTER_HIGH_PASS = 2

class py_sweep_style(IntEnum):
    LINEAR = 0
    INTERLEAVED = 1

cdef dict global_callbacks = {}

cdef int __rx_callback(chackrf.hackrf_transfer* transfer) nogil:
    global global_callbacks
    with gil:
        np_buffer = np.asarray(<uint8_t[:transfer.buffer_length]>transfer.buffer)
        if global_callbacks[<size_t> transfer.device]['__rx_callback'] is not None:
            result = global_callbacks[<size_t> transfer.device]['__rx_callback'](np_buffer, transfer.buffer_length, transfer.valid_length)
            return result
    return -1

cdef int __tx_callback(chackrf.hackrf_transfer* transfer) nogil:
    global global_callbacks
    with gil:
        np_buffer = np.asarray(<uint8_t[:transfer.buffer_length]>transfer.buffer)
        if global_callbacks[<size_t> transfer.device]['__tx_callback'] is not None:
            result, buffer, valid_length = global_callbacks[<size_t> transfer.device]['__tx_callback'](np_buffer, transfer.buffer_length, transfer.valid_length)

            for i in range(valid_length):
                transfer.buffer[i] = buffer[i]
            transfer.valid_length = valid_length

            return result
    return -1

cdef int __sweep_callback(chackrf.hackrf_transfer* transfer) nogil:
    global global_callbacks
    with gil:
        np_buffer = np.asarray(<uint8_t[:transfer.buffer_length]>transfer.buffer)
        if global_callbacks[<size_t> transfer.device]['__sweep_callback'] is not None:
            result = global_callbacks[<size_t> transfer.device]['__sweep_callback'](np_buffer, transfer.buffer_length, transfer.valid_length)
            return result
    return -1

cdef void __tx_complete_callback(chackrf.hackrf_transfer* transfer, int success) nogil:
    global global_callbacks
    with gil:
        np_buffer = np.asarray(<uint8_t[:transfer.buffer_length]>transfer.buffer)
        if global_callbacks[<size_t> transfer.device]['__tx_complete_callback'] is not None:
            global_callbacks[<size_t> transfer.device]['__tx_complete_callback'](np_buffer, transfer.buffer_length, transfer.valid_length, success)

cdef void __tx_flush_callback(void* flush_ctx, int success) nogil:
    global global_callbacks
    with gil:
        if global_callbacks['__tx_flush_callback'] is not None:
            global_callbacks['__tx_flush_callback'](success)


cdef class PyHackRFDeviceList:
    cdef chackrf.hackrf_device_list_t* __hackrf_device_list

    cdef chackrf.hackrf_device_list_t* get_hackrf_device_list_ptr(self):
        return self.__hackrf_device_list

    def __cinit__(self):
        self.__hackrf_device_list = chackrf.hackrf_device_list()

    def __dealloc__(self):
        if self.__hackrf_device_list is not NULL:
            chackrf.hackrf_device_list_free(self.__hackrf_device_list)

    property devicecount:
        def __get__(self):
            if self.__hackrf_device_list is not NULL:
                return self.__hackrf_device_list[0].devicecount

    property serial_numbers:
        def __get__(self):
            if self.__hackrf_device_list is not NULL:
                return [self.__hackrf_device_list[0].serial_numbers[i].decode('utf-8') for i in range(self.__hackrf_device_list[0].devicecount)]

    property usb_board_ids:
        def __get__(self):
            if self.__hackrf_device_list is not NULL:
                return [self.__hackrf_device_list[0].usb_board_ids[i] for i in range(self.__hackrf_device_list[0].devicecount)]

    def pyhackrf_board_id_name(self, index: int) -> str:
        if self.__hackrf_device_list is not NULL:
            return chackrf.hackrf_board_id_name(self.__hackrf_device_list[0].usb_board_ids[index]).decode('utf-8')

cdef class PyHackrfDevice:

    cdef chackrf.hackrf_device* __hackrf_device

    def __cinit__(self):
        self.__hackrf_device = NULL

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
    cdef chackrf.hackrf_device* get_hackrf_device_ptr(self):
        return self.__hackrf_device

    cdef chackrf.hackrf_device** get_hackrf_device_double_ptr(self):
        return &self.__hackrf_device


    # ---- callbacks ---- #
    def _setup_callbacks(self):
        global global_callbacks

        if self.__hackrf_device is not NULL:
            global_callbacks[<size_t>self.__hackrf_device] = {
                '__rx_callback': None,
                '__tx_callback': None,
                '__sweep_callback': None,
                '__tx_complete_callback': None,
            }
            global_callbacks['__tx_flush_callback'] = None
            return

        raise RuntimeError(f'_setup_callbacks() failed: Device not initialized!')


    # ---- device ---- #
    def pyhackrf_close(self):
        global global_callbacks
        if self.__hackrf_device is not NULL:
            if <size_t> self.__hackrf_device in global_callbacks.keys():
                global_callbacks.pop(<size_t> self.__hackrf_device)
            
            result = chackrf.hackrf_close(self.__hackrf_device)
            self.__hackrf_device = NULL

            if result != chackrf.hackrf_error.HACKRF_SUCCESS:
                raise RuntimeError(f'pyhackrf_close() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')


    def pyhackrf_reset(self):
        result = chackrf.hackrf_reset(self.__hackrf_device)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_reset() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_board_id_read(self) -> tuple(int, str):
        cdef uint8_t value
        result = chackrf.hackrf_board_id_read(self.__hackrf_device, &value)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_board_id_read() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')
        return value, chackrf.hackrf_board_id_name(value).decode('utf-8')

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

    def pyhackrf_board_partid_serialno_read(self):
        cdef chackrf.read_partid_serialno_t read_partid_serialno
        result = chackrf.hackrf_board_partid_serialno_read(self.__hackrf_device, &read_partid_serialno)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_board_partid_serialno_read() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')
        return read_partid_serialno
    
    def pyhackrf_filter_path_name(self, path: py_rf_path_filter) -> str:
        return chackrf.hackrf_filter_path_name(path).decode('utf-8')

    def pyhackrf_set_ui_enable(self, value: bool):
        result = chackrf.hackrf_set_ui_enable(self.__hackrf_device,  <uint8_t> 1 if value else 0)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_ui_enable() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')


    # ---- configuration ---- #
    def pyhackrf_compute_baseband_filter_bw_round_down_lt(self, bandwidth_hz: int) -> int:
        return chackrf.hackrf_compute_baseband_filter_bw_round_down_lt(<uint32_t> bandwidth_hz)

    def pyhackrf_compute_baseband_filter_bw(self, bandwidth_hz: int) -> int:
        return chackrf.hackrf_compute_baseband_filter_bw(<uint32_t> bandwidth_hz)

    def pyhackrf_set_baseband_filter_bandwidth(self, bandwidth_hz: int):
        result = chackrf.hackrf_set_baseband_filter_bandwidth(self.__hackrf_device, <uint32_t> bandwidth_hz)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_baseband_filter_bandwidth() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_freq(self, freq_hz: int):
        result = chackrf.hackrf_set_freq(self.__hackrf_device, <uint64_t> freq_hz)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_freq() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_freq_explicit(self, if_freq_hz: int, lo_freq_hz: int, path: py_rf_path_filter):
        result = chackrf.hackrf_set_freq_explicit(self.__hackrf_device, <uint64_t> if_freq_hz, <uint64_t> lo_freq_hz, path)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_freq_explicit() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_sample_rate_manual(self, freq_hz: int, divider: int):
        result = chackrf.hackrf_set_sample_rate_manual(self.__hackrf_device, <uint32_t> freq_hz, <uint32_t> divider)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_sample_rate_manual() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_sample_rate(self, freq_hz: float):
        result = chackrf.hackrf_set_sample_rate(self.__hackrf_device, <double> freq_hz)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_sample_rate() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_amp_enable(self, value: bool):
        result = chackrf.hackrf_set_amp_enable(self.__hackrf_device, <uint8_t> 1 if value else 0)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_amp_enable() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_lna_gain(self, value: int):
        result = chackrf.hackrf_set_lna_gain(self.__hackrf_device, <uint32_t> value)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_lna_gain() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_vga_gain(self, value: int):
        result = chackrf.hackrf_set_vga_gain(self.__hackrf_device, <uint32_t> value)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_vga_gain() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_txvga_gain(self, value: int):
        result = chackrf.hackrf_set_txvga_gain(self.__hackrf_device, <uint32_t> value)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_txvga_gain() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_antenna_enable(self, value: bool):
        result = chackrf.hackrf_set_antenna_enable(self.__hackrf_device, <uint8_t> 1 if value else 0)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_antenna_enable() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_clkout_enable(self, value: bool):
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
    def pyhackrf_is_streaming(self):
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
                            style: py_sweep_style
                            ):

        cdef uint16_t* frequencies
        frequencies = <uint16_t*>malloc(chackrf.MAX_SWEEP_RANGES * 2 * sizeof(uint16_t))

        for index, frequency in enumerate(frequency_list):
            frequencies[index] = frequency

        result = chackrf.hackrf_init_sweep(
            self.__hackrf_device,
            frequencies,
            num_ranges,
            <uint32_t> num_bytes,
            <uint32_t> step_width,
            <uint32_t> offset,
            style
        )

        free(frequencies)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_init_sweep() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_start_rx_sweep(self):
        result = chackrf.hackrf_start_rx_sweep(self.__hackrf_device, __sweep_callback, NULL)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_start_rx_sweep() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')       
    
    def pyhackrf_start_rx(self):
        result = chackrf.hackrf_start_rx(self.__hackrf_device, __rx_callback, NULL)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_start_rx() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')       
    
    def pyhackrf_stop_rx(self):
        result = chackrf.hackrf_stop_rx(self.__hackrf_device)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_stop_rx() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_start_tx(self):
        result = chackrf.hackrf_start_tx(self.__hackrf_device, __tx_callback, NULL)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_start_tx() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_stop_tx(self):
        result = chackrf.hackrf_stop_tx(self.__hackrf_device)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_stop_tx() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_tx_block_complete_callback(self):
        result = chackrf.hackrf_set_tx_block_complete_callback(self.__hackrf_device, __tx_complete_callback)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_tx_block_complete_callback() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_enable_tx_flush(self):
        result = chackrf.hackrf_enable_tx_flush(self.__hackrf_device, __tx_flush_callback, NULL)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_enable_tx_flush() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_tx_underrun_limit(self, value):
        result = chackrf.hackrf_set_tx_underrun_limit(self.__hackrf_device, <uint32_t> value)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_tx_underrun_limit() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_rx_overrun_limit(self, value):
        result = chackrf.hackrf_set_rx_overrun_limit(self.__hackrf_device, <uint32_t> value)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_rx_overrun_limit() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

    def pyhackrf_set_hw_sync_mode(self,  value: bool):
        result = chackrf.hackrf_set_hw_sync_mode(self.__hackrf_device, <uint8_t> 1 if value else 0)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_set_hw_sync_mode() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')


    # ---- debug ---- #
    def pyhackrf_get_m0_state(self):
        cdef chackrf.hackrf_m0_state hackrf_m0_state
        result = chackrf.hackrf_get_m0_state(self.__hackrf_device, &hackrf_m0_state)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_get_m0_state() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')
        return hackrf_m0_state
    
    def pyhackrf_max2837_read(self, register_number: int) -> int:
        cdef uint16_t value
        result = chackrf.hackrf_max2837_read(self.__hackrf_device, <uint8_t> register_number, &value)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_max2837_read() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')
        return value

    def pyhackrf_max2837_write(self, register_number: int, value: int):
        result = chackrf.hackrf_max2837_write(self.__hackrf_device, <uint8_t> register_number, <uint16_t> value)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_max2837_write() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')
        return value

    def pyhackrf_si5351c_read(self, register_number: int) -> int:
        cdef uint16_t value
        result = chackrf.hackrf_si5351c_read(self.__hackrf_device, <uint16_t> register_number, &value)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_si5351c_read() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')
        return value

    def pyhackrf_si5351c_write(self, register_number: int, value: int):
        result = chackrf.hackrf_max2837_write(self.__hackrf_device, <uint16_t> register_number, <uint16_t> value)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_si5351c_write() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')
        return value

    def pyhackrf_rffc5071_read(self, register_number) -> int:
        cdef uint16_t value
        result = chackrf.hackrf_rffc5071_read(self.__hackrf_device, <uint8_t> register_number, &value)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_rffc5071_read() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')
        return value

    def pyhackrf_rffc5071_write(self, register_number: int, value: int):
        result = chackrf.hackrf_rffc5071_write(self.__hackrf_device, <uint8_t> register_number, <uint16_t> value)
        if result != chackrf.hackrf_error.HACKRF_SUCCESS:
            raise RuntimeError(f'pyhackrf_rffc5071_write() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')


    # ---- python callbacks setters ---- #
    def set_rx_callback(self, rx_callback_function):
        global global_callbacks
        """
        Accept a 3 args that contains the buffer, the maximum length and the length of the buffer data.
        buffer: numpy.array(dtype=numpy.uint8), buffer_length: int, valid_length: int

        Should copy/process the contents of the transfer buffer's valid part.

        The callback should return 0 if it wants to be called again, and any other value otherwise.
        """
        if self.__hackrf_device is not NULL:
            global_callbacks[<size_t>self.__hackrf_device]['__rx_callback'] = rx_callback_function
            return

        raise RuntimeError(f'set_rx_callback() failed: Device not initialized!')

    def set_tx_callback(self, tx_callback_function):
        global global_callbacks
        """
        Accept a 3 args that contains the buffer, the maximum length and the length of the buffer data.
        buffer: numpy.array(dtype=numpy.uint8), buffer_length: int, valid_length: int


        The callback should return 0 if it wants to be called again, and any other value otherwise, numpy array(buffer) and new valid_length
        """
        if self.__hackrf_device is not NULL:
            global_callbacks[<size_t>self.__hackrf_device]['__tx_callback'] = tx_callback_function
            return

        raise RuntimeError(f'set_tx_callback() failed: Device not initialized!')

    def set_sweep_callback(self, sweep_callback_function):
        global global_callbacks
        """
        Accept a 3 args that contains the buffer, the maximum length and the length of the buffer data.
        buffer: numpy.array(dtype=numpy.uint8), buffer_length: int, valid_length: int

        Must copy/process the contents of a valid portion of the send buffer.

        The callback should return 0 if it wants to be called again, and any other value otherwise.
        * In this mode, with one data transfer (one callback call)
        """
        if self.__hackrf_device is not NULL:
            global_callbacks[<size_t>self.__hackrf_device]['__sweep_callback'] = sweep_callback_function
            return

        raise RuntimeError(f'set_sweep_callback() failed: Device not initialized!')

    def set_tx_complete_callback(self, tx_complete_callback_function):
        global global_callbacks
        """
        Accept a 4 args that contains the buffer, the maximum length and the length of the buffer data.
        buffer: numpy.array(dtype=numpy.uint8), buffer_length: int, valid_length: int
        and
        success: int # if the transfer was successful or not
        """
        if self.__hackrf_device is not NULL:
            global_callbacks[<size_t>self.__hackrf_device]['__tx_complete_callback'] = tx_complete_callback_function
            return

        raise RuntimeError(f'set_tx_complete_callback() failed: Device not initialized!')

    def set_tx_flush_callback(self, tx_flush_callback_function):
        global global_callbacks
        """
        Accept one argument of type int.
        This callback will be called when all the data was transmitted and all data transfers were completed.
        Prameter is success flag.
        """

        global_callbacks['__tx_flush_callback'] = tx_flush_callback_function

    # ---- operacake ---- # [Not implemented]
    def pyhackrf_get_operacake_boards(self, boards):# Not implemented
        pass

    def pyhackrf_set_operacake_mode(self, address, mode):# Not implemented
        pass

    def pyhackrf_get_operacake_mode(self, address, mode):# Not implemented
        pass

    def pyhackrf_set_operacake_ports(self, adress, port_a, port_b):# Not implemented
        pass

    def pyhackrf_set_operacake_dwell_times(self, dwell_times, count):# Not implemented
        pass

    def pyhackrf_set_operacake_freq_ranges(self, freq_ranges, count):# Not implemented
        pass

    def pyhackrf_set_operacake_ranges(self, ranges, num_ranges):# Not implemented
        pass

    def pyhackrf_operacake_gpio_test(self, address):# Not implemented
        pass


    # ---- library ---- #
    def pyhackrf_get_transfer_buffer_size(self) -> int:
        return chackrf.hackrf_get_transfer_buffer_size(self.__hackrf_device)

    def pyhackrf_get_transfer_queue_depth(self) -> int:
        return chackrf.hackrf_get_transfer_queue_depth(self.__hackrf_device)


# ---- library ---- #
# Should run before use library
def pyhackrf_init() -> int:
    return chackrf.hackrf_init()

def pyhackrf_android_init(int fileDescriptor) -> PyHackrfDevice | None:
    hackrf_device = PyHackrfDevice()
    result = chackrf.hackrf_android_init(fileDescriptor, hackrf_device.get_hackrf_device_double_ptr())
    if result == chackrf.hackrf_error.HACKRF_SUCCESS:
        hackrf_device._setup_callbacks()
        return hackrf_device

    raise RuntimeError(f'pyhackrf_android_init() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')


# Should run atrer use library
def pyhackrf_exit() -> int:
    return chackrf.hackrf_exit()


# Hackrf library info
def pyhackrf_library_version() -> str:
    return chackrf.hackrf_library_version().decode('utf-8')

def pyhackrf_library_release() -> str:
    return chackrf.hackrf_library_release().decode('utf-8')

# Founded hackrf devices
def pyhackrf_device_list() -> PyHackRFDeviceList:
    return PyHackRFDeviceList()

# Open and return hackrf device
def pyhackrf_device_list_open(hackrf_device_list: PyHackRFDeviceList, index: int) -> PyHackrfDevice | None:
    hackrf_device = PyHackrfDevice()
    result = chackrf.hackrf_device_list_open(hackrf_device_list.get_hackrf_device_list_ptr(), index, hackrf_device.get_hackrf_device_double_ptr())

    if result == chackrf.hackrf_error.HACKRF_SUCCESS:
        hackrf_device._setup_callbacks()
        return hackrf_device

    raise RuntimeError(f'pyhackrf_device_list_open() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

def pyhackrf_open() -> PyHackrfDevice | None:
    hackrf_device = PyHackrfDevice()

    result = chackrf.hackrf_open(hackrf_device.get_hackrf_device_double_ptr())

    if result == chackrf.hackrf_error.HACKRF_SUCCESS:
        hackrf_device._setup_callbacks()
        return hackrf_device

    raise RuntimeError(f'pyhackrf_open() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')

def pyhackrf_open_by_serial(desired_serial_number: str) -> PyHackrfDevice | None:
    hackrf_device = PyHackrfDevice()

    result = chackrf.hackrf_open_by_serial(desired_serial_number.encode('utf-8'), hackrf_device.get_hackrf_device_double_ptr())

    if result == chackrf.hackrf_error.HACKRF_SUCCESS:
        hackrf_device._setup_callbacks()
        return hackrf_device

    raise RuntimeError(f'pyhackrf_open_by_serial() failed: {chackrf.hackrf_error_name(result).decode("utf-8")} ({result})')
