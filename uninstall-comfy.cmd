@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: CD to the script location so relative paths work
cd /d "%~dp0"

:: Setup Variables
for %%I in ("..\installs") do set "INSTALLS_DIR=%%~fI"

if "%~1"=="" goto :interactive_mode

:: Remove each named install passed as arguments
:remove_args
if "%~1"=="" goto :done
call :RemoveInstall "%~1"
if errorlevel 1 goto :error
shift
goto :remove_args

:done
echo.
echo Done!
exit /b 0

:: Interactive mode: remove all installs except the most recently created
:interactive_mode
if not exist "%INSTALLS_DIR%\" (
    echo Install directory not found: %INSTALLS_DIR%
    exit /b 1
)

:: Enumerate install dirs sorted by creation time (oldest first)
set "COUNT=0"
for /f "delims=" %%D in ('powershell -NoProfile -Command "Get-ChildItem -LiteralPath '%INSTALLS_DIR%' -Directory | Sort-Object CreationTime | ForEach-Object { $_.Name }"') do (
    set /a COUNT+=1
    set "DIR_!COUNT!=%%D"
)

if %COUNT% LEQ 1 (
    echo No directories found to remove: %INSTALLS_DIR%
    exit /b 1
)

:: The last one in creation order is the most recent
set "MOST_RECENT="
for /l %%N in (1,1,%COUNT%) do set "MOST_RECENT=!DIR_%%N!"

set "REMOVAL_LIST="
for /l %%N in (1,1,!COUNT!) do (
    if not "!DIR_%%N!"=="!MOST_RECENT!" set "REMOVAL_LIST=!REMOVAL_LIST! "!DIR_%%N!""
)

echo Remove these installs?
for /l %%N in (1,1,!COUNT!) do (
    if not "!DIR_%%N!"=="!MOST_RECENT!" echo   %INSTALLS_DIR%\!DIR_%%N!
)
echo.
echo This will be kept:
echo %INSTALLS_DIR%\!MOST_RECENT!
echo.
set "RESPONSE="
set /p "RESPONSE=Press Enter to remove, Ctrl-C to cancel... "

for %%D in (!REMOVAL_LIST!) do (
    call :RemoveInstall "%%~D"
    if errorlevel 1 goto :error
)

echo.
echo Done!
exit /b 0

:: RemoveInstall <name> - removes the conda env and workspace for an install
:RemoveInstall
setlocal
set "VERSION=%~1"
set "CONDA_ENV=comfy-%VERSION%"
set "WORKSPACE=%INSTALLS_DIR%\%VERSION%"

echo Removing Conda: %CONDA_ENV%
call conda env remove -y -n "%CONDA_ENV%"

echo Removing Workspace: %WORKSPACE%
if exist "%WORKSPACE%\" rmdir /s /q "%WORKSPACE%"
if exist "%WORKSPACE%" (
    echo Failed to remove workspace: %WORKSPACE%
    endlocal
    exit /b 1
)

echo.
endlocal
exit /b 0

:error
echo.
echo uninstall-comfy.cmd failed with error code %errorlevel%.
exit /b %errorlevel%
