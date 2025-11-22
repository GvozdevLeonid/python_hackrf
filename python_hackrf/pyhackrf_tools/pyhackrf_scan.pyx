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
from libc.stdint cimport uint64_t, uint32_t, uint8_t
from python_hackrf.pylibhackrf cimport pyhackrf as c_pyhackrf
from python_hackrf import pyhackrf
from libcpp.atomic cimport atomic
cimport numpy as cnp
import numpy as np
import threading
import signal
import time
import sys
import os

cnp.import_array()
FREQ_MIN_MHZ = 0  # 70 MHz
FREQ_MAX_MHZ = 7_250  # 6000 MHZ
FREQ_MIN_HZ = int(FREQ_MIN_MHZ * 1e6)  # Hz
FREQ_MAX_HZ = int(FREQ_MAX_MHZ * 1e6)  # Hz
AVAILABLE_SAMPLING_RATES = (2_000_000, 4_000_000, 6_000_000, 8_000_000, 10_000_000, 12_000_000, 14_000_000, 16_000_000, 18_000_000, 20_000_000)
AVAILABLE_BASEBAND_FILTER_BANDWIDTHS = (1_750_000, 2_500_000, 3_500_000, 5_000_000, 5_500_000, 6_000_000, 7_000_000, 8_000_000, 9_000_000, 10_000_000, 12_000_000, 14_000_000, 15_000_000, 20_000_000, 24_000_000, 28_000_000)


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


cpdef int rx_callback(c_pyhackrf.PyHackrfDevice device, cnp.ndarray[cnp.int8_t, ndim=1] buffer, int buffer_length, int valid_length):
    global working_sdrs

    cdef dict device_data = device.device_data
    cdef uint8_t device_id = device_data['device_id']
    cdef double divider = 1 / 128

    if not working_sdrs[device_id].load():
        device_data['close_ready'].set()
        device_data['hop_ready'].set()
        return -1

    cdef uint64_t to_read = valid_length
    if device_data['num_samples'] > 0:
        device_data['accepted_bytes'] += valid_length

        if (to_read > device_data['num_samples'] * 2):
            to_read = device_data['num_samples'] * 2

        device_data['buffer'][device_data['samples_per_scan'] - device_data['num_samples']: device_data['samples_per_scan'] - device_data['num_samples'] + (to_read // 2)] = (buffer[:to_read:2] * divider + 1j * buffer[1:to_read:2] * divider).astype(np.complex64)
        device_data['num_samples'] -= (to_read // 2)

        if device_data['num_samples'] == 0:
            device_data['hop_ready'].set()
    else:
        return -1

    return 0


def pyhackrf_scan(frequencies: list[int], samples_per_scan: int, queue: object, sample_rate: int = 20_000_000, baseband_filter_bandwidth: int | None = None,
                  lna_gain: int = 16, vga_gain: int = 20, amp_enable: bool = False, antenna_enable: bool = False, serial_number: str | None = None,
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

    sample_rate = int(sample_rate) if int(sample_rate) in AVAILABLE_SAMPLING_RATES else 20_000_000
    cdef uint64_t offset = int(sample_rate // 2)

    if baseband_filter_bandwidth is None:
        baseband_filter_bandwidth = int(sample_rate * .75)
    baseband_filter_bandwidth = int(baseband_filter_bandwidth) if int(baseband_filter_bandwidth) in AVAILABLE_BASEBAND_FILTER_BANDWIDTHS else pyhackrf.pyhackrf_compute_baseband_filter_bw(int(sample_rate * .75))

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
    calculated_frequencies = []
    if pyhackrf.PY_MAX_SWEEP_RANGES < num_ranges:
        RuntimeError(f'specify a maximum of {pyhackrf.PY_MAX_SWEEP_RANGES} frequency ranges')

    for i in range(num_ranges):
        frequencies[2 * i] = int(frequencies[2 * i] * 1e6)
        frequencies[2 * i + 1] = int(frequencies[2 * i + 1] * 1e6)

        if frequencies[2 * i] >= frequencies[2 * i + 1]:
            raise RuntimeError('max frequency must be greater than min frequency.')

        if frequencies[2 * i] < FREQ_MIN_HZ:
            raise RuntimeError(f'min frequency must must be greater than {FREQ_MIN_MHZ} MHz.')
        if frequencies[2 * i + 1] > FREQ_MAX_HZ:
            raise RuntimeError(f'max frequency may not be higher {FREQ_MAX_MHZ} MHz.')

        step_count = 1 + (frequencies[2 * i + 1] - frequencies[2 * i] - 1) // sample_rate
        frequencies[2 * i + 1] = int(frequencies[2 * i] + step_count * sample_rate)

        frequency = frequencies[2 * i]
        for j in range(step_count):
            calculated_frequencies.append(frequency)
            frequency += sample_rate

        if print_to_console:
            sys.stderr.write(f'Scaning from {frequencies[2 * i] / 1e6} MHz to {frequencies[2 * i + 1] / 1e6} MHz\n')

    cdef cnp.ndarray buffer = np.empty(samples_per_scan, dtype=np.complex64)
    cdef dict device_data = {
        'device_id': device_id,

        'accepted_bytes': 0,

        'samples_per_scan': samples_per_scan,
        'num_samples': samples_per_scan,
        'close_ready': threading.Event(),
        'hop_ready': threading.Event(),
        
        'buffer': buffer,
    }

    device.device_data = device_data
    device.set_rx_callback(rx_callback)

    cdef double time_start = time.time()
    cdef double time_prev = time.time()
    cdef double timestamp = time.time()
    cdef double time_difference = 0
    cdef double scan_rate = 0
    cdef double time_now = 0
    cdef uint64_t scan_count = 0
    cdef uint32_t tune_step = 0
    cdef uint32_t tune_steps = len(calculated_frequencies)
    cdef double delay = float(os.environ.get('pyhackrf_scan_await_time', 0.0002))

    device.pyhackrf_set_freq(calculated_frequencies[tune_step] + offset)
    tune_step = (tune_step + 1) % tune_steps
    device.pyhackrf_start_rx()

    while device.pyhackrf_is_streaming() and working_sdrs[device_id].load():
        time_now = time.time()
        time_difference = time_now - time_prev

        if time_difference >= 1.0:
            if print_to_console:
                scan_rate = scan_count / (time_now - time_start)
                sys.stderr.write(f'{scan_count} total scans completed, {round(scan_rate, 2)} scans/second\n')

            if device_data['accepted_bytes'] == 0:
                if print_to_console:
                    sys.stderr.write('Couldn\'t transfer any data for one second.\n')
                break

            device_data['accepted_bytes'] = 0
            time_prev = time_now

        if device_data['hop_ready'].wait():
            device_data['hop_ready'].clear()
            device.pyhackrf_stop_rx()

            queue.put({
                'start_frequency': calculated_frequencies[tune_step],
                'stop_frequency': calculated_frequencies[tune_step] + sample_rate,
                'raw_iq': buffer.copy(),
                'timestamp': timestamp,
            })

            device.pyhackrf_set_freq(calculated_frequencies[tune_step] + offset)
            time.sleep(delay)
            tune_step = (tune_step + 1) % tune_steps
            if tune_step == 0:
                scan_count += 1

            device_data['num_samples'] = samples_per_scan

            timestamp = time.time()
            device.pyhackrf_start_rx()

    if print_to_console:
        if not working_sdrs[device_id].load():
            sys.stderr.write('\nExiting...\n')
        else:
            sys.stderr.write('\nExiting... [ pyhackrf streaming stopped ]\n')

    time_now = time.time()
    time_difference = time_now - time_prev
    if scan_rate == 0 and time_difference > 0:
        scan_rate = scan_count / (time_now - time_start)

    if print_to_console:
        sys.stderr.write(f'Total scans: {scan_count} in {time_now - time_start:.5f} seconds ({scan_rate :.2f} scans/second)\n')

    working_sdrs[device_id].store(0)
    device_data['close_ready'].wait()
    sdr_ids.pop(device.serialno, None)

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
