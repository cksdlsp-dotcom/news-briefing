@echo off
setlocal
title CHAIGIDA Capture10 - H Drive APK Builder
if not exist "H:\BRON_BUILD\" (
  echo ERROR: H:\BRON_BUILD not found.
  pause
  exit /b 1
)
if not exist "H:\BRON_BUILD\temp\" mkdir "H:\BRON_BUILD\temp"
set "TEMP=H:\BRON_BUILD\temp"
set "TMP=H:\BRON_BUILD\temp"
echo.
echo === CHAIGIDA Capture10 / Build on H: ===
echo This will NOT touch BRON source or the CHAIGIDA production files.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0BUILD_CAPTURE10.ps1"
set "EXITCODE=%ERRORLEVEL%"
if not "%EXITCODE%"=="0" (
 echo.
 echo BUILD FAILED. Error code %EXITCODE%.
 echo Please share a screenshot of this window.
) else (
 echo.
 echo APK: H:\BRON_BUILD\output\CHAIGIDA_CAPTURE10_DEBUG.apk
)
pause
exit /b %EXITCODE%
