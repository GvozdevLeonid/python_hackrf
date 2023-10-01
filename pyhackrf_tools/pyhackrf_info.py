from python_hackrf import pyhackrf

def pyhackrf_info(print_to_console: bool = True, initialize: bool = True) -> None | str:
    if initialize:
        pyhackrf.pyhackrf_init()
    print_info = ''
    device_list = pyhackrf.pyhackrf_device_list()
    print_info += f'pyhackrf_info version: {pyhackrf.pyhackrf_library_release()}\n'
    print_info += f'pylibhackrf version: {pyhackrf.pyhackrf_library_release()} ({pyhackrf.pyhackrf_library_version()})\n'
    print_info += 'Found HackRF\n'

    for i in range(device_list.devicecount):
        device = pyhackrf.pyhackrf_open_by_serial(device_list.serial_numbers[i])
        board_id, board_name = device.pyhackrf_board_id_read()
        read_partid_serialno = device.pyhackrf_board_partid_serialno_read()
        print_info += f'Index: {i}\n'
        print_info += f'Serial number: {device_list.serial_numbers[i]}\n'
        print_info += f'Board ID Number: {board_id} ({board_name})\n'
        print_info += f'Firmware Version: {device.pyhackrf_version_string_read()} ({device.pyhackrf_usb_api_version_read()})\n'
        print_info += f'Part ID Number: 0x{read_partid_serialno["part_id"][0]:08x} 0x{read_partid_serialno["part_id"][1]:08x}\n'

    if print_to_console:
        print(print_info)
    else:
        return print_info


    if initialize:
        pyhackrf.pyhackrf_exit()

def pyhackrf_serial_numbers_list_info(print_to_console: bool = True, initialize: bool = True) -> None | tuple[int, list]:
    if initialize:
        pyhackrf.pyhackrf_init()

    device_list = pyhackrf.pyhackrf_device_list()

    if print_to_console:
        print(f'Serial numbers [{device_list.devicecount}]: {device_list.serial_numbers}')
    else:
        return device_list.devicecount, device_list.serial_numbers
    if initialize:
        pyhackrf.pyhackrf_exit()
