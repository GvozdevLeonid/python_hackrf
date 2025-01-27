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

from libc.stdint cimport *

cdef extern from 'hackrf.h':
    int SAMPLES_PER_BLOCK
    int BYTES_PER_BLOCK
    int MAX_SWEEP_RANGES
    int HACKRF_OPERACAKE_ADDRESS_INVALID
    int HACKRF_OPERACAKE_MAX_BOARDS
    int HACKRF_OPERACAKE_MAX_DWELL_TIMES
    int HACKRF_OPERACAKE_MAX_FREQ_RANGES

    enum hackrf_error:
        HACKRF_SUCCESS
        HACKRF_TRUE
        HACKRF_ERROR_INVALID_PARAM
        HACKRF_ERROR_NOT_FOUND
        HACKRF_ERROR_BUSY
        HACKRF_ERROR_NO_MEM
        HACKRF_ERROR_LIBUSB
        HACKRF_ERROR_THREAD
        HACKRF_ERROR_STREAMING_THREAD_ERR
        HACKRF_ERROR_STREAMING_STOPPED
        HACKRF_ERROR_STREAMING_EXIT_CALLED
        HACKRF_ERROR_USB_API_VERSION
        HACKRF_ERROR_NOT_LAST_DEVICE
        HACKRF_ERROR_OTHER

    int HACKRF_BOARD_REV_GSG
    int HACKRF_PLATFORM_JAWBREAKER
    int HACKRF_PLATFORM_HACKRF1_OG
    int HACKRF_PLATFORM_RAD1O
    int HACKRF_PLATFORM_HACKRF1_R9

    enum hackrf_board_id:
        BOARD_ID_JELLYBEAN
        BOARD_ID_JAWBREAKER
        BOARD_ID_HACKRF1_OG
        BOARD_ID_RAD1O
        BOARD_ID_HACKRF1_R9
        BOARD_ID_UNRECOGNIZED
        BOARD_ID_UNDETECTED

    int BOARD_ID_HACKRF_ONE
    int BOARD_ID_INVALID

    enum hackrf_board_rev:
        BOARD_REV_HACKRF1_OLD
        BOARD_REV_HACKRF1_R6
        BOARD_REV_HACKRF1_R7
        BOARD_REV_HACKRF1_R8
        BOARD_REV_HACKRF1_R9

        BOARD_REV_GSG_HACKRF1_R6
        BOARD_REV_GSG_HACKRF1_R7
        BOARD_REV_GSG_HACKRF1_R8
        BOARD_REV_GSG_HACKRF1_R9
        BOARD_REV_UNRECOGNIZED
        BOARD_REV_UNDETECTED

    enum hackrf_usb_board_id:
        USB_BOARD_ID_JAWBREAKER
        USB_BOARD_ID_HACKRF_ONE
        USB_BOARD_ID_RAD1O
        USB_BOARD_ID_INVALID

    enum rf_path_filter:
        RF_PATH_FILTER_BYPASS
        RF_PATH_FILTER_LOW_PASS
        RF_PATH_FILTER_HIGH_PASS

    enum operacake_ports:
        OPERACAKE_PA1
        OPERACAKE_PA2
        OPERACAKE_PA3
        OPERACAKE_PA4
        OPERACAKE_PB1
        OPERACAKE_PB2
        OPERACAKE_PB3
        OPERACAKE_PB4

    enum operacake_switching_mode:
        OPERACAKE_MODE_MANUAL
        OPERACAKE_MODE_FREQUENCY
        OPERACAKE_MODE_TIME

    enum sweep_style:
        LINEAR
        INTERLEAVED

    ctypedef struct hackrf_device:
        pass

    ctypedef struct hackrf_transfer:
        hackrf_device *device
        uint8_t *buffer
        int buffer_length
        int valid_length
        void *rx_ctx
        void *tx_ctx

    ctypedef struct read_partid_serialno_t:
        uint32_t part_id[2]
        uint32_t serial_no[4]

    ctypedef struct hackrf_operacake_dwell_time:
        uint32_t dwell
        uint8_t port

    ctypedef struct hackrf_operacake_freq_range:
        uint16_t freq_min
        uint16_t freq_max
        uint8_t port

    ctypedef struct hackrf_bool_user_settting:
        int do_update
        int change_on_mode_entry
        int enabled

    ctypedef struct hackrf_bias_t_user_settting_req:
        hackrf_bool_user_settting tx
        hackrf_bool_user_settting rx
        hackrf_bool_user_settting off

    ctypedef struct hackrf_m0_state:
        uint16_t requested_mode
        uint16_t request_flag
        uint32_t active_mode
        uint32_t m0_count
        uint32_t m4_count
        uint32_t num_shortfalls
        uint32_t longest_shortfall
        uint32_t shortfall_limit
        uint32_t threshold
        uint32_t next_mode
        uint32_t error

    ctypedef struct hackrf_device_list_t:
        char **serial_numbers
        hackrf_usb_board_id *usb_board_ids
        int *usb_device_index
        int devicecount
        void **usb_devices
        int usb_devicecount

    ctypedef int(*hackrf_sample_block_cb_fn)(hackrf_transfer *transfer)

    ctypedef void(*hackrf_tx_block_complete_cb_fn)(hackrf_transfer *transfer, int)

    ctypedef void(*hackrf_flush_cb_fn)(void *flush_ctx, int)

    int hackrf_init()

    int hackrf_exit()

    const char *hackrf_library_version()

    const char *hackrf_library_release()

    hackrf_device_list_t *hackrf_device_list()

    void hackrf_device_list_free(hackrf_device_list_t *list)

    int hackrf_device_list_open(hackrf_device_list_t *list, int idx, hackrf_device **device)

    int hackrf_open(hackrf_device **device)

    int hackrf_open_by_serial(char *desired_serial_number, hackrf_device **device)

    int hackrf_close(hackrf_device *device)

    int hackrf_start_rx(hackrf_device *device, hackrf_sample_block_cb_fn callback, void *rx_ctx)

    int hackrf_stop_rx(hackrf_device *device)

    int hackrf_start_tx(hackrf_device *device, hackrf_sample_block_cb_fn callback, void *tx_ctx)

    int hackrf_set_tx_block_complete_callback(hackrf_device *device, hackrf_tx_block_complete_cb_fn callback)

    int hackrf_enable_tx_flush(hackrf_device *device, hackrf_flush_cb_fn callback, void *flush_ctx)

    int hackrf_stop_tx(hackrf_device *device)

    int hackrf_get_m0_state(hackrf_device *device, hackrf_m0_state *value)

    int hackrf_set_tx_underrun_limit(hackrf_device *device, uint32_t value)

    int hackrf_set_rx_overrun_limit(hackrf_device *device, uint32_t value)

    int hackrf_is_streaming(hackrf_device *device)

    int hackrf_max2837_read(hackrf_device *device, uint8_t register_number, uint16_t *value)

    int hackrf_max2837_write(hackrf_device *device, uint8_t register_number, uint16_t value)

    int hackrf_si5351c_read(hackrf_device *device, uint16_t register_number, uint16_t *value)

    int hackrf_si5351c_write(hackrf_device *device, uint16_t register_number, uint16_t value)

    int hackrf_set_baseband_filter_bandwidth(hackrf_device *device, const uint32_t bandwidth_hz)

    int hackrf_rffc5071_read(hackrf_device *device, uint8_t register_number, uint16_t *value)

    int hackrf_rffc5071_write(hackrf_device *device, uint8_t register_number, uint16_t value)

    int hackrf_spiflash_erase(hackrf_device *device)

    int hackrf_spiflash_write(hackrf_device *device, const uint32_t address, const uint16_t length, unsigned char *data)

    int hackrf_spiflash_read(hackrf_device *device, const uint32_t address, const uint16_t length, unsigned char *data)

    int hackrf_spiflash_status(hackrf_device *device, uint8_t *data)

    int hackrf_spiflash_clear_status(hackrf_device *device)

    int hackrf_cpld_write(hackrf_device *device, unsigned char *data, const unsigned int total_length)

    int hackrf_board_id_read(hackrf_device *device, uint8_t *value)

    int hackrf_version_string_read(hackrf_device *device, char *version, uint8_t length)

    int hackrf_usb_api_version_read(hackrf_device *device, uint16_t *version)

    int hackrf_set_freq(hackrf_device *device, const uint64_t freq_hz)

    int hackrf_set_freq_explicit(hackrf_device *device, const uint64_t if_freq_hz, const uint64_t lo_freq_hz, const rf_path_filter path)

    int hackrf_set_sample_rate_manual(hackrf_device *device, const uint32_t freq_hz, const uint32_t divider)

    int hackrf_set_sample_rate(hackrf_device *device, const double freq_hz)

    int hackrf_set_amp_enable(hackrf_device *device, const uint8_t value)

    int hackrf_board_partid_serialno_read(hackrf_device *device, read_partid_serialno_t *read_partid_serialno)

    int hackrf_set_lna_gain(hackrf_device *device, uint32_t value)

    int hackrf_set_vga_gain(hackrf_device *device, uint32_t value)

    int hackrf_set_txvga_gain(hackrf_device *device, uint32_t value)

    int hackrf_set_antenna_enable(hackrf_device *device, const uint8_t value)

    const char *hackrf_error_name(int errcode)

    const char *hackrf_board_id_name(int board_id)

    uint32_t hackrf_board_id_platform(hackrf_board_id board_id)

    const char *hackrf_usb_board_id_name(hackrf_usb_board_id usb_board_id)

    const char *hackrf_filter_path_name(const rf_path_filter path)

    uint32_t hackrf_compute_baseband_filter_bw_round_down_lt(const uint32_t bandwidth_hz)

    uint32_t hackrf_compute_baseband_filter_bw(const uint32_t bandwidth_hz)

    int hackrf_set_hw_sync_mode(hackrf_device *device, const uint8_t value)

    int hackrf_init_sweep(hackrf_device *device, const uint16_t *frequency_list, const int num_ranges, const uint32_t num_bytes, const uint32_t step_width, const uint32_t offset, const sweep_style style)

    int hackrf_get_operacake_boards(hackrf_device *device, uint8_t *boards)

    int hackrf_set_operacake_mode(hackrf_device *device, uint8_t address, operacake_switching_mode mode)

    int hackrf_get_operacake_mode(hackrf_device *device, uint8_t address, operacake_switching_mode *mode)

    int hackrf_set_operacake_ports(hackrf_device *device, uint8_t address, uint8_t port_a, uint8_t port_b)

    int hackrf_set_operacake_dwell_times(hackrf_device *device, hackrf_operacake_dwell_time *dwell_times, uint8_t count)

    int hackrf_set_operacake_freq_ranges(hackrf_device *device, hackrf_operacake_freq_range *freq_ranges, uint8_t count)

    int hackrf_reset(hackrf_device *device)

    int hackrf_set_clkout_enable(hackrf_device *device, const uint8_t value)

    int hackrf_get_clkin_status(hackrf_device *device, uint8_t *status)

    int hackrf_operacake_gpio_test(hackrf_device *device, uint8_t address, uint16_t *test_result)

    int hackrf_cpld_checksum(hackrf_device *device, uint32_t *crc)

    int hackrf_set_ui_enable(hackrf_device *device, const uint8_t value)

    int hackrf_start_rx_sweep(hackrf_device *device, hackrf_sample_block_cb_fn callback, void *rx_ctx)

    size_t hackrf_get_transfer_buffer_size(hackrf_device *device)

    uint32_t hackrf_get_transfer_queue_depth(hackrf_device *device)

    int hackrf_board_rev_read(hackrf_device *device, uint8_t *value)

    const char *hackrf_board_rev_name(uint8_t board_rev)

    int hackrf_set_leds(hackrf_device *device, const uint8_t state)

    int hackrf_set_user_bias_t_opts(hackrf_device *device, hackrf_bias_t_user_settting_req *req)
