# The M4 gate: two headless clients drive the real head-to-head screens through
# a local relay into a lockstep game, play N days at Fast, and their day hashes
# are diffed. -Load then runs a second pair that picks the saved game from the
# Load Game list (M5) and resumes it. -Save (issue #301): the host saves "The
# Battle of Hoth" on day 6; both computers' copy is checked, a second pair loads
# it from the Load Game list and must resume at the saved day and state, and
# each computer's copy is then loaded alone against the AI (tests/h2h_solo.gd).
# Each client keeps its saves in its own user:// folder (--save-dir). Usage:
#   .\tools\mp-flow-local.ps1 [-Days 30] [-Load] [-Save] [-PlainWindows] [-RelayPort 8790]
param(
    [int]$Days = 30,
    [switch]$Load,
    [switch]$Save,
    [switch]$PlainWindows,     # every client ignores the imported art: the plain windows
    [string]$SpeedRule = '',   # 'average' runs the pair under TeeJ's average rule
    [int]$RejoinCode = 0,      # the guest drops on this day and comes back by code through the screens
    [switch]$GuestOtherVersion,   # the guest starts on another version of the pack and must switch to the host's on joining (strangers plan PR 5)
    [int]$RelayPort = 8790,
    [string]$Godot = 'D:\Downloads\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
)
$repo = Split-Path -Parent $PSScriptRoot
$box = Join-Path $env:TEMP ("mpflow-" + [guid]::NewGuid().ToString().Substring(0, 8))
New-Item -ItemType Directory -Force $box | Out-Null
$env:PORT = "$RelayPort"; $env:DATA_DIR = "$box\relay-data"
$relay = Start-Process -FilePath 'bun' -ArgumentList @('run', (Join-Path $repo 'relay\server.ts')) -RedirectStandardOutput "$box\relay.stdout.txt" -RedirectStandardError "$box\relay.stderr.txt" -PassThru -NoNewWindow
Start-Sleep -Seconds 2

# Each computer's saves, apart from each other and from the player's own.
function SaveDir([string]$role) { return "user://mpflow-$(Split-Path -Leaf $box)-$role" }

function Run-Pair([string]$tag, [string[]]$extra, [string[]]$guestExtra = @(), [switch]$SwapDirs) {
    $procs = @()
    foreach ($role in @('host', 'guest')) {
        # -SwapDirs: each client reads the OTHER computer's saves - the guest's
        # copy of a save loaded by the host, so the seats are the other way round.
        $dirRole = if ($SwapDirs) { if ($role -eq 'host') { 'guest' } else { 'host' } } else { $role }
        $args = @('--headless', '--path', $repo, '-s', 'tests/mp_flow.gd', '--',
            "--role=$role", "--relay=ws://127.0.0.1:$RelayPort/ws", "--box=$box", "--days=$Days", "--replay-log=$box\$role$tag.hashes.log",
            "--save-dir=$(SaveDir $dirRole)") + $extra
        if ($PlainWindows) { $args += '--no-art' }
        if ($role -eq 'guest') { $args += $guestExtra }
        $p = Start-Process -FilePath $Godot -ArgumentList $args -RedirectStandardOutput "$box\$role$tag.stdout.txt" -RedirectStandardError "$box\$role$tag.stderr.txt" -PassThru -NoNewWindow
        # Windows PowerShell 5.1 leaves ExitCode empty unless the handle is opened now.
        $null = $p.Handle
        $procs += $p
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
$guestExtra = @()
if ($GuestOtherVersion) {
    # A copy of the default pack that differs only in its version - so in its
    # content hash - for the guest to start on (--pack-dir).
    $id = (Get-Content (Join-Path $repo 'packs\active.json') -Raw | ConvertFrom-Json).pack
    $alt = Join-Path $box "alt\$id"
    New-Item -ItemType Directory -Force (Split-Path $alt) | Out-Null
    Copy-Item (Join-Path $repo "packs\$id") $alt -Recurse
    $pj = Join-Path $alt 'pack.json'
    $text = [IO.File]::ReadAllText($pj) -replace '^\{', "{`n  `"version`": `"0.9-other`","
    [IO.File]::WriteAllText($pj, $text)
    $guestExtra = @("--pack-dir=$($alt -replace '\\', '/')")
}
$first = @()
if ($SpeedRule -ne '') { $first += "--speed-rule=$SpeedRule" }
if ($Save) { $first += @('--save', '--compact-every=40') }   # the history compacted several times before the save
$g1 = Run-Pair "" $first $guestExtra
Write-Host ("M4 (screens -> lockstep) GATE: {0}  (box: {1})" -f $g1, $box)
if ($Save) {
    # Both computers' saved game: written, the same game (orders and phase ends).
    $slots = @{}
    foreach ($role in @('host', 'guest')) {
        $line = Select-String -Path "$box\$role.stdout.txt" -Pattern '\[mp_flow\] \w+ SLOT' | Select-Object -Last 1
        $slots[$role] = if ($line) { $line.Line } else { '' }
    }
    $said = (Select-String -Path "$box\host.stdout.txt" -Pattern 'host SAVE says: (.*)' | Select-Object -Last 1)
    $digest = { param($l) if ($l -match 'digest=(\w+)') { $Matches[1] } else { '' } }
    $same = ($slots['host'] -match 'used=true side=h2h') -and ($slots['guest'] -match 'used=true side=h2h') -and ((& $digest $slots['host']) -eq (& $digest $slots['guest'])) -and (& $digest $slots['host'])
    Write-Host ("SAVE GATE: {0} - host says: {1}" -f $(if ($same) { 'PASS, written on both computers, the same game' } else { 'FAIL' }), $(if ($said) { $said.Matches[0].Groups[1].Value } else { '(nothing)' }))
    Remove-Item "$box\room.code" -Force
    $g3 = Run-Pair ".slot" @('--load-slot')
    Write-Host ("LOAD-SLOT GATE: {0}" -f $g3)
    foreach ($role in @('host', 'guest')) {
        Select-String -Path "$box\$role.slot.stdout.txt" -Pattern 'LOAD-SLOT resumed' | ForEach-Object { Write-Host "  $($_.Line)" }
    }
    # The same save from the guest's copy, the host now playing the side that
    # was the guest's: the galaxy stays seeded from the side that hosted it.
    Remove-Item "$box\room.code" -Force
    $g4 = Run-Pair ".swap" @('--load-slot') -SwapDirs
    Write-Host ("LOAD-SLOT SWAPPED SEATS GATE: {0}" -f $g4)
    foreach ($role in @('host', 'guest')) {
        Select-String -Path "$box\$role.swap.stdout.txt" -Pattern 'LOAD-SLOT resumed|plays \w+ from' | ForEach-Object { Write-Host "  $($_.Line)" }
    }
    # Each computer's copy played on alone, the AI taking the other side.
    foreach ($role in @('host', 'guest')) {
        $out = & (Join-Path $PSScriptRoot 'run-gd.ps1') 'tests/h2h_solo.gd' -- "--save-dir=$(SaveDir $role)" "--box=$box" 2>&1 | Out-String
        $v = ($out -split "`n" | Where-Object { $_ -match '^\[h2h_solo\]' } | Select-Object -Last 1)
        Write-Host ("SOLO GATE ($role's copy): {0}" -f $v)
        $out -split "`n" | Where-Object { $_ -match '^\s+FAIL ' } | ForEach-Object { Write-Host "  $_" }
    }
}
if ($Load) {
    Remove-Item "$box\room.code" -Force -ErrorAction SilentlyContinue
    $g2 = Run-Pair ".load" @('--load')
    Write-Host ("M5 (Load Game from the Options screen) GATE: {0}" -f $g2)
}
try { $relay.Kill() } catch {}
