# UNCOMMENT THESE LINES TO BUILD FROM LATEST COMMIT
# git reset --hard origin/main
# git pull

param(
    [ValidateSet("x64", "arm64")]
    [string]$Architecture = "x64",

    [string]$OutputPath,

    [string[]]$FlutterCommand = @("fvm", "flutter")
)

. $PSScriptRoot\windows_build_helpers.ps1

$artifactArchitecture = Get-WindowsArtifactArchitectureName -Architecture $Architecture
if (!$OutputPath) {
    $OutputPath = "LocalSend-XXX-windows-$artifactArchitecture.zip"
}

Push-Location (Join-Path -Path $PSScriptRoot -ChildPath "..\app")
try {
    Invoke-FlutterCommand -FlutterCommand $FlutterCommand -Arguments @("clean")
    Invoke-FlutterCommand -FlutterCommand $FlutterCommand -Arguments @("pub", "get")
    Ensure-WindowsMsixHelper -Architecture $Architecture
    Invoke-FlutterCommand -FlutterCommand $FlutterCommand -Arguments @("build", "windows")

    $outputDir = Get-WindowsBuildOutputDir -Architecture $Architecture
    Assert-WindowsBuildOutputDir -Architecture $Architecture -Path $outputDir

    Set-Content -Path (Join-Path -Path $outputDir -ChildPath "settings.json") -Value "{}" -NoNewline
    Copy-WindowsRuntimeDlls -Architecture $Architecture -Destination $outputDir

    if (Test-Path $OutputPath) {
        Remove-Item -Path $OutputPath -Force
    }
    Compress-Archive -Path (Join-Path -Path $outputDir -ChildPath "*") -DestinationPath $OutputPath
} finally {
    Pop-Location
}

Write-Output "Generated Windows $Architecture zip!"
