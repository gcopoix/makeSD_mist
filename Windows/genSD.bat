@echo off

rem forward to PowerShell script
Powershell -ExecutionPolicy Bypass "%~dp0%~n0.ps1" %*
