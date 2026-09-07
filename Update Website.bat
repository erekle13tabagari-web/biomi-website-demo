@echo off
setlocal
REM --- Never let git page its output. With a long file list git pipes through
REM     "less", which parks this script at an (END) prompt waiting for a
REM     keypress nobody expected. ---
set "GIT_PAGER="
title Biomi - Publish website to GitHub
color 0B
cd /d "%~dp0"

echo.
echo  ==================================================
echo    BIOMI  -  Publish website to GitHub
echo  ==================================================
echo.

if not exist ".git" (
  echo   ERROR: this folder is not a git repository.
  goto :end
)

REM --- The website publishes from "main" only. ---
for /f "delims=" %%b in ('git rev-parse --abbrev-ref HEAD') do set "BRANCH=%%b"
if /i not "%BRANCH%"=="main" (
  echo   ERROR: you are on branch "%BRANCH%", but the website
  echo          publishes from "main" only.
  echo.
  echo          Fix it with:   git checkout main
  goto :end
)

REM --- Refresh the ?v= tag on style.css / main.js so visitors' browsers fetch
REM     the new files instead of serving a cached copy. Without this, a change
REM     can be live on GitHub Pages but invisible to anyone who visited before. ---
REM --- Rebuild the search index from the hub pages first, so a product added
REM     to a hub is findable the moment it goes live. Regenerating every time
REM     is cheap and means the index can never quietly fall behind. ---
echo   [1/4] Rebuilding search index and refreshing cache tags...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-search-index.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0bump-cache-version.ps1"

REM --- The page generators in tools\ strip the meta block and rely on
REM     build-meta.ps1 being run afterwards. If it was forgotten the page ships
REM     with no canonical, hreflang or share card - invisible in a browser, so
REM     nothing else catches it. Stop before committing rather than publish it. ---
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check-meta.ps1"
if errorlevel 1 (
  echo.
  echo   PUBLISH ABORTED - nothing was committed or pushed.
  goto :end
)

git add -A
git diff --cached --quiet
if errorlevel 1 (
  echo.
  echo   Files to publish:
  git --no-pager diff --cached --name-only
  echo.
  echo   [2/4] Committing...
  git commit -m "Update website (%date% %time%)" >nul
  if errorlevel 1 (
    echo   Commit failed.
    goto :end
  )
) else (
  echo   No new file changes.
  echo.
  echo   [2/4] Nothing to commit.
)

REM --- Committed work still has to reach GitHub. Check for unpushed
REM     commits separately: a clean working tree does NOT mean the
REM     site is up to date. ---
echo   [3/4] Comparing with GitHub...
git fetch origin main --quiet
for /f "delims=" %%c in ('git rev-list --count origin/main..HEAD') do set "AHEAD=%%c"

if "%AHEAD%"=="0" (
  echo.
  echo   Nothing new to publish - the site is already up to date.
  goto :end
)

echo.
echo   Commits waiting to publish: %AHEAD%
git --no-pager log --oneline origin/main..HEAD
echo.

echo   [4/4] Pushing to GitHub...
git push origin main
if errorlevel 1 (
  echo.
  echo   PUSH FAILED. Check your internet connection or GitHub login.
  goto :end
)

echo.
echo   ==================================================
echo    DONE - website published.
echo    It goes live in about a minute on GitHub Pages.
echo   ==================================================

:end
echo.
if not defined BIOMI_NOPAUSE pause
