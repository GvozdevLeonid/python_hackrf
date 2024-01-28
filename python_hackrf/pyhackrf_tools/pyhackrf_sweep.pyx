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
from python_hackrf import pyhackrf
try:
    from scipy.fft import fft, fftshift
except ImportError:
    from numpy.fft import fft, fftshift

from queue import Queue
cimport numpy as np
import numpy as np
import datetime
import signal
import struct
import time
import sys


PY_FREQ_MIN_MHZ = 0  # 0 MHz
PY_FREQ_MAX_MHZ = 7_250  # 7250 MHz
PY_FREQ_MAX_HZ = PY_FREQ_MAX_MHZ * 1e6 # Hz
PY_BLOCKS_PER_TRANSFER = 16

# hackrf sweep settings
AVAILABLE_SAMPLING_RATES = (2_000_000, 4_000_000, 6_000_000, 8_000_000, 10_000_000, 12_000_000, 14_000_000, 16_000_000, 18_000_000, 20_000_000)
AVAILABLE_BASEBAND_FILTER_BANDWIDTHS = (1_750_000, 2_500_000, 3_500_000, 5_000_000, 5_500_000, 6_000_000, 7_000_000, 8_000_000, 9_000_000, 10_000_000, 12_000_000, 14_000_000, 15_000_000, 20_000_000, 24_000_000, 28_000_000)
INTERLEAVED_OFFSET_RATIO = 0.375
LINEAR_OFFSET_RATIO = 0.5

SWEEP_STYLE = None

cdef int SAMPLE_RATE = 20_000_000
cdef int frequency_step_1 = 0
cdef int frequency_step_2 = 0
cdef int frequency_step_3 = 0


# hackrf sweep valiables
binary_output_mode = False
one_shot_mode = False
file_object = None
queue_mode = False

queue = Queue()
window = None

cdef double time_start = 0.
cdef double time_prev = 0.
cdef double time_now = 0.
cdef double time_second = 1.

cdef int fftSize = 20
cdef int data_length = 0


cdef int pwr_1_start = 0
cdef int pwr_1_stop = 0
cdef int pwr_2_start = 0
cdef int pwr_2_stop = 0
cdef float norm_factor = 0
cdef unsigned long start_frequency = 0

sweep_started = False
run_available = True
check_max_num_sweeps = False

cdef int max_num_sweeps = 0
cdef unsigned long long accepted_bytes = 0
cdef double sweep_rate = 0
cdef unsigned long long sweep_count = 0


def sigint_callback_handler(sig, frame):
    global run_available
    run_available = False
    sys.stderr.write('\n')

def init_signals():
    try:
        signal.signal(signal.SIGINT, sigint_callback_handler)
        signal.signal(signal.SIGILL, sigint_callback_handler)
        signal.signal(signal.SIGFPE, sigint_callback_handler)
        signal.signal(signal.SIGTERM, sigint_callback_handler)
        signal.signal(signal.SIGABRT, sigint_callback_handler)
    except Exception:
        pass


cdef sweep_callback(buffer: np.ndarray[:], buffer_length: int, valid_length: int):
    global fftSize, window, pwr_1_start, pwr_1_stop, pwr_2_start, pwr_2_stop, norm_factor, data_length, SAMPLE_RATE
    global start_frequency, sweep_count, sweep_started, max_num_sweeps, check_max_num_sweeps, accepted_bytes, one_shot_mode, run_available
    global binary_output_mode, file_object, queue_mode, SWEEP_STYLE
    global queue

    timestamp = datetime.datetime.now()
    time_str = timestamp.strftime("%Y-%m-%d, %H:%M:%S.%f")

    cdef unsigned long frequency = 0
    cdef int index = 0
    cdef int i, j
    for j in range(PY_BLOCKS_PER_TRANSFER):
        if buffer[index] == 127 and buffer[index + 1] == 127:
            frequency = np.frombuffer(buffer[index + 2:index + 10].tobytes(), dtype=np.uint64)[0]
        else:
            index += pyhackrf.PY_BYTES_PER_BLOCK
            continue

        if frequency == start_frequency:
            if sweep_started:
                sweep_count += 1
                if one_shot_mode or (check_max_num_sweeps and max_num_sweeps == sweep_count):
                    run_available = False

            sweep_started = True

        if not run_available:
            return -1

        if not sweep_started:
            index += pyhackrf.PY_BYTES_PER_BLOCK
            continue

        if PY_FREQ_MAX_HZ < frequency:
            index += pyhackrf.PY_BYTES_PER_BLOCK
            continue

        index += (pyhackrf.PY_BYTES_PER_BLOCK - data_length)

        fftwOut = fft((buffer[index: index + data_length: 2].astype(np.int8, copy=False) / 128 + 1j * buffer[index + 1: index + data_length: 2].astype(np.int8, copy=False) / 128) * window)
        pwr = np.log10(np.abs(fftwOut * norm_factor) ** 2) * 10.0

        if SWEEP_STYLE == pyhackrf.py_sweep_style.LINEAR:
            pwr = fftshift(pwr)

        index += data_length
        if binary_output_mode:
            if SWEEP_STYLE == pyhackrf.py_sweep_style.INTERLEAVED:
                record_length = 16 + (fftSize // 4) * 4
                line = struct.pack('I', record_length)
                line += struct.pack('Q', frequency)
                line += struct.pack('Q', frequency + frequency_step_1)
                line += struct.pack('<' + 'f' * (fftSize // 4), *pwr[pwr_1_start: pwr_1_stop])
                line += struct.pack('I', record_length)
                line += struct.pack('Q', frequency + frequency_step_2)
                line += struct.pack('Q', frequency + frequency_step_3)
                line += struct.pack('<' + 'f' * (fftSize // 4), *pwr[pwr_2_start: pwr_2_stop])

            else:
                record_length = 16 + fftSize * 4
                line = struct.pack('I', record_length)
                line += struct.pack('Q', frequency)
                line += struct.pack('Q', frequency + SAMPLE_RATE)
                line += struct.pack('<' + 'f' * fftSize, *pwr)

            if file_object is None:
                sys.stdout.buffer.write(line)
            else:
                file_object.write(line)

        elif queue_mode:
            if SWEEP_STYLE == pyhackrf.py_sweep_style.INTERLEAVED:
                queue.put_nowait({
                    'timestamp': time_str,
                    'start_frequency': frequency,
                    'stop_frequency': frequency + frequency_step_1,
                    'array': pwr[pwr_1_start: pwr_1_stop]
                })
                queue.put_nowait({
                    'timestamp': time_str,
                    'start_frequency': frequency + frequency_step_2,
                    'stop_frequency': frequency + frequency_step_3,
                    'array': pwr[pwr_2_start: pwr_2_stop]
                })

            else:
                queue.put_nowait({
                    'timestamp': time_str,
                    'start_frequency': frequency,
                    'stop_frequency': frequency + SAMPLE_RATE,
                    'array': pwr
                })

        else:
            if SWEEP_STYLE == pyhackrf.py_sweep_style.INTERLEAVED:
                line = f'{time_str}, {frequency}, {frequency + frequency_step_1}, {SAMPLE_RATE / fftSize}, {fftSize}, '
                pwr_1 = pwr[pwr_1_start: pwr_1_stop]
                for i in range(len(pwr_1)):
                    line += f'{pwr_1[i]:.10f}, '
                line += f'\n{time_str}, {frequency + frequency_step_2}, {frequency + frequency_step_3}, {SAMPLE_RATE / fftSize}, {fftSize}, '
                pwr_2 = pwr[pwr_2_start: pwr_2_stop]
                for i in range(len(pwr_2)):
                    line += f'{pwr_2[i]:.10f}, '
                line = line[:-2] + '\n'

            else:
                line = f'{time_str}, {frequency}, {frequency + SAMPLE_RATE}, {SAMPLE_RATE / fftSize}, {fftSize}, '
                for i in range(len(pwr)):
                    line += f'{pwr[i]:.2f}, '
                line = line[:-2] + '\n'

            if file_object is None:
                sys.stdout.write(line)
            else:
                file_object.write(line)

    accepted_bytes += valid_length

    return 0


def pyhackrf_sweep(frequencies: list = [0, 6000], lna_gain: int = 16, vga_gain: int = 20, bin_width: int = 100_000,
                   serial_number: str = None, amp_enable: bool = False, antenna_enable: bool = False, sample_rate: int = 20_000_000, baseband_filter: int = 15_000_000,
                   num_sweeps: int = None, binary_output: bool = False, one_shot: bool = False, use_queue: bool = False, filename: str = None, sweep_style: pyhackrf.py_sweep_style = pyhackrf.py_sweep_style.INTERLEAVED,
                   print_to_console: bool = True, device: pyhackrf.PyHackrfDevice = None):

    global fftSize, window, pwr_1_start, pwr_1_stop, pwr_2_start, pwr_2_stop, norm_factor, data_length, SAMPLE_RATE
    global start_frequency, sweep_count, sweep_started, max_num_sweeps, check_max_num_sweeps, accepted_bytes, one_shot_mode, run_available
    global binary_output_mode, file_object, queue_mode, SWEEP_STYLE
    global frequency_step_1, frequency_step_2, frequency_step_3
    global queue

    queue = Queue()

    if sweep_style in pyhackrf.py_sweep_style:
        SWEEP_STYLE = sweep_style
    else:
        SWEEP_STYLE = pyhackrf.sweep_stylepyhackrf.py_sweep_style.INTERLEAVED

    if sample_rate in AVAILABLE_SAMPLING_RATES:
        SAMPLE_RATE = int(sample_rate)
    else:
        SAMPLE_RATE = 20_000_000

    SAMPLE_RATE = int(sample_rate)

    if baseband_filter in AVAILABLE_BASEBAND_FILTER_BANDWIDTHS:
        BASEBAND_FILTER_BANDWIDTH = int(baseband_filter)
    else:
        BASEBAND_FILTER_BANDWIDTH = pyhackrf.pyhackrf_compute_baseband_filter_bw(int(baseband_filter))

    frequency_step_1 = sample_rate // 4
    frequency_step_2 = sample_rate // 2
    frequency_step_3 = (sample_rate * 3) // 4

    run_available = True
    sweep_count = 0
    sweep_rate = 0
    accepted_bytes = 0
    sweep_started = False

    TUNE_STEP = SAMPLE_RATE / 1e6
    if SWEEP_STYLE == pyhackrf.py_sweep_style.INTERLEAVED:
        OFFSET = int(SAMPLE_RATE * INTERLEAVED_OFFSET_RATIO)
    else:
        OFFSET = int(SAMPLE_RATE * LINEAR_OFFSET_RATIO)

    init_signals()

    if filename is not None:
        file_object = open(filename, 'w' if not binary_output else 'wb')

    binary_output_mode = binary_output
    one_shot_mode = one_shot
    queue_mode = use_queue

    if device is None:
        pyhackrf.pyhackrf_init()

        if num_sweeps is not None:
            check_max_num_sweeps = True
            max_num_sweeps = num_sweeps

        if serial_number is None:
            device = pyhackrf.pyhackrf_open()
        else:
            device = pyhackrf.pyhackrf_open_by_serial(serial_number)

    device.set_sweep_callback(sweep_callback)

    if print_to_console:
        sys.stderr.write(f'call pyhackrf_sample_rate_set({SAMPLE_RATE / 1e6 :.3f} MHz)\n')
    device.pyhackrf_set_sample_rate_manual(SAMPLE_RATE, 1)

    if print_to_console:
        sys.stderr.write(f'call pyhackrf_set_baseband_filter_bandwidth({BASEBAND_FILTER_BANDWIDTH / 1e6 :.3f} MHz)\n')
    device.pyhackrf_set_baseband_filter_bandwidth(BASEBAND_FILTER_BANDWIDTH)

    device.pyhackrf_set_vga_gain(vga_gain)
    device.pyhackrf_set_lna_gain(lna_gain)

    num_ranges = len(frequencies) // 2
    if pyhackrf.PY_MAX_SWEEP_RANGES < num_ranges:
        RuntimeError(f'specify a maximum of {pyhackrf.PY_MAX_SWEEP_RANGES} frequency ranges')

    for i in range(num_ranges):
        frequencies[i] = int(frequencies[i])

    for i in range(num_ranges):
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

    start_frequency = int(frequencies[0] * 1e6)

    fftSize = int(SAMPLE_RATE / bin_width)
    if fftSize < 4:
        raise RuntimeError(f'bin_width should be no more than {SAMPLE_RATE // 4} Hz')
    elif fftSize > 8180:
        raise RuntimeError(f'bin_width should be no less than {SAMPLE_RATE // 8180 + 1} Hz')

    while ((fftSize + 4) % 8):
        fftSize += 1

    pwr_1_start = 1 + (fftSize * 5) // 8
    pwr_1_stop = 1 + (fftSize * 5) // 8 + fftSize // 4

    pwr_2_start = 1 + fftSize // 8
    pwr_2_stop = 1 + fftSize // 8 + fftSize // 4

    norm_factor = 1.0 / fftSize
    data_length = fftSize * 2
    window = np.hanning(fftSize)

    device.pyhackrf_init_sweep(frequencies, num_ranges, pyhackrf.PY_BYTES_PER_BLOCK, int(TUNE_STEP * 1e6), OFFSET, sweep_style)

    if amp_enable:
        if print_to_console:
            sys.stderr.write('call pyhackrf_set_amp_enable(True)\n')
        device.pyhackrf_set_amp_enable(True)

    if antenna_enable:
        if print_to_console:
            sys.stderr.write('call pyhackrf_set_antenna_enable(True)\n')
        device.pyhackrf_set_antenna_enable(True)

    device.pyhackrf_start_rx_sweep()

    time_start = time.time()
    time_prev = time.time()
    while device.pyhackrf_is_streaming() and run_available:
        time.sleep(0.05)
        time_now = time.time()
        time_difference = time_now - time_prev
        if time_difference >= time_second:
            if print_to_console:
                sweep_rate = sweep_count / (time_now - time_start)
                sys.stderr.write(f'{sweep_count} total sweeps completed,{round(sweep_rate, 2)} sweeps/second\n')

            if accepted_bytes == 0:
                if print_to_console:
                    sys.stderr.write('Couldn\'t transfer any data for one second.\n')
                    break

            time_prev = time_now

    if filename is not None:
        file_object.close()

    if print_to_console:
        if not run_available:
            sys.stderr.write('Exiting...\n')
        else:
            sys.stderr.write('Exiting... [ pyhackrf streaming stopped ]\n')

    time_now = time.time()
    time_difference = time_now - time_prev
    if sweep_rate == 0 and time_difference > 0:
        sweep_rate = sweep_count / (time_now - time_start)

    if print_to_console:
        sys.stderr.write(f'Total sweeps: {sweep_count} in {time_now - time_start:.5f} seconds ({sweep_rate :.2f}sweeps/second)\n')

    try:
        device.pyhackrf_close()
        if print_to_console:
            sys.stderr.write('pyhackrf_close() done\n')
    except RuntimeError as e:
        sys.stderr.write(f'{e}\n')

    pyhackrf.pyhackrf_exit()
    if print_to_console:
        sys.stderr.write('pyhackrf_exit() done\n')

    run_available = False
