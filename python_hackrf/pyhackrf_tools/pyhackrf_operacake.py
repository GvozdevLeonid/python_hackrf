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


def pyhackrf_operacake_info(device: pyhackrf.PyHackrfDevice = None,
                            serial_number: str | None = None,
                            print_to_console: bool = True,
                            ) -> str | None:

    initialize = True if device is None else False

    if initialize:
        pyhackrf.pyhackrf_init()

        if serial_number is not None:
            device = pyhackrf.pyhackrf_open_by_serial(serial_number)
        else:
            device = pyhackrf.pyhackrf_open()

    operacake_info = ''
    boards = device.pyhackrf_get_operacake_boards()
    if len(boards):
        operacake_info += 'Opera Cakes found:\n'
        for i in range(len(boards)):
            address = boards[i]
            mode = device.pyhackrf_get_operacake_mode(address)
            operacake_info += f'Address: {address} Switching mode: {mode}\n'
    else:
        operacake_info = 'Opera Cakes found: None'

    if initialize:
        device.pyhackrf_close()
        pyhackrf.pyhackrf_exit()

    if print_to_console:
        print(operacake_info)
        return None

    return operacake_info


def pyhackrf_set_operacake_mode(address: int,
                                mode: str,
                                serial_number: str | None = None,
                                device: pyhackrf.PyHackrfDevice = None,
                                ) -> None:

    initialize = True if device is None else False

    if initialize:
        pyhackrf.pyhackrf_init()

        if serial_number is not None:
            device = pyhackrf.pyhackrf_open_by_serial(serial_number)
        else:
            device = pyhackrf.pyhackrf_open()

    if mode == 'frequency':
        mode = pyhackrf.py_operacake_switching_mode.OPERACAKE_MODE_FREQUENCY
    elif mode == 'time':
        mode = pyhackrf.py_operacake_switching_mode.OPERACAKE_MODE_TIME
    else:
        mode = pyhackrf.py_operacake_switching_mode.OPERACAKE_MODE_MANUAL

    device.pyhackrf_set_operacake_mode(address, mode)

    if initialize:
        device.pyhackrf_close()
        pyhackrf.pyhackrf_exit()


def pyhackrf_set_operacake_freq_ranges(freq_ranges: list,
                                       serial_number: str | None = None,
                                       device: pyhackrf.PyHackrfDevice = None,
                                       ) -> None:

    initialize = True if device is None else False

    if initialize:
        pyhackrf.pyhackrf_init()

        if serial_number is not None:
            device = pyhackrf.pyhackrf_open_by_serial(serial_number)
        else:
            device = pyhackrf.pyhackrf_open()

    device.pyhackrf_set_operacake_freq_ranges(freq_ranges)

    if initialize:
        device.pyhackrf_close()
        pyhackrf.pyhackrf_exit()


def pyhackrf_set_operacake_dwell_times(dwell_times: list,
                                       serial_number: str | None = None,
                                       device: pyhackrf.PyHackrfDevice = None,
                                       ) -> None:

    initialize = True if device is None else False

    if initialize:
        pyhackrf.pyhackrf_init()

        if serial_number is not None:
            device = pyhackrf.pyhackrf_open_by_serial(serial_number)
        else:
            device = pyhackrf.pyhackrf_open()

    device.pyhackrf_set_operacake_dwell_times(dwell_times)

    if initialize:
        device.pyhackrf_close()
        pyhackrf.pyhackrf_exit()


def pyhackrf_set_operacake_ports(address: int,
                                 port_a: str,
                                 port_b: str,
                                 serial_number: str | None = None,
                                 device: pyhackrf.PyHackrfDevice = None,
                                 ) -> None:

    initialize = True if device is None else False

    if initialize:
        pyhackrf.pyhackrf_init()

        if serial_number is not None:
            device = pyhackrf.pyhackrf_open_by_serial(serial_number)
        else:
            device = pyhackrf.pyhackrf_open()

    device.pyhackrf_set_operacake_ports(address, port_a, port_b)

    if initialize:
        device.pyhackrf_close()
        pyhackrf.pyhackrf_exit()


def pyhackrf_operacake_gpio_test(address: int,
                                 serial_number: str | None = None,
                                 device: pyhackrf.PyHackrfDevice = None,
                                 ) -> None:

    initialize = True if device is None else False

    if initialize:
        pyhackrf.pyhackrf_init()

        if serial_number is not None:
            device = pyhackrf.pyhackrf_open_by_serial(serial_number)
        else:
            device = pyhackrf.pyhackrf_open()

    test_result = device.pyhackrf_operacake_gpio_test(address)
    if test_result == 0xFFFF:
        print('GPIO mode disabled.')
        print('Remove additional add-on boards and retry.')

    elif test_result:
        reg, mask = 0x7, 0x7

        print("u2ctrl1\t%d\t%d\t%d\n", (reg >> 2) & 1, (reg >> 1) & 1, reg & 1)
        test_result >>= 3
        reg = test_result & mask
        print("u2ctrl0\t%d\t%d\t%d", (reg >> 2) & 1, (reg >> 1) & 1, reg & 1)
        test_result >>= 3
        reg = test_result & mask
        print("u3ctrl1\t%d\t%d\t%d", (reg >> 2) & 1, (reg >> 1) & 1, reg & 1)
        test_result >>= 3
        reg = test_result & mask
        print("u3ctrl0\t%d\t%d\t%d", (reg >> 2) & 1, (reg >> 1) & 1, reg & 1)
        test_result >>= 3
        reg = test_result & mask
        print("u1ctrl \t%d\t%d\t%d\n", (reg >> 2) & 1, (reg >> 1) & 1, reg & 1)
    else:
        print('GPIO test passed')

    if initialize:
        device.pyhackrf_close()
        pyhackrf.pyhackrf_exit()
