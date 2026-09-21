# soak-gate.ps1 - THE BUILT-IN AI GATE: four headless soaks (tests/soak.gd, the AI on
# both sides) whose day hashes must match tests/fixtures/gate/*.log byte for byte.
#
#   .\tools\soak-gate.ps1                 compare against the committed baseline
#   .\tools\soak-gate.ps1 -Rebaseline     REWRITE the baseline from this tree
#
# A refactor of the AI must leave it green. A change that is MEANT to alter what the
# built-in AI decides (the fog-legal reads of 2026-09-20 were the first) re-baselines
# in the same commit and says so - never to make a red gate go away.

param([switch]$Rebaseline)

$repo = Split-Path -Parent $PSScriptRoot
$dir = Join-Path $repo 'tests\fixtures\gate'
New-Item -ItemType Directory -Force $dir | Out-Null
$runs = @(
    @{ n = '12345-standard-easy-200';   a = @('--days=200', '--seed=12345', '--size=Standard', '--difficulty=Easy') },
    @{ n = '12345-standard-medium-200'; a = @('--days=200', '--seed=12345', '--size=Standard', '--difficulty=Medium') },
    @{ n = '12345-standard-hard-200';   a = @('--days=200', '--seed=12345', '--size=Standard', '--difficulty=Hard') },
    @{ n = '777-large-hard-300';        a = @('--days=300', '--seed=777', '--size=Large', '--difficulty=Hard') }
)
$red = 0
foreach ($r in $runs) {
    $fixture = "res://tests/fixtures/gate/$($r.n).log"
    $rest = $r.a + $(if ($Rebaseline) { "--replay-log=$fixture" } else { "--expect=$fixture" })
    $out = & (Join-Path $PSScriptRoot 'run-gd.ps1') tests/soak.gd -Seconds 1800 @rest 2>&1
    $code = $LASTEXITCODE
    $verdict = $out | Where-Object { $_ -match '^\[soak\] hashes matching' } | Select-Object -Last 1
    if ($Rebaseline) { $verdict = 'baseline written' }
    elseif (-not $verdict) { $verdict = 'NO VERDICT (no baseline, or the soak did not finish)'; $code = 1 }
    if ($code -ne 0) { $red++ }
    '{0,-28} exit={1}  {2}' -f $r.n, $code, $verdict
}
exit $red
