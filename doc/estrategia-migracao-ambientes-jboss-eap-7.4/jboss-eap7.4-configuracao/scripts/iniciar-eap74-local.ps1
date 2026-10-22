#requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Configuracao,[switch]$AdminOnly)
$ErrorActionPreference='Stop'
Import-Module "$PSScriptRoot/Eap74Preparation.psm1" -Force -DisableNameChecking
Start-EapPrepared -ConfigPath $Configuracao -AdminOnly:$AdminOnly
