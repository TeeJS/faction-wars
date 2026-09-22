# run-gd.ps1 - run one headless GDScript test in this project with a hard timeout.
#
#   .\tools\run-gd.ps1 tests/prng_check.gd
#   .\tools\run-gd.ps1 tests/bench_1b.gd -- --days=100 --missions
#
# Imports the project first when the class cache is missing (class_name lookup
# needs it). Never opens a window. Prints the script's output and exits with
# its exit code; a hang is killed after -Seconds and reported as exit 124.
# Raw output lands in $env:TEMP\gd-<repo folder>-<pid>-<script>.txt (+ .err).

param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Script,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest,
    [string]$Godot = 'D:\Downloads\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe',
    [int]$Seconds = 300
)

$ErrorActionPreference = 'Stop'
$port = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path $Godot)) { throw "Godot console binary not found: $Godot" }
# One log per repo folder AND process: two runs of the same script - two
# agents' worktrees, or a soak beside the gate - used to clobber one file.
$tag = (Split-Path -Leaf $port) + '-' + $PID
$out = Join-Path $env:TEMP ('gd-' + $tag + '-' + [IO.Path]::GetFileNameWithoutExtension($Script) + '.txt')

function Invoke-Godot([string[]]$GodotArgs, [string]$Log, [int]$Timeout) {
    Remove-Item $Log, ($Log + '.err') -ErrorAction SilentlyContinue
    $p = Start-Process -FilePath $Godot -ArgumentList $GodotArgs -RedirectStandardOutput $Log -RedirectStandardError ($Log + '.err') -PassThru -NoNewWindow
    if (-not $p.WaitForExit($Timeout * 1000)) { $p.Kill(); Write-Host "TIMEOUT after ${Timeout}s"; return 124 }
    return $p.ExitCode
}

# The global class cache is rebuilt only by an import, so a class_name added since
# the last import is unknown until the next one. Import whenever a script is newer
# than the cache.
$cache = Join-Path $port '.godot/global_script_class_cache.cfg'
$stale = -not (Test-Path $cache)
if (-not $stale) {
    $cacheTime = (Get-Item $cache).LastWriteTimeUtc
    $newest = Get-ChildItem -Path (Join-Path $port 'src'), (Join-Path $port 'tests') -Recurse -Filter *.gd | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    if ($newest -and $newest.LastWriteTimeUtc -gt $cacheTime) { $stale = $true }
}
if ($stale) {
    Write-Host "run-gd: importing the project (class cache stale)"
    Invoke-Godot @('--headless', '--path', $port, '--import') (Join-Path $env:TEMP ('gd-' + $tag + '-import.txt')) 300 | Out-Null
}

$args = @('--headless', '--path', $port, '-s', $Script)
# PowerShell swallows a bare "--", so the user-arg separator Godot needs is added here.
if ($Rest) { $args += '--'; $args += $Rest }
$code = Invoke-Godot $args $out $Seconds
Get-Content $out -ErrorAction SilentlyContinue | Where-Object { $_ -notmatch '^Godot Engine v' }
$err = Get-Content ($out + '.err') -ErrorAction SilentlyContinue
if ($err) { Write-Host '--- stderr ---'; $err | Select-Object -First 60 }
exit $code
