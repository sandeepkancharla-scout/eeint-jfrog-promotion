@echo off
setlocal EnableExtensions
title Scout Hotfix Upload

cls
echo.
echo ==============================================
echo          SCOUT HOTFIX UPLOAD
echo ==============================================
echo.

REM ============================================================
REM LOCAL FOLDER
REM ============================================================

set "LOCAL_FOLDER="

set /p "LOCAL_FOLDER=Enter Local Folder Path: "

if "%LOCAL_FOLDER%"=="" (
    echo.
    echo ERROR: Local Folder Path is required.
    echo.
    pause
    exit /b 1
)

if not exist "%LOCAL_FOLDER%\" (
    echo.
    echo ERROR: Folder does not exist:
    echo %LOCAL_FOLDER%
    echo.
    pause
    exit /b 1
)


REM ============================================================
REM CALENDAR WEEK
REM ============================================================

echo.

set "CW_PATH="

set /p "CW_PATH=Enter CW Path (example CW11): "

if "%CW_PATH%"=="" (
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

set /p "HF_NAME=Enter HF Name (example HF01): "

if "%HF_NAME%"=="" (
    echo.
    echo ERROR: HF Name is required.
    echo.
    pause
    exit /b 1
)


REM ============================================================
REM POWERSHELL SCRIPT
REM upload-hotfix.ps1 must be beside this BAT file.
REM ============================================================

set "PS_SCRIPT=%~dp0upload-hotfix.ps1"

if not exist "%PS_SCRIPT%" (
    echo.
    echo ==============================================
    echo ERROR
    echo ==============================================
    echo.
    echo upload-hotfix.ps1 was not found.
    echo.
    echo Expected:
    echo %PS_SCRIPT%
    echo.
    pause
    exit /b 1
)


REM ============================================================
REM DISPLAY REQUEST
REM ============================================================

for %%F in ("%LOCAL_FOLDER%") do set "FOLDER_NAME=%%~nxF"

echo.
echo ==============================================
echo          UPLOAD CONFIGURATION
echo ==============================================
echo.
echo Local Folder:
echo %LOCAL_FOLDER%
echo.
echo Local Folder Name:
echo %FOLDER_NAME%
echo.
echo Calendar Week:
echo %CW_PATH%
echo.
echo Hotfix:
echo %HF_NAME%
echo.
echo Scout Target:
echo Official_Release/%CW_PATH%/Hotfixes/%HF_NAME%/%FOLDER_NAME%
echo.
echo ==============================================
echo.

choice /C YN /M "Continue with upload"

if errorlevel 2 (
    echo.
    echo Upload cancelled.
    echo.
    pause
    exit /b 0
)


REM ============================================================
REM RUN POWERSHELL
REM
REM PowerShell will securely ask:
REM Enter Scout JFrog Access Token
REM
REM Token characters are NOT shown.
REM ============================================================

echo.
echo Starting upload...
echo.

pwsh.exe ^
    -NoLogo ^
    -NoProfile ^
    -ExecutionPolicy Bypass ^
    -File "%PS_SCRIPT%" ^
    -LocalFolder "%LOCAL_FOLDER%" ^
    -CWPath "%CW_PATH%" ^
    -HFName "%HF_NAME%"

set "EXIT_CODE=%ERRORLEVEL%"


REM ============================================================
REM RESULT
REM ============================================================

echo.

if not "%EXIT_CODE%"=="0" (

    echo ==============================================
    echo              UPLOAD FAILED
    echo ==============================================
    echo.
    echo Exit Code: %EXIT_CODE%
    echo.
    echo Check the error above for details.
    echo.

    pause

    exit /b %EXIT_CODE%
)


echo ==============================================
echo         HOTFIX UPLOAD SUCCESSFUL
echo ==============================================
echo.
echo Scout Location:
echo.
echo Official_Release/%CW_PATH%/Hotfixes/%HF_NAME%/%FOLDER_NAME%
echo.
echo ==============================================
echo.

pause

exit /b 0
