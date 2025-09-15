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
# cython: language_level=3str
try:
    from pyfftw.interfaces.numpy_fft import fft, fftshift  # type: ignore
except ImportError:
    try:
        from scipy.fft import fft, fftshift  # type: ignore
    except ImportError:
        from numpy.fft import fft, fftshift  # type: ignore

from libc.stdint cimport uint64_t, uint32_t, uint8_t
from python_hackrf.pylibhackrf cimport pyhackrf as c_pyhackrf
from python_hackrf import pyhackrf
from libcpp.atomic cimport atomic
cimport numpy as cnp
import numpy as np
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
cpdef int sweep_callback(c_pyhackrf.PyHackrfDevice device, cnp.ndarray[cnp.int8_t, ndim=1] buffer, int buffer_length, int valid_length):
    global working_sdrs

    cdef str time_str = datetime.datetime.now().strftime('%Y-%m-%d, %H:%M:%S.%f')

    cdef dict device_data = device.device_data
    cdef double norm_factor = 1 / device_data['fft_size']
    cdef uint32_t data_length = device_data['fft_size'] * 2
    cdef object sweep_style = device_data['sweep_style']
    cdef uint32_t sample_rate = device_data['sample_rate']
    cdef uint32_t fft_size = device_data['fft_size']
    cdef cnp.ndarray window = device_data['window']
    cdef uint8_t device_id = device_data['device_id']

    cdef uint64_t start_frequency = device_data['start_frequency']

    cdef cnp.ndarray fftOut
    cdef cnp.ndarray raw_iq
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
            if device_data['sweep_started']:
                device_data['sweep_count'] += 1
                if (
                    device_data['one_shot'] or
                    device_data['num_sweeps'] == device_data['sweep_count']
                ):
                    working_sdrs[device_id].store(0)
            else:
                device_data['sweep_started'] = True

        if not working_sdrs[device_id].load():
            return -1

        if not device_data['sweep_started']:
            index += pyhackrf.PY_BYTES_PER_BLOCK
            continue

        if PY_FREQ_MAX_HZ < frequency:
            index += pyhackrf.PY_BYTES_PER_BLOCK
            continue

        index += (pyhackrf.PY_BYTES_PER_BLOCK - data_length)

        raw_iq = buffer[index:index + data_length:2] / 128 + 1j * buffer[index + 1:index + data_length:2] / 128
        raw_iq =  (raw_iq - raw_iq.mean()) * window 
        fftOut = fft(raw_iq)
        pwr = np.log10(np.abs(fftOut * norm_factor) ** 2) * 10.0

        if sweep_style == pyhackrf.py_sweep_style.LINEAR:
            pwr = fftshift(pwr)

        index += data_length

        if device_data['binary_output']:
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

            device_data['file'].write(line)

        elif device_data['queue'] is not None:
            if sweep_style == pyhackrf.py_sweep_style.INTERLEAVED:
                device_data['queue'].put({
                    'timestamp': time_str,
                    'start_frequency': frequency,
                    'stop_frequency': frequency + sample_rate // 4,
                    'fft': pwr[fft_1_start:fft_1_stop].astype(np.float32),
                })
                device_data['queue'].put({
                    'timestamp': time_str,
                    'start_frequency': frequency + sample_rate // 2,
                    'stop_frequency': frequency + (sample_rate * 3) // 4,
                    'fft': pwr[fft_2_start:fft_2_stop].astype(np.float32),
                })

            else:
                device_data['queue'].put({
                    'timestamp': time_str,
                    'start_frequency': frequency,
                    'stop_frequency': frequency + sample_rate,
                    'fft': pwr.astype(np.float32),
                    'raw_iq': raw_iq,
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

            device_data['file'].write(line)

    device_data['accepted_bytes'] += valid_length

    return 0


def pyhackrf_sweep(frequencies: list[int] | None = None, sample_rate: int = 20_000_000, baseband_filter_bandwidth: int | None = None,
                   lna_gain: int = 16, vga_gain: int = 20, bin_width: int = 100_000, amp_enable: bool = False, antenna_enable: bool = False,
                   sweep_style: pyhackrf.py_sweep_style = pyhackrf.py_sweep_style.INTERLEAVED, serial_number: str | None = None,
                   binary_output: bool = False, one_shot: bool = False, num_sweeps: int | None = None,
                   filename: str | None = None, queue: object | None = None,
                   print_to_console: bool = True) -> None:

    global working_sdrs, sdr_ids

    cdef uint8_t device_id = init_signals()
    cdef c_pyhackrf.PyHackrfDevice device
    cdef uint32_t offset = 0
    cdef int i

    pyhackrf.pyhackrf_init()

    if serial_number is None:
        device = pyhackrf.pyhackrf_open()
    else:
        device = pyhackrf.pyhackrf_open_by_serial(serial_number)

    working_sdrs[device_id].store(1)
    sdr_ids[device.serialno] = device_id

    sample_rate = int(sample_rate) if int(sample_rate) in AVAILABLE_SAMPLING_RATES else 20_000_000

    if baseband_filter_bandwidth is None:
        baseband_filter_bandwidth = int(sample_rate * .75)
    baseband_filter_bandwidth = int(baseband_filter_bandwidth) if int(baseband_filter_bandwidth) in AVAILABLE_BASEBAND_FILTER_BANDWIDTHS else pyhackrf.pyhackrf_compute_baseband_filter_bw(int(sample_rate * .75))

    sweep_style = sweep_style if sweep_style in pyhackrf.py_sweep_style else pyhackrf.py_sweep_style.INTERLEAVED

    if frequencies is None:
        frequencies = [0, 6000]

    TUNE_STEP = sample_rate / 1e6
    if sweep_style == pyhackrf.py_sweep_style.INTERLEAVED:
        offset = int(sample_rate * INTERLEAVED_OFFSET_RATIO)
    else:
        offset = int(sample_rate * LINEAR_OFFSET_RATIO)

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
        frequencies[2 * i] = int(frequencies[2 * i])
        frequencies[2 * i + 1] = int(frequencies[2 * i + 1])

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

    cdef dict device_data = {
        'device_id': device_id,

        'sweep_style': sweep_style,
        'sample_rate': sample_rate,

        'sweep_started': False,
        'accepted_bytes': 0,
        'sweep_count': 0,
        'num_sweeps': num_sweeps,

        'start_frequency': int(frequencies[0] * 1e6),
        'fft_size': fft_size,
        'window': np.hanning(fft_size),

        'binary_output': binary_output,
        'one_shot': one_shot,
        'file': open(filename, 'w' if not binary_output else 'wb') if filename is not None else (sys.stdout.buffer if binary_output else sys.stdout),
        'queue': queue
    }

    device.device_data = device_data

    device.pyhackrf_init_sweep(frequencies, num_ranges, pyhackrf.PY_BYTES_PER_BLOCK, int(TUNE_STEP * 1e6), offset, sweep_style)
    device.pyhackrf_start_rx_sweep()

    cdef double time_start = time.time()
    cdef double time_prev = time.time()
    cdef double time_difference = 0
    cdef double sweep_rate = 0
    cdef double time_now = 0

    while device.pyhackrf_is_streaming() and working_sdrs[device_id].load():
        time.sleep(0.05)
        time_now = time.time()
        time_difference = time_now - time_prev
        if time_difference >= 1.0:
            if print_to_console:
                sweep_rate = device_data['sweep_count'] / (time_now - time_start)
                sys.stderr.write(f'{device_data["sweep_count"]} total sweeps completed, {round(sweep_rate, 2)} sweeps/second\n')

            if device_data['accepted_bytes'] == 0:
                if print_to_console:
                    sys.stderr.write('Couldn\'t transfer any data for one second.\n')
                break

            device_data['accepted_bytes'] = 0
            time_prev = time_now

    if filename is not None:
        device_data['file'].close()

    if print_to_console:
        if not working_sdrs[device_id].load():
            sys.stderr.write('\nExiting...\n')
        else:
            sys.stderr.write('\nExiting... [ pyhackrf streaming stopped ]\n')

    time_now = time.time()
    time_difference = time_now - time_prev
    if sweep_rate == 0 and time_difference > 0:
        sweep_rate = device_data['sweep_count'] / (time_now - time_start)

    if print_to_console:
        sys.stderr.write(f'Total sweeps: {device_data["sweep_count"]} in {time_now - time_start:.5f} seconds ({sweep_rate :.2f} sweeps/second)\n')

    sdr_ids.pop(device.serialno, None)
    working_sdrs[device_id].store(0)
    device.device_data = {}

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
