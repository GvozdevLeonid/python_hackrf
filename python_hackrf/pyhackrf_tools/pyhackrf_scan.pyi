from python_hackrf import pyhackrf

def stop_all() -> None:
    ...

def stop_sdr(serialno: str) -> None:
    ...

def pyhackrf_sweep(frequencies: list[int], samples_per_scan: int, queue: object, sample_rate: int = 20_000_000, baseband_filter_bandwidth: int | None = None,
                   lna_gain: int = 16, vga_gain: int = 20, amp_enable: bool = False, antenna_enable: bool = False, serial_number: str | None = None,
                   print_to_console: bool = True) -> None:
    ...
