# Unattended multiplayer test: starts a host and a client of the built game
# on this PC, lets them play a direct-connection game by themselves and
# checks the result. Nothing to click, the game windows stay hidden.
#
#   pwsh tools/mptest.ps1                      # 20 rounds, 2 AI civs
#   pwsh tools/mptest.ps1 -Turns 50 -AIPlayers 3
#   pwsh tools/mptest.ps1 -Asan                # client with AddressSanitizer
#   pwsh tools/mptest.ps1 -Show                # watch the two windows
#
# Needs the game data in the working copy (ctp2_data, Scenarios) and a
# Final-SDL x64 build (tools/win-build.ps1). Exit code 0 = passed.
#
# What it checks: both instances reach the requested round, nobody crashes
# or hangs, no database CRC errors, no resync requests (= client state did
# not drift from the host).

param(
    [int]$Turns = 20,
    [int]$AIPlayers = 2,
    [int]$TimeoutMinutes = 30,
    [switch]$Asan,
    [switch]$Show,
    [string]$Port = '21157'
)

$ErrorActionPreference = 'Stop'
$root   = Split-Path -Parent $PSScriptRoot
$ctpDir = Join-Path $root 'ctp2_code\ctp'
$build  = Join-Path $ctpDir 'x64'
if (-not (Test-Path (Join-Path $build 'ctp2.exe'))) { throw "No build in $build - run tools/win-build.ps1 first" }

# --- prepare two program folders next to x64 (paths in civpaths.txt are relative)
function Prepare-Instance([string]$name) {
    $dir = Join-Path $ctpDir $name
    New-Item -ItemType Directory -Force $dir | Out-Null
    Copy-Item (Join-Path $build 'ctp2.exe'), (Join-Path $build '*.dll'), (Join-Path $build 'civpaths.txt'), `
              (Join-Path $build 'anet.inf'), (Join-Path $build 'appstr.txt') $dir -Force
    Copy-Item (Join-Path $build 'dll') $dir -Recurse -Force
    # release network DLL (the logging variant only if the folder had one)
    Copy-Item (Join-Path $build 'anet2.dll') $dir -Force
    Remove-Item (Join-Path $dir 'dp.ini'), (Join-Path $dir 'autotest_*.txt') -ErrorAction SilentlyContinue
    Set-Content -Path (Join-Path $dir 'userprofile.txt') -Encoding ascii -Value @(
        'WindowedMode=Yes', 'ScreenResWidth=800', 'ScreenResHeight=600', 'TryWindowsResolution=No',
        'FullScreenMovies=No', 'SfxVolume=0', 'VoiceVolume=0', 'MusicVolume=0')
    return $dir
}

$hostDir   = Prepare-Instance 'autotest_host'
$clientDir = Prepare-Instance 'autotest_client'

$clientExe = 'ctp2.exe'
if ($Asan) {
    $asanExe = Join-Path $root '_local\asan\out\ctp2-asan.exe'
    if (-not (Test-Path $asanExe)) { throw "No ASan build at $asanExe" }
    Copy-Item $asanExe $clientDir -Force
    $vs = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -property installationPath
    $rt = Get-ChildItem (Join-Path $vs 'VC\Tools\MSVC') -Recurse -Filter 'clang_rt.asan_dynamic-x86_64.dll' |
          Where-Object { $_.FullName -like '*Hostx64\x64*' } | Select-Object -First 1
    Copy-Item $rt.FullName $clientDir -Force
    $clientExe = 'ctp2-asan.exe'
}

$showArg = if ($Show) { ' autoshow' } else { '' }
$common = "nointromovie autoturns=$Turns$showArg"

Write-Host "Host:   $hostDir"
Write-Host "Client: $clientDir  ($clientExe)"
Write-Host "Rounds: $Turns, AI civilisations: $AIPlayers"

$hostProc = Start-Process -FilePath (Join-Path $hostDir 'ctp2.exe') -WorkingDirectory $hostDir -PassThru `
    -ArgumentList "$common autohost autoai=$AIPlayers autoname=AutoHost"
Start-Sleep -Seconds 8

$clientArgs = "$common autojoin=127.0.0.1:$Port autoname=AutoClient"
if ($Asan) {
    $env:ASAN_OPTIONS = 'alloc_dealloc_mismatch=0:continue_on_error=1'
    $clientProc = Start-Process -FilePath (Join-Path $clientDir $clientExe) -WorkingDirectory $clientDir -PassThru `
        -ArgumentList $clientArgs -RedirectStandardOutput (Join-Path $clientDir 'asan_output.txt') `
        -RedirectStandardError (Join-Path $clientDir 'asan_stderr.txt')
} else {
    $clientProc = Start-Process -FilePath (Join-Path $clientDir $clientExe) -WorkingDirectory $clientDir -PassThru `
        -ArgumentList $clientArgs
}

# --- wait
$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
$lastRound = ''
while ((Get-Date) -lt $deadline -and (-not $hostProc.HasExited -or -not $clientProc.HasExited)) {
    Start-Sleep -Seconds 5
    $hl = Get-Content (Join-Path $hostDir 'autotest_log.txt') -ErrorAction SilentlyContinue | Select-String '^\[.*\] round ' | Select-Object -Last 1
    $cl = Get-Content (Join-Path $clientDir 'autotest_log.txt') -ErrorAction SilentlyContinue | Select-String '^\[.*\] round ' | Select-Object -Last 1
    $status = "host: $(if ($hl) { ($hl.Line -split ' round ')[1] } else { '-' })  client: $(if ($cl) { ($cl.Line -split ' round ')[1] } else { '-' })"
    if ($status -ne $lastRound) { Write-Host "  rounds  $status"; $lastRound = $status }
    if ($hostProc.HasExited -and -not (Test-Path (Join-Path $hostDir 'autotest_result.txt'))) { break }
    if ($clientProc.HasExited -and -not (Test-Path (Join-Path $clientDir 'autotest_result.txt'))) { break }
}

foreach ($p in $hostProc, $clientProc) { if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } }

# --- evaluate
function Read-Result([string]$dir, [string]$who) {
    $file = Join-Path $dir 'autotest_result.txt'
    $r = @{ who = $who; ok = $false; text = '' }
    if (-not (Test-Path $file)) {
        $last = Get-Content (Join-Path $dir 'autotest_log.txt') -ErrorAction SilentlyContinue | Select-Object -Last 1
        $r.text = "no result file (crashed, hung or timed out); last log line: $last"
        return $r
    }
    $kv = @{}
    Get-Content $file | ForEach-Object { if ($_ -match '^(\w+)=(.*)$') { $kv[$matches[1]] = $matches[2] } }
    $r.ok = ($kv.result -eq 'ok') -and ([int]$kv.crc_errors -eq 0) -and ([int]$kv.resync_requests -eq 0)
    $r.text = "result=$($kv.result) rounds=$($kv.rounds) crc_errors=$($kv.crc_errors) resync_requests=$($kv.resync_requests) resyncs_sent=$($kv.resyncs_sent) seconds=$($kv.seconds)"
    return $r
}

$results = @( (Read-Result $hostDir 'host'), (Read-Result $clientDir 'client') )
Write-Host ''
foreach ($r in $results) { Write-Host ("{0,-7} {1}  {2}" -f $r.who, ($(if ($r.ok) { 'OK  ' } else { 'FAIL' })), $r.text) }

if ($Asan) {
    $asanOut = Join-Path $clientDir 'asan_output.txt'
    $n = (Select-String -Path $asanOut -Pattern 'ERROR: AddressSanitizer' -ErrorAction SilentlyContinue | Measure-Object).Count
    $w = (Select-String -Path $asanOut -Pattern 'WRITE of size|double-free|use-after-free' -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-Host "ASan: $n reports, $w writes/double frees/use-after-free  ($asanOut)"
}

if ($results | Where-Object { -not $_.ok }) { Write-Host 'MULTIPLAYER TEST FAILED'; exit 1 }
Write-Host 'MULTIPLAYER TEST PASSED'
exit 0
