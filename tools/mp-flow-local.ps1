# The M4 gate: two headless clients drive the real head-to-head screens through
# a local relay into a lockstep game, play N days at Fast, and their day hashes
# are diffed. -Load then runs a second pair that picks the saved game from the
# Load Game list (M5) and resumes it. Usage:
#   .\tools\mp-flow-local.ps1 [-Days 30] [-Load] [-RelayPort 8790]
param(
    [int]$Days = 30,
    [switch]$Load,
    [string]$SpeedRule = '',   # 'average' runs the pair under TeeJ's average rule
    [int]$RelayPort = 8790,
    [string]$Godot = 'D:\Downloads\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
)
$repo = Split-Path -Parent $PSScriptRoot
$box = Join-Path $env:TEMP ("mpflow-" + [guid]::NewGuid().ToString().Substring(0, 8))
New-Item -ItemType Directory -Force $box | Out-Null
$env:PORT = "$RelayPort"; $env:DATA_DIR = "$box\relay-data"
$relay = Start-Process -FilePath 'bun' -ArgumentList @('run', (Join-Path $repo 'relay\server.ts')) -RedirectStandardOutput "$box\relay.stdout.txt" -RedirectStandardError "$box\relay.stderr.txt" -PassThru -NoNewWindow
Start-Sleep -Seconds 2

function Run-Pair([string]$tag, [string[]]$extra) {
    $procs = @()
    foreach ($role in @('host', 'guest')) {
        $args = @('--headless', '--path', $repo, '-s', 'tests/mp_flow.gd', '--',
            "--role=$role", "--relay=ws://127.0.0.1:$RelayPort/ws", "--box=$box", "--days=$Days", "--replay-log=$box\$role$tag.hashes.log") + $extra
        $procs += Start-Process -FilePath $Godot -ArgumentList $args -RedirectStandardOutput "$box\$role$tag.stdout.txt" -RedirectStandardError "$box\$role$tag.stderr.txt" -PassThru -NoNewWindow
    }
    foreach ($p in $procs) { if (-not $p.WaitForExit(900000)) { $p.Kill(); Write-Host "TIMEOUT" } }
    foreach ($role in @('host', 'guest')) {
        $idx = if ($role -eq 'host') { 0 } else { 1 }
        Write-Host ("{0}{1}: exit {2}" -f $role, $tag, $procs[$idx].ExitCode)
        Select-String -Path "$box\$role$tag.stdout.txt" -Pattern '\[mp_flow\]|\[GameManager\] head|\[Lockstep\]' | ForEach-Object { Write-Host "  $($_.Line)" }
        $errs = (Select-String -Path "$box\$role$tag.stdout.txt", "$box\$role$tag.stderr.txt" -Pattern 'SCRIPT ERROR' | Measure-Object).Count
        Write-Host "  script errors: $errs"
    }
    $a = @{}; Get-Content "$box\host$tag.hashes.log" | Select-Object -Skip 1 | ForEach-Object { $d, $h = $_ -split ',', 2; $a[[int]$d] = $h }
    $b = @{}; Get-Content "$box\guest$tag.hashes.log" | Select-Object -Skip 1 | ForEach-Object { $d, $h = $_ -split ',', 2; $b[[int]$d] = $h }
    $shared = $a.Keys | Where-Object { $b.ContainsKey($_) } | Sort-Object
    $n = $shared.Count; $same = 0; $first = -1
    foreach ($d in $shared) { if ($a[$d] -eq $b[$d]) { $same++ } elseif ($first -lt 0) { $first = $d } }
    return ("{0} of {1} day hashes identical{2}" -f $same, $n, $(if ($first -ge 0) { " - first difference on day $first" } else { "" }))
}

$g1 = Run-Pair "" $(if ($SpeedRule -ne '') { @("--speed-rule=$SpeedRule") } else { @() })
Write-Host ("M4 (screens -> lockstep) GATE: {0}  (box: {1})" -f $g1, $box)
if ($Load) {
    Remove-Item "$box\room.code" -Force
    $g2 = Run-Pair ".load" @('--load')
    Write-Host ("M5 (Load Game from the Options screen) GATE: {0}" -f $g2)
}
try { $relay.Kill() } catch {}
