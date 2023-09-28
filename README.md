# Script to initialize an empty SD card for [MiST](https://github.com/mist-devel/mist-board/wiki) or [SiDi](https://github.com/ManuFerHi/SiDi-FPGA/wiki)

This script initializes the SD cards for either a MiST or SiDi FPGA system. \
There are seperate versions for [Linux](Linux) and [Windows](Windows).

## Preconditions
The SD card must be
- formatted (FAT32 or exFAT)

## Usage
simply call the script with minor parameters:
```
genSD [-d <destination SD drive or folder>] [-s <mist|sidi>]
```
with
- -d <destination SD (drive) folder> \
     Location where the target files should be generated. \
     If this option isn't specified, `SD\sidi` will be used by default. \
- -s <mist|sidi> \
     Set target system (mist or sidi).
     If this option isn't specified, `sidi` will be used by default. \
- -h \
     Show some help text.

## Examples
- Initialize SD card for MiST, SD card in drive E: (Windows)
	```
	genSD -d E: -s mist
	```
- Initialize SD card for MiST, SD card mounted to /media/SD-Card (Linux):
	```
	genSD.sh -d /media/SD-Card -s mist
	```
- Initialize SD card for SiDi, SD card in drive E: (Windows)
	```
	genSD -d E: -s sidi
	```
- Initialize SD card for MiST, create in subfolder (Windows)
	```
	genSD -s mist
	```
- Initialize SD card for MiST, create in subfolder (Linux)
	```
	genSD.sh -s mist
	```

## Used repositories
- [fixed mra tool](http://github.com/gcopoix/mra-tools-c/tree/fix/windows_crash/release)
- [Jotego Arcade cores](http://github.com/jotego/jtbin.git)

### MiST
- [MiST Cores](http://github.com/mist-devel/mist-binaries.git)
- [Gehstock Arcade Cores](http://github.com/Gehstock/Mist_FPGA_Cores.git) 

### SiDi
- [SiDi Cores](http://github.com/ManuFerHi/SiDi-FPGA.git)
- [eubrunosilva Arcade Cores](http://github.com/eubrunosilva/SiDi.git)
