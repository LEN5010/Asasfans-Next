param(
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path $PSScriptRoot -Parent
$versionLine = Select-String -Path "$projectRoot/pubspec.yaml" -Pattern '^version:\s*(\S+)'
$version = $versionLine.Matches[0].Groups[1].Value.Split('+')[0]
$source = (Resolve-Path "$projectRoot/build/windows/x64/runner/$Configuration").Path
$output = New-Item -ItemType Directory -Force "$projectRoot/dist"
$compiler = "${env:ProgramFiles(x86)}/Inno Setup 6/ISCC.exe"

& $compiler "/DAppVersion=$version" "/DSourceDir=$source" "/O$($output.FullName)" "$projectRoot/windows/packaging/installer.iss"
if ($LASTEXITCODE -ne 0) { throw "Windows installer compilation failed ($LASTEXITCODE)" }
