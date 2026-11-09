@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: CD to the script location so relative paths work
cd /d "%~dp0"

:: Setup Variables
set "TS=%DATE:~-4%.%DATE:~4,2%.%DATE:~7,2%-%TIME:~0,2%%TIME:~3,2%"
set "TS=%TS: =0%"
set "NODES_FILE=customnodes.txt"
set "SKIP_NODES=false"

:: Parse arguments
:parse_args
if "%~1"=="" goto :args_done
if "%~1"=="--help" (
    echo Usage: install-comfy.cmd [--name ^<dir^>] [--customnodes ^<path^>] [--skip-custom-nodes]
    echo.
    echo   --name ^<dir^>            Name for the install directory and conda env
    echo                           (default: date-timestamp, e.g. comfy-2026.11.06-1310^)
    echo   --customnodes ^<path^>    Path to a .txt file listing custom nodes, one per line
    echo                           (default: customnodes.txt next to this script^)
    echo   --skip-custom-nodes     Skip custom node installation entirely
    echo   --help                  Show this help and exit
    exit /b 0
)
if "%~1"=="--name" (
    if "%~2"=="" (
        echo --name requires a value.
        exit /b 1
    )
    set "INSTALL_NAME=%~2"
    shift & shift
    goto :parse_args
)
if "%~1"=="--customnodes" (
    if "%~2"=="" (
        echo --customnodes requires a value.
        exit /b 1
    )
    set "NODES_FILE=%~2"
    shift & shift
    goto :parse_args
)
if "%~1"=="--skip-custom-nodes" (
    set "SKIP_NODES=true"
    shift
    goto :parse_args
)
echo Unknown argument: %~1
exit /b 1
:args_done

:: Minimal sanity check on custom install name (no path separators or reserved chars)
if defined INSTALL_NAME (
    echo !INSTALL_NAME!| findstr /r /c:"[ /\\:*?<>|]" >nul && (
        echo Invalid --name value: !INSTALL_NAME!
        exit /b 1
    )
)

:: Use custom install name if given, otherwise the timestamp
if not defined INSTALL_NAME set "INSTALL_NAME=%TS%"
set "ENV=comfy-%INSTALL_NAME%"
for %%I in ("..\installs\%INSTALL_NAME%") do set "WORKSPACE=%%~fI"
for %%I in ("..\common") do set "COMMON=%%~fI"

:: Create and activate conda environment
call conda create --name "%ENV%" python=3.12 -y || goto :error
call conda activate "%ENV%" || goto :error

:: Install pip packages (matrix-nio is just to remove some warnings on startup)
python -m pip install comfy-cli triton-windows matrix-nio || goto :error

:: Detect GPU type and choose comfy install flags
call :DetectGPU || goto :error
echo Detected GPU: %GPU_TYPE% - installing with %GPU_ARGS%

:: Install comfy
comfy --workspace="%WORKSPACE%" --skip-prompt install %GPU_ARGS% --fast-deps || goto :error

:: Install custom nodes
if "%SKIP_NODES%"=="true" (
    echo Skipping custom node install.
    goto :after_nodes
)

call :LoadNodeArgs "%NODES_FILE%" || goto :error

if not defined NODE_ARGS (
    echo No custom nodes listed in "%NODES_FILE%" - skipping node install.
    goto :after_nodes
)

comfy node install --uv-compile --exit-on-fail %NODE_ARGS% || goto :error

:after_nodes

if not exist "%WORKSPACE%\user\default\workflows" mkdir "%WORKSPACE%\user\default\workflows"
if not exist "%COMMON%\output" mkdir "%COMMON%\output"
if not exist "%COMMON%\input" mkdir "%COMMON%\input"
call :CreateLinkedDirectory "%COMMON%\models" "%WORKSPACE%\models" || goto :error
call :CreateLinkedDirectory "%COMMON%\workflows" "%WORKSPACE%\user\default\workflows" || goto :error

set "LAUNCH_SCRIPT=%WORKSPACE%\run.cmd"

> "%LAUNCH_SCRIPT%" (
    echo @echo off
    echo call conda activate "%ENV%"
    echo comfy --workspace="%WORKSPACE%" launch -- --output-directory "%COMMON%\output" --input-directory "%COMMON%\input"
)
if errorlevel 1 goto :error

echo.
echo Done! To launch, run:
echo   %LAUNCH_SCRIPT%
exit /b 0

:CreateLinkedDirectory
setlocal
set "directory1=%~f1"
set "directory2=%~f2"

:: Ensure source exists
if not exist "%directory1%\" mkdir "%directory1%"

:: If target has content (e.g. freshly scaffolded dirs), move it into the source first
if exist "%directory2%\" (
    robocopy "%directory2%" "%directory1%" /E /MOVE >nul
    if errorlevel 8 goto :cle_fail
)

:: Remove leftover target dir/link, then create junction
if exist "%directory2%\." rmdir /s /q "%directory2%"
if exist "%directory2%" goto :cle_fail
mklink /J "%directory2%" "%directory1%" >nul || goto :cle_fail
endlocal & exit /b 0

:cle_fail
endlocal
exit /b 1

:: DetectGPU - detects GPU type and sets GPU_TYPE and GPU_ARGS
:DetectGPU
set "GPU_ARGS=--cpu"

nvidia-smi --query-gpu=name --format=csv,noheader >nul 2>&1

if not errorlevel 1 (
    set "GPU_ARGS=--nvidia"
    set "GPU_TYPE=NVIDIA"
    exit /b 0
)

for /f "delims=" %%G in ('powershell -NoProfile -Command "(Get-CimInstance Win32_VideoController).Name"') do (
    echo %%G | findstr /i "AMD Radeon" >nul && (
        set "GPU_ARGS=--amd"
        set "GPU_TYPE=AMD"
    )
)

if not defined GPU_TYPE set "GPU_TYPE=Intel or unsupported (falling back to CPU)"
exit /b 0

:: LoadNodeArgs <file> - reads node names (one per line) from a file into NODE_ARGS.
:: Skips # comment lines, strips inline # comments and leading whitespace.
:LoadNodeArgs
setlocal EnableDelayedExpansion
set "file=%~f1"
if not exist "%file%" (
    echo Nodes file "%~1" not found.
    endlocal
    exit /b 1
)
set "args="
for /f "usebackq eol=# delims=" %%L in ("%file%") do (
    set "line=%%L"
    :: Strip inline comment: keep everything before the first #
    for /f "delims=#" %%C in ("!line!") do set "line=%%C"
    :: Trim leading whitespace
    for /f "tokens=* delims= " %%T in ("!line!") do set "line=%%T"
    if not "!line!"=="" set "args=!args! !line!"
)
endlocal & set "NODE_ARGS=%args%"
exit /b 0

:error
echo.
echo install-comfy.cmd failed with error code %errorlevel%.
exit /b %errorlevel%
