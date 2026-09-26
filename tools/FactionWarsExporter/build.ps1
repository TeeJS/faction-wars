# Builds the Faction Wars Exporter for players: ONE exe, FactionWarsExporter.exe,
# self-contained (no .NET install, no admin) and compressed, its data built in,
# optionally Authenticode-signed with Azure Trusted Signing. It lands in dist\.
#
#   .\tools\FactionWarsExporter\build.ps1            unsigned (for testing)
#   .\tools\FactionWarsExporter\build.ps1 -Sign      signed (for a release)
#
# Needs the Visual Studio Build Tools' C++ tools (for the movies' converter,
# native\build-xiph.ps1) and the .NET SDK.
#
# Signing needs, on this machine only (never committed):
#   <repo>\.signing\dlib-x64\Azure.CodeSigning.Dlib.dll and <repo>\.signing\metadata.json
#     (the same pair the other signed repos use - copy one repo's .signing folder)
#   the Windows 10/11 SDK's signtool.exe
#   a live Azure session in PowerShell 7: Connect-AzAccount -UseDeviceAuthentication
#
# Endpoint protection: the exe is signed after it is bundled, so its signature
# covers everything in it; .NET extracts nothing when it runs (a WinForms app
# has no native libraries to unpack; checked 2026-09-23 - nothing appears
# under %TEMP%\.net). The movies' converter, fwxiph.dll, is built first and
# SIGNED ON ITS OWN before it is built into the exe as a resource: Export
# movies writes it to %LOCALAPPDATA%\FactionWarsExporter\<hash>\ (never Temp)
# and loads it from there. The file name carries no version, so
# /releases/latest/download/FactionWarsExporter.exe stays a permanent link; the
# version is in the exe (its title bar) and the release tag.
param(
    [switch]$Sign,
    [string]$SigningDir = (Join-Path (Resolve-Path "$PSScriptRoot\..\..") ".signing")
)
$ErrorActionPreference = "Stop"

$project = Join-Path $PSScriptRoot "FactionWarsExporter.csproj"
$dist = Join-Path $PSScriptRoot "dist"
$exe = Join-Path $dist "FactionWarsExporter.exe"
$dll = Join-Path $PSScriptRoot "native\bin\fwxiph.dll"

if ($Sign) {
    $dlib = Join-Path $SigningDir "dlib-x64\Azure.CodeSigning.Dlib.dll"
    $metadata = Join-Path $SigningDir "metadata.json"
    if (-not (Test-Path $dlib) -or -not (Test-Path $metadata)) {
        throw "Signing requested but $SigningDir has no dlib-x64\Azure.CodeSigning.Dlib.dll + metadata.json - copy them from another repo's .signing folder"
    }
    $signtool = Get-ChildItem "C:\Program Files (x86)\Windows Kits\10\bin" -Recurse -Filter signtool.exe -ErrorAction SilentlyContinue |
        Where-Object { $_.Directory.Name -eq 'x64' } | Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
    if (-not $signtool) { throw "signtool.exe not found - install the Windows 10/11 SDK" }

    # The dlib reads the token from the Connect-AzAccount session through PowerShell 7,
    # and a personal Microsoft account must be pinned to the right tenant.
    $env:AZURE_TENANT_ID = "a4ae2122-9515-4f85-abc8-71c29ccc261f"
    if (Test-Path "$env:LOCALAPPDATA\pwsh7\pwsh.exe") { $env:PATH = "$env:LOCALAPPDATA\pwsh7;$env:PATH" }
}

function Sign-File([string]$path) {
    Write-Host "Signing $(Split-Path $path -Leaf)..."
    & $signtool sign /v /fd SHA256 /tr "http://timestamp.acs.microsoft.com" /td SHA256 /dlib $dlib /dmdf $metadata $path
    if ($LASTEXITCODE -ne 0) { throw "signing failed: $path" }
    & $signtool verify /pa $path
    if ($LASTEXITCODE -ne 0) { throw "signature verification failed: $path" }
}

Write-Host "Building the movies' converter (fwxiph.dll: libogg, libvorbis, libtheora)..."
& (Join-Path $PSScriptRoot "native\build-xiph.ps1")
if ($Sign) { Sign-File $dll }

if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
Write-Host "Publishing (one exe, self-contained, win-x64)..."
& dotnet publish $project -c Release -r win-x64 --self-contained true -o $dist -nologo -v q
if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed" }

# One file and nothing beside it, or the player gets a folder again.
$extra = Get-ChildItem $dist | Where-Object { $_.Name -ne "FactionWarsExporter.exe" }
if ($extra) { throw "publish left files beside the exe: $($extra.Name -join ', ')" }

if ($Sign) { Sign-File $exe }

$sig = Get-AuthenticodeSignature $exe
$dllSig = Get-AuthenticodeSignature $dll
$version = (Get-Item $exe).VersionInfo.ProductVersion
Write-Host ("`nBuilt {0}  ({1:N1} MB, version {2}, {3} {4})" -f $exe, ((Get-Item $exe).Length / 1MB), $version, $sig.Status, $sig.SignerCertificate.Subject)
Write-Host ("  with fwxiph.dll ({0:N0} bytes, {1})" -f (Get-Item $dll).Length, $dllSig.Status)
