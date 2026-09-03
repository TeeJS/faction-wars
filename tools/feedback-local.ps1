# The feedback box gate: a local relay, one headless client that submits a
# report, then the files the relay wrote. Usage: .\tools\feedback-local.ps1
param(
    [int]$RelayPort = 8791,
    [string]$Godot = 'D:\Downloads\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
)
$repo = Split-Path -Parent $PSScriptRoot
$box = Join-Path $env:TEMP ("feedback-" + [guid]::NewGuid().ToString().Substring(0, 8))
New-Item -ItemType Directory -Force $box | Out-Null
$env:PORT = "$RelayPort"; $env:DATA_DIR = "$box\relay-data"
$relay = Start-Process -FilePath 'bun' -ArgumentList @('run', (Join-Path $repo 'relay\server.ts')) -RedirectStandardOutput "$box\relay.stdout.txt" -RedirectStandardError "$box\relay.stderr.txt" -PassThru -NoNewWindow
Start-Sleep -Seconds 2
& $Godot --headless --path $repo -s tests/feedback_smoke.gd -- "--relay=ws://127.0.0.1:$RelayPort/ws" 2>&1 | Select-String 'feedback_smoke|FAIL|SCRIPT ERROR' | ForEach-Object { Write-Host "  $($_.Line)" }
$files = Get-ChildItem "$box\relay-data\feedback" -ErrorAction SilentlyContinue
Write-Host ("files written: " + (($files | ForEach-Object { $_.Name }) -join ", "))
$json = $files | Where-Object { $_.Extension -eq '.json' } | Select-Object -First 1
if ($json) { $r = Get-Content $json.FullName -Raw | ConvertFrom-Json; Write-Host ("report: player={0} game={1} day={2} seed={3} log_lines={4} message='{5}'" -f $r.player, $r.game, $r.day, $r.seed, $r.log_lines, $r.message) }
$ok = ($files.Count -eq 2) -and $json -and ($r.log_lines -ge 3)
Write-Host ("FEEDBACK GATE: {0}" -f $(if ($ok) { "PASS" } else { "FAIL" }))
try { $relay.Kill() } catch {}
git -C $repo checkout -- project.godot 2>$null
