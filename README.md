# Script to initialize an SD card for MiST or SiDi FPGA retro board

This script initializes or updates the SD cards for either a [MiST](https://github.com/mist-devel/mist-board/wiki) or [SiDi](https://github.com/ManuFerHi/SiDi-FPGA/wiki) FPGA retro system. \
It tries to create a complete as possible collection of cores and their required ROM files to get an out-of-the-box working SD card. \
There are seperate scripts for [Linux](Linux) and [Windows](Windows) hosts.

## Preconditions
The SD card must be
- formatted (FAT, FAT32 or exFAT)

## Usage
simply call the script with minor parameters:
```
genSD [-s <mist|sidi>] [-d <destination SD drive or folder>]
```
with
option|description|example
---|---|---
-s|Target system (mist or sidi).<br>If this option isn't specified, `sidi` will be used by default.|-s mist<br>-s sidi
-d|Destination folder the target folders and files are generated.<br>If this option isn't specified, `SD\sidi` will be used by default.|-d /media/SD-Card<br>-d E:
-h|Show some help text.|-h

## Examples
- Initialize SD card for MiST, SD card in drive E: (Windows)
	```
	genSD -s mist -d E:
	```
- Initialize SD card for MiST, SD card mounted to /media/SD-Card (Linux):
	```
	genSD.sh -s mist -d /media/SD-Card
	```
- Initialize SD card for SiDi, SD card in drive E: (Windows)
	```
	genSD -s sidi -d E:
	```
- Initialize SD card for MiST, create in subfolder (Windows)
	```
	genSD -s mist
	```
- Initialize SD card for MiST, create in subfolder (Linux)
	```
	genSD.sh -s mist
	```

## What is created
This script fills/updates an SD card or folder with
- the Computer/Console/Arcade Cores (organized in subfolders)
- the required ROMs and optional sample Game/HDD files
- ARM Firmware update file
to get an SD card which can be directly plugged into **MiST** or **SiDi**.

The generated folder structure:
```
├── Arcade
│   ├── Gehstock
│   │   ├── ...
│   │   └── ...
│   ├── Jotego
│   │   ├── ...
│   │   └── ...
│   ├── ...
│   └── ...
│
├── Computer
│   ├── Amiga
│   ├── Amstrad CPC
│   ├── Atari ST
│   ├── C64
│   ├── ...
│   └── ...
│
├── Console
│   ├── Atari 2600
│   ├── Astrocade
│   ├── Nintendo NES
│   ├── ...
│   └── ...
│
├── <core subfolders unfortunately required in root folder>
├── ...
│
├── <additional rom files unfortunately required in root folder>
├── ...
│
├── core.rbf      # <- menu core
└── firmware.upg  # latest ARM firmware update file
```
The Arcade cores are installed with their required ROM files. \
The information about the Arcade cores/roms is parsed from the `.mra` files (e.g. for [jotego's cores](https://github.com/jotego/jtbin/tree/master/mra)). \
The `genSD` script tries to download the Arcade ROMs from a [set of URLs](Linux/genSD.sh#L196-L199), hoping that at least 1 of them will deliver the requested ROM in the correct version. Not a perfect solution, but mostly working for now (see [Known Issues](#known-issues))

### Cache folders
During installation, several temporary folders are created in the folder of the `genSD` script:
```
├── repos
│   ├── jotego           # Jotego repository
│   ├── mame             # cache folder for Arcade ROM files
│   ├── MiST
│   │   ├── binaries     # MiST core repository
│   │   ├── gehstock     # Gehstock MiST core repository
│   │   └── sorgelig     # Sorgelig MiST core repositories
│   └── SiDi
│       ├── ManuFerHi    # ManuFerHi SiDi core repository
│       └── eubrunosilva # eubrunosilva SiDi core repository
└── tools                # required tools for executung this script
```
It is a good idea to keep these folders as the next run will be much faster (git only needs to be updated and not cloned, the download of the MAME ROMs can be skipped, ...). This saves more than 10GB of data not being fetched again.

## Known issues
- **exFAT and DOS attributes (Linux version only)** \
  MiST and SiDi read FAT, FAT32 or exFAT (since [firmware_210525](https://github.com/mist-devel/mist-firmware/commit/56a1a0888f2448e6d1b5cf705d106a648709aff7)) fomatted SD cards. \
  The menu core [uses](http://github.com/mist-devel/mist-board/wiki/SDCardSetup#sd-card-with-multiple-fpga-cores) the system attribute (to show subfolders) and hidden attribute (to hide cores from menu). \
  Linux can write these attributes on FAT or FAT32 drives and SD cards (`msdos`/`vfat` filesystem, written by `fatattr`), but not yet on exFAT formatted cards (`fuseblk` filesystem). \
  This will hopefully be updated in the future (or somebody has a hint how to modify these attributes on exFAT drives). \
  If the Linux script detects a non-FAT/FAT32 filesystem, it asks to continue as the folder attributes can't be set correctly. \
  The windows Powershell script doesn't have this issue.
- **.mra parsing of ROM files** \
  The ROM file names parsed from the `.mra` files can be found in different versions. \
  I am not sure if I always refere the correct version of the ROM file (sometimes there's a checsum mismatch or parts missing). \
  The .mra file contains a MAME version, but I didn't manage to link this information to the correct download link (supporting all .mra files). \
  Any support here is appreciated.
- **ROMs #2** \
  As I've only started with this script, there are lots of ROMs and Games to add.
- **files and folders required in root folder** \
  Many cores require special files and folders in the root of the SD-Card for their ROM/Game/... files. This makes the folder structure a bit messy. \
  I would recommend the default root folder of a running core is by default the folder of the core, what would make a modular setup of the SD card much easier. \
  May be I find the time to introduce this feature in the [ARM firmware](http://github.com/mist-devel/mist-firmware).
- **no mist.ini** \
  Currently the script doesn't create/update [mist.ini](http://github.com/mist-devel/mist-board/wiki/DocIni) file. \
  Generating a setup with optimal settings for each core would be a nice additional feature for this script. \
  Will hopefully be introduced in the future.
- **MiSTer support** \
  Will need to check the typical MiSTer setup and align with this script. \
  Target systems of this script are MiST and SiDi (much cheaper than MiSTer).

And: It would be nice if all cores will be built for both MiST and SiDi as the hardware features are nearly identical.

## Links

### MiST repositories
- [MiST cores](http://github.com/mist-devel/mist-binaries.git)
- [MiST ARM Firmware](http://github.com/mist-devel/mist-firmware)
- [Marcel Gehstock arcade cores](http://github.com/Gehstock/Mist_FPGA_Cores.git) 
- [Alexey Melnikov (sorgelig) cores](http://github.com/sorgelig?tab=repositories)
- [Nino Porcino (nippur72) cores](http://github.com/nippur72)
- [Petr (PetrM1) Ondra SPO 186 core](http://github.com/PetrM1/OndraSPO186_MiST)
- [Jozsef Laszlo cores](http://joco.homeserver.hu/fpga)

### SiDi repositories
- [Manuel Fernández (ManuFerHi) SiDi cores](http://github.com/ManuFerHi/SiDi-FPGA.git)
- [Bruno Silvia (eubrunosilva) SiDi cores](http://github.com/eubrunosilva/SiDi.git)

### General repositories
- [Jotego Arcade cores](http://github.com/jotego/jtbin.git)
- [fixed mra tool](http://github.com/gcopoix/mra-tools-c/tree/fix/windows_crash/release) (the windows version crashed in rare situations and several issues with filename conversion)

Thanks to all contributors for their work.