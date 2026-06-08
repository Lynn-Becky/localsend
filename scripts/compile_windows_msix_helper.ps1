# Using Visual Studio 2022 Developer PowerShell
# or using e.g. "C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\makeappx.exe"

param(
    [ValidateSet("x64", "arm64")]
    [string]$Architecture = "x64",

    [string]$OutputPath = (Join-Path -Path $PSScriptRoot -ChildPath "..\app\windows\localsend_msix_helper.msix")
)

. $PSScriptRoot\windows_build_helpers.ps1

New-WindowsMsixHelper -Architecture $Architecture -OutputPath $OutputPath
