param(
    [ValidateSet("x64", "arm64")]
    [string]$Architecture = "x64",

    [string[]]$FlutterCommand = @("fvm", "flutter")
)

. $PSScriptRoot\windows_build_helpers.ps1

Push-Location (Join-Path -Path $PSScriptRoot -ChildPath "..\app")
try {
    Invoke-FlutterCommand -FlutterCommand $FlutterCommand -Arguments @("clean")
    Invoke-FlutterCommand -FlutterCommand $FlutterCommand -Arguments @("pub", "get")
    Ensure-WindowsMsixHelper -Architecture $Architecture
    Invoke-FlutterCommand -FlutterCommand $FlutterCommand -Arguments @("build", "windows")

    $outputDir = Get-WindowsBuildOutputDir -Architecture $Architecture
    Assert-WindowsBuildOutputDir -Architecture $Architecture -Path $outputDir

    Remove-Item "D:\inno" -Force -Recurse -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path "D:\inno"
    Copy-Item -Path (Join-Path -Path $outputDir -ChildPath "*") -Destination "D:\inno" -Recurse
    Copy-Item -Path "assets\packaging\logo.ico" -Destination "D:\inno"
} finally {
    Pop-Location
}

Copy-WindowsRuntimeDlls -Architecture $Architecture -Destination "D:\inno"
Remove-Item "D:\inno-result" -Force -Recurse -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path "D:\inno-result"
iscc "/DAppArchitecture=$Architecture" .\scripts\compile_windows_exe-inno.iss

Write-Output "Generated Windows $Architecture exe installer!"
