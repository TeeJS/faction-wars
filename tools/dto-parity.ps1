# dto-parity.ps1 - the pack hydration regression (was HANDOFF step 1A's C# gate).
#
# Loads the active pack the way the game does, dumps it in canonical form and
# compares it with tests/fixtures/dto-pack.json. A field that hydrates
# differently after a DTO change shows up here.
#
#   .\tools\dto-parity.ps1              compare with the committed fixture
#   .\tools\dto-parity.ps1 -Rebaseline  rewrite the fixture (say so in the commit)
#
# Headless only; never opens a window. The data/*.json folder and the C# dump it
# was compared against are gone (2026-09-22): the pack is the only data.

param(
    [switch]$Rebaseline,
    [string]$Godot = 'D:\Downloads\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe',
    [string]$OutDir = "$env:TEMP\scr-parity"
)

$ErrorActionPreference = 'Stop'
$port = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path $Godot)) { throw "Godot console binary not found: $Godot" }
New-Item -ItemType Directory -Force $OutDir | Out-Null

function Invoke-Godot([string[]]$GodotArgs, [string]$Log, [int]$Seconds = 120) {
    $p = Start-Process -FilePath $Godot -ArgumentList $GodotArgs -RedirectStandardOutput $Log -RedirectStandardError ($Log + '.err') -PassThru -NoNewWindow
    if (-not $p.WaitForExit($Seconds * 1000)) { $p.Kill(); Write-Host "  timed out after ${Seconds}s: $($GodotArgs -join ' ')"; return 124 }
    Get-Content ($Log + '.err') -ErrorAction SilentlyContinue | Add-Content $Log
    return $p.ExitCode
}

if (-not (Test-Path (Join-Path $port '.godot/global_script_class_cache.cfg'))) {
    Write-Host "dto-parity: first run - importing the GDScript project"
    Invoke-Godot @('--headless', '--path', $port, '--import') (Join-Path $OutDir 'gd-import.txt') 300 | Out-Null
}

$args_ = @('--headless', '--path', $port, '-s', 'tests/dto_parity.gd', '--')
if ($Rebaseline) { $args_ += '--rebaseline' }
$log = Join-Path $OutDir 'gd-stdout.txt'
$code = Invoke-Godot $args_ $log
Get-Content $log | Select-String '\[dto_parity\]|SCRIPT ERROR|  fixture|  loaded|  full dump'
if ($code -ne 0 -and -not $Rebaseline) {
    Write-Host "dto-parity: field-level diff:"
    python (Join-Path $PSScriptRoot 'compare_json.py') (Join-Path $port 'tests\fixtures\dto-pack.json') (Join-Path $env:APPDATA 'Godot\app_userdata\faction-wars\dto-pack-actual.json')
}
exit $code
