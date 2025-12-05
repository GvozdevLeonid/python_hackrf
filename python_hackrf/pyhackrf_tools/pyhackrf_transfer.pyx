# MIT License

# Copyright (c) 2023-2025 GvozdevLeonid

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

# distutils: language = c++
# cython: language_level = 3str
# cython: freethreading_compatible = True
from python_hackrf.pylibhackrf cimport pyhackrf as c_pyhackrf
from libc.stdint cimport uint64_t, uint8_t
from python_hackrf import pyhackrf
from libcpp.atomic cimport atomic
from libcpp cimport bool as c_bool
cimport numpy as cnp
import numpy as np
import threading
cimport cython
import signal
import time
import sys

cnp.import_array()

AVAILABLE_SAMPLING_RATES = (2_000_000, 4_000_000, 6_000_000, 8_000_000, 10_000_000, 12_000_000, 14_000_000, 16_000_000, 18_000_000, 20_000_000)
AVAILABLE_BASEBAND_FILTER_BANDWIDTHS = (1_750_000, 2_500_000, 3_500_000, 5_000_000, 5_500_000, 6_000_000, 7_000_000, 8_000_000, 9_000_000, 10_000_000, 12_000_000, 14_000_000, 15_000_000, 20_000_000, 24_000_000, 28_000_000)

FREQ_MIN_HZ = 0
FREQ_MAX_HZ = 7_250_000_000

SAMPLES_TO_XFER_MAX = 9_223_372_036_854_775_808
IF_MIN_HZ = 2_000_000_000
IF_MAX_HZ = 3_000_000_000
LO_MIN_HZ = 84_375_000
LO_MAX_HZ = 5_400_000_000

DEFAULT_FREQUENCY = 900_000_000
DEFAULT_LO_HZ = 1_000_000_000

cdef atomic[uint8_t] working_sdrs[16]
cdef dict sdr_ids = {}


def sigint_callback_handler(sig, frame, sdr_id):
    global working_sdrs
    working_sdrs[sdr_id].store(0)


def init_signals() -> int:
    global working_sdrs

    sdr_id = -1
    for i in range(16):
        if working_sdrs[i].load() == 0:
            sdr_id = i
            break

    if sdr_id >= 0:
        try:
            signal.signal(signal.SIGINT, lambda sig, frame: sigint_callback_handler(sig, frame, sdr_id))
            signal.signal(signal.SIGILL, lambda sig, frame: sigint_callback_handler(sig, frame, sdr_id))
            signal.signal(signal.SIGTERM, lambda sig, frame: sigint_callback_handler(sig, frame, sdr_id))
            signal.signal(signal.SIGABRT, lambda sig, frame: sigint_callback_handler(sig, frame, sdr_id))
        except Exception as ex:
            sys.stderr.write(f'Error: {ex}\n')

    return sdr_id


def stop_all() -> None:
    global working_sdrs
    for i in range(16):
        working_sdrs[i].store(0)


def stop_sdr(serialno: str) -> None:
    global sdr_ids, working_sdrs
    if serialno in sdr_ids:
        working_sdrs[sdr_ids[serialno]].store(0)


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef int rx_callback(c_pyhackrf.PyHackrfDevice device, cnp.ndarray[cnp.int8_t, ndim=1] buffer, int buffer_length, int valid_length):
    global working_sdrs

    cdef dict device_data = device.device_data
    cdef uint8_t device_id = device_data['device_id']

    if not working_sdrs[device_id].load():
        device_data['close_ready'].set()
        return -1

    device_data['byte_count'] += valid_length
    device_data['stream_power'] += np.sum(buffer[:valid_length].astype(np.int32) ** 2)

    cdef uint64_t to_read = valid_length
    if device_data['num_samples']:
        if (to_read > device_data['num_samples'] * 2):
            to_read = device_data['num_samples'] * 2
        device_data['num_samples'] -= (to_read // 2)

    cdef cnp.ndarray accepted_data = (buffer[:to_read:2] / 128 + 1j * buffer[1:to_read:2] / 128).astype(np.complex64)

    if device_data['rx_buffer'] is not None:
        device_data['rx_buffer'].append(accepted_data)
    else:
        accepted_data.tofile(device_data['rx_file'])

    if device_data['num_samples'] == 0:
        working_sdrs[device_id].store(0)
        device_data['close_ready'].set()
        return -1

    return 0


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef int tx_callback(c_pyhackrf.PyHackrfDevice device, cnp.ndarray[cnp.int8_t, ndim=1] buffer, int buffer_length, object valid_length):
    global working_sdrs

    cdef dict device_data = device.device_data
    cdef uint8_t device_id = device_data['device_id']

    if device_data['tx_complete'] or not working_sdrs[device_id].load():
        device_data['close_ready'].set()
        valid_length = 0
        return -1

    cdef uint64_t to_write = buffer_length // 2
    cdef uint64_t rewrited = 0
    cdef uint64_t writed = 0
    cdef bytes raw_data
    cdef cnp.ndarray sent_data
    cdef cnp.ndarray scaled_data
    if device_data['num_samples']:
        if (to_write > device_data['num_samples']):
            to_write = device_data['num_samples']
        device_data['num_samples'] -= to_write

    if device_data['tx_buffer'] is not None:

        sent_data = device_data['tx_buffer'].get_chunk(to_write, ring=device_data['repeat_tx'])

        if len(sent_data):
            writed = len(sent_data)
        else:
            # buffer is empty or finished
            device_data['tx_complete'] = True
            working_sdrs[device_id].store(0)
            device_data['close_ready'].set()
            valid_length = 0
            return -1

        scaled_data = (sent_data.view(np.float32) * 128).astype(np.int8)
        buffer[0:writed * 2:2] = scaled_data[0::2]
        buffer[1:writed * 2:2] = scaled_data[1::2]

        # limit samples
        if device_data['num_samples'] == 0:
            device_data['tx_complete'] = True
            working_sdrs[device_id].store(0)
            device_data['close_ready'].set()

        valid_length = writed * 2
        return 0

    else:
        raw_data = device_data['tx_file'].read(to_write * 8)
        if len(raw_data):
            writed = len(raw_data) // 8
        elif device_data['tx_file'].tell() < 1:
            # file is empty
            working_sdrs[device_id].store(0)
            device_data['close_ready'].set()
            valid_length = 0
            return -1
        else:
            writed = 0

        sent_data = np.frombuffer(raw_data, dtype=np.complex64)
        scaled_data = (sent_data.view(np.float32) * 128).astype(np.int8)
        buffer[0:writed * 2:2] = scaled_data[0::2]
        buffer[1:writed * 2:2] = scaled_data[1::2]

        # limit samples
        if device_data['num_samples'] == 0:
            device_data['tx_complete'] = True
            working_sdrs[device_id].store(0)
            device_data['close_ready'].set()
            valid_length = writed * 2
            return 0

        # buffer is full
        if to_write == writed:
            valid_length = writed * 2
            return 0

        # file is finished
        if not device_data['repeat_tx']:
            device_data['tx_complete'] = True
            working_sdrs[device_id].store(0)
            device_data['close_ready'].set()
            valid_length = writed * 2
            return 0

        # repeat file
        while writed < to_write:
            device_data['tx_file'].seek(0)
            raw_data = device_data['tx_file'].read((to_write - writed) * 8)
            if len(raw_data):
                rewrited = len(raw_data) // 8
            else:
                device_data['tx_complete'] = True
                working_sdrs[device_id].store(0)
                device_data['close_ready'].set()
                valid_length = writed * 2
                return 0

            sent_data = np.frombuffer(raw_data, dtype=np.complex64)
            scaled_data = (sent_data.view(np.float32) * 128).astype(np.int8)
            buffer[writed * 2:(writed + rewrited) * 2:2] = scaled_data[0::2]
            buffer[writed * 2 + 1:(writed + rewrited) * 2:2] = scaled_data[1::2]

            writed += rewrited

        valid_length = writed * 2
        return 0


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef void tx_complete_callback(c_pyhackrf.PyHackrfDevice device, cnp.ndarray[cnp.int8_t, ndim=1] buffer, int buffer_length, int valid_length, c_bool success):
    global working_sdrs

    cdef dict device_data = device.device_data
    cdef uint8_t device_id = device_data['device_id']

    if not success:
        working_sdrs[device_id].store(0)
        device_data['close_ready'].set()
        return

    device_data['byte_count'] += valid_length
    device_data['stream_power'] += np.sum(buffer[:valid_length].astype(np.int32) ** 2)


cpdef void flush_callback(c_pyhackrf.PyHackrfDevice device, c_bool success):
    global working_sdrs

    cdef dict device_data = device.device_data
    cdef uint8_t device_id = device_data['device_id']

    if success:
        device_data['flush_complete'] = True

    working_sdrs[device_id].store(0)
    device_data['close_ready'].set()


def pyhackrf_transfer(frequency: int | None = None, sample_rate: int = 10_000_000, baseband_filter_bandwidth: int | None = None, i_frequency: int | None = None, lo_frequency: int | None = None, image_reject: pyhackrf.py_rf_path_filter = pyhackrf.py_rf_path_filter.RF_PATH_FILTER_BYPASS,
                      rx_lna_gain: int = 16, rx_vga_gain: int = 20, tx_vga_gain: int = 0, amp_enable: bool = False, antenna_enable: bool = False,
                      repeat_tx: bool = False, synchronize: bool = False, num_samples: int | None = None, serial_number: str | None = None,
                      rx_filename: str | None = None, tx_filename: str | None = None, rx_buffer: object | None = None, tx_buffer: object | None = None,
                      print_to_console: bool = True) -> None:

    global working_sdrs, sdr_ids

    cdef uint8_t device_id = init_signals()
    cdef c_pyhackrf.PyHackrfDevice device
    pyhackrf.pyhackrf_init()

    if serial_number is None:
        device = pyhackrf.pyhackrf_open()
    else:
        device = pyhackrf.pyhackrf_open_by_serial(serial_number)

    working_sdrs[device_id].store(1)
    sdr_ids[device.serialno] = device_id

    sample_rate = int(sample_rate) if sample_rate and int(sample_rate) in AVAILABLE_SAMPLING_RATES else 10_000_000
    if baseband_filter_bandwidth is None:
        baseband_filter_bandwidth = int(sample_rate * .75)
    baseband_filter_bandwidth = int(baseband_filter_bandwidth) if int(baseband_filter_bandwidth) in AVAILABLE_BASEBAND_FILTER_BANDWIDTHS else pyhackrf.pyhackrf_compute_baseband_filter_bw(int(sample_rate * .75))

    if num_samples and num_samples >= SAMPLES_TO_XFER_MAX:
        raise RuntimeError(f'num_samples must be less than {SAMPLES_TO_XFER_MAX}')

    if (rx_buffer is not None or rx_filename is not None) and (tx_buffer is not None or tx_filename is not None):
        raise RuntimeError('HackRF cannot receive and send IQ samples at the same time.')

    if i_frequency is not None or lo_frequency is not None:
        if i_frequency is None:
            raise RuntimeError('i_frequency must be specified for explicit tuning')

        if image_reject is None:
            raise RuntimeError('image_reject must be specified for explicit tuning')

        if lo_frequency is None and image_reject != pyhackrf.py_rf_path_filter.RF_PATH_FILTER_BYPASS:
            raise RuntimeError('lo_frequency must be specified for explicit tuning unless image_reject is set to bypass.')

        if i_frequency > IF_MAX_HZ or i_frequency < IF_MIN_HZ:
            raise RuntimeError(f'i_frequency should be between {IF_MIN_HZ} and {IF_MAX_HZ}')

        if lo_frequency is None:
            lo_frequency = DEFAULT_LO_HZ
        elif lo_frequency > LO_MAX_HZ or lo_frequency < LO_MIN_HZ:
            raise RuntimeError(f'lo_frequency should be between {LO_MIN_HZ} and {LO_MAX_HZ}')

        if image_reject not in (pyhackrf.py_rf_path_filter.RF_PATH_FILTER_BYPASS, pyhackrf.py_rf_path_filter.RF_PATH_FILTER_LOW_PASS, pyhackrf.py_rf_path_filter.RF_PATH_FILTER_HIGH_PASS):
            raise RuntimeError('image_reject must be pyhackrf.py_rf_path_filter[RF_PATH_FILTER_BYPASS | RF_PATH_FILTER_LOW_PASS | RF_PATH_FILTER_HIGH_PASS]')

        if frequency and print_to_console:
            frequency = None
            sys.stderr.write('Warning: frequency ignored by explicit tuning selection.\n')

        if image_reject == pyhackrf.py_rf_path_filter.RF_PATH_FILTER_BYPASS:
            explicit_frequency = i_frequency
        elif image_reject == pyhackrf.py_rf_path_filter.RF_PATH_FILTER_LOW_PASS:
            explicit_frequency = i_frequency - lo_frequency
        elif image_reject == pyhackrf.py_rf_path_filter.RF_PATH_FILTER_HIGH_PASS:
            explicit_frequency = i_frequency + lo_frequency

        if print_to_console:
            sys.stderr.write(f'explicit tuning specified for {explicit_frequency} Hz\n')

    elif frequency is not None:
        if frequency > FREQ_MAX_HZ or frequency < FREQ_MIN_HZ:
            raise RuntimeError(f'frequency must be between {FREQ_MIN_HZ} and {FREQ_MAX_HZ}')

    else:
        frequency = DEFAULT_FREQUENCY

    if print_to_console:
        sys.stderr.write(f'call pyhackrf_set_sample_rate({sample_rate / 1e6 :.3f} MHz)\n')
    device.pyhackrf_set_sample_rate(sample_rate)

    if print_to_console:
        sys.stderr.write(f'call pyhackrf_set_baseband_filter_bandwidth({baseband_filter_bandwidth / 1e6 :.3f} MHz)\n')
    device.pyhackrf_set_baseband_filter_bandwidth(baseband_filter_bandwidth)

    if synchronize:
        if print_to_console:
            sys.stderr.write('call pyhackrf_set_hw_sync_mode(True)\n')
        device.pyhackrf_set_hw_sync_mode(True)

    if frequency is not None:
        if print_to_console:
            sys.stderr.write(f'call pyhackrf_set_freq({frequency} Hz / {frequency / 1e6 :.3f} MHz)\n')
        device.pyhackrf_set_freq(frequency)
    else:
        if print_to_console:
            sys.stderr.write(f'call pyhackrf_set_freq_explicit({i_frequency}, {lo_frequency}, {image_reject})\n')
        device.pyhackrf_set_freq_explicit(i_frequency, lo_frequency, image_reject)

    if amp_enable:
        if print_to_console:
            sys.stderr.write('call pyhackrf_set_amp_enable(True)\n')
        device.pyhackrf_set_amp_enable(True)

    cdef dict device_data = {
        'num_samples': num_samples,
        'flush_complete': False,
        'repeat_tx': repeat_tx,
        'tx_complete': False,
        'stream_power': 0,
        'byte_count': 0,

        'close_ready': threading.Event(),

        'rx_file': open(rx_filename, 'wb') if rx_filename not in ('-', None) else (sys.stdout.buffer if rx_filename == '-' else None),
        'tx_file': open(tx_filename, 'rb') if tx_filename not in ('-', None) else (sys.stdin.buffer if tx_filename == '-' else None),
        'rx_buffer': rx_buffer,
        'tx_buffer': tx_buffer
    }

    device.device_data = device_data

    if antenna_enable:
        if print_to_console:
            sys.stderr.write('call pyhackrf_set_antenna_enable(True)\n')
        device.pyhackrf_set_antenna_enable(True)

    if rx_buffer is not None or rx_filename is not None:
        if rx_lna_gain % 8 and print_to_console:
            sys.stderr.write('Warning: lna_gain must be a multiple of 8\n')

        if rx_vga_gain % 2 and print_to_console:
            sys.stderr.write('Warning: vga_gain must be a multiple of 2\n')

        device.pyhackrf_set_lna_gain(rx_lna_gain)
        device.pyhackrf_set_vga_gain(rx_vga_gain)

        device.set_rx_callback(rx_callback)
        device.pyhackrf_start_rx()

    elif tx_buffer is not None or tx_filename is not None:
        device.pyhackrf_set_txvga_gain(tx_vga_gain)
        device.pyhackrf_enable_tx_block_complete_callback()
        device.pyhackrf_enable_tx_flush()

        device.set_tx_flush_callback(flush_callback)
        device.set_tx_complete_callback(tx_complete_callback)
        device.set_tx_callback(tx_callback)
        device.pyhackrf_start_tx()

    if num_samples and print_to_console:
        sys.stderr.write(f'samples_to_xfer {num_samples}/{num_samples / 5e5:.3f} MB\n')

    cdef double time_start = time.time()
    cdef double time_prev = time.time()
    cdef double time_difference = 0
    cdef uint64_t byte_count = 0
    cdef uint64_t stream_power = 0
    cdef double dB_full_scale = 0

    while working_sdrs[device_id].load():
        time.sleep(0.05)
        time_now = time.time()
        time_difference = time_now - time_prev
        if time_difference >= 1.0:
            if print_to_console:
                byte_count, stream_power = device_data['byte_count'], device_data['stream_power']
                device_data['stream_power'], device_data['byte_count'] = 0, 0

                if byte_count == 0 and synchronize:
                    sys.stderr.write('Waiting for trigger...\n')
                elif byte_count != 0 and not device_data['flush_complete']:
                    dB_full_scale = 10 * np.log10(stream_power / ((byte_count / 2) * 127 ** 2))
                    sys.stderr.write(f'{(byte_count / time_difference) / 1e6:.1f} MB/second, average power {dB_full_scale:.1f} dBfs\n')
                elif byte_count == 0 and not synchronize and not device_data['flush_complete']:
                    if print_to_console:
                        sys.stderr.write('Couldn\'t transfer any data for one second.\n')
                    break

            time_prev = time_now

    time_now = time.time()
    if print_to_console:
        if not working_sdrs[device_id].load():
            sys.stderr.write('\nExiting...\n')
        else:
            sys.stderr.write('\nExiting... [ pyhackrf streaming stopped ]\n')

    if print_to_console:
        sys.stderr.write(f'Total time: {time_now - time_start:.5f} seconds\n')

    working_sdrs[device_id].store(0)
    device_data['close_ready'].wait()
    sdr_ids.pop(device.serialno, None)

    if rx_filename not in ('-', None):
        device_data['rx_file'].close()

    if tx_filename not in ('-', None):
        device_data['tx_file'].close()

    if rx_buffer is not None or rx_filename is not None:
        try:
            device.pyhackrf_stop_rx()
            if print_to_console:
                sys.stderr.write('pyhackrf_stop_rx() done\n')
        except Exception as e:
            sys.stderr.write(f'{e}\n')

    elif tx_buffer is not None or tx_filename is not None:
        try:
            device.pyhackrf_stop_tx()
            if print_to_console:
                sys.stderr.write('pyhackrf_stop_tx() done\n')
        except Exception as e:
            sys.stderr.write(f'{e}\n')

    if antenna_enable:
        try:
            device.pyhackrf_set_antenna_enable(False)
        except Exception as e:
            sys.stderr.write(f'{e}\n')

    try:
        device.pyhackrf_close()
        if print_to_console:
            sys.stderr.write('pyhackrf_close() done\n')
    except Exception as e:
        sys.stderr.write(f'{e}\n')

    try:
        pyhackrf.pyhackrf_exit()
        if print_to_console:
            sys.stderr.write('pyhackrf_exit() done\n')
    except Exception as e:
            sys.stderr.write(f'{e}\n')
