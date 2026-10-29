@echo off
setlocal EnableExtensions EnableDelayedExpansion

title Scout Hotfix Upload
cls

echo.
echo ==============================================
echo          SCOUT HOTFIX UPLOAD
echo ==============================================
echo.

REM ============================================================
REM LOCAL FOLDER
REM Supports spaces and parentheses, for example:
REM C:\Users\User\Downloads\softwareartifact (1)
REM ============================================================

set "LOCAL_FOLDER="
set /p "LOCAL_FOLDER=Enter Local Folder Path: "

if not defined LOCAL_FOLDER (
    echo.
    echo ERROR: Local Folder Path is required.
    echo.
    pause
    exit /b 1
)

REM Remove surrounding quotation marks if the user pasted them.
set "LOCAL_FOLDER=!LOCAL_FOLDER:"=!"

REM Validate using PowerShell instead of CMD IF EXIST.
powershell.exe -NoLogo -NoProfile -Command ^
    "if (Test-Path -LiteralPath $env:LOCAL_FOLDER -PathType Container) { exit 0 } else { exit 1 }"

if errorlevel 1 (
    echo.
    echo ERROR: Folder does not exist or cannot be accessed:
    echo !LOCAL_FOLDER!
    echo.
    pause
    exit /b 1
)


REM ============================================================
REM CALENDAR WEEK
REM ============================================================

echo.

set "CW_PATH="
set /p "CW_PATH=Enter CW Path (example CW11 or 11): "

if not defined CW_PATH (
    echo.
    echo ERROR: CW Path is required.
    echo.
    pause
    exit /b 1
)


REM ============================================================
REM HOTFIX NAME
REM ============================================================

echo.

set "HF_NAME="
set /p "HF_NAME=Enter HF Name (example HF01 or 01): "

if not defined HF_NAME (
    echo.
    echo ERROR: HF Name is required.
    echo.
    pause
    exit /b 1
)


REM ============================================================
REM LOCATE POWERSHELL SCRIPT
REM ============================================================

set "PS_SCRIPT=%~dp0upload-hotfix.ps1"

if not exist "!PS_SCRIPT!" (
    echo.
    echo ==============================================
    echo ERROR
    echo ==============================================
    echo.
    echo upload-hotfix.ps1 was not found.
    echo.
    echo Expected location:
    echo !PS_SCRIPT!
    echo.
    pause
    exit /b 1
)


REM ============================================================
REM DETERMINE LOCAL FOLDER NAME
REM Uses PowerShell to handle parentheses and spaces safely.
REM ============================================================

set "FOLDER_NAME="

for /f "usebackq delims=" %%F in (`powershell.exe -NoLogo -NoProfile -Command "(Get-Item -LiteralPath $env:LOCAL_FOLDER).Name"`) do (
    set "FOLDER_NAME=%%F"
)

if not defined FOLDER_NAME (
    echo.
    echo ERROR: Could not determine the local folder name.
    echo.
    pause
    exit /b 1
)


REM ============================================================
REM SHOW CONFIGURATION
REM CW and HF are normalized by upload-hotfix.ps1:
REM cw11 becomes CW11
REM 11 becomes CW11
REM hf01 becomes HF01
REM 01 becomes HF01
REM ============================================================

echo.
echo ==============================================
echo          UPLOAD CONFIGURATION
echo ==============================================
echo.
echo Local Folder:
echo !LOCAL_FOLDER!
echo.
echo Folder Name:
echo !FOLDER_NAME!
echo.
echo CW Input:
echo !CW_PATH!
echo.
echo HF Input:
echo !HF_NAME!
echo.
echo Expected target:
echo Official_Release/[normalized CW]/Hotfixes/[normalized HF]/!FOLDER_NAME!
echo.
echo ==============================================
echo.


REM ============================================================
REM CONFIRMATION
REM ============================================================

choice /C YN /M "Continue with upload"

if errorlevel 2 (
    echo.
    echo Upload cancelled.
    echo.
    pause
    exit /b 0
)


REM ============================================================
REM RUN POWERSHELL UPLOADER
REM ============================================================

echo.
echo Starting PowerShell uploader...
echo.

pwsh.exe ^
    -NoLogo ^
    -NoProfile ^
    -ExecutionPolicy Bypass ^
    -File "!PS_SCRIPT!" ^
    -LocalFolder "!LOCAL_FOLDER!" ^
    -CWPath "!CW_PATH!" ^
    -HFName "!HF_NAME!"

set "EXIT_CODE=!ERRORLEVEL!"


REM ============================================================
REM RESULT
REM ============================================================

echo.

if not "!EXIT_CODE!"=="0" (
    echo.
    echo ==============================================
    echo              UPLOAD FAILED
    echo ==============================================
    echo.
    echo Exit Code: !EXIT_CODE!
    echo.
    echo Review the PowerShell error displayed above.
    echo.
    pause
    exit /b !EXIT_CODE!
)

echo.
echo ==============================================
echo         HOTFIX UPLOAD SUCCESSFUL
echo ==============================================
echo.
echo Uploaded folder:
echo !FOLDER_NAME!
echo.
echo ==============================================
echo.

pause
exit /b 0