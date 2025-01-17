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

from python_hackrf import pyhackrf
from libc.stdint cimport uint64_t
import numpy as np
cimport numpy as cnp
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

cdef dict run_available = {}
cdef dict device_data = {}


def sigint_callback_handler(sig, frame):
    global run_available
    for device in run_available.keys():
        run_available[device] = False


def init_signals():
    try:
        signal.signal(signal.SIGINT, sigint_callback_handler)
        signal.signal(signal.SIGILL, sigint_callback_handler)
        signal.signal(signal.SIGTERM, sigint_callback_handler)
        signal.signal(signal.SIGHUP, sigint_callback_handler)
        signal.signal(signal.SIGABRT, sigint_callback_handler)
    except Exception:
        pass


@cython.boundscheck(False)
@cython.wraparound(False)
def rx_callback(object device, cnp.ndarray[cnp.int8_t, ndim=1] buffer, int buffer_length, int valid_length):
    global run_available, device_data

    if not run_available[device.serialno]:
        return -1

    cdef dict current_device_data = device_data[device.serialno]

    current_device_data['byte_count'] += valid_length
    current_device_data['stream_power'] += np.sum(buffer[:valid_length].astype(np.int32) ** 2)

    cdef uint64_t to_read = valid_length
    if current_device_data['num_samples']:
        if (to_read > current_device_data['num_samples'] * 2):
            to_read = current_device_data['num_samples'] * 2
        current_device_data['num_samples'] -= (to_read // 2)

    cdef cnp.ndarray accepted_data = (buffer[:to_read:2] / 128 + 1j * buffer[1:to_read:2] / 128).astype(np.complex64)

    if current_device_data['rx_buffer'] is not None:
        current_device_data['rx_buffer'].append(accepted_data)
    else:
        accepted_data.tofile(current_device_data['rx_file'])

    if current_device_data['num_samples'] == 0:
        run_available[device.serialno] = False
        return -1

    return 0


@cython.boundscheck(False)
@cython.wraparound(False)
def tx_callback(object device, cnp.ndarray[cnp.int8_t, ndim=1] buffer, int buffer_length, object valid_length):
    global run_available, device_data

    cdef dict current_device_data = device_data[device.serialno]

    if current_device_data['tx_complete'] or not run_available[device.serialno]:
        valid_length = 0
        return -1

    cdef uint64_t to_write = buffer_length // 2
    cdef uint64_t rewrited = 0
    cdef uint64_t writed = 0
    cdef bytes raw_data
    cdef cnp.ndarray sent_data
    cdef cnp.ndarray scaled_data
    if current_device_data['num_samples']:
        if (to_write > current_device_data['num_samples']):
            to_write = current_device_data['num_samples']
        current_device_data['num_samples'] -= to_write

    if current_device_data['tx_buffer'] is not None:

        sent_data = current_device_data['tx_buffer'].get_chunk(to_write, ring=current_device_data['repeat_tx'])

        if len(sent_data):
            writed = len(sent_data)
        else:
            # buffer is empty or finished
            current_device_data['tx_complete'] = True
            run_available[device.serialno] = False
            valid_length = 0
            return -1

        scaled_data = (sent_data.view(np.float32) * 128).astype(np.int8)
        buffer[0:writed * 2:2] = scaled_data[0::2]
        buffer[1:writed * 2:2] = scaled_data[1::2]

        # limit samples
        if current_device_data['num_samples'] == 0:
            current_device_data['tx_complete'] = True
            run_available[device.serialno] = False

        valid_length = writed * 2
        return 0

    else:
        raw_data = current_device_data['tx_file'].read(to_write * 8)
        if len(raw_data):
            writed = len(raw_data) // 8
        elif current_device_data['tx_file'].tell() < 1:
            # file is empty
            run_available[device.serialno] = False
            valid_length = 0
            return -1
        else:
            writed = 0

        sent_data = np.frombuffer(raw_data, dtype=np.complex64)
        scaled_data = (sent_data.view(np.float32) * 128).astype(np.int8)
        buffer[0:writed * 2:2] = scaled_data[0::2]
        buffer[1:writed * 2:2] = scaled_data[1::2]

        # limit samples
        if current_device_data['num_samples'] == 0:
            current_device_data['tx_complete'] = True
            run_available[device.serialno] = False
            valid_length = writed * 2
            return 0

        # buffer is full
        if to_write == writed:
            valid_length = writed * 2
            return 0

        # file is finished
        if not current_device_data['repeat_tx']:
            current_device_data['tx_complete'] = True
            run_available[device.serialno] = False
            valid_length = writed * 2
            return 0

        # repeat file
        while writed < to_write:
            current_device_data['tx_file'].seek(0)
            raw_data = current_device_data['tx_file'].read((to_write - writed) * 8)
            if len(raw_data):
                rewrited = len(raw_data) // 8
            else:
                current_device_data['tx_complete'] = True
                run_available[device.serialno] = False
                valid_length = writed * 2
                return (0, valid_length)

            sent_data = np.frombuffer(raw_data, dtype=np.complex64)
            scaled_data = (sent_data.view(np.float32) * 128).astype(np.int8)
            buffer[writed * 2:(writed + rewrited) * 2:2] = scaled_data[0::2]
            buffer[writed * 2 + 1:(writed + rewrited) * 2:2] = scaled_data[1::2]

            writed += rewrited

        valid_length = writed * 2
        return 0


@cython.boundscheck(False)
@cython.wraparound(False)
def tx_complete_callback(object device, cnp.ndarray[cnp.int8_t, ndim=1] buffer, int buffer_length, int valid_length, int success):
    global run_available, device_data

    if not success:
        run_available[device.serialno] = False
        return

    cdef dict current_device_data = device_data[device.serialno]

    current_device_data['byte_count'] += valid_length
    current_device_data['stream_power'] += np.sum(buffer[:valid_length].astype(np.int32) ** 2)


def flush_callback(object device, int success):
    global run_available, device_data

    cdef dict current_device_data = device_data[device.serialno]

    if success:
        current_device_data['flush_complete'] = True

    run_available[device.serialno] = False


def pyhackrf_transfer(frequency: int = None, sample_rate: int = 10_000_000, baseband_filter_bandwidth: int = None, i_frequency: int = None, lo_frequency: int = None, image_reject: pyhackrf.py_rf_path_filter = pyhackrf.py_rf_path_filter.RF_PATH_FILTER_BYPASS,
                      rx_lna_gain: int = 16, rx_vga_gain: int = 20, tx_vga_gain: int = 0, amp_enable: bool = False, antenna_enable: bool = False,
                      repeat_tx: bool = False, synchronize: bool = False, num_samples: int = None, serial_number: str = None,
                      rx_filename: str = None, tx_filename: str = None, rx_buffer: object = None, tx_buffer: object = None,
                      print_to_console: bool = True):

    global run_available, device_data

    init_signals()
    pyhackrf.pyhackrf_init()

    if serial_number is None:
        device = pyhackrf.pyhackrf_open()
    else:
        device = pyhackrf.pyhackrf_open_by_serial(serial_number)

    run_available[device.serialno] = True

    sample_rate = int(sample_rate) if sample_rate and int(sample_rate) in AVAILABLE_SAMPLING_RATES else 10_000_000
    baseband_filter_bandwidth = int(baseband_filter_bandwidth) if baseband_filter_bandwidth and int(baseband_filter_bandwidth) in AVAILABLE_BASEBAND_FILTER_BANDWIDTHS else pyhackrf.pyhackrf_compute_baseband_filter_bw(int(sample_rate * .75))
    if num_samples and num_samples >= SAMPLES_TO_XFER_MAX:
        raise RuntimeError(f'num_samples must be less than {SAMPLES_TO_XFER_MAX}')

    cdef dict current_device_data = {
        'num_samples': num_samples,
        'flush_complete': False,
        'repeat_tx': repeat_tx,
        'tx_complete': False,
        'stream_power': 0,
        'byte_count': 0,

        'rx_file': open(rx_filename, 'wb') if rx_filename not in ('-', None) else (sys.stdout.buffer if rx_filename == '-' else None),
        'tx_file': open(tx_filename, 'rb') if tx_filename not in ('-', None) else (sys.stdin.buffer if tx_filename == '-' else None),
        'rx_buffer': rx_buffer,
        'tx_buffer': tx_buffer
    }
    device_data[device.serialno] = current_device_data

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
        sys.stderr.write(f'samples_to_xfer {num_samples}/{num_samples / 1e6:.3f} Mio\n')

    cdef double time_start = time.time()
    cdef double time_prev = time.time()
    cdef double time_difference = 0
    cdef uint64_t byte_count = 0
    cdef uint64_t stream_power = 0
    cdef double dB_full_scale = 0
    while run_available[device.serialno]:
        time.sleep(0.05)
        time_now = time.time()
        time_difference = time_now - time_prev
        if time_difference >= 1.0:
            if print_to_console:
                byte_count, stream_power = current_device_data['byte_count'], current_device_data['stream_power']
                current_device_data['stream_power'], current_device_data['byte_count'] = 0, 0

                if byte_count == 0 and synchronize:
                    sys.stderr.write('Waiting for trigger...\n')
                elif byte_count != 0 and not current_device_data['flush_complete']:
                    dB_full_scale = 10 * np.log10(stream_power / ((byte_count / 2) * 127 ** 2))
                    sys.stderr.write(f'{(byte_count / time_difference) / 1e6:.1f} MB/second, average power {dB_full_scale:.1f} dBfs\n')
                elif byte_count == 0 and not synchronize and not current_device_data['flush_complete']:
                    if print_to_console:
                        sys.stderr.write('Couldn\'t transfer any data for one second.\n')
                    break

            time_prev = time_now

    time_now = time.time()
    if print_to_console:
        if not run_available[device.serialno]:
            sys.stderr.write('\nExiting...\n')
        else:
            sys.stderr.write('\nExiting... [ pyhackrf streaming stopped ]\n')

    if print_to_console:
        sys.stderr.write(f'Total time: {time_now - time_start:.5f} seconds\n')
    time.sleep(.5)

    if rx_filename not in ('-', None):
        current_device_data['rx_file'].close()

    if tx_filename not in ('-', None):
        current_device_data['tx_file'].close()

    if rx_buffer is not None or rx_filename is not None:
        try:
            device.pyhackrf_stop_rx()
            if print_to_console:
                sys.stderr.write('pyhackrf_stop_rx() done\n')
        except RuntimeError as e:
            sys.stderr.write(f'{e}\n')

    elif tx_buffer is not None or tx_filename is not None:
        try:
            device.pyhackrf_stop_tx()
            if print_to_console:
                sys.stderr.write('pyhackrf_stop_tx() done\n')
        except RuntimeError as e:
            sys.stderr.write(f'{e}\n')

    device_data.pop(device.serialno, None)
    run_available.pop(device.serialno, None)

    try:
        device.pyhackrf_close()
        if print_to_console:
            sys.stderr.write('pyhackrf_close() done\n')
    except RuntimeError as e:
        sys.stderr.write(f'{e}\n')

    if not len(run_available):
        pyhackrf.pyhackrf_exit()
        if print_to_console:
            sys.stderr.write('pyhackrf_exit() done\n')
