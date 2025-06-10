from python_hackrf import pyhackrf

def stop_all() -> None:
    ...

def stop_sdr(serialno: str) -> None:
    ...

def pyhackrf_transfer(frequency: int | None = None, sample_rate: int = 10_000_000, baseband_filter_bandwidth: int | None = None, i_frequency: int | None = None, lo_frequency: int | None = None, image_reject: pyhackrf.py_rf_path_filter = pyhackrf.py_rf_path_filter.RF_PATH_FILTER_BYPASS,
                      rx_lna_gain: int = 16, rx_vga_gain: int = 20, tx_vga_gain: int = 0, amp_enable: bool = False, antenna_enable: bool = False,
                      repeat_tx: bool = False, synchronize: bool = False, num_samples: int | None = None, serial_number: str | None = None,
                      rx_filename: str | None = None, tx_filename: str | None = None, rx_buffer: object | None = None, tx_buffer: object | None = None,
                      print_to_console: bool = True) -> None:
    ...
