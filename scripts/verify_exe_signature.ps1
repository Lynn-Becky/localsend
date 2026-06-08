param(
    [ValidateSet("x64", "arm64")]
    [string]$Architecture = "x64"
)

$signtoolPath = "C:\Program Files (x86)\Windows Kits\10\bin\10.0.19041.0\x64\signtool.exe"
& $signtoolPath verify "build\windows\$Architecture\runner\Release\localsend_app.exe"
