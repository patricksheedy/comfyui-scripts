[CmdletBinding()]

param(
  [Parameter(Mandatory=$true)]
  [string]$InstallName
)

Set-StrictMode -Version Latest
Install-Module 7Zip4Powershell -Scope CurrentUser -Force

$pathSharedApps             = Join-Path -Path $PSScriptRoot       -ChildPath "..\apps"
$pathSharedReleases         = Join-Path -Path $PSScriptRoot       -ChildPath "..\releases"
$pathSharedModels           = Join-Path -Path $PSScriptRoot       -ChildPath "..\models"
$pathSharedOutputs          = Join-Path -Path $PSScriptRoot       -ChildPath "..\outputs"
$pathSharedWorkflows        = Join-Path -Path $PSScriptRoot       -ChildPath "..\workflows"
$pathSharedIncludesPath     = Join-Path -Path $pathSharedReleases -ChildPath "python_3.12.7_include_libs"
$pathSharedIncludesArchive  = Join-Path -Path $pathSharedReleases -ChildPath "python_3.12.7_include_libs.zip"
$pathDestination            = Join-Path -Path $pathSharedApps     -ChildPath $InstallName
$pathRunCommand             = Join-Path -Path $pathDestination    -ChildPath "run.cmd"
$pathWorkflow               = Join-Path -Path $pathDestination    -ChildPath "ComfyUI\user\default\workflows"
$pathModels                 = Join-Path -Path $pathDestination    -ChildPath "ComfyUI\models"
$pathCustomNodes            = Join-Path -Path $pathDestination    -ChildPath "ComfyUI\custom_nodes"
$pathCustomNodeManager      = Join-Path -Path $pathCustomNodes    -ChildPath "ComfyUI-Manager"

function Add-SharedDirectories {
  $directories = @($pathSharedApps, $pathSharedReleases, $pathSharedModels, $pathSharedOutputs, $pathSharedWorkflows)

  foreach ($directory in $directories) {
    if (-not (Test-Path -Path $directory)) {
      New-Item -Path $directory -ItemType Directory | Out-Null
    }
  }
}

function Get-LatestReleaseInfo { return Invoke-RestMethod -Uri "https://api.github.com/repos/comfyanonymous/ComfyUI/releases/latest" }

function Get-ReleaseFiles { 
  param([PSCustomObject]$Release)

  $asset            = $Release.assets | Select-Object -First 1
  $version          = $Release.tag_name
  $releaseRoot      = Join-Path -Path $pathSharedReleases -ChildPath $version
  $releaseArchive   = Join-Path -Path $releaseRoot -ChildPath "release.7z"
  $releaseExtracted = Join-Path -Path $releaseRoot -ChildPath "extracted"
  
  if (-not (Test-Path -Path $pathSharedIncludesArchive)) {
    Start-BitsTransfer -Source "https://github.com/woct0rdho/triton-windows/releases/download/v3.0.0-windows.post1/python_3.12.7_include_libs.zip" -Destination $pathSharedIncludesArchive
  }

  if (-not (Test-Path -Path $pathSharedIncludesPath)) {
    Expand-Archive -Path $pathSharedIncludesArchive -DestinationPath $pathSharedIncludesPath -Force
  }

  if (-not (Test-Path -Path $releaseRoot)) {
    New-Item -Path $releaseRoot -ItemType Directory | Out-Null
  }

  if (-not (Test-Path -Path $releaseArchive)) {
    Start-BitsTransfer -Source $asset.browser_download_url -Destination $releaseArchive
  }

  if (-not (Test-Path -Path $releaseExtracted)) {
    Expand-7Zip -ArchiveFileName $releaseArchive -TargetPath $releaseExtracted
  }

  return Join-Path -Path $releaseExtracted -ChildPath "ComfyUI_windows_portable"
}

function Install-ComfyUI {
  param([string]$SourcePath, [string]$DestinationPath)

  $pathEmbededPython = Join-Path -Path $DestinationPath -ChildPath "python_embeded"
  $pathSharedInclude = Join-Path -Path $pathSharedIncludesPath -ChildPath "include"
  $pathSharedLibs    = Join-Path -Path $pathSharedIncludesPath -ChildPath "libs"

  Copy-Item -Path $SourcePath        -Destination $DestinationPath   -Recurse -Force -Container -ErrorAction Stop
  Copy-Item -Path $pathSharedInclude -Destination $pathEmbededPython -Recurse -Force -Container -ErrorAction Stop
  Copy-Item -Path $pathSharedLibs    -Destination $pathEmbededPython -Recurse -Force -Container -ErrorAction Stop
}

function Install-CustomNode {
  param([string]$GitUrl, [string]$DestinationPath)

  git clone --quiet --depth 1 $GitUrl $DestinationPath
}

function Add-RunCommand {
  param([string]$DestinationFile, [string[]]$ComfyuiParameter)

  $comfyBaseCommand = ".\python_embeded\python.exe -s ComfyUI\main.py --windows-standalone-build"
  $command = $comfyBaseCommand + " " + ($ComfyuiParameter -join " ")

  Set-Content -Path $DestinationFile -Value $command
}

function Add-SymbolicLink {
  param([string]$Path, [string]$TargetPath)

  if (Test-Path -Path $Path) {
    Remove-Item -Path $Path -Recurse -Force
  }

  New-Item -ItemType Junction -Path $Path -Target $TargetPath -Force -ErrorAction Stop  | Out-Null
}

function Copy-TopDirectories {
  param([string]$SourcePath, [string]$DestinationPath)

  Get-ChildItem -Path $SourcePath -Directory | ForEach-Object {
    $destDir = Join-Path -Path $DestinationPath -ChildPath $_.Name
    
    if (-not (Test-Path -Path $destDir)) {
      New-Item -Path $destDir -ItemType Directory | Out-Null
    }
  }
}

function Remove-FilesInDirectory {
  param([string]$Directory, [string[]]$Filenames)

  foreach ($filename in $Filenames) {
    $filePath = Join-Path -Path $Directory -ChildPath $filename
    
    if (Test-Path -Path $filePath) {
      Remove-Item -Path $filePath -Force
    }
  }
}

Add-SharedDirectories

$release          = Get-LatestReleaseInfo
$releaseExtracted = Get-ReleaseFiles $release

if (Test-Path -Path $pathDestination) {
  Write-Host "$InstallName already exists at $pathDestination. Exiting."
  exit 1
}

Install-ComfyUI $releaseExtracted $pathDestination
Install-CustomNode "https://github.com/Comfy-Org/ComfyUI-Manager" $pathCustomNodeManager

Add-RunCommand -DestinationFile $pathRunCommand -ComfyuiParameter @("--output-directory", $pathSharedOutputs)

if (-not (Test-Path -Path $pathWorkflow)) {
  New-Item -Path $pathWorkflow -ItemType Directory | Out-Null
}

Add-SymbolicLink -Path $pathWorkflow -TargetPath $pathSharedWorkflows

Copy-TopDirectories -SourcePath $pathModels -DestinationPath $pathSharedModels

if (Test-Path -Path $pathModels) {
  Remove-Item -Path $pathModels -Recurse -Force
}

Add-SymbolicLink -Path $pathModels -TargetPath $pathSharedModels

Remove-FilesInDirectory -Directory $pathDestination -Filenames @("README_VERY_IMPORTANT.txt", "run_cpu.bat", "run_nvidia_gpu.bat", "run_nvidia_gpu_fast_fp16_accumulation.bat")

Write-Host "Installed successfully to: $pathDestination"