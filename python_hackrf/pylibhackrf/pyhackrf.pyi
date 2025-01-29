# MIT License

# Copyright (c) 2023-2024 GvozdevLeonid

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

from enum import IntEnum
from typing import Callable, Self

import numpy as np

PY_BYTES_PER_BLOCK: int
'''Number of bytes per tuning for sweeping'''

PY_MAX_SWEEP_RANGES: int
'''Maximum number of sweep ranges to be specified for `pyhackrf_init_sweep`'''

PY_HACKRF_OPERACAKE_ADDRESS_INVALID: int
'''Invalid Opera Cake add-on board address, placeholder in hackrf_get_operacake_boards'''

PY_HACKRF_OPERACAKE_MAX_BOARDS: int
'''Maximum number of specifiable dwell times for Opera Cake add-on boards'''

PY_HACKRF_OPERACAKE_MAX_DWELL_TIMES: int
'''HACKRF_OPERACAKE_MAX_DWELL_TIMES'''

PY_HACKRF_OPERACAKE_MAX_FREQ_RANGES: int
'''Maximum number of specifiable frequency ranges for Opera Cake add-on boards'''

class py_rf_path_filter(IntEnum):
    '''
    RF filter path setting enum

    Used only when performing explicit tuning using `pyhackrf_set_freq_explicit`
    This can select the image rejection filter (U3, U8 or none) to use - using switches U5, U6, U9 and U11. When no filter is selected, the mixer itself is bypassed.
    '''
    RF_PATH_FILTER_BYPASS = ...
    '''No filter is selected, **the mixer is bypassed**, frequency_center = i_freq'''

    RF_PATH_FILTER_LOW_PASS = ...
    '''LPF is selected, frequency_center = i_freq - lo_freq'''

    RF_PATH_FILTER_HIGH_PASS = ...
    '''HPF is selected, frequency_center = i_freq + lo_freq'''

    def __str__(self) -> str:
        ...

class py_sweep_style(IntEnum):
    '''
    Sweep mode enum

    Used by `pyhackrf_init_sweep`, to set sweep parameters.
    '''

    LINEAR = ...
    '''step_width is added to the current frequency at each step.'''

    INTERLEAVED = ...
    '''each step is divided into two interleaved sub-steps, allowing the host to select the best portions of the FFT of each sub-step and discard the rest.'''

    def __str__(self) -> str:
        ...

class py_operacake_switching_mode(IntEnum):
    '''Opera Cake port switching mode. Set via `pyhackrf_set_operacake_mode` and quaried via `pyhackrf_get_operacake_mode`'''

    OPERACAKE_MODE_MANUAL = ...
    '''Port connections are set manually using `pyhackrf_set_operacake_ports`. Both ports can be specified, but not on the same side.'''

    OPERACAKE_MODE_FREQUENCY = ...
    '''Port connections are switched automatically when the frequency is changed. Frequency ranges can be set using `pyhackrf_set_operacake_freq_ranges`. In this mode, B0 mirrors A0'''

    OPERACAKE_MODE_TIME = ...
    '''Port connections are switched automatically over time. dwell times can be set with `pyhackrf_set_operacake_dwell_times`. In this mode, B0 mirrors A0'''

    def __str__(self) -> str:
        ...

operacake_ports = {
    'A1': ...,
    'A2': ...,
    'A3': ...,
    'A4': ...,
    'B1': ...,
    'B2': ...,
    'B3': ...,
    'B4': ...,
}
'''Opera Cake secondary ports (A1-A4, B1-B4)'''

class PyHackRFDeviceList:
    '''
        Class implementing list of HackRF devices.
    '''

    def __init__(self) -> None:
        ...

    @property
    def device_count() -> int:
        '''Number of devices found'''
        ...

    @property
    def serial_numbers() -> list[str]:
        '''List of serial numbers of found devices'''
        ...

    @property
    def usb_board_ids() -> list[int]:
        '''List of USB board ids of found devices'''
        ...

    @property
    def file_descriptors() -> list[int]:
        '''
        List of file descriptors of found devices.
        Available only on android platform
        '''
        ...

    def pyhackrf_board_id_name(self, index: int) -> str:
        '''Human readable name of the board'''
        ...

class PyHackrfDevice:
    '''
    Class implementing interaction with the device.

    If any of the functions returns not `HACKRF_SUCCESS`, then an exception will be raised.

    **Do not use this class directly**
        To open the device, use one of the functions: `pyhackrf_open`, `pyhackrf_open_by_serial`, `pyhackrf_device_list_open`

    Notes:
    - Before using the methods of this class, ensure the device is properly connected and initialized using `pyhackrf_init()`.
    - After finishing, it is recommended to call `pyhackrf_close()` to properly close the device.
    - It is also recommended to call `pyhackrf_exit()` to properly release resources.
    - When using callbacks, ensure they are optimized for real-time processing to avoid data loss.
    '''

    def __init__(self) -> None:
        ...

    # ---- device ---- #
    def pyhackrf_close(self) -> None:
        '''Close a previously opened device'''
        ...

    def pyhackrf_reset(self) -> None:
        '''Reset HackRF device'''
        ...

    def pyhackrf_board_id_read(self) -> tuple[int, str]:
        '''
        Read `hackrf_board_id` from a device

        It return `hackrf_board_id` as integer and a human-readable string via `hackrf_board_id_name`
        '''
        ...

    def pyhackrf_board_rev_read(self) -> tuple[int, str]:
        '''Read board revision of device'''
        ...

    def pyhackrf_version_string_read(self) -> str:
        '''Read HackRF firmware version as a string'''
        ...

    def pyhackrf_usb_api_version_read(self) -> str:
        '''Read HackRF USB API version as string'''
        ...

    def pyhackrf_board_partid_serialno_read(self) -> tuple[tuple[int, int], tuple[int, int, int, int]]:
        '''Read board part ID and serial number'''
        ...

    def pyhackrf_serialno_read(self) -> str:
        '''Read human-readable string of serial number'''
        ...

    def pyhackrf_set_ui_enable(self, value: bool) -> None:
        '''
        Enable / disable UI display (RAD1O, PortaPack, etc.)

        Enable or disable the display on display-enabled devices (Rad1o, PortaPack)
        '''
        ...

    def pyhackrf_set_leds(self, state: int) -> None:
        '''
        Turn on or off (override) the LEDs of the HackRF device
        This function can turn on or off the LEDs of the device. There are 3 controllable LEDs on the HackRF one: USB, RX and TX. On the Rad1o, there are 4 LEDs. Each LED can be set individually, but the setting might get overridden by other functions.

        The LEDs can be set via specifying them as string `state`, first index  representing the first (USB on the HackRF One) and index 3 or 4 representing the last LED. The upper 4 or 5 bits are unused. For example, string value "101" turns on the USB and TX LEDs on the HackRF One.
        '''
        ...

    def pyhackrf_set_user_bias_t_opts(self, rx: tuple[bool, bool, bool], tx: tuple[bool, bool, bool], off: tuple[bool, bool, bool]) -> None:
        '''
        Configure bias tee behavior of the HackRF device when changing RF states

        This function allows the user to configure bias tee behavior so that it can be turned on or off automatically by the HackRF when entering the RX, TX, or OFF state. By default, the HackRF switches off the bias tee when the RF path switches to OFF mode.

        `rx | tx | off` [do_update: bool, change_on_mode_entry: bool, enabled: bool]

        If `do_update` is true, then the values of `change_on_mode_entry` and `enabled` will be used as the new default.  If `do_update` is false, the current default will not change.
        '''
        ...

    # ---- configuration ---- #
    def pyhackrf_set_baseband_filter_bandwidth(self, bandwidth_hz: int) -> None:
        '''
        Set baseband filter bandwidth

        Possible values: 1.75, 2.5, 3.5, 5, 5.5, 6, 7, 8, 9, 10, 12, 14, 15, 20, 24, 28MHz, default 0.75 * sample_rate
        The functions `pyhackrf_compute_baseband_filter_bw` and `pyhackrf_compute_baseband_filter_bw_round_down_lt` can be used to get a valid value nearest to a given value.

        Setting the sample rate causes the filter bandwidth to be (re)set to its default 0.75 * sample_rate value, so setting sample rate should be done before setting filter bandwidth.
        '''
        ...

    def pyhackrf_set_freq(self, freq_hz: int) -> None:
        '''
        Set the center frequency

        This setting is not exact and depends on the PLL settings. Exact resolution is not determined, but the actual tuned frequency will be queryable in the future.

        Center frequency in Hz. Should be in range 0-7250MHz. The resolution is ~50Hz
        '''
        ...

    def pyhackrf_set_freq_explicit(self, i_freq_hz: int, lo_freq_hz: int, path: py_rf_path_filter) -> None:
        '''
        Set the center frequency via explicit tuning

        Center frequency is set to center_freqiency = `i_freq_hz` + k * `lo_freq_hz` where k = {-1; 0; 1}, depending on the value of `path`. See the documentation of `py_rf_path_filter` for details
        '''
        ...

    def pyhackrf_set_sample_rate_manual(self, freq_hz: int, divider: int) -> None:
        '''
        Set sample rate explicitly

        Sample rate should be in the range 2-20MHz. Lower & higher values are technically possible, but the performance is not guaranteed.

        This function sets the sample rate by specifying a clock frequency in Hz and a divider, so the resulting sample rate will be `freq_hz` / `divider`.

        This function also sets the baseband filter bandwidth to a value 0.75 * sample_rate, so any calls to `pyhackrf_set_baseband_filter_bandwidth` should only be made after this.
        '''
        ...

    def pyhackrf_set_sample_rate(self, freq_hz: float) -> None:
        '''
        Set sample rate

        Sample rate should be in the range 2-20MHz. Lower & higher values are technically possible, but the performance is not guaranteed.

        This function also sets the baseband filter bandwidth to a value 0.75 * sample_rate, so any calls to `pyhackrf_set_baseband_filter_bandwidth` should only be made after this.
        '''
        ...

    def pyhackrf_set_amp_enable(self, value: bool) -> None:
        '''
        Enable/disable 14dB RF amplifier

        Enable / disable the ~11dB RF RX/TX amplifiers U13/U25 via controlling switches U9 and U14.
        '''
        ...

    def pyhackrf_set_lna_gain(self, value: int) -> None:
        '''
        Set LNA gain

        Set the RF RX gain of the MAX2837 transceiver IC ("IF" gain setting) in decibels. Must be in range 0-40dB, with 8dB steps.
        '''
        ...

    def pyhackrf_set_vga_gain(self, value: int) -> None:
        '''Set baseband RX gain of the MAX2837 transceiver IC ("BB" or "VGA" gain setting) in decibels. Must be in range 0-62dB with 2dB steps.'''
        ...

    def pyhackrf_set_txvga_gain(self, value: int) -> None:
        '''Set RF TX gain of the MAX2837 transceiver IC ("IF" or "VGA" gain setting) in decibels. Must be in range 0-47dB in 1dB steps.'''
        ...

    def pyhackrf_set_antenna_enable(self, value: bool) -> None:
        '''
        Enable / disable bias-tee (antenna port power)

        Enable or disable the **3.3V (max 50mA)** bias-tee (antenna port power). Defaults to disabled.

        **Note:** the firmware auto-disables this after returning to IDLE mode, so a perma-set is not possible, which means all software supporting HackRF devices must support enabling bias-tee, as setting it externally is not possible.
        '''
        ...

    def pyhackrf_set_clkout_enable(self, value: bool) -> None:
        '''Enable / disable CLKOUT'''
        ...

    def pyhackrf_get_clkin_status(self) -> int:
        '''
        Get CLKIN status

        Check if an external clock signal is detected on the CLKIN port.
        '''
        ...

    # ---- streaming ---- #
    def pyhackrf_is_streaming(self) -> bool:
        '''Query device streaming status'''
        ...

    def pyhackrf_init_sweep(self,
                            frequency_list: list,
                            num_ranges: int,
                            num_bytes: int,
                            step_width: int,
                            offset: int,
                            style: py_sweep_style,
                            ) -> None:
        '''
        Initialize sweep mode

        In this mode, in a single data transfer (single call to the sweep callback), multiple blocks of size `num_bytes` bytes are received with different center frequencies. At the beginning of each block, a 10-byte frequency header is present in `0x7F - 0x7F - uint64_t frequency (LSBFIRST, in Hz)` format, followed by the actual samples.
        '''
        ...

    def pyhackrf_start_rx_sweep(self) -> None:
        '''Start RX sweep'''
        ...

    def pyhackrf_start_rx(self) -> None:
        '''
        Start receiving

        Should be called after setting gains, frequency and sampling rate, as these values won't get reset but instead keep their last value, thus their state is unknown.
        '''
        ...

    def pyhackrf_stop_rx(self) -> None:
        '''Stop receiving'''
        ...

    def pyhackrf_start_tx(self) -> None:
        '''
        Start transmitting

        Should be called after setting gains, frequency and sampling rate, as these values won't get reset but instead keep their last value, thus their state is unknown.

        Setting flush function pyhackrf_enable_tx_flush and/or setting block complete callback pyhackrf_set_tx_block_complete_callback (if these features are used) should also be done before this.
        '''
        ...

    def pyhackrf_stop_tx(self) -> None:
        '''Stop transmission'''
        ...

    def pyhackrf_enable_tx_block_complete_callback(self) -> None:
        '''
        Setup callback to be called when an USB transfer is completed.

        This callback will be called whenever an USB transfer to the device is completed, regardless if it was successful or not
        '''
        ...

    def pyhackrf_enable_tx_flush(self) -> None:
        '''
        Setup flush (end-of-transmission) callback

        This callback will be called when all the data was transmitted and all data transfers were completed.
        '''
        ...

    def pyhackrf_set_tx_underrun_limit(self, value: int) -> None:
        '''
        Set transmit underrun limit

        When this limit is set, after the specified number of samples (bytes, not whole IQ pairs) missing the device will automatically return to IDLE mode, thus stopping operation. Useful for handling cases like program/computer crashes or other problems. The default value 0 means no limit.
        '''
        ...

    def pyhackrf_set_rx_overrun_limit(self, value: int) -> None:
        '''
        Set receive overrun limit

        When this limit is set, after the specified number of samples (bytes, not whole IQ pairs) missing the device will automatically return to IDLE mode, thus stopping operation. Useful for handling cases like program/computer crashes or other problems. The default value 0 means no limit.
        '''
        ...

    def pyhackrf_set_hw_sync_mode(self, value: bool) -> None:
        '''
        Set hardware sync mode (hardware triggering)

        See the documentation on hardware triggering for details
        '''
        ...

    # ---- debug ---- #
    def pyhackrf_get_m0_state(self) -> dict:
        '''
        Get the state of the M0 code on the LPC43xx MCU

        requested_mode: Requested mode. Possible values are 0(IDLE), 1(WAIT), 2(RX), 3(TX_START), 4(TX_RUN)
        request_flag: Request flag, 0 means request is completed, any other value means request is pending
        active_mode: Active mode. Possible values are the same as in `hackrf_m0_state.requested_mode`
        m0_count: Number of bytes transferred by the M0
        m4_count: Number of bytes transferred by the M4
        num_shortfalls: Number of shortfalls
        longest_shortfall: Longest shortfall in bytes
        shortfall_limit: Shortfall limit in bytes
        threshold: Threshold m0_count value (in bytes) for next mode change
        next_mode: Mode which will be switched to when threshold is reached. Possible values are the same as in `hackrf_m0_state.requested_mode`
        error: Error, if any, that caused the M0 to revert to IDLE mode. Possible values are 0 (NONE), 1 (RX_TIMEOUT) and 2(TX_TIMEOUT)
        '''
        ...

    def pyhackrf_max2837_read(self, register_number: int) -> int:
        '''
        Directly read the registers of the MAX2837 transceiver IC

        Intended for debugging purposes only!
        '''
        ...

    def pyhackrf_max2837_write(self, register_number: int, value: int) -> None:
        '''
        Directly write the registers of the MAX2837 transceiver IC

        Intended for debugging purposes only!
        '''
        ...

    def pyhackrf_si5351c_read(self, register_number: int) -> int:
        '''
        Directly read the registers of the Si5351C clock generator IC

        Intended for debugging purposes only!
        '''
        ...

    def pyhackrf_si5351c_write(self, register_number: int, value: int) -> None:
        '''
        Directly write the registers of the Si5351 clock generator IC

        Intended for debugging purposes only!
        '''
        ...

    def pyhackrf_rffc5071_read(self, register_number: int) -> int:
        '''
        Directly read the registers of the RFFC5071/5072 mixer-synthesizer IC

        Intended for debugging purposes only!
        '''
        ...

    def pyhackrf_rffc5071_write(self, register_number: int, value: int) -> None:
        '''
        Directly write the registers of the RFFC5071/5072 mixer-synthesizer IC

        Intended for debugging purposes only!
        '''
        ...

    # ---- python callbacks setters ---- #
    def set_rx_callback(self, rx_callback_function: Callable[[Self, np.ndarray, int, int], int]) -> None:
        '''
        Accept a 4 args that contains the device, buffer, the maximum length and the length of the buffer data.
        device: PyHackrfDevice, buffer: numpy.array(dtype=numpy.int8), buffer_length: int, valid_length: int

        Should copy/process the contents of the buffer's valid part.

        The callback should return 0 if it wants to be called again, and any other value otherwise.
        '''
        ...

    def set_tx_callback(self, tx_callback_function: Callable[[Self, np.ndarray, int, int], tuple[int, np.ndarray, int]]) -> None:
        '''
        Accept a 4 args that contains the device, buffer, the maximum length and the length of the buffer data.
        device: PyHackrfDevice, buffer: numpy.array(dtype=numpy.int8), buffer_length: int, valid_length: int


        The callback should return 0 if it should be called again, and any other value otherwise.
        You should change the value of the valid_length variable to the number of modified elements in the buffer.
        '''
        ...

    def set_sweep_callback(self, sweep_callback_function: Callable[[Self, np.ndarray, int, int], int]) -> None:
        '''
        Accept a 4 args that contains the device, buffer, the maximum length and the length of the buffer data.
        device: PyHackrfDevice, buffer: numpy.array(dtype=numpy.int8), buffer_length: int, valid_length: int

        Should copy/process the contents of the buffer's valid part.

        The callback should return 0 if it wants to be called again, and any other value otherwise.
        * In this mode, with one data transfer (one callback call)
        '''
        ...

    def set_tx_complete_callback(self, tx_complete_callback_function: Callable[[Self, np.ndarray, int, int, bool], None]) -> None:
        '''
        Accept a 5 args that contains the device, buffer, the maximum length and the length of the buffer data.
        device: PyHackrfDevice, buffer: numpy.array(dtype=numpy.int8), buffer_length: int, valid_length: int
        and
        success: int # if the transfer was successful or not
        '''
        ...

    def set_tx_flush_callback(self, tx_flush_callback_function: Callable[[Self, int], None]) -> None:
        '''
        Accept 2 args that contains device and success flag
        device: PyHackrfDevice, success: int
        This callback will be called when all the data was transmitted and all data transfers were completed.
        '''
        ...

    # ---- library ---- #
    def pyhackrf_get_transfer_buffer_size(self) -> int:
        '''Get USB transfer buffer size.'''
        ...

    def pyhackrf_get_transfer_queue_depth(self) -> int:
        '''Get the total number of USB transfer buffers.'''
        ...

    # ---- operacake ---- #
    def pyhackrf_get_operacake_boards(self) -> list:
        '''
        Query connected Opera Cake boards

        Returns a list of operacake addresses where the maximum size is `PYHACKRF_OPERACAKE_MAX_BOARDS`
        '''
        ...

    def pyhackrf_set_operacake_mode(self, address: int, mode: py_operacake_switching_mode) -> None:
        '''Setup Opera Cake operation mode'''
        ...

    def pyhackrf_get_operacake_mode(self, address: int) -> py_operacake_switching_mode:
        '''Query Opera Cake mode'''
        ...

    def pyhackrf_set_operacake_ports(self, address: int, port_a: str, port_b: str) -> None:
        '''
        Setup Opera Cake ports in `py_operacake_switching_mode.OPERACAKE_MODE_MANUAL` mode operation

        Should be called after `pyhackrf_set_operacake_mode`. A0 and B0 must be connected to opposite sides (A->A and B->B or A->B and B->A but not A->A and B->A or A->B and B->B)
        '''
        ...

    def pyhackrf_set_operacake_dwell_times(self, dwell_times: list) -> None:
        '''
        Setup Opera Cake dwell times in `py_operacake_switching_mode.OPERACAKE_MODE_TIME` mode operation

        Should be called after `pyhackrf_set_operacake_mode`

        **Note:** this configuration applies to all Opera Cake boards in `py_operacake_switching_mode.OPERACAKE_MODE_TIME` mode
        '''
        ...

    def pyhackrf_set_operacake_freq_ranges(self, freq_ranges: list) -> None:
        '''
        Setup Opera Cake frequency ranges in `py_operacake_switching_mode.OPERACAKE_MODE_FREQUENCY` mode operation

        Should be called after `pyhackrf_set_operacake_mode`

        **Note:** this configuration applies to all Opera Cake boards in `py_operacake_switching_mode.OPERACAKE_MODE_FREQUENCY` mode
        '''
        ...

    def pyhackrf_operacake_gpio_test(self, address: int) -> int:
        '''
        Perform GPIO test on an Opera Cake addon board

        Value 0xFFFF means "GPIO mode disabled", and hackrf_operacake advises to remove additional add-on boards and retry.
        Value 0 means all tests passed.
        In any other values, a 1 bit signals an error. Bits are grouped in groups of 3. Encoding: 0 - u1ctrl - u3ctrl0 - u3ctrl1 - u2ctrl0 - u2ctrl1
        '''
        ...

# ---- initialization and exit ---- #
def pyhackrf_init() -> None:
    '''
    Initialize pylibhackrf

    Should be called before any other pylibhackrf function.
    Can be safely called multiple times.
    '''
    ...

def pyhackrf_exit() -> None:
    '''
    Exit pylibhackrf

    Should be called before exit. No other pylibhackrf functions should be called after it.
    Can be safely called multiple times.
    '''
    ...

# ---- version ---- #
def python_hackrf_library_version() -> str:
    '''Get python_hackrf library version'''
    ...

def pyhackrf_library_version() -> str:
    '''Get libhackrf library version'''
    ...

def pyhackrf_library_release() -> str:
    '''Get libhackrf library version'''
    ...

# ---- device ---- #
def pyhackrf_device_list() -> PyHackRFDeviceList:
    '''Return list of connected HackRF devices'''
    ...

def pyhackrf_device_list_open(pyhackrf_device_list: PyHackRFDeviceList, index: int) -> PyHackrfDevice | None:
    '''Open a HackRF device from a device list'''
    ...

def pyhackrf_open() -> PyHackrfDevice | None:
    '''Open first available HackRF device'''
    ...

def pyhackrf_open_by_serial(desired_serial_number: str) -> PyHackrfDevice | None:
    '''Open HackRF device by serial number'''
    ...

# ---- baseband filter bandwidth ---- #
def pyhackrf_compute_baseband_filter_bw_round_down_lt(bandwidth_hz: int) -> int:
    '''
    Compute nearest valid baseband filter bandwidth lower than a specified value

    The result can be used via `pyhackrf_set_baseband_filter_bandwidth`
    '''
    ...

def pyhackrf_compute_baseband_filter_bw(bandwidth_hz: int) -> int:
    '''
    Compute nearest valid baseband filter bandwidth to specified value

    The result can be used via `pyhackrf_set_baseband_filter_bandwidth`
    '''
    ...
