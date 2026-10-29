@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set ROOT_DIR=%~dp0..
pushd "%ROOT_DIR%" 2>nul
if errorlevel 1 (
    echo ERROR: Failed to find project root
    pause
    exit /b 1
)

git config core.quotepath false >nul 2>&1
git config i18n.commitencoding utf-8 >nul 2>&1
git config i18n.logoutputencoding utf-8 >nul 2>&1

for /f %%b in ('git rev-parse --abbrev-ref HEAD') do set CURRENT=%%b
if not defined CURRENT set CURRENT=main

echo ================================================
echo   Kibal (SmartCC IP-PBX) Git Pull
echo   Fetch + Pull + Branch Selector
echo ================================================
echo.

echo [1/5] Fetching from all remotes...
git fetch --all --prune
if errorlevel 1 echo   WARN: fetch had issues
echo.

:: Build branch list (temp file for UTF-8 Korean branch names)
set PYTHON_CMD=python
if exist "%USERPROFILE%\miniconda3\python.exe" set PYTHON_CMD=%USERPROFILE%\miniconda3\python.exe

set "BRANCH_TMP=%TEMP%\kibal_gitpull_branches.tmp"
"%PYTHON_CMD%" scripts\pick_branch.py --list > "%BRANCH_TMP%" 2>nul

set BRANCH_COUNT=0
for /f "delims=" %%b in ('type "%BRANCH_TMP%"') do (
    set /a BRANCH_COUNT+=1
    set "BRANCH_!BRANCH_COUNT!=%%b"
)
if exist "%BRANCH_TMP%" del "%BRANCH_TMP%" 2>nul

echo Available branches:
echo ----------------------
for /l %%i in (1,1,%BRANCH_COUNT%) do (
    set "marker="
    if "!BRANCH_%%i!"=="!CURRENT!" set "marker= (current)"
    echo   %%i^) !BRANCH_%%i!!marker!
)
echo.
set choice=
set /p choice="Select number [1-%BRANCH_COUNT%] (Enter=current): "
echo.

if not defined choice (
    set BRANCH=!CURRENT!
) else (
    set BRANCH=!BRANCH_%choice%!
    if not defined BRANCH (
        echo   Invalid selection. Using current: !CURRENT!
        set BRANCH=!CURRENT!
    )
)
echo Selected: !BRANCH!
echo.

echo [2/5] Current state:
git status --short
echo.

echo [3/5] Switching to branch: !BRANCH!...
git checkout !BRANCH! 2>nul
if errorlevel 1 (
    echo   Not found locally. Creating from remote...
    git checkout -b !BRANCH! github/!BRANCH! 2>nul
    if errorlevel 1 (
        echo   WARN: checkout failed (local changes?). Aborting.
        echo   Try: git stash then re-run
        pause
        popd
        exit /b 1
    )
)
echo.

set RC=0

echo [4/5] Pulling from github/!BRANCH!...
git pull github !BRANCH!
if errorlevel 1 (
    echo   WARN: pull had issues
    set RC=1
)
echo.

echo [5/5] Sync Status Report
echo -----------------------------------------------
for /f %%h in ('git rev-parse --short HEAD 2^>nul') do echo  HEAD: %%h
echo.
echo  Latest commits:
git log --oneline -5
echo.
echo  Branch status:
for %%r in (github dev prd) do (
    for /f "tokens=1,2" %%a in ('git rev-list --left-right --count %%r/!BRANCH!...HEAD 2^>nul') do (
        echo   %%r: behind=%%a ahead=%%b
    )
)
echo -----------------------------------------------
if "%RC%"=="0" (echo  RESULT: Pull OK) else (echo  RESULT: Issues detected)
echo.
echo  PRD deploy (if needed):
echo    ssh nas2 "cd /var/services/homes/atom/SmartCC_Kibal && git pull github !BRANCH!"
echo.

popd
pause
exit /b %RC%
