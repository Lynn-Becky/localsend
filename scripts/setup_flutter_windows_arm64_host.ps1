param(
    [string]$FlutterRoot = $env:FLUTTER_ROOT
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

if (!$FlutterRoot) {
    $flutterCommand = Get-Command flutter -ErrorAction Stop
    $FlutterRoot = Split-Path -Parent (Split-Path -Parent $flutterCommand.Source)
}

$flutterBat = Join-Path -Path $FlutterRoot -ChildPath "bin\flutter.bat"
if (!(Test-Path $flutterBat)) {
    throw "Could not find Flutter at '$FlutterRoot'."
}

$null = & $flutterBat --version --machine

$cachePath = Join-Path -Path $FlutterRoot -ChildPath "bin\cache"
$engineStampPath = Join-Path -Path $cachePath -ChildPath "engine.stamp"
$engineDartSdkStampPath = Join-Path -Path $cachePath -ChildPath "engine-dart-sdk.stamp"
$engineRealmPath = Join-Path -Path $cachePath -ChildPath "engine.realm"

if (!(Test-Path $engineStampPath)) {
    throw "Could not determine Flutter engine version from '$engineStampPath'."
}

$engineVersion = (Get-Content -Path $engineStampPath -Raw).Trim()
$storageBaseUrl = $env:FLUTTER_STORAGE_BASE_URL
if (!$storageBaseUrl) {
    $storageBaseUrl = "https://storage.googleapis.com"
}
if ((Test-Path $engineRealmPath)) {
    $engineRealm = (Get-Content -Path $engineRealmPath -Raw).Trim()
    if ($engineRealm) {
        $storageBaseUrl = "$storageBaseUrl/$engineRealm"
    }
}

$archiveName = "dart-sdk-windows-arm64.zip"
$dartArchiveUrl = "$storageBaseUrl/flutter_infra_release/flutter/$engineVersion/$archiveName"
$downloadDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "localsend-flutter-dart-sdk-$engineVersion-arm64"
$zipPath = Join-Path -Path $downloadDir -ChildPath $archiveName
$extractDir = Join-Path -Path $downloadDir -ChildPath "extract"
$dartSdkPath = Join-Path -Path $cachePath -ChildPath "dart-sdk"

Remove-Item -Path $downloadDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null

Invoke-WebRequest -Uri $dartArchiveUrl -OutFile $zipPath
Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

Remove-Item -Path $dartSdkPath -Recurse -Force
Move-Item -Path (Join-Path -Path $extractDir -ChildPath "dart-sdk") -Destination $dartSdkPath
Set-Content -Path $engineDartSdkStampPath -Value $engineVersion -Encoding ASCII

Remove-Item -Path (Join-Path -Path $FlutterRoot -ChildPath "bin\cache\flutter_tools.snapshot") -Force -ErrorAction SilentlyContinue
Remove-Item -Path (Join-Path -Path $FlutterRoot -ChildPath "bin\cache\flutter_tools.stamp") -Force -ErrorAction SilentlyContinue

& (Join-Path -Path $dartSdkPath -ChildPath "bin\dart.exe") --version
& $flutterBat --version
