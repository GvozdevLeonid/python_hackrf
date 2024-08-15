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

from queue import Queue
import numpy as np
import datetime
import signal
import struct
import time
import sys


AVAILABLE_SAMPLING_RATES = (2_000_000, 4_000_000, 6_000_000, 8_000_000, 10_000_000, 12_000_000, 14_000_000, 16_000_000, 18_000_000, 20_000_000)
AVAILABLE_BASEBAND_FILTER_BANDWIDTHS = (1_750_000, 2_500_000, 3_500_000, 5_000_000, 5_500_000, 6_000_000, 7_000_000, 8_000_000, 9_000_000, 10_000_000, 12_000_000, 14_000_000, 15_000_000, 20_000_000, 24_000_000, 28_000_000)
INTERLEAVED_OFFSET_RATIO = 0.375
LINEAR_OFFSET_RATIO = 0.5

PY_FREQ_MIN_MHZ = 0  # 0 MHz
PY_FREQ_MAX_MHZ = 7_250  # 7250 MHz
PY_FREQ_MAX_HZ = PY_FREQ_MAX_MHZ * 1e6  # Hz
PY_BLOCKS_PER_TRANSFER = 16

run_available = True

repeat_tx = False


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


def rx_callback(buffer: np.ndarray[:], buffer_length: int, valid_length: int):
    pass


def tx_callback(buffer: np.ndarray[:], buffer_length: int, valid_length: int):
    pass


def tx_complete_callback(buffer: np.ndarray[:], buffer_length: int, valid_length: int):
    pass


def flush_callback():
    pass


def pyhackrf_transfer():
    pass
