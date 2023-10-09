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

from python_hackrf import pyhackrf
try:
    from scipy.fft import fft
except ImportError:
    from numpy.fft import fft
import numpy as np
import datetime
import signal
import struct
import time
import sys


PY_FREQ_MIN_MHZ = 0 # 0 MHz 
PY_FREQ_MAX_MHZ = 7250 # 7250 MHz

# hackrf sweep settings
PY_DEFAULT_SAMPLE_RATE_HZ = 20000000 # 20MHz default sample rate
PY_DEFAULT_BASEBAND_FILTER_BANDWIDTH = 15000000 #15MHz default

PY_TUNE_STEP = PY_DEFAULT_SAMPLE_RATE_HZ / 1e6
PY_OFFSET = 7500000

PY_BLOCKS_PER_TRANSFER = 16

# hackrf sweep valiables
binary_output_mode = False
one_shot_mode = False

time_start = None
time_prev = None
time_now = None
time_second = datetime.timedelta(seconds=1)


fftSize = 20
window = None

step_count = 0
used_frequencies = None
sweep_started = False

run_available = True
max_num_sweeps = 0
check_max_num_sweeps = False
accepted_bytes = 0
sweep_rate = 0
sweep_count = 0

file_object = None
callback = None


def sigint_callback_handler(sig, frame):
    global run_available
    run_available = False
    print('', file=sys.stderr)


def init_signals():
    try:
        signal.signal(signal.SIGINT, sigint_callback_handler)
        signal.signal(signal.SIGILL, sigint_callback_handler)
        signal.signal(signal.SIGFPE, sigint_callback_handler)
        signal.signal(signal.SIGTERM, sigint_callback_handler)
        signal.signal(signal.SIGABRT, sigint_callback_handler)
    except:
        pass


def sweep_callback(buffer: np.ndarray, buffer_length: int, valid_length: int) -> int:
    global one_shot_mode, run_available, sweep_count, used_frequencies, sweep_started, check_max_num_sweeps, max_num_sweeps, fftSize, window, binary_output_mode, file_object, callback, accepted_bytes
    
    timestamp = datetime.datetime.now()
    frequency = None
    index = 0
    for j in range(PY_BLOCKS_PER_TRANSFER):
        if buffer[index] == 127 or buffer[index + 1] == 127:
            frequency = int.from_bytes(buffer[index + 9:index + 1: -1], byteorder='big', signed=False)
        else:
            index += pyhackrf.PY_BYTES_PER_BLOCK
            continue
        
        if frequency == int(used_frequencies[0] * 1e6):
            if sweep_started:
                sweep_count += 1
                if one_shot_mode:
                    run_available = False
                elif check_max_num_sweeps and max_num_sweeps == sweep_count:
                    run_available = False
                
            sweep_started = True
        
        if not run_available:
            return -1

        if not sweep_started:
            index += pyhackrf.PY_BYTES_PER_BLOCK
            continue
        
        if PY_FREQ_MAX_MHZ * 1e6 < frequency:
            index += pyhackrf.PY_BYTES_PER_BLOCK
            continue
        
        index += (pyhackrf.PY_BYTES_PER_BLOCK - (fftSize * 2))
        ibuffer = buffer[index : index + fftSize * 2].astype(np.int8)
        
        fftwIn = ibuffer[::2]/128 + 1j * ibuffer[1::2] / 128
        
        index += fftSize * 2
        fftwOut = fft(fftwIn * window)

        magsq = (fftwOut.real * (1 / fftSize)) ** 2 + (fftwOut.imag  * (1 / fftSize)) ** 2
        pwr = np.log2(magsq) * ( 10.0 / np.log2(10.0))

        if binary_output_mode:
            record_length = 16 + (fftSize // 4) * 4
            line = struct.pack('I', record_length)
            line += struct.pack('Q', frequency)
            line += struct.pack('Q', int(frequency + PY_DEFAULT_SAMPLE_RATE_HZ // 4))
            line += struct.pack('<' + 'f' * (fftSize // 4), *pwr[1 + (fftSize * 5) // 8 : 1 + (fftSize * 5) // 8 + fftSize // 4])
            line += struct.pack('I', record_length)
            line += struct.pack('Q', int(frequency + PY_DEFAULT_SAMPLE_RATE_HZ // 2))
            line += struct.pack('Q', int(frequency + (PY_DEFAULT_SAMPLE_RATE_HZ * 3) // 4))
            line += struct.pack('<' + 'f' * (fftSize // 4), *pwr[1 + fftSize // 8 : 1 + fftSize // 8 + fftSize // 4])

            if file_object is None:
                sys.stdout.buffer.write(line)
            else:
                file_object.write(line)
        else:
            time_str = timestamp.strftime("%Y-%m-%d, %H:%M:%S.%f")
            line = f'{time_str}, {int(frequency)}, {int(frequency + PY_DEFAULT_SAMPLE_RATE_HZ // 4)}, {(PY_DEFAULT_SAMPLE_RATE_HZ / fftSize)}, {fftSize}, '
            for i in range(fftSize // 4):
                line += f'{pwr[i + 1 + (fftSize * 5) // 8]:.2f}, '
            line += f'\n{time_str}, {int(frequency + PY_DEFAULT_SAMPLE_RATE_HZ // 2)}, {int(frequency + (PY_DEFAULT_SAMPLE_RATE_HZ * 3) // 4)}, {(PY_DEFAULT_SAMPLE_RATE_HZ / fftSize)}, {fftSize}, '
            for i in range(fftSize // 4):
                line += f'{pwr[i + 1 + (fftSize // 8)]:.2f}, '
            line += '\n'
            if callback is not None:
                callback({
                    'timestamp': time_str,
                    'start_frequency': frequency,
                    'stop_frequency': frequency + PY_DEFAULT_SAMPLE_RATE_HZ // 4,
                    'array': pwr[1 + (fftSize * 5) // 8 : 1 + (fftSize * 5) // 8 + fftSize // 4]
                })
                callback({
                    'timestamp': time_str,
                    'start_frequency': frequency + PY_DEFAULT_SAMPLE_RATE_HZ // 2,
                    'stop_frequency': frequency + (PY_DEFAULT_SAMPLE_RATE_HZ * 3) // 4,
                    'array': pwr[1 + fftSize // 8 : 1 + fftSize // 8 + fftSize // 4]
                })
            if file_object is None:
                print(line, end='')
            else:
                file_object.write(line)
        
    accepted_bytes += valid_length
    
    return 0


def pyhackrf_sweep(frequencies: list = [0, 6000], lna_gain: int = 16, vga_gain: int = 20, bin_width: int = 100000,
                         serial_number: str = None, amp_enable: bool = False, antenna_enable:bool = False,
                         num_sweeps: int = None, binary_output: bool = False, one_shot: bool = False, filename: str = None,
                         print_to_console: bool = True, device: pyhackrf.PyHackrfDevice = None):

    global file_object, one_shot_mode, binary_output_mode, check_max_num_sweeps, max_num_sweeps, used_frequencies, fftSize, window, sweep_count, sweep_rate

    init_signals()

    if filename is not None:
        file_object = open(filename, 'w' if not binary_output else 'wb')
    
    binary_output_mode = binary_output
    one_shot_mode = one_shot

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
        print(f'call pyhackrf_sample_rate_set({PY_DEFAULT_SAMPLE_RATE_HZ / 1e6 :.3f} MHz)', file=sys.stderr)
    device.pyhackrf_set_sample_rate_manual(PY_DEFAULT_SAMPLE_RATE_HZ, 1)

    if print_to_console:
        print(f'call pyhackrf_set_baseband_filter_bandwidth({PY_DEFAULT_BASEBAND_FILTER_BANDWIDTH / 1e6 :.3f} MHz)', file=sys.stderr)
    device.pyhackrf_set_baseband_filter_bandwidth(PY_DEFAULT_BASEBAND_FILTER_BANDWIDTH)

    device.pyhackrf_set_vga_gain(vga_gain)
    device.pyhackrf_set_lna_gain(lna_gain)

    num_ranges = len(frequencies) // 2
    if pyhackrf.PY_MAX_SWEEP_RANGES < num_ranges:
        RuntimeError(f'specify a maximum of {pyhackrf.PY_MAX_SWEEP_RANGES} frequency ranges')

    for i in range(num_ranges):
        if frequencies[2 * i] >= frequencies[2 * i + 1]:
            raise RuntimeError('max frequency must be greater than min frequency.')
        
        step_count = 1 + (frequencies[2 * i + 1] - frequencies[2 * i] - 1) // PY_TUNE_STEP
        frequencies[2 * i + 1] = int(frequencies[2 * i] + step_count * PY_TUNE_STEP)

        if frequencies[2 * i] < PY_FREQ_MIN_MHZ:
            raise RuntimeError(f'min frequency must must be greater than than {PY_FREQ_MIN_MHZ} MHz.')
        if frequencies[2 * i + 1] > PY_FREQ_MAX_MHZ:
            raise RuntimeError(f'max frequency may not be higher {PY_FREQ_MAX_MHZ} MHz.')
        
        if print_to_console:
            print(f'Sweeping from {frequencies[2 * i]} MHz to {frequencies[2 * i + 1]} MHz', file=sys.stderr)
    
    used_frequencies = frequencies[:]

    if not  2445 <= bin_width <= 5000000:
        raise RuntimeError(f'bin_width should be between 2445:5000000 Hz')

    fftSize = int(PY_DEFAULT_SAMPLE_RATE_HZ / bin_width)

    while ((fftSize + 4) % 8):
        fftSize += 1
    
    window = np.hanning(fftSize)

    device.pyhackrf_init_sweep(frequencies, num_ranges, pyhackrf.PY_BYTES_PER_BLOCK, int(PY_TUNE_STEP * 1e6), PY_OFFSET, pyhackrf.py_sweep_style.INTERLEAVED)

    if amp_enable:
        if print_to_console:
            print('call pyhackrf_set_amp_enable(True)', file=sys.stderr)
        device.pyhackrf_set_amp_enable(True)
        
    if antenna_enable:
        if print_to_console:
            print('call pyhackrf_set_antenna_enable(True)', file=sys.stderr)
        device.pyhackrf_set_antenna_enable(True)
    
    device.pyhackrf_start_rx_sweep()

    time_start = datetime.datetime.now()
    time_prev = datetime.datetime.now()
    while device.pyhackrf_is_streaming() and run_available:
        time.sleep(0.05)
        time_now = datetime.datetime.now()
        time_difference = time_now - time_prev
        if time_difference >= time_second:
            if print_to_console:
                sweep_rate = sweep_count / (time_now - time_start).total_seconds()
                print(f'{sweep_count} total sweeps completed, {sweep_rate :.2f} sweeps/second', file=sys.stderr)

            if accepted_bytes == 0:
                if print_to_console:
                    print('Couldn\'t transfer any data for one second.', file=sys.stderr)
                    break
                
            time_prev = time_now
    
    if filename is not None:
        file_object.close()
    
    if print_to_console:
        if not run_available:
            print('Exiting...', file=sys.stderr)
        else:
            print(f'Exiting... [ pyhackrf streaming stopped ]', file=sys.stderr)
            time.sleep(2)
    
    time_now = datetime.datetime.now()
    time_difference = time_now - time_prev
    if sweep_rate == 0 and time_difference.total_seconds() > 0:
        sweep_rate = sweep_count / (time_now - time_start).total_seconds()

    if print_to_console:
        print(f'Total sweeps: {sweep_count} in {(time_now - time_start).total_seconds():.5f} seconds ({sweep_rate :.2f}sweeps/second)', file=sys.stderr)
    
    try:
        device.pyhackrf_close()
        if print_to_console:
            print('pyhackrf_close() done', file=sys.stderr)
    except RuntimeError as e:
        print(e, file=sys.stderr)

    pyhackrf.pyhackrf_exit()
    if print_to_console:
        print('pyhackrf_exit() done', file=sys.stderr)
