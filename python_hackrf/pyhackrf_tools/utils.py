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

import atexit
import io
import os
import sys
import time
from queue import Queue
from tempfile import NamedTemporaryFile
from threading import Event, RLock, Thread
from typing import Any

import numpy as np


class FileBuffer:
    '''
    A file-based buffer designed for efficient data transmission and reception, minimizing RAM usage.
    Provides methods for appending data, retrieving new data, accessing the entire buffer, and processing data in chunks.
    Supports ring-buffer behavior.
    '''
    def __init__(self, dtype: type = np.complex64, use_thread: bool = False) -> None:
        self._use_thread = use_thread
        self._dtype = dtype

        self._read_ptr = 0
        self._write_ptr = 0

        self._dtype_size = np.dtype(dtype).itemsize

        self._temp_file = NamedTemporaryFile(mode='r+b', delete=True)
        self._writer = io.FileIO(self._temp_file.name, mode='w')
        self._reader = io.FileIO(self._temp_file.name, mode='r')
        self._not_empty = Event()
        self._rlock = RLock()
        self._wlock = RLock()

        if use_thread:
            self._run_available = True
            self._queue = Queue()
            self._append_thread = Thread(target=self._append, daemon=True)
            self._append_thread.start()

        self._register_cleanup()

    def __del__(self) -> None:
        self._cleanup()

    def __getitem__(self, index: int | slice) -> Any:
        with self._rlock:

            write_ptr = self._write_ptr

            if write_ptr == 0:
                self._not_empty.clear()
                self._not_empty.wait()
                write_ptr = self._write_ptr

            size = write_ptr // self._dtype_size
            if isinstance(index, int):
                index = index + size if index < 0 else index
                if index < 0 or index >= size:
                    raise IndexError('index out of range')
                self._reader.seek(index * self._dtype_size)
                result = np.frombuffer(self._reader.read(self._dtype_size), dtype=self._dtype, count=1)[0]
                self._reader.seek(self._read_ptr)
                return result

            if isinstance(index, slice):
                start, stop, step = index.indices(size)
                byte_start, byte_stop = start * self._dtype_size, stop * self._dtype_size
                if byte_start < 0 or byte_start >= size or byte_stop < 0 or byte_stop >= size:
                    raise IndexError('slice out of range')
                self._reader.seek(byte_start)
                result = np.frombuffer(self._reader.read(byte_stop - byte_start), dtype=self._dtype)[::step]
                self._reader.seek(self._read_ptr)
                return result

            raise TypeError('index must be int or slice')

    def _cleanup(self) -> None:
        if self._temp_file:
            filepath = self._temp_file.name

            if self._use_thread:
                self._run_available = False

            try:
                with self._wlock:
                    with self._rlock:
                        self._reader.close()
                        self._writer.close()
                        self._temp_file.close()

            except Exception as er:
                print(f'Exception during cleanup: {er}', file=sys.stderr)

            if os.path.exists(filepath) and not self._save_file:
                os.remove(filepath)

    def _register_cleanup(self) -> None:
        atexit.register(self._cleanup)

    def _append(self) -> None:
        while self._run_available:
            if not self._queue.empty():
                data, chunk_size = self._queue.get_nowait()

                data = data.astype(self._dtype, copy=False)
                chunk_elements = chunk_size // self._dtype_size

                with self._wlock:
                    for i in range(0, len(data), chunk_elements):
                        chunk = data[i:i + chunk_elements]

                        self._writer.write(chunk)
                        self._write_ptr += self._dtype_size * chunk.size

                        self._not_empty.set()

                        if not self._run_available:
                            break
            else:
                time.sleep(.035)

    def append(self, data: np.ndarray, chunk_size: int = 131072) -> None:
        if len(data) == 0:
            return
        if self._use_thread:
            self._queue.put_nowait((data, chunk_size))
        else:
            data = data.astype(self._dtype, copy=False)
            chunk_elements = chunk_size // self._dtype_size

            with self._wlock:
                for i in range(0, len(data), chunk_elements):
                    chunk = data[i:i + chunk_elements]

                    self._writer.write(chunk)
                    self._write_ptr += self._dtype_size * chunk.size

                    self._not_empty.set()

                    if not self._run_available:
                        break

    def get_all(self, use_memmap: bool = False, wait: bool = False, timeout: float | None = None) -> np.ndarray:
        with self._rlock:

            if self._write_ptr == 0:
                self._not_empty.clear()
                if not self._not_empty.wait(timeout):
                    return np.array([], dtype=self._dtype)

            if not use_memmap:
                self._reader.seek(0)
                result = np.frombuffer(self._reader.read(), dtype=self._dtype)
                self._reader.seek(self._read_ptr)
                return result

            return np.memmap(self._temp_file, dtype=self._dtype)

    def get_new(self, wait: bool = False, timeout: float | None = None) -> np.ndarray:
        with self._rlock:

            write_ptr = self._write_ptr
            while write_ptr in {0, self._read_ptr}:
                if not wait:
                    return np.array([], dtype=self._dtype)

                self._not_empty.clear()
                if not self._not_empty.wait(timeout):
                    return np.array([], dtype=self._dtype)

                write_ptr = self._write_ptr

            result = np.frombuffer(self._reader.read(write_ptr - self._read_ptr), dtype=self._dtype)
            self._read_ptr = write_ptr
            return result

    def get_chunk(self, num_elements: int, ring: bool = True, wait: bool = False, timeout: float | None = None) -> np.ndarray:
        with self._rlock:

            if num_elements <= 0:
                return np.array([], dtype=self._dtype)

            write_ptr = self._write_ptr
            while write_ptr in {0, self._read_ptr}:
                if not wait:
                    return np.array([], dtype=self._dtype)

                self._not_empty.clear()
                if not self._not_empty.wait(timeout):
                    return np.array([], dtype=self._dtype)

                write_ptr = self._write_ptr

            total_bytes = num_elements * self._dtype_size
            available_bytes = write_ptr - self._read_ptr

            if available_bytes >= total_bytes:
                result = np.frombuffer(self._reader.read(total_bytes), dtype=self._dtype)
                self._read_ptr += total_bytes
                return result

            if not ring:
                result = np.frombuffer(self._reader.read(available_bytes), dtype=self._dtype)
                self._read_ptr += available_bytes
                return result

            result = np.empty(num_elements, dtype=self._dtype)
            filled_elements = 0
            while filled_elements < num_elements:
                if available_bytes <= 0:
                    available_bytes = write_ptr
                    self._reader.seek(0)
                    self._read_ptr = 0

                to_read = min((num_elements - filled_elements) * self._dtype_size, available_bytes)
                new_elements = to_read // self._dtype_size
                result[filled_elements: filled_elements + new_elements] = np.frombuffer(self._reader.read(to_read), dtype=self._dtype)
                filled_elements += new_elements
                available_bytes -= to_read
                self._read_ptr += to_read

            return result

    def empty(self) -> bool:
        return self._write_ptr == 0

    def has_new_data(self) -> bool:
        return self._read_ptr < self._write_ptr

    def size(self) -> int:
        return self._write_ptr // self._dtype_size

    def rewind(self) -> None:
        with self._rlock:
            self._reader.seek(0)
            self._read_ptr = 0

    def clear(self) -> None:
        if self._use_thread:
            self._run_available = False

        with self._wlock:
            with self._rlock:
                os.truncate(self._temp_file.fileno(), 0)
                self._reader.seek(0)
                self._writer.seek(0)
                self._write_ptr = 0
                self._read_ptr = 0

        if self._use_thread:
            self._run_available = True
            self._queue = Queue()
            self._append_thread = Thread(target=self._append, daemon=True)
            self._append_thread.start()
