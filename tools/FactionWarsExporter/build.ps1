# Builds the Faction Wars Exporter for players: a self-contained win-x64 folder
# (no .NET install, no admin), optionally Authenticode-signed with Azure Trusted
# Signing, zipped as FactionWarsExporter-win-x64.zip beside this script.
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
# Not single-file: a normal exe beside its DLLs, nothing self-extracting, so
# endpoint protection sees an ordinary signed program. The zip's name carries no
# version, so /releases/latest/download/FactionWarsExporter-win-x64.zip stays a
# permanent link; the version is in the exe and the release tag.
param(
    [switch]$Sign,
    [string]$SigningDir = (Join-Path (Resolve-Path "$PSScriptRoot\..\..") ".signing")
)
$ErrorActionPreference = "Stop"

$project = Join-Path $PSScriptRoot "FactionWarsExporter.csproj"
$dist = Join-Path $PSScriptRoot "dist\FactionWarsExporter"
$zip = Join-Path $PSScriptRoot "FactionWarsExporter-win-x64.zip"

if (Test-Path $dist) { Remove-Item $dist -Recurse -Force }
Write-Host "Publishing (self-contained, win-x64)..."
& dotnet publish $project -c Release -r win-x64 --self-contained true -p:PublishSingleFile=false -o $dist -nologo -v q
if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed" }

# Our two files; the runtime's own DLLs already carry Microsoft's signature.
$ours = @("FactionWarsExporter.exe", "FactionWarsExporter.dll") | ForEach-Object { Join-Path $dist $_ }

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

    foreach ($file in $ours) {
        Write-Host "Signing $(Split-Path $file -Leaf)..."
        & $signtool sign /v /fd SHA256 /tr "http://timestamp.acs.microsoft.com" /td SHA256 /dlib $dlib /dmdf $metadata $file
        if ($LASTEXITCODE -ne 0) { throw "signing failed: $file" }
        & $signtool verify /pa $file
        if ($LASTEXITCODE -ne 0) { throw "signature verification failed: $file" }
    }
}

foreach ($file in $ours) {
    $sig = Get-AuthenticodeSignature $file
    Write-Host ("{0}: {1} {2}" -f (Split-Path $file -Leaf), $sig.Status, $sig.SignerCertificate.Subject)
}

if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $dist -DestinationPath $zip
$version = (Get-Item (Join-Path $dist "FactionWarsExporter.exe")).VersionInfo.ProductVersion
Write-Host ("`nBuilt {0}  ({1:N1} MB, version {2}, {3})" -f $zip, ((Get-Item $zip).Length / 1MB), $version, $(if ($Sign) { "signed" } else { "UNSIGNED" }))
