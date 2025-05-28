# comfyui-scripts

## Installation

* Create a directory where you want to store the files.
* ```CD``` to that directory.
* git clone https://github.com/patricksheedy/comfyui-scripts scripts
  * If you don't already have git then run ```winget install Microsoft.Git``` first.
* While running the scripts, if you get an error message about Powershell Execution Policies then run the following command.
  * ```Set-ExecutionPolicy Unrestricted```

## install.ps1

#### This script will
* Download the latest release of ComfyUI from Github.
* Extract and copy it to the ```apps``` directory.
* Install ComfyUI Manager.
* Create directories that are shared between all ComfyUI installations.
  * Models
  * Workflows
  * Input
  * Output

#### Usage

* Open a Powershell window in the ```scripts``` directory
* ```.\install.ps1 [InstallName]```
  * InstallName is the directory created in the ```apps``` directory so you can have multiple versions of ComfyUI. You can name this whatever you want.
* ComfyUI is now installed, ```cd ..\apps``` and you will see a new directory with the ComfyUI installation.
