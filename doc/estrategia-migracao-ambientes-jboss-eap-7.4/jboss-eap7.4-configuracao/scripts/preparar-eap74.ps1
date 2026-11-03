#requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Configuracao,[switch]$Aplicar,[switch]$LogSql,[string]$Perfil)
$ErrorActionPreference='Stop'
Import-Module "$PSScriptRoot/Eap74Preparation.psm1" -Force -DisableNameChecking
Invoke-EapPreparation -ConfigPath $Configuracao -Apply:$Aplicar -LogSql:$LogSql -Profile $Perfil
