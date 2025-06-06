#!/usr/bin/pwsh

# -- genSD.ps1
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


# using '/' instead of '\' as path separator makes this script more easy to compare against linux bash version
filter replace-slash { $_ -replace '\\', '/' }

# cache folders for repositories, MAME ROMs and miscellaneous support files
$PSScriptRoot =  $PSScriptRoot | replace-slash
$GIT_ROOT     = "$PSScriptRoot/repos"
$TOOLS_ROOT   = "$PSScriptRoot/tools"
$MAME_ROMS    = "$PSScriptRoot/repos/mame"
$MISC_FILES   = "$PSScriptRoot/repos/misc"
$SUDO_PW      = ""

function check_dependencies {
  Write-Host "`r`nChecking required tools ..."

  # this script can be executed with Powershell for Linux (pwsh) too.
  # Handle external tool names with OS dependent script-scoped variables.
  if ($isLinux) {
    if (-not (&which unzip  )) { &sudo apt install -y unzip   };
    if (-not (&which unrar  )) { &sudo apt install -y unrar   };
    if (-not (&which 7z     )) { &sudo apt install -y 7z      };
    if (-not (&which git    )) { &sudo apt install -y git     };
    if (-not (&which fatattr)) { &sudo apt install -y fatattr };

    if(-not ( Test-Path "$TOOLS_ROOT/mra")) {
      download_url 'https://github.com/mist-devel/mra-tools-c/raw/master/release/linux/mra' "$TOOLS_ROOT/" | Out-Null
      &chmod +x -f "$TOOLS_ROOT/mra" *>$null
    }
    $script:unzip    = 'unzip'
    $script:unrar    = 'unrar'
    $script:sevenzip = '7z'
    $script:touch    = 'touch'
    $script:git      = 'git'
    $script:attrib   = 'fatattr'
    $script:mra      = "$TOOLS_ROOT/mra"
    $env:TEMP        = '/tmp'
  } else {
    #if (-not (Test-Path "$TOOLS_ROOT/wget.exe")) {
    #  download_url 'http://eternallybored.org/misc/wget/1.21.4/32/wget.exe' "$TOOLS_ROOT/" | Out-Null
    #}
    if (-not (Test-Path "$TOOLS_ROOT/unzip.exe" )) {
      download_url 'http://stahlworks.com/dev/unzip.exe' "$TOOLS_ROOT/" | Out-Null
    }
    if (-not ( Test-Path "$TOOLS_ROOT/UnRAR.exe")) {
      download_url 'https://www.rarlab.com/rar/unrarw64.exe' "$TOOLS_ROOT/" | Out-Null
      try {
        Push-Location -Path $TOOLS_ROOT
        & ./unrarw64.exe /s
        Start-Sleep -Seconds 3 # necessary as unrarw32.exe detatches itself from CLI and runs asynchronously
        Remove-Item $('unrarw64.exe', 'license.txt') | Out-Null
      } finally {
        Pop-Location
      }
    }
    if (-not (Test-Path "$TOOLS_ROOT/7z/7za.exe")) {
      download_url 'https://master.dl.sourceforge.net/project/sevenzip/7-Zip/9.20/7za920.zip' "$TOOLS_ROOT/7z/" | Out-Null
      Expand-Archive -Path "$TOOLS_ROOT/7z/7za920.zip" -d "$TOOLS_ROOT/7z/" -Force
      Remove-Item "$TOOLS_ROOT/7z/7za920.zip" -Force
    }
    if ( -not ( Test-Path "$TOOLS_ROOT/touch.exe" )) {
      download_url 'https://master.dl.sourceforge.net/project/touchforwindows/touchforwindows/binary release one/touch.r1.bin.i386.zip' "$TOOLS_ROOT/" | Out-Null
      Expand-Archive -Path "$TOOLS_ROOT/touch.r1.bin.i386.zip" -d "$TOOLS_ROOT/" -Force
      Remove-Item "$TOOLS_ROOT/touch.r1.bin.i386.zip" -Force
    }
    if (-not (Test-Path "$TOOLS_ROOT/git/cmd/git.exe")) {
      download_url 'https://github.com/git-for-windows/git/releases/download/v2.33.1.windows.1/MinGit-2.33.1-32-bit.zip' "$TOOLS_ROOT/git/" | Out-Null
      Expand-Archive -Path "$TOOLS_ROOT/git/MinGit-2.33.1-32-bit.zip" -d "$TOOLS_ROOT/git/" -Force
      Remove-Item "$TOOLS_ROOT/git/MinGit-2.33.1-32-bit.zip" -Force
    }
    if (-not (Test-Path "$TOOLS_ROOT/mra.exe")) {
      download_url 'https://github.com/mist-devel/mra-tools-c/raw/master/release/windows/mra.exe' "$TOOLS_ROOT/" | Out-Null
    }
    $script:unzip    = "$TOOLS_ROOT/unzip.exe"
    $script:unrar    = "$TOOLS_ROOT/UnRAR.exe"
    $script:sevenzip = "$TOOLS_ROOT/7z/7za.exe"
    $script:touch    = "$TOOLS_ROOT/touch.exe"
    $script:git      = "$TOOLS_ROOT/git/cmd/git.exe"
    $script:attrib   = "attrib"
    $script:mra      = "$TOOLS_ROOT/mra.exe"
  }
}


function clone_or_update_git {
  param ( [string]$url,       # $1: git url
           $dstpath = $null ) # $2: destination directory (optional)

  $name = $url.Replace('/','.').Split('.')[-2]
  if ($null -eq $dstpath) { $dstpath = "$GIT_ROOT/$name" }

  # check if cloned before
  if (-not (Test-Path -Path "$dstpath/.git" -pathtype Container)) {
    Write-Host "Cloning `'$url`'"
    & $script:git -c core.protectNTFS=false clone $url $dstpath 2>&1 | % ToString
  } else {
    &$script:git -C $dstpath/ remote update 2>&1 | % ToString
    &$script:git -C "$dstpath/" diff remotes/origin/HEAD --shortstat --exit-code
    if ($LASTEXITCODE -gt 0) {
      Write-Host "Updating `'$url`'"
      &$script:git -C "$dstpath/" -c core.protectNTFS=false pull 2>&1 | % ToString
    } else {
      Write-Host "Up-to-date: `'$url`'"
      return
    }
  }

  # Set timestamps on git files to match repository commit dates
  # see https://stackoverflow.com/questions/21735435/git-clone-changes-file-modification-time for details
  foreach ($f in (&$script:git -C "$dstpath/" ls-tree -r --name-only HEAD)) {
    Write-Host -noNewLine "`rsychronizing timestamps: $([char]27)[0K$f"
    $itm = Get-Item -LiteralPath "$dstpath/$f" -Force
    $itm.CreationTime = $itm.LastWriteTime = $(&$script:git -C "$dstpath/" log -1 --format="%ai" -- $f 2>$null)
  }
  Write-Host ""
}


function set_system_attr {
  param ( [string]$1 ) # $1: path to file/directory
  $p = $1
  while ( ($p -ne $SD_ROOT) -and ($p.length -gt 1) ) {
    if ($isLinux -and $script:SUDO_PW -ne '') {
      &sh -c "echo $script:SUDO_PW | sudo -S $script:attrib +s $p 2>/dev/null"
    } else {
      &$script:attrib +s $p *>$null
    }
    $p = Split-Path -Parent $p | replace-slash
  }
}

function set_hidden_attr {
  param ( [string]$1 ) # $1: path to file
  if ($isLinux -and $script:SUDO_PW -ne '') {
    &sh -c "echo $script:SUDO_PW | sudo -S $script:attrib +h $1 2>/dev/null"
  } else {
    &$script:attrib +h $1 *>$null
  }
}


function Escape-Name {
  param ( [string]$path ) # $1: string to be PowerShell escaped

  # escape square brackets with filenames - necessary for PowerShell methods if not using -LiteralPath
  return $path.replace('[','``[').replace(']','``]')
}

function makedir {
  param ( [string]$dstpath ) # $1: directory path

  if (-not (Test-Path -LiteralPath $dstpath -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $dstpath | Out-Null
  }
}

function sdcopy {
  param ( [string[]]$src, # $1: src file(s)
          [string]$dst )  # $2: destination file | directory

  if (Test-Path -Path (Escape-Name $src) -PathType Leaf) {
    # create destination folder if it doesn't exist
    if ($dst.SubString($dst.length -1) -eq '/') {
      makedir $dst
    } else {
      $parent = Split-Path -Parent $dst
      makedir $parent
    }
    # skip if source file is older
    if (Test-Path -Path $dst -pathtype leaf) {
      $tms = (Get-Item -Path (Escape-Name $src) -Force).LastWriteTime
      $tmd = (Get-Item -Path (Escape-Name $dst) -Force).LastWriteTime
      if ($tmd -ge $tms) { return }
    }
    Copy-Item -Path (Escape-Name $src) -Destination $dst -Force
  }
  elseif (Test-Path -Path (Escape-Name $src) -PathType Container) {
    # create destination folder if it doesn't exist
    if ($dst.SubString($dst.length -1) -eq '/') {
      makedir $dst
    }
    Copy-Item -Path (Escape-Name $src) -Destination $dst -Recurse -Force
  } else {
    Write-Host -ForegroundColor red "  `'$src`' not found."
  }
}

function expand {
  param ( [string]$srcfile,  # $1: arc archive
          [string]$dstpath ) # $2: destination directory (will be created if it doesn't exist)

  Write-Host -noNewLine "  extracting `'$srcfile`' ..."
  if (Test-Path -LiteralPath $srcfile) {
    # create destination folder if it doesn't exist
    makedir $dstpath

    switch -Wildcard ($srcfile) {
      '*.zip' { if ($isLinux -or ($null -ne  $script:unzip)) { $(&$script:unzip -uoq "$srcfile" -d "$dstpath") } else {
                try { Expand-Archive -LiteralPath $srcfile -DestinationPath $dstpath -Force; $true } catch { $false }
              } if ($?)                                                            { Write-Host " done." } else { Write-Host -ForegroundColor red " failed." } }
      '*.rar' { if ($(&$script:unrar x -u -o- -y "$srcfile" "$dstpath"; $?))       { Write-Host " done." } else { Write-Host -ForegroundColor red " failed." } }
      '*.7z'  { if ($isLinux) { &$script:sevenzip x -aos -bso0 -o"$dstpath" "$srcfile" }
                   else       { &$script:sevenzip x -y -o"$dstpath" $srcfile | Out-Null }
                if ($?) { Write-Host " done." } else { Write-Host -ForegroundColor red " failed." } }
      default { Write-Host -ForegroundColor red "Invalid file extension." }
    }
  } else {
    Write-Host -ForegroundColor red "not found."
  }
}


function download_url {
  param ( [string]$url,  # $1: url
          [string]$dst ) # $2: destination directory | destination file

  Write-Host -noNewLine "  fetching `'$url`' ..."
  $result = $true
  # create destination folder if it doesn't exist
  if ($dst.SubString($dst.length -1) -eq '/') {
    makedir $dst
  } else {
    $parent = Split-Path -Parent $dst
    makedir $parent
  }
  if (Test-Path "$dst/" -pathtype Container) {
    $dst="$dst/$($url.Split('/')[-1])"
  }
  # skip download if file exists
  if ((Test-Path -LiteralPath $dst) -And ((Get-Item $dst).length -gt 0)) {
    Write-Host ' exists.'
  } else {
    try {
      # download file (System.Net.WebClient.DownloadFile method works perfectly synchronously)
      (New-Object System.Net.WebClient).DownloadFile($url.replace('+','%2b'), $dst)
      # get timestamp from meta data via WebRequest API
      $f = Get-Item -LiteralPath $dst
      $resp = [System.Net.WebRequest]::Create($url).GetResponse()
      $f.CreationTime = $f.LastWriteTime = $resp.LastModified
      $resp.Close()
      Write-Host ' done.'
    } catch {
      Write-Host -ForegroundColor red ' failed.'
      $result = $false
    }
  }
  return $result
}


function grep {
  param ( [string]$pattern, # $1: search pattern
          [string]$f )      # $2: file to search in

  $result = "$((Select-String -Pattern $pattern -LiteralPath $f).Matches)"
  return $result
}


function copy_latest_file {
  param ( [string]$srcdir,  # $1: source directory
          [string]$dstfile, # $2: destination file
          [string]$pattern, # $3: name pattern
          $exclude = $null) # $4: optional exclude pattern

  Write-Host "  `'$($srcdir.Replace("$GIT_ROOT/",''))`' -> `'$($dstfile.Replace("$($PSScriptRoot | replace-slash)/",''))`'"
  $options = @{ Path="$srcdir/*" } + @{ Include="$pattern" }; if ($exclude) { $options += @{ Exclude="$exclude" } }
  $rbf = Get-ChildItem @options | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($rbf) {
    sdcopy $rbf.fullname $dstfile
  }
}


function download_mame_roms {
  param ( [string]$dstroot, # $1: destination directory
          [int]$ver,        # $2: mameversion info from .mra file
          [String[]]$zips ) # $3: array with zip archive name(s), e.g. $('single.zip') or $('file1.zip', 'file2.zip')

  # referred by -mra files: 251, 245, 240, 229, 224, 222, 220, 218, 193
  $mameurls=@(
   #( mame-version, 'base url (incl. '/', will be extended by .zip name)'                                              ),
   #( 0185, 'https://archive.org/download/MAME_0.185_ROMs_merged/MAME_0.185_ROMs_merged.zip/MAME 0.185 ROMs (merged)/' ),
   #( 0193, 'https://archive.org/download/MAME0.193RomCollectionByGhostware/'                                          ),
   #( 0193, 'https://archive.org/download/MAME_0.193_ROMs_merged/MAME_0.193_ROMs_merged.zip/MAME 0.193 ROMs (merged)/' ),
   #( 0197, 'https://archive.org/download/MAME_0.197_ROMs_merged/MAME_0.197_ROMs_merged.zip/MAME 0.197 ROMs (merged)/' ),
   #( 0201, 'https://archive.org/download/MAME201_Merged/MAME 0.201 ROMs (merged)/'                 ),
   #( 0202, 'https://archive.org/download/MAME_0.202_Software_List_ROMs_merged/'                    ), # only update
   #( 0205, 'https://archive.org/download/mame205T7zMerged/'                                        ),
   #( 0211, 'https://archive.org/download/MAME211RomsOnlyMerged/'                                   ),
   #( 0212, 'https://archive.org/download/MAME212RomsOnlyMerged/'                                   ),
   #( 0213, 'https://archive.org/download/MAME213RomsOnlyMerged/'                                   ),
   #( 0214, 'https://archive.org/download/MAME214RomsOnlyMerged/'                                   ),
   #( 0215, 'https://archive.org/download/MAME215RomsOnlyMerged/'                                   ),
    ( 0216, 'https://archive.org/download/MAME216RomsOnlyMerged/'                                   ),
    ( 0218, 'https://archive.org/download/MAME218RomsOnlyMerged/MAME 0.218 ROMs (merged).zip/'      ),
    ( 0220, 'https://archive.org/download/MAME220RomsOnlyMerged/'                                   ),
   #( 0221, 'https://archive.org/download/MAME221RomsOnlyMerged/'                                   ),
   #( 0221, 'https://archive.org/download/mame-0.221-roms-merged/'                                  ),
   #( 0221, 'https://archive.org/download/mame_0.221_roms/mame_0.221_roms.zip/'                     ),
   #( 0222, 'https://archive.org/download/MAME222RomsOnlyMerged/'                                   ),
   #( 0223, 'https://archive.org/download/MAME223RomsOnlyMerged/'                                   ),
    ( 0224, 'https://archive.org/download/mame0.224/'                                               ),
   #( 0224, 'https://archive.org/download/MAME_0.224_ROMs_merged/'                                  ),
    ( 0229, 'https://archive.org/download/mame.0229/'                                               ),
   #( 0236, 'https://archive.org/download/mame-0.236-roms-split/MAME 0.236 ROMs (split)/'           ),
   #( 0240, 'https://archive.org/download/mame.0240/'                                               ),
   #( 0245, 'https://archive.org/download/mame.0245.revival/'                                       ),
   #( 0245, 'https://archive.org/download/mame-0.245-roms-split/MAME 0.245 ROMs (split)/'           ),
   #( 0251, 'https://archive.org/download/mame251/'                                                 ),
   #( 0252, 'https://archive.org/download/mame-chds-roms-extras-complete/MAME 0.252 ROMs (merged)/' ),
   #( 0254, 'https://archive.org/download/mame-chds-roms-extras-complete/MAME 0.254 ROMs (merged)/' ),
   #( 0256, 'https://archive.org/download/mame-chds-roms-extras-complete/MAME 0.256 ROMs (merged)/' ),
    ( 0259, 'https://archive.org/download/mame-merged/mame-merged/'                                 ),
   #( 0271, 'https://bda.retroroms.net/downloads/mame/mame-0271-full/'                              ), # login required
   #( 9999, 'https://bda.retroroms.net/downloads/mame/currentroms/'                                 ), # login required
    ( 9999, 'https://archive.org/download/2020_01_06_fbn/roms/arcade.zip/arcade/'                   ),
    ( 9999, 'https://downloads.retrostic.com/roms/'                                                 ),
    ( 9999, 'https://archive.org/download/fbnarcade-fullnonmerged/arcade/'                          ),
    ( 9999, 'https://www.doperoms.org/files/roms/mame/GETFILE_'                                     ) # without '/', archive.zip leads to 'GETFILE_archive.zip')
  )
  # list of ROMs not downloadable from URLs above, using dedicated download URLs
  $romlookup=@(
   #( 'combh.zip',          'https://downloads.retrostic.com/roms/combatsc.zip'                                    ), #bad MD5
   #( 'combh.zip',          'https://archive.org/download/mame-0.236-roms-split/MAME 0.236 ROMs (split)/combh.zip' ), #bad MD5
   #( 'clubpacm.zip',       'https://downloads.retrostic.com/roms/clubpacm.zip'                                    ), #bad MD5
   #( 'clubpacm.zip',       'https://archive.org/download/mame251/clubpacm.zip'                                    ), #bad MD5
   #( 'journey.zip',        'https://archive.org/download/MAME216RomsOnlyMerged/journey.zip'                       ), #bad MD5
   #( 'journey.zip',        'https://downloads.retrostic.com/roms/journey.zip'                                     ), #bad MD5
   #( 'journey.zip',        'https://mdk.cab/download/split/journey'                                               ), #bad MD5
   #( 'wbml.zip',           'https://archive.org/download/MAME224RomsOnlyMerged/wbml.zip'                          ), #bad MD5
   #( 'wbml.zip',           'https://downloads.retrostic.com/roms/wbml.zip'                                        ), #missing files
   #( 'wbml.zip',           'https://archive.org/download/mame.0229/wbml.zip'                                      ), #bad MD5
   #( 'wbml.zip',           'https://downloads.romspedia.com/roms/wbml.zip'                                        ), #missing files
   #( 'xevious.zip',        'https://downloads.retrostic.com/roms/xevious.zip'                                     ), #bad MD5
   #( 'xevious.zip',        'https://archive.org/download/2020_01_06_fbn/roms/arcade.zip/arcade/xevious.zip'       ), #bad MD5
   #( 'xevious.zip',        'https://archive.org/download/MAME216RomsOnlyMerged/xevious.zip'                       ), #bad MD5
   #( 'xevious.zip',        'https://mdk.cab/download/split/xevious'                                               ), #missing files
    ( 'airduel.zip',        'https://www.doperoms.org/files/roms/mame/GETFILE_airduel.zip'                         ), #ok
    ( 'neocdz.zip',         'https://archive.org/download/mame-0.221-roms-merged/neocdz.zip'                       ), #ok
    ( 'neogeo.zip',         'https://github.com/Abdess/retroarch_system/raw/libretro/Arcade/neogeo.zip'            ), #ok
    ( 'roadfu.zip',         'https://archive.org/download/mame0.224/roadfu.zip'                                    ), #ok
    ( 'irrmaze.zip',        'https://www.doperoms.org/files/roms/mame/GETFILE_irrmaze.zip'                         ), #ok
    ( 'zaxxon_samples.zip', 'https://www.arcadeathome.com/samples/zaxxon.zip'                                      ), #ok
    ( 'jtbeta.zip',         'https://archive.org/download/jtkeybeta/beta.zip'                                      )  #https://twitter.com/jtkeygetterscr1/status/1403441761721012224?s=20&t=xvNJtLeBsEOr5rsDHRMZyw
  )

  if ($zips.length -gt 0) {
    # download zips from list
    foreach ($zip in $zips) {
      # 1st: fetch from special urls if found in lookup table
      foreach ($rlu in $romlookup) {
        if ($rlu[0] -eq $zip) {
          if (download_url $rlu[1] "$dstroot/$zip") {
            $rlu = $null
          }
          break
        }
      }
      if ($null -eq $rlu) { continue }

      # 2nd: fetch required rom sets from MAME URLs starting with MAME version
      foreach ($rlu in $mameurls) {
        if ($ver -le $rlu[0]) {
          if (download_url "$($rlu[1])$zip" "$dstroot/") {
            $rlu = $null
            break
          }
        }
      }
      if ($null -eq $rlu) { continue }
    }
  }
}


function mra {
  param ( [string]$mrafile,  # $1: .mra file. ROM zip file(s) need to be present in same folder, Output files will be generated into same folder
          [string]$dstpath ) # $2: destination folder for generated files (.rom and .arc)

  # parse informations from .mra file
  $name = (Get-Item -LiteralPath $mrafile).Basename
  $arcname = grep '(?<=<name>)[^<]+' $mrafile
  # replace html codes (known used ones)
  $arcname = $arcname.Replace('&amp;', '&').Replace('&apos;',"'")
  if ($arcname -eq '') { $arcname = $name }
  # replace special characters with '_' (like rom file rename of mra tool)
  $arcname = $($arcname -replace '[//?:]','_').Trim()
  $setname = grep '(?<=<setname>)[^<]+' $mrafile
  if ($setname -eq '') {
    $setname = $name
    # replace special characters (like rom filename rename of mra tool))
    # https://github.com/mist-devel/mra-tools-c/blob/master/src/utils.c#L38
    $setname = $setname -replace '[ ()?.:]','_'
  }
  # trim setname if longer than 16 characters (take 1st 13 characters and last 3 characters (like rom filename trim of mra tool))
  $MAX_ROM_FILENAME_SIZE = 16
  if ($setname.length -gt $MAX_ROM_FILENAME_SIZE) {
    $setname = "$($setname.SubString(0,$MAX_ROM_FILENAME_SIZE-3))$($setname.SubString($setname.length-3))"
  }

  # genrate .rom, .ram and .arc files
  Write-Host "  `'$name.mra`': generating `'$setname.rom`' and `'$name.arc`'"
  &$script:mra -A -O $dstpath -z $MAME_ROMS $mrafile

  # give .rom, .ram and .arc files same timestamp as .mra file
  if (Test-Path -LiteralPath $dstpath/$setname.rom) {
    &$script:touch -r "$mrafile" "$dstpath/$setname.rom"
    #if (Test-Path -LiteralPath $dstpath/$setname.ram) {
    #  &$script:touch -r "$mrafile" "$dstpath/$setname.ram"
    #}
  } else {
    Write-Host -ForegroundColor red "  ERROR: `'$dstpath/$setname.rom`' not found"
  }
  if (Test-Path -LiteralPath $dstpath/$arcname.arc) {
    if ($name -ne $arcname) { Move-Item -LiteralPath $dstpath/$arcname.arc -Destination $dstpath/$name.arc -Force }
    &$script:touch -r "$mrafile" "$dstpath/$name.arc"
  } else {
    Write-Host -ForegroundColor red "  ERROR: `'$dstpath/$arcname.arc`' not found"
  }
}


function process_mra {
  param ( [string]$mrafile,   # $1: source -mra file
          [string]$dstpath,   # $2: destination base folder
          [string]$rbfpath )  # $3: source rbf folder - if empty don't copy .rbf file

  $rbflookup=@(
   #( 'mra .rbf filename reference',                    'real file name'  ),
    ( 'Inferno (Williams)',                             'williams2'       ),
    ( 'Joust 2 - Survival of the Fittest (revision 2)', 'williams2'       ),
    ( 'Mystic Marathon',                                'williams2'       ),
    ( 'Turkey Shoot',                                   'williams2'       ),
    ( 'Power Surge',                                    'time_pilot_mist' ),
    ( 'Time Pilot',                                     'time_pilot_mist' ),
    ( 'Journey',                                        'journey'         )
  )

  # parse informations from .mra file
  # get name (1st: <name> tag information, 2nd: use .mra filename
  $name = grep '(?<=<name>)[^<]+' $mrafile
  if ($name -eq '') { $name = (Get-Item $mrafile).Basename }
  # replace html codes (known used ones)
  $name = $name.Replace('&amp;','&').Replace('&apos;',"'")
  # some name beautification (replace/drop special characters and double/leading/tailing spaces)
  $name = $name -replace '[//]','-'; $name = $name -replace '[?:]',''; $name = $name.Replace('  ',' ').Trim()
  # try to fetch .rbf name: 1st: from <rbf> info, 2nd: from alternative <rbf> info, 3rd: from <name> info (without spaces)
  $rbf = grep '(?<=<rbf>)[^<]+' $mrafile
  if ($rbf -eq '') { $rbf = grep '(?<=<rbf alt=)[^>]+' $mrafile }
  # drop quote characters and make rbf destination filename lowercase
  $rbf = $rbf -replace "['`"]",''; $rbf = $rbf.ToLower()
  if ($rbf -eq '') { $rbf = $name.Replace(' ','') }
  # fetch mame version
  $mamever = grep '(?<=<mameversion>)[^<]+' $mrafile
  # grep list of zip files: 1st: encapsulated in ", 2nd: encapsulated in '
  $zips = grep '(?<=zip=")[^"]+' $mrafile
  if ($zips -eq '') { $zips = grep "(?<=zip=')[^']+" $mrafile }
  $zips = "$zips".Replace(' ','|').Split('|')

  Write-Host "`r`n$(($mrafile | replace-slash).Replace("$GIT_ROOT/",'')) ($name, $rbf, $zips ($mamever)):"
  if ($mamever -eq '') {
    Write-Host -ForegroundColor yellow '  WARNING: Missing mameversion'
    $mamever = '0000'
  }

  # create target folder and set system attribute for this subfolder to be visible in menu core
  makedir $dstpath
  set_system_attr $dstpath

  # create temporary copy of .mra file with correct name
  if ((Split-Path -Path $mrafile) -ne $env:TEMP) {
    sdcopy $mrafile "$env:TEMP/$name.mra"
  }

  # optional copy of core .rbf file
  if ($rbfpath -ne '') {
    # get correct core name
    $rbfpath = $rbfpath.replace('/InWork','').replace('/meta','')
    $srcrbf = $rbf
    # lookup non-matching filenames <-> .rbf name references in .mra file
    foreach ($rlu in $rbflookup ) {
      if ($rlu[0] -eq $name) {
        if (Get-ChildItem "$rbfpath/*.rbf" | Where-Object {$_.name -ieq "$($rlu[1]).rbf"}) {
          $srcrbf = $rlu[1]
          break
        }
      }
    }
    $srcrbf = ((Get-ChildItem "$rbfpath/*.rbf") | Where-Object {$_.name -ieq "$srcrbf.rbf"}).fullname

    # copy .rbf file to destination folder and hide from menu (as .arc file will show up)
    if ($null -ne $srcrbf) {
      sdcopy $srcrbf "$dstpath/$rbf.rbf"
      set_hidden_attr "$dstpath/$rbf.rbf"
    } else {
      Write-Host -ForegroundColor red "  ERROR: `"$rbfpath/$rbf.rbf`" not found"
      Remove-Item -LiteralPath "$env:TEMP/$name.mra"
      if ($null -eq (Get-ChildItem -Force "$dstpath")) { Remove-Item "$dstpath" }
      return
    }
  }

  # generate .rom/.arc files in destination folder
  if ((-not (Test-Path -LiteralPath $dstpath/$name.arc)) `
  -Or ((Get-Item -LiteralPath "$env:TEMP/$name.mra").LastWriteTime -gt (Get-Item -LiteralPath "$dstpath/$name.arc").LastWriteTime) `
  -Or (-not (Test-Path -LiteralPath $dstpath/$name.rom))) {
    # download rom zip archive(s)
    download_mame_roms $MAME_ROMS $mamever $zips
    # generate .rom and .arc file from .mra and .zip files
    mra "$env:TEMP/$name.mra" $dstpath
    Remove-Item -LiteralPath "$env:TEMP/$name.mra"
  }
}


function copy_mra_arcade_cores {
  param ( [string]$mrapath, # $1: src folder for .mra files
          [string]$rbfpath, # $2: src folder for core files
          [string]$dstroot, # $3: destination root folder
          [array[]]$lut )   # $4: optional lookup table for sub folders

  # loop over all .mra files
  foreach ($f in (Get-ChildItem "$mrapath/*.mra" | Sort-Object -Property FullName)) {
    $rbf = grep '(?<=<rbf>)[^<]+' $f
    if ($rbf -eq '') { $rbf = grep '(?<=<rbf alt=)[^>]+' $f }
    $rbf = $rbf -replace "['`"]",''; $rbf = $rbf.ToLower()

    $dstpath = $dstroot
    if ($lut.length -gt 0) {
      # check for dstpath in lookup table for this core
      foreach ($lue in $lut ) {
        foreach ($c in $lue[1]) {
          if ($c -eq $rbf) {
            $dstpath = "$dstpath/$($lue[0])"
            break
          }
        }
      }
    }
    # build target folder from .mra descrition information
    process_mra $f $dstpath $rbfpath
  }
}


function copy_jotego_arcade_cores {
  param ( [string]$dstroot ) # $1: target folder

  Write-Host "`r`n----------------------------------------------------------------------" `
             "`r`nCopy Jotego Cores for `'$SYSTEM`' to `'$dstroot`'" `
             "`r`n----------------------------------------------------------------------`r`n"

  # some lookup to sort games into sub folder (if they don't support the <platform> tag)
  $jtlookup=@(
    ( 'CAPCOM',     @( 'jt1942', 'jt1943',   'jtbiocom', 'jtbtiger', 'jtcommnd', 'jtexed',   'jtf1drm', 'jtgunsmk', 'jthige',
                       'jtpang', 'jtrumble', 'jtsarms',  'jtsf',     'jtsectnz', 'jttrojan', 'jttora',  'jtvulgus' ) ),
    ( 'CPS-2',      @( 'jtcps2'  ) ),
    ( 'CPS-15',     @( 'jtcps15' ) ),
    ( 'CPS-1',      @( 'jtcps1'  ) ),
    ( 'SEGA S16A',  @( 'jts16'   ) ),
    ( 'SEGA S16B',  @( 'jts16b'  ) ),
    ( 'TAITO TNZS', @( 'jtkiwi'  ) )
  )

  # get jotego git
  $srcpath="$GIT_ROOT/jotego"
  clone_or_update_git 'https://github.com/jotego/jtbin.git' $srcpath

  # add non-official mist/sidi cores from somhi repo (not yet part of jotego binaries)
  if ($SYSTEM -ne 'sidi128') {
    $jtname = if ($SYSTEM -eq 'mist') {'jtoutrun_MiST_230312'} else {'jtoutrun_SiDi_20231108'}
    download_url "https://github.com/somhi/jtbin/raw/master/$SYSTEM/$jtname.rbf" "$srcpath/$SYSTEM/jtoutrun.rbf" | Out-Null
    download_url "https://github.com/somhi/jtbin/raw/master/$SYSTEM/jtkiwi.rbf"  "$srcpath/$SYSTEM/" | Out-Null
  }

  # ini file from jotego git
  #sdcopy "$srcpath/arc/mist.ini" "$dstroot/"

  # generate destination arcade folders from .mra and .core files
  foreach ($dir in @(,"$srcpath/mra" | replace-slash) + (Get-ChildItem "$srcpath/mra" -Directory -Recurse | Select-Object -ExpandProperty FullName | Sort-Object | replace-slash)) {
    copy_mra_arcade_cores "$dir" "$srcpath/$SYSTEM" $dstroot $jtlookup
  }
}


function copy_gehstock_mist_cores {
  param ( [string]$dstroot ) # $1: target folder

  Write-Host "`r`n----------------------------------------------------------------------" `
             "`r`nCopy Gehstock Cores for `'mist`' to `'$dstroot`'" `
             "`r`n----------------------------------------------------------------------`r`n"

  # additional ROM/Game copy for some Gehstock cores
  $cores = @(
   #( 'rbf name',         'opt_romcopy_fn' ),
    ( 'AppleII.rbf',      'apple2e_roms'   ),
    ( 'vectrex.rbf',      'vectrex_roms'   )
  )
  # get Gehstock git
  $srcroot="$GIT_ROOT/MiST/gehstock"
  clone_or_update_git 'https://github.com/Gehstock/Mist_FPGA_Cores.git' $srcroot

  # find all cores
  foreach ($rbf in (Get-ChildItem "$srcroot/*.rbf" -Recurse | Sort-Object -Property FullName | replace-slash)) {
    $dir = Split-Path -Path $rbf | replace-slash
    $dst = $dstroot+($dir.Replace($srcroot,'') -ireplace '_MiST', '').Replace('/Arcade/','/Arcade/Gehstock/')
    if (Test-Path "$dir/*.mra") {
      # .mra file(s) in same folder as .rbf file
      copy_mra_arcade_cores $dir $dir $dst
    } elseif (Test-Path "$dir/meta/*.mra") {
      # .mra file(s) in meta subfolder
      copy_mra_arcade_cores "$dir/meta" $dir $dst
    } else {
      # 'normal' .rbf-only core (remove '_MIST' from file name)
      $name = (Split-Path $rbf -Leaf) -ireplace '_MiST', ''
      Write-Host "`r`n$($rbf.Replace("$GIT_ROOT/",'')):"
      sdcopy $rbf "$dst/$name"
      set_system_attr "$dst"
      if (Test-Path "$dir/*.rom") {
        sdcopy "$dir/*.rom" "$dst/"
      }
      # check for additional actions for ROMS/Games
      foreach($item in $cores) {
        $rbf = $item[0]
        $hdl = $item[1]
        if ("$name" -eq "$rbf") {
          # optional rom handling
          if ($null -ne $hdl) {
            &$hdl $dir $dst "$MISC_FILES/$(dst.Split('/')[-1])"
          }
          break
        }
      }
    }
  }
}


function copy_sorgelig_mist_cores {
  param ( [string]$dstroot ) # $1: target folder

  Write-Host "`r`n----------------------------------------------------------------------" `
             "`r`nCopy Sorgelig/PetrM1/nippur72 Cores for `'mist`' to `'$dstroot`'" `
             "`r`n----------------------------------------------------------------------`r`n"

  # additional cores from Alexey Melnikov's (sorgelig) repositories
  $cores=@(
   #( 'dst folder',                    'git url',                                   'core release folder', 'opt_romcopy_fn'   ),
    ( 'Computer/Apogee BK-01',         'https://github.com/sorgelig/Apogee_MIST.git',           'release',  'apogee_roms'      ),
    ( 'Arcade/Sorgelig/Galaga',        'https://github.com/sorgelig/Galaga_MIST.git',           'releases'                     ),
    ( 'Computer/Vector-06',            'https://github.com/sorgelig/Vector06_MIST.git',         'releases'                     ),
    ( 'Computer/Specialist',           'https://github.com/sorgelig/Specialist_MIST.git',       'release'                      ),
    ( 'Computer/Phoenix',              'https://github.com/sorgelig/Phoenix_MIST.git',          'releases'                     ),
    ( 'Computer/BK0011M',              'https://github.com/sorgelig/BK0011M_MIST.git',          'releases'                     ),
    ( 'Computer/Ondra SPO 186',        'https://github.com/PetrM1/OndraSPO186_MiST.git',        'releases', 'ondra_roms'       ),
    ( 'Computer/Laser 500',            'https://github.com/nippur72/Laser500_MiST.git',         'releases', 'laser500_roms'    ),
    ( 'Computer/LM80C Color Computer', 'https://github.com/nippur72/LM80C_MiST.git',            'releases', 'lm80c_roms'       )
   # no release yet for CreatiVision core
   #( 'Computer/CreatiVision',         'https://github.com/nippur72/CreatiVision_MiST.git',     'releases'                     ),
   # other Sorgelig repos are already part of MiST binaries repo
   #( 'Computer/ZX Spectrum 128k',     'https://github.com/sorgelig/ZX_Spectrum-128K_MIST.git', 'releases', 'zx_spectrum_roms' ),
   #( 'Computer/Amstrad CPC 6128',     'https://github.com/sorgelig/Amstrad_MiST.git',          'releases', 'amstrad_roms'     ),
   #( 'Computer/C64',                  'https://github.com/sorgelig/C64_MIST.git',              'releases', 'c64_roms'         ),
   #( 'Computer/PET2001',              'https://github.com/sorgelig/PET2001_MIST.git',          'releases', 'pet2001_roms'     ),
   #( 'Console/NES',                   'https://github.com/sorgelig/NES_MIST.git',              'releases', 'nes_roms'         ),
   #( 'Computer/SAM Coupe',            'https://github.com/sorgelig/SAMCoupe_MIST.git',         'releases', 'samcoupe_roms'    ),
   #( '.',                             'https://github.com/sorgelig/Menu_MIST.git',             'release'                      ),
   #( 'Computer/Apple 1',              'https://github.com/nippur72/Apple1_MiST.git',           'releases'                     ),
  )
  $srcroot="$GIT_ROOT/MiST/sorgelig"
  foreach($item in $cores) {
    $name = $item[1].Replace('/','.').Split('.')[-2] -ireplace '_MiST', ''
    clone_or_update_git $item[1] "$srcroot/$name"
    copy_latest_file "$srcroot/$name/$($item[2])" "$dstroot/$($item[0])/$($item[0].Split('/')[-1]).rbf" '*.rbf'
    set_system_attr "$dstroot/$($item[0])"
    # optional rom handling
    if ($null -ne $item[3]) {
      &$item[3] "$srcroot/$name/$($item[2])" "$dstroot/$($item[0])" "$MISC_FILES/$($item[0].Split('/')[-1])"
    }
  }
}


function copy_sebdel_mist_cores {
  param ( [string]$dstroot ) # $1: target folder

  Write-Host "`r`n----------------------------------------------------------------------" `
             "`r`nCopy Sebastien Delestaing (sebdel) Cores for 'mist' to `'$dstroot`'" `
             "`r`n----------------------------------------------------------------------`r`n"

  $srcpath="$GIT_ROOT/MiST/sebdel"
  clone_or_update_git 'https://github.com/sebdel/mist-cores.git' "$srcpath"

  $comp_cores=@(
   #( 'dst folder',                    'path',                 ),
    ( 'Computer/TRS80 Color Computer', 'trs80/output_files'    ),
    ( 'Console/SD8',                   'sd8/output_files'      ) #??
   # other sebdel core is already part of SiDi binaries repo
   #( 'Computer/Mattel Aquarius',      'aquarius/output_files' ),
  )

  foreach($item in $comp_cores) {
    copy_latest_file "$srcpath/$($item[1])" "$dstroot/$($item[0])/$($item[0].Split('/')[-1]).rbf" '*.rbf'
    set_system_attr "$dstroot/$($item[0])"
  }
}


function copy_joco_mist_cores {
  param ( [string]$dstroot ) # $1: target folder

  Write-Host "`r`n----------------------------------------------------------------------" `
             "`r`nCopy Jozsef Laszlo (joco) Cores for 'mist' to `'$dstroot`'" `
             "`r`n----------------------------------------------------------------------`r`n"

  # MiST Primo files from https://joco.homeserver.hu/fpga/mist_primo_en.html
  $roms=@( 'primo.rbf', 'primo.rom',
           'pmf/astro.pmf', 'pmf/astrob.pmf', 'pmf/galaxy.pmf', 'pmf/invazio.pmf', 'pmf/jetpac.pmf'
  )
  foreach ($f in $roms) {
    download_url "https://joco.homeserver.hu/fpga/download/$f" "$dstroot/Computer/Primo/" | Out-Null
  }
  set_system_attr "$dstroot/Computer/Primo"

  # other joco cores are already part of MiST binaries repo
}


function copy_eubrunosilva_sidi_cores {
  param ( [string]$dstroot ) # $1: target folder

  Write-Host "`r`n----------------------------------------------------------------------" `
             "`r`nCopy eubrunosilva Cores for `'sidi`' to `'$dstroot`'" `
             "`r`n----------------------------------------------------------------------`r`n"

  # get eubrunosilva git
  $srcpath = "$GIT_ROOT/SiDi/eubrunosilva"
  clone_or_update_git 'https://github.com/eubrunosilva/SiDi.git' $srcpath

  # generate destination arcade folders from .mra and .core files
  copy_mra_arcade_cores "$srcpath/Arcade" "$srcpath/Arcade" "$dstroot/Arcade/eubrunosilva"

  # additional Computer cores from eubrunosilva repos (which aren't in ManuFerHi's repo)
  $comp_cores=@(
   #( 'dst folder',                       'pattern',       'opt_rom_copy_fn' ),
    ( 'Computer/Apogee BK-01',            'Apoge',         'apogee_roms'     ),
    ( 'Computer/Chip-8',                  'Chip8'                            ),
    ( 'Computer/HT1080Z School Computer', 'trs80',         'ht1080z_roms'    ),
    ( 'Computer/Microcomputer',           'Microcomputer'                    ),
    ( 'Computer/Specialist',              'Specialist'                       ),
    ( 'Computer/Vector-06',               'Vector06'                         )
   # other eubrunosilva cores are already part of SiDi binaries repo
   #( 'Computer/Amstrad',                 'Amstrad',       'amstrad_roms'    ),
   #( 'Computer/Apple Macintosh',         'plusToo',       'plus_too_roms'   ),
   #( 'Computer/Archimedes',              'Archie',        'archimedes_roms' ),
   #( 'Computer/Atari STe',               'Mistery',       'atarist_roms'    ),
   #( 'Computer/BBC Micro',               'bbc',           'bbc_roms'        ),
   #( 'Computer/BK0011M',                 'BK0011M'                          ),
   #( 'Computer/C16',                     'c16',           'c16_roms'        ),
   #( 'Computer/C64',                     'c64',           'c64_roms'        ),
   #( 'Computer/Mattel Aquarius',         'Aquarius'                         ),
   #( 'Computer/MSX1',                    'MSX',           'msx1_roms'       ),
   #( 'Computer/Oric',                    'Oric',          'oric_roms'       ),
   #( 'Computer/PET2001',                 'Pet2001',       'pet2001_roms'    ),
   #( 'Computer/SAM Coupe',               'SAMCoupe',      'samcoupe_roms'   ),
   #( 'Computer/Sinclair QL',             'QL',            'ql_roms'         ),
   #( 'Computer/VIC20',                   'VIC20',         'vic20_roms'      ),
   #( 'Computer/ZX Spectrum 128k',        'Spectrum128k'                     ),
   #( 'Computer/ZX8x',                    'ZX8x',          'zx8x_roms'       )
  )

  foreach($item in $comp_cores) {
    copy_latest_file "$srcpath/Computer" "$dstroot/$($item[0])/$($item[0].Split('/')[-1]).rbf" "$($item[1])*.rbf"
    set_system_attr "$dstroot/$($item[0])"
    # optional rom handling
    if ($null -ne $item[2]) {
      &$item[2] "$srcpath/Computer" "$dstroot/$($item[0])" "$MISC_FILES/$($item[0].Split('/')[-1])"
    }
  }
}


# handlers for core specific ROM actions. $1=core src directory, $2=sd core dst directory, $3=core specific cache folder
function amiga_roms         { param($1,$2,$3)
                              sdcopy "$1/AROS.ROM" "$2/kick/aros.rom"
                              sdcopy "$1/HRTMON.ROM" "$SD_ROOT/hrtmon.rom"
                              sdcopy "$1/MinimigUtils.adf" "$2/adf/"
                              expand "$1/minimig_boot_art.zip" "$SD_ROOT/"
                              $kicks=@('https://archive.org/download/Older_Computer_Environments_and_Operating_Systems/Amiga.zip/Amiga/Amiga Kickstart Roms - Complete - TOSEC v0.04/KS-ROMs/Kickstart v1.3 rev 34.5 (1987)(Commodore)(A500-A1000-A2000-CDTV).rom',
                                       'https://archive.org/download/Older_Computer_Environments_and_Operating_Systems/Amiga.zip/Amiga/Amiga Kickstart Roms - Complete - TOSEC v0.04/KS-ROMs/Kickstart v2.04 rev 37.175 (1991)(Commodore)(A500+).rom',
                                       'https://archive.org/download/Older_Computer_Environments_and_Operating_Systems/Amiga.zip/Amiga/Amiga Kickstart Roms - Complete - TOSEC v0.04/KS-ROMs/Kickstart v2.05 rev 37.300 (1991)(Commodore)(A600HD).rom',
                                       'https://archive.org/download/Older_Computer_Environments_and_Operating_Systems/Amiga.zip/Amiga/Amiga Kickstart Roms - Complete - TOSEC v0.04/KS-ROMs/Kickstart v3.1 rev 40.63 (1993)(Commodore)(A500-A600-A2000).rom',
                                       'https://archive.org/download/Older_Computer_Environments_and_Operating_Systems/Amiga.zip/Amiga/Amiga Kickstart Roms - Complete - TOSEC v0.04/KS-ROMs/Kickstart v3.1 rev 40.68 (1993)(Commodore)(A1200).rom',
                                       'https://archive.org/download/Older_Computer_Environments_and_Operating_Systems/Amiga.zip/Amiga/Amiga Kickstart Roms - Complete - TOSEC v0.04/KS-ROMs/Kickstart v3.1 rev 40.70 (1993)(Commodore)(A4000).rom'
                                      )
                              foreach ($f in $kicks) {
                                download_url "$f" "$3/kick/" | Out-Null; sdcopy "$3/kick/$($f.Split('/')[-1])" "$2/kick/"
                              }
                              $adfs= @('https://archive.org/download/commodore-amiga-operating-systems-workbench/Workbench v3.1 rev 40.42 (1994)(Commodore)(M10)(Disk 1 of 6)(Install)[!].zip',
                                       'https://archive.org/download/commodore-amiga-operating-systems-workbench/Workbench v3.1 rev 40.42 (1994)(Commodore)(M10)(Disk 2 of 6)(Workbench)[!].zip',
                                       'https://download.freeroms.com/amiga_roms/t/turrican.zip',
                                       'https://download.freeroms.com/amiga_roms/t/turrican2.zip',
                                       'https://download.freeroms.com/amiga_roms/t/turrican3.zip',
                                       'https://download.freeroms.com/amiga_roms/a/agony.zip'
                                      )
                              foreach ($f in $adfs) {
                                download_url "$f" "$3/adf/" | Out-Null; expand "$3/adf/$($f.Split('/')[-1])" "$2/adf/"
                              }
                              $hdfs=@( 'https://archive.org/download/amigaromset/CommodoreAmigaRomset1.zip/MonkeyIsland2_v1.1_De_0077.hdf'
                                     )
                              foreach ($f in $hdfs) {
                                download_url "$f" "$3/hdf/" | Out-Null; sdcopy "$3/hdf/$($f.Split('/')[-1])" "$2/hdf/"
                              }
                              # use Kickstart 1.3 as default kick.rom
                              sdcopy "$2/kick/Kickstart v3.1 rev 40.68 (1993)(Commodore)(A1200).rom" "$SD_ROOT/kick.rom"
                            }
function amstrad_roms       { param ($1,$2,$3)
                              if ($SYSTEM -eq 'mist') { sdcopy "$1/ROMs/*.e*" "$SD_ROOT/" } else { sdcopy "$1/amstrad.rom" "$SD_ROOT/" }
                              download_url 'https://github.com/mist-devel/mist-binaries/raw/master/cores/amstrad/ROMs/AST-Equinox.dsk' "$3/" | Out-Null
                              sdcopy "$3/AST-Equinox.dsk" "$SD_ROOT/amstrad/AST-Equinox.dsk" # roms are presented by core from /amstrad folder
                              $games=@('https://www.amstradabandonware.com/mod/upload/ams_de/games_disk/cyberno2.zip',
                                       'https://www.amstradabandonware.com/mod/upload/ams_de/games_disk/supermgp.zip'
                                      )
                              foreach ($f in $games) {
                                download_url "$f" "$3/" | Out-Null; expand "$3/$($f.Split('/')[-1])" "$SD_ROOT/amstrad/"
                              }
                            }
function apogee_roms        { param ($1,$2,$3) sdcopy "$1/../extra/apogee.rom" "$2/" }
function apple1_roms        { param ($1,$2,$3)
                              if ($SYSTEM -eq 'mist') {
                                sdcopy "$1/BASIC.e000.prg" "$2/"
                                sdcopy "$1/DEMO40TH.0280.prg" "$2/"
                              }
                            }
function apple1_roms_alt    { param ($1,$2,$3)
                              download_url 'https://github.com/mist-devel/mist-binaries/raw/master/cores/apple1/BASIC.e000.prg' "$2/" | Out-Null
                              download_url 'https://github.com/mist-devel/mist-binaries/raw/master/cores/apple1/DEMO40TH.0280.prg' "$2/" | Out-Null
                            }
function apple2e_roms       { param ($1,$2,$3)
                              download_url 'https://mirrors.apple2.org.za/Apple II Documentation Project/Computers/Apple II/Apple IIe/ROM Images/Apple IIe Enhanced Video ROM - 342-0265-A - US 1983.bin' "$2/" | Out-Null
                              download_url 'https://archive.org/download/PitchDark/Pitch-Dark-20210331.zip' "$3/" | Out-Null
                              expand "$3/Pitch-Dark-20210331.zip" "$2/"
                            }
function apple2p_roms       { param ($1,$2,$3)
                              download_url 'https://github.com/wsoltys/mist-cores/raw/master/apple2fpga/apple_II.rom' "$2/" | Out-Null
                              download_url 'https://github.com/wsoltys/mist-cores/raw/master/apple2fpga/bios.rom' "$2/" | Out-Null
                            }
function archimedes_roms    { param ($1,$2,$3)
                              sdcopy "$1/SVGAIDE.RAM" "$SD_ROOT/svgaide.ram"
                              expand "$1/RiscDevIDE.zip" "$2/"
                              download_url 'https://github.com/MiSTer-devel/Archie_MiSTer/raw/master/releases/riscos.rom' "$SD_ROOT/" | Out-Null
                              download_url 'https://github.com/mist-devel/mist-binaries/raw/master/cores/archimedes/archie1.zip' "$3/" | Out-Null
                              expand "$3/archie1.zip" "$SD_ROOT/"
                            }
function atarist_roms       { param ($1,$2,$3)
                              download_url 'https://github.com/mist-devel/mist-binaries/raw/master/cores/mist/tos.img' "$SD_ROOT/" | Out-Null
                              download_url 'https://github.com/mist-devel/mist-binaries/raw/master/cores/mist/system.fnt' "$SD_ROOT/" | Out-Null
                              download_url 'https://github.com/mist-devel/mist-binaries/raw/master/cores/mist/disk_a.st' "$2/" | Out-Null
                            }
function atari800_roms      { param ($1,$2,$3) sdcopy "$1/A800XL.ROM" "$2/a800xl.rom" }
function atari2600_roms     { param ($1,$2,$3)
                              download_url 'https://static.emulatorgames.net/roms/atari-2600/Asteroids (1979) (Atari) (PAL) [!].zip' "$3/" | Out-Null
                              download_url 'https://download.freeroms.com/atari_roms/starvygr.zip' "$3/" | Out-Null
                              expand "$3/Asteroids (1979) (Atari) (PAL) [!].zip" "$SD_ROOT/ma2601/" # roms are presented by core from /MA2601 folder
                              expand "$3/starvygr.zip" "$SD_ROOT/ma2601/"
                            }
function atari5200_roms     { param ($1,$2,$3)
                              download_url 'https://downloads.romspedia.com/roms/Asteroids (1983) (Atari).zip' "$3/" | Out-Null
                              expand "$3/Asteroids (1983) (Atari).zip" "$SD_ROOT/a5200/" # roms are presented by core from /A5200 folder
                            }
function atari7800_roms     { param ($1,$2,$3)
                              download_url 'https://archive.org/download/Atari7800FullRomCollectionReuploadByDataghost/Atari 7800.7z' "$3/" | Out-Null
                              expand "$3/Atari 7800.7z" "$3/"
                              makedir "$SD_ROOT/a7800"
                              sdcopy "$3/Atari 7800/*" "$SD_ROOT/a7800/"
                            }
function bbc_roms           { param ($1,$2,$3)
                              sdcopy "$1/bbc.rom" "$2/"
                              download_url 'https://github.com/ManuFerHi/SiDi-FPGA/raw/master/Cores/Computer/BBC/BBC.vhd' "$3/" | Out-Null
                              sdcopy "$3/BBC.vhd" "$2/"
                              download_url 'https://www.stardot.org.uk/files/mmb/higgy_mmbeeb-v1.2.zip' "$3/" | Out-Null
                              expand "$3/higgy_mmbeeb-v1.2.zip" "$3/beeb/"
                              sdcopy "$3/beeb/BEEB.MMB" "$2/BEEB.ssd"
                              Remove-Item "$2/beeb" -Recurse -Force
                            }
function bk001m_roms        { param ($1,$2,$3) sdcopy "$1/bk0011m.rom" "$2/" }
function c16_roms           { param ($1,$2,$3)
                              sdcopy "$1/c16.rom" "$2/"
                              download_url 'https://www.c64games.de/c16/spiele/boulder_dash_3.prg' "$3/" | Out-Null
                              download_url 'https://www.c64games.de/c16/spiele/giana_sisters.prg' "$3/" | Out-Null
                              sdcopy "$3/boulder_dash_3.prg" "$SD_ROOT/c16/" # roms are presented by core from /C16 folder
                              sdcopy "$3/giana_sisters.prg" "$SD_ROOT/c16/"
                            }
function c64_roms           { param ($1,$2,$3)
                              sdcopy "$1/c64.rom" "$2/"
                              if ($SYSTEM -eq 'mist') { sdcopy "$1/C64GS.ARC" "$2/C64GS.arc" }
                              download_url 'https://csdb.dk/getinternalfile.php/67833/giana sisters.prg' "$3/" | Out-Null
                              #curl -O "$2/roms/SuperZaxxon.zip" -d 'id=727332&download=Télécharger' 'https://www.planetemu.net/php/roms/download.php'
                              download_url 'https://www.c64.com/games/download.php?id=315' "$3/zaxxon.zip" | Out-Null
                              download_url 'https://www.c64.com/games/download.php?id=2073' "$3/super_zaxxon.zip" | Out-Null
                              sdcopy "$3/giana sisters.prg" "$SD_ROOT/c64/" # roms are presented by core from /C64 folder
                              expand "$3/zaxxon.zip" "$SD_ROOT/c64/"
                              expand "$3/super_zaxxon.zip" "$SD_ROOT/c64/"
                            }
function coco2_roms         { param ($1,$2,$3) copy_mra_arcade_cores "$1" '' "$2" }
function coco3_roms         { sdcopy "$1/COCO3.ROM" "$2/coco3.rom" }
function enterprise_roms    { param ($1,$2,$3)
                              sdcopy "$1/ep128.rom" "$2/"
                              if (-not ( Test-Path "$2/ep128.vhd")) {
                                download_url 'http://www.ep128.hu/Emu/Ep_ide192m.rar' "$3/" | Out-Null
                                expand "$3/Ep_ide192m.rar" "$3/"
                                Move-Item "$3/Ep_ide192m.vhd" "$2/ep128.vhd"
                              }
                            }
function gameboy_roms       { param ($1,$2,$3)
                              download_url 'https://archive.org/download/mister-console-bios-pack_theypsilon/MiSTer_Console_BIOS_PACK.zip/Gameboy.zip' "$3/" | Out-Null
                              expand "$3/Gameboy.zip" "$2/roms/"
                            }
function ht1080z_roms       { param ($1,$2,$3)
                              if ($SYSTEM -eq 'mist') {
                                sdcopy "$1/HT1080Z.ROM" "$2/ht1080z.rom"
                              } else {
                                download_url 'https://joco.homeserver.hu/fpga/download/HT1080Z.ROM' "$2/ht1080z.rom" | Out-Null
                              }
                            }
function intellivision_roms { param ($1,$2,$3) sdcopy "$1/intv.rom" "$2/" }
function laser500_roms      { param ($1,$2,$3) sdcopy "$1/laser500.rom" "$2/" }
function lm80c_roms         { param ($1,$2,$3) sdcopy "$1/lm80c.rom" "$2/" }
function lynx_roms          { param ($1,$2,$3) download_url 'https://archive.org/download/mister-console-bios-pack_theypsilon/MiSTer_Console_BIOS_PACK.zip/AtariLynx.zip' "$2/" | Out-Null
                              expand "$2/AtariLynx.zip" "$2/"
                            }
function menu_image         { param ($1,$2,$3) download_url 'https://github.com/mist-devel/mist-binaries/raw/master/cores/menu/menu.rom' "$2/" | Out-Null }
function msx1_roms          { param ($1,$2,$3) expand "$1/MSX1_vhd.rar" "$2/" }
function msx2p_roms         { param ($1,$2,$3); return; }
function neogeo_roms        { param ($1,$2,$3)
                              if ($SYSTEM -eq 'mist') {
                                copy_mra_arcade_cores "$1/bios" '' "$2"
                              } else {
                                #download_url 'https://api.github.com/repos/mist-devel/mist-binaries/contents/cores/neogeo/bios' "$3/" # doesn't work here
                                #foreach($f in $(grep '(?<="name": ")[^*]*.mra' "$3/bios.urls")) {
                                $mras=@('Europe MVS (Ver. 2).mra', 'Irritating Maze.mra', 'Universe BIOS (Hack, Ver. 3.3) (CD).mra',
                                        'Universe BIOS (Hack, Ver. 3.3).mra', 'Universe BIOS (Hack, Ver. 4.0).mra' )
                                foreach($f in $mras) {
                                  download_url "https://github.com/mist-devel/mist-binaries/raw/refs/heads/master/cores/neogeo/bios/$f" "$3/"
                                }
                                copy_mra_arcade_cores "$3/" '' "$2"
                              }
                              set_hidden_attr "$2/NeoGeo.rbf"
                              makedir "$SD_ROOT/neogeo"
                              if (-not (Test-Path "$SD_ROOT/neogeo/neogeo.vhd")) {
                                if ($isLinux) {
                                  &dd if=/dev/zero of="$SD_ROOT/neogeo/neogeo.vhd" bs=8k count=1
                                } else {
                                  &fsutil file createnew "$SD_ROOT/neogeo/neogeo.vhd" 8192
                                }
                              }
                              download_url 'https://archive.org/download/1-g-1-r-terra-onion-snk-neo-geo/1G1R - TerraOnion - SNK - Neo Geo.zip/maglord.neo' "$SD_ROOT/neogeo/Magician Lord.neo" | Out-Null
                              download_url 'https://archive.org/download/1-g-1-r-terra-onion-snk-neo-geo/1G1R - TerraOnion - SNK - Neo Geo.zip/twinspri.neo' "$SD_ROOT/neogeo/Twinkle Star Sprites.neo"  | Out-Null
                            }
function nes_roms           { param ($1,$2,$3)
                              download_url 'https://www.nesworld.com/powerpak/powerpak130.zip' "$3/" | Out-Null
                              expand "$3/powerpak130.zip" "$3/"
                              sdcopy "$3/POWERPAK/FDSBIOS.BIN" "$2/fdsbios.bin"
                              Remove-Item "$3/POWERPAK" -Recurse -Force
                              download_url 'https://info.sonicretro.org/images/f/f8/SonicTheHedgehog(Improvment+Tracks).zip' "$3/" | Out-Null
                              expand "$3/SonicTheHedgehog(Improvment+Tracks).zip" "$SD_ROOT/nes/"
                              download_url 'https://archive.org/download/nes-romset-ultra-us/Super Mario Kart Raider (Unl) [!].zip' "$3/" | Out-Null
                              expand "$3/Super Mario Kart Raider (Unl) [!].zip" "$SD_ROOT/nes/"
                            }
function next186_roms       { param ($1,$2,$3)
                              sdcopy "$1/Next186.ROM" "$2/next186.rom"
                              download_url 'https://archive.org/download/next-186.vhd/Next186.vhd.zip' "$3/" | Out-Null
                              expand "$3/Next186.vhd.zip" "$SD_ROOT/"
                              Remove-Item "$SD_ROOT/__MACOSX" -Recurse -Force
                            }
function nintendo_sysattr   { param ($1,$2,$3) set_system_attr "$2/Nintendo hardware" }
function ondra_roms         { param ($1,$2,$3)
                              download_url 'https://docs.google.com/uc?export=download&id=1seHwftKzaBWHR4sSZVJLq7IKw-ZLafei' "$3/OndraSD.zip" | Out-Null
                              expand "$3/OndraSD.zip" "$3/Ondra/"
                              sdcopy "$3/Ondra/__LOADER.BIN" "$SD_ROOT/ondra/__loader.bin"
                              sdcopy "$3/Ondra/_ONDRAFM.BIN" "$SD_ROOT/ondra/_ondradm.bin"
                              Remove-Item "$3/Ondra" -Recurse -Force
                            }
function oric_roms          { param ($1,$2,$3)
                              if ($SYSTEM -eq 'mist') { sdcopy "$1/oric.rom" "$2/" }
                              $urls=@(('https://github.com/rampa069/Oric_Mist_48K/raw/master/dsk', `
                                          @( '1337_dsk.dsk','B7es_dsk.dsk','ElPrisionero.dsk','Oricium12_edsk.dsk','SEDO40u_DSK.dsk','Torreoscura.dsk', 'space1999-en_dsk.dsk' )),
                                      ('https://github.com/teiram/oric-dsk-manager/raw/master/src/test/resources', `
                                          @( 'space1999-en_dsk.dsk','BuggyBoy.dsk','barbitoric.dsk','oricdos.dsk','xenon1.new.dsk','xenon1.old.dsk' ))
                                     )
                              foreach ($u in $urls) {
                                foreach ($f in $u[1]) {
                                  download_url "$($u[0])/$f" "$SD_ROOT/oric/" | Out-Null
                                }
                              }
                            }
function pcxt_roms          { param ($1,$2,$3)
                              download_url 'https://github.com/MiSTer-devel/PCXT_MiSTer/raw/main/games/PCXT/hd_image.zip' "$3/" | Out-Null
                              expand "$3/hd_image.zip" "$3/"
                              Move-Item "$3/Freedos_HD.vhd" -Destination "$2/PCXT.HD0" -Force
                              #download_url 'https://github.com/640-KB/GLaBIOS/releases/download/v0.2.4/GLABIOS_0.2.4_8T.ROM' "$2/" | Out-Null
                              download_url 'https://github.com/somhi/PCXT_DeMiSTify/raw/main/SW/ROMs/pcxt_pcxt31.rom' "$2/" | Out-Null
                            }
function pet2001_roms       { param ($1,$2,$3) download_url 'https://github.com/mist-devel/mist-binaries/raw/master/cores/pet2001/pet2001.rom' "$2/" | Out-Null }
function plus_too_roms      { param ($1,$2,$3) download_url 'https://github.com/ManuFerHi/SiDi-FPGA/raw/master/Cores/Computer/Plus_too/plus_too.rom' "$2/" | Out-Null
                              expand "$1/hdd_empty.zip" "$2/"
                            }
function psx_roms           { param ($1,$2,$3) download_url 'https://ps1emulator.com/SCPH1001.BIN' "$2/games/PSX/boot.rom" | Out-Null
                              download_url 'https://github.com/MiSTer-devel/PSX_MiSTer/raw/main/memcard/empty.mcd' "$2/"
                            }
function ql_roms            { param ($1,$2,$3)
                              sdcopy "$1/*.rom" "$2/"
                              download_url 'https://github.com/mist-devel/mist-binaries/raw/master/cores/ql/QL-SD.zip' "$3/" | Out-Null
                              expand "$3/QL-SD.zip" "$2/"
                            }
function samcoupe_roms      { param ($1,$2,$3) sdcopy "$1/samcoupe.rom" "$2/" }
function sidi128_arcade     { param ($1,$2,$3) makedir "$2/"; sdcopy "$1/*.rbf" "$2/" }
function snes_roms          { param ($1,$2,$3) download_url 'https://archive.org/download/mister-console-bios-pack_theypsilon/MiSTer_Console_BIOS_PACK.zip/SNES.zip' "$3/" | Out-Null
                              expand "$3/SNES.zip" "$2/"
                              download_url 'https://nesninja.com/downloadssnes/Super Mario World (U) [!].smc' "$3/" | Out-Null
                              sdcopy "$3/Super Mario World (U) [!].smc" "$SD_ROOT/snes/"
                            }
function sourcerer_roms     { param ($1,$2,$3) download_url 'https://archive.org/download/year-based-collection-of-games-for-the-exidy-sorcerer-v-1.0/Year-Based Collection of Games for the Exidy Sorcerer v1.0.zip' "$3/" | Out-Null
                              expand "$3/Year-Based Collection of Games for the Exidy Sorcerer v1.0.zip" "$2/"
                            }
function speccy_roms        { param ($1,$2,$3) sdcopy "$1/speccy.rom" "$2/" }
function ti994a_roms        { param ($1,$2,$3) sdcopy "$1/TI994A.ROM" "$2/ti994a.rom" }
function tnzs_roms          { param ($1,$2,$3)
                              $kiwis=@( "Arkanoid - Revenge of DOH (World).mra",
                                        "Dr. Toppel's Adventure (World).mra",
                                        "Extermination (World).mra",
                                        "Insector X (World).mra",
                                        "Kageki (World).mra",
                                        "The NewZealand Story (World, new version) (P0-043A PCB).mra"
                                       )
                              foreach ($f in $kiwis) {
                                download_url "https://github.com/jotego/jtbin/raw/master/mra/$f" "$3/" | Out-Null
                              }
                              copy_mra_arcade_cores "$3" '' "$2"
                            }
function tsconf_roms        {  param ($1,$2,$3)
                              sdcopy "$1/TSConf.r*" "$SD_ROOT/"
                              if (Test-Path "$1/TSConf.vhd.zip") {
                                expand "$1/TSConf.vhd.zip" "$SD_ROOT/"
                              } else {
                                download_url "https://github.com/mist-devel/mist-binaries/raw/master/cores/tsconf/TSConf.vhd.zip" "$3/" | Out-Null
                                expand "$3/TSConf.vhd.zip" "$SD_ROOT/"
                              }
                            }
function turbogfx_roms      { param ($1,$2,$3)
                              download_url 'https://archive.org/download/mister-console-bios-pack_theypsilon/MiSTer_Console_BIOS_PACK.zip/TurboGrafx16.zip' "$3/" | Out-Null
                              expand "$3/TurboGrafx16.zip" "$3/"
                              sdcopy "$3/TurboGrafx16/*" "$2/"
                              Remove-Item -Path "$3/TurboGrafx16/" -Recurse -Force
                            }
function tvc_roms()         { param ($1,$2,$3) sdcopy "$1/tvc.rom" "$2/" }
function vectrex_roms       { param ($1,$2,$3)
                              download_url 'https://archive.org/download/VectrexROMS/Vectrex_ROMS.zip' "$3/" | Out-Null
                              expand "$3/Vectrex_ROMS.zip" "$3/"
                              foreach ($arc in (Get-ChildItem "$3/*.7z" | Sort-Object -Property FullName)) {
                                expand $arc "$SD_ROOT/vectrex/"
                              }
                            }
function vic20_roms         { param ($1,$2,$3) sdcopy "$1/vic20.rom" "$2/" }
function videopac_roms      { param ($1,$2,$3)
                              download_url 'https://archive.org/download/Philips_Videopac_Plus_TOSEC_2012_04_23/Philips_Videopac_Plus_TOSEC_2012_04_23.zip' "$3/" | Out-Null
                              expand "$3/Philips_Videopac_Plus_TOSEC_2012_04_23.zip" "$3/"
                              $zippath = "$3/Philips Videopac+ [TOSEC]/Philips Videopac+ - Games (TOSEC-v2011-02-22_CM)"
                              foreach ($zip in (Get-ChildItem -LiteralPath $zippath -Include '*.zip' | Select-Object  -ExpandProperty FullName | Sort-Object )) {
                                expand "$zip" "$SD_ROOT/videopac/"
                              }
                            }
function x68000_roms        { param ($1,$2,$3) sdcopy "$1/X68000.rom" "$2/"; sdcopy "$1/BLANK_disk_X68000.D88" "$2/"; }
function zx8x_roms          { param ($1,$2,$3) download_url 'https://github.com/ManuFerHi/SiDi-FPGA/raw/master/Cores/Computer/ZX8X/zx8x.rom' "$2/" | Out-Null }
function zx_spectrum_roms   { param ($1,$2,$3) sdcopy "$1/spectrum.rom" "$2/" }
function bagman_roms        { param ($1,$2,$3)
                              download_url 'https://github.com/Gehstock/Mist_FPGA/raw/master/Arcade_MiST/Bagman Hardware/meta/Super Bagman.mra' "$env:TEMP/" | Out-Null
                              process_mra "$env:TEMP/Super Bagman.mra" "$2"
                            }

$cores=@(
 #( 'core dst dir',                                   'src dir MiST',  'src dir SiDi',                                      'opt_romcopy_fn'      ),
 # Main Menu
  ( '.',                                              'menu',          'menu',                                              'menu_image'           ),
 # Computers
  ( 'Computer/Amstrad CPC',                           'amstrad',       'Computer/AmstradCPC',                               'amstrad_roms'         ),
  ( 'Computer/Amstrad PCW',                           '',              'Computer/AmstradPCW'                                                       ),
  ( 'Computer/Amiga',                                 'minimig-aga',   'Computer/Amiga',                                    'amiga_roms'           ),
  ( 'Computer/Apple I',                               'apple1',        'Computer/AppleI',                                   'apple1_roms'          ),
  ( 'Computer/Apple IIe',                             'appleIIe',      'Computer/AppleIIe',                                 'apple2e_roms'         ),
  ( 'Computer/Apple II+',                             'appleii+',      'Computer/AppleII+',                                 'apple2p_roms'         ),
  ( 'Computer/Apple Macintosh',                       'plus_too',      'Computer/Plus_too',                                 'plus_too_roms'        ),
  ( 'Computer/Archimedes',                            'archimedes',    'Computer/Archimedes',                               'archimedes_roms'      ),
  ( 'Computer/Atari 800',                             'atari800',      'Computer/Atari800',                                 'atari800_roms'        ),
  ( 'Computer/Atari ST',                              'mist',          'Computer/AtariST',                                  'atarist_roms'         ),
  ( 'Computer/Atari STe',                             'mistery',       'Computer/Mistery',                                  'atarist_roms'         ),
  ( 'Computer/BBC Micro',                             'bbc',           'Computer/BBC',                                      'bbc_roms'             ),
  ( 'Computer/BK0011M',                               '',              'Computer/BK0011M',                                  'bk001m_roms'          ),
  ( 'Computer/C16',                                   'c16',           'Computer/C16',                                      'c16_roms'             ),
  ( 'Computer/C64',                                   'fpga64',        'Computer/C64',                                      'c64_roms'             ),
  ( 'Computer/Coleco Adam',                           '',              'Computer/Adam'                                                             ),
  ( 'Computer/Color Computer 2',                      'coco2',         'Computer/CoCo',                                     'coco2_roms'           ),
  ( 'Computer/Color Computer 3',                      '',              'Computer/Coco3',                                    'coco3_roms'           ),
  ( 'Computer/Enterprise 128',                        'enterprise',    'Computer/ElanEnterprise',                           'enterprise_roms'      ),
  ( 'Computer/Exidy Sorcerer',                        'sorcerer',      'Computer/Sorcerer',                                 'sourcerer_roms'       ),
  ( 'Computer/HT1080Z School Computer',               'ht1080z',       ''                                                                          ),
  ( 'Computer/Laser500',                              '',              'Computer/Laser500',                                 'laser500_roms'        ),
  ( 'Computer/Luxor ABC80',                           'abc80',         'Computer/ABC80'                                                            ),
  ( 'Computer/Lynx',                                  '',              'Computer/CamputerLynx'                                                     ),
  ( 'Computer/Mattel Aquarius',                       'aquarius',      'Computer/MattelAquarius'                                                   ),
  ( 'Computer/MSX1',                                  '',              'Computer/MSX1',                                     'msx1_roms'            ),
  ( 'Computer/MSX2+',                                 'msx',           'Computer/MSX',                                      'msx2p_roms'           ),
  ( 'Computer/Next186',                               'next186',       'Computer/Next186',                                  'next186_roms'         ),
  ( 'Computer/Oric',                                  'oric',          'Computer/Oric',                                     'oric_roms'            ),
  ( 'Computer/PCXT',                                  'pcxt',          '',                                                  'pcxt_roms'            ),
  ( 'Computer/PET2001',                               'pet2001',       'Computer/PET2001',                                  'pet2001_roms'         ),
  ( 'Computer/Robotron Z1013',                        'z1013',         ''                                                                          ),
  ( 'Computer/Sinclair QL',                           'ql',            'Computer/QL',                                       'ql_roms'              ),
  ( 'Computer/SAM Coupe',                             'samcoupe',      'Computer/SamCoupe',                                 'samcoupe_roms'        ),
  ( 'Computer/Speccy',                                '',              'Computer/Speccy',                                   'speccy_roms'          ),
  ( 'Computer/TI99-4A',                               'ti994a',        'Computer/TI994A',                                   'ti994a_roms'          ),
  ( 'Computer/TSConf',                                'tsconf',        'Computer/TSConf',                                   'tsconf_roms'          ),
  ( 'Computer/VIC20',                                 'vic20',         'Computer/VIC20',                                    'vic20_roms'           ),
  ( 'Computer/Videoton TV Computer',                  'tvc',           'Computer/VideotonTVC',                              'tvc_roms'             ),
  ( 'Computer/X68000',                                '',              'Computer/X68000',                                   'x68000_roms'          ),
  ( 'Computer/ZX8x',                                  'zx01',          'Computer/ZX8X',                                     'zx8x_roms'            ),
  ( 'Computer/ZX-Next',                               'zxn',           'Computer/ZXSpectrum_Next'                                                  ),
  ( 'Computer/ZX Spectrum',                           'spectrum',      'Computer/ZXSpectrum',                               'zx_spectrum_roms'     ),
  ( 'Computer/ZX Spectrum 48k',                       '',              'Computer/ZXSpectrum48K_Kyp'                                                ),
 # Consoles
  ( 'Console/Atari 2600',                             'a2600',         'Console/A2600',                                     'atari2600_roms'       ),
  ( 'Console/Atari 5200',                             'atari5200',     'Console/A5200',                                     'atari5200_roms'       ),
  ( 'Console/Atari 7800',                             'atari7800',     'Console/A7800',                                     'atari7800_roms'       ),
  ( 'Console/Astrocade',                              'astrocade',     'Console/Astrocade'                                                         ),
  ( 'Console/ColecoVision',                           'colecovision',  'Console/COLECOVISION'                                                      ),
  ( 'Console/Gameboy',                                'gameboy',       'Console/GAMEBOY',                                   'gameboy_roms'         ),
  ( 'Console/Genesis MegaDrive',                      'fpgagen',       'Console/GENESIS'                                                           ),
  ( 'Console/Intellivision',                          'intellivision', 'Console/Intellivison',                              'intellivision_roms'   ),
  ( 'Console/NeoGeo',                                 'neogeo',        'Console/NEOGEO',                                    'neogeo_roms'          ),
  ( 'Console/Nintendo NES',                           'nes',           'Console/NES',                                       'nes_roms'             ),
  ( 'Console/Nintendo SNES',                          'snes',          'Console/SNES',                                      'snes_roms'            ),
  ( 'Console/PC Engine',                              'pcengine',      'Console/PCE',                                       'turbogfx_roms'        ),
  ( 'Console/SEGA MasterSystem',                      'sms',           'Console/SMS'                                                               ),
  ( 'Console/SEGA Master System Nuked',               'sms-nuked',     'Console/NukedSMS'                                                          ),
  ( 'Console/SONY Playstation',                       '',              'Console/PSX',                                       'psx_roms'             ),
  ( 'Console/Vectrex',                                '',              'Console/Vectrex',                                   'vectrex_roms'         ),
  ( 'Console/Videopac',                               'videopac',      'Console/VIDEOPAC',                                  'videopac_roms'        ),
 # SiDi Arcade: Gehstock
  ( 'Arcade/Gehstock/Atari BW Raster Hardware',       '',              'Arcade/Gehstock/ATARI BW Raster Hardware.rar'                              ),
  ( 'Arcade/Gehstock/Atari Centipede Hardware',       '',              'Arcade/Gehstock/Atari Centipede Hardware.rar'                              ),
  ( 'Arcade/Gehstock/Atari Tetris',                   '',              'Arcade/Gehstock/Atari Tetris.rar'                                          ),
  ( 'Arcade/Gehstock/Bagman Hardware',                '',              'Arcade/Gehstock/Bagman_Hardware.rar',               'bagman_roms'          ),
  ( 'Arcade/Gehstock/Berzerk Hardware',               '',              'Arcade/Gehstock/Berzerk Hardware.rar'                                      ),
  ( 'Arcade/Gehstock/Bombjack',                       '',              'Arcade/Gehstock/Bombjack.rar'                                              ),
  ( 'Arcade/Gehstock/Crazy Climber Hardware',         '',              'Arcade/Gehstock/Crazy Climber Hardware.rar'                                ),
  ( 'Arcade/Gehstock/Data East Burger Time Hardware', '',              'Arcade/Gehstock/Data East Burger Time Hardware.rar'                        ),
  ( 'Arcade/Gehstock/Galaga Hardware',                '',              'Arcade/Gehstock/Galaga hardware.rar'                                       ),
  ( 'Arcade/Gehstock/Galaxian Hardware',              '',              'Arcade/Gehstock/Galaxian Hardware.rar'                                     ),
  ( 'Arcade/Gehstock/Pacman Hardware',                '',              'Arcade/Gehstock/Pacman_hardware.rar'                                       ),
  ( 'Arcade/Gehstock/Phoenix Hardware',               '',              'Arcade/Gehstock/Phoenix_hardware.rar'                                      ),
  ( 'Arcade/Gehstock/Tetris',                         '',              'Arcade/Gehstock'                                                           ),
 # SiDi Arcade: Jotego fetched directly from Jotego jtbin repository
 #( 'Arcade/Jotego/jt1942_SiDi.rbf',                  '',              'Arcade/Jotego/1942',                                '1942_roms'            ),
 #( 'Arcade/Jotego/jt1943_SiDi.rbf',                  '',              'Arcade/Jotego/1943',                                '1943_roms'            ),
 #( 'Arcade/Jotego/jtcommando_SiDi.rbf',              '',              'Arcade/Jotego/Commando',                            'commando_roms'        ),
 #( 'Arcade/Jotego/jtgng_SiDi.rbf',                   '',              'Arcade/Jotego/GhostnGoblins',                       'ghost_n_goblins_roms' ),
 #( 'Arcade/Jotego/jtgunsmoke_SiDi.rbf',              '',              'Arcade/Jotego/Gunsmoke',                            'gunsmoke_roms'        ),
 #( 'Arcade/Jotego/jtvulgus_SiDi.rbf',                '',              'Arcade/Jotego/Vulgus',                              'vulgus_roms'          ),
 # SiDi Arcade: other
  ( 'Arcade',                                         '',              'Arcade/arcade',                                     'sidi128_arcade'       ), # SiDi128 folder only
  ( 'Arcade/Alpha68k',                                '',              'Arcade/Alpha68k'                                                           ),
  ( 'Arcade/IremM72',                                 '',              'Arcade/IremM72'                                                            ),
  ( 'Arcade/IremM92',                                 '',              'Arcade/IremM92'                                                            ),
  ( 'Arcade/Jotego/TAITO TNZS',                       '',              'Arcade/JTKiwi',                                     'tnzs_roms'            ),
  ( 'Arcade/Konami Hardware',                         '',              'Arcade/Konami hardware/konami hardware.rar'                                ),
  ( 'Arcade/NeoGeo',                                  '',              'Arcade/Neogeo',                                     'neogeo_roms'          ),
  ( 'Arcade',                                         '',              'Arcade/Nintendo hardware/Nintendo hardware.rar',    'nintendo_sysattr'     ), # archive contains destination folder
  ( 'Arcade/Prehisle',                                '',              'Arcade/Prehisle'                                                           )
)

function copy_mist_cores {
  param ( [string]$dstroot,   # $1: destination folder
          $testcore = $null ) # $2: optional core for single test

  Write-Host "`r`n----------------------------------------------------------------------" `
             "`r`nCopy MiST Cores to `'$dstroot`'" `
             "`r`n----------------------------------------------------------------------`r`n"

  $srcroot="$GIT_ROOT/MiST/binaries"

  # get MiST binary repository
  clone_or_update_git 'https://github.com/mist-devel/mist-binaries.git' $srcroot

  # default ini file (it not exists)
  if (-not (Test-Path "$dstroot/mist.ini")) { sdcopy "$srcroot/cores/mist.ini" "$dstroot/" }

  # Firmware upgrade file
  copy_latest_file "$srcroot/firmware" "$dstroot/firmware.upg" 'firmware*.upg'

  if (($null -eq $testcore) -or ($testcore -eq 'Arcade')) {
    # loop over arcade folders in MiST repository
    foreach ($dir in (Get-ChildItem "$srcroot/cores/arcade" -Directory | Select-Object -ExpandProperty FullName | Sort-Object | replace-slash)) {
      # support for optional testing of single specific core
      if (($null -ne $testcore) -and ($dir.Contains($testcore))) { continue }
      # generate destination arcade folders from .mra and .core files
      copy_mra_arcade_cores $dir $dir "$dstroot/Arcade/MiST/$($dir.Split('/')[-1])"
    }
  }

  # loop over other folders in MiST repository
  foreach ($dir in (Get-ChildItem "$srcroot/cores" -Directory | Select-Object -ExpandProperty FullName | Sort-Object | replace-slash)) {
    # check if in our list of cores
    foreach($item in $cores) {
      $dst = $item[0]
      $src = $item[1]
      $hdl = $item[3]
      if ("$srcroot/cores/$src" -eq $dir) {
        # support for optional testing of single specific core
        if (($null -ne $testcore) -and ($testcore -ne $dst)) { continue }
        # Info
        Write-Host "`r`n$($dir.Replace("$GIT_ROOT/",'')) ..."
        # copy latest core to destination folder
        if ($dst -eq '.') {
          # copy latest menu core and set hidden attribute to hide this core from menu
          copy_latest_file $dir "$dstroot/$dst/core.rbf" '*.rbf'
          set_hidden_attr "$dstroot/$dst/core.rbf"
        } else {
          # copy latest core to destination folder and set its system attribute to be visible in menu core
          copy_latest_file $dir "$dstroot/$dst/$($dst.Split('/')[-1]).rbf" '*.rbf'
          set_system_attr "$dstroot/$dst"
        }
        # optional rom handling
        if ($null -ne $hdl) {
          &$hdl "$dir" "$dstroot/$dst" "$MISC_FILES/$($dst.Split('/')[-1])"
        }
        $dir = $null
        break
      }
    }
    if ($null -ne $dir) {
      Write-Host -ForegroundColor red "`r`nUnhandled: `'$dir`'"
    }
  }
}

function copy_sidi_cores {
  param ( [string]$dstroot,   # $1: destination folder
          $testcore = $null ) # $2: optional core for single test

  # some parameters to be distinguished between SiDi and SiDi128 handling
  $paramSet=@(
    #( 'firmware folder',  'menu core',   'arcade dir', 'core exclude pattern' ),
    @( 'Firmware',         'core.rbf',    'SiDi',       '*sidi128*'            ), # SiDi
    @( 'Firmware_SiDi128', 'sidi128.rbf', 'SiDi128',    ''                     )  # SiDi128
  )
  if ($SYSTEM -eq 'sidi') { $params = $paramSet[0] } else { $params = $paramSet[1] }
  Write-Host "`r`n----------------------------------------------------------------------" `
             "`r`nCopy $SYSTEM Cores to `'$dstroot`'" `
             "`r`n----------------------------------------------------------------------`r`n"

  $srcroot="$GIT_ROOT/SiDi/ManuFerHi"

  # get SiDi binary repository
  clone_or_update_git 'https://github.com/ManuFerHi/SiDi-FPGA.git' $srcroot

  # default ini file (it not exists)
  if (-not (Test-Path "$dstroot/mist.ini")) { download_url 'https://github.com/mist-devel/mist-binaries/raw/master/cores/mist.ini' "$dstroot/" }

  # Firmware upgrade file
  copy_latest_file "$srcroot/$($params[0])" "$dstroot/firmware.upg" 'firmware*.upg'

  # loop over folders in SiDi repository
  foreach ($dir in (Get-ChildItem -Recurse $srcroot/Cores -Directory | Select-Object  -ExpandProperty FullName | Sort-Object | replace-slash)) {
    if ((($dir.Split('/'))[-1] -ne 'old') -and (($dir.Split('/'))[-1] -ne 'output_files')) {
      if (Test-Path "$dir/*.rbf") {
        # check if in our list of cores
        foreach($item in $cores) {
          $dst = $item[0]
          $src = $item[2].replace('Arcade/',"Arcade/$($params[2])/")
          $hdl = $item[3]
          if ("$srcroot/Cores/$src" -eq $dir) {
            # support for optional testing of single specific core
            if (($null -ne $testcore) -and ($testcore -ne $dst)) { continue }
            # Info
            Write-Host "`r`n$($dir.Replace("$GIT_ROOT/",'')) ..."
            if ($dst -eq '.') {
              # copy latest menu core and set hidden attribute to hide this core from menu
              copy_latest_file $dir "$dstroot/$dst/$($params[1])" "*$SYSTEM*.rbf" "$($params[3])"
              set_hidden_attr "$dstroot/$dst/$($params[1])"
            } else {
              # copy latest core to destination folder and set its system attribute to be visible in menu core
              copy_latest_file "$dir" "$dstroot/$dst/$($dst.Split('/')[-1]).rbf" "*$SYSTEM*.rbf" "$($params[3])"
              set_system_attr "$dstroot/$dst"
            }
            # optional rom handling
            if ($null -ne $hdl) {
              &$hdl $dir "$dstroot/$dst" "$MISC_FILES/$($dst.Split('/')[-1])"
            }
            $dir = $null
            break
          }
        }
      }
      if (Test-Path "$dir/*.rar") {
        foreach ($rar in (Get-ChildItem "$dir/*.rar" | Sort-Object -Property FullName | replace-slash)) {
          # check if in our list of cores
          foreach($item in $cores) {
            $dst = $item[0]
            $src = $item[2].replace('Arcade/',"Arcade/$($params[2])/")
            $hdl = $item[3]
            if ("$srcroot/Cores/$src" -eq $rar) {
              # support for optional testing of single specific core
              if (($null -ne $testcore) -and ($testcore -ne $dst)) { continue }
              # Info
              Write-Host "`r`n$($rar.Replace("$GIT_ROOT/",'')) ..."
              # uncompress to destination folder
              Write-Host "  Uncompressing $src ..."
              expand $rar "$dstroot/$dst/"
              # optional rom handling
              if ($null -ne $hdl) {
                &$hdl $dir "$dstroot/$dst" "$MISC_FILES/$($dst.Split('/')[-1])"
              }
              # set system attribute for this subfolder to be visible in menu core
              set_system_attr "$dstroot/$dst"
              $dir = $null
              break
            }
          }
        }
      }

      if ($null -ne $dir) {
        if ((Test-Path "$dir/*.rbf") -Or (Test-Path "$dir/*.rar")) {
          Write-Host -ForegroundColor red "`r`nUnhandled: $dir"
        }
      }
    }
  }
}


function check_sd_filesystem {
  param ( [string]$dstroot )  # $1: destination folder

  if ($isLinux) {
    # check filesystem of SD folder (only vfat and msdos supported by fatattr (exfat with root privileges))
    # $fs = &stat -f -c %T $dstroot
    $fs = &df --output="fstype" "$dstroot" | tail -1
    Write-Host "`r`nFilesystem type of destination '$SD_ROOT' is '$fs'."
    switch -regex ($fs) {
      '(msdos)|(vfat)' {
        # on FAT/FAT32 volumes we are fine
      }
      'exfat' {
        if ((&id -u) -eq 0) {
          # already running as root - we are fine for exFAT
        } else {
          Write-Host "root privileges required to write DOS filesystem attributes on exFAT destination file system."
          while(1) {
            $script:SUDO_PW = Read-Host -MaskInput "[sudo] Passwort für $env:USER "
            if (&echo "$script:SUDO_PW" | sudo -k -S ls) {
              break
            }
            Write-Host -ForegroundColor red "ERROR: Invalid sudo password! Please retry"
          }
        }
      }
      default {
        Write-Host "`r`nUnsupported file system." `
                   "`r`nContinue anyway (no support for DOS filesystem attributes) ?`r`n"
        while($true) {
          $reply = Read-Host -Prompt "Pick an option (Y or N)"
          switch ($reply.ToLower()) {
            'y' { return }
            'n' { exit 1 }
          }
        }
      }
    }
  }
}

function show_usage {
  Write-Host "`r`nUsage: genSD [-s <mist|sidi|sidi128>] [-d <destination SD drive or folder>] [-h]" `
             "`r`nGenerate SD card content with cores/roms for specific FPGA platform." `
             "`r`n" `
             "`r`nOptional arguments:" `
             "`r`n -s <mist|sidi>" `
             "`r`n    Set target system (mist, sidi or sidi128)." `
             "`r`n    This parameter is mandatory!" `
             "`r`n -d <destination SD (drive) folder>" `
             "`r`n    Location where the target files should be generated." `
             "`r`n    If this option isn't specified, `'SD/<system>`' will be used." `
             "`r`n -h" `
             "`r`n    Show this help text`r`n"
}

# mute some warnings
$progressPreference='silentlyContinue'

# Parse commandline options
for ( $i = 0; $i -lt $($args.count); $i+=2 ) {
  switch($($args[$i])) {
    '-d'    { $SD_ROOT=($($args[$i+1]) | replace-slash) }
    '-s'    { $SYSTEM = $($args[$i+1]).ToLower()
              if (($SYSTEM -ne 'mist') -and ($SYSTEM -ne 'sidi') -and ($SYSTEM -ne 'sidi128')) {
                Write-Host -ForegroundColor red "Invalid target `'$SYSTEM`'!"
                show_usage; exit 1
              }
            }
    '-h'    { show_usage; exit 0 }
    default { Write-Host -ForegroundColor red "`r`nERROR: Invalid option '$($args[$i])'"
              show_usage; exit 1 }
  }
}
if ($SYSTEM.length  -eq 0) { show_usage; exit 1 }
if ($SD_ROOT.length -eq 0) { $SD_ROOT = "$PSScriptRoot/SD/$SYSTEM" }


Write-Host "`r`n----------------------------------------------------------------------" `
           "`r`nGenerating SD content for `'$SYSTEM`' to `'$SD_ROOT`'" `
           "`r`n----------------------------------------------------------------------`r`n"

Write-Host "Creating destination folder `'$SD_ROOT`' ..."
makedir $SD_ROOT

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
if (($SYSTEM -eq 'sidi') -or (($SYSTEM -eq 'sidi128'))) {
  copy_sidi_cores $SD_ROOT
  copy_eubrunosilva_sidi_cores $SD_ROOT
} elseif ($SYSTEM -eq 'mist') {
  copy_mist_cores $SD_ROOT
  copy_sorgelig_mist_cores $SD_ROOT
  copy_gehstock_mist_cores $SD_ROOT
  copy_sebdel_mist_cores $SD_ROOT
  copy_joco_mist_cores $SD_ROOT
}
copy_jotego_arcade_cores $SD_ROOT/Arcade/Jotego

Write-Host "`r`ndone."
