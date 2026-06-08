# UNCOMMENT THESE LINES TO BUILD FROM LATEST COMMIT
# git reset --hard origin/main
# git pull

param(
    [Parameter(Mandatory=$true)]
    [string]$CERTIFICATE_PASSWORD,

    [ValidateSet("x64", "arm64")]
    [string]$Architecture = "x64",

    [string]$OutputPath,

    [string[]]$FlutterCommand = @("fvm", "flutter"),

    [string[]]$DartCommand = @("fvm", "dart")
)

. $PSScriptRoot\windows_build_helpers.ps1

$artifactArchitecture = Get-WindowsArtifactArchitectureName -Architecture $Architecture
if (!$OutputPath) {
    $OutputPath = "LocalSend-XXX-windows-$artifactArchitecture.msix"
}

Push-Location (Join-Path -Path $PSScriptRoot -ChildPath "..\app")
try {
    Invoke-FlutterCommand -FlutterCommand $FlutterCommand -Arguments @("clean")
    Invoke-FlutterCommand -FlutterCommand $FlutterCommand -Arguments @("pub", "get")
    Ensure-WindowsMsixHelper -Architecture $Architecture
    Invoke-DartCommand -DartCommand $DartCommand -Arguments @("run", "msix:create", "--certificate-path", "../secrets/windows-tienisto.pfx", "--certificate-password", $CERTIFICATE_PASSWORD)

    $outputDir = Get-WindowsBuildOutputDir -Architecture $Architecture
    $msixPath = Join-Path -Path $outputDir -ChildPath "localsend_app.msix"
    if (!(Test-Path $msixPath)) {
        throw "Windows $Architecture MSIX was not found at '$msixPath'."
    }

    Move-Item -Path $msixPath -Destination $OutputPath -Force
} finally {
    Pop-Location
}

Write-Output "Generated Signed Windows $Architecture msix!"
