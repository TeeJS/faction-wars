# run-tests.ps1 - every headless test in tests/, one line each, then the red ones.
#
#   .\tools\run-tests.ps1                 all of them (about 25 minutes)
#   .\tools\run-tests.ps1 -Match fleet    only tests whose name contains "fleet"
#
# Tests with their own harness are run the way their headers say, or left to
# their tool: never one that talks to a server (feedback_smoke posts a report -
# tools/feedback-local.ps1 runs it against a relay on this machine; tls_probe
# connects to the host it is given). The captures need a window, the soak and
# the parity check have their gates (soak-gate.ps1, dto-parity.ps1), and the
# lockstep and mp_flow pairs have theirs (lockstep-local.ps1, mp-flow-local.ps1).
#
# One run at a time: every checkout of this project shares one user:// folder,
# so two runs side by side read each other's settings and saves.

param([string]$Match = "", [int]$TimeoutSeconds = 300)

$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo
$runGd = Join-Path $PSScriptRoot 'run-gd.ps1'
$leftToTools = @('capture_', 'bench_', 'soak', 'dto_parity', 'lockstep_client', 'mp_flow', 'ency_clicks', 'feedback_smoke', 'tls_probe')
# name -> its runs in order, each run's arguments space-separated (run-gd adds
# Godot's "--"); the test's verdict is the last run's.
$harness = @{
    'pack_plumbing' = @('--pack=ww2')
    'pack_switch'   = @('--pack=ww2 --write', '')
    'validate_pack' = @('--dir=res://packs/star-wars-rebellion')
}

function Invoke-Test([string]$name, [string[]]$extra) {
    $job = Start-Job -ScriptBlock {
        param($r, $gd, $t, $a)
        Set-Location $r
        & $gd "tests/$t.gd" @a 2>&1 | Out-String
        $LASTEXITCODE
    } -ArgumentList $repo, $runGd, $name, $extra
    if (-not (Wait-Job $job -Timeout $TimeoutSeconds)) {
        Stop-Job $job; Remove-Job $job -Force
        return @{ code = 'TIMEOUT'; text = '' }
    }
    $res = Receive-Job $job; Remove-Job $job
    return @{ code = ($res | Select-Object -Last 1); text = (($res | Select-Object -SkipLast 1) -join "`n") }
}

$lines = @()
foreach ($f in Get-ChildItem tests -Filter *.gd | Sort-Object Name) {
    $n = $f.BaseName
    if ($Match -and -not $n.Contains($Match)) { continue }
    if ($leftToTools | Where-Object { $n.StartsWith($_) }) { continue }
    $runs = @('')
    if ($harness.ContainsKey($n)) { $runs = $harness[$n] }
    $r = $null
    foreach ($spec in $runs) {
        $a = @()
        if ($spec) { $a = $spec -split ' ' }
        $r = Invoke-Test $n $a
    }
    # The test's own verdict line ("[name] 12 checks, 0 failed"), else any.
    $out = $r.text -split "`n"
    $summary = $out | Where-Object { $_ -match "^\[$n\]" -and $_ -match 'checks|PASS|FAIL|SKIP|failed|passed|scripts|ran' } | Select-Object -Last 1
    if (-not $summary) { $summary = $out | Where-Object { $_ -match 'checks|PASS|FAIL|SKIP|failed|passed' } | Select-Object -Last 1 }
    $line = '{0,-32} exit={1}  {2}' -f $n, $r.code, $summary
    $line
    $lines += $line
}
$red = @($lines | Where-Object { $_ -notmatch 'exit=0 ' })
"--- $($lines.Count) tests, $($red.Count) red"
$red
exit $red.Count
