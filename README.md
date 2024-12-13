# Script to initialize an SD card for MiST, SiDi and SiDi128 FPGA retro board

This script initializes or updates the SD cards for either a [MiST](https://github.com/mist-devel/mist-board/wiki), [SiDi](https://github.com/ManuFerHi/SiDi-FPGA/wiki#sidi-board) or [SiDi128](https://github.com/ManuFerHi/SiDi-FPGA/wiki#sidi128-board) FPGA retro system. \
It tries to create a complete as possible collection of cores and their required ROM files to get an out-of-the-box working SD card. \
There are seperate scripts for [Linux](Linux) and [Windows](Windows) hosts. \
With PowerShell [installed](https://learn.microsoft.com/de-de/powershell/scripting/install/installing-powershell-on-linux) on a Linux system the Windows [genSD.ps1](Windows/genSD.ps1) script is executable on a Linux system too.

This script only collects the work of many other contributors (FPGA, Hardware, Software, ...) to generate a 'distribution' for the systems mentioned above. \
Thanks to all these contributors for their work (see [links to repositories](#Links) for only some of them).

After executing this script appr.

| |MiST|SiDi|SiDi128|
|---|---:|---:|---:|
|.rbf|~255|~140|~180|
|.arc|~1320|~940|~1090|
|.rom|~1360|~970|~1120|

files are collected/generated.

## Preconditions
The SD card must be
- at least 32GB
- formatted (FAT, FAT32 or exFAT)

or use a folder on HDD with the same available disk space

## Usage
simply call the script with minor parameters:
```
genSD [-s <mist|sidi|sidi128>] [-d <destination SD drive or folder>]
```
with
option|description|example
---|---|---
-s|Target system (mist, sidi or sidi128).<br>If this option isn't specified, `sidi` will be used by default.|-s mist<br>-s sidi<br>-s sidi128
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
- Initialize SD card for SiDi128, SD card in drive E: (Windows)
  ```
  genSD -s sidi128 -d E:
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
- default mist.ini

to get an SD card which can be directly plugged into **MiST**, **SiDi** or **SiDi128**.

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
├── <subfolders unfortunately required by some cores in root folder>
├── ...
│
├── <additional files unfortunately required by some cores in root folder>
├── ...
│
├── core.rbf      # <- menu core (named sidi128.rbf on SiDi128)
└── firmware.upg  # latest ARM firmware update file
```
The Arcade cores are installed with their required ROM files. \
The information about the Arcade cores/roms is parsed from the `.mra` files (e.g. for [jotego's cores](https://github.com/jotego/jtbin/tree/master/mra)) and [converted](https://github.com/mist-devel/mist-board/wiki/CoreDocArcade) to `.arc` files together with the created `.rom` file.

### Cache folders
During installation, several temporary folders are created in the folder of the `genSD` script:
```
├── repos
│   ├── jotego           # Jotego repository
│   ├── mame             # cache folder for MAME Arcade ROM files
│   ├── MiST
│   │   ├── binaries     # MiST core repository
│   │   ├── gehstock     # Gehstock MiST core repository
│   │   └── sorgelig     # Sorgelig MiST core repositories
│   ├── SiDi
│   │   ├── ManuFerHi    # ManuFerHi SiDi core repository
│   │   └── eubrunosilva # eubrunosilva SiDi core repository
│   └── misc             # miscellaneous core support files, e.g. game archives, ...
│       ├── Atari 2600
│       ├── Next186
│       └── ...
└── tools                # required tools for executung this script
```
It is a good idea to keep these folders as the next run will be much faster (git only needs to update and not clone, the download of the MAME ROMs and the other miscellaneous files can be skipped, ...). \
This saves more than 10GB of data not being fetched again.

## Developing
The project contains a [workspace file](https://code.visualstudio.com/docs/editor/workspaces) for [Visual Studio Code](https://code.visualstudio.com) with pre-configured
- plugin [recommendations](genSD.code-workspace#L13-L16)
   - [Bash Debugger](https://marketplace.visualstudio.com/items?itemName=rogalmic.bash-debug)
   - [PowerShell Debugger](https://marketplace.visualstudio.com/items?itemName=ms-vscode.powershell)
- script [debug/launch](genSD.code-workspace#L39-L63) settings

Best practice here is to simply open the project by double-click on the [genSD.code-workspace](genSD.code-workspace) file. \
VisualStudio Code will open the project and install/configure the required plugins.

For testing/debugging specific cores, please refer to some [test code](Linux/genSD.sh#L1307-L1327) left disabled in the scripts.

A [configuration](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/using-scriptanalyzer?view=ps-modules#settings-support-in-scriptanalyzer) file for PowerShell [ScriptAnalyzer](https://learn.microsoft.com/en-us/powershell/module/psscriptanalyzer) is [provided](.vscode/PSScriptAnalyzerSettings.psd1) and used by both Visual Studio Code and the Windows [test.bat](test/test.bat#L15) script

## Testing
There are initial [test scripts](test) to be executed with Linux and Windows. \
Threse scripts will
- do some script checking
- generate a destination set for
   - mist
   - sidi
   - sidi128

  with each 2 runs:
   - 1st: run with empty cache (=initial run)
   - 2nd: run with cache and SD (=update run)

Both folders should contain the same content at the end (assuming no git or source repo update in between). \
Additionally, a full log for each set is created in the 'SD#' folder with some summary at the end:
- Missing core .rbf files
- Missing MAME ROMs
- MAME ROMs with wrong checksum
- MAME ROMs with missing parts
- some statistics about the number of .rbf, .arc and .rom files

Additionally it is always a good idea to compare the Linux and Windows generated sets and logs. \
Please keep in mind that each test execution will consume about 50GB of HDD space (the Linux version more as it will test the PowerShell script too) - not talking about the test run time (several hours)

## Known issues
- **exFAT and DOS attributes (Linux version only)** \
  MiST and SiDi read FAT, FAT32 or exFAT (since [firmware_210525](https://github.com/mist-devel/mist-firmware/commit/56a1a0888f2448e6d1b5cf705d106a648709aff7)) fomatted SD cards. \
  The menu core [uses](http://github.com/mist-devel/mist-board/wiki/SDCardSetup#sd-card-with-multiple-fpga-cores) the system attribute (to show subfolders) and hidden attribute (to hide cores from menu). \
  Linux can write these attributes on FAT or FAT32 drives and SD cards (`msdos`/`vfat` filesystem, written by `fatattr`), but not yet on exFAT formatted cards (`fuseblk` filesystem). \
  This will hopefully be updated in the future (or somebody has a hint how to modify these attributes on exFAT drives). \
  If the Linux script detects a non-FAT/FAT32 filesystem, it asks to continue as the folder attributes can't be set correctly. \
  The windows Powershell script executed on a Windows system doesn't have this issue.
- **.mra parsing of ROM files** \
  The ROM file names parsed from the `.mra` files refer a MAME version. \
  Unfortunetly many ROMS, if fetched from their referred MAME version, don't match. I tried to find a best matching [set of download URLs](Linux/genSD.sh#L212-L253) incl. some [extra handling](Linux/genSD.sh#L254-L278), but for some ROM archives `mra` still complains about checksum mismatch or missing parts: \
  **ROMs not found**: \
  `avengersa.zip`, `bioniccbl2.zip`, `kchamp2p.zip`, `makaimurb.zip`, `outruneha.zip`, `pmonster.zip`, `pzloop2jd.zip`, `sbagman2.zip`, `sf2en.zip`, `sf2j17.zip`, `sf2qp2.zip`, `shinobi6.zip`, `timescan3.zip`
  **ROMs found, but with MD5 mismatch or missing parts**: \
  btime.zip journey.zip xevious.zip clubpacm.zip combh.zip choplift.zip tokisens.zip ufosensi.zip wbml.zip
  `journey.rom`, `sxevious.rom`, `xevious.rom`, `clubpacm.rom`, `combh.rom`, `wbml.rom`, `lottofun.rom`, `spdball.rom`, `topgunbl.rom` \
  Any support her` is appreciated.
- **ROMs #2** \
  As this is an early version, there are lots of ROMs and Games to add/fix - please give me a hint or pull request. \
  I think here we have a structured base to improve in the future.
- **files and folders required in root folder** \
  Many cores require special files and folders in the root of the SD-Card for their ROM/Game/... files. This makes in my opinion the folder structure a bit messy, especially if we want to have a full core distribution. \
  I would recommend the default root folder of a running core is by default the folder of the core, what would make a modular setup of the SD card much easier. \
  May be somebody (or I myself) will find the time to introduce this feature in the [ARM firmware](http://github.com/mist-devel/mist-firmware).
- **mist.ini** \
  Currently the script simply uses the default [mist.ini](https://github.com/mist-devel/mist-binaries/blob/master/cores/mist.ini) from the main repository. \
  Generating a configuration with [optimal settings](https://github.com/mist-devel/mist-board/wiki/Configuration-files-(.ini)) for each core would be a nice additional feature for this scripts. \
  Jotego provides an extended [mist.ini](https://github.com/jotego/jtbin/blob/master/arc/mist.ini) file for his cores.
- **Missing Jotego Cores** \
  Some .mra files in the Jotego repository refer missing .rbf files in the [mist](https://github.com/jotego/jtbin/tree/master/mist), [sidi](https://github.com/jotego/jtbin/tree/master/sidi) or [sidi128](https://github.com/jotego/jtbin/tree/master/sidi128) folders (->[issue](https://github.com/jotego/jtbin/issues/345)): \
   - `jtoutrun.rbf`, `jtkiwi.rbf`: \
     not enough ressources with MiST/SiDi according Jotego, although Somhi offers builds for **MiST** and **SiDi (fetched [here](Linux/genSD.sh#L511-L514) in the scripts).
   -  `jtflstory.rbf` `jtngpc.rbf` `jtngp.rbf` `jtriders.rbf` `jts18.rbf` `jtshanon.rbf` `jtshouse.rbf` `jttoki.rbf` `jtwc.rbf` `jtxmen.rbf`

- **MiSTer support** \
  Need to check the typical **MiSTer** setup and align with this script. \
  Target systems of this script are **MiST**, **SiDi** and **SiDi128** (much cheaper than MiSTer).

It would be nice if all cores would be built for both **MiST** and **SiDi** (as the hardware features are nearly identical). **SiDi128** has even more resources so is be able to run all cores a **MiST** or **SiDi** does (and even more). \
Thanks to Jotego for his [jtbin](http://github.com/jotego/jtbin.git) Arcade repository providing releases for multiple FPGA platforms.

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
- [Manuel Fernández Higueras (ManuFerHi) SiDi/SiDi128 cores](http://github.com/ManuFerHi/SiDi-FPGA.git)
- [Bruno Silvia (eubrunosilva) SiDi cores](http://github.com/eubrunosilva/SiDi.git)

### General repositories
- [Jose Tejada (jotego) Arcade cores](http://github.com/jotego/jtbin.git)
- [Gyurco's repositories](https://github.com/gyurco)
- [Somhi's repositories](https://github.com/somhi)
- [Alastair M. Robinson's repositories](https://github.com/robinsonb5)
- [Sebastien Delestaing's repositories](https://github.com/sebdel)
- [fixed mra tool](http://github.com/gcopoix/mra-tools-c/tree/fix/windows_crash/release) - (now [merged](https://github.com/mist-devel/mra-tools-c/commit/1b62e9499860e8e09c171d9b5ff468324c4b480a) to [mist-devel/mra-tools-c](https://github.com/mist-devel/mra-tools-c) repository)
