# Script to initialize an SD card for MiST or SiDi FPGA retro board

This script initializes or updates the SD cards for either a [MiST](https://github.com/mist-devel/mist-board/wiki) or [SiDi](https://github.com/ManuFerHi/SiDi-FPGA/wiki) FPGA retro system. \
It tries to create a complete as possible collection of cores and their required ROM files to get an out-of-the-box working SD card. \
There are seperate scripts for [Linux](Linux) and [Windows](Windows) hosts.

This script only collects the work of many other contributors (FPGA, Hardware, Software, ...) to generate a 'distribution' for the systems mentioned above. \
Thanks to all these contributors for their work (see [links to repositories](#Links) for only some of them).

## Preconditions
The SD card must be
- at least 32GB
- formatted (FAT, FAT32 or exFAT)

or use a folder on HDD with the same available disk space

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
- called without parameters: Initialize a subfolder for SiDi (Linux)
	```
	genSD.sh
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
The `genSD` script tries to download the Arcade ROMs from a [set of URLs](Linux/genSD.sh#L197-L230) together with their MAME version. As not all .mra files seem to refere the correct MAME version, only a set of versions is currently enabled which will deliver the best matching ROMs. \
Not a perfect solution, but working quiet good for now (see [Known Issues](#known-issues))

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
It is a good idea to keep these folders as the next run will be much faster (git only needs to be updated and not cloned, the download of the MAME ROMs can be skipped, ...). \
This saves more than 10GB of data not being fetched again.

## Testing
There are initial [test scripts](test) to be executed with Linux and Windows. \
Threse scripts will
- do some script checking
- generate a destination set for
   - mist
   - sidi

	with 2 runs:
   - 1st: run with empty cache (=initial run)
   - 2nd: run with cache and SD (=update run)

Both folders should contain same content at the end (assuming no git or source repo update in between). \
Additionally, a full log for each set is created in the 'SD#' folder with some summary at the end:
- Missing core .rbf files
- Missing MAME ROMs
- MAME ROMs with wrong checksum
- MAME ROMs with missing parts

Additionally it is always a good idea to compare the Linux and Windows generated sets and logs. \
Please keep in mind that each test execution will consume about 40GB of HDD space - not talking about the test run time (several hours)

## Known issues
- **exFAT and DOS attributes (Linux version only)** \
  MiST and SiDi read FAT, FAT32 or exFAT (since [firmware_210525](https://github.com/mist-devel/mist-firmware/commit/56a1a0888f2448e6d1b5cf705d106a648709aff7)) fomatted SD cards. \
  The menu core [uses](http://github.com/mist-devel/mist-board/wiki/SDCardSetup#sd-card-with-multiple-fpga-cores) the system attribute (to show subfolders) and hidden attribute (to hide cores from menu). \
  Linux can write these attributes on FAT or FAT32 drives and SD cards (`msdos`/`vfat` filesystem, written by `fatattr`), but not yet on exFAT formatted cards (`fuseblk` filesystem). \
  This will hopefully be updated in the future (or somebody has a hint how to modify these attributes on exFAT drives). \
  If the Linux script detects a non-FAT/FAT32 filesystem, it asks to continue as the folder attributes can't be set correctly. \
  The windows Powershell script doesn't have this issue.
- **.mra parsing of ROM files** \
  The ROM file names parsed from the `.mra` files refere a MAME version. \
  Unfortunetly many ROMS fetched from the referred MAME version don't match, so I tried to find a best matching download strategy incl. some [extra handling](Linux/genSD.sh#L232-L249), but still some ROM files complain about checksum mismatch or missing parts. \
  ROMs not found: \
  `mikiek.zip`, `rastsagaabl.zip` \
  ROMs found, but with MD5 mismatch or missing parts: \
  `journey.rom`, `sxevious.rom`, `xevious.rom`, `clubpacm.rom`, `combh.rom`, `wbml.rom`, `lottofun.rom`, `spdball.rom`, `topgunbl.rom` \
  Any support here is appreciated.
- **ROMs #2** \
  As this is an early version, there are lots of ROMs and Games to add/fix. \
  But I think here we have a structured base to improve in the future.
- **files and folders required in root folder** \
  Many cores require special files and folders in the root of the SD-Card for their ROM/Game/... files. This makes in my opinion the folder structure a bit messy, especially if we want to have a full core distribution. \
  I would recommend the default root folder of a running core is by default the folder of the core, what would make a modular setup of the SD card much easier. \
  May be somebody (or I myself) finds the time to introduce this feature in the [ARM firmware](http://github.com/mist-devel/mist-firmware).
- **no mist.ini** \
  Currently the script doesn't create/update [mist.ini](http://github.com/mist-devel/mist-board/wiki/DocIni) file. \
  Generating a setup with optimal settings for each core would be a nice additional feature for this script.
- **Missing Jotego Cores** \
  Some .mra files in the Jotego repository refer missing .rbf files in the [mist](https://github.com/jotego/jtbin/tree/master/mist) or [sidi](https://github.com/jotego/jtbin/tree/master/sidi) folders. \
  I've openend an [issue](https://github.com/jotego/jtbin/issues/345) for that.
- **MiSTer support** \
  Need to check the typical **MiSTer** setup and align with this script. \
  Target systems of this script are **MiST** and **SiDi** (much cheaper than MiSTer).

And: It would be nice if all cores would be built for both **MiST** and **SiDi** as the hardware features are nearly identical \
(Thanks to Jotego for his Arcade repository with all releases for multiple FPGA platforms)

## Links

### MiST repositories
- [MiST cores](http://github.com/mist-devel/mist-binaries.git)
- [MiST ARM Firmware](http://github.com/mist-devel/mist-firmware)
- [Marcel Gehstock arcade cores](http://github.com/Gehstock/Mist_FPGA_Cores.git)
- [Alexey Melnikov (sorgelig) cores](http://github.com/sorgelig?tab=repositories)
- [Nino Porcino (nippur72) cores](http://github.com/nippur72)
- [Petr (PetrM1) Ondra SPO 186 core](http://github.com/PetrM1/OndraSPO186_MiST)
- [Jozsef Laszlo cores](http://joco.homeserver.hu/fpga)
- [Till Harbaum's repositories](https://github.com/harbaum)
- [Rok Krajnc's repositories](https://github.com/rkrajnc)

### SiDi repositories
- [Manuel Fernández (ManuFerHi) SiDi cores](http://github.com/ManuFerHi/SiDi-FPGA.git)
- [Bruno Silvia (eubrunosilva) SiDi cores](http://github.com/eubrunosilva/SiDi.git)

### General repositories
- [Jose Tejada (jotego) Arcade cores](http://github.com/jotego/jtbin.git)
- [Gyurco's repositories](https://github.com/gyurco)
- [Sebastien Delestaing's repositories](https://github.com/sebdel)
- [fixed mra tool](http://github.com/gcopoix/mra-tools-c/tree/fix/windows_crash/release) - ([merged](https://github.com/mist-devel/mra-tools-c/commit/1b62e9499860e8e09c171d9b5ff468324c4b480a) 2023-10-10 to [mist-devel/mra-tools-c](https://github.com/mist-devel/mra-tools-c) repository)
