from .pyhackrf_tools import pyhackrf_info, pyhackrf_sweep
from .libhackrf import pyhackrf
import argparse

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description="python_hackrf is a Python wrapper for libhackrf and hackrf-tools.",
        usage="python -m python_hackrf [-h] {info, sweep} ..."
    )
    subparsers = parser.add_subparsers(dest="command", title="Available commands")
    subparsers.required = True
    pyhackrf_info_parser = subparsers.add_parser(
        'info', help='Read device information from HackRF such as serial number and firmware version.', usage="python -m python_hackrf info [-h] [-f] [-s]"
    )
    pyhackrf_info_parser.add_argument('-f', '--full', action='store_true', help='show info like in hackrf_info')
    pyhackrf_info_parser.add_argument('-s', '--serial_numbers', action='store_true', help='show only founded serial_numbers')

    pyhackrf_sweep_parser = subparsers.add_parser(
        'sweep', help='a command-line spectrum analyzer.', usage='python -m python_hackrf sweep [-h] [-d] [-a] [-f] [-p] [-l] [-g] [-w] [-1] [-N] [-B] [-s] [-SR] [-r]'
    )
    pyhackrf_sweep_parser.add_argument('-d', action='store', help='serial_number. serial number of desired HackRF', metavar='')
    pyhackrf_sweep_parser.add_argument('-a', action='store_true', help='amp_enable. RX RF amplifier. If specified = Enable')
    pyhackrf_sweep_parser.add_argument('-f', action='store', help='freq_min:freq_max. minimum and maximum frequencies in MHz srart:stop or start1:stop1,start2:stop2 (MAX_SWEEP_RANGES = 10)', metavar='', default='0:6000')
    pyhackrf_sweep_parser.add_argument('-p', action='store_true', help='antenna_enable. Antenna port power. If specified = Enable')
    pyhackrf_sweep_parser.add_argument('-l', action='store', help='gain_db. RX LNA (IF) gain, 0-40dB, 8dB steps', metavar='', default=16)
    pyhackrf_sweep_parser.add_argument('-g', action='store', help='gain_db. RX VGA (baseband) gain, 0-62dB, 2dB steps', metavar='', default=20)
    pyhackrf_sweep_parser.add_argument('-w', action='store', help='bin_width. FFT bin width (frequency resolution) in Hz, 245-5000000 Depends on sample rate min= sample rate * 1e6 / 8180, max = sample_rate * 1e6 / 4', metavar='', default=1000000)
    pyhackrf_sweep_parser.add_argument('-1', action='store_true', help='one shot mode. If specified = Enable')
    pyhackrf_sweep_parser.add_argument('-N', action='store', help='num_sweeps. Number of sweeps to perform', metavar='')
    pyhackrf_sweep_parser.add_argument('-B', action='store_true', help='binary output. If specified = Enable')
    pyhackrf_sweep_parser.add_argument('-s', action='store', help='sweep style ("L" - LINEAR, "I" - INTERLEAVED). Default is INTERLEAVED', metavar='', default='I')
    pyhackrf_sweep_parser.add_argument('-SR', action='store', help='sample rate (2, 4, 6, 8, 10, 12, 14, 16, 18, 20). Default is 20', metavar='', default=20)
    pyhackrf_sweep_parser.add_argument('-r', action='store', help='filename. output file', metavar='')
    args, unparsed_args = parser.parse_known_args()

    if args.command == 'info':
        if args.serial_numbers:
            pyhackrf_info.pyhackrf_serial_numbers_list_info()
        else:
            pyhackrf_info.pyhackrf_info()

    if args.command == 'sweep':
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
                                      sweep_style=pyhackrf.py_sweep_style.LINEAR if args.s == 'L' else pyhackrf.py_sweep_style.INTERLEAVED,
                                      sample_rate=int(args.SR) * 1e6,
                                      print_to_console=True,
                                      )
