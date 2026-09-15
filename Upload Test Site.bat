@echo off
setlocal
title Biomi - Upload website to test.biomi.ge
color 0B
cd /d "%~dp0"

echo.
echo  ==================================================
echo    BIOMI  -  Upload website to test.biomi.ge
echo  ==================================================
echo.
REM --- Sends only the files that changed since the last upload. The FTP login
REM     is asked for once and kept encrypted in %%APPDATA%%\Biomi (never in this
REM     folder). Add -ResetLogin to re-type it, -Full to send everything again. ---
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\deploy\deploy-test.ps1" %*

echo.
pause
