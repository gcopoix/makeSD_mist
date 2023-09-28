#!/bin/bash

# -- make_SiDi_SD.sh
#    Generates or updates the folder structure for using in SiDi or MiST FPGA system.
#    Picked cores:
#    SiDi repository (http://github.com/ManuFerHi/SiDi-FPGA.git)
#    MiST repository (http://github.com/mist-devel/mist-binaries.git)
#    Marcel Gehstock MiST repository (http://github.com/Gehstock/Mist_FPGA_Cores.git)
#    Jose Tejada (jotego) MiST/SiDi Arcade repository (http://github.com/jotego/jtbin.git)
#    Alexey Melnikov (sorgelig) repositories (http://github.com/sorgelig/<...>.git)
#    eubrunosilva SiDi repositoriy (http://github.com/eubrunosilva/SiDi.git)
#    Additionally the required MAME ROMs are fetched too to generate a working SD card.

#    SiDi wiki: http://github.com/ManuFerHi/SiDi-FPGA.git
#    MiST wiki: http://github.com/mist-devel/mist-board/wiki

# other update scripts:
#    http://gist.github.com/squidrpi/4ce3ea61cbbfa3900e116f9565d45e74
#    http://github.com/theypsilon/Update_All_MiSTer

# MiSTer BIOS pack (sub-archives can be downloaded directly too)
#    http://archive.org/download/mister-console-bios-pack_theypsilon/MiSTer_Console_BIOS_PACK.zip


# cache folde for repositories and MAME ROMs
GIT_ROOT=$(dirname "${BASH_SOURCE[0]}")/repos
TOOLS_ROOT=$(dirname "${BASH_SOURCE[0]}")/tools
MAME_ROMS=$(dirname "${BASH_SOURCE[0]}")/repos/mame


check_dependencies() {
  # get necessary helper tools (unzip, unrar, grep, git)
  if ! which unzip   1>/dev/null; then sudo apt install -y unzip;   fi
  if ! which unrar   1>/dev/null; then sudo apt install -y unrar;   fi
  if ! which 7z      1>/dev/null; then sudo apt install -y 7z;      fi
  if ! which grep    1>/dev/null; then sudo apt install -y grep;    fi
  if ! which fatattr 1>/dev/null; then sudo apt install -y fatattr; fi
  if ! which git     1>/dev/null; then sudo apt install -y git;     fi
  if [ ! -x "$TOOLS_ROOT/mra" ]; then
    #download_url 'http://github.com/sebdel/mra-tools-c/raw/master/release/linux/mra' "$TOOLS_ROOT/"
    #download_url 'http://github.com/mist-devel/mra-tools-c/raw/master/release/linux/mra' "$TOOLS_ROOT/"
    download_url 'http://github.com/gcopoix/mra-tools-c/raw/fix/windows_crash/release/linux/mra' "$TOOLS_ROOT/"
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
  # see http://stackoverflow.com/questions/21735435/git-clone-changes-file-modification-time for details
  local unixtime touchtime
  git -C "$dstpath/" ls-tree -r --name-only HEAD | while read f; do
    echo -e -n "\rsychronizing timestamps: \e[0K$f"
    unixtime=$(git -C "$dstpath/" log -1 --format="%at" -- "$f" 2>/dev/null)
    touchtime=$(date -d @$unixtime +'%Y%m%d%H%M.%S')
    touch -t $touchtime "$dstpath/$f" 2>/dev/null
  done
  echo
}


set_system_attr() {
  local p=$1 # $1: path to file/directory
  while [ "$p" != "$SD_ROOT" ]; do
    fatattr +s "$p" 2>/dev/null
    p=$(dirname "$p")
  done
}

set_hidden_attr() {
  # $1: path to file

  fatattr +h "$1" 2>/dev/null
}

copy() {
  local src=$1 # $1: src file(s)
  local dst=$2 # $2: destination file | directory (will be created if it doesn't exist)

  if [ -f "$src" ]; then
    # create destination folder if it doesn't exist
    if [ "${dst: -1}" == "/" ] && [ ! -d "$dst" ]; then
      mkdir -p "$dst"
    else
      parent=$(dirname "$dst")
      mkdir -p "$(dirname "$dst")"
    fi
    # copy/update if source file is newer
    cp -pu "$src" "$dst"
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
    if [ ! -d "$dstpath" ]; then
      mkdir -p "$dstpath"
    fi

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
  if [ "${dst: -1}" == '/' ] && [ ! -d "$dst" ]; then
    mkdir -p "$dst"
  fi
  if [ -d "$dst" ]; then
    local opt=-qNP
    local dstfile=$(realpath "$dst")/$(basename $url)
  else
    local opt=-qNO
    local dstfile=$dst
  fi
  # skip download if file exists
  if [ -f "$dstfile" ]; then
    echo ' exists.'
  else
    # download file
    if wget --content-disposition $opt "$dst" "$url"; then
      echo ' done.'
    else
      echo -e "\e[1;31m failed.\e[0m"
      return $(false)
    fi
  fi
  return $(true)
}


copy_latest_core() {
  local srcdir=$1  # $1: source directory
  local dstfile=$2 # $2: destination rbf file
  local pattern=$3 # $3: optional name pattern

  echo "  '${srcdir//$GIT_ROOT\//}' -> '${dstfile//$(dirname "${BASH_SOURCE[0]}")\//}'"
  shopt -s nocaseglob
  local rbf=$(ls -t "$srcdir/"*$pattern*.rbf 2>/dev/null | head -1)
  if [ -z $rbf ]; then rbf=$(ls -t "$srcdir/"*.rbf | head -1); fi
  shopt -u nocaseglob
  copy "$rbf" "$dstfile"
}


download_mame_roms() {
  local dstroot=$1      # $1: destination directory
  local zips=("${@:2}") # $2 array with zip archive name(s), e.g. ("single.zip") or ("file1.zip" "file2.zip")

  # list of download sites for required MAME roms - will be used top first
  local mameurls=(
    'http://archive.org/download/mame-0.221-roms-merged'
    'http://downloads.retrostic.com/roms'
    'http://bda.retroroms.info/downloads/mame/currentroms'
    'https://ia801800.us.archive.org/view_archive.php?archive=/14/items/2020_01_06_fbn/roms/arcade.zip&file=arcade'
   #'http://archive.org/download/mame0.224'
   #'http://archive.org/download/mame.0229'
   #'http://archive.org/download/MAME220RomsOnlyMerged' #no benefit over 224
   #'http://archive.org/download/hbmame0220' ------
   #'http://archive.org/download/MAME224RomsOnlyMerged'
   #'http://archive.org/download/mame-merged/mame-merged'
   #'http://archive.org/download/mame-0.236-roms-split/MAME 0.236 ROMs (split)'
   #'http://archive.org/download/mame-0.240-roms-split_202201/MAME 0.240 ROMs (split)'
   #'http://archive.org/download/MAME220RomsOnlyMerged' #no benefit over 224
   #'http://archive.org/download/MAME216RomsOnlyMerged' #no benefit over 224
   #'http://archive.org/download/MAME223RomsOnlyMerged'
   #'http://archive.org/download/MAME214RomsOnlyMerged'
   #'http://archive.org/download/MAME215RomsOnlyMerged'
   #'http://archive.org/download/MAME216RomsOnlyMerged'
   #'http://archive.org/download/MAME221RomsOnlyMerged'
   #'http://archive.org/download/MAME222RomsOnlyMerged'
   #'http://archive.org/download/MAME223RomsOnlyMerged'
   #'http://archive.org/download/mame-merged/mame-merged'
   #'http://archive.org/download/mame-0.236-roms-split/MAME 0.236 ROMs (split)'
   #'http://downloads.gamulator.com/roms'
  )
  # list of ROMs not downloadable from URLs above, having special download URLs
  local romlookup=(
   #"( 'combatsc.zip'       'http://downloads.retrostic.com/roms/combatsc.zip'                          )" #bad md5
    "( 'clubpacm.zip'       'http://downloads.retrostic.com/roms/clubpacm.zip'                          )" #bad md5
    "( 'devilfsg.zip'       'http://od.serverboi.org/Megaromserver/Roms/mame-libretro/devilfsg.zip'     )" #ok
    "( 'gallop.zip'         'http://od.serverboi.org/Megaromserver/Roms/mame-libretro/gallop.zip'       )" #ok
    "( 'journey.zip'        'http://archive.org/download/MAME216RomsOnlyMerged/journey.zip'             )" #bad MD5
   #"( 'mooncrst.zip'       'http://archive.org/download/MAME216RomsOnlyMerged/mooncrst.zip'            )"
    "( 'mooncrst.zip'       'http://archive.org/download/MAME216RomsOnlyMerged/mooncrst.zip'            )" # ok
    "( 's16mcu_alt.zip'     'http://misterfpga.org/download/file.php?id=3319'                           )" #ok
    "( 'sinistar.zip'       'http://downloads.gamulator.com/roms/sinistar.zip'                          )" #ok
   #"( 'wbml.zip'           'http://archive.org/download/MAME224RomsOnlyMerged/wbml.zip'                )" #bad MD5
   #"( 'wbml.zip'           'http://downloads.retrostic.com/roms/wbml.zip'                              )" #missing files
   #"( 'wbml.zip'           'http://ia801803.us.archive.org/9/items/mame.0229/wbml.zip'                 )" #bad md5
   #"( 'xevious.zip'        'http://downloads.retrostic.com/roms/xevious.zip'                           )" #bad md5
   #"( 'xevious.zip'        'htts://ia802803.us.archive.org/35/items/MAME216RomsOnlyMerged/xevious.zip' )" #can't download
    "( 'zaxxon_samples.zip' 'http://www.arcadeathome.com/samples/zaxxon.zip'                            )" #ok
    "( 'jtbeta.zip'         'https://ia804503.us.archive.org/1/items/jtkeybeta/beta.zip'                )" #http://twitter.com/jtkeygetterscr1/status/1403441761721012224?s=20&t=xvNJtLeBsEOr5rsDHRMZyw
  )

  if [ ! -z "$zips" ]; then
    # download zips from list
    local zip rlu baseurl
    for zip in "${zips[@]}"; do
      # 1st: fetch from special urls if found in lookup table
      for rlu in "${romlookup[@]}"; do
        eval "local rlu=$rlu"
        if [ "${rlu[0]}" = "$zip" ]; then
          if download_url "${rlu[1]}" "$dstroot/$zip"; then
            rlu=''
          fi
          break
        fi
      done

      if [ ! -z "$rlu" ]; then
        # 2nd: fetch required rom sets from common base URLs starting with first URL in list
        for url in "${mameurls[@]}"; do
          if download_url "$url/$zip" "$dstroot/"; then
            break
          fi
        done
      fi
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
  arcname=${arcname//[\/?:]/'_'}
  local setname=$(grep -oP '(?<=<setname>)[^<]+' "$mrafile")
  if [ -z "$setname" ]; then
    setname=$name
    # replace special characters (like rom filename rename of mra tool))
    setname=${setname//[ ()?:]/'_'}
  fi
  local MAX_ROM_FILENAME_SIZE=16
  # trim setname if longer than 8 characters (take 1st 5 characters and last 3 characters (like rom filename trim of mra tool))
  if [ ${#setname} -gt $MAX_ROM_FILENAME_SIZE ]; then
    setname=${setname::$((MAX_ROM_FILENAME_SIZE-3))}${setname: -3}
  fi

  # genrate .rom and.arc files
  echo "  '$name.mra': generating '$setname.rom' and '$name.arc'"
  "$TOOLS_ROOT/mra" -A -O "$dstpath" -z "$MAME_ROMS" "$mrafile"

  # give .rom and.arc files same timestamp as .mra file
  if [ -f "$dstpath/$setname.rom" ]; then
    touch -r "$mrafile" "$dstpath/$setname.rom"
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
  # some name beautification (replace/drop special characters and double spaces)
  name=${name//[\/]/'-'}; name=${name//[\"?:]/}; name=${name//'  '/' '}
  # try to fetch .rbf name: 1st: from <rbf> info, 2nd: from alternative <rbf> info, 3rd: from <name> info (without spaces)
  local rbf=$(grep -oP '(?<=<rbf>)[^<]+' "$mrafile")
  if [ -z "$rbf" ]; then rbf=$(grep -oP '(?<=<rbf alt=)[^>]+' "$mrafile"); fi
  # drop quote characters and make rbf destination filename lowercase
  rbf="${rbf//[\'\"]/}"; rbf=${rbf,,}
  if [ -z "$rbf" ]; then rbf=${name//' '/}; fi
  # grep list of zip files: 1st: encapsulated in ", 2nd: encapsulated in '
  local zips=$(grep -oP '(?<=zip=")[^"]+' "$mrafile")
  if [ -z "$zips" ]; then zips=$(grep -oP "(?<=zip=')[^']+" "$mrafile"); fi
  eval "zips=(${zips//|/ })"

  echo -e "\n${mrafile//"$GIT_ROOT/"} ($name, $rbf, ${zips[@]}):"

  # prepare target .mra, .rbf, -zip's and .rom/.arc in destination folder
  if [ ! -f "$dstpath/$name.arc" ] || [ ! -f "$dstpath/$rbf.rbf" ]; then
    # create target folder and set system attribute for this subfolder to be visible in menu core
    mkdir -p "$dstpath"
    set_system_attr "$dstpath"
    if [ "$(dirname "$mrafile")" != '/tmp' ]; then
      copy "$mrafile" "/tmp/$name.mra"
    fi
    if [ ! -z "$rbfpath" ]; then
      rbfpath=${rbfpath//'/InWork'/}; rbfpath=${rbfpath//'/meta'/}
      local srcrbf=$rbf
      # lookup non-matching filenames <-> .rbf name references in .mra file
      for rlu in "${rbflookup[@]}"; do
        eval "local rlu=$rlu"
        if [ "${rlu[0]}" = "$name" ]; then
          srcrbf=${rlu[1]}
          break
        fi
      done
      # make source file case insensitive
      srcrbf=$(find "$rbfpath/" -maxdepth 1 -iname "$srcrbf.rbf")

      # copy .rbf file to destination folder and hide from menu (as .arc file will show up)
      if [ -f "$srcrbf" ]; then
        copy "$srcrbf" "$dstpath/$rbf.rbf"
        set_hidden_attr "$dstpath/$rbf.rbf"
      else
        echo -e "\e[1;31m  ERROR: \"$rbfpath/$rbf.rbf\" not found\e[0m"
        rm -d "$dstpath"
        return $(false)
      fi
    fi
    # download rom zip archive(s)
    download_mame_roms "$MAME_ROMS" "${zips[@]}"
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
    if [ ! -z "$lut" ]; then
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
  local fpga=$1    # $1: target system ("mist", "sidi" of "mister")
  local dstroot=$2 # $2: target folder

  echo -e "\n----------------------------------------------------------------------"
  echo -e "Copy Jotego Cores for '$fpga' to '$dstroot'"
  echo -e "----------------------------------------------------------------------\n"

  # some lookup to sort games into sub folder (if they don't support the <platform> tag)
  local jtlookup=(
    "( 'CAPCOM'    'jt1942' 'jt1943' 'jtbiocom' 'jtbtiger' 'jtcommnd' 'jtexed'   'jtf1drm'  'jtgunsmk' 'jthige'
                   'jtpang' 'jtrumble' 'jtsarms'  'jtsf'     'jtsectnz' 'jttrojan' 'jttora'   'jtvulgus' )"
    "( 'CPS-2'     'jtcps2'  )"
    "( 'CPS-15'    'jtcps15' )"
    "( 'CPS-1'     'jtcps1'  )"
    "( 'SEGA S16A' 'jts16'   )"
    "( 'SEGA S16B' 'jts16b'  )"
  )

  # get jotego git
  local srcpath=$GIT_ROOT/jotego
  clone_or_update_git 'http://github.com/jotego/jtbin.git' "$srcpath"

  # ini file from jotego git
  #copy "$srcpath/arc/mist.ini" "$dstroot/"

  # generate destination arcade folders from .mra and .core files
  local saveIFS=$IFS
  IFS=$(echo -en "\n\b")
  local dir
  for dir in $(find "$srcpath/mra" -type d | sort); do
    copy_mra_arcade_cores "$dir" "$srcpath/$fpga" "$dstroot" "${jtlookup[@]}"
  done
  IFS=$saveIFS
}


copy_gehstock_mist_cores() {
  local dstroot=$1 # $1: target folder

  echo -e "\n----------------------------------------------------------------------"
  echo -e "Copy Gehstock Cores for 'mist' to '$dstroot'"
  echo -e "----------------------------------------------------------------------\n"

  # get Gehstock git
  local srcroot="$GIT_ROOT/MiST/gehstock"
  clone_or_update_git 'http://github.com/Gehstock/Mist_FPGA_Cores.git' "$srcroot"

  # find all cores
  local saveIFS=$IFS
  IFS=$(echo -en "\n\b")
  local rbf dir dst name
  for rbf in $(find "$srcroot" -iname '*.rbf' | sort); do
    dir=$(dirname "$rbf")
    shopt -s nocasematch
    dst=${dir//$srcroot/$dstroot}; dst=${dst//'_MiST'/}; dst=${dst//'/Arcade/'/'/Arcade/Gehstock/'}
    shopt -u nocasematch
    if [ ! -z "$(find "$dir" -maxdepth 1 -iname '*.mra')" ]; then
      # .mra file(s) in same folder as .rbf file
      copy_mra_arcade_cores "$dir" "$dir" "$dst"
    elif [ ! -z "$(find "$dir/meta" -maxdepth 1 -iname '*.mra' 2>/dev/null)" ]; then
      # .mra file(s) in meta subfolder
      copy_mra_arcade_cores "$dir/meta" "$dir" "$dst"
    else
      # 'normal' .rbf-only core (remove '_MIST' from file name)
      shopt -s nocasematch
      name=$(basename "$rbf"); name=${name//'_MiST'/}; name=${name//'_mist'/}
      shopt -u nocasematch
      echo -e "\n$rbf:"
      copy "$rbf" "$dst/$name"
      if [ ! -z "$(find "$dir" -iname '*.rom')" ]; then
        cp -pu $(find "$dir" -iname '*.rom') "$dst/"
      fi
    fi
  done
  IFS=$saveIFS
}


copy_sorgelig_mist_cores() {
  local dstroot=$1 # $1: target folder

  echo -e "\n----------------------------------------------------------------------"
  echo -e "Copy Sorgelig Cores for 'mist' to '$dstroot'"
  echo -e "----------------------------------------------------------------------\n"

  # additional cores from Alexey Melnikov's (sorgelig) repositories
  local cores=(
   #"( 'dst folder'                    'git url'                                   'core release folder' opt_romcoppy_fn  )"
    "( 'Arcade/Sorgelig/Apogee'        'http://github.com/sorgelig/Apogee_MIST.git'           'release'  apogee_roms      )"
    "( 'Arcade/Sorgelig/Galaga'        'http://github.com/sorgelig/Galaga_MIST.git'           'releases'                  )"
    "( 'Computer/Vector-06'            'http://github.com/sorgelig/Vector06_MIST.git'         'releases'                  )"
    "( 'Computer/Specialist'           'http://github.com/sorgelig/Specialist_MIST.git'       'release'                   )"
    "( 'Computer/Phoenix'              'http://github.com/sorgelig/Phoenix_MIST.git'          'releases'                  )"
    "( 'Computer/BK0011M'              'http://github.com/sorgelig/BK0011M_MIST.git'          'releases'                  )"
    "( 'Computer/Laser 500'            'http://github.com/nippur72/Laser500_MiST.git'         'releases' laser500_roms    )"
    "( 'Computer/LM80C Color Computer' 'http://github.com/nippur72/LM80C_MiST.git'            'releases' lm80c_roms       )"
    "( 'Computer/Ondra SPO 186'        'http://github.com/PetrM1/OndraSPO186_MiST.git'        'releases' ondra_roms       )"
   # other Sorgelig repos are already part of MiST binaries repo
   #"( 'Computer/ZX Spectrum 128k'     'http://github.com/sorgelig/ZX_Spectrum-128K_MIST.git' 'releases' zx_spectrum_roms )"
   #"( 'Computer/Amstrad CPC 6128'     'http://github.com/sorgelig/Amstrad_MiST.git'          'releases' amstrad_roms     )"
   #"( 'Computer/C64'                  'http://github.com/sorgelig/C64_MIST.git'              'releases' c64_roms         )"
   #"( 'Computer/PET2001'              'http://github.com/sorgelig/PET2001_MIST.git'          'releases' pet2001_roms     )"
   #"( 'Console/NES'                   'http://github.com/sorgelig/NES_MIST.git'              'releases' nes_roms         )"
   #"( 'Computer/SAM Coupe'            'http://github.com/sorgelig/SAMCoupe_MIST.git'         'releases' samcoupe_roms    )"
   #"( '.'                             'http://github.com/sorgelig/Menu_MIST.git'             'release'                   )"
  )
  local srcroot=$GIT_ROOT/MiST/sorgelig
  local item name
  for item in "${cores[@]}"; do
    eval "item=$item"
    name=$(basename ${item[1]::-9})
    clone_or_update_git ${item[1]} "$srcroot/$name"
    copy_latest_core "$srcroot/$name/${item[2]}" "$dstroot/${item[0]}/$(basename "${item[0]}").rbf"
    # optional rom handling
    if [ ! -z "${item[3]}" ]; then
      ${item[3]} "$srcroot/$name/${item[2]}" "$dstroot/${item[0]}"
    fi
  done
}


copy_other_mist_cores() {
  local dstroot=$1 # $1: target folder

  # MiST Primo from http://joco.homeserver.hu/fpga/mist_primo_en.html
  download_url 'http://joco.homeserver.hu/fpga/download/primo.rbf'       "$dstroot/Computer/Primo/"
  download_url 'http://joco.homeserver.hu/fpga/download/primo.rom'       "$dstroot/Computer/Primo/"
  download_url 'http://joco.homeserver.hu/fpga/download/pmf/astro.pmf'   "$dstroot/Computer/Primo/"
  download_url 'http://joco.homeserver.hu/fpga/download/pmf/astrob.pmf'  "$dstroot/Computer/Primo/"
  download_url 'http://joco.homeserver.hu/fpga/download/pmf/galaxy.pmf'  "$dstroot/Computer/Primo/"
  download_url 'http://joco.homeserver.hu/fpga/download/pmf/invazio.pmf' "$dstroot/Computer/Primo/"
  download_url 'http://joco.homeserver.hu/fpga/download/pmf/jetpac.pmf'  "$dstroot/Computer/Primo/"
}


copy_eubrunosilva_sidi_cores() {
  local dstroot=$1 # $1: target folder

  echo -e "\n----------------------------------------------------------------------"
  echo -e "Copy eubrunosilva Cores for 'sidi' to '$dstroot'"
  echo -e "----------------------------------------------------------------------\n"

  # get eubrunosilva git
  local srcpath=$GIT_ROOT/SiDi/eubrunosilva
  clone_or_update_git 'http://github.com/eubrunosilva/SiDi.git' "$srcpath"

  # generate destination arcade folders from .mra and .core files
  copy_mra_arcade_cores "$srcpath/Arcade" "$srcpath/Arcade" "$dstroot/Arcade/eubrunosilva"

  # additional Computer cores from eubrunosilva repos (which aren't in ManuFerHi's repo)
  local comp_cores=(
   #"( 'dst folder'                       'pattern'       opt_rom_copy_fn )"
    "( 'Computer/HT1080Z School Computer' 'trs80'         ht1080z_roms    )"
    "( 'Computer/BK0011M'                 'BK0011M'                       )"
    "( 'Computer/Chip-8'                  'Chip8'                         )"
    "( 'Computer/Microcomputer'           'Microcomputer'                 )"
    "( 'Computer/Specialist'              'Specialist'                    )"
    "( 'Computer/Vector-06'               'Vector06'                      )"
   # other eubrunosilva cores are already part of SiDi binaries repo
   #"( 'Computer/Amstrad'                 'Amstrad'       amstrad_roms    )"
   #"( 'Computer/BBC Micro'               'bbc'           bbc_roms        )"
   #"( 'Computer/Oric'                    'Oric'          oric_roms       )"
   #"( 'Computer/SAM Coupe'               'SAMCoupe'      samcoupe_roms   )"
   #"( 'Computer/Apoge'                   'Apoge'         apogee_roms     )"
   #"( 'Computer/PET2001'                 'Pet2001'       pet2001_roms    )"
   #"( 'Computer/VIC20'                   'VIC20'         vic20_roms      )"
   #"( 'Computer/Mattel Aquarius'         'Aquarius'                      )"
   #"( 'Computer/C16'                     'c16'           c16_roms        )"
   #"( 'Computer/Atari STe'               'Mistery'       atarist_roms    )"
   #"( 'Computer/Apple Macintosh'         'plusToo'       plus_too_roms   )"
   #"( 'Computer/ZX Spectrum 128k'        'Spectrum128k'                  )"
   #"( 'Computer/ZX8x'                    'ZX8x'          zx8x_roms       )"
   #"( 'Computer/Archimedes'              'Archie'        archimedes_roms )"
   #"( 'Computer/C64'                     'c64'           c64_roms        )"
   #"( 'Computer/MSX1'                    'MSX'           msx1_roms       )"
   #"( 'Computer/Sinclair QL'             'QL'            ql_roms         )"
  )

  local item
  for item in "${comp_cores[@]}"; do
    eval "item=$item"
    copy_latest_core "$srcpath/Computer" "$dstroot/${item[0]}/$(basename "${item[0]}").rbf" "${item[1]}"
    # optional rom handling
    if [ ! -z "${item[2]}" ]; then
      ${item[2]} "$srcpath/Computer" "$dstroot/${item[0]}"
    fi
  done
}


# handlers for core specific ROM actions. $1=core src directory, $2=sd core dst directory
amiga_roms()           { copy "$1/AROS.ROM" "$2/kick/aros.rom"
                         copy "$1/HRTMON.ROM" "$SD_ROOT/hrtmon.rom"
                         copy "$1/MinimigUtils.adf" "$2/adf/"
                         expand "$1/minimig_boot_art.zip" "$SD_ROOT/"
                         download_url 'http://fsck.technology/software/Commodore/Amiga/Kickstart ROMs/Kickstart 3.1/Kickstart v3.1 rev 40.63 (1993)(Commodore)(A500-A600-A2000).rom' "$2/kick/"
                         download_url 'http://fsck.technology/software/Commodore/Amiga/Kickstart ROMs/Kickstart 3.1/Kickstart v3.1 rev 40.70 (1993)(Commodore)(A4000).rom' "$2/kick/"
                         download_url 'http://fsck.technology/software/Commodore/Amiga/Kickstart ROMs/Kickstart 3.1/Kickstart v3.1 rev 40.68 (1993)(Commodore)(A1200).rom' "$2/kick/"
                         copy "$2/kick/Kickstart v3.1 rev 40.68 (1993)(Commodore)(A1200).rom" "$SD_ROOT/kick.rom"
                         download_url 'http://fsck.technology/software/Commodore/Amiga/Workbench and AmigaOS/Amiga Workbench 3.1/Commodore/Workbench v3.1 rev 40.42 (1994)(Commodore)(M10)(Disk 1 of 6)(Install)[!].adf' "$2/adf/"
                         download_url 'http://fsck.technology/software/Commodore/Amiga/Workbench and AmigaOS/Amiga Workbench 3.1/Commodore/Workbench v3.1 rev 40.42 (1994)(Commodore)(M10)(Disk 2 of 6)(Workbench)[!].adf' "$2/adf/"
                         download_url 'http://download.freeroms.com/amiga_roms/t/turrican.zip' "$2/adf/"
                         download_url 'http://download.freeroms.com/amiga_roms/t/turrican2.zip' "$2/adf/"
                         download_url 'http://download.freeroms.com/amiga_roms/t/turrican3.zip' "$2/adf/"
                         download_url 'http://download.freeroms.com/amiga_roms/a/agony.zip' "$2/adf/"
                         expand "$2/adf/turrican.zip" "$2/adf/"
                         expand "$2/adf/turrican2.zip" "$2/adf/"
                         expand "$2/adf/turrican3.zip" "$2/adf/"
                         expand "$2/adf/agony.zip" "$2/adf/"
                       }
amstrad_roms()         { if [ $SYSTEM == 'mist' ]; then cp -pu "$1/ROMs/"*.e* "$SD_ROOT/"; else cp -pu "$1/amstrad.rom" "$SD_ROOT/"; fi
                         download_url 'http://raw.githubusercontent.com/mist-devel/mist-binaries/master/cores/amstrad/ROMs/AST-Equinox.dsk' "$2/roms/"
                         copy "$2/roms/AST-Equinox.dsk" "$SD_ROOT/amstrad/AST-Equinox.dsk" # roms are presented by core from /amstrad folder
                         download_url 'http://www.amstradabandonware.com/mod/upload/ams_de/games_disk/cyberno2.zip' "$2/roms/"
                         download_url 'http://www.amstradabandonware.com/mod/upload/ams_de/games_disk/supermgp.zip' "$2/roms/"
                         expand "$2/roms/cyberno2.zip" "$SD_ROOT/amstrad/"
                         expand "$2/roms/supermgp.zip" "$SD_ROOT/amstrad/"
                       }
apogee_roms()          { copy "$1/../extra/apogee.rom" "$2/"; }
apple1_roms()          { if [ $SYSTEM == 'mist' ]; then
                           copy "$1/BASIC.e000.prg" "$2/"
                           copy "$1/DEMO40TH.0280.prg" "$2/"
                         fi
                       }
apple1_roms_alt()      { download_url 'http://raw.githubusercontent.com/mist-devel/mist-binaries/master/cores/apple1/BASIC.e000.prg' "$2/"
                         download_url 'http://raw.githubusercontent.com/mist-devel/mist-binaries/master/cores/apple1/DEMO40TH.0280.prg' "$2/"
                       }
apple2e_roms()         { download_url 'http://mirrors.apple2.org.za/Apple II Documentation Project/Computers/Apple II/Apple IIe/ROM Images/Apple IIe Enhanced Video ROM - 342-0265-A - US 1983.bin' "$2/"
                         download_url 'http://ia802800.us.archive.org/4/items/PitchDark/Pitch-Dark-20210331.zip' "$2/"
                         expand "$2/Pitch-Dark-20210331.zip" "$2/"
                       }
apple2p_roms()         { download_url 'http://raw.githubusercontent.com/wsoltys/mist-cores/mockingboard/apple2fpga/apple_II.rom' "$2/"
                         download_url 'http://raw.githubusercontent.com/wsoltys/mist-cores/mockingboard/apple2fpga/bios.rom' "$2/"
                       }
archimedes_roms()      { download_url 'http://raw.githubusercontent.com/MiSTer-devel/Archie_MiSTer/master/releases/riscos.rom' "$2/"
                         copy "$2/riscos.rom" "$SD_ROOT/"
                         copy "$1/SVGAIDE.RAM" "$SD_ROOT/svgaide.ram"
                         download_url 'http://raw.githubusercontent.com/mist-devel/mist-binaries/master/cores/archimedes/archie1.zip' "$2/"
                         expand "$2/archie1.zip" "$SD_ROOT/"
                         expand "$1/RiscDevIDE.zip" "$2/"
                       }
atarist_roms()         { download_url 'http://raw.githubusercontent.com/mist-devel/mist-binaries/master/cores/mist/tos.img' "$SD_ROOT"
                         download_url 'http://raw.githubusercontent.com/mist-devel/mist-binaries/master/cores/mist/system.fnt' "$SD_ROOT"
                         download_url 'http://raw.githubusercontent.com/mist-devel/mist-binaries/master/cores/mist/disk_a.st' "$2/"
                       }
atari800_roms()        { copy "$1/A800XL.ROM" "$2/a800xl.rom"; }
atari2600_roms()       { download_url 'http://static.emulatorgames.net/roms/atari-2600/Asteroids (1979) (Atari) (PAL) [!].zip' "$2/roms/"
                         download_url 'http://download.freeroms.com/atari_roms/starvygr.zip' "$2/roms/"
                         expand "$2/roms/Asteroids (1979) (Atari) (PAL) [!].zip" "$SD_ROOT/ma2601/" # roms are presented by core from /MA2601 folder
                         expand "$2/roms/starvygr.zip" "$SD_ROOT/ma2601/"
                       }
atari5200_roms()       { download_url 'http://downloads.romspedia.com/roms/Asteroids (1983) (Atari).zip' "$2/roms/"
                         expand "$2/roms/Asteroids (1983) (Atari).zip" "$SD_ROOT/a5200/" # roms are presented by core from /A5200 folder
                       }
bbc_roms()             { copy "$1/bbc.rom" "$2/"
                         download_url 'http://raw.githubusercontent.com/ManuFerHi/SiDi-FPGA/master/Cores/Computer/BBC/BBC.vhd' "$2/"
                         download_url 'http://www.stardot.org.uk/files/mmb/higgy_mmbeeb-v1.2.zip' "$2/"
                         expand "$2/higgy_mmbeeb-v1.2.zip" "$2/beeb/"
                         copy "$2/beeb/BEEB.MMB" "$2/BEEB.ssd"
                         rm -rf "$2/beeb"
                       }
c16_roms()             { copy "$1/c16.rom" "$2/"
                         download_url 'http://www.c64games.de/c16/spiele/boulder_dash_3.prg' "$2/roms/"
                         download_url 'http://www.c64games.de/c16/spiele/giana_sisters.prg' "$2/roms/"
                         copy "$2/roms/boulder_dash_3.prg" "$SD_ROOT/c16/" # roms are presented by core from /C16 folder
                         copy "$2/roms/giana_sisters.prg" "$SD_ROOT/c16/"
                       }
c64_roms()             { copy "$1/c64.rom" "$2/"
                         download_url 'http://csdb.dk/getinternalfile.php/67833/giana sisters.prg' "$2/roms/"
                         #curl -O "$2/roms/SuperZaxxon.zip" -d 'id=727332&download=Télécharger' 'https://www.planetemu.net/php/roms/download.php'
                         download_url 'http://www.c64.com/games/download.php?id=315' "$2/roms/" # zaxxon.zip
                         download_url 'http://www.c64.com/games/download.php?id=2073' "$2/roms/" # super_zaxxon.zip
                         copy "$2/roms/giana sisters.prg" "$SD_ROOT/c64/" # roms are presented by core from /C64 folder
                         expand "$2/roms/zaxxon.zip" "$SD_ROOT/c64/"
                         expand "$2/roms/super_zaxxon.zip" "$SD_ROOT/c64/"
                       }
coco_roms()            { copy "$1/COCO3.ROM" "$2/coco3.rom"; }
enterprise_roms()      { copy "$1/ep128.rom" "$2/"
                         if [ ! -f "$2/ep128.vhd" ]; then
                           download_url 'http://www.ep128.hu/Emu/Ep_ide192m.rar' "$2/hdd/"
                           expand "$2/hdd/Ep_ide192m.rar" "$2/hdd/"
                           mv "$2/hdd/Ep_ide192m.vhd" "$2/ep128.vhd"
                           rm -rf "$2/hdd"
                         fi
                       }
gameboy_roms()         { download_url 'http://archive.org/download/mister-console-bios-pack_theypsilon/MiSTer_Console_BIOS_PACK.zip/Gameboy.zip' "$2/roms/"
                         expand "$2/roms/Gameboy.zip" "$2/roms/"
                       }
ht1080z_roms()         { if [ $SYSTEM == 'mist' ]; then copy "$1/HT1080Z.ROM" "$2/ht1080z.rom"; else download_url 'http://joco.homeserver.hu/fpga/download/HT1080Z.ROM' "$2/ht1080z.rom"; fi; }
intellivision_roms()   { copy "$1/intv.rom" "$2/"; }
laser500_roms()        { copy "$1/laser500.rom" "$2/"; }
lm80c_roms()           { copy "$1/lm80c.rom" "$2/"; }
lynx_roms()            { download_url 'http://archive.org/download/mister-console-bios-pack_theypsilon/MiSTer_Console_BIOS_PACK.zip/AtariLynx.zip' "$2/"
                         expand "$2/AtariLynx.zip" "$2/"
                       }
menu_image()           { download_url 'http://raw.githubusercontent.com/mist-devel/mist-binaries/master/cores/menu/menu.rom' "$2/"; }
msx1_roms()            { expand "$1/MSX1_vhd.rar" "$2/"; }
msx2p_roms()           { return; }
nes_roms()             { download_url 'http://archive.org/download/mister-console-bios-pack_theypsilon/MiSTer_Console_BIOS_PACK.zip/NES.zip' "$2/"
                         expand "$2/NES.zip" "$2/"
                         download_url 'http://nesninja.com/downloadssega/Sonic The Hedgehog (W) (REV01) [!].bin' "$2/roms/"
                         copy "$2/roms/Sonic The Hedgehog (W) (REV01) [!].bin" "$SD_ROOT/nes/"
                       }
next186_roms()         { copy "$1/Next186.ROM" "$2/next186.rom"
                         download_url 'http://ia804501.us.archive.org/22/items/next-186.vhd/Next186.vhd.zip' "$2/hd/"
                         expand "$2/hd/Next186.vhd.zip" "$SD_ROOT/"
                         rm -rf "$SD_ROOT/__MACOSX"
                       }
nintendo_sysattr()     { set_system_attr "$2/Nintendo hardware"; }
ondra_roms()           { return # https://github.com/PetrM1/OndraSPO186_MiST#loading-games-via-ondra-sd
                                # https://drive.google.com/file/d/1seHwftKzaBWHR4sSZVJLq7IKw-ZLafei
                       }
oric_roms()            { if [ $SYSTEM == 'mist' ]; then copy "$1/oric.rom" "$2/"; fi; }
pcxt_roms()            { download_url 'https://github.com/MiSTer-devel/PCXT_MiSTer/raw/main/games/PCXT/hd_image.zip' "$2/";
                         expand "$2/hd_image.zip" "$2/";
                         mv -f "$2/Freedos_HD.vhd" "$2/PCXT.HD0"
                         #download_url 'https://github.com/640-KB/GLaBIOS/releases/download/v0.2.4/GLABIOS_0.2.4_8T.ROM';
                         download_url 'https://github.com/somhi/PCXT_DeMiSTify/raw/main/SW/ROMs/pcxt_pcxt31.rom' "$2/";
                       }
pet2001_roms()         { download_url 'http://raw.githubusercontent.com/mist-devel/mist-binaries/master/cores/pet2001/pet2001.rom' "$2/"; }
plus_too_roms()        { download_url 'http://raw.githubusercontent.com/ManuFerHi/SiDi-FPGA/master/Cores/Computer/Plus_too/plus_too.rom' "$2/"
                         expand "$1/hdd_empty.zip" "$2/"
                       }
ql_roms()              { download_url 'http://raw.githubusercontent.com/mist-devel/mist-binaries/master/cores/ql/QXL.WIN' "$2/"
                         download_url 'http://raw.githubusercontent.com/mist-devel/mist-binaries/master/cores/ql/QL-SD.zip' "$2/"
                         expand "$2/QL-SD.zip" "$2/"
                         cp -pu "$1/"*.rom "$2/"
                       }
samcoupe_roms()        { copy "$1/samcoupe.rom" "$2/"; }
snes_roms()            { download_url 'http://archive.org/download/mister-console-bios-pack_theypsilon/MiSTer_Console_BIOS_PACK.zip/SNES.zip' "$2/"
                         expand "$2/SNES.zip" "$2/"
                         download_url 'http://nesninja.com/downloadssnes/Super Mario World (U) [!].smc' "$2/roms/"
                         copy "$2/roms/Super Mario World (U) [!].smc" "$SD_ROOT/snes/"
                       }
speccy_roms()          { copy "$1/speccy.rom" "$2/"; }
ti994a_roms()          { copy "$1/TI994A.ROM" "$2/ti994a.rom"; }
turbogfx_roms()        { download_url 'http://archive.org/download/mister-console-bios-pack_theypsilon/MiSTer_Console_BIOS_PACK.zip/TurboGrafx16.zip' "$2/"
                         expand "$2/TurboGrafx16.zip" "$2/"
                         cp -pu "$2/TurboGrafx16/"* "$2/"
                         rm -rf "$2/TurboGrafx16/"
                       }
tvc_roms()             { copy "$1/tvc.rom" "$2/"; }
vectrex_roms()         {
                         download_url 'http://ia902801.us.archive.org/33/items/VectrexROMS/Vectrex_ROMS.zip' "$2/roms/"
                         expand "$2/roms/Vectrex_ROMS.zip" "$2/roms/"
                         expand "$2/roms/Bedlam (1983).7z" "$SD_ROOT/vectrex/"
                       }
vic20_roms()           { copy "$1/vic20.rom" "$2/"; }
videopac_roms()        { #download_url 'http://f.s3roms.download/romfiles/philips-videopac/l/loony-balloon-europe-usa.zip' "$2/roms/"
                         #download_url 'http://f.s3roms.download/romfiles/philips-videopac/a/air-battle-europe-usa.zip' "$2/roms/"
                         expand "$2/roms/air-battle-europe-usa.zip" "$SD_ROOT/videopac/"
                         expand "$2/roms/loony-balloon-europe-usa.zip" "$SD_ROOT/videopac/"
                       }
zx8x_roms()            { download_url 'http://raw.githubusercontent.com/ManuFerHi/SiDi-FPGA/master/Cores/Computer/ZX8X/zx8x.rom' "$2/"; }
zx_spectrum_roms()     { copy "$(find "$1" -name 'spectrum.rom' | head -1)" "$2/"; }
bagman_roms()          {
                         download_url 'http://raw.githubusercontent.com/Gehstock/Mist_FPGA/master/Arcade_MiST/Bagman Hardware/meta/Super Bagman.mra' '/tmp/'
                         process_mra '/tmp/Super Bagman.mra' "$2"
                         rm '/tmp/Super Bagman.mra'
                       }

cores=(
 #"( 'core dst dir'                                   'src dir MiST'  'src dir SiDi'                                      opt_rom_copy_fn      )"
 # Main Menu
  "( '.'                                              'menu'          'menu/release'                                      menu_image           )"
 # Computers
  "( 'Computer/Amstrad CPC'                           'amstrad'       'Computer/Amstrad CPC'                              amstrad_roms         )"
  "( 'Computer/Amiga'                                 'minimig-aga'   'Computer/Amiga'                                    amiga_roms           )"
  "( 'Computer/AppleI'                                'apple1'        'Computer/AppleI'                                   apple1_roms          )"
  "( 'Computer/AppleIIe'                              'appleIIe'      'Computer/AppleIIe'                                 apple2e_roms         )"
  "( 'Computer/AppleII+'                              'appleii+'      'Computer/AppleII+'                                 apple2p_roms         )"
  "( 'Computer/Apple Macintosh'                       'plus_too'      'Computer/Plus_too'                                 plus_too_roms        )"
  "( 'Computer/Archimedes'                            'archimedes'    'Computer/Archimedes'                               archimedes_roms      )"
  "( 'Computer/Atari 800'                             'atari800'      'Computer/Atari800'                                 atari800_roms        )"
  "( 'Computer/Atari ST'                              'mist'          'Computer/AtariST'                                  atarist_roms         )"
  "( 'Computer/Atari STe'                             'mistery'       'Computer/Mistery'                                  atarist_roms         )"
  "( 'Computer/BBC Micro'                             'bbc'           'Computer/BBC'                                      bbc_roms             )"
  "( 'Computer/C16'                                   'c16'           'Computer/C16'                                      c16_roms             )"
  "( 'Computer/C64'                                   'fpga64'        'Computer/C64'                                      c64_roms             )"
  "( 'Computer/Color Computer'                        ''              'Computer/Coco'                                     coco_roms            )"
  "( 'Computer/Enterprise 128'                        'enterprise'    'Computer/Elan Enterprise'                          enterprise_roms      )"
  "( 'Computer/HT1080Z School Computer'               'ht1080z'       ''                                                                       )"
  "( 'Computer/Laser500'                              ''              'Computer/Laser500'                                 laser500_roms        )"
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
  "( 'Computer/SAM Coupe'                             'samcoupe'      'Computer/Sam Coupe'                                samcoupe_roms        )"
  "( 'Computer/Speccy'                                ''              'Computer/Speccy'                                   speccy_roms          )"
  "( 'Computer/TI99-4A'                               'ti994a'        'Computer/TI994A'                                   ti994a_roms          )"
  "( 'Computer/VIC20'                                 'vic20'         'Computer/VIC20'                                    vic20_roms           )"
  "( 'Computer/ZX8x'                                  'zx01'          'Computer/ZX8X'                                     zx8x_roms            )"
  "( 'Computer/ZX-Next'                               'zxn'           'Computer/ZX Spectrum Next'                                              )"
  "( 'Computer/ZX Spectrum'                           'spectrum'      'Computer/ZX Spectrum'                              zx_spectrum_roms     )"
  "( 'Computer/ZX Spectrum 48k'                       ''              'Computer/ZX Spectrum 48K Kyp'                                           )"
 # Consoles
  "( 'Console/Atari 2600'                             'a2600'         'Console/A2600'                                     atari2600_roms       )"
  "( 'Console/Atari 5200'                             'atari5200'     'Console/A5200'                                     atari5200_roms       )"
  "( 'Console/Astrocade'                              'astrocade'     'Console/Astrocade'                                                      )"
  "( 'Console/ColecoVision'                           'colecovision'  'Console/COLECOVISION'                                                   )"
  "( 'Console/Gameboy'                                'gameboy'       'Console/GAMEBOY'                                   gameboy_roms         )"
  "( 'Console/Genesis MegaDrive'                      'fpgagen'       'Console/GENESIS'                                                        )"
  "( 'Console/Intellivision'                          'intellivision' ''                                                                       )"
  "( 'Console/Nintendo NES'                           'nes'           'Console/NES'                                       nes_roms             )"
  "( 'Console/Nintendo SNES'                          'snes'          'Console/SNES'                                      snes_roms            )"
  "( 'Console/PC Engine'                              'pcengine'      'Console/PCE'                                       turbogfx_roms        )"
  "( 'Console/SEGA MasterSystem'                      'sms'           'Console/SMS'                                                            )"
  "( 'Console/Videoton TV Computer'                   'tvc'           ''                                                  tvc_roms             )"
  "( 'Console/Vectrex'                                ''              'Console/Vectrex'                                   vectrex_roms         )"
  "( 'Console/Videopac'                               'videopac'      'Console/VIDEOPAC'                                  videopac_roms        )"
 # Arcade: Gehstock
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
 # Arcade: Jotego fetched directly from Jotego jtbin repository
 #"( 'Arcade/Jotego/jt1942_SiDi.rbf'                  ''              'Arcade/Jotego/1942'                                1942_roms            )"
 #"( 'Arcade/Jotego/jt1943_SiDi.rbf'                  ''              'Arcade/Jotego/1943'                                1943_roms            )"
 #"( 'Arcade/Jotego/jtcommando_SiDi.rbf'              ''              'Arcade/Jotego/Commando'                            commando_roms        )"
 #"( 'Arcade/Jotego/jtgng_SiDi.rbf'                   ''              'Arcade/Jotego/GhostnGoblins'                       ghost_n_goblins_roms )"
 #"( 'Arcade/Jotego/jtgunsmoke_SiDi.rbf'              ''              'Arcade/Jotego/Gunsmoke'                            gunsmoke_roms        )"
 #"( 'Arcade/Jotego/jtvulgus_SiDi.rbf'                ''              'Arcade/Jotego/Vulgus'                              vulgus_roms          )"
 # Arcade: other
  "( 'Arcade/Alpha68k'                                ''              'Arcade/Alpha68k'                                                        )"
  "( 'Arcade/IremM72'                                 ''              'Arcade/IremM72'                                                         )"
  "( 'Arcade/IremM92'                                 ''              'Arcade/IremM92'                                                         )"
  "( 'Arcade/Jotego'                                  ''              'Arcade/Jotego'                                                          )"
  "( 'Arcade/Neogeo'                                  'neogeo'        'Arcade/Neogeo'                                                          )"
  "( 'Arcade/Prehisle'                                ''              'Arcade/Prehisle'                                                        )"
  "( 'Arcade/Konami Hardware'                         ''              'Arcade/Konami hardware/konami hardware.rar'                             )"
  "( 'Arcade'                                         ''              'Arcade/Nintendo hardware/Nintendo hardware.rar'    nintendo_sysattr     )"
)

copy_mist_cores() {
  local dstroot=$1 # $1: destination folder

  echo -e "\n----------------------------------------------------------------------"
  echo -e "Copy MiST Cores to '$dstroot'"
  echo -e "----------------------------------------------------------------------\n"

  local srcroot=$GIT_ROOT/MiST/binaries

  # get MiST binary repository
  #clone_or_update_git 'http://github.com/mist-devel/mist-board.git' "$srcroot/board"
  #srcroot=$srcroot/binaries
  clone_or_update_git 'http://github.com/mist-devel/mist-binaries.git' "$srcroot"

  # Firmware upgrade file
  cp -pu "$srcroot/firmware/firmware"*.upg "$dstroot/firmware.upg"

  # loop over folders in MiST repository
  local saveIFS=$IFS
  IFS=$(echo -en "\n\b")
  local dir line src dst hdl
  for dir in $(find "$srcroot/cores" -type d -maxdepth 1 | sort); do
    # check if in our list of cores
    for line in "${cores[@]}"; do
      eval "line=$line"
      dst=${line[0]}
      src=${line[1]}
      hdl=${line[3]}
      if [ "$srcroot/cores/$src" = "$dir" ]; then
      # Info
      echo -e "\n${dir//$GIT_ROOT\//}"
        # create destination forlder and copy latest core
        if [ "$dst" = "." ]; then
          # copy latest menu core and set hidden attribute to hide this core from menu
          copy_latest_core "$dir" "$dstroot/$dst/core.rbf"
          set_hidden_attr "$dstroot/$dst/core.rbf"
       else
          copy_latest_core "$dir" "$dstroot/$dst/$(basename "$dst").rbf"
           # set system attribute for this subfolder to be visible in menu core and copy latest core
          set_system_attr "$dstroot/$dst"
        fi
         # optional rom handling
        if [ ! -z "$hdl" ]; then
          $hdl "$dir" "$dstroot/$dst"
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
  local dstroot=$1 # $1: destination folder

  echo -e "\n----------------------------------------------------------------------"
  echo -e "Copy SiDi Cores to '$dstroot'"
  echo -e "----------------------------------------------------------------------\n"

  local srcroot=$GIT_ROOT/SiDi/ManuFerHi

  # get SiDi binary repository
  clone_or_update_git 'http://github.com/ManuFerHi/SiDi-FPGA.git' "$srcroot"

  # Firmware upgrade file
  copy "$srcroot/Firmware/firmware"*.upg "$dstroot/firmware.upg"

  if [ true ]; then
    # loop over folders in SiDi repository
    local saveIFS=$IFS
    IFS=$(echo -en "\n\b")
    local dir line src dst hdl
    for dir in $(find "$srcroot/Cores" -type d | sort); do
      if [ $(basename "$dir") != 'old' ] && [ $(basename "$dir") != 'output_files' ]; then
        if [ -n "$(find "$dir" -maxdepth 1 -iname '*.rbf')" ]; then
          # check if in our list of cores
          for line in "${cores[@]}"; do
            eval "line=$line"
            dst=${line[0]}
            src=${line[2]}
            hdl=${line[3]}
            if [ "$srcroot/Cores/$src" = "$dir" ]; then
              # Info
              echo -e "\n${dir//$GIT_ROOT\//}"
              if [ "$dst" = "." ]; then
                # copy latest menu core and set hidden attribute to hide this core from menu
                copy_latest_core "$dir" "$dstroot/$dst/core.rbf" 'sidi'
                set_hidden_attr "$dstroot/$dst/core.rbf"
              else
                # create destination folder, set system attribute for this subfolder to be visible in menu core and copy latest core
                copy_latest_core "$dir" "$dstroot/$dst/$(basename "$dst").rbf" 'sidi'
                set_system_attr "$dstroot/$dst"
              fi
              # optional rom handling
              if [ ! -z "$hdl" ]; then
                $hdl "$dir" "$dstroot/$dst"
              fi
              dir=''
              break
            fi
          done
        elif [ -n "$(find "$dir" -maxdepth 1 -iname '*.rar')" ]; then
          for rar in $(find "$dir" -iname '*.rar' | sort); do
            # check if in our list of cores
            for line in "${cores[@]}"; do
              eval "line=$line"
              dst=${line[0]}
              src=${line[2]}
              hdl=${line[3]}
              if [ "$srcroot/Cores/$src" = "$rar" ]; then
                # Info
                echo -e "\n${rar//$GIT_ROOT\//} ..."
                # uncompress to destination folder
                echo "  Uncompressing $src ..."
                expand "$rar" "$dstroot/$dst"
                # optional rom handling
                if [ ! -z "$hdl" ]; then
                  $hdl "$dir" "$dstroot/$dst"
                fi
                # set system attribute for this subfolder to be visible in menu core and extract cores
                set_system_attr "$dstroot/$dst"
                dir=''
                break
              fi
            done
          done
        fi

        if [ ! -z $dir ]; then
          if ([ ! -z "$(find "$dir" -maxdepth 1 -iname '*.rbf')" ] || [ ! -z "$(find "$dir" -maxdepth 1 -iname '*.rar')" ]); then
            echo -e "\e[1;31m\nUnhandled: \"$dir\"\e[0m"
          fi
        fi
      fi
    done
    IFS=$saveIFS
  else
    # Loop over list of cores
    local line id src dst hdl
    for line in "${cores[@]}"; do
      eval "line=$line"
      dst=${line[0]}
      src=${line[2]}
      hdl=${line[3]}

      # Info
      echo -e "\n${dst//$GIT_ROOT\//} ..."

      # handle core(s)
      if [ -d "$srcroot/Cores/$src" ]; then
        if [ "$dst" = '.' ]; then
          # copy latest menu core and set hidden attribute to hide this core from menu
          copy_latest_core "$srcroot/Cores/$src" "$dstroot/$dst/core.rbf" 'sidi'
          set_hidden_attr "$dstroot/$dst/core.rbf"
        else
          # set system attribute for this subfolder to be visible in menu core and copy latest core
          copy_latest_core "$srcroot/Cores/$src" "$dstroot/$dst/$(basename "$dst").rbf" 'sidi'
          set_system_attr "$dstroot/$dst"
        fi
      elif [ -f "$srcroot/Cores/$src" ]; then
        case "$srcroot/Cores/$src" in
          *.rbf) copy "$srcroot/Cores/$src" "$dstroot/$dst/";;
          *.rar) expand "$srcroot/Cores/$src" "$dstroot/$dst";;
          *)     echo -e "\n\e[1;31m  ERROR: Invalid extension: '$src'\e[0m";;
        esac
        set_system_attr "$dstroot/$dst"
      else
        echo -e "\e[1;31m  ERROR: Invalid '$srcroot/Cores/$src'\e[0m"
      fi

      # optional rom handling
      if [ ! -z "$hdl" ]; then
        $hdl "$srcroot/Cores/$src" "$dstroot/$dst"
      fi
    done
  fi
}


show_usage() {
  echo -e "\n Usage: $0 [-d ^<destination SD drive or folder^>] [-s <^<mist^|sidi^^>] [-h]\n" \
          "Generate SD card content with Jotego cores/roms for specific FPGA platform.\n" \
          "\n" \
          "Optional arguments:\n" \
          " -d <destination SD (drive) folder>\n" \
          "    Location where the target files should be generated.\n" \
          "    If this option isn't specified, 'SD\sidi' will be used by default.\n" \
          " -s <mist|sidi>\n" \
          "    Set target system (mist or sidi).\n" \
          "    If this option isn't specified, 'sidi' will be used by default.\n" \
          " -h\n" \
          "    Show this help text\n"
}


while getopts ':hs:d:' option; do
  case $option in
    d)  SD_ROOT=$OPTARG;;
    s)  SYSTEM=${OPTARG,,}
        if [ $SYSTEM != 'sidi' ] && [ $SYSTEM != 'mist' ]; then
          echo -e "\n\e[1;31mInvalid target \"$SYSTEM\"!\e[0m"
          show_usage; exit $(false)
        fi;;
    h)  show_usage; exit $(true);;
    \?) echo -e "\n\e[1;31mERROR: Invalid option \"$option\"\e[0m"
        show_usage
        exit $(false);;
   esac
done
if [ -z "$SYSTEM" ];  then SYSTEM='sidi'; fi
if [ -z "$SD_ROOT" ]; then SD_ROOT=$(dirname "${BASH_SOURCE[0]}")/SD/$SYSTEM; fi


echo -e "\n----------------------------------------------------------------------"
echo -e "Generating SD content for '$SYSTEM' to '$SD_ROOT'"
echo -e "----------------------------------------------------------------------\n"

echo -e "Creating destination folder '$SD_ROOT'..."
mkdir -p "$SD_ROOT"

# check filesystem of SD folder (only vfat ans msdos support fatattr ioctrls - fuseblk will stzarting from 1.4.0)
fs=$(stat -f -c %T "$SD_ROOT")
if [ "$fs" != 'vfat' ] && [ "$fs" != 'msdos' ] ; then
  prompt='Pick an option:'
  options=('y' 'n')
  echo -e "\nFilesystem type of destination '$SD_ROOT' is '$fs',"
  echo "but should be 'vfat' or 'msdos'."
  echo "This means some DOS file/folder attributes (SYSTEM/HIDDEN) can't be set correctly."
  echo "Continue anyway?"
  PS3="$prompt "
  select opt in "${options[@]}"; do
    case "$REPLY" in
    'y'|'Y') break;;
    'n'|'N') exit $(false);;
    *) echo "Invalid option (Y or N)";continue;;
    esac
  done
else
  echo -e "\nFilesystem type of destination \"$SD_ROOT\" is '$fs'."
fi

# check required helper tools
check_dependencies

# start generating
if [ $SYSTEM == 'sidi' ]; then
  copy_sidi_cores "$SD_ROOT"
  copy_eubrunosilva_sidi_cores "$SD_ROOT"
elif [ $SYSTEM == 'mist' ]; then
  copy_mist_cores "$SD_ROOT"
  copy_sorgelig_mist_cores "$SD_ROOT"
  copy_gehstock_mist_cores "$SD_ROOT"
  copy_other_mist_cores "$SD_ROOT"
fi
copy_jotego_arcade_cores "$SYSTEM" "$SD_ROOT/Arcade/Jotego"

echo -e '\ndone.'