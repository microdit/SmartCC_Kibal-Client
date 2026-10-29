@echo off
setlocal enabledelayedexpansion
:: Kibal (SmartCC IP-PBX) Git Sync for Windows - CMD
:: Commit + Push All Remotes + Auto Log
:: Version: 2.3 - Windows Batch - CP949
:: @>-- 2026-10-01 v2.3 - ��ȭ�� ���(--interactive / -i) �߰�
:: @>--   SLACK_AI_Assistant/scripts/git-sync.bat ���� �̽�:
:: @>--   �귣ġ ���� �޴�(:branch_prompt) + Ǫ�� ���� ��õ� ������Ʈ.
:: @>--   D12 - ���ν� -- �÷��׸� Ŀ�� �޽����� ��Ű�� �ʰ� ���� ó��.
:: @>--   D13 - "--" �����ڷ� �÷��� �ؼ� ���� �� �޽����� ���� ����.
:: @>-- 2026-09-29 Windows ��ġ ��ȯ �˼� - �۾����ü� v3.0 4.2
:: @>-- ���� �缳�� �ٰ� - CMD �� ��ȣ ���� ������ �󺧰� goto �׸���
:: @>--   �̽����������� ���� �ݴ� ��ȣ�� �����ϰ� ó������ ���Ѵ�.
:: @>--   ���� v2.0 �� �� ������ �� ����� �������̾���.
:: @>--   �ذ�å - ��� �۾��� �󺧰� goto �׸��� �����ƾ���� �и��ߴ�.
:: @>-- ���ڵ� ��Ģ - �� ������ CP949 �� �����Ѵ�.
:: @>--   �ּ� �ٿ��� ��ȣ�� ��Ŀ� �����ڵ带 ���� �ʴ´�.
:: @>--   CMD �� ��Ƽ����Ʈ �ؼ��� �� ��踦 �Ѿ� ���ĵǾ� ��ũ��Ʈ�� ������.

:: -- ��� ���� --
cd /d "%~dp0.." 2>nul
if errorlevel 1 (
    echo   ERROR: ������Ʈ ��Ʈ�� �̵� ���� - "%~dp0.."
    exit /b 1
)
set "ROOT_DIR=%CD%"

:: -- Git ���͸� - ��ũƮ�� �� ������ ���� --
set "GIT_DIR="
for /f "usebackq delims=" %%i in (`git rev-parse --absolute-git-dir 2^>nul`) do set "GIT_DIR=%%i"
if not defined GIT_DIR set "GIT_DIR=%ROOT_DIR%\.git"

:: ---------------------------------------------------------------
:: D6 ���� - ���� �ڵ�� where python3 ����� �ŷ��ߴ�.
::   Microsoft Store ������ where ���� �ɸ����� ���� rc=9009 �� �״´�.
::   ���� ���ΰ� �ƴ϶� ���� ���� ���� ���η� �����ϵ��� �����ߴ�.
:: ---------------------------------------------------------------
set "PYTHON="
for %%P in (python python3 py) do (
    if not defined PYTHON (
        %%P -c "import sys" >nul 2>&1
        if not errorlevel 1 set "PYTHON=%%P"
    )
)
if not defined PYTHON (
    echo   ERROR: ���� ������ Python �� ã�� �� �����ϴ�.
    exit /b 1
)

:: -- �⺻ ���� --
set "AUTO=0"
set "STATUS=0"
set "INTERACTIVE=0"
set "DEPLOY_MODE=ask"
set "COMMIT_MSG="

:: ---------------------------------------------------------------
:: D2 ���� - ���� �ڵ�� if ���� set �׸��� shift �׸��� goto ��
::   ���ۻ��� �� �ٿ� ������ �� ��° �÷��׺��� ���� ���ȴ�.
::   ���� �÷��װ� ������ ���õǴ� ġ���� �����̾���.
::   �÷��׸��� ���� ���� �и��� ��� ���ڸ� ���� �νĽ�Ų��.
:: ---------------------------------------------------------------
:parse_args
if "%~1"=="" goto end_parse_args
if defined MSG_ONLY goto append_msg
if /i "%~1"=="--auto"          goto opt_auto
if /i "%~1"=="--status"        goto opt_status
if /i "%~1"=="--interactive"   goto opt_interactive
if /i "%~1"=="--ineteractive"  goto opt_interactive
if /i "%~1"=="-i"              goto opt_interactive
if /i "%~1"=="--deploy"        goto opt_deploy
if /i "%~1"=="--no-deploy"     goto opt_nodeploy
if /i "%~1"=="-h"              goto show_help
if /i "%~1"=="--help"          goto show_help
if /i "%~1"=="--" (
    set "MSG_ONLY=1"
    shift
    goto parse_args
)
:: D12 ���� - ���ν� �÷��׸� Ŀ�� �޽����� ������ ��Ű�� �ʴ´�.
::   ���� "--ineteractive"(��Ÿ) ó�� ���ڸ� �ָ� ������ ���õǰ�
::   auto Ŀ�Ը� ����ż� "�ɼ��� �� �Դ´�" �� ������ �߻��ߴ�.
::   ���� ��� ������ �˸��� ������ ����Ѵ�.
::   ����: cmd �� if ���ڿ� �񱳴� ���ϵ�ī�尡 ���� �����Ƿ�
::   "*" ���� ��� �κ� ���ڿ�(!_ARG:~0,1!)�� "-" ���λ縦 �Ǻ��Ѵ�.
set "_ARG=%~1"
if "!_ARG:~0,1!"=="-" goto unknown_flag
:append_msg
if defined COMMIT_MSG (
    set "COMMIT_MSG=%COMMIT_MSG% %~1"
) else (
    set "COMMIT_MSG=%~1"
)
shift
goto parse_args
:opt_auto
set "AUTO=1"
shift
goto parse_args
:opt_status
set "STATUS=1"
shift
goto parse_args
:opt_interactive
set "INTERACTIVE=1"
shift
goto parse_args
:unknown_flag
echo   ERROR: �� �� ���� �ɼ� "%~1"
call :print_usage
exit /b 1
:opt_deploy
set "DEPLOY_MODE=yes"
shift
goto parse_args
:opt_nodeploy
set "DEPLOY_MODE=no"
shift
goto parse_args
:end_parse_args

:: -- �귣ġ - detached HEAD ��� --
set "BRANCH=main"
for /f "usebackq delims=" %%i in (`git rev-parse --abbrev-ref HEAD 2^>nul`) do set "BRANCH=%%i"
if "!BRANCH!"=="" set "BRANCH=main"
if "!BRANCH!"=="HEAD" (
    echo   ERROR: detached HEAD �����Դϴ�. ���� �귣ġ�� üũ�ƿ� �Ͻʽÿ�.
    exit /b 1
)

:: -- ��� 1 - Status --
if "!STATUS!"=="1" goto status_mode
if "!INTERACTIVE!"=="1" call :branch_prompt
if "!AUTO!"=="0" if "!COMMIT_MSG!"=="" goto show_usage

set "REMOTES="
for /f "usebackq delims=" %%r in (`git remote 2^>nul`) do set "REMOTES=!REMOTES! %%r"
echo ================================================
echo   Kibal (SmartCC IP-PBX) Git Sync ^(Windows^)
echo   Branch: !BRANCH!
echo   Remotes:!REMOTES!
echo ================================================
echo.

:: ---------------------------------------------------------------
:: 1/4 Staging
:: D3 ���� - ���� �ڵ�� git add -u �� �Ἥ �ű� ������ ������¡���� �ʾҴ�.
::   �� ��� git-sync.bat �ڽ��� ������ untracked �� ���Ҵ�.
::   ���� sh �� �����ϰ� git add -A �� �����ߴ�.
::   Windows �������� gitignore �� �����Ѵ�.
:: ---------------------------------------------------------------
echo [1/4] Staging changes...
git add -A
if errorlevel 1 (
    echo   FAILED: git add
    call :log_result "FAILED" "1"
    exit /b 1
)
echo   ok
echo.

:: ---------------------------------------------------------------
:: 2/4 Commit
:: ---------------------------------------------------------------
if "!AUTO!"=="1" goto auto_commit
echo [2/4] Committing: !COMMIT_MSG!
git commit -m "!COMMIT_MSG!"
goto commit_done

:auto_commit
echo [2/4] Generating commit message...
if exist "%ROOT_DIR%\scripts\generate-commit-msg.py" (
    if exist "%GIT_DIR%\AUTO_COMMIT_MSG" del /f /q "%GIT_DIR%\AUTO_COMMIT_MSG" >nul 2>&1
    "%PYTHON%" "%ROOT_DIR%\scripts\generate-commit-msg.py" >nul 2>&1
    if errorlevel 1 echo   WARN: auto-generator had issues
)
set "FIRST_LINE="
if exist "%GIT_DIR%\AUTO_COMMIT_MSG" goto auto_msg_found
echo   Auto-generator not available. Using date-based message.
:: D8 ���� - date ������ ������ �����̶� �����ǿ��� MM-DD-YYYY �� �ȴ�.
::   ISO 8601 �� �����ϴ� ��η� ��ü�ߴ�. ���˹��ڿ� ȸ�ǰ� �����̴�.
set "MYDATE="
for /f "usebackq delims=" %%i in (`"%PYTHON%" -c "import datetime;print(str(datetime.datetime.now())[:16])" 2^>nul`) do set "MYDATE=%%i"
if not defined MYDATE set "MYDATE=%DATE%"
git commit -m "chore: !MYDATE! sync"
goto commit_done

:auto_msg_found
:: D5 ���� - ���� �ڵ�� ��ȣ ���� �ȿ� ���� �ΰ� for �ݺ��� �ڿ�
::   goto �� �ٿ� ù ���� ���Ϸ� ������ ������ �Ľ� �ܰ迡�� ������.
::   �󺧰� goto �� �����ϰ� ���� ������ ù �ٸ� �����Ѵ�.
:: D14 ���� - AUTO_COMMIT_MSG �� UTF-8(�� BOM) �̰� �ܼ��� CP949 �̹Ƿ�
::   �״�� echo �ϸ� �ѱ� ������ ���� ���δ�. generate-commit-msg.py ��
::   �ý��� ���ڵ����� ���� �� �ִ� AUTO_COMMIT_MSG_TITLE �� ǥ�ÿ����� ����,
::   ������ �������� �����Ѵ�. ���� Ŀ���� ������ UTF-8 ������ ����.
set "FIRST_LINE="
if exist "%GIT_DIR%\AUTO_COMMIT_MSG_TITLE" (
    for /f "usebackq delims=" %%i in ("%GIT_DIR%\AUTO_COMMIT_MSG_TITLE") do if not defined FIRST_LINE set "FIRST_LINE=%%i"
)
if not defined FIRST_LINE (
    for /f "usebackq delims=" %%i in ("%GIT_DIR%\AUTO_COMMIT_MSG") do if not defined FIRST_LINE set "FIRST_LINE=%%i"
)
if defined FIRST_LINE echo   Title: !FIRST_LINE!
git commit -F "%GIT_DIR%\AUTO_COMMIT_MSG"
goto commit_done

:commit_done
set "EXIT_CODE=!errorlevel!"
if "!EXIT_CODE!"=="0" goto commit_ok
if "!EXIT_CODE!"=="1" goto commit_nothing
echo   FAILED: git commit ^(rc=!EXIT_CODE!^)
call :log_result "FAILED" "!EXIT_CODE!"
exit /b 1

:commit_ok
set "RC=0"
goto commit_end
:commit_nothing
echo   Nothing to commit - all clean.
set "RC=2"
:commit_end
echo.

:: ---------------------------------------------------------------
:: 3/4 Push
:: ---------------------------------------------------------------
if "!RC!"=="2" goto push_skip
echo [3/4] Pushing to all remotes...
set "PUSH_OK=0"
set "PUSH_FAIL=0"
for /f "usebackq delims=" %%r in (`git remote 2^>nul`) do call :push_one "%%r"
echo   Push complete: !PUSH_OK! OK, !PUSH_FAIL! failed
echo.
:push_skip

:: ---------------------------------------------------------------
:: 4/4 Report
:: ---------------------------------------------------------------
echo [4/4] Sync Status Report
echo -----------------------------------------------
call :print_head
echo.
echo   Recent commits:
:: D4 ���� - �ֻ��� �������� caret �� ���ŵ��� �ʰ� git ���� ���ͷ��� ���޵Ǿ�
::   ambiguous argument ������ ����. ���⼭�� caret ���� ����.
git --no-pager log --oneline -5 2>nul
if errorlevel 1 echo   ^(none^)
echo.
echo   Remotes:
git remote -v 2>nul
echo.
echo   [Remote Sync]
call :print_remote_sync
echo -----------------------------------------------
if "!RC!"=="0" echo   RESULT: All OK
if "!RC!"=="2" echo   RESULT: Nothing to commit
echo ================================================

:: ---------------------------------------------------------------
:: 5/5 PRD NAS ����
:: DEPLOY_MODE ���� ask �Ǵ� yes �Ǵ� no
:: ---------------------------------------------------------------
if "!DEPLOY_MODE!"=="no" goto end_deploy
if "!RC!"=="0" goto deploy_gate_ok
if "!RC!"=="2" goto deploy_gate_ok
echo   ^(����ȭ ���� - ���� �ǳʶ�^)
goto end_deploy
:deploy_gate_ok
if "!DEPLOY_MODE!"=="yes" goto do_deploy

:: ask ��� - �Է��� ������ set ������ EOF �� �����Ͽ� n �� �����ǹǷ� �ڵ� �����ȴ�
if "!RC!"=="2" echo   ^(Ŀ���� ���� ���� - ���� ���� ���� ���� ���� ����^)
set "ans=n"
set /p "ans=  PRD NAS �� �����Ͻðڽ��ϱ�? [y/N] "
if /i "!ans!"=="y" goto do_deploy
if /i "!ans!"=="yes" goto do_deploy
echo   ���� ����.
goto end_deploy

:do_deploy
echo.
echo [5/5] PRD NAS ����
echo -----------------------------------------------
set "DEPLOY_KIND="
if exist "%ROOT_DIR%\deploy_to_nas_v2.bat" set "DEPLOY_KIND=bat"
if not defined DEPLOY_KIND if exist "%ROOT_DIR%\deploy_to_nas_v2.sh" set "DEPLOY_KIND=sh"
if not defined DEPLOY_KIND goto deploy_missing
if "!DEPLOY_KIND!"=="bat" goto deploy_bat

:: ---------------------------------------------------------------
:: D7 ���� - ���� �ڵ�� bash �� �̸����θ� ȣ���ߴ�.
::   Windows PATH ������ WSL ���۰� Git bash ���� �켱�Ǹ�
::   ���� �� ȯ�濡�� WSL �� ��ġ�� ���� �ʾ� ��� �����ߴ�.
::   Git for Windows �� bash �� ���� ��η� ã�� ������ �ߴ��Ѵ�.
:: ---------------------------------------------------------------
call :resolve_git_bash
if not defined GIT_BASH goto deploy_no_bash
call :warn_crlf "%ROOT_DIR%\deploy_to_nas_v2.sh"
"!GIT_BASH!" "%ROOT_DIR%\deploy_to_nas_v2.sh"
goto deploy_result

:deploy_bat
call "%ROOT_DIR%\deploy_to_nas_v2.bat"
goto deploy_result

:deploy_missing
echo   ERROR: deploy_to_nas_v2 ��ũ��Ʈ�� ã�� �� �����ϴ�.
goto deploy_failed
:deploy_no_bash
echo   ERROR: Git for Windows �� bash �� ã�� �� �����ϴ�.
echo          Program Files under Git under bin under bash.exe �� Ȯ���Ͻʽÿ�.
echo          WSL bash �� �� ������Ʈ �� ��ũ��Ʈ�� ȣȯ���� �ʽ��ϴ�.
goto deploy_failed

:deploy_result
set "DEPLOY_RC=!errorlevel!"
if "!DEPLOY_RC!"=="0" goto deploy_ok
echo   WARN: ���� ���� ^(rc=!DEPLOY_RC!^) - ����ȭ�� ���� �Ϸ�, ���� ���� ���� �ʿ�
goto end_deploy
:deploy_failed
set "DEPLOY_RC=1"
:deploy_ok

:end_deploy
call :log_result "PASSED" "!RC!"
:: D9 ���� - ���� sh �� �����ϰ� ���� �ڵ��� �� FAILED �� ����Ѵ�
if not "!RC!"=="0" call :log_result "FAILED" "!RC!"
exit /b !RC!


:: ===============================================================
:: Status ���
:: ===============================================================
:status_mode
echo ================================================
echo   Kibal (SmartCC IP-PBX) Git Status ^(Windows^)
echo   %DATE% %TIME%
echo ================================================
echo.
echo   Branch: !BRANCH!
call :print_head
echo.
set "DIRTY=0"
for /f "usebackq delims=" %%i in (`git status --short 2^>nul ^| find /c /v ""`) do set "DIRTY=%%i"
if not defined DIRTY set "DIRTY=0"
if "!DIRTY!"=="0" goto tree_clean
echo   Tree: !DIRTY! pending
goto tree_done
:tree_clean
echo   Tree: clean
:tree_done
echo.
echo   [Remote Sync]
call :print_remote_sync
echo.
echo   [Recent Commits]
git --no-pager log --oneline -5 2>nul
if errorlevel 1 echo   ^(none^)
echo.
if "!DIRTY!"=="0" echo   Tree is clean - nothing to commit or push
if not "!DIRTY!"=="0" echo   [Quick Actions]
if not "!DIRTY!"=="0" echo     -^> scripts\git-sync.bat --auto
if not "!DIRTY!"=="0" echo     -^> scripts\git-sync.bat --auto --deploy
if not "!DIRTY!"=="0" echo     -^> scripts\git-sync.bat --status
echo ================================================
exit /b 0


:: ===============================================================
:: Subroutines
:: ===============================================================

:: ---------------------------------------------------------------
:: ��ȭ�� �귣ġ ���� �޴� (--interactive / -i)
::   SLACK_AI_Assistant/scripts/git-sync.bat �� :branch_prompt ��
::   ����/�귣ġ��/N(new) ��� �޴� ���·� �̽��ߴ�.
::   ����: call �� ȣ��� �����ƾ�̶� ��� goto �� �� ���ؽ�Ʈ �ȿ� �ӹ���.
:: ---------------------------------------------------------------
:branch_prompt
echo.
echo ================================================
echo   �귣ġ ���� - ����: !BRANCH!
echo ================================================
echo.
echo   0) !BRANCH! ^(����, Enter=�״��^)
set "_BP_N=0"
for /f "usebackq delims=" %%b in (`git branch --format="%%(refname:short)" 2^>nul`) do (
    if /i not "%%b"=="!BRANCH!" (
        set /a _BP_N+=1
        echo   !_BP_N!^) %%b
    )
)
set /a _BP_N+=1
set "_BP_NEW=!_BP_N!"
echo   !_BP_NEW!^) [�� �귣ġ �����]
echo.
:bp_ask
set "bp_sel="
set /p "bp_sel=  ���� (Enter=����, ����=��ȯ, N=�ű�): "
if not defined bp_sel goto :eof
if /i "!bp_sel!"=="n" goto branch_prompt_new
echo !bp_sel!| findstr /r "^[0-9][0-9]*$" >nul 2>&1
if errorlevel 1 goto bp_by_name
if "!bp_sel!"=="0" goto :eof
if "!bp_sel!"=="!_BP_NEW!" goto branch_prompt_new
goto bp_by_number

:bp_by_number
set "_BP_C=0"
set "_BP_T="
for /f "usebackq delims=" %%b in (`git branch --format="%%(refname:short)" 2^>nul`) do (
    if /i not "%%b"=="!BRANCH!" (
        set /a _BP_C+=1
        if "!_BP_C!"=="!bp_sel!" set "_BP_T=%%b"
    )
)
if defined _BP_T goto bp_switch
echo   �߸��� �����Դϴ�.
goto :bp_ask

:bp_by_name
git show-ref --verify --quiet "refs/heads/!bp_sel!" 2>nul
if errorlevel 1 (
    echo   �Է� ����. ���� / ��Ȯ�� �귣ġ�� / N �� �ϳ��� �Է��ϼ���.
    goto :bp_ask
)
set "_BP_T=!bp_sel!"

:bp_switch
git checkout "!_BP_T!" >nul 2>&1
if errorlevel 1 (
    echo   ��ȯ ����: "!_BP_T!"
    goto :eof
)
set "BRANCH=!_BP_T!"
echo   ��ȯ��: !BRANCH!
goto :eof

:branch_prompt_new
echo.
set "new_branch="
set /p "new_branch=  �� �귣ġ�� �Է� (Enter=���): "
if not defined new_branch goto :eof
set "confirm="
set /p "confirm=  �귣ġ !new_branch! �� ������? (Y/N): "
if /i not "!confirm!"=="y" (
    echo   ����߽��ϴ�.
    goto :eof
)
git checkout -b "!new_branch!" >nul 2>&1
if errorlevel 1 (
    echo   ����: �̹� �ְų� �߸��� �̸��Դϴ�.
    goto :eof
)
set "BRANCH=!new_branch!"
echo   �� �귣ġ�� ��ȯ: !BRANCH!
goto :eof

:print_head
for /f "usebackq delims=" %%i in (`git rev-parse --short HEAD 2^>nul`) do echo   HEAD: %%i
goto :eof

:: D11 ���� - �׸��� �����ƾ ���ڴ� ���� �ۼ�Ʈ�� �ƴ϶� ���� �ۼ�Ʈ�� �޴´�. - rev-list �� �����ϸ� �ݺ����� �ƹ� �͵� ������� �ʾ�
::   �ش� remote �� ���������� ��°�� �������. �⺻���� �����Ѵ�.
:print_remote_sync
for /f "usebackq delims=" %%r in (`git remote 2^>nul`) do call :print_one_remote "%%r"
goto :eof

:print_one_remote
set "_R=%~1"
set "_BEHIND=0"
set "_AHEAD=0"
set "_REF=!_R!/!BRANCH!"
git show-ref --verify --quiet "refs/remotes/!_REF!" 2>nul
if not errorlevel 1 (
    for /f "tokens=1,2" %%a in (`git rev-list --left-right --count "!_REF!...HEAD" 2^>nul`) do (
        set "_BEHIND=%%a"
        set "_AHEAD=%%b"
    )
)
if not "!_BEHIND!"=="0" echo     !_R!: behind=!_BEHIND! ahead=!_AHEAD!
if "!_BEHIND!"=="0" if "!_AHEAD!"=="0" echo     !_R!: in sync
if "!_BEHIND!"=="0" if not "!_AHEAD!"=="0" echo     !_R!: ahead=!_AHEAD!
goto :eof

:push_one
set "_R=%~1"
:push_retry
echo     Pushing to !_R!/!BRANCH!...
git push "!_R!" "!BRANCH!" >nul 2>&1
if errorlevel 1 (
    if "!INTERACTIVE!"=="1" (
        set "retry_ans="
        set /p "retry_ans=    !_R! push ����. ��õ��ұ��? (Y/N): "
        if /i "!retry_ans!"=="y" goto push_retry
    )
    echo     WARN: !_R! push failed
    set /a PUSH_FAIL+=1
) else (
    echo     !_R!: OK
    set /a PUSH_OK+=1
)
goto :eof

:: ProgramFiles86 ������ ��ȣ�� ������ for ���� ���� ��� �Ľ��� ���߸���.
::   �ֻ������� ������ ĸó�� �� ���� Ȯ������ �����Ͽ� ȸ���Ѵ�.
:resolve_git_bash
set "GIT_BASH="
set "_PF86="
if exist "%ProgramFiles(x86)%" set "_PF86=%ProgramFiles(x86)%"
for %%B in ("%ProgramFiles%\Git\bin\bash.exe" "!_PF86!\Git\bin\bash.exe" "!_PF86!\Git\usr\bin\bash.exe") do (
    if not defined GIT_BASH if exist %%B set "GIT_BASH=%%~B"
)
if defined GIT_BASH goto :eof
for /f "usebackq delims=" %%B in (`where bash 2^>nul`) do (
    if not defined GIT_BASH (
        set "_B=%%~B"
        echo !_B! | find /i "Git" >nul
        if not errorlevel 1 set "GIT_BASH=!_B!"
    )
)
goto :eof

:: core.autocrlf �� ���� ������ �� ��ũ��Ʈ�� CRLF �� üũ�ƿ��Ǿ� ������ ������.
::   ���� ���� �������� ����Ѵ�.
:warn_crlf
set "_F=%~1"
if not exist "!_F!" goto :eof
"%PYTHON%" -c "import sys;d=open(sys.argv[1],'rb').read();sys.exit(0 if b'\r\n' in d else 1)" "!_F!" >nul 2>&1
if not errorlevel 1 (
    echo   WARN: ���� ��� �� ��ũ��Ʈ�� CRLF �� üũ�ƿ��Ǿ� �ֽ��ϴ� - core.autocrlf ����.
    echo         gitattributes �߰� �� git add --renormalize . �� �����Ͻʽÿ�.
)
goto :eof

:log_result
if exist "%ROOT_DIR%\scripts\log.py" (
    "%PYTHON%" "%ROOT_DIR%\scripts\log.py" "git-sync" "%~1" "0" --desc "branch=!BRANCH! rc=%~2" >nul 2>&1
)
goto :eof

:print_usage
echo Usage: %~nx0 "commit message"
echo        %~nx0 --auto             (auto-generate from log)
echo        %~nx0 --auto --deploy    (sync + PRD ���� �ڵ�)
echo        %~nx0 --auto --no-deploy (sync, ���� ���� ����)
echo        %~nx0 --status           (show sync status)
echo        %~nx0 --auto --interactive ^(branch menu + sync^)
echo        %~nx0 -i                 ^(interactive short form^)
echo        %~nx0 "msg" --           ^(end of options^)
goto :eof

:: D10 ���� - help �� ���� �ȳ��̹Ƿ� 0, ���� ���� ȣ���� ���� 1
:show_help
call :print_usage
exit /b 0
:show_usage
call :print_usage
exit /b 1
