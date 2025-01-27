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

from python_hackrf import pyhackrf


def pyhackrf_info(print_to_console: bool = True, initialize: bool = True) -> str | None:
    if initialize:
        pyhackrf.pyhackrf_init()

    print_info = ''
    device_list = pyhackrf.pyhackrf_device_list()
    print_info += f'python_hackrf version: {pyhackrf.python_hackrf_library_version()}\n'
    print_info += f'libhackrf version: {pyhackrf.pyhackrf_library_release()} ({pyhackrf.pyhackrf_library_version()})\n'

    if device_list.device_count > 0:
        for i in range(device_list.device_count):
            print_info += 'Found HackRF:\n'
            device = pyhackrf.pyhackrf_open_by_serial(device_list.serial_numbers[i])
            board_id, board_id_name = device.pyhackrf_board_id_read()
            board_rev, board_rev_name = device.pyhackrf_board_rev_read()
            read_partid_serialno = device.pyhackrf_board_partid_serialno_read()
            print_info += f'Index: {i}\n'
            print_info += f'Serial number: {device_list.serial_numbers[i]}\n'
            print_info += f'Board ID Number: {board_id} ({board_id_name})\n'
            print_info += f'Firmware Version: {device.pyhackrf_version_string_read()} ({device.pyhackrf_usb_api_version_read()})\n'
            print_info += f'Part ID Number: 0x{read_partid_serialno[0][0]:08x} 0x{read_partid_serialno[0][1]:08x}\n'
            if board_rev not in {0xFE, 0xFF}:
                print_info += f'Hardware Revision: {board_rev_name}\n'
                if board_rev > 0:
                    if (board_rev & 0x80):
                        print_info += 'Hardware appears to have been manufactured by Great Scott Gadgets.\n'
                    else:
                        print_info += 'Hardware does not appear to have been manufactured by Great Scott Gadgets.\n'
            else:
                print_info += f'{board_rev_name}\n'
            operacake_boards = device.pyhackrf_get_operacake_boards()
            for operacake_board_address in operacake_boards:
                mode = device.pyhackrf_get_operacake_mode(operacake_board_address)
                print_info += f'Opera Cake found, address: {operacake_board_address} | switching mode: {mode}'

            device.pyhackrf_close()
    else:
        print_info += 'No HackRF boards found.'

    if initialize:
        pyhackrf.pyhackrf_exit()

    if print_to_console:
        print(print_info)
        return None

    return print_info


def pyhackrf_serial_numbers_list_info(print_to_console: bool = True, initialize: bool = True) -> tuple[int, list] | None:
    if initialize:
        pyhackrf.pyhackrf_init()

    device_list = pyhackrf.pyhackrf_device_list()

    if initialize:
        pyhackrf.pyhackrf_exit()

    if print_to_console:
        print(f'Serial numbers [{device_list.device_count}]: {device_list.serial_numbers}')
        return None

    return device_list.device_count, device_list.serial_numbers
