[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$InstallName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Call {
  param([string]$Command)
  Write-Host " [RUNNING]: $Command" -ForegroundColor Cyan
  Invoke-Expression $Command
}

$pathInstall = Join-Path -Path $PSScriptRoot -ChildPath "..\apps\$InstallName"
$pathOutput  = Join-Path -Path $PSScriptRoot -ChildPath "..\outputs"
$envName     = "wan2gp-$InstallName"

if (-not (Test-Path -Path $pathOutput)) {
  mkdir $pathOutput
}

Call "git clone https://github.com/deepbeepmeep/Wan2GP.git $pathInstall"

Set-Location -Path $pathInstall

$condaEnvList = conda env list | Out-String

if ($condaEnvList -match $envName) {
  conda remove -n $envName -y
}

Call "conda create -n $envName python=3.10.9 -y"

Call "conda run -n $envName pip install hf_xet"
Call "conda run -n $envName pip install torch==2.6.0+cu126 torchvision==0.21.0+cu126 torchaudio==2.6.0+cu126 --index-url https://download.pytorch.org/whl/cu126"
Call "conda run -n $envName pip install -r requirements.txt"

"conda run -n $envName --no-capture-output python wgp.py --output-dir $pathOutput" | Out-File -FilePath run.cmd -Encoding utf8

Write-Host "cd /d $pathInstall"      -ForegroundColor Green
Write-Host "conda activate $envName" -ForegroundColor Green
Write-Host "./run.cmd"               -ForegroundColor Green