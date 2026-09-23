@echo off
setlocal
title Biomi - Upload website to biomi.ge (LIVE)
color 0E
cd /d "%~dp0"

echo.
echo  ==================================================
echo    BIOMI  -  Upload website to biomi.ge  (LIVE)
echo  ==================================================
echo.
REM --- The real website. Sends only the files that changed since the last
REM     upload, after it lists them and you press Enter. Run "Upload Test Site"
REM     first and check the change there. The live FTP login is asked for once
REM     and kept encrypted in %%APPDATA%%\Biomi (never in this folder).
REM     -DryRun lists what would change without connecting. ---
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\deploy\deploy-site.ps1" -Target live %*

echo.
pause