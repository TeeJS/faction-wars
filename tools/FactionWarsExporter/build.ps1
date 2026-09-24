# Builds the Faction Wars Exporter for players: ONE exe, FactionWarsExporter.exe,
# self-contained (no .NET install, no admin) and compressed, its data built in,
# optionally Authenticode-signed with Azure Trusted Signing. It lands in dist\.
#
#   .\tools\FactionWarsExporter\build.ps1            unsigned (for testing)
#   .\tools\FactionWarsExporter\build.ps1 -Sign      signed (for a release)
#
# Signing needs, on this machine only (never committed):
#   <repo>\.signing\dlib-x64\Azure.CodeSigning.Dlib.dll and <repo>\.signing\metadata.json
#     (the same pair the other signed repos use - copy one repo's .signing folder)
#   the Windows 10/11 SDK's signtool.exe
#   a live Azure session in PowerShell 7: Connect-AzAccount -UseDeviceAuthentication
#
# Endpoint protection: the exe is signed after it is bundled, so its signature
# covers everything in it, and it extracts nothing to disk when it runs (a
# WinForms app has no native libraries to unpack; checked 2026-09-23 - nothing
# appears under %TEMP%\.net). The file name carries no version, so
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

if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
Write-Host "Publishing (one exe, self-contained, win-x64)..."
& dotnet publish $project -c Release -r win-x64 --self-contained true -o $dist -nologo -v q
if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed" }

# One file and nothing beside it, or the player gets a folder again.
$extra = Get-ChildItem $dist | Where-Object { $_.Name -ne "FactionWarsExporter.exe" }
if ($extra) { throw "publish left files beside the exe: $($extra.Name -join ', ')" }

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

    Write-Host "Signing FactionWarsExporter.exe..."
    & $signtool sign /v /fd SHA256 /tr "http://timestamp.acs.microsoft.com" /td SHA256 /dlib $dlib /dmdf $metadata $exe
    if ($LASTEXITCODE -ne 0) { throw "signing failed: $exe" }
    & $signtool verify /pa $exe
    if ($LASTEXITCODE -ne 0) { throw "signature verification failed: $exe" }
}

$sig = Get-AuthenticodeSignature $exe
$version = (Get-Item $exe).VersionInfo.ProductVersion
Write-Host ("`nBuilt {0}  ({1:N1} MB, version {2}, {3} {4})" -f $exe, ((Get-Item $exe).Length / 1MB), $version, $sig.Status, $sig.SignerCertificate.Subject)
