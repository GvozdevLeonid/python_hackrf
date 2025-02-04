import argparse
import sys

from .pyhackrf_tools import (
    pyhackrf_info,
    pyhackrf_operacake,
    pyhackrf_sweep,
    pyhackrf_transfer,
)
from .pylibhackrf import pyhackrf


def main() -> None:
    parser = argparse.ArgumentParser(
        description='python_hackrf is a Python wrapper for libhackrf and hackrf-tools.',
        usage='python_hackrf [-h] {info, sweep, operacake, transfer} ...',
    )
    subparsers = parser.add_subparsers(dest='command', title='Available commands')
    subparsers.required = True
    pyhackrf_info_parser = subparsers.add_parser(
        'info', help='Read device information from HackRF such as serial number and firmware version.', usage='python_hackrf info [-h] [-f] [-s]',
    )
    pyhackrf_info_parser.add_argument('-f', '--full', action='store_true', help='show info like in hackrf_info')
    pyhackrf_info_parser.add_argument('-s', '--serial_numbers', action='store_true', help='show only founded serial_numbers')

    pyhackrf_operacake_parser = subparsers.add_parser(
        'operacake', help='Configure Opera Cake antenna switch connected to HackRF.', usage='python_hackrf operacake [-h] [-d] [-o] [-m] [-a] [-b] [-f] [-t] [-w] [-l] [-g]',
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
        'sweep', help='Command-line spectrum analyzer.', usage='python_hackrf sweep [-h] [-d] [-a] [-f] [-p] [-l] [-g] [-w] [-1] [-N] [-B] [-S] [-s] [-b] [-r]',
    )
    pyhackrf_sweep_parser.add_argument('-d', action='store', help='serial number of desired HackRF', metavar='')
    pyhackrf_sweep_parser.add_argument('-a', action='store_true', help='RX RF amplifier. If specified = Enable')
    pyhackrf_sweep_parser.add_argument('-f', action='store', help='freq_min:freq_max. minimum and maximum frequencies in MHz start:stop or start1:stop1,start2:stop2 (MAX_SWEEP_RANGES = 10)', metavar='', default='0:6000')
    pyhackrf_sweep_parser.add_argument('-p', action='store_true', help='antenna port power. If specified = Enable')
    pyhackrf_sweep_parser.add_argument('-l', action='store', help='RX LNA (IF) gain, 0 - 40dB, 8dB steps', metavar='', default=16)
    pyhackrf_sweep_parser.add_argument('-g', action='store', help='RX VGA (baseband) gain, 0 - 62dB, 2dB steps', metavar='', default=20)
    pyhackrf_sweep_parser.add_argument('-w', action='store', help='FFT bin width (frequency resolution) in Hz, 245-5000000 Depends on sample rate min = sample rate * 1e6 / 8180, max = sample_rate * 1e6 / 4', metavar='', default=1000000)
    pyhackrf_sweep_parser.add_argument('-1', action='store_true', help='one shot mode. If specified = Enable')
    pyhackrf_sweep_parser.add_argument('-N', action='store', help='number of sweeps to perform', metavar='')
    pyhackrf_sweep_parser.add_argument('-B', action='store_true', help='binary output. If specified = Enable')
    pyhackrf_sweep_parser.add_argument('-S', action='store', help='sweep style ("L" - LINEAR, "I" - INTERLEAVED). Default is INTERLEAVED', metavar='', default='I')
    pyhackrf_sweep_parser.add_argument('-s', action='store', help='sample rate in MHz (2, 4, 6, 8, 10, 12, 14, 16, 18, 20). Default is 20', metavar='', default=20)
    pyhackrf_sweep_parser.add_argument('-b', action='store', help='baseband filter bandwidth in MHz (1.75, 2.5, 3.5, 5.0, 5.5, 6.0, 7.0, 8.0, 9.0, 10.0, 12.0, 14.0, 15.0 20.0, 24.0, 28.0). Default .75 * sample rate', metavar='')
    pyhackrf_sweep_parser.add_argument('-r', action='store', help='<filename> output file', metavar='')

    pyhackrf_transfer_parser = subparsers.add_parser(
        'transfer', help='Send and receive signals using HackRF. Input/output files consist of complex64 quadrature samples.', usage='python_hackrf transfer [-h] [-d] [-r] [-t] [-f] [-i] [-o] [-m] [-a] [-p] [-l] [-g] [-x] [-s] [-N] [-R] -[b] [-H]',
    )
    pyhackrf_transfer_parser.add_argument('-d', action='store', help='serial number of desired HackRF', metavar='')
    pyhackrf_transfer_parser.add_argument('-r', action='store', help='<filename> receive data into file (use "-" for stdout)', metavar='')
    pyhackrf_transfer_parser.add_argument('-t', action='store', help='<filename> transmit data from file (use "-" for stdin)', metavar='')
    pyhackrf_transfer_parser.add_argument('-f', '--freq_hz', action='store', help='frequency in Hz (0MHz to 7250MHz supported). Default is 900MHz', metavar='', default=900_000_000)
    pyhackrf_transfer_parser.add_argument('-i', '--i_freq_hz', action='store', help='intermediate frequency in Hz (2000MHz to 3000MHz supported)', metavar='')
    pyhackrf_transfer_parser.add_argument('-o', '--lo_freq_hz', action='store', help='front-end local oscillator frequency in Hz (84MHz to 5400MHz supported)', metavar='')
    pyhackrf_transfer_parser.add_argument('-m', '--image_reject', action='store', help='image rejection filter selection (bypass, low, high)', metavar='', default='bypass')
    pyhackrf_transfer_parser.add_argument('-a', action='store_true', help='RX RF amplifier. If specified = Enable')
    pyhackrf_transfer_parser.add_argument('-p', action='store_true', help='antenna port power. If specified = Enable')
    pyhackrf_transfer_parser.add_argument('-l', action='store', help='RX LNA (IF) gain, 0 - 40dB, 8dB steps', metavar='', default=16)
    pyhackrf_transfer_parser.add_argument('-g', action='store', help='RX VGA (baseband) gain, 0 - 62dB, 2dB steps', metavar='', default=20)
    pyhackrf_transfer_parser.add_argument('-x', action='store', help='TX VGA (IF) gain, 0 - 47dB, 1dB steps', metavar='', default=0)
    pyhackrf_transfer_parser.add_argument('-s', action='store', help='sample rate in MHz (2, 4, 6, 8, 10, 12, 14, 16, 18, 20). Default is 10', metavar='', default=10)
    pyhackrf_transfer_parser.add_argument('-N', action='store', help='number of samples to transfer (default is unlimited)', metavar='')
    pyhackrf_transfer_parser.add_argument('-R', action='store_true', help='repeat TX mode. Fefault is off')
    pyhackrf_transfer_parser.add_argument('-b', action='store', help='baseband filter bandwidth in MHz (1.75, 2.5, 3.5, 5.0, 5.5, 6.0, 7.0, 8.0, 9.0, 10.0, 12.0, 14.0, 15.0 20.0, 24.0, 28.0). Default .75 * sample rate', metavar='')
    pyhackrf_transfer_parser.add_argument('-H', action='store_true', help='synchronize RX/TX to external trigger input')

    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(0)

    args, _ = parser.parse_known_args()

    if args.command == 'info':
        if args.serial_numbers:
            pyhackrf_info.pyhackrf_serial_numbers_list_info()
            return
        pyhackrf_info.pyhackrf_info()

    elif args.command == 'operacake':
        if sum([args.list, args.mode is not None, args.f is not None, args.t is not None, args.gpio_test, (args.a is not None or args.b is not None)]) == 1:
            if args.list:
                pyhackrf_operacake.pyhackrf_operacake_info(
                    serial_number=args.d,
                    print_to_console=True,
                )
                return

            if args.mode in {'manual', 'frequency', 'time'}:
                try:
                    address = int(args.address)
                except Exception:
                    address = 0

                pyhackrf_operacake.pyhackrf_set_operacake_mode(
                    address,
                    args.mode,
                    serial_number=args.d,
                )
                return

            if args.f is not None:
                str_freq_ranges = args.f.split(',')
                freq_ranges = []
                for freq_range in str_freq_ranges:
                    try:
                        port, freq_min, freq_max = freq_range.split(':')
                        freq_min, freq_max = int(freq_min), int(freq_max)
                        if port in pyhackrf.py_operacake_ports:
                            freq_ranges.extend([port, freq_min, freq_max])
                    except Exception:
                        pass

                pyhackrf_operacake.pyhackrf_set_operacake_freq_ranges(
                    freq_ranges,
                    serial_number=args.d,
                )
                return

            if args.t is not None:
                str_dwell_times = args.f.split(',')
                dwell_times = []
                for dwell_time in str_dwell_times:
                    try:
                        dwell_split = dwell_time.split(':')

                        if len(dwell_split) == 2:
                            port, dwell = dwell_split
                            dwell = int(dwell)
                        else:
                            port = dwell_split[0]
                            dwell = int(args.w)

                        if port in pyhackrf.py_operacake_ports:
                            dwell_times.extend([dwell, port])
                    except Exception:
                        pass

                pyhackrf_operacake.pyhackrf_set_operacake_dwell_times(
                    dwell_times,
                    serial_number=args.d,
                )
                return

            if (args.a is not None or args.b is not None):
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

                if args.a is None:
                    if port_b[0] == 'B':
                        port_a = 'A1'
                    else:
                        port_a = 'B1'

                if args.b is None:
                    if port_a[0] == 'B':
                        port_b = 'A1'
                    else:
                        port_b = 'B1'

                if port_a in pyhackrf.py_operacake_ports and port_b in pyhackrf.py_operacake_ports:
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

    elif args.command == 'sweep':
        str_frequencies = args.f.split(',')
        frequencies = []
        for frequency_range in str_frequencies:
            try:
                freq_min, freq_max = map(int, frequency_range.split(':'))
                frequencies.extend([freq_min, freq_max])
            except Exception:
                pass

        pyhackrf_sweep.pyhackrf_sweep(
            frequencies=frequencies,
            sample_rate=int(args.s) * 1e6,
            baseband_filter_bandwidth=float(args.b) * 1e6 if args.b is not None else None,
            lna_gain=int(args.l),
            vga_gain=int(args.g),
            bin_width=int(args.w),
            amp_enable=args.a,
            antenna_enable=args.p,
            sweep_style=pyhackrf.py_sweep_style.LINEAR if args.S == 'L' else (pyhackrf.py_sweep_style.INTERLEAVED if args.S == 'I' else -1),
            serial_number=args.d,
            binary_output=args.B,
            one_shot=args.__dict__.get('1'),
            num_sweeps=int(args.N) if args.N is not None else None,
            filename=args.r,
            print_to_console=True,
        )

    elif args.command == 'transfer':
        pyhackrf_transfer.pyhackrf_transfer(
            frequency=int(args.freq_hz),
            sample_rate=int(args.s) * 1e6,
            baseband_filter_bandwidth=float(args.b) * 1e6 if args.b is not None else None,
            i_frequency=int(args.i_freq_hz) if args.i_freq_hz is not None else None,
            lo_frequency=int(args.lo_freq_hz) if args.lo_freq_hz is not None else None,
            image_reject=pyhackrf.py_rf_path_filter.RF_PATH_FILTER_BYPASS if args.image_reject == 'bypass' else (pyhackrf.py_rf_path_filter.RF_PATH_FILTER_LOW_PASS if args.image_reject == 'low' else (pyhackrf.py_rf_path_filter.RF_PATH_FILTER_HIGH_PASS if args.image_reject == 'high' else -1)),
            rx_lna_gain=int(args.l),
            rx_vga_gain=int(args.g),
            tx_vga_gain=int(args.x),
            amp_enable=args.a,
            antenna_enable=args.p,
            repeat_tx=args.R,
            synchronize=args.H,
            num_samples=int(args.N) if args.N is not None else None,
            serial_number=args.d,
            rx_filename=args.r,
            tx_filename=args.t,
            print_to_console=True,
        )


if __name__ == '__main__':
    main()
