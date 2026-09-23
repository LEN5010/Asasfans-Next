$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$pin = Get-Content -Raw (Join-Path $PSScriptRoot 'flutter-sdk.json') | ConvertFrom-Json
$sdk = $env:ASASFANS_FLUTTER_SDK
if ([string]::IsNullOrWhiteSpace($sdk)) {
    $flutter = Get-Command flutter.bat -CommandType Application -ErrorAction SilentlyContinue
    if ($null -eq $flutter) {
        [Console]::Error.WriteLine("Flutter $($pin.version) is not on PATH. Set ASASFANS_FLUTTER_SDK; see tool/README.md.")
        exit 78
    }
    $sdk = Split-Path -Parent (Split-Path -Parent $flutter.Source)
}
$dart = Join-Path $sdk 'bin/cache/dart-sdk/bin/dart.exe'
if (-not (Test-Path -LiteralPath $dart -PathType Leaf)) {
    [Console]::Error.WriteLine("Flutter $($pin.version) is missing at $sdk. See tool/README.md; no other SDK will be substituted.")
    exit 78
}
& $dart (Join-Path $PSScriptRoot 'flutter_sdk.dart') $root $sdk @args
exit $LASTEXITCODE
