function Get-WindowsArtifactArchitectureName {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("x64", "arm64")]
        [string]$Architecture
    )

    switch ($Architecture) {
        "x64" { return "x86-64" }
        "arm64" { return "arm64" }
    }
}

function Get-WindowsBuildOutputDir {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("x64", "arm64")]
        [string]$Architecture
    )

    return Join-Path -Path "build/windows/$Architecture/runner" -ChildPath "Release"
}

function Assert-WindowsBuildOutputDir {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("x64", "arm64")]
        [string]$Architecture,

        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    if (!(Test-Path $Path)) {
        throw "Windows $Architecture build output was not found at '$Path'. For arm64 builds, make sure the arm64 Flutter SDK is installed and selected."
    }
}

function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$Command,

        [Parameter(Mandatory=$true)]
        [string[]]$Arguments
    )

    if ($Command.Length -eq 0) {
        throw "Command cannot be empty."
    }

    $executable = $Command[0]
    $prefixArgs = @()
    if ($Command.Length -gt 1) {
        $prefixArgs = $Command[1..($Command.Length - 1)]
    }

    & $executable @prefixArgs @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed: $($Command -join ' ') $($Arguments -join ' ')"
    }
}

function Invoke-FlutterCommand {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$FlutterCommand,

        [Parameter(Mandatory=$true)]
        [string[]]$Arguments
    )

    Invoke-ExternalCommand -Command $FlutterCommand -Arguments $Arguments
}

function Invoke-DartCommand {
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$DartCommand,

        [Parameter(Mandatory=$true)]
        [string[]]$Arguments
    )

    Invoke-ExternalCommand -Command $DartCommand -Arguments $Arguments
}

function Find-WindowsRuntimeDllDir {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("x64", "arm64")]
        [string]$Architecture
    )

    $localRuntimeDir = Join-Path -Path $PSScriptRoot -ChildPath "windows/$Architecture"
    if (Test-Path $localRuntimeDir) {
        return $localRuntimeDir
    }

    $programFilesRoots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ }
    foreach ($root in $programFilesRoots) {
        $redistPattern = Join-Path -Path $root -ChildPath "Microsoft Visual Studio/2022/*/VC/Redist/MSVC/*/$Architecture/Microsoft.VC*.CRT"
        $redistDir = Get-ChildItem -Path $redistPattern -Directory -ErrorAction SilentlyContinue |
            Sort-Object -Property FullName -Descending |
            Select-Object -First 1
        if ($redistDir) {
            return $redistDir.FullName
        }
    }

    throw "Could not find Microsoft Visual C++ runtime DLLs for Windows $Architecture."
}

function Copy-WindowsRuntimeDlls {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("x64", "arm64")]
        [string]$Architecture,

        [Parameter(Mandatory=$true)]
        [string]$Destination
    )

    $runtimeDir = Find-WindowsRuntimeDllDir -Architecture $Architecture
    $runtimeDlls = @("msvcp140.dll", "vcruntime140.dll", "vcruntime140_1.dll")

    foreach ($dll in $runtimeDlls) {
        $source = Join-Path -Path $runtimeDir -ChildPath $dll
        if (!(Test-Path $source)) {
            throw "Missing required runtime DLL '$dll' in '$runtimeDir'."
        }
        Copy-Item -Path $source -Destination $Destination -Force
    }
}

function Find-MakeAppxPath {
    $command = Get-Command MakeAppx.exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $sdkRoot = ${env:ProgramFiles(x86)}
    if (!$sdkRoot) {
        throw "Could not locate Windows SDK to find MakeAppx.exe."
    }

    $toolArchitectures = @("x64")
    if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") {
        $toolArchitectures = @("arm64", "x64")
    }

    foreach ($toolArchitecture in $toolArchitectures) {
        $makeAppxPattern = Join-Path -Path $sdkRoot -ChildPath "Windows Kits/10/bin/*/$toolArchitecture/makeappx.exe"
        $makeAppx = Get-ChildItem -Path $makeAppxPattern -File -ErrorAction SilentlyContinue |
            Sort-Object -Property FullName -Descending |
            Select-Object -First 1
        if ($makeAppx) {
            return $makeAppx.FullName
        }
    }

    throw "Could not find MakeAppx.exe. Install the Windows SDK or run from a Visual Studio Developer PowerShell."
}

function New-WindowsMsixHelper {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("x64", "arm64")]
        [string]$Architecture,

        [string]$OutputPath = (Join-Path -Path $PSScriptRoot -ChildPath "../app/windows/localsend_msix_helper.msix")
    )

    $sourceDir = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath "../msix")
    $tempDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "localsend-msix-helper-$Architecture-$([System.Guid]::NewGuid())"

    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
    try {
        Copy-Item -Path (Join-Path -Path $sourceDir -ChildPath "*") -Destination $tempDir -Recurse

        $manifestPath = Join-Path -Path $tempDir -ChildPath "AppxManifest.xml"
        $manifest = Get-Content -Path $manifestPath -Raw
        $manifest = $manifest -replace 'ProcessorArchitecture="[^"]+"', "ProcessorArchitecture=`"$Architecture`""
        Set-Content -Path $manifestPath -Value $manifest -NoNewline

        $makeAppx = Find-MakeAppxPath
        & $makeAppx pack /o /d $tempDir /nv /p $OutputPath
        if ($LASTEXITCODE -ne 0) {
            throw "MakeAppx.exe failed to create Windows $Architecture MSIX helper."
        }
        Set-Content -Path "$OutputPath.arch" -Value $Architecture -NoNewline
    } finally {
        Remove-Item -Path $tempDir -Force -Recurse -ErrorAction SilentlyContinue
    }
}

function Ensure-WindowsMsixHelper {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("x64", "arm64")]
        [string]$Architecture,

        [string]$OutputPath = (Join-Path -Path $PSScriptRoot -ChildPath "../app/windows/localsend_msix_helper.msix")
    )

    if (Test-Path $OutputPath) {
        $stampPath = "$OutputPath.arch"
        if (Test-Path $stampPath) {
            $existingArchitecture = (Get-Content -Path $stampPath -Raw).Trim()
            if ($existingArchitecture -eq $Architecture) {
                return
            }
        } elseif ($Architecture -eq "x64") {
            return
        }
    }

    New-WindowsMsixHelper -Architecture $Architecture -OutputPath $OutputPath
}
