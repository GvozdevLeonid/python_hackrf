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

import mmap
import os
import pickle
import sys
from queue import Queue
from tempfile import NamedTemporaryFile
from threading import Lock
from typing import Any, Self

import numpy as np


class FileBuffer:
    '''
    A file-based buffer designed for efficient data transmission and reception, minimizing RAM usage.
    Provides methods for appending data, retrieving new data, accessing the entire buffer, and processing data in chunks.
    Supports ring-buffer behavior.
    '''
    def __init__(self, dtype: type = np.complex64) -> None:
        self._dtype = dtype

        self._read_ptr = 0
        self._write_ptr = 0

        self._dtype_size = np.dtype(dtype).itemsize

        self._temp_file = NamedTemporaryFile(mode='r+b', delete=True)
        self._lock = Lock()

    def __getitem__(self, index: int | slice) -> Any:
        with self._lock:
            size = self._write_ptr // self._dtype_size
            if isinstance(index, int):
                index = index + size if index < 0 else index
                if index < 0 or index >= size:
                    raise IndexError('index out of range')
                byte_start = index * self._dtype_size
                self._temp_file.seek(byte_start)
                return np.frombuffer(self._temp_file.read(self._dtype_size), dtype=self._dtype, count=1)[0]

            if isinstance(index, slice):
                start, stop, step = index.indices(size)
                byte_start, byte_stop = start * self._dtype_size, stop * self._dtype_size
                self._temp_file.seek(byte_start)
                return np.frombuffer(self._temp_file.read(byte_stop - byte_start), dtype=self._dtype)[::step]

        raise TypeError("index must be int or slice")

    def append(self, data: np.ndarray) -> None:
        with self._lock:
            data = data.astype(self._dtype, copy=False)
            data_bytes = data.tobytes()

            self._temp_file.seek(self._write_ptr)
            self._temp_file.write(data_bytes)
            self._write_ptr += len(data_bytes)

    def get_all(self) -> np.ndarray:
        with self._lock:
            if self._write_ptr == 0:
                return np.array([], dtype=self._dtype)
            self._temp_file.seek(0)
            return np.frombuffer(self._temp_file.read(), dtype=self._dtype)

    def get_new(self) -> np.ndarray:
        with self._lock:
            if self._read_ptr == self._write_ptr:
                return np.array([], dtype=self._dtype)
            self._temp_file.seek(self._read_ptr)
            result = np.frombuffer(self._temp_file.read(), dtype=self._dtype)
            self._read_ptr = self._write_ptr
            return result

    def get_chunk(self, num_elements: int, ring: bool = True) -> np.ndarray:
        with self._lock:

            if num_elements <= 0 or self._write_ptr == 0:
                return np.array([], dtype=self._dtype)

            total_bytes = num_elements * self._dtype_size
            available_bytes = self._write_ptr - self._read_ptr

            if available_bytes >= total_bytes:
                self._temp_file.seek(self._read_ptr)
                result = np.frombuffer(self._temp_file.read(total_bytes), dtype=self._dtype)
                self._read_ptr += total_bytes
                return result

            if not ring:
                self._temp_file.seek(self._read_ptr)
                result = np.frombuffer(self._temp_file.read(), dtype=self._dtype)
                self._read_ptr = self._write_ptr
                return result

            result = np.empty(num_elements, dtype=self._dtype)
            filled_elements = 0
            while filled_elements < num_elements:
                available_bytes = self._write_ptr - self._read_ptr
                if available_bytes <= 0:
                    self._read_ptr = 0
                    available_bytes = self._write_ptr - self._read_ptr

                to_read = min((num_elements - filled_elements) * self._dtype_size, available_bytes)
                new_elements = to_read // self._dtype_size
                self._temp_file.seek(self._read_ptr)
                result[filled_elements: filled_elements + new_elements] = np.frombuffer(self._temp_file.read(to_read), dtype=self._dtype)
                filled_elements += new_elements
                self._read_ptr += to_read

            return result

    def empty(self) -> bool:
        return self._write_ptr == 0

    def has_new_data(self) -> bool:
        return self._read_ptr < self._write_ptr

    def size(self) -> int:
        return self._write_ptr // self._dtype_size

    def rewind(self) -> None:
        with self._lock:
            self._read_ptr = 0

    def clear(self) -> None:
        with self._lock:
            os.truncate(self._temp_file.fileno(), 0)
            self._write_ptr = 0
            self._read_ptr = 0


class MmapQueue:
    '''
    A memory-mapped queue for handling serialized Python objects, optimized for large-scale data storage and retrieval.
    Utilizes file-based storage to minimize RAM usage and dynamically resizes with efficient memory management via an interval tree.
    Suitable  in resource-constrained environments.
    '''

    class IntervalTreeNode:
        def __init__(self, start: int, end: int) -> None:
            self.start: int = start
            self.end: int = end
            self.parent_node: Self = None
            self.left_node: Self = None
            self.right_node: Self = None

            self._max_length = None
            self._min_start = None
            self._max_end = None

            self._height: int = 1

        @property
        def length(self) -> int:
            return self.end - self.start

        @property
        def max_length(self) -> int:
            if self._max_length is None:
                return self.update_max_length()
            return self._max_length

        def update_max_length(self) -> int:
            self._max_length = max(self.length,
                    self.left_node.update_max_length() if self.left_node else 0,
                    self.right_node.update_max_length() if self.right_node else 0)

            return self._max_length

        @property
        def min_start(self) -> int:
            if self._min_start is None:
                return self.update_min_start()
            return self._min_start

        def update_min_start(self) -> int:
            self._min_start = min(self.start, self.left_node.update_min_start() if self.left_node else self.start)
            return self._min_start

        @property
        def max_end(self) -> int:
            if self._max_end is None:
                return self.update_max_end()
            return self._max_end

        def update_max_end(self) -> int:
            self._max_end = max(self.end, self.right_node.update_max_end() if self.right_node else self.end)
            return self._max_end

        @property
        def height(self) -> int:
            if self._height is None:
                return self.update_height()
            return self._height

        def update_height(self) -> int:
            self._height = 1 + max(self.left_node.update_height() if self.left_node else 0,
                                self.right_node.update_height() if self.right_node else 0)
            return self._height

        @property
        def balance_factor(self) -> int:
            left_height = self.left_node.height if self.left_node else 0
            right_height = self.right_node.height if self.right_node else 0
            return left_height - right_height

    class IntervalTree:
        def __init__(self) -> None:
            self.root: MmapQueue.IntervalTreeNode = None

        def __str__(self) -> str:
            def recurse(node: 'MmapQueue.IntervalTreeNode', depth: int = 0) -> str:
                if not node:
                    return ""
                left = recurse(node.left_node, depth + 1)
                right = recurse(node.right_node, depth + 1)
                return f"{'  ' * depth}[{node.start}, {node.end}] (H={node.height})\n{left}{right}"

            return recurse(self.root)

        def _insert_node(self, parent_node: 'MmapQueue.IntervalTreeNode', child_node: 'MmapQueue.IntervalTreeNode') -> None:
            if parent_node is None:
                self.root = child_node
                return

            while True:
                if child_node.end < parent_node.start:
                    if parent_node.left_node is None:
                        parent_node.left_node = child_node
                        child_node.parent_node = parent_node
                        return
                    parent_node = parent_node.left_node
                elif child_node.start > parent_node.end:
                    if parent_node.right_node is None:
                        parent_node.right_node = child_node
                        child_node.parent_node = parent_node
                        return
                    parent_node = parent_node.right_node

                elif child_node.end == parent_node.start or parent_node.end == child_node.start:
                    self._merge(parent_node, child_node)
                    return
                else:
                    raise ValueError(f'Unexpected overlap: [{child_node.start}, {child_node.end}) intersects with [{parent_node.start}, {parent_node.end}).')

        def _merge(self, target_node: 'MmapQueue.IntervalTreeNode', source_node: 'MmapQueue.IntervalTreeNode') -> None:
            target_node.start = min(target_node.start, source_node.start)
            target_node.end = max(target_node.end, source_node.end)

            if source_node.parent_node is not None:
                if source_node.parent_node.left_node == source_node:
                    source_node.parent_node.left_node = None

                elif source_node.parent_node.right_node == source_node:
                    source_node.parent_node.right_node = None

                source_node.parent_node = None

            if source_node.left_node is not None:
                self._insert_node(target_node, source_node.left_node)

            if source_node.right_node is not None:
                self._insert_node(target_node, source_node.right_node)

            if target_node.right_node and target_node.right_node.min_start == target_node.end:
                new_source_node = target_node.right_node
                while True:
                    if new_source_node.start == target_node.end:
                        self._merge(target_node, new_source_node)
                        break
                    if new_source_node.left_node is not None:
                        new_source_node = new_source_node.left_node
                    else:
                        break

            if target_node.left_node and target_node.left_node.max_end == target_node.start:
                new_source_node = target_node.left_node
                while True:
                    if new_source_node.end == target_node.start:
                        self._merge(target_node, new_source_node)
                        break
                    if new_source_node.right_node is not None:
                        new_source_node = new_source_node.right_node
                    else:
                        break

        def _balance(self, node: 'MmapQueue.IntervalTreeNode') -> None:
            self.root.update_height()

            while True:
                if node.balance_factor > 1:
                    if node.left_node and node.left_node.balance_factor < 0:
                        node.left_node = self._rotate_left(node.left_node)
                    node = self._rotate_right(node)
                elif node.balance_factor < -1:
                    if node.right_node and node.right_node.balance_factor > 0:
                        node.right_node = self._rotate_right(node.right_node)
                    node = self._rotate_left(node)

                if node.parent_node is None:
                    self.root = node
                    self.root.update_height()
                    return
                node = node.parent_node

        def _rotate_left(self, node: 'MmapQueue.IntervalTreeNode') -> 'MmapQueue.IntervalTreeNode':
            if node.right_node is None:
                return node

            new_root = node.right_node
            node.right_node = new_root.left_node
            if new_root.left_node:
                new_root.left_node.parent_node = node
            new_root.parent_node = node.parent_node
            if node.parent_node is None:
                self.root = new_root
            elif node == node.parent_node.left_node:
                node.parent_node.left_node = new_root
            else:
                node.parent_node.right_node = new_root
            new_root.left_node = node
            node.parent_node = new_root

            return new_root

        def _rotate_right(self, node: 'MmapQueue.IntervalTreeNode') -> 'MmapQueue.IntervalTreeNode':
            if node.left_node is None:
                return node
            new_root = node.left_node
            node.left_node = new_root.right_node
            if new_root.right_node:
                new_root.right_node.parent_node = node
            new_root.parent_node = node.parent_node
            if node.parent_node is None:
                self.root = new_root
            elif node == node.parent_node.right_node:
                node.parent_node.right_node = new_root
            else:
                node.parent_node.left_node = new_root
            new_root.right_node = node
            node.parent_node = new_root

            return new_root

        def insert(self, start: int, end: int) -> None:
            new_node = MmapQueue.IntervalTreeNode(start, end)

            self._insert_node(self.root, new_node)
            if self.root is not None:
                self._balance(new_node.parent_node if new_node.parent_node else self.root)
                self.root.update_max_length()
                self.root.update_min_start()
                self.root.update_max_end()

        def search(self, length: int) -> 'MmapQueue.IntervalTreeNode | None':
            if self.root is None or self.root.max_length < length:
                return None

            current_node = self.root
            while True:
                if current_node.length >= length:
                    return current_node

                if current_node.left_node is not None and current_node.left_node.max_length >= length:
                    current_node = current_node.left_node
                elif current_node.right_node is not None and current_node.right_node.max_length >= length:
                    current_node = current_node.right_node
                else:
                    return None

        def delete(self, node: 'MmapQueue.IntervalTreeNode') -> None:

            if node.parent_node is not None:
                if node.parent_node.left_node == node:
                    node.parent_node.left_node = None
                elif node.parent_node.right_node == node:
                    node.parent_node.right_node = None
            else:
                self.root = None

            if node.left_node:
                if self.root is None:
                    self.root = node.left_node
                    self.root.parent_node = None
                else:
                    self._insert_node(self.root, node.left_node)

            if node.right_node:
                if self.root is None:
                    self.root = node.right_node
                    self.root.parent_node = None
                else:
                    self._insert_node(self.root, node.right_node)

            if self.root is not None:
                self._balance(node.parent_node if node.parent_node else self.root)
                self.root.update_max_length()
                self.root.update_min_start()
                self.root.update_max_end()

        def change_node_range(self, node: 'MmapQueue.IntervalTreeNode', new_start: int, new_end: int) -> None:
            if new_start >= node.start:
                node.start = new_start
            else:
                raise ValueError(f'new_start value must be greater than {node.start}')
            if new_end <= node.end:
                node.end = new_end
            else:
                raise ValueError(f'new_end value must be less than {node.end}')

            if self.root is not None:
                self.root.update_max_length()
                self.root.update_min_start()
                self.root.update_max_end()

    def __init__(self, initial_size: int = int(1e9)) -> None:
        if initial_size <= 0:
            raise ValueError('initial_size must be greater than 0')

        self._file_size = initial_size

        self._temp_file = NamedTemporaryFile(mode='r+b', delete=True)
        self._temp_file.write(b'\x00' * self._file_size)
        self._temp_file.flush()

        self._mmap = mmap.mmap(self._temp_file.fileno(), self._file_size)

        self._lock = Lock()

        self._tree = MmapQueue.IntervalTree()
        self._tree.insert(0, self._file_size)
        self._queue = Queue()

    def __del__(self) -> None:
        try:
            with self._lock:
                self._mmap.close()
        except Exception as er:
            print(f'Exception during cleanup: {er}', file=sys.stderr)

    def _resize(self, additional_size: int) -> None:
        new_size = self._file_size + additional_size

        self._temp_file.seek(self._file_size)
        self._temp_file.write(b'\x00' * additional_size)
        self._temp_file.flush()

        self._tree.insert(self._file_size, new_size)

        self._mmap.close()
        self._mmap = mmap.mmap(self._temp_file.fileno(), new_size)
        self._file_size = new_size

    def size(self) -> int:
        with self._lock:
            return self._queue.qsize()

    def clear(self) -> None:
        with self._lock:
            self._queue.queue.clear()
            self._tree = MmapQueue.IntervalTree()
            self._tree.insert(0, self._file_size)

    def empty(self) -> bool:
        with self._lock:
            return self._queue.empty()

    def put(self, data: Any) -> None:
        with self._lock:
            data_bytes = pickle.dumps(data)
            data_len_bytes = len(data_bytes)

            chunk_node = self._tree.search(data_len_bytes)
            if chunk_node is None:
                self._resize(data_len_bytes)
                chunk_node = self._tree.search(data_len_bytes)

            if chunk_node.length == data_len_bytes:
                self._mmap[chunk_node.start:chunk_node.end] = data_bytes
                self._queue.put_nowait((chunk_node.start, chunk_node.end))
                self._tree.delete(chunk_node)
            else:
                self._mmap[chunk_node.start: chunk_node.start + data_len_bytes] = data_bytes
                self._queue.put_nowait((chunk_node.start, chunk_node.start + data_len_bytes))
                self._tree.change_node_range(chunk_node, chunk_node.start + data_len_bytes, chunk_node.end)

    def get(self) -> Any:
        with self._lock:
            if self._queue.empty():
                return None
            start, end = self._queue.get_nowait()
            result = pickle.loads(self._mmap[start:end])  # noqa: S301
            self._tree.insert(start, end)
            return result
