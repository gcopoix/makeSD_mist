@echo off
setlocal EnableDelayedExpansion

rem Script checking
PowerShell -ExecutionPolicy Bypass "$ErrorActionPreference = 'SilentlyContinue';" ^
                                   "if (-not (Get-Module -ListAvailable -Name 'PSScriptAnalyzer')) {" ^
                                   "  if (-not (Get-PackageProvider -ListAvailable -Name 'NuGet')) {" ^
                                   "    Write-Host 'Installing PackageProvider NuGet for current user ...'; " ^
                                   "    Install-PackageProvider -Name NuGet -Scope CurrentUser -Force | Out-Null;" ^
                                   "  }" ^
                                   "  Write-Host 'Installing PSScriptAnalyzer Module for current user ...';" ^
                                   "  Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force;" ^
                                   "}" ^
                                   "Import-Module PSScriptAnalyzer;" ^
                                   "Invoke-ScriptAnalyzer \"%~dp0..\Windows\genSD.ps1\"" ^
                                   "    -Severity Warning " ^
                                   "    -ExcludeRule PSAvoidUsingWriteHost, PSReviewUnusedParameter, PSPossibleIncorrectComparisonWithNull, PSUseApprovedVerbs"

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

    rem log error/warning results
    PowerShell -ExecutionPolicy Bypass "Write-Host -ForegroundColor red \"`r`nMissing core .rbf files:\"                                                     | Tee-Object \"!dstSD!\log.txt\" -Append;" ^
                                       "Get-Content -Path \"!dstSD!\log.txt\" | Select-String -Pattern 'rbf(.) not found' | Sort-Object -Unique | Write-Host | Tee-Object \"!dstSD!\log.txt\" -Append;" ^
                                       "" ^
                                       "Write-Host -ForegroundColor red \"`r`nMissing MAME ROMs:\"                                                           | Tee-Object \"!dstSD!\log.txt\" -Append;" ^
                                       "Get-Content -Path \"!dstSD!\log.txt\" | Select-String -Pattern 'zip file not found' | Sort-Object -Unique            | Write-Host | Tee-Object \"!dstSD!\log.txt\" -Append;" ^
                                       "" ^
                                       "Write-Host -ForegroundColor red \"`r`nMAME ROMs with wrong checksum:\"                                               | Tee-Object \"!dstSD!\log.txt\" -Append;" ^
                                       "Get-Content -Path \"!dstSD!\log.txt\" | Select-String -Context 1,0 -Pattern 'md5 mismatch' | Write-Host              | Tee-Object \"!dstSD!\log.txt\" -Append;" ^
                                       "" ^
                                       "Write-Host -ForegroundColor red \"`r`nMAME ROMs with missing parts:\"                                                | Tee-Object \"!dstSD!\log.txt\" -Append;" ^
                                       "Get-Content -Path \"!dstSD!\log.txt\" | Select-String -Context 1,0 -Pattern 'not found in zip' | Write-Host          | Tee-Object \"!dstSD!\log.txt\" -Append;"
  )
  rem compare both folders
  PowerShell -ExecutionPolicy Bypass "Write-Host \"`r`nDiff of '!dstSys!\SD1' - '!dstSys!\SD2:'\"                                                            | Tee-Object \"!dstSys!\SD2\log.txt\" -Append;" ^
                                     "Compare-Object (Get-ChildItem \"!dstSys!\SD1\log.txt\" -Recurse) (Get-ChildItem \"!dstSys!\SD2\log.txt\" -Recurse)     | Tee-Object \"!dstSys!\SD2\log.txt\" -Append;"
)
