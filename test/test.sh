#!/bin/bash

if which shellcheck 1>/dev/null; then
  if shellcheck -S warning -e SC2155 "$(dirname "${BASH_SOURCE[0]}")/../Linux/genSD.sh" \
  && shellcheck -S warning "${BASH_SOURCE[0]}"; then
    echo 'shellcheck passed.'
  else
    echo -e '\e[1;31mERROR: shellcheck of Linux/genSD.sh failed\e[0m\n'
    exit 1

  fi
else
  echo -e '\e[1;33mWARNING: shellcheck not installed!\e[0m\n' \
          'Please install by \e[1mapt install -y shellcheck\e[0m to enable shellchecking.'
fi

avail=$(df --output=avail . | tail -n 1)
if [ $avail -lt 50000000 ]; then
  echo -e "\e[1;31mERROR: Not enough free disk space ($(df -h --output=avail . | tail -n 1 | tr -d '[:blank:]')). Minimum 50GB required\e[0m\n"
  exit 1
fi

# create empty folder for destination system
dstRoot=$(dirname "${BASH_SOURCE[0]}")/Linux
rm -rf "$dstRoot"
mkdir -p "$dstRoot"

# Test Linux .sh and Windows .ps1 scripts
for scr in Linux/genSD.sh Windows/genSD.ps1; do
  # make copy of script
  cp -pu "$(dirname "${BASH_SOURCE[0]}")/../$scr" "$dstRoot/"

  # test all supported FPGA systems
  for sys in mist sidi sidi128; do
    # make sure we start with empty repositories/cache folders for fpga system
    rm -rf "$dstRoot/repos"
    dstSys=$dstRoot/${scr##*.}/$sys
    echo -e "\n----------------------------------------------------------------------" \
            "\nTest '$scr' for '$sys' -> '$dstSys':" \
            "\n----------------------------------------------------------------------\n"

    # make 2 runs: 1st with empty cache folders, 2nd with cache folders available (=update)
    for i in 1 2; do
      dstSD=$dstSys/SD$i
      echo -e "Test #$i -> '$dstSD':"

      # create empty folder for destination distribution
      rm -rf "$dstSD"
      mkdir -p "$dstSD"
      if [ $i -ne 1 ]; then
        # use initially created folder content for re-run
        echo -e "\n\nCreating copy of '$dstSys/SD1' for update test ..."
        cp -pr "$dstSys/SD1/"* "$dstSD/"
      fi

      echo -e "\n----------------------------------------------------------------------" \
              "\nResult for '$sys' -> '$dstSD'" \
              "\n----------------------------------------------------------------------\n"

      # https://unix.stackexchange.com/questions/111899/how-to-strip-color-codes-out-of-stdout-and-pipe-to-file-and-stdout
      ansifilter='s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g'

      # generate content to destination SD folder
      echo 'y' | (time "$(dirname "${BASH_SOURCE[0]}")/Linux/$(basename $scr)" -s $sys -d "$dstSD" 2>&1) | sed -ru $ansifilter | tee "$dstSD/log.txt"

      # log error/warning results
      echo -e -n "\n\n\e[1mMissing core .rbf files:\n\e[1;31m"                                 | sed -ru $ansifilter | tee -a "$dstSD/log.txt"
      (grep -i 'rbf\" not found' "$dstSD/log.txt" | sort | uniq)                               | sed -ru $ansifilter | tee -a "$dstSD/log.txt"

      echo -e -n "\n\n\e[1mMissing MAME ROMs:\n\e[1;31m"                                       | sed -ru $ansifilter | tee -a "$dstSD/log.txt"
      (grep -i 'zip file not found' "$dstSD/log.txt" | sort | uniq)                            | sed -ru $ansifilter | tee -a "$dstSD/log.txt"

      echo -e -n "\n\n\e[0;1mMAME ROMs with wrong checksum:\n\e[1;31m"                         | sed -ru $ansifilter | tee -a "$dstSD/log.txt"
      (grep -i -B 1 --no-group-separator 'md5 mismatch' "$dstSD/log.txt" | awk '!x[$0]++')     | sed -ru $ansifilter | tee -a "$dstSD/log.txt"

      echo -e -n "\n\n\e[0;1mMAME ROMs with missing parts:\n\e[1;31m"                          | sed -ru $ansifilter | tee -a "$dstSD/log.txt"
      (grep -i -B 1 --no-group-separator 'not found in zip' "$dstSD/log.txt" | awk '!x[$0]++') | sed -ru $ansifilter | tee -a "$dstSD/log.txt"

      # some statistics
      echo -e -n "\n\n\e[0;1mNumber of .rbf files\e[0m:" \
                 "$(find $dstSD -name '*.rbf' -printf '%f\n' | sort | uniq | wc -l)\n"         | sed -ru $ansifilter | tee -a "$dstSD/log.txt"
      echo -e -n "\e[0;1mNumber of .arc files\e[0m:" \
                 "$(find $dstSD -name '*.arc' -printf '%f\n' | sort | uniq | wc -l)\n"         | sed -ru $ansifilter | tee -a "$dstSD/log.txt"
      echo -e -n "\e[0;1mNumber of .rom files\e[0m:" \
                 "$(find $dstSD -name '*.rom' -printf '%f\n' | sort | uniq | wc -l)\n"         | sed -ru $ansifilter | tee -a "$dstSD/log.txt"
      echo -e -n "\e[0;1mNumber of .ram files\e[0m:" \
                 "$(find $dstSD -name '*.ram' -printf '%f\n' | sort | uniq | wc -l)\n"         | sed -ru $ansifilter | tee -a "$dstSD/log.txt"
    done
    echo -e -n "\n\n\e[1mDiff of $dstSys/SD1 <-> $dstSys/SD2:\n\e[1;31m"                       | sed -ru $ansifilter | tee -a "$dstSD/log.txt"
    diff -qr "$dstSys/SD1/" "$dstSys/SD2/"                                                     | sed -ru $ansifilter | tee -a "$dstSD/log.txt"
  done
done
