# The M2 gate: two headless lockstep clients over a mailbox directory, then a
# diff of their day-hash logs. Usage:
#   .\tools\lockstep-local.ps1 [-Days 200] [-Seed 12345] [-Corrupt 0]
param(
    [int]$Days = 200,
    [int]$Seed = 12345,
    [int]$Corrupt = 0,
    [switch]$Relay,          # M3 gate A: through a relay started here for the duration of the test
    [int]$Rejoin = 0,        # M5 gate: the Empire client quits on this day and rejoins the room
    [int]$RelayPort = 8787,
    [string]$Godot = 'D:\Downloads\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
)
$repo = Split-Path -Parent $PSScriptRoot
$box = Join-Path $env:TEMP ("lockstep-" + [guid]::NewGuid().ToString().Substring(0, 8))
New-Item -ItemType Directory -Force $box | Out-Null
$relayProc = $null
if ($Relay) {
    $env:PORT = "$RelayPort"; $env:DATA_DIR = "$box\relay-data"
    $relayProc = Start-Process -FilePath 'bun' -ArgumentList @('run', (Join-Path $repo 'relay\server.ts')) -RedirectStandardOutput "$box\relay.stdout.txt" -RedirectStandardError "$box\relay.stderr.txt" -PassThru -NoNewWindow
    Start-Sleep -Seconds 2
}
$procs = @()
foreach ($side in @('alliance', 'empire')) {
    $args = @('--headless', '--path', $repo, '-s', 'tests/lockstep_client.gd', '--',
        "--side=$side", "--mailbox=$box", "--days=$Days", "--seed=$Seed", "--replay-log=$box\$side.hashes.log")
    if ($Relay) { $args += "--relay=ws://127.0.0.1:$RelayPort/ws" }
    if ($Corrupt -gt 0 -and $side -eq 'empire') { $args += "--corrupt=$Corrupt" }
    if ($Rejoin -gt 0 -and $side -eq 'empire') { $args += "--quit-at=$Rejoin" }
    $procs += Start-Process -FilePath $Godot -ArgumentList $args -RedirectStandardOutput "$box\$side.stdout.txt" -RedirectStandardError "$box\$side.stderr.txt" -PassThru -NoNewWindow
}
if ($Rejoin -gt 0) {
    # Wait for the Empire to drop, then bring it back into the same room.
    $procs[1].WaitForExit(600000) | Out-Null
    Move-Item "$box\empire.stdout.txt" "$box\empire.first.stdout.txt" -Force
    $args = @('--headless', '--path', $repo, '-s', 'tests/lockstep_client.gd', '--',
        "--side=empire", "--mailbox=$box", "--days=$Days", "--seed=$Seed", "--replay-log=$box\empire.hashes.log", "--relay=ws://127.0.0.1:$RelayPort/ws", "--rejoin")
    $procs[1] = Start-Process -FilePath $Godot -ArgumentList $args -RedirectStandardOutput "$box\empire.stdout.txt" -RedirectStandardError "$box\empire.stderr.txt" -PassThru -NoNewWindow
}
foreach ($p in $procs) { if (-not $p.WaitForExit(900000)) { $p.Kill(); Write-Host "TIMEOUT" } }
foreach ($side in @('alliance', 'empire')) {
    $line = Select-String -Path "$box\$side.stdout.txt" -Pattern '\[lockstep\]' | ForEach-Object { $_.Line }
    $idx = if ($side -eq 'alliance') { 0 } else { 1 }
    Write-Host ("{0}: exit {1}" -f $side, $procs[$idx].ExitCode)
    $line | ForEach-Object { Write-Host "  $_" }
    $errs = (Select-String -Path "$box\$side.stdout.txt", "$box\$side.stderr.txt" -Pattern 'SCRIPT ERROR' | Measure-Object).Count
    Write-Host "  script errors: $errs"
}
$a = @{}; Get-Content "$box\alliance.hashes.log" | Select-Object -Skip 1 | ForEach-Object { $d, $h = $_ -split ',', 2; $a[[int]$d] = $h }
$b = @{}; Get-Content "$box\empire.hashes.log" | Select-Object -Skip 1 | ForEach-Object { $d, $h = $_ -split ',', 2; $b[[int]$d] = $h }
$shared = $a.Keys | Where-Object { $b.ContainsKey($_) } | Sort-Object
$n = $shared.Count; $same = 0; $first = -1
foreach ($d in $shared) { if ($a[$d] -eq $b[$d]) { $same++ } elseif ($first -lt 0) { $first = $d } }
$gate = if ($Rejoin -gt 0) { "M5 (rejoin day $Rejoin)" } elseif ($Relay) { "M3-A (relay)" } else { "M2" }
Write-Host ("{4} GATE: {0} of {1} day hashes identical{2}  (mailbox: {3})" -f $same, $n, $(if ($first -ge 0) { " - first difference on day $first" } else { "" }), $box, $gate)
if ($relayProc) { try { $relayProc.Kill() } catch {} ; Write-Host ("relay log lines: {0}" -f ((Get-ChildItem "$box\relay-data\rooms" -Recurse -Filter log.jsonl | Get-Content | Measure-Object -Line).Lines)) }
