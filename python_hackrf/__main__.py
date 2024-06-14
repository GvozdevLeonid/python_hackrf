from .pyhackrf_tools import (
    pyhackrf_operacake,
    pyhackrf_sweep,
    pyhackrf_info,
)
from .pylibhackrf import pyhackrf
import argparse
import sys


def main():
    parser = argparse.ArgumentParser(
        description="python_hackrf is a Python wrapper for libhackrf and hackrf-tools.",
        usage="python_hackrf [-h] {info, sweep, operacake} ..."
    )
    subparsers = parser.add_subparsers(dest="command", title="Available commands")
    subparsers.required = True
    pyhackrf_info_parser = subparsers.add_parser(
        'info', help='Read device information from HackRF such as serial number and firmware version.', usage="python_hackrf info [-h] [-f] [-s]"
    )
    pyhackrf_info_parser.add_argument('-f', '--full', action='store_true', help='show info like in hackrf_info')
    pyhackrf_info_parser.add_argument('-s', '--serial_numbers', action='store_true', help='show only founded serial_numbers')

    pyhackrf_operacake_parser = subparsers.add_parser(
        'operacake', help='Specify either list, mode, or GPIO test option.', usage="python_hackrf operacake [-h] [-d] [-o] [-m] [-a] [-b] [-f] [-t] [-w] [-l] [-g]"
    )
    pyhackrf_operacake_parser.add_argument('-d', action='store', help='serial_number. serial number of desired HackRF', metavar='')
    pyhackrf_operacake_parser.add_argument('-o', '--address', action='store', help='specify a particular Opera Cake by address. Default is 0', metavar='', default=0)
    pyhackrf_operacake_parser.add_argument('-m', '--mode', action='store', help='specify switching mode [options: manual, frequency, time]', metavar='')
    pyhackrf_operacake_parser.add_argument('-a', action='store', help='set port connected to port A0', metavar='')
    pyhackrf_operacake_parser.add_argument('-b', action='store', help='set port connected to port B0', metavar='')
    pyhackrf_operacake_parser.add_argument('-f', action='store', help='<port:min:max> or <port:min:max>,<port:min:max> automatically assign <port> for range <min:max> in MHz.', metavar='')
    pyhackrf_operacake_parser.add_argument('-t', action='store', help='<port:dwell> or <port:dwell>,<port:dwell> in time mode, dwell on <port> for <dwell> samples. Specify only <port> to use the default dwell time (with -w).', metavar='')
    pyhackrf_operacake_parser.add_argument('-w', action='store', help='set default dwell time in samples for time mode', metavar='', default=0)
    pyhackrf_operacake_parser.add_argument('-l', '--list', action='store_true', help='list available Opera Cake boards')
    pyhackrf_operacake_parser.add_argument('-g', '--gpio_test', action='store_true', help='test GPIO functionality of an Opera Cake')

    pyhackrf_sweep_parser = subparsers.add_parser(
        'sweep', help='a command-line spectrum analyzer.', usage='python_hackrf sweep [-h] [-d] [-a] [-f] [-p] [-l] [-g] [-w] [-1] [-N] [-B] [-s] [-SR] [-BF] [-r]'
    )
    pyhackrf_sweep_parser.add_argument('-d', action='store', help='serial_number. serial number of desired HackRF', metavar='')
    pyhackrf_sweep_parser.add_argument('-a', action='store_true', help='amp_enable. RX RF amplifier. If specified = Enable')
    pyhackrf_sweep_parser.add_argument('-f', action='store', help='freq_min:freq_max. minimum and maximum frequencies in MHz start:stop or start1:stop1,start2:stop2 (MAX_SWEEP_RANGES = 10)', metavar='', default='0:6000')
    pyhackrf_sweep_parser.add_argument('-p', action='store_true', help='antenna_enable. Antenna port power. If specified = Enable')
    pyhackrf_sweep_parser.add_argument('-l', action='store', help='gain_db. RX LNA (IF) gain, 0 - 40dB, 8dB steps', metavar='', default=16)
    pyhackrf_sweep_parser.add_argument('-g', action='store', help='gain_db. RX VGA (baseband) gain, 0 - 62dB, 2dB steps', metavar='', default=20)
    pyhackrf_sweep_parser.add_argument('-w', action='store', help='bin_width. FFT bin width (frequency resolution) in Hz, 245-5000000 Depends on sample rate min= sample rate * 1e6 / 8180, max = sample_rate * 1e6 / 4', metavar='', default=1000000)
    pyhackrf_sweep_parser.add_argument('-1', action='store_true', help='one shot mode. If specified = Enable')
    pyhackrf_sweep_parser.add_argument('-N', action='store', help='num_sweeps. Number of sweeps to perform', metavar='')
    pyhackrf_sweep_parser.add_argument('-B', action='store_true', help='binary output. If specified = Enable')
    pyhackrf_sweep_parser.add_argument('-s', action='store', help='sweep style ("L" - LINEAR, "I" - INTERLEAVED). Default is INTERLEAVED', metavar='', default='I')
    pyhackrf_sweep_parser.add_argument('-SR', action='store', help='sample rate in Hz (2, 4, 6, 8, 10, 12, 14, 16, 18, 20). Default is 20000000', metavar='', default=20)
    pyhackrf_sweep_parser.add_argument('-BF', action='store', help='baseband filter bandwidth in Hz (1.75, 2.5, 3.5, 5.0, 5.5, 6.0, 7.0, 8.0, 9.0, 10.0, 12.0, 14.0, 15.0 20.0, 24.0, 28.0). Default is 15000000', metavar='', default=15.0)
    pyhackrf_sweep_parser.add_argument('-r', action='store', help='filename. output file', metavar='')

    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(0)

    args, unparsed_args = parser.parse_known_args()
    if args.command == 'info':
        if args.serial_numbers:
            pyhackrf_info.pyhackrf_serial_numbers_list_info()
        else:
            pyhackrf_info.pyhackrf_info()

    elif args.command == 'operacake':
        if sum([args.list, args.mode is not None, args.f is not None, args.t is not None, args.gpio_test, (args.a is not None or args.b is not None)]) == 1:
            if args.list:
                pyhackrf_operacake.pyhackrf_operacake_info(
                    serial_number=args.d,
                    print_to_console=True,
                )
                return

            elif args.mode in ('manual', 'frequency', 'time'):
                address = 0
                if args.address is not None:
                    try:
                        address = int(args.address)
                    except Exception:
                        pass
                pyhackrf_operacake.pyhackrf_set_operacake_mode(
                    address,
                    args.mode,
                    serial_number=args.d
                )
                return

            elif args.f is not None:
                str_freq_ranges = args.f.split(',')
                freq_ranges = []
                for freq_range in str_freq_ranges:
                    freq_range = freq_range.split(':')
                    port, freq_min, freq_max = None, None, None
                    try:
                        port = freq_range[0]
                    except Exception:
                        pass
                    try:
                        freq_min = int(freq_range[1])
                    except Exception:
                        pass
                    try:
                        freq_max = int(freq_range[2])
                    except Exception:
                        pass

                    if freq_min is not None and freq_max is not None and port in ('A1', 'A2', 'A3', 'A4', 'B1', 'B2', 'B3', 'B4'):
                        freq_ranges.extend([port, freq_min, freq_max])

                pyhackrf_operacake.pyhackrf_set_operacake_freq_ranges(
                    freq_ranges,
                    serial_number=args.d
                )
                return

            elif args.t is not None:
                str_dwell_times = args.f.split(',')
                dwell_times = []
                for dwell_time in str_dwell_times:
                    dwell_time = dwell_time.split(':')
                    dwell, port = None
                    if len(dwell_time) == 2:
                        try:
                            port = dwell_time[0]
                        except Exception:
                            pass
                        try:
                            dwell = int(dwell_time[1])
                        except Exception:
                            pass
                    else:
                        port = dwell_time[0]
                        try:
                            dwell = int(args.w)
                        except Exception:
                            pass

                    if dwell is not None and port in ('A1', 'A2', 'A3', 'A4', 'B1', 'B2', 'B3', 'B4'):
                        dwell_times.extend([dwell, port])

                pyhackrf_operacake.pyhackrf_set_operacake_dwell_times(
                    dwell_times,
                    serial_number=args.d
                )
                return

            elif (args.a is not None or args.b is not None):
                address, port_a, port_b = 0, 'A1', 'B1'
                if args.a is not None:
                    port_a = args.a
                if args.b is not None:
                    port_b = args.b
                if args.address is not None:
                    try:
                        address = int(args.address)
                    except Exception:
                        pass

                if port_a is None:
                    if port_b[0] == 'B':
                        port_a = 'A1'
                    else:
                        port_a = 'B1'

                if port_b is None:
                    if port_a[0] == 'B':
                        port_b = 'A1'
                    else:
                        port_b = 'B1'

                if port_a in ('A1', 'A2', 'A3', 'A4', 'B1', 'B2', 'B3', 'B4') and port_b in ('A1', 'A2', 'A3', 'A4', 'B1', 'B2', 'B3', 'B4'):
                    if port_a[0] != port_b[0]:
                        pyhackrf_operacake.pyhackrf_set_operacake_ports(
                            address,
                            port_a,
                            port_b,
                            serial_number=args.d,
                        )
                    else:
                        print('Port A and B cannot be connected to the same side')

                    return

            elif args.gpio_test is not None:
                address = 0
                if args.address is not None:
                    try:
                        address = int(args.address)
                    except Exception:
                        pass
                pyhackrf_operacake.pyhackrf_operacake_gpio_test(
                    address,
                    serial_number=args.d,
                )
                return

        print('Argument error')
        print(pyhackrf_sweep_parser.usage)

    elif args.command == 'sweep':
        str_frequencies = args.f.split(',')
        frequencies = []
        for frequency_range in str_frequencies:
            frequency_range = frequency_range.split(':')
            freq_min, freq_max = None, None
            try:
                freq_min = int(frequency_range[0])
            except Exception:
                pass
            try:
                freq_max = int(frequency_range[1])
            except Exception:
                pass
            if freq_min is not None and freq_max is not None:
                frequencies.extend([freq_min, freq_max])

        pyhackrf_sweep.pyhackrf_sweep(frequencies=frequencies,
                                      lna_gain=int(args.l),
                                      vga_gain=int(args.g),
                                      bin_width=int(args.w),
                                      serial_number=args.d,
                                      amp_enable=args.a,
                                      antenna_enable=args.p,
                                      num_sweeps=int(args.N) if args.N is not None else None,
                                      binary_output=args.B,
                                      one_shot=args.__dict__.get('1'),
                                      filename=args.r,
                                      sweep_style=pyhackrf.py_sweep_style.LINEAR if args.s == 'L' else (pyhackrf.py_sweep_style.INTERLEAVED if args.s == 'I' else -1),
                                      sample_rate=int(args.SR) * 1e6,
                                      baseband_filter=float(args.BF) * 1e6,
                                      print_to_console=True,
                                      )


if __name__ == '__main__':
    main()
