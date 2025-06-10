from python_hackrf import pyhackrf

def stop_all() -> None:
    ...

def stop_sdr(serialno: str) -> None:
    ...

def pyhackrf_sweep(frequencies: list[int] | None = None, sample_rate: int = 20_000_000, baseband_filter_bandwidth: int | None = None,
                   lna_gain: int = 16, vga_gain: int = 20, bin_width: int = 100_000, amp_enable: bool = False, antenna_enable: bool = False,
                   sweep_style: pyhackrf.py_sweep_style = pyhackrf.py_sweep_style.INTERLEAVED, serial_number: str | None = None,
                   binary_output: bool = False, one_shot: bool = False, num_sweeps: int | None = None,
                   filename: str | None = None, queue: object | None = None,
                   print_to_console: bool = True) -> None:
    ...
