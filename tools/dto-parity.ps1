# dto-parity.ps1 - HANDOFF step 1A gate.
#
# Dumps every data file as the C# source deserialises it, hydrates the same files
# with the GDScript port, and compares the two canonical dumps field by field.
#
# Usage (non-admin PowerShell, from faction-wars, after `dotnet build` in the
# source repo):
#   .\tools\dto-parity.ps1
#
# Headless only; never opens a window.

param(
    [string]$Source = 'D:\Github\sol-conflict-revolution',
    [string]$Godot = 'D:\Downloads\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe',
    [string]$OutDir = "$env:TEMP\scr-parity"
)

$ErrorActionPreference = 'Stop'
$port = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path $Godot)) { throw "Godot console binary not found: $Godot" }
New-Item -ItemType Directory -Force $OutDir | Out-Null
# Runs Godot headless with a hard timeout: a script that fails to compile leaves
# an empty SceneTree running forever, and the gate must fail, not hang.
function Invoke-Godot([string[]]$GodotArgs, [string]$Log, [int]$Seconds = 120) {
    $p = Start-Process -FilePath $Godot -ArgumentList $GodotArgs -RedirectStandardOutput $Log -RedirectStandardError ($Log + '.err') -PassThru -NoNewWindow
    if (-not $p.WaitForExit($Seconds * 1000)) { $p.Kill(); Write-Host "  timed out after ${Seconds}s: $($GodotArgs -join ' ')" }
    Get-Content ($Log + '.err') -ErrorAction SilentlyContinue | Add-Content $Log
}

$cs = Join-Path $OutDir 'cs-dto.json'
$gd = Join-Path $OutDir 'gd-dto.json'
Remove-Item $cs, $gd -ErrorAction SilentlyContinue

Write-Host "dto-parity: C# dump from $Source"
Invoke-Godot @('--headless', '--path', $Source, 'res://Main.tscn', '--', "--dto-dump=$cs") (Join-Path $OutDir 'cs-stdout.txt')
if (-not (Test-Path $cs)) { Get-Content (Join-Path $OutDir 'cs-stdout.txt') -Tail 30; throw "C# dump not produced" }

# A fresh checkout has no .godot/ cache, and class_name lookups need the global
# script class cache the import step builds. Idempotent, a few seconds.
if (-not (Test-Path (Join-Path $port '.godot/global_script_class_cache.cfg'))) {
    Write-Host "dto-parity: first run - importing the GDScript project"
    Invoke-Godot @('--headless', '--path', $port, '--import') (Join-Path $OutDir 'gd-import.txt') 300
}

Write-Host "dto-parity: GDScript dump from $port"
Invoke-Godot @('--headless', '--path', $port, '-s', 'tests/dto_parity.gd', '--', "--out=$gd") (Join-Path $OutDir 'gd-stdout.txt')
if (-not (Test-Path $gd)) { Get-Content (Join-Path $OutDir 'gd-stdout.txt') -Tail 40; throw "GDScript dump not produced" }

python (Join-Path $PSScriptRoot 'compare_json.py') $cs $gd
exit $LASTEXITCODE
