# UNCOMMENT THESE LINES TO BUILD FROM LATEST COMMIT
# git reset --hard origin/main
# git pull

param(
    [ValidateSet("x64", "arm64")]
    [string]$Architecture = "x64",

    [string]$OutputPath,

    [string[]]$FlutterCommand = @("fvm", "flutter"),

    [string[]]$DartCommand = @("fvm", "dart")
)

. $PSScriptRoot\windows_build_helpers.ps1

$artifactArchitecture = Get-WindowsArtifactArchitectureName -Architecture $Architecture
if (!$OutputPath) {
    $OutputPath = "LocalSend-XXX-windows-$artifactArchitecture-store.msix"
}

Push-Location (Join-Path -Path $PSScriptRoot -ChildPath "..\app")
try {
    Invoke-FlutterCommand -FlutterCommand $FlutterCommand -Arguments @("clean")
    Invoke-FlutterCommand -FlutterCommand $FlutterCommand -Arguments @("pub", "get")
    Invoke-DartCommand -DartCommand $DartCommand -Arguments @("run", "build_runner", "build", "-d")
    Ensure-WindowsMsixHelper -Architecture $Architecture
    Invoke-FlutterCommand -FlutterCommand $FlutterCommand -Arguments @("pub", "run", "msix:create", "--store")

    $outputDir = Get-WindowsBuildOutputDir -Architecture $Architecture
    $msixPath = Join-Path -Path $outputDir -ChildPath "localsend_app.msix"
    if (!(Test-Path $msixPath)) {
        throw "Windows $Architecture MSIX was not found at '$msixPath'."
    }

    Move-Item -Path $msixPath -Destination $OutputPath -Force
} finally {
    Pop-Location
}

Write-Output "Generated Windows $Architecture msix!"
