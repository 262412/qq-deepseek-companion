@echo off
setlocal
set "PSModulePath=%SystemRoot%\System32\WindowsPowerShell\v1.0\Modules;%ProgramFiles%\WindowsPowerShell\Modules"
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0scripts\setup-gui.ps1"
