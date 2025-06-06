#!/bin/bash

# -- genSD.sh
#    Generates or updates the folder structure for using in SiDi or MiST FPGA system.
#    Picked cores:
#    - SiDi repository (https://github.com/ManuFerHi/SiDi-FPGA.git)
#    - MiST repository (https://github.com/mist-devel/mist-binaries.git)
#    - Marcel Gehstock MiST repository (https://github.com/Gehstock/Mist_FPGA_Cores.git)
#    - Alexey Melnikov (sorgelig) MiST repositories (https://github.com/sorgelig/<...>.git)
#    - Jozsef Laszlo MiST cores (https://joco.homeserver.hu/fpga)
#    - Nino Porcino (nippur72) cores (https://github.com/nippur72)
#    - Petr (PetrM1) cores (https://github.com/PetrM1)
#    - Jose Tejada (jotego) MiST/SiDi Arcade repository (https://github.com/jotego/jtbin.git)
#    - eubrunosilva SiDi repositoriy (https://github.com/eubrunosilva/SiDi.git)
#    Additionally the required MAME ROMs are fetched too to generate a working SD card.
#
#    SiDi wiki: https://github.com/ManuFerHi/SiDi-FPGA.git
#    MiST wiki: https://github.com/mist-devel/mist-board/wiki
#
# other SD card creation/update scripts:
#    https://github.com/mist-devel/mist-binaries/tree/master/starter_pack
#    https://gist.github.com/squidrpi/4ce3ea61cbbfa3900e116f9565d45e74
#    https://github.com/theypsilon/Update_All_MiSTer
#
# MiSTer BIOS pack (sub-archives can be downloaded directly too)
#    https://archive.org/download/mister-console-bios-pack_theypsilon/MiSTer_Console_BIOS_PACK.zip
#
# current MAME ROM archive:
#    https://archive.org/download/mame-merged/mame-merged/


# cache folders for repositories, MAME ROMs and miscellaneous support files
GIT_ROOT=$(dirname "${BASH_SOURCE[0]}")/repos
TOOLS_ROOT=$(dirname "${BASH_SOURCE[0]}")/tools
MAME_ROMS=$(dirname "${BASH_SOURCE[0]}")/repos/mame
MISC_FILES=$(dirname "${BASH_SOURCE[0]}")/repos/misc
SUDO_PW=""

check_dependencies() {
  # get necessary helper tools (unzip, unrar, grep, git)
  if ! which unzip   1>/dev/null; then sudo apt install -y unzip;   fi
  if ! which unrar   1>/dev/null; then sudo apt install -y unrar;   fi
  if ! which 7z      1>/dev/null; then sudo apt install -y 7z;      fi
  if ! which grep    1>/dev/null; then sudo apt install -y grep;    fi
  if ! which fatattr 1>/dev/null; then sudo apt install -y fatattr; fi
  if ! which git     1>/dev/null; then sudo apt install -y git;     fi
  if [ ! -x "$TOOLS_ROOT/mra" ]; then
    download_url 'https://github.com/mist-devel/mra-tools-c/raw/master/release/linux/mra' "$TOOLS_ROOT/"
    chmod +x "$TOOLS_ROOT/mra"
  fi
}


clone_or_update_git() {
  local url=$1     # $1: git url
  local dstpath=$2 # $2: destination directory (optional)

  local name=$(basename -s .git "$url")
  if [ -z "$dstpath" ]; then dstpath=$(dirname "${BASH_SOURCE[0]}")/$name; fi

  # check if cloned before
  if [ ! -d "$dstpath/.git" ]; then
    echo "Cloning $url"
    git clone "$url" "$dstpath"
  else
    git -C "$dstpath/" remote update
    if ! git -C "$dstpath/" diff remotes/origin/HEAD --shortstat --exit-code; then
      echo "Updating '$url'"
      git -C "$dstpath/" pull
    else
      echo "Up-to-date: '$url'"
      return
    fi
  fi

  # Set timestamps on git files to match repository commit dates
  # see https://stackoverflow.com/questions/21735435/git-clone-changes-file-modification-time for details
  local unixtime touchtime
  git -C "$dstpath/" ls-tree -r --name-only HEAD | while read f; do
    echo -e -n "\rsychronizing timestamps: \e[0K$f" >&2
    unixtime=$(git -C "$dstpath/" log -1 --format="%at" -- "$f" 2>/dev/null)
    touchtime=$(date -d @$unixtime +'%Y%m%d%H%M.%S' 2>/dev/null)
    touch -t $touchtime "$dstpath/$f" 2>/dev/null
  done
  echo
}


set_system_attr() {
  local p=$1 # $1: path to file/directory
  while [ "$p" != "$SD_ROOT" ] && [ ${#p} -gt 1 ]; do
    if [ -n "$SUDO_PW" ]; then
      echo "$SUDO_PW" | sudo -S fatattr +s "$p" 2>/dev/null
    else
      fatattr +s "$p" 2>/dev/null
    fi
    p=$(dirname "$p")
  done
}

set_hidden_attr() {
  # $1: path to file
  if [ -n "$SUDO_PW" ]; then
    echo "$SUDO_PW" | sudo -S fatattr +h "$1" 2>/dev/null
  else
    fatattr +h "$1" 2>/dev/null
  fi
}

makedir() {
  # $1: directory path
  mkdir -p "$1"
}

sdcopy() {
  local src=$1 # $1: src file(s)
  local dst=$2 # $2: destination file | directory (will be created if it doesn't exist)

  if [ -f "$src" ]; then
    # create destination folder if it doesn't exist
    if [ "${dst: -1}" = "/" ]; then
      makedir "$dst"
    else
      local parent=$(dirname "$dst")
      makedir "$parent"
    fi
    # copy/update if source file is newer
    cp -pu "$src" "$dst"
  elif [ -d "$src" ]; then
    # create destination folder if it doesn't exist
    if [ "${dst: -1}" = "/" ]; then
      makedir "$dst"
    fi
    # copy/update if source file is newer
    cp -pur "$src" "$dst"
  else
    echo -e "\e[1;31mCopy: '$src' not found.\e[0m"
  fi
}

expand() {
  local srcfile=$1 # $1: arc archive
  local dstpath=$2 # $2: destination directory (will be created if it doesn't exist)

  echo -n -e "  extracting '$srcfile' ..."
  if [ -f "$srcfile" ]; then
    # create destination folder if it doesn't exist
    makedir "$dstpath"

    case "$srcfile" in
      *.zip) if unzip -uoq "$srcfile" -d "$dstpath";        then echo " done."; else echo -e "\e[1;31m failed.\e[0m"; fi;;
      *.rar) if unrar x -u -inul -o- "$srcfile" "$dstpath"; then echo " done."; else echo -e "\e[1;31m failed.\e[0m"; fi;;
      *.7z)  if 7z -aos -bso0 x -o"$dstpath" "$srcfile";    then echo " done."; else echo -e "\e[1;31m failed.\e[0m"; fi;;
      *)     echo -e "\e[1;31mInvalid file extension.\e[0m";;
    esac
  else
    echo -e "\e[1;31m not found.\e[0m"
  fi
}


download_url() {
  local url=$1 # $1: url
  local dst=$2 # $2: destination directory | destination file

  echo -n -e "  fetching '$url' ..."
  # create destination folder if it doesn't exist
  if [ "${dst: -1}" = '/' ]; then
    makedir "$dst"
  else
    makedir "$(dirname "$dst")"
  fi
  if [ -d "$dst" ]; then
    local opt=-qNP
    local dstfile=$(realpath "$dst")/$(basename "$url")
  else
    local opt=-qNO
    local dstfile=$dst
  fi
  # skip download if file exists
  if [ -f "$dstfile" ] && [ -s "$dstfile" ]; then
    echo ' exists.'
  else
    # download file
    if wget --content-disposition --no-check-certificate $opt "$dst" "${url//'+'/'%2b'}"; then
      echo ' done.'
    else
      echo -e "\e[1;31m failed.\e[0m"
      false; return
    fi
  fi
  true
}


copy_latest_file() {
  local srcdir=$1  # $1: source directory
  local dstfile=$2 # $2: destination file
  local pattern=$3 # $3: name pattern
  local exclude=$4 # $4: optional exclude pattern

  echo "  '${srcdir//$GIT_ROOT\//}' -> '${dstfile//$(dirname "${BASH_SOURCE[0]}")\//}'"
  if [ -z "$exclude" ]; then
    local files=$(find $srcdir -maxdepth 1 -type f -iname $pattern -printf '%T@ %p\n')
  else
    local files=$(find $srcdir -maxdepth 1 -type f -iname $pattern -printf '%T@ %p\n' -not -iname $exclude)
  fi
  files=$(echo "$files" | sort -k 1nr | head -1 | cut -d ' ' -f 2-)
  if [ ! -z "$files" ]; then
    sdcopy "$files" "$dstfile"
  fi
}


download_mame_roms() {
  local dstroot=$1      # $1: destination directory
  local ver=$2          # $2: mameversion info from .mra file
  local zips=("${@:3}") # $3: array with zip archive name(s), e.g. ('single.zip') or ('file1.zip' 'file2.zip')

  # referred by -mra files: 251, 245, 240, 229, 224, 222, 220, 218, 193
  local mameurls=(
   #"( 'mame-version' 'base url (incl. '/', will be extended by .zip name)'                                              )"
   #"( '0185' 'https://archive.org/download/MAME_0.185_ROMs_merged/MAME_0.185_ROMs_merged.zip/MAME 0.185 ROMs (merged)/' )"
   #"( '0193' 'https://archive.org/download/MAME0.193RomCollectionByGhostware/'                                          )"
   #"( '0193' 'https://archive.org/download/MAME_0.193_ROMs_merged/MAME_0.193_ROMs_merged.zip/MAME 0.193 ROMs (merged)/' )"
   #"( '0197' 'https://archive.org/download/MAME_0.197_ROMs_merged/MAME_0.197_ROMs_merged.zip/MAME 0.197 ROMs (merged)/' )"
   #"( '0201' 'https://archive.org/download/MAME201_Merged/MAME 0.201 ROMs (merged)/'                 )"
   #"( '0202' 'https://archive.org/download/MAME_0.202_Software_List_ROMs_merged/'                    )" # only update
   #"( '0205' 'https://archive.org/download/mame205T7zMerged/'                                        )"
   #"( '0211' 'https://archive.org/download/MAME211RomsOnlyMerged/'                                   )"
   #"( '0212' 'https://archive.org/download/MAME212RomsOnlyMerged/'                                   )"
   #"( '0213' 'https://archive.org/download/MAME213RomsOnlyMerged/'                                   )"
   #"( '0214' 'https://archive.org/download/MAME214RomsOnlyMerged/'                                   )"
   #"( '0215' 'https://archive.org/download/MAME215RomsOnlyMerged/'                                   )"
    "( '0216' 'https://archive.org/download/MAME216RomsOnlyMerged/'                                   )"
    "( '0218' 'https://archive.org/download/MAME218RomsOnlyMerged/MAME 0.218 ROMs (merged).zip/'      )"
    "( '0220' 'https://archive.org/download/MAME220RomsOnlyMerged/'                                   )"
   #"( '0221' 'https://archive.org/download/MAME221RomsOnlyMerged/'                                   )"
   #"( '0221' 'https://archive.org/download/mame-0.221-roms-merged/'                                  )"
   #"( '0221' 'https://archive.org/download/mame_0.221_roms/mame_0.221_roms.zip/'                     )"
   #"( '0222' 'https://archive.org/download/MAME222RomsOnlyMerged/'                                   )"
   #"( '0223' 'https://archive.org/download/MAME223RomsOnlyMerged/'                                   )"
    "( '0224' 'https://archive.org/download/mame0.224/'                                               )"
   #"( '0224' 'https://archive.org/download/MAME_0.224_ROMs_merged/'                                  )"
    "( '0229' 'https://archive.org/download/mame.0229/'                                               )"
   #"( '0236' 'https://archive.org/download/mame-0.236-roms-split/MAME 0.236 ROMs (split)/'           )"
   #"( '0240' 'https://archive.org/download/mame.0240/'                                               )"
   #"( '0245' 'https://archive.org/download/mame.0245.revival/'                                       )"
   #"( '0245' 'https://archive.org/download/mame-0.245-roms-split/MAME 0.245 ROMs (split)/'           )"
   #"( '0251' 'https://archive.org/download/mame251/'                                                 )"
   #"( '0252' 'https://archive.org/download/mame-chds-roms-extras-complete/MAME 0.252 ROMs (merged)/' )"
   #"( '0254' 'https://archive.org/download/mame-chds-roms-extras-complete/MAME 0.254 ROMs (merged)/' )"
   #"( '0256' 'https://archive.org/download/mame-chds-roms-extras-complete/MAME 0.256 ROMs (merged)/' )"
    "( '0259' 'https://archive.org/download/mame-merged/mame-merged/'                                 )"
   #"( '0271' 'https://bda.retroroms.net/downloads/mame/mame-0271-full/'                              )" # login required
   #"( '9999' 'https://bda.retroroms.net/downloads/mame/currentroms/'                                 )" # login required
    "( '9999' 'https://archive.org/download/2020_01_06_fbn/roms/arcade.zip/arcade/'                   )"
    "( '9999' 'https://downloads.retrostic.com/roms/'                                                 )"
    "( '9999' 'https://archive.org/download/fbnarcade-fullnonmerged/arcade/'                          )"
    "( '9999' 'https://www.doperoms.org/files/roms/mame/GETFILE_'                                     )" # without '/', archive.zip leads to 'GETFILE_archive.zip')
  )
  # list of ROMs not downloadable from URLs above, using dedicated download URLs
  local romlookup=(
   #"( 'combh.zip'          'https://downloads.retrostic.com/roms/combatsc.zip'                                    )" #bad MD5
   #"( 'combh.zip'          'https://archive.org/download/mame-0.236-roms-split/MAME 0.236 ROMs (split)/combh.zip' )" #bad MD5
   #"( 'clubpacm.zip'       'https://downloads.retrostic.com/roms/clubpacm.zip'                                    )" #bad MD5
   #"( 'clubpacm.zip'       'https://archive.org/download/mame251/clubpacm.zip'                                    )" #bad MD5
   #"( 'journey.zip'        'https://archive.org/download/MAME216RomsOnlyMerged/journey.zip'                       )" #bad MD5
   #"( 'journey.zip'        'https://downloads.retrostic.com/roms/journey.zip'                                     )" #bad MD5
   #"( 'journey.zip'        'https://mdk.cab/download/split/journey'                                               )" #bad MD5
   #"( 'wbml.zip'           'https://archive.org/download/MAME224RomsOnlyMerged/wbml.zip'                          )" #bad MD5
   #"( 'wbml.zip'           'https://downloads.retrostic.com/roms/wbml.zip'                                        )" #missing files
   #"( 'wbml.zip'           'https://archive.org/download/mame.0229/wbml.zip'                                      )" #bad MD5
   #"( 'wbml.zip'           'https://downloads.romspedia.com/roms/wbml.zip'                                        )" #missing files
   #"( 'xevious.zip'        'https://downloads.retrostic.com/roms/xevious.zip'                                     )" #bad MD5
   #"( 'xevious.zip'        'https://archive.org/download/2020_01_06_fbn/roms/arcade.zip/arcade/xevious.zip'       )" #bad MD5
   #"( 'xevious.zip'        'https://archive.org/download/MAME216RomsOnlyMerged/xevious.zip'                       )" #bad MD5
   #"( 'xevious.zip'        'https://mdk.cab/download/split/xevious'                                               )" #missing files
    "( 'airduel.zip'        'https://www.doperoms.org/files/roms/mame/GETFILE_airduel.zip'                         )" #ok
    "( 'neocdz.zip'         'https://archive.org/download/mame-0.221-roms-merged/neocdz.zip'                       )" #ok
    "( 'neogeo.zip'         'https://github.com/Abdess/retroarch_system/raw/libretro/Arcade/neogeo.zip'            )" #ok
    "( 'roadfu.zip'         'https://archive.org/download/mame0.224/roadfu.zip'                                    )" #ok
    "( 'irrmaze.zip'        'https://www.doperoms.org/files/roms/mame/GETFILE_irrmaze.zip'                         )" #ok
    "( 'zaxxon_samples.zip' 'https://www.arcadeathome.com/samples/zaxxon.zip'                                      )" #ok
    "( 'jtbeta.zip'         'https://archive.org/download/jtkeybeta/beta.zip'                                      )" #ok, from https://twitter.com/jtkeygetterscr1/status/1403441761721012224?s=20&t=xvNJtLeBsEOr5rsDHRMZyw
  )

  if [ ${#zips[@]} -gt 0 ]; then
    # download zips from list
    local zip rlu
    for zip in "${zips[@]}"; do
      # 1st: fetch from special urls if found in lookup table
      for rlu in "${romlookup[@]}"; do
        eval "rlu=$rlu"
        if [ "${rlu[0]}" = "$zip" ]; then
          if download_url "${rlu[1]}" "$dstroot/$zip"; then
            rlu=''
          fi
          break
        fi
      done
      [ -z "$rlu" ] && continue

      # 2nd: fetch required rom sets from MAME URLs starting with MAME version
      for rlu in "${mameurls[@]}"; do
        eval "rlu=$rlu"
        if [ $ver -le ${rlu[0]} ]; then
          if download_url "${rlu[1]}$zip" "$dstroot/"; then
            rlu=''
            break
          fi
        fi
      done
    done
  fi
}


mra() {
  local mrafile=$1 # $1: .mra file. ROM zip file(s) need to be present in same folder, Output files will be generated into same folder
  local dstpath=$2 # $2: destination folder for generated files (.rom and .arc)

  # parse informations from .mra file
  local name=$(basename -s .mra "$mrafile")
  local arcname=$(grep -oP '(?<=<name>)[^<]+' "$mrafile")
  # replace html codes (known used ones)
  arcname=${arcname//'&amp;'/'&'}; arcname=${arcname//'&apos;'/"'"}
  if [ -z "$arcname" ]; then arcname=$name; fi
  # replace special characters with '_' (like rom file rename of mra tool)
  arcname=${arcname//[\/?:]/'_'}; arcname=$(echo ${arcname//"'"/"\'"} | xargs)
  local setname=$(grep -oP '(?<=<setname>)[^<]+' "$mrafile")
  if [ -z "$setname" ]; then
    setname=$name
    # replace special characters (like rom filename rename of mra tool))
    # https://github.com/mist-devel/mra-tools-c/blob/master/src/utils.c#L38
    setname=${setname//[ ()\[\]?.:]/'_'}
  fi
  # trim setname if longer than 16 characters (take 1st 13 characters and last 3 characters (like rom filename trim of mra tool))
  local MAX_ROM_FILENAME_SIZE=16
  if [ ${#setname} -gt $MAX_ROM_FILENAME_SIZE ]; then
    setname=${setname::$((MAX_ROM_FILENAME_SIZE-3))}${setname: -3}
  fi

  # genrate .rom, .ram and .arc files
  echo "  '$name.mra': generating '$setname.rom' and '$name.arc'"
  "$TOOLS_ROOT/mra" -A -O "$dstpath" -z "$MAME_ROMS" "$mrafile"

  # give .rom, .ram and .arc files same timestamp as .mra file
  if [ -f "$dstpath/$setname.rom" ]; then
    touch -r "$mrafile" "$dstpath/$setname.rom"
    #if [ -f "$dstpath/$setname.ram" ]; then
    #  touch -r "$mrafile" "$dstpath/$setname.ram"
    #fi
  else
    echo -e "\e[1;31m  ERROR: '$dstpath/$setname.rom' not found\e[0m"
  fi
  if [ -f "$dstpath/$arcname.arc" ]; then
    if [ "$name" != "$arcname" ]; then mv "$dstpath/$arcname.arc" "$dstpath/$name.arc"; fi
    touch -r "$mrafile" "$dstpath/$name.arc"
  else
    echo -e "\e[1;31m  ERROR: \"$dstpath/$arcname.arc\" not found\e[0m"
  fi
}


process_mra() {
  local mrafile=$1 # $1: source -mra file
  local dstpath=$2 # $2: destination base folder
  local rbfpath=$3 # $3: source rbf folder - if empty don't copy .rbf file

  local rbflookup=(
    #( 'mra .rbf filename reference'                    'real file name'  )"
    "( 'Inferno (Williams)'                             'williams2'       )"
    "( 'Joust 2 - Survival of the Fittest (revision 2)' 'williams2'       )"
    "( 'Mystic Marathon'                                'williams2'       )"
    "( 'Turkey Shoot'                                   'williams2'       )"
    "( 'Power Surge'                                    'time_pilot_mist' )"
    "( 'Time Pilot'                                     'time_pilot_mist' )"
    "( 'Journey'                                        'journey'         )"
  )

  # parse informations from .mra file
  # get name (1st: <name> tag information, 2nd: use .mra filename
  local name=$(grep -oP '(?<=<name>)[^<]+' "$mrafile")
  if [ -z "$name" ]; then name=$(basename -s .mra "$mrafile"); fi
  # replace html codes (known used ones)
  name=${name//'&amp;'/'&'}; name=${name//'&apos;'/"'"}
  # some name beautification (replace/drop special characters and double/leading/tailing spaces)
  name=${name//[\/]/'-'}; name=${name//[\"?:]/}; name=$(echo ${name//"'"/"\'"} | xargs)
  # try to fetch .rbf name: 1st: from <rbf> info, 2nd: from alternative <rbf> info, 3rd: from <name> info (without spaces)
  local rbf=$(grep -oP '(?<=<rbf>)[^<]+' "$mrafile")
  if [ -z "$rbf" ]; then rbf=$(grep -oP '(?<=<rbf alt=)[^>]+' "$mrafile"); fi
  # drop quote characters and make rbf destination filename lowercase
  rbf="${rbf//[\'\"]/}"; rbf=${rbf,,}
  if [ -z "$rbf" ]; then rbf=${name//' '/}; fi
  # fetch mame version
  local mamever=$(grep -oP '(?<=<mameversion>)[^<]+' "$mrafile")
  # grep list of zip files: 1st: encapsulated in ", 2nd: encapsulated in '
  local zps=$(grep -oP '(?<=zip=")[^"]+' "$mrafile")
  if [ -z "$zps" ]; then zps=$(grep -oP "(?<=zip=')[^']+" "$mrafile"); fi
  eval "local zips=(${zps//|/ })"

  # shellcheck disable=SC2027
  echo -e "\n${mrafile//"$GIT_ROOT/"} ($name, $rbf, "${zips[*]}" ($mamever)):"
  if [ -z "$mamever" ]; then
    echo -e "\e[1;33m  WARNING: Missing mameversion\e[0m"
    mamever='0000'
  fi

  # create target folder and set system attribute for this subfolder to be visible in menu core
  makedir "$dstpath"
  set_system_attr "$dstpath"

  # create temporary copy of .mra file with correct name
  if [ "$(dirname "$mrafile")" != '/tmp' ]; then
    sdcopy "$mrafile" "/tmp/$name.mra"
  fi

  # optional copy of core .rbf file
  if [ ! -z "$rbfpath" ]; then
    # get correct core name
    rbfpath=${rbfpath//'/InWork'/}; rbfpath=${rbfpath//'/meta'/}
    local rlu srcrbf=$rbf
    # lookup non-matching filenames <-> .rbf name references in .mra file
    for rlu in "${rbflookup[@]}"; do
      eval "rlu=$rlu"
      if [ "${rlu[0]}" = "$name" ]; then
        if [ "$(find "$rbfpath/" -maxdepth 1 -iname "${rlu[1]}.rbf" 2>/dev/null)" != '' ]; then
          srcrbf=${rlu[1]}
          break
        fi
      fi
    done
    # make source file case insensitive
    srcrbf=$(find "$rbfpath/" -maxdepth 1 -iname "$srcrbf.rbf")

    # copy .rbf file to destination folder and hide from menu (as .arc file will show up)
    if [ -f "$srcrbf" ]; then
      sdcopy "$srcrbf" "$dstpath/$rbf.rbf"
      set_hidden_attr "$dstpath/$rbf.rbf"
    else
      echo -e "\e[1;31m  ERROR: \"$rbfpath/$rbf.rbf\" not found\e[0m"
      rm "/tmp/$name.mra"
      rm -d "$dstpath" 2>/dev/null
      return
    fi
  fi

  # generate .rom/.arc files in destination folder
  if [ ! -f "$dstpath/$name.arc" ] \
  || [ "/tmp/$name.mra" -nt "$dstpath/$name.arc" ] \
  || [ ! -f "$dstpath/$name.rom" ]; then
    # download rom zip archive(s)
    download_mame_roms "$MAME_ROMS" $mamever "${zips[@]}"
    # generate .rom and .arc file from .mra and .zip files
    mra "/tmp/$name.mra" "$dstpath"
    rm "/tmp/$name.mra"
  fi
}


copy_mra_arcade_cores() {
  local mrapath=$1     # $1: src folder for .mra files
  local rbfpath=$2     # $2: src folder for core files
  local dstroot=$3     # $3: destination root folder
  local lut=("${@:4}") # $4: optional lookup table for sub folders

  # loop over all .mra files
  local f dstpath rbf lue c
  for f in "$mrapath/"*.mra; do
    [ -f "$f" ] || continue
    rbf=$(grep -oP '(?<=<rbf>)[^<]+' "$f")
    if [ -z "$rbf" ]; then rbf=$(grep -oP '(?<=<rbf alt=)[^>]+' "$f"); fi
    rbf=${rbf//[\'\"]/}; rbf=${rbf,,}

    dstpath=$dstroot
    if [ "${#lut[@]}" -gt 0 ]; then
      # check for dstpath in lookup table for this core
      for lue in "${lut[@]}"; do
        eval "lue=$lue"
        for c in "${lue[@]:1}"; do
          if [ "$c" = "$rbf" ]; then
            dstpath=$dstpath/${lue[0]}
            break
          fi
        done
      done
    fi
    # build target folder from .mra descrition information
    process_mra "$f" "$dstpath" "$rbfpath"
  done
}


copy_jotego_arcade_cores() {
  local dstroot=$1 # $1: target folder

  echo -e "\n----------------------------------------------------------------------" \
          "\nCopy Jotego Cores for '$SYSTEM' to '$dstroot'" \
          "\n----------------------------------------------------------------------\n"

  # some lookup to sort games into sub folder (if they don't support the <platform> tag)
  local jtlookup=(
    "( 'CAPCOM'     'jt1942' 'jt1943' 'jtbiocom' 'jtbtiger' 'jtcommnd' 'jtexed'   'jtf1drm'  'jtgunsmk' 'jthige'
                    'jtpang' 'jtrumble' 'jtsarms' 'jtsf'    'jtsectnz' 'jttrojan' 'jttora'   'jtvulgus' )"
    "( 'CPS-2'      'jtcps2'  )"
    "( 'CPS-15'     'jtcps15' )"
    "( 'CPS-1'      'jtcps1'  )"
    "( 'SEGA S16A'  'jts16'   )"
    "( 'SEGA S16B'  'jts16b'  )"
    "( 'TAITO TNZS' 'jtkiwi'  )"
  )

  # get jotego git
  local srcpath=$GIT_ROOT/jotego
  clone_or_update_git 'https://github.com/jotego/jtbin.git' "$srcpath"

  if [ $SYSTEM != 'sidi128' ]; then
    # add non-official mist/sidi cores from somhi repo (not yet part of jotego binaries)
    local jtname=$([[ $SYSTEM == 'mist' ]] && echo 'jtoutrun_MiST_230312' || echo 'jtoutrun_SiDi_20231108')
    download_url "https://github.com/somhi/jtbin/raw/master/$SYSTEM/$jtname.rbf" "$srcpath/$SYSTEM/jtoutrun.rbf"
    download_url "https://github.com/somhi/jtbin/raw/master/$SYSTEM/jtkiwi.rbf"  "$srcpath/$SYSTEM/"
  fi

  # ini file from jotego git
  #sdcopy "$srcpath/arc/mist.ini" "$dstroot/"

  # generate destination arcade folders from .mra and .core files
  local saveIFS=$IFS
  IFS=$(echo -en "\n\b")
  local dir; for dir in $(find "$srcpath/mra" -type d | sort); do
    copy_mra_arcade_cores "$dir" "$srcpath/$SYSTEM" "$dstroot" "${jtlookup[@]}"
  done
  IFS=$saveIFS
}


copy_gehstock_mist_cores() {
  local dstroot=$1 # $1: target folder

  echo -e "\n----------------------------------------------------------------------" \
          "\nCopy Gehstock Cores for 'mist' to '$dstroot'" \
          "\n----------------------------------------------------------------------\n"

  # additional ROM/Game copy for some Gehstock cores
  local cores=(
   #"( 'rbf name'         opt_romcopy_fn  )"
    "( 'AppleII.rbf'      apple2e_roms    )"
    "( 'vectrex.rbf'      vectrex_roms    )"
  )
  # get Gehstock git
  local srcroot="$GIT_ROOT/MiST/gehstock"
  clone_or_update_git 'https://github.com/Gehstock/Mist_FPGA_Cores.git' "$srcroot"

  # find all cores
  local saveIFS=$IFS
  IFS=$(echo -en "\n\b")
  local rbf dir dst name item hdl
  for rbf in $(find "$srcroot" -iname '*.rbf' | sort); do
    dir=$(dirname "$rbf")
    shopt -s nocasematch
    dst=${dir//$srcroot/}; dst=${dst//'_MiST'/}; dst=$dstroot/${dst//'/Arcade/'/'/Arcade/Gehstock/'}
    shopt -u nocasematch
    if [ ! -z "$(find "$dir" -maxdepth 1 -iname '*.mra')" ]; then
      # .mra file(s) in same folder as .rbf file
      copy_mra_arcade_cores "$dir" "$dir" "$dst"
    elif [ ! -z "$(find "$dir/meta" -maxdepth 1 -iname '*.mra' 2>/dev/null)" ]; then
      # .mra file(s) in meta subfolder
      copy_mra_arcade_cores "$dir/meta" "$dir" "$dst"
    else
      # 'normal' .rbf-only core (remove '_MIST' from file name)
      shopt -s nocasematch nocaseglob
      name=$(basename "$rbf"); name=${name//'_MiST'/}
      echo -e "\n${rbf//$GIT_ROOT\//}:"
      sdcopy "$rbf" "$dst/$name"
      set_system_attr "$dst"
      if [ ! -z "$(find "$dir" -iname '*.rom')" ]; then
        cp -pu "$dir/"*.rom "$dst/"
      fi
      shopt -u nocasematch nocaseglob

      # check for additional actions for ROMS/Games
      for item in "${cores[@]}"; do
        eval "item=$item"
        rbf=${item[0]}
        hdl=${item[1]}
        if [ "$name" = "$rbf" ]; then
          # optional rom handling
          if [ ! -z "$hdl" ]; then
            $hdl "$dir" "$dst" "$MISC_FILES/$(basename "$dst")"
          fi
          break
        fi
      done
    fi
  done
  IFS=$saveIFS
}


copy_sorgelig_mist_cores() {
  local dstroot=$1 # $1: target folder

  echo -e "\n----------------------------------------------------------------------" \
          "\nCopy Sorgelig/PetrM1/nippur72 Cores for 'mist' to '$dstroot'" \
          "\n----------------------------------------------------------------------"

  # additional cores from Alexey Melnikov's (sorgelig) repositories
  local cores=(
   #"( 'dst folder'                    'git url'                                    'core release folder' opt_romcopy_fn   )"
    "( 'Computer/Apogee BK-01'         'https://github.com/sorgelig/Apogee_MIST.git'           'release'  apogee_roms      )"
    "( 'Arcade/Sorgelig/Galaga'        'https://github.com/sorgelig/Galaga_MIST.git'           'releases'                  )"
    "( 'Computer/Vector-06'            'https://github.com/sorgelig/Vector06_MIST.git'         'releases'                  )"
    "( 'Computer/Specialist'           'https://github.com/sorgelig/Specialist_MIST.git'       'release'                   )"
    "( 'Computer/Phoenix'              'https://github.com/sorgelig/Phoenix_MIST.git'          'releases'                  )"
    "( 'Computer/BK0011M'              'https://github.com/sorgelig/BK0011M_MIST.git'          'releases'                  )"
    "( 'Computer/Ondra SPO 186'        'https://github.com/PetrM1/OndraSPO186_MiST.git'        'releases' ondra_roms       )"
    "( 'Computer/Laser 500'            'https://github.com/nippur72/Laser500_MiST.git'         'releases' laser500_roms    )"
    "( 'Computer/LM80C Color Computer' 'https://github.com/nippur72/LM80C_MiST.git'            'releases' lm80c_roms       )"
   # no release yet for CreatiVision core
   #"( 'Computer/CreatiVision'         'https://github.com/nippur72/CreatiVision_MiST.git'     'releases'                  )"
   # other Sorgelig repos are already part of MiST binaries repo
   #"( 'Computer/ZX Spectrum 128k'     'https://github.com/sorgelig/ZX_Spectrum-128K_MIST.git' 'releases' zx_spectrum_roms )"
   #"( 'Computer/Amstrad CPC 6128'     'https://github.com/sorgelig/Amstrad_MiST.git'          'releases' amstrad_roms     )"
   #"( 'Computer/C64'                  'https://github.com/sorgelig/C64_MIST.git'              'releases' c64_roms         )"
   #"( 'Computer/PET2001'              'https://github.com/sorgelig/PET2001_MIST.git'          'releases' pet2001_roms     )"
   #"( 'Console/NES'                   'https://github.com/sorgelig/NES_MIST.git'              'releases' nes_roms         )"
   #"( 'Computer/SAM Coupe'            'https://github.com/sorgelig/SAMCoupe_MIST.git'         'releases' samcoupe_roms    )"
   #"( '.'                             'https://github.com/sorgelig/Menu_MIST.git'             'release'                   )"
   #"( 'Computer/Apple 1'              'https://github.com/nippur72/Apple1_MiST.git'           'releases'                  )"
  )
  local srcroot=$GIT_ROOT/MiST/sorgelig
  local item name
  for item in "${cores[@]}"; do
    eval "item=$item"
    name=$(basename ${item[1]::-9})
    echo ''
    clone_or_update_git ${item[1]} "$srcroot/$name"
    copy_latest_file "$srcroot/$name/${item[2]}" "$dstroot/${item[0]}/$(basename "${item[0]}").rbf" '*.rbf'
    set_system_attr "$dstroot/${item[0]}"
    # optional rom handling
    if [ ! -z "${item[3]}" ]; then
      ${item[3]} "$srcroot/$name/${item[2]}" "$dstroot/${item[0]}" "$MISC_FILES/$(basename "${item[0]}")"
    fi
  done
}


copy_sebdel_mist_cores() {
  local dstroot=$1 # $1: target folder

  echo -e "\n----------------------------------------------------------------------" \
          "\nCopy Sebastien Delestaing (sebdel) Cores for 'mist' to '$dstroot'" \
          "\n----------------------------------------------------------------------\n"

  local srcpath=$GIT_ROOT/MiST/sebdel
  clone_or_update_git 'https://github.com/sebdel/mist-cores.git' "$srcpath"

  local comp_cores=(
   #"( 'dst folder'                    'path',                 )"
    "( 'Computer/TRS80 Color Computer' 'trs80/output_files'    )"
    "( 'Console/SD8'                   'sd8/output_files'      )" #??
   # other sebdel core is already part of SiDi binaries repo
   #"( 'Computer/Mattel Aquarius',      'aquarius/output_files' )"
  )

  local item; for item in "${comp_cores[@]}"; do
    eval "item=$item"
    copy_latest_file "$srcpath/${item[1]}" "$dstroot/${item[0]}/$(basename "${item[0]}").rbf" '*.rbf'
    set_system_attr "$dstroot/${item[0]}"
  done
}


copy_joco_mist_cores() {
  local dstroot=$1 # $1: target folder

  echo -e "\n----------------------------------------------------------------------" \
          "\nCopy Jozsef Laszlo (joco) Cores for 'mist' to '$dstroot'" \
          "\n----------------------------------------------------------------------\n"

  # MiST Primo from https://joco.homeserver.hu/fpga/mist_primo_en.html
  local roms=( 'primo.rbf'  'primo.rom'
               'pmf/astro.pmf' 'pmf/astrob.pmf' 'pmf/galaxy.pmf' 'pmf/invazio.pmf' 'pmf/jetpac.pmf'
             )
  local f; for f in "${roms[@]}"; do
    download_url "https://joco.homeserver.hu/fpga/download/$f" "$dstroot/Computer/Primo/"
  done
  set_system_attr "$dstroot/Computer/Primo"

  # other joco cores are already part of MiST binaries repo
}


copy_eubrunosilva_sidi_cores() {
  local dstroot=$1 # $1: target folder

  echo -e "\n----------------------------------------------------------------------" \
          "\nCopy eubrunosilva Cores for 'sidi' to '$dstroot'" \
          "\n----------------------------------------------------------------------\n"

  # get eubrunosilva git
  local srcpath=$GIT_ROOT/SiDi/eubrunosilva
  clone_or_update_git 'https://github.com/eubrunosilva/SiDi.git' "$srcpath"

  # generate destination arcade folders from .mra and .core files
  copy_mra_arcade_cores "$srcpath/Arcade" "$srcpath/Arcade" "$dstroot/Arcade/eubrunosilva"

  # additional Computer cores from eubrunosilva repos (which aren't in ManuFerHi's repo)
  local comp_cores=(
   #"( 'dst folder'                       'pattern'       opt_rom_copy_fn )"
    "( 'Computer/Apogee BK-01'            'Apoge'         apogee_roms     )"
    "( 'Computer/Chip-8'                  'Chip8'                         )"
    "( 'Computer/HT1080Z School Computer' 'trs80'         ht1080z_roms    )"
    "( 'Computer/Microcomputer'           'Microcomputer'                 )"
    "( 'Computer/Specialist'              'Specialist'                    )"
    "( 'Computer/Vector-06'               'Vector06'                      )"
   # other eubrunosilva cores are already part of SiDi binaries repo
   #"( 'Computer/Amstrad'                 'Amstrad'       amstrad_roms    )"
   #"( 'Computer/Apple Macintosh'         'plusToo'       plus_too_roms   )"
   #"( 'Computer/Archimedes'              'Archie'        archimedes_roms )"
   #"( 'Computer/Atari STe'               'Mistery'       atarist_roms    )"
   #"( 'Computer/BBC Micro'               'bbc'           bbc_roms        )"
   #"( 'Computer/BK0011M'                 'BK0011M'                       )"
   #"( 'Computer/C16'                     'c16'           c16_roms        )"
   #"( 'Computer/C64'                     'c64'           c64_roms        )"
   #"( 'Computer/Mattel Aquarius'         'Aquarius'                      )"
   #"( 'Computer/MSX1'                    'MSX'           msx1_roms       )"
   #"( 'Computer/Oric'                    'Oric'          oric_roms       )"
   #"( 'Computer/PET2001'                 'Pet2001'       pet2001_roms    )"
   #"( 'Computer/SAM Coupe'               'SAMCoupe'      samcoupe_roms   )"
   #"( 'Computer/Sinclair QL'             'QL'            ql_roms         )"
   #"( 'Computer/VIC20'                   'VIC20'         vic20_roms      )"
   #"( 'Computer/ZX Spectrum 128k'        'Spectrum128k'                  )"
   #"( 'Computer/ZX8x'                    'ZX8x'          zx8x_roms       )"
  )

  local item; for item in "${comp_cores[@]}"; do
    eval "item=$item"
    copy_latest_file "$srcpath/Computer" "$dstroot/${item[0]}/$(basename "${item[0]}").rbf" "${item[1]}*.rbf"
    set_system_attr "$dstroot/${item[0]}"
    # optional rom handling
    if [ ! -z "${item[2]}" ]; then
      ${item[2]} "$srcpath/Computer" "$dstroot/${item[0]}" "$MISC_FILES/$(basename "${item[0]}")"
    fi
  done
}


# handlers for core specific ROM actions. $1=core src directory, $2=sd core dst directory, $3=core specific cache folder
amiga_roms()           { sdcopy "$1/AROS.ROM" "$2/kick/aros.rom"
                         sdcopy "$1/HRTMON.ROM" "$SD_ROOT/hrtmon.rom"
                         sdcopy "$1/MinimigUtils.adf" "$2/adf/"
                         expand "$1/minimig_boot_art.zip" "$SD_ROOT/"
                         local kicks=('https://archive.org/download/Older_Computer_Environments_and_Operating_Systems/Amiga.zip/Amiga/Amiga Kickstart Roms - Complete - TOSEC v0.04/KS-ROMs/Kickstart v1.3 rev 34.5 (1987)(Commodore)(A500-A1000-A2000-CDTV).rom'
                                      'https://archive.org/download/Older_Computer_Environments_and_Operating_Systems/Amiga.zip/Amiga/Amiga Kickstart Roms - Complete - TOSEC v0.04/KS-ROMs/Kickstart v2.04 rev 37.175 (1991)(Commodore)(A500+).rom'
                                      'https://archive.org/download/Older_Computer_Environments_and_Operating_Systems/Amiga.zip/Amiga/Amiga Kickstart Roms - Complete - TOSEC v0.04/KS-ROMs/Kickstart v2.05 rev 37.300 (1991)(Commodore)(A600HD).rom'
                                      'https://archive.org/download/Older_Computer_Environments_and_Operating_Systems/Amiga.zip/Amiga/Amiga Kickstart Roms - Complete - TOSEC v0.04/KS-ROMs/Kickstart v3.1 rev 40.63 (1993)(Commodore)(A500-A600-A2000).rom'
                                      'https://archive.org/download/Older_Computer_Environments_and_Operating_Systems/Amiga.zip/Amiga/Amiga Kickstart Roms - Complete - TOSEC v0.04/KS-ROMs/Kickstart v3.1 rev 40.68 (1993)(Commodore)(A1200).rom'
                                      'https://archive.org/download/Older_Computer_Environments_and_Operating_Systems/Amiga.zip/Amiga/Amiga Kickstart Roms - Complete - TOSEC v0.04/KS-ROMs/Kickstart v3.1 rev 40.70 (1993)(Commodore)(A4000).rom'
                                     )
                         local f; for f in "${kicks[@]}"; do
                           download_url "$f" "$3/kick/" && sdcopy "$3/kick/$(basename "$f")" "$2/kick/"
                         done
                         local adfs=( 'https://archive.org/download/commodore-amiga-operating-systems-workbench/Workbench v3.1 rev 40.42 (1994)(Commodore)(M10)(Disk 1 of 6)(Install)[!].zip'
                                      'https://archive.org/download/commodore-amiga-operating-systems-workbench/Workbench v3.1 rev 40.42 (1994)(Commodore)(M10)(Disk 2 of 6)(Workbench)[!].zip'
                                      'https://download.freeroms.com/amiga_roms/t/turrican.zip'
                                      'https://download.freeroms.com/amiga_roms/t/turrican2.zip'
                                      'https://download.freeroms.com/amiga_roms/t/turrican3.zip'
                                      'https://download.freeroms.com/amiga_roms/a/agony.zip'
                                    )
                         for f in "${adfs[@]}"; do
                           download_url "$f" "$3/adf/" && expand "$3/adf/$(basename "$f")" "$2/adf/"
                         done
                         local hdfs=( 'https://archive.org/download/amigaromset/CommodoreAmigaRomset1.zip/MonkeyIsland2_v1.1_De_0077.hdf'
                                    )
                         for f in "${hdfs[@]}"; do
                           download_url "$f" "$3/hdf/" && sdcopy "$3/hdf/$(basename "$f")" "$2/hdf/"
                         done
                         # use Kickstart 3.1 as default kick.rom
                         sdcopy "$2/kick/Kickstart v3.1 rev 40.68 (1993)(Commodore)(A1200).rom" "$SD_ROOT/kick.rom"
                       }
amstrad_roms()         { if [ $SYSTEM = 'mist' ]; then cp -pu "$1/ROMs/"*.e* "$SD_ROOT/"; else cp -pu "$1/amstrad.rom" "$SD_ROOT/"; fi
                         download_url 'https://github.com/mist-devel/mist-binaries/raw/master/cores/amstrad/ROMs/AST-Equinox.dsk' "$3/"
                         sdcopy "$3/AST-Equinox.dsk" "$SD_ROOT/amstrad/AST-Equinox.dsk" # roms are presented by core from /amstrad folder
                         local games=('https://www.amstradabandonware.com/mod/upload/ams_de/games_disk/cyberno2.zip'
                                      'https://www.amstradabandonware.com/mod/upload/ams_de/games_disk/supermgp.zip'
                                     )
                         local f; for f in "${games[@]}"; do
                           download_url "$f" "$3/" && expand "$3/$(basename "$f")" "$SD_ROOT/amstrad/"
                         done
                       }
apogee_roms()          { sdcopy "$1/../extra/apogee.rom" "$2/"; }
apple1_roms()          { if [ $SYSTEM = 'mist' ]; then
                           sdcopy "$1/BASIC.e000.prg" "$2/"
                           sdcopy "$1/DEMO40TH.0280.prg" "$2/"
                         fi
                       }
apple1_roms_alt()      { download_url 'https://github.com/mist-devel/mist-binaries/raw/master/cores/apple1/BASIC.e000.prg' "$2/"
                         download_url 'https://github.com/mist-devel/mist-binaries/raw/master/cores/apple1/DEMO40TH.0280.prg' "$2/"
                       }
apple2e_roms()         { download_url 'https://mirrors.apple2.org.za/Apple II Documentation Project/Computers/Apple II/Apple IIe/ROM Images/Apple IIe Enhanced Video ROM - 342-0265-A - US 1983.bin' "$2/"
                         download_url 'https://archive.org/download/PitchDark/Pitch-Dark-20210331.zip' "$3/"
                         expand "$3/Pitch-Dark-20210331.zip" "$2/"
                       }
apple2p_roms()         { download_url 'https://github.com/wsoltys/mist-cores/raw/master/apple2fpga/apple_II.rom' "$2/"
                         download_url 'https://github.com/wsoltys/mist-cores/raw/master/apple2fpga/bios.rom' "$2/"
                       }
archimedes_roms()      { sdcopy "$1/SVGAIDE.RAM" "$SD_ROOT/svgaide.ram"
                         expand "$1/RiscDevIDE.zip" "$2/"
                         download_url 'https://github.com/MiSTer-devel/Archie_MiSTer/raw/master/releases/riscos.rom' "$SD_ROOT/"
                         download_url 'https://github.com/mist-devel/mist-binaries/raw/master/cores/archimedes/archie1.zip' "$3/"
                         expand "$3/archie1.zip" "$SD_ROOT/"
                       }
atarist_roms()         { download_url 'https://github.com/mist-devel/mist-binaries/raw/master/cores/mist/tos.img' "$SD_ROOT/"
                         #download_url 'https://downloads.sourceforge.net/project/emutos/emutos/1.2.1/emutos-512k-1.2.1.zip' "$SD_ROOT/"
                         #expand "$2/emutos-512k-1.2.1.zip" "$2/"; sdcopy "$2/emutos-512k-1.2.1/etos512de.img" "$SD_ROOT/tos.img"
                         download_url 'https://github.com/mist-devel/mist-binaries/raw/master/cores/mist/system.fnt' "$SD_ROOT/"
                         download_url 'https://github.com/mist-devel/mist-binaries/raw/master/cores/mist/disk_a.st' "$2/"
                       }
atari800_roms()        { sdcopy "$1/A800XL.ROM" "$2/a800xl.rom"; }
atari2600_roms()       { download_url 'https://static.emulatorgames.net/roms/atari-2600/Asteroids (1979) (Atari) (PAL) [!].zip' "$3/"
                         download_url 'https://download.freeroms.com/atari_roms/starvygr.zip' "$3/"
                         expand "$3/Asteroids (1979) (Atari) (PAL) [!].zip" "$SD_ROOT/ma2601/" # roms are presented by core from /MA2601 folder
                         expand "$3/starvygr.zip" "$SD_ROOT/ma2601/"
                       }
atari5200_roms()       { download_url 'https://downloads.romspedia.com/roms/Asteroids (1983) (Atari).zip' "$3/"
                         expand "$3/Asteroids (1983) (Atari).zip" "$SD_ROOT/a5200/" # roms are presented by core from /A5200 folder
                       }
atari7800_roms()       { download_url 'https://archive.org/download/Atari7800FullRomCollectionReuploadByDataghost/Atari 7800.7z' "$3/"
                         expand "$3/Atari 7800.7z" "$3/"
                         makedir "$SD_ROOT/a7800"
                         cp -pur "$3/Atari 7800/"* "$SD_ROOT/a7800/"
                         rm -rf "$3/Atari 7800"
                       }
bbc_roms()             { sdcopy "$1/bbc.rom" "$2/"
                         download_url 'https://github.com/ManuFerHi/SiDi-FPGA/raw/master/Cores/Computer/BBC/BBC.vhd' "$3/"
                         sdcopy "$3/BBC.vhd" "$2/"
                         download_url 'https://www.stardot.org.uk/files/mmb/higgy_mmbeeb-v1.2.zip' "$3/"
                         expand "$3/higgy_mmbeeb-v1.2.zip" "$3/beeb/"
                         sdcopy "$3/beeb/BEEB.MMB" "$2/BEEB.ssd"
                         rm -rf "$2/beeb"
                       }
bk0011m_roms()         { sdcopy "$1/bk0011m.rom" "$2/"; }
c16_roms()             { sdcopy "$1/c16.rom" "$2/"
                         download_url 'https://www.c64games.de/c16/spiele/boulder_dash_3.prg' "$3/"
                         download_url 'https://www.c64games.de/c16/spiele/giana_sisters.prg' "$3/"
                         sdcopy "$3/boulder_dash_3.prg" "$SD_ROOT/c16/" # roms are presented by core from /C16 folder
                         sdcopy "$3/giana_sisters.prg" "$SD_ROOT/c16/"
                       }
c64_roms()             { sdcopy "$1/c64.rom" "$2/"
                         if [ $SYSTEM = 'mist' ]; then sdcopy "$1/C64GS.ARC" "$2/C64GS.arc"; fi
                         download_url 'https://csdb.dk/getinternalfile.php/67833/giana sisters.prg' "$3/"
                         #curl -O "$2/roms/SuperZaxxon.zip" -d 'id=727332&download=Télécharger' 'https://www.planetemu.net/php/roms/download.php'
                         download_url 'https://www.c64.com/games/download.php?id=315' "$3/zaxxon.zip"
                         download_url 'https://www.c64.com/games/download.php?id=2073' "$3/super_zaxxon.zip"
                         sdcopy "$3/giana sisters.prg" "$SD_ROOT/c64/" # roms are presented by core from /C64 folder
                         expand "$3/zaxxon.zip" "$SD_ROOT/c64/"
                         expand "$3/super_zaxxon.zip" "$SD_ROOT/c64/"
                       }
coco2_roms()           { copy_mra_arcade_cores "$1" '' "$2"; }
coco3_roms()           { sdcopy "$1/COCO3.ROM" "$2/coco3.rom"; }
enterprise_roms()      { sdcopy "$1/ep128.rom" "$2/"
                         if [ ! -f "$2/ep128.vhd" ]; then
                           download_url 'http://www.ep128.hu/Emu/Ep_ide192m.rar' "$3/"
                           expand "$3/Ep_ide192m.rar" "$3/"
                           mv -uf "$3/Ep_ide192m.vhd" "$2/ep128.vhd"
                         fi
                       }
gameboy_roms()         { download_url 'https://archive.org/download/mister-console-bios-pack_theypsilon/MiSTer_Console_BIOS_PACK.zip/Gameboy.zip' "$3/"
                         expand "$3/Gameboy.zip" "$2/roms/"
                       }
ht1080z_roms()         { if [ $SYSTEM = 'mist' ]; then
                           sdcopy "$1/HT1080Z.ROM" "$2/ht1080z.rom"
                         else
                           download_url 'https://joco.homeserver.hu/fpga/download/HT1080Z.ROM' "$2/ht1080z.rom"
                         fi
                       }
intellivision_roms()   { sdcopy "$1/intv.rom" "$2/"; }
laser500_roms()        { sdcopy "$1/laser500.rom" "$2/"; }
lm80c_roms()           { sdcopy "$1/lm80c.rom" "$2/"; }
lynx_roms()            { download_url 'https://archive.org/download/mister-console-bios-pack_theypsilon/MiSTer_Console_BIOS_PACK.zip/AtariLynx.zip' "$3/"
                         expand "$3/AtariLynx.zip" "$2/"
                       }
menu_image()           { download_url 'https://github.com/mist-devel/mist-binaries/raw/master/cores/menu/menu.rom' "$2/"; }
msx1_roms()            { expand "$1/MSX1_vhd.rar" "$2/"; }
msx2p_roms()           { return; }
neogeo_roms()          { if [ $SYSTEM = 'mist' ]; then
                           copy_mra_arcade_cores "$1/bios" '' "$2"
                         else
                           local f; for f in $(wget -q -O- https://api.github.com/repos/mist-devel/mist-binaries/contents/cores/neogeo/bios - | grep -oP '(?<="download_url": ")[^*]*.mra' | sort); do
                             download_url "$f" "$3/"
                           done
                           copy_mra_arcade_cores "$3/" '' "$2"
                         fi
                         set_hidden_attr "$2/NeoGeo.rbf"
                         makedir "$SD_ROOT/neogeo"
                         if [ ! -f "$SD_ROOT/neogeo/neogeo.vhd" ]; then
                           dd if=/dev/zero of="$SD_ROOT/neogeo/neogeo.vhd" bs=8k count=1
                         fi
                         download_url 'https://archive.org/download/1-g-1-r-terra-onion-snk-neo-geo/1G1R - TerraOnion - SNK - Neo Geo.zip/maglord.neo' "$SD_ROOT/neogeo/Magician Lord.neo"
                         download_url 'https://archive.org/download/1-g-1-r-terra-onion-snk-neo-geo/1G1R - TerraOnion - SNK - Neo Geo.zip/twinspri.neo' "$SD_ROOT/neogeo/Twinkle Star Sprites.neo"
                       }
nes_roms()             { download_url 'https://www.nesworld.com/powerpak/powerpak130.zip' "$3/"
                         expand "$3/powerpak130.zip" "$3/"
                         sdcopy "$3/POWERPAK/FDSBIOS.BIN" "$2/fdsbios.bin"
                         rm -rf "$3/POWERPAK"
                         download_url 'https://info.sonicretro.org/images/f/f8/SonicTheHedgehog(Improvment+Tracks).zip' "$3/"
                         expand "$3/SonicTheHedgehog(Improvment+Tracks).zip" "$SD_ROOT/nes/"
                         download_url 'https://archive.org/download/nes-romset-ultra-us/Super Mario Kart Raider (Unl) [!].zip' "$3/"
                         expand "$3/Super Mario Kart Raider (Unl) [!].zip" "$SD_ROOT/nes/"
                       }
next186_roms()         {
                         sdcopy "$1/Next186.ROM" "$2/next186.rom"
                         download_url 'https://archive.org/download/next-186.vhd/Next186.vhd.zip' "$3/"
                         expand "$3/Next186.vhd.zip" "$SD_ROOT/"
                         rm -rf "$SD_ROOT/__MACOSX"
                       }
nintendo_sysattr()     { set_system_attr "$2/Nintendo hardware"; }
ondra_roms()           { download_url 'https://docs.google.com/uc?export=download&id=1seHwftKzaBWHR4sSZVJLq7IKw-ZLafei' "$3/OndraSD.zip"
                         expand "$3/OndraSD.zip" "$3/Ondra/"
                         sdcopy "$3/Ondra/__LOADER.BIN" "$SD_ROOT/ondra/__loader.bin"
                         sdcopy "$3/Ondra/_ONDRAFM.BIN" "$SD_ROOT/ondra/_ondradm.bin"
                         rm -rf "$3/Ondra"
                       }
oric_roms()            { if [ $SYSTEM = 'mist' ]; then sdcopy "$1/oric.rom" "$2/"; fi
                         local urls=("('https://github.com/rampa069/Oric_Mist_48K/raw/master/dsk' \
                                           '1337_dsk.dsk' 'B7es_dsk.dsk' 'ElPrisionero.dsk' 'Oricium12_edsk.dsk' 'SEDO40u_DSK.dsk' 'Torreoscura.dsk' 'space1999-en_dsk.dsk' )"
                                     "('https://github.com/teiram/oric-dsk-manager/raw/master/src/test/resources' \
                                           'space1999-en_dsk.dsk' 'BuggyBoy.dsk' 'barbitoric.dsk' 'oricdos.dsk' 'xenon1.new.dsk' 'xenon1.old.dsk' )"
                                    )
                         local u dsks f; for u in "${urls[@]}"; do
                           eval "dsks=$u"
                           for f in "${dsks[@]:1}"; do
                             download_url "${dsks[0]}/$f" "$SD_ROOT/oric/"
                           done
                         done
                       }
pcxt_roms()            { download_url 'https://github.com/MiSTer-devel/PCXT_MiSTer/raw/main/games/PCXT/hd_image.zip' "$3/"
                         expand "$3/hd_image.zip" "$3/"
                         mv -uf "$3/Freedos_HD.vhd" "$2/PCXT.HD0"
                         #download_url 'https://github.com/640-KB/GLaBIOS/releases/download/v0.2.4/GLABIOS_0.2.4_8T.ROM' "$2/"
                         download_url 'https://github.com/somhi/PCXT_DeMiSTify/raw/main/SW/ROMs/pcxt_pcxt31.rom' "$2/"
                       }
pet2001_roms()         { download_url 'https://github.com/mist-devel/mist-binaries/raw/master/cores/pet2001/pet2001.rom' "$2/"; }
plus_too_roms()        { download_url 'https://github.com/ManuFerHi/SiDi-FPGA/raw/master/Cores/Computer/Plus_too/plus_too.rom' "$2/"
                         expand "$1/hdd_empty.zip" "$2/"
                       }
psx_roms()             { download_url 'https://ps1emulator.com/SCPH1001.BIN' "$2/games/PSX/boot.rom"
                         download_url 'https://github.com/MiSTer-devel/PSX_MiSTer/raw/main/memcard/empty.mcd' "$2/"
                       }
ql_roms()              { cp -pu "$1/"*.rom "$2/"
                         download_url 'https://github.com/mist-devel/mist-binaries/raw/master/cores/ql/QL-SD.zip' "$3/"
                         expand "$3/QL-SD.zip" "$2/"
                       }
samcoupe_roms()        { sdcopy "$1/samcoupe.rom" "$2/"; }
sidi128_arcade()       { makedir "$2/"; cp -pu "$1/"*.rbf "$2/"; }
snes_roms()            { download_url 'https://archive.org/download/mister-console-bios-pack_theypsilon/MiSTer_Console_BIOS_PACK.zip/SNES.zip' "$3/"
                         expand "$3/SNES.zip" "$2/"
                         download_url 'https://nesninja.com/downloadssnes/Super Mario World (U) [!].smc' "$3/"
                         sdcopy "$3/Super Mario World (U) [!].smc" "$SD_ROOT/snes/"
                       }
sourcerer_roms()       { download_url 'https://archive.org/download/year-based-collection-of-games-for-the-exidy-sorcerer-v-1.0/Year-Based Collection of Games for the Exidy Sorcerer v1.0.zip' "$3/"
                         expand "$3/Year-Based Collection of Games for the Exidy Sorcerer v1.0.zip" "$2/"
                       }
speccy_roms()          { sdcopy "$1/speccy.rom" "$2/"; }
ti994a_roms()          { sdcopy "$1/TI994A.ROM" "$2/ti994a.rom"; }
tnzs_roms()            { local kiwis=( "Arkanoid - Revenge of DOH (World).mra"
                                       "Dr. Toppel's Adventure (World).mra"
                                       "Extermination (World).mra"
                                       "Insector X (World).mra"
                                       "Kageki (World).mra"
                                       "The NewZealand Story (World, new version) (P0-043A PCB).mra"
                                     )
                         local f; for f in "${kiwis[@]}"; do
                           download_url "https://github.com/jotego/jtbin/raw/master/mra/$f" "$3/"
                         done
                         copy_mra_arcade_cores "$3" '' "$2"
                       }
tsconf_roms()          { cp -pu "$1/TSConf.r"* "$SD_ROOT/"
                         download_url "https://github.com/mist-devel/mist-binaries/raw/master/cores/tsconf/TSConf.vhd.zip" "$3/"
                         expand "$3/TSConf.vhd.zip" "$SD_ROOT/"
                       }
turbogfx_roms()        { download_url 'https://archive.org/download/mister-console-bios-pack_theypsilon/MiSTer_Console_BIOS_PACK.zip/TurboGrafx16.zip' "$3/"
                         expand "$3/TurboGrafx16.zip" "$3/"
                         mv -uf "$3/TurboGrafx16/"* "$2/"
                         rm -rf "$3/TurboGrafx16"
                       }
tvc_roms()             { sdcopy "$1/tvc.rom" "$2/"; }
vectrex_roms()         {
                         download_url 'https://archive.org/download/VectrexROMS/Vectrex_ROMS.zip' "$3/"
                         expand "$3/Vectrex_ROMS.zip" "$3"
                         local arc; for arc in $(find "$3/" -iname '*.7z' | sort); do
                           expand "$arc" "$SD_ROOT/vectrex/"
                         done
                       }
vic20_roms()           { sdcopy "$1/vic20.rom" "$2/"; }
videopac_roms()        { download_url 'https://archive.org/download/Philips_Videopac_Plus_TOSEC_2012_04_23/Philips_Videopac_Plus_TOSEC_2012_04_23.zip' "$3/"
                         expand "$3/Philips_Videopac_Plus_TOSEC_2012_04_23.zip" "$3/"
                         local zippath="$3/Philips Videopac+ [TOSEC]/Philips Videopac+ - Games (TOSEC-v2011-02-22_CM)"
                         local zip; for zip in $(find "$zippath" -iname '*.zip' | sort); do
                           expand "$zip" "$SD_ROOT/videopac/"
                         done
                       }
x68000_roms()          { sdcopy "$1/X68000.rom" "$2/"; sdcopy "$1/BLANK_disk_X68000.D88" "$2/"; }
zx8x_roms()            { download_url 'https://github.com/ManuFerHi/SiDi-FPGA/raw/master/Cores/Computer/ZX8X/zx8x.rom' "$2/"; }
zx_spectrum_roms()     { sdcopy "$1/spectrum.rom" "$2/"; }
bagman_roms()          {
                         download_url 'https://github.com/Gehstock/Mist_FPGA/raw/master/Arcade_MiST/Bagman Hardware/meta/Super Bagman.mra' '/tmp/'
                         process_mra '/tmp/Super Bagman.mra' "$2"
                       }

cores=(
 #"( 'core dst dir'                                   'src dir MiST'  'src dir SiDi'                                      opt_rom_copy_fn      )"
 # Main Menu
  "( '.'                                              'menu'          'menu'                                              menu_image           )"
 # Computers
  "( 'Computer/Amstrad CPC'                           'amstrad'       'Computer/AmstradCPC'                               amstrad_roms         )"
  "( 'Computer/Amstrad PCW'                           ''              'Computer/AmstradPCW'                                                    )"
  "( 'Computer/Amiga'                                 'minimig-aga'   'Computer/Amiga'                                    amiga_roms           )"
  "( 'Computer/Apple I'                               'apple1'        'Computer/AppleI'                                   apple1_roms          )"
  "( 'Computer/Apple IIe'                             'appleIIe'      'Computer/AppleIIe'                                 apple2e_roms         )"
  "( 'Computer/Apple II+'                             'appleii+'      'Computer/AppleII+'                                 apple2p_roms         )"
  "( 'Computer/Apple Macintosh'                       'plus_too'      'Computer/Plus_too'                                 plus_too_roms        )"
  "( 'Computer/Archimedes'                            'archimedes'    'Computer/Archimedes'                               archimedes_roms      )"
  "( 'Computer/Atari 800'                             'atari800'      'Computer/Atari800'                                 atari800_roms        )"
  "( 'Computer/Atari ST'                              'mist'          'Computer/AtariST'                                  atarist_roms         )"
  "( 'Computer/Atari STe'                             'mistery'       'Computer/Mistery'                                  atarist_roms         )"
  "( 'Computer/BBC Micro'                             'bbc'           'Computer/BBC'                                      bbc_roms             )"
  "( 'Computer/BK0011M'                               ''              'Computer/BK0011M'                                  bk0011m_roms         )"
  "( 'Computer/C16'                                   'c16'           'Computer/C16'                                      c16_roms             )"
  "( 'Computer/C64'                                   'fpga64'        'Computer/C64'                                      c64_roms             )"
  "( 'Computer/Coleco Adam'                           ''              'Computer/Adam'                                                          )"
  "( 'Computer/Color Computer 2'                      'coco2'         'Computer/CoCo'                                     coco2_roms           )"
  "( 'Computer/Color Computer 3'                      ''              'Computer/Coco3'                                    coco3_roms           )"
  "( 'Computer/Enterprise 128'                        'enterprise'    'Computer/ElanEnterprise'                           enterprise_roms      )"
  "( 'Computer/Exidy Sorcerer'                        'sorcerer'      'Computer/Sorcerer'                                 sourcerer_roms       )"
  "( 'Computer/HT1080Z School Computer'               'ht1080z'       ''                                                                       )"
  "( 'Computer/Laser500'                              ''              'Computer/Laser500'                                 laser500_roms        )"
  "( 'Computer/Luxor ABC80'                           'abc80'         'Computer/ABC80'                                                         )"
  "( 'Computer/Lynx'                                  ''              'Computer/CamputerLynx'                                                  )"
  "( 'Computer/Mattel Aquarius'                       'aquarius'      'Computer/MattelAquarius'                                                )"
  "( 'Computer/MSX1'                                  ''              'Computer/MSX1'                                     msx1_roms            )"
  "( 'Computer/MSX2+'                                 'msx'           'Computer/MSX'                                      msx2p_roms           )"
  "( 'Computer/Next186'                               'next186'       'Computer/Next186'                                  next186_roms         )"
  "( 'Computer/Oric'                                  'oric'          'Computer/Oric'                                     oric_roms            )"
  "( 'Computer/PCXT'                                  'pcxt'          ''                                                  pcxt_roms            )"
  "( 'Computer/PET2001'                               'pet2001'       'Computer/PET2001'                                  pet2001_roms         )"
  "( 'Computer/Robotron Z1013'                        'z1013'         ''                                                                       )"
  "( 'Computer/Sinclair QL'                           'ql'            'Computer/QL'                                       ql_roms              )"
  "( 'Computer/SAM Coupe'                             'samcoupe'      'Computer/SamCoupe'                                 samcoupe_roms        )"
  "( 'Computer/Speccy'                                ''              'Computer/Speccy'                                   speccy_roms          )"
  "( 'Computer/TI99-4A'                               'ti994a'        'Computer/TI994A'                                   ti994a_roms          )"
  "( 'Computer/TSConf'                                'tsconf'        'Computer/TSConf'                                   tsconf_roms          )"
  "( 'Computer/VIC20'                                 'vic20'         'Computer/VIC20'                                    vic20_roms           )"
  "( 'Computer/Videoton TV Computer'                  'tvc'           'Computer/VideotonTVC'                              tvc_roms             )"
  "( 'Computer/X68000'                                ''              'Computer/X68000'                                   x68000_roms          )"
  "( 'Computer/ZX8x'                                  'zx01'          'Computer/ZX8X'                                     zx8x_roms            )"
  "( 'Computer/ZX-Next'                               'zxn'           'Computer/ZXSpectrum_Next'                                               )"
  "( 'Computer/ZX Spectrum'                           'spectrum'      'Computer/ZXSpectrum'                               zx_spectrum_roms     )"
  "( 'Computer/ZX Spectrum 48k'                       ''              'Computer/ZXSpectrum48K_Kyp'                                             )"
 # Consoles
  "( 'Console/Atari 2600'                             'a2600'         'Console/A2600'                                     atari2600_roms       )"
  "( 'Console/Atari 5200'                             'atari5200'     'Console/A5200'                                     atari5200_roms       )"
  "( 'Console/Atari 7800'                             'atari7800'     'Console/A7800'                                     atari7800_roms       )"
  "( 'Console/Astrocade'                              'astrocade'     'Console/Astrocade'                                                      )"
  "( 'Console/ColecoVision'                           'colecovision'  'Console/COLECOVISION'                                                   )"
  "( 'Console/Gameboy'                                'gameboy'       'Console/GAMEBOY'                                   gameboy_roms         )"
  "( 'Console/Genesis MegaDrive'                      'fpgagen'       'Console/GENESIS'                                                        )"
  "( 'Console/Intellivision'                          'intellivision' 'Console/Intellivison'                              intellivision_roms   )"
  "( 'Console/NeoGeo'                                 'neogeo'        'Console/NEOGEO'                                    neogeo_roms          )"
  "( 'Console/Nintendo NES'                           'nes'           'Console/NES'                                       nes_roms             )"
  "( 'Console/Nintendo SNES'                          'snes'          'Console/SNES'                                      snes_roms            )"
  "( 'Console/PC Engine'                              'pcengine'      'Console/PCE'                                       turbogfx_roms        )"
  "( 'Console/SEGA MasterSystem'                      'sms'           'Console/SMS'                                                            )"
  "( 'Console/SEGA Master System Nuked'               'sms-nuked'     'Console/NukedSMS'                                                       )"
  "( 'Console/SONY Playstation'                       ''              'Console/PSX'                                       psx_roms             )"
  "( 'Console/Vectrex'                                ''              'Console/Vectrex'                                   vectrex_roms         )"
  "( 'Console/Videopac'                               'videopac'      'Console/VIDEOPAC'                                  videopac_roms        )"
 # SiDi Arcade: Gehstock
  "( 'Arcade/Gehstock/Atari BW Raster Hardware'       ''              'Arcade/Gehstock/ATARI BW Raster Hardware.rar'                           )"
  "( 'Arcade/Gehstock/Atari Centipede Hardware'       ''              'Arcade/Gehstock/Atari Centipede Hardware.rar'                           )"
  "( 'Arcade/Gehstock/Atari Tetris'                   ''              'Arcade/Gehstock/Atari Tetris.rar'                                       )"
  "( 'Arcade/Gehstock/Bagman Hardware'                ''              'Arcade/Gehstock/Bagman_Hardware.rar'               bagman_roms          )"
  "( 'Arcade/Gehstock/Berzerk Hardware'               ''              'Arcade/Gehstock/Berzerk Hardware.rar'                                   )"
  "( 'Arcade/Gehstock/Bombjack'                       ''              'Arcade/Gehstock/Bombjack.rar'                                           )"
  "( 'Arcade/Gehstock/Crazy Climber Hardware'         ''              'Arcade/Gehstock/Crazy Climber Hardware.rar'                             )"
  "( 'Arcade/Gehstock/Data East Burger Time Hardware' ''              'Arcade/Gehstock/Data East Burger Time Hardware.rar'                     )"
  "( 'Arcade/Gehstock/Galaga Hardware'                ''              'Arcade/Gehstock/Galaga hardware.rar'                                    )"
  "( 'Arcade/Gehstock/Galaxian Hardware'              ''              'Arcade/Gehstock/Galaxian Hardware.rar'                                  )"
  "( 'Arcade/Gehstock/Pacman Hardware'                ''              'Arcade/Gehstock/Pacman_hardware.rar'                                    )"
  "( 'Arcade/Gehstock/Phoenix Hardware'               ''              'Arcade/Gehstock/Phoenix_hardware.rar'                                   )"
  "( 'Arcade/Gehstock/Tetris'                         ''              'Arcade/Gehstock'                                                        )"
 # SiDi Arcade: Jotego fetched directly from Jotego jtbin repository
 #"( 'Arcade/Jotego/jt1942_SiDi.rbf'                  ''              'Arcade/Jotego/1942'                                1942_roms            )"
 #"( 'Arcade/Jotego/jt1943_SiDi.rbf'                  ''              'Arcade/Jotego/1943'                                1943_roms            )"
 #"( 'Arcade/Jotego/jtcommando_SiDi.rbf'              ''              'Arcade/Jotego/Commando'                            commando_roms        )"
 #"( 'Arcade/Jotego/jtgng_SiDi.rbf'                   ''              'Arcade/Jotego/GhostnGoblins'                       ghost_n_goblins_roms )"
 #"( 'Arcade/Jotego/jtgunsmoke_SiDi.rbf'              ''              'Arcade/Jotego/Gunsmoke'                            gunsmoke_roms        )"
 #"( 'Arcade/Jotego/jtvulgus_SiDi.rbf'                ''              'Arcade/Jotego/Vulgus'                              vulgus_roms          )"
 # SiDi Arcade: other
  "( 'Arcade'                                         ''              'Arcade/arcade'                                     sidi128_arcade       )"
  "( 'Arcade/Alpha68k'                                ''              'Arcade/Alpha68k'                                                        )"
  "( 'Arcade/IremM72'                                 ''              'Arcade/IremM72'                                                         )"
  "( 'Arcade/IremM92'                                 ''              'Arcade/IremM92'                                                         )"
  "( 'Arcade/Jotego/TAITO TNZS'                       ''              'Arcade/JTKiwi'                                     tnzs_roms            )"
  "( 'Arcade/Konami Hardware'                         ''              'Arcade/Konami hardware/konami hardware.rar'                             )"
  "( 'Arcade/NeoGeo'                                  ''              'Arcade/Neogeo'                                     neogeo_roms          )"
  "( 'Arcade'                                         ''              'Arcade/Nintendo hardware/Nintendo hardware.rar'    nintendo_sysattr     )"
  "( 'Arcade/Prehisle'                                ''              'Arcade/Prehisle'                                                        )"
)

copy_mist_cores() {
  local dstroot=$1  # $1: destination folder
  local testcore=$2 # $2: optional core for single test

  echo -e "\n----------------------------------------------------------------------" \
          "\nCopy MiST Cores to '$dstroot'" \
          "\n----------------------------------------------------------------------\n"

  local srcroot=$GIT_ROOT/MiST/binaries

  # get MiST binary repository
  clone_or_update_git 'https://github.com/mist-devel/mist-binaries.git' "$srcroot"

  # default ini file (it not exists)
  [ -f "$dstroot/mist.ini" ] || sdcopy "$srcroot/cores/mist.ini" "$dstroot/"

  # Firmware upgrade file
  copy_latest_file "$srcroot/firmware"  "$dstroot/firmware.upg" 'firmware*.upg'

  local saveIFS=$IFS
  IFS=$(echo -en "\n\b")
  local dir line src dst hdl
  if [ "$testcore" == "" ] || [ "$testcore" == "Arcade" ]; then
    # loop over arcade folders in MiST repository
    for dir in $(find "$srcroot/cores/arcade" -maxdepth 1 -mindepth 1 -type d | sort); do
      # support for optional testing of single specific core
      if [ "$testcore" != "" ] && [[ "$dir" == *"$testcore"* ]]; then continue; fi
      # generate destination arcade folders from .mra and .core files
      copy_mra_arcade_cores "$dir" "$dir" "$dstroot/Arcade/MiST/$(basename "$dir")"
    done
  fi

  # loop over other folders in MiST repository
  for dir in $(find "$srcroot/cores" -maxdepth 1 -mindepth 1 -type d -not -name 'arcade' | sort); do
    # check if in our list of cores
    for line in "${cores[@]}"; do
      eval "line=$line"
      dst=${line[0]}
      src=${line[1]}
      hdl=${line[3]}
      if [ "$srcroot/cores/$src" = "$dir" ]; then
        # support for optional testing of single specific core
        if [ "$testcore" != "" ] && [ "$testcore" != "$dst" ]; then continue; fi
        # Info
        echo -e "\n${dir//$GIT_ROOT\//}"
        # copy latest core to destination folder
        if [ "$dst" = "." ]; then
          # copy latest menu core and set hidden attribute to hide this core from menu
          copy_latest_file "$dir" "$dstroot/$dst/core.rbf" '*.rbf'
          set_hidden_attr "$dstroot/$dst/core.rbf"
        else
          # copy latest core to destination folder and set its system attribute to be visible in menu core
          copy_latest_file "$dir" "$dstroot/$dst/$(basename "$dst").rbf" '*.rbf'
          set_system_attr "$dstroot/$dst"
        fi
        # optional rom handling
        if [ ! -z "$hdl" ]; then
          $hdl "$dir" "$dstroot/$dst" "$MISC_FILES/$(basename "$dst")"
        fi
        dir=''
        break
      fi
    done
    if [ ! -z "$dir" ]; then
      echo -e "\e[1;31m\nUnhandled: '$dir'\e[0m"
    fi
  done
  IFS=$saveIFS
}

copy_sidi_cores() {
  local dstroot=$1  # $1: destination folder
  local testcore=$2 # $2: optional core for single test

  # some parameters to be distinguished between SiDi and SiDi128 handling
  local params='', paramSet=(
   #"( 'firmware folder',  'menu core',   'arcade dir', 'core exclude pattern' )"
    "( 'Firmware'          'core.rbf'     'SiDi'        '*sidi128*'            )" # SiDi
    "( 'Firmware_SiDi128'  'sidi128.rbf'  'SiDi128'     ''                     )" # SiDi128
  )
  if [ $SYSTEM == 'sidi' ]; then eval params=${paramSet[0]}; else eval params=${paramSet[1]}; fi

  echo -e "\n----------------------------------------------------------------------" \
          "\nCopy $SYSTEM Cores to '$dstroot'" \
          "\n----------------------------------------------------------------------\n"

  local srcroot=$GIT_ROOT/SiDi/ManuFerHi

  # get SiDi binary repository
  clone_or_update_git 'https://github.com/ManuFerHi/SiDi-FPGA.git' "$srcroot"

  # default ini file (it not exists)
  [ -f "$dstroot/mist.ini" ] || download_url 'https://github.com/mist-devel/mist-binaries/raw/master/cores/mist.ini' "$dstroot/"

  # Firmware upgrade file
  copy_latest_file "$srcroot/${params[0]}" "$dstroot/firmware.upg" 'firmware*.upg'

  # loop over folders in SiDi repository
  local saveIFS=$IFS
  IFS=$(echo -en "\n\b")
  local dir line src dst hdl
  for dir in $(find "$srcroot/Cores" -type d | sort); do
    if [ "$(basename "$dir")" != 'old' ] && [ "$(basename "$dir")" != 'output_files' ]; then
      if [ -n "$(find "$dir" -maxdepth 1 -iname '*.rbf' 2>/dev/null)" ]; then
        # check if in our list of cores
        for line in "${cores[@]}"; do
          eval "line=$line"
          dst=${line[0]}
          src=${line[2]/'Arcade/'/"Arcade/${params[2]}/"}
          hdl=${line[3]}
          if [ "$srcroot/Cores/$src" = "$dir" ]; then
            # support for optional testing of single specific core
            if [ "$testcore" != "" ] && [ "$testcore" != "$dst" ]; then continue; fi
            # Info
            echo -e "\n${dir//$GIT_ROOT\//}"
            if [ "$dst" = "." ]; then
              # copy latest menu core and set hidden attribute to hide this core from menu
              copy_latest_file "$dir" "$dstroot/$dst/${params[1]}" "*$SYSTEM*.rbf" "${params[3]}"
              set_hidden_attr "$dstroot/$dst/${params[1]}"
            else
              # copy latest core to destination folder and set its system attribute to be visible in menu core
              copy_latest_file "$dir" "$dstroot/$dst/$(basename "$dst").rbf" "*$SYSTEM*.rbf" "${params[3]}"
              set_system_attr "$dstroot/$dst"
            fi
            # optional rom handling
            if [ ! -z "$hdl" ]; then
              $hdl "$dir" "$dstroot/$dst" "$MISC_FILES/$(basename "$dst")"
            fi
            dir=''
            break
          fi
        done
      fi
      if [ -n "$(find "$dir" -maxdepth 1 -iname '*.rar' 2>/dev/null)" ]; then
        for rar in $(find "$dir" -iname '*.rar' | sort); do
          # check if in our list of cores
          for line in "${cores[@]}"; do
            eval "line=$line"
            dst=${line[0]}
            src=${line[2]/'Arcade/'/"Arcade/${params[2]}/"}
            hdl=${line[3]}
            if [ "$srcroot/Cores/$src" = "$rar" ]; then
              # support for optional testing of single specific core
              if [ "$testcore" != "" ] && [ "$testcore" != "$dst" ]; then continue; fi
              # Info
              echo -e "\n${rar//$GIT_ROOT\//} ..."
              # uncompress to destination folder
              echo "  Uncompressing $src ..."
              expand "$rar" "$dstroot/$dst"
              # optional rom handling
              if [ ! -z "$hdl" ]; then
                $hdl "$dir" "$dstroot/$dst" "$MISC_FILES/$(basename "$dst")"
              fi
              # set system attribute for this subfolder to be visible in menu core
              set_system_attr "$dstroot/$dst"
              dir=''
              break
            fi
          done
        done
      fi

      if [ ! -z $dir ]; then
        if ([ ! -z "$(find "$dir" -maxdepth 1 -iname '*.rbf' 2>/dev/null)" ] || [ ! -z "$(find "$dir" -maxdepth 1 -iname '*.rar' 2>/dev/null)" ]); then
          echo -e "\e[1;31m\nUnhandled: \"$dir\"\e[0m"
        fi
      fi
    fi
  done
  IFS=$saveIFS
}


check_sd_filesystem() {
  local dstroot=$1 # $1: destination folder

  # check filesystem of SD folder (only vfat and msdos supported by fatattr (exfat with root privileges))
  # local fs=$(stat -f -c %T "$dstroot")
  local fs=$(df --output="fstype" "$dstroot" | tail -1)
  echo -e "\nFilesystem type of destination '$SD_ROOT' is '$fs'."
  case "$fs" in
    msdos | vfat)
      # on FAT/FAT32 volumes we are fine
      true;;
    exfat)
      if [ "$(id -u)" -eq 0 ]; then
        true # already running as root - we are fine for exFAT
      else
        echo -e "root privileges required to set DOS filesystem attributes on exFAT destination file system.\n"
        while : ; do
          echo -n "[sudo] Passwort für $USER: "
          read -s SUDO_PW && echo ""
          if echo "$SUDO_PW" | sudo -k -S true &>/dev/null; then
            break
          fi
          echo -e "\e[1;31mERROR: Invalid sudo password! Please retry\e[0m\n"
        done
      fi;;
    *)
      echo -e "\nUnsupported file system." \
              "\nContinue anyway (no support for DOS filesystem attributes) ?"
      PS3='Pick an option:'
      select opt in 'y' 'n'; do
        case "$REPLY" in
          'y'|'Y') break;;
          'n'|'N') exit 1;;
          *)       continue;;
        esac
      done
  esac
}


show_usage() {
  echo -e "\nUsage: $0 [-s <mist|sidi|sidi128>] [-d <destination SD drive or folder>] [-h]" \
          "\nGenerate SD card content with Jotego cores/roms for specific FPGA platform." \
          "\n" \
          "\nOptional arguments:" \
          "\n -s <mist|sidi>" \
          "\n    Set target system (mist, sidi or sidi128)." \
          "\n    This parameter is mandatory!" \
          "\n -d <destination SD (drive) folder>" \
          "\n    Location where the target files should be generated." \
          "\n    If this option isn't specified, 'SD\<system>' will be used." \
          "\n -h" \
          "\n    Show this help text\n"
}


# Parse commandline options
while getopts ':hs:d:' option; do
  case $option in
    d)  SD_ROOT=$OPTARG;;
    s)  SYSTEM=${OPTARG,,}
        if [ $SYSTEM != 'mist' ] && [ $SYSTEM != 'sidi' ] && [ $SYSTEM != 'sidi128' ]; then
          echo -e "\n\e[1;31mInvalid target \"$SYSTEM\"!\e[0m"
          show_usage; exit 1
        fi;;
    h)  show_usage; exit 0;;
    \?) echo -e "\n\e[1;31mERROR: Invalid option \"$option\"\e[0m"
        show_usage; exit 1;;
  esac
done
if [ -z "$SYSTEM" ];  then show_usage; exit 1; fi
if [ -z "$SD_ROOT" ]; then SD_ROOT=$(dirname "${BASH_SOURCE[0]}")/SD/$SYSTEM; fi

echo -e "\n----------------------------------------------------------------------"
echo -e "Generating SD content for '$SYSTEM' to '$SD_ROOT'"
echo -e "----------------------------------------------------------------------\n"

echo -e "Creating destination folder '$SD_ROOT'..."
makedir "$SD_ROOT"

# check filesystem of SD folder
check_sd_filesystem "$SD_ROOT"
# check required helper tools
check_dependencies

# testing specfic cores
# download_url 'https://raw.githubusercontent.com/Gehstock/Mist_FPGA_Cores/master/Arcade_MiST/Konami Scramble Hardware/calipso.mra' '/tmp/'
# download_url 'https://raw.githubusercontent.com/Gehstock/Mist_FPGA_Cores/master/Arcade_MiST/Namco Galaxian Hardware/Z80 Based/Devil Fish.mra' '/tmp/'
# download_url 'https://raw.githubusercontent.com/Gehstock/Mist_FPGA_Cores/master/Arcade_MiST/Konami Scramble Hardware/Scramble.rbf' '/tmp/'
# process_mra '/tmp/calipso.mra' . '/tmp'
# process_mra '/tmp/Devil Fish.mra' . '/tmp'
# download_url 'https://github.com/Gehstock/Mist_FPGA_Cores/raw/refs/heads/master/Arcade_MiST/Konami Timepilot Hardware/Time Pilot.mra' '/tmp/'
# download_url 'https://github.com/Gehstock/Mist_FPGA_Cores/raw/refs/heads/master/Arcade_MiST/Konami Timepilot Hardware/time_pilot_mist.rbf' '/tmp/'
# download_url 'https://github.com/mist-devel/mist-binaries/raw/refs/heads/master/cores/arcade/Konami Timepilot Hardware/Time Pilot.mra' '/tmp/'
# download_url 'https://github.com/mist-devel/mist-binaries/raw/refs/heads/master/cores/arcade/Konami Timepilot Hardware/TimePlt.rbf' '/tmp/'
# process_mra '/tmp/Time Pilot.mra' . '/tmp'
# copy_mist_cores $SD_ROOT 'Console/Videopac'
# copy_mist_cores $SD_ROOT 'Computer/Mattel Aquarius'
# copy_mist_cores $SD_ROOT 'Arcade/NeoGeo'
# copy_mist_cores $SD_ROOT 'Computer/Oric'
# copy_sidi_cores $SD_ROOT '.'
# copy_sidi_cores $SD_ROOT 'Console/Videopac'
# copy_sidi_cores $SD_ROOT 'Arcade/Jotego/TAITO TNZS'
# copy_sidi_cores $SD_ROOT 'Arcade'
# copy_sorgelig_mist_cores "$SD_ROOT"
# exit 0

# start generating
if [ $SYSTEM = 'sidi' ] || [ $SYSTEM = 'sidi128' ]; then
  copy_sidi_cores "$SD_ROOT"
  copy_eubrunosilva_sidi_cores "$SD_ROOT"
elif [ $SYSTEM = 'mist' ]; then
  copy_mist_cores "$SD_ROOT"
  copy_sorgelig_mist_cores "$SD_ROOT"
  copy_gehstock_mist_cores "$SD_ROOT"
  copy_sebdel_mist_cores "$SD_ROOT"
  copy_joco_mist_cores "$SD_ROOT"
fi
copy_jotego_arcade_cores "$SD_ROOT/Arcade/Jotego"

echo -e '\ndone.'
