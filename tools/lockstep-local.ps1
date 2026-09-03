# The M2 gate: two headless lockstep clients over a mailbox directory, then a
# diff of their day-hash logs. Usage:
#   .\tools\lockstep-local.ps1 [-Days 200] [-Seed 12345] [-Corrupt 0]
param(
    [int]$Days = 200,
    [int]$Seed = 12345,
    [int]$Corrupt = 0,
    [string]$Godot = 'D:\Downloads\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
)
$repo = Split-Path -Parent $PSScriptRoot
$box = Join-Path $env:TEMP ("lockstep-" + [guid]::NewGuid().ToString().Substring(0, 8))
New-Item -ItemType Directory -Force $box | Out-Null
$procs = @()
foreach ($side in @('alliance', 'empire')) {
    $args = @('--headless', '--path', $repo, '-s', 'tests/lockstep_client.gd', '--',
        "--side=$side", "--mailbox=$box", "--days=$Days", "--seed=$Seed", "--replay-log=$box\$side.hashes.log")
    if ($Corrupt -gt 0 -and $side -eq 'empire') { $args += "--corrupt=$Corrupt" }
    $procs += Start-Process -FilePath $Godot -ArgumentList $args -RedirectStandardOutput "$box\$side.stdout.txt" -RedirectStandardError "$box\$side.stderr.txt" -PassThru -NoNewWindow
}
foreach ($p in $procs) { if (-not $p.WaitForExit(900000)) { $p.Kill(); Write-Host "TIMEOUT" } }
foreach ($side in @('alliance', 'empire')) {
    $line = Select-String -Path "$box\$side.stdout.txt" -Pattern '\[lockstep\]' | ForEach-Object { $_.Line }
    Write-Host ("{0}: exit {1}" -f $side, ($procs | Where-Object { $_.HasExited })[0].ExitCode)
    $line | ForEach-Object { Write-Host "  $_" }
    $errs = (Select-String -Path "$box\$side.stdout.txt", "$box\$side.stderr.txt" -Pattern 'SCRIPT ERROR' | Measure-Object).Count
    Write-Host "  script errors: $errs"
}
$a = Get-Content "$box\alliance.hashes.log" | Select-Object -Skip 1
$b = Get-Content "$box\empire.hashes.log" | Select-Object -Skip 1
$n = [Math]::Min($a.Count, $b.Count)
$same = 0; $first = -1
for ($i = 0; $i -lt $n; $i++) { if ($a[$i] -eq $b[$i]) { $same++ } elseif ($first -lt 0) { $first = $i } }
Write-Host ("M2 GATE: {0} of {1} day hashes identical{2}  (mailbox: {3})" -f $same, $n, $(if ($first -ge 0) { " - first difference at line $first" } else { "" }), $box)
