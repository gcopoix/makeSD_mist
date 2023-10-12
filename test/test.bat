@echo off
setlocal EnableDelayedExpansion

rem Script checking
PowerShell -ExecutionPolicy Bypass "if (Get-Module -ListAvailable -Name \"PSScriptAnalyzer\") { Import-Module PSScriptAnalyzer; Invoke-ScriptAnalyzer "%~dp0..\Windows\genSD.ps1" -Severity Error" } else { echo \"WARNING: PSScriptAnalyzer not installed. No script checking available.\" }"

rem Available disk space test
for /f "usebackq tokens=3" %%s in (`dir /-c /-o /w "%~dp0"`) do set avail=%%s
set avail=%avail:~0,-9%
if %avail% LSS 40 (
  echo "ERROR: Not enough free disk space (only %avail%GB available). At least 40GB free disk space required."
  exit /b 1
)

for %%s in (mist sidi) do (
  set dstSys=%~dp0Windows\%%s
  echo.
  echo ----------------------------------------------------------------------
  echo Test for %%s -^> '!dstSys!':
  echo ----------------------------------------------------------------------
  echo.

  rem create empty folder for destination system with copy of script
  rmdir /Q /S "!dstSys!" 2>nul
  mkdir "!dstSys!" >nul 2>&1
  copy "%~dp0..\Windows\genSD.ps1" "!dstSys!\" >nul
  rem make 2 runs: 1st with empty cache folders, 2nd with cache and destination folders available (update case)
  for %%i in (1 2) do (
    set dstSD=!dstSys!\SD%%i
    echo Test #%%i -^> '!dstSD!':
    rem create empty folder for destination distribution
    rmdir /Q /S "!dstSD!" 2>nul
    mkdir "!dstSD!"
    if '%%i' NEQ '1' (
      rem use initially created folder content for re-run
      echo Creating copy of '!dstSys!\SD1' for update test ...
      xcopy /E /C /Q /H /R /K /Y "!dstSys!\SD1" "!dstSD!\"
    )
    rem ToDo: loggings currently don't support -no-newline.
    rem https://stackoverflow.com/questions/1215260/how-to-redirect-the-output-of-a-powershell-to-a-file-during-its-execution
    rem PowerShell -ExecutionPolicy Bypass "$ErrorActionPreference=\"SilentlyContinue\"; Stop-Transcript | out-null; $ErrorActionPreference=\"Continue\"; Start-Transcript -Path \"%~dp0Windows\%%s\SD%%i\log.txt\"; %~dp0Windows\%%s\genSD.ps1 -s %%s -d \"%~dp0Windows\%%s\SD%%i 2>&1 3>&1\"; Stop-Transcript"
    PowerShell -ExecutionPolicy Bypass "&\"!dstSys!\genSD.ps1\" -s %%s -d \"!dstSD!\" 2>&1 3>&1 4>&1 5>&1 6>&1 | Tee-Object \"!dstSD!\log.txt\""
  )
  rem compare both folders
  rem https://stackoverflow.com/questions/17599576/comparing-two-folders-and-its-subfolder-batch-file
)
