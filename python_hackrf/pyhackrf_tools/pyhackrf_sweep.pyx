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

try:
    from pyfftw.interfaces.numpy_fft import fft, fftshift  # type: ignore
except ImportError:
    try:
        from scipy.fft import fft, fftshift  # type: ignore
    except ImportError:
        from numpy.fft import fft, fftshift  # type: ignore

from libc.stdint cimport uint32_t, uint64_t
from python_hackrf import pyhackrf
import numpy as np
cimport numpy as cnp
import datetime
cimport cython
import signal
import struct
import time
import sys

cnp.import_array()

PY_FREQ_MIN_MHZ = 0  # 0 MHz
PY_FREQ_MAX_MHZ = 7_250  # 7250 MHz
PY_FREQ_MAX_HZ = PY_FREQ_MAX_MHZ * 1e6  # Hz
PY_BLOCKS_PER_TRANSFER = 16

# hackrf sweep settings
AVAILABLE_SAMPLING_RATES = (2_000_000, 4_000_000, 6_000_000, 8_000_000, 10_000_000, 12_000_000, 14_000_000, 16_000_000, 18_000_000, 20_000_000)
AVAILABLE_BASEBAND_FILTER_BANDWIDTHS = (1_750_000, 2_500_000, 3_500_000, 5_000_000, 5_500_000, 6_000_000, 7_000_000, 8_000_000, 9_000_000, 10_000_000, 12_000_000, 14_000_000, 15_000_000, 20_000_000, 24_000_000, 28_000_000)
INTERLEAVED_OFFSET_RATIO = 0.375
LINEAR_OFFSET_RATIO = 0.5

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
def sweep_callback(object device, cnp.ndarray[cnp.int8_t, ndim=1] buffer, int buffer_length, int valid_length):
    global run_available, device_data

    timestamp = datetime.datetime.now()
    cdef str time_str = timestamp.strftime('%Y-%m-%d, %H:%M:%S.%f')

    cdef dict current_device_data = device_data[device.serialno]
    cdef double norm_factor = 1 / current_device_data['fft_size']
    cdef uint32_t data_length = current_device_data['fft_size'] * 2
    cdef object sweep_style = current_device_data['sweep_style']
    cdef uint32_t sample_rate = current_device_data['sample_rate']
    cdef uint32_t fft_size = current_device_data['fft_size']
    cdef cnp.ndarray window = current_device_data['window']

    cdef uint64_t start_frequency = current_device_data['start_frequency']

    cdef cnp.ndarray fftOut
    cdef cnp.ndarray pwr

    cdef uint32_t fft_1_start = 1 + (fft_size * 5) // 8
    cdef uint32_t fft_1_stop = 1 + (fft_size * 5) // 8 + fft_size // 4

    cdef uint32_t fft_2_start = 1 + fft_size // 8
    cdef uint32_t fft_2_stop = 1 + fft_size // 8 + fft_size // 4

    cdef uint64_t frequency = 0
    cdef uint32_t index = 0
    cdef uint32_t i, j

    for j in range(PY_BLOCKS_PER_TRANSFER):
        if buffer[index] == 127 and buffer[index + 1] == 127:
            frequency = np.frombuffer(buffer[index + 2:index + 10].tobytes(), dtype=np.uint64)[0]
        else:
            index += pyhackrf.PY_BYTES_PER_BLOCK
            continue

        if frequency == start_frequency:
            if current_device_data['sweep_started']:
                current_device_data['sweep_count'] += 1
                if (
                    current_device_data['one_shot'] or
                    current_device_data['num_sweeps'] == current_device_data['sweep_count']
                ):
                    run_available[device.serialno] = False
            else:
                current_device_data['sweep_started'] = True

        if not run_available[device.serialno]:
            return -1

        if not current_device_data['sweep_started']:
            index += pyhackrf.PY_BYTES_PER_BLOCK
            continue

        if PY_FREQ_MAX_HZ < frequency:
            index += pyhackrf.PY_BYTES_PER_BLOCK
            continue

        index += (pyhackrf.PY_BYTES_PER_BLOCK - data_length)

        fftOut = fft((buffer[index:index + data_length:2] / 128 + 1j * buffer[index + 1:index + data_length:2] / 128) * window)
        pwr = np.log10(np.abs(fftOut * norm_factor) ** 2) * 10.0

        if sweep_style == pyhackrf.py_sweep_style.LINEAR:
            pwr = fftshift(pwr)

        index += data_length

        if current_device_data['binary_output']:
            if sweep_style == pyhackrf.py_sweep_style.INTERLEAVED:
                record_length = 16 + (fft_size // 4) * 4
                line = struct.pack('I', record_length)
                line += struct.pack('Q', frequency)
                line += struct.pack('Q', frequency + sample_rate // 4)
                line += struct.pack('<' + 'f' * (fft_size // 4), *pwr[fft_1_start:fft_1_stop])
                line += struct.pack('I', record_length)
                line += struct.pack('Q', frequency + sample_rate // 2)
                line += struct.pack('Q', frequency + (sample_rate * 3) // 4)
                line += struct.pack('<' + 'f' * (fft_size // 4), *pwr[fft_2_start:fft_2_stop])

            else:
                record_length = 16 + fft_size * 4
                line = struct.pack('I', record_length)
                line += struct.pack('Q', frequency)
                line += struct.pack('Q', frequency + sample_rate)
                line += struct.pack('<' + 'f' * fft_size, *pwr)

            current_device_data['file'].write(line)

        elif current_device_data['queue'] is not None:
            if sweep_style == pyhackrf.py_sweep_style.INTERLEAVED:
                current_device_data['queue'].put({
                    'timestamp': time_str,
                    'start_frequency': frequency,
                    'stop_frequency': frequency + sample_rate // 4,
                    'array': pwr[fft_1_start:fft_1_stop]
                })
                current_device_data['queue'].put({
                    'timestamp': time_str,
                    'start_frequency': frequency + sample_rate // 2,
                    'stop_frequency': frequency + (sample_rate * 3) // 4,
                    'array': pwr[fft_2_start:fft_2_stop]
                })

            else:
                current_device_data['queue'].put({
                    'timestamp': time_str,
                    'start_frequency': frequency,
                    'stop_frequency': frequency + sample_rate,
                    'array': pwr
                })

        else:
            if sweep_style == pyhackrf.py_sweep_style.INTERLEAVED:
                line = f'{time_str}, {frequency}, {frequency + sample_rate // 4}, {sample_rate / fft_size}, {fft_size}, '
                for value in pwr[fft_1_start:fft_1_stop]:
                    line += f'{value:.10f}, '
                line += f'\n{time_str}, {frequency + sample_rate // 2}, {frequency + (sample_rate * 3) // 4}, {sample_rate / fft_size}, {fft_size}, '
                for value in pwr[fft_2_start:fft_2_stop]:
                    line += f'{value:.10f}, '
                line = line[:len(line) - 2] + '\n'

            else:
                line = f'{time_str}, {frequency}, {frequency + sample_rate}, {sample_rate / fft_size}, {fft_size}, '
                for i in range(len(pwr)):
                    line += f'{pwr[i]:.2f}, '
                line = line[:len(line) - 2] + '\n'

            current_device_data['file'].write(line)

    current_device_data['accepted_bytes'] += valid_length

    return 0


def pyhackrf_sweep(frequencies: list = None, sample_rate: int = 20_000_000, baseband_filter_bandwidth: int = None,
                   lna_gain: int = 16, vga_gain: int = 20, bin_width: int = 100_000, amp_enable: bool = False, antenna_enable: bool = False,
                   sweep_style: pyhackrf.py_sweep_style = pyhackrf.py_sweep_style.INTERLEAVED, serial_number: str = None,
                   binary_output: bool = False, one_shot: bool = False, num_sweeps: int = None,
                   filename: str = None, queue: object = None,
                   print_to_console: bool = True):

    global run_available, device_data

    init_signals()
    pyhackrf.pyhackrf_init()

    if serial_number is None:
        device = pyhackrf.pyhackrf_open()
    else:
        device = pyhackrf.pyhackrf_open_by_serial(serial_number)

    run_available[device.serialno] = True

    sample_rate = int(sample_rate) if int(sample_rate) in AVAILABLE_SAMPLING_RATES else 20_000_000

    if baseband_filter_bandwidth is None:
        baseband_filter_bandwidth = int(sample_rate * .75)
    baseband_filter_bandwidth = int(baseband_filter_bandwidth) if int(baseband_filter_bandwidth) in AVAILABLE_BASEBAND_FILTER_BANDWIDTHS else pyhackrf.pyhackrf_compute_baseband_filter_bw(int(sample_rate * .75))

    cdef dict current_device_data = {
        'sweep_style': sweep_style if sweep_style in pyhackrf.py_sweep_style else pyhackrf.py_sweep_style.INTERLEAVED,
        'sample_rate': sample_rate,

        'sweep_started': False,
        'accepted_bytes': 0,
        'sweep_count': 0,
        'num_sweeps': num_sweeps,

        'start_frequency': None,
        'fft_size': None,
        'window': None,

        'binary_output': binary_output,
        'one_shot': one_shot,
        'file': open(filename, 'w' if not binary_output else 'wb') if filename is not None else (sys.stdout.buffer if binary_output else sys.stdout),
        'queue': queue
    }

    if frequencies is None:
        frequencies = [0, 6000]

    TUNE_STEP = sample_rate / 1e6
    if current_device_data['sweep_style'] == pyhackrf.py_sweep_style.INTERLEAVED:
        OFFSET = int(sample_rate * INTERLEAVED_OFFSET_RATIO)
    else:
        OFFSET = int(sample_rate * LINEAR_OFFSET_RATIO)

    device.set_sweep_callback(sweep_callback)

    if print_to_console:
        sys.stderr.write(f'call pyhackrf_set_sample_rate({sample_rate / 1e6 :.3f} MHz)\n')
    device.pyhackrf_set_sample_rate(sample_rate)

    if print_to_console:
        sys.stderr.write(f'call pyhackrf_set_baseband_filter_bandwidth({baseband_filter_bandwidth / 1e6 :.3f} MHz)\n')
    device.pyhackrf_set_baseband_filter_bandwidth(baseband_filter_bandwidth)

    if lna_gain % 8 and print_to_console:
        sys.stderr.write('Warning: lna_gain must be a multiple of 8\n')

    if vga_gain % 2 and print_to_console:
        sys.stderr.write('Warning: vga_gain must be a multiple of 2\n')

    device.pyhackrf_set_lna_gain(lna_gain)
    device.pyhackrf_set_vga_gain(vga_gain)

    if amp_enable:
        if print_to_console:
            sys.stderr.write('call pyhackrf_set_amp_enable(True)\n')
        device.pyhackrf_set_amp_enable(True)

    if antenna_enable:
        if print_to_console:
            sys.stderr.write('call pyhackrf_set_antenna_enable(True)\n')
        device.pyhackrf_set_antenna_enable(True)

    num_ranges = len(frequencies) // 2
    if pyhackrf.PY_MAX_SWEEP_RANGES < num_ranges:
        RuntimeError(f'specify a maximum of {pyhackrf.PY_MAX_SWEEP_RANGES} frequency ranges')

    for i in range(num_ranges):
        frequencies[2 * i] = int(frequencies[2 * i] * 1e6)
        frequencies[2 * i + 1] = int(frequencies[2 * i + 1] * 1e6)

        if frequencies[2 * i] >= frequencies[2 * i + 1]:
            raise RuntimeError('max frequency must be greater than min frequency.')

        step_count = 1 + (frequencies[2 * i + 1] - frequencies[2 * i] - 1) // TUNE_STEP
        frequencies[2 * i + 1] = int(frequencies[2 * i] + step_count * TUNE_STEP)

        if frequencies[2 * i] < PY_FREQ_MIN_MHZ:
            raise RuntimeError(f'min frequency must must be greater than {PY_FREQ_MIN_MHZ} MHz.')
        if frequencies[2 * i + 1] > PY_FREQ_MAX_MHZ:
            raise RuntimeError(f'max frequency may not be higher {PY_FREQ_MAX_MHZ} MHz.')

        if print_to_console:
            sys.stderr.write(f'Sweeping from {frequencies[2 * i]} MHz to {frequencies[2 * i + 1]} MHz\n')

    fft_size = int(sample_rate / bin_width)
    if fft_size < 4:
        raise RuntimeError(f'bin_width should be no more than {sample_rate // 4} Hz')
    elif fft_size > 8180:
        raise RuntimeError(f'bin_width should be no less than {sample_rate // 8180 + 1} Hz')

    while ((fft_size + 4) % 8):
        fft_size += 1

    current_device_data['start_frequency'] = int(frequencies[0] * 1e6)
    current_device_data['fft_size'] = fft_size
    current_device_data['window'] = np.hanning(fft_size)
    device_data[device.serialno] = current_device_data

    device.pyhackrf_init_sweep(frequencies, num_ranges, pyhackrf.PY_BYTES_PER_BLOCK, int(TUNE_STEP * 1e6), OFFSET, current_device_data['sweep_style'])
    device.pyhackrf_start_rx_sweep()

    cdef double time_start = time.time()
    cdef double time_prev = time.time()
    cdef double time_difference = 0
    cdef double sweep_rate = 0
    cdef double time_now = 0

    while device.pyhackrf_is_streaming() and run_available[device.serialno]:
        time.sleep(0.05)
        time_now = time.time()
        time_difference = time_now - time_prev
        if time_difference >= 1.0:
            if print_to_console:
                sweep_rate = current_device_data['sweep_count'] / (time_now - time_start)
                sys.stderr.write(f'{current_device_data["sweep_count"]} total sweeps completed, {round(sweep_rate, 2)} sweeps/second\n')

            if current_device_data['accepted_bytes'] == 0:
                if print_to_console:
                    sys.stderr.write('Couldn\'t transfer any data for one second.\n')
                break

            current_device_data['accepted_bytes'] = 0
            time_prev = time_now

    if filename is not None:
        current_device_data['file'].close()

    if print_to_console:
        if not run_available[device.serialno]:
            sys.stderr.write('\nExiting...\n')
        else:
            sys.stderr.write('\nExiting... [ pyhackrf streaming stopped ]\n')

    time_now = time.time()
    time_difference = time_now - time_prev
    if sweep_rate == 0 and time_difference > 0:
        sweep_rate = current_device_data['sweep_count'] / (time_now - time_start)

    if print_to_console:
        sys.stderr.write(f'Total sweeps: {current_device_data["sweep_count"]} in {time_now - time_start:.5f} seconds ({sweep_rate :.2f} sweeps/second)\n')

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
