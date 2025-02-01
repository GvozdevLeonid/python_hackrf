# python_hackrf

python_hackrf is a cython wrapper for [hackrf](https://github.com/greatscottgadgets/hackrf).

Before installing python_hackrf library, you must have hackrf host software installed. Because this library uses dynamic linking with an existing library file.

You can install this library using
```
pip install python_hackrf
```

If your hackrf files are in non-standard paths and during installation the python_hackrf cannot find hackrf.h or the library file, you can specify the paths via environment variables
```
export PYTHON_HACKRF_CFLAGS=path_to_hackrf.h
export PYTHON_HACKRF_LDFLAGS=path_to_hackrf.(so, dylib, dll)
```

## Requirements:
* Cython==0.29.37
* Numpy>=2.2.1
* Scipy (optional, for faster work)
* pyFFTW (optional, for faster work)
* pyjnius and android (only for android)


## Scope:
All functions from libhackrf are ported. On Android, connection to hackrf and obtaining a list of devices are changed.

#### hackrf_tools
* hackrf_info.c (Implemented)
* hackrf_operacake.c (Implemented)
* hackrf_sweep.c (Implemented)
* hackrf_transfer.c (Implemented)
* hackrf_clock.c (Will not be implemented)
* hackrf_cpldjtag.c (Will not be implemented)
* hackrf_debug.c (Will not be implemented)
* hackrf_spiflash.c (Will not be implemented and features will not be ported)

## Usage
```
usage: python_hackrf [-h] {info, sweep, operacake, transfer} ...

python_hackrf is a Python wrapper for libhackrf and hackrf-tools.

options:
  -h, --help            show this help message and exit

Available commands:
  {info,operacake,sweep,transfer}
    info                Read device information from HackRF such as serial number and firmware version.
    operacake           Specify either list, mode, or GPIO test option.
    sweep               Command-line spectrum analyzer.
    transfer            Send and receive signals using HackRF. Input/output files consist of complex64 quadrature samples.
```
##### python_hackrf info
```
usage: python_hackrf info [-h] [-f] [-s]

options:
  -h, --help            show this help message and exit
  -f, --full            show info like in hackrf_info
  -s, --serial_numbers  show only founded serial_numbers
```
##### python_hackrf sweep
```
usage: python_hackrf sweep [-h] [-d] [-a] [-f] [-p] [-l] [-g] [-w] [-1] [-N] [-B] [-S] [-s] [-b] [-r]

options:
  -h, --help  show this help message and exit
  -d          serial number of desired HackRF
  -a          RX RF amplifier. If specified = Enable
  -f          freq_min:freq_max. minimum and maximum frequencies in MHz start:stop or start1:stop1,start2:stop2 (MAX_SWEEP_RANGES = 10)
  -p          antenna port power. If specified = Enable
  -l          RX LNA (IF) gain, 0 - 40dB, 8dB steps
  -g          RX VGA (baseband) gain, 0 - 62dB, 2dB steps
  -w          FFT bin width (frequency resolution) in Hz, 245-5000000 Depends on sample rate min= sample rate * 1e6 / 8180, max = sample_rate
              * 1e6 / 4
  -1          one shot mode. If specified = Enable
  -N          number of sweeps to perform
  -B          binary output. If specified = Enable
  -S          sweep style ("L" - LINEAR, "I" - INTERLEAVED). Default is INTERLEAVED
  -s          sample rate in MHz (2, 4, 6, 8, 10, 12, 14, 16, 18, 20). Default is 20
  -b          baseband filter bandwidth in MHz (1.75, 2.5, 3.5, 5.0, 5.5, 6.0, 7.0, 8.0, 9.0, 10.0, 12.0, 14.0, 15.0 20.0, 24.0, 28.0). Default .75 * sample rate
  -r          <filename> output file
```
##### python_hackrf operacake
```
usage: python_hackrf operacake [-h] [-d] [-o] [-m] [-a] [-b] [-f] [-t] [-w] [-l] [-g]

options:
  -h, --help       show this help message and exit
  -d               serial number of desired HackRF
  -o , --address   specify a particular Opera Cake by address. Default is 0
  -m , --mode      specify switching mode [options: manual, frequency, time]
  -a               set port connected to port A0
  -b               set port connected to port B0
  -f               <port:min:max> or <port:min:max>,<port:min:max> automatically assign <port> for range <min:max> in MHz.
  -t               <port:dwell> or <port:dwell>,<port:dwell> in time mode, dwell on <port> for <dwell> samples. Specify only <port> to use the default
                   dwell time (with -w).
  -w               set default dwell time in samples for time mode
  -l, --list       list available Opera Cake boards
  -g, --gpio_test  test GPIO functionality of an Opera Cake
```
##### python_hackrf transfer
Be careful pyhackrf_transfer saves data in complex64 format!
```
usage: python_hackrf transfer [-h] [-d] [-r] [-t] [-f] [-i] [-o] [-m] [-a] [-p] [-l] [-g] [-x] [-s] [-N] [-R] -[b] [-H]

options:
  -d                  serial number of desired HackRF
  -r                  <filename> receive data into file (use "-" for stdout)
  -t                  <filename> transmit data from file (use "-" for stdout)
  -f, --freq_hz       frequency in Hz (0MHz to 7250MHz supported). Default is 900MHz
  -i, --i_freq_hz     intermediate frequency in Hz (2000MHz to 3000MHz supported)
  -o, --lo_freq_hz    front-end local oscillator frequency in Hz (84MHz to 5400MHz supported)
  -m, --image_reject  image rejection filter selection (bypass, low, high)
  -a                  RX RF amplifier. If specified = Enable
  -p                  antenna port power. If specified = Enable
  -l                  RX LNA (IF) gain, 0 - 40dB, 8dB steps
  -g                  RX VGA (baseband) gain, 0 - 62dB, 2dB steps
  -x                  TX VGA (IF) gain, 0 - 47dB, 1dB steps
  -s                  sample rate in MHz (2, 4, 6, 8, 10, 12, 14, 16, 18, 20). Default is 10
  -N                  number of samples to transfer (default is unlimited)
  -R                  repeat TX mode. Fefault is off
  -b                  baseband filter bandwidth in MHz (1.75, 2.5, 3.5, 5.0, 5.5, 6.0, 7.0, 8.0, 9.0, 10.0, 12.0, 14.0, 15.0 20.0, 24.0, 28.0). Default .75 * sample rate
  -H                  synchronize RX/TX to external trigger input
```
## Android
This library can work on android. To do this, go to the android directory and download 3 recipes for [p4a](https://github.com/kivy/python-for-android).

buildozer.spec
```
requirements = python3,android,pyjnius,numpy,libusb,libhackrf,python_hackrf
p4a.local_recipes = path_to_pythonforandroidrecipes_folder
```

#### Your recipes folder should contain at least the following files:
```
pythonforandroidrecipes/
    __init__.py
    libusb/
        __init__.py
    python_hackrf/
        __init__.py
    libhackrf/
        __init__.py
        hackrf_android.patch
        jni/
            Android.mk
            Application.mk
            libhackrf.mk
```


## Examples
You can see a basic example of working with python_hackrf in [this](https://pysdr.org/content/hackrf.html) tutorial.

Please use the original hackrf documentation


## Notes
You can use FileQueue to receive data in pyhackrf_sweep. This will reduce the load on RAM and can work even on weak devices.

For pyhackrf_transfer, FileBuffer has been implemented, which will allow you to more conveniently receive and send iq data from sdr.

you can find the structure you need in the utils module.
