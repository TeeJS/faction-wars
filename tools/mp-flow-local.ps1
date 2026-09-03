# The M4 gate: two headless clients drive the real head-to-head screens through
# a local relay into a lockstep game, play N days at Fast, and their day hashes
# are diffed. -Load then runs a second pair that picks the saved game from the
# Load Game list (M5) and resumes it. Usage:
#   .\tools\mp-flow-local.ps1 [-Days 30] [-Load] [-RelayPort 8790]
param(
    [int]$Days = 30,
    [switch]$Load,
    [string]$SpeedRule = '',   # 'average' runs the pair under TeeJ's average rule
    [int]$RejoinCode = 0,      # the guest drops on this day and comes back by code through the screens
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

if ($RejoinCode -gt 0) {
    # The host plays through; the guest drops on day D and comes back by code.
    $hostArgs = @('--headless', '--path', $repo, '-s', 'tests/mp_flow.gd', '--', "--role=host", "--relay=ws://127.0.0.1:$RelayPort/ws", "--box=$box", "--days=$Days", "--replay-log=$box\host.hashes.log")
    $h = Start-Process -FilePath $Godot -ArgumentList $hostArgs -RedirectStandardOutput "$box\host.stdout.txt" -RedirectStandardError "$box\host.stderr.txt" -PassThru -NoNewWindow
    $g1Args = @('--headless', '--path', $repo, '-s', 'tests/mp_flow.gd', '--', "--role=guest", "--relay=ws://127.0.0.1:$RelayPort/ws", "--box=$box", "--days=$Days", "--replay-log=$box\guest.first.hashes.log", "--quit-at=$RejoinCode")
    $g = Start-Process -FilePath $Godot -ArgumentList $g1Args -RedirectStandardOutput "$box\guest.first.stdout.txt" -RedirectStandardError "$box\guest.first.stderr.txt" -PassThru -NoNewWindow
    $g.WaitForExit(600000) | Out-Null
    $g2Args = @('--headless', '--path', $repo, '-s', 'tests/mp_flow.gd', '--', "--role=guest", "--relay=ws://127.0.0.1:$RelayPort/ws", "--box=$box", "--days=$Days", "--replay-log=$box\guest.hashes.log", "--rejoin-code")
    $g2 = Start-Process -FilePath $Godot -ArgumentList $g2Args -RedirectStandardOutput "$box\guest.stdout.txt" -RedirectStandardError "$box\guest.stderr.txt" -PassThru -NoNewWindow
    foreach ($p in @($h, $g2)) { if (-not $p.WaitForExit(900000)) { $p.Kill(); Write-Host "TIMEOUT" } }
    foreach ($f in @('host', 'guest.first', 'guest')) { Select-String -Path "$box\$f.stdout.txt" -Pattern '\[mp_flow\]|\[GameManager\] head|\[Lockstep\] rebuilt' | ForEach-Object { Write-Host "  $($_.Line)" } }
    $a = @{}; Get-Content "$box\host.hashes.log" | Select-Object -Skip 1 | ForEach-Object { $d, $hh = $_ -split ',', 2; $a[[int]$d] = $hh }
    $b = @{}; Get-Content "$box\guest.hashes.log" | Select-Object -Skip 1 | ForEach-Object { $d, $hh = $_ -split ',', 2; $b[[int]$d] = $hh }
    $shared = $a.Keys | Where-Object { $b.ContainsKey($_) } | Sort-Object
    $n = $shared.Count; $same = 0
    foreach ($d in $shared) { if ($a[$d] -eq $b[$d]) { $same++ } }
    Write-Host ("M5 (rejoin by code through the screens, guest dropped day $RejoinCode) GATE: {0} of {1} day hashes identical  (box: {2})" -f $same, $n, $box)
    try { $relay.Kill() } catch {}
    exit
}
$g1 = Run-Pair "" $(if ($SpeedRule -ne '') { @("--speed-rule=$SpeedRule") } else { @() })
Write-Host ("M4 (screens -> lockstep) GATE: {0}  (box: {1})" -f $g1, $box)
if ($Load) {
    Remove-Item "$box\room.code" -Force
    $g2 = Run-Pair ".load" @('--load')
    Write-Host ("M5 (Load Game from the Options screen) GATE: {0}" -f $g2)
}
try { $relay.Kill() } catch {}
