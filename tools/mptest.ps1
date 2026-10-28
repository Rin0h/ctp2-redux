# Unattended multiplayer test: starts a host and a client of the built game
# on this PC, lets them play a direct-connection game by themselves and
# checks the result. Nothing to click, the game windows stay hidden.
#
#   pwsh tools/mptest.ps1                      # 20 rounds, 2 AI civs
#   pwsh tools/mptest.ps1 -Turns 50 -AIPlayers 3
#   pwsh tools/mptest.ps1 -Asan                # client with AddressSanitizer
#   pwsh tools/mptest.ps1 -Show                # watch the two windows
#   pwsh tools/mptest.ps1 -ShotEvery 5         # screenshot every 5th round (0 = none)
#   pwsh tools/mptest.ps1 -Idle                # test players only end their turns
#   pwsh tools/mptest.ps1 -AnetLog             # network library with logging (dp.log)
#   pwsh tools/mptest.ps1 -Single -Tour        # screenshots of all game windows (autotest_ui_*.png)
#   pwsh tools/mptest.ps1 -Single -Tour -Apolyton   # the same with the Apolyton interface
#   pwsh tools/mptest.ps1 -JoinAddress '[::1]:21157'   # client joins over IPv6
#
# By default the two test players play a simple turn (settle, walk, fill
# build queues, pick research), so their actions go over the network.
#
# Each instance logs a stats line per player and round (cities, units,
# gold, advances) and saves a screenshot of its own turn start as
# autotest_round_<nnn>.png in its folder, also while the window is hidden.
#
# Needs the game data in the working copy (ctp2_data, Scenarios) and a
# Final-SDL x64 build (tools/win-build.ps1). Exit code 0 = passed.
#
# What it checks: both instances reach the requested round, nobody crashes
# or hangs, no database CRC errors, no resync requests (= client state did
# not drift from the host), and host and client log identical values for
# the AI civilisations (cities, units, gold, advances).

param(
    [int]$Turns = 20,
    [int]$AIPlayers = 2,
    [int]$TimeoutMinutes = 30,
    [switch]$Asan,
    [switch]$Show,
    [int]$ShotEvery = 1,
    [switch]$Idle,
    [switch]$Single,
    [switch]$Tour,
    [switch]$Apolyton,
    [switch]$AnetLog,
    [string]$Port = '21157',
    [string]$JoinAddress = ''
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
    # Own base directory: with the "..'" of the build every instance would
    # read and write ctp2_code\ctp\userprofile.txt and share the saves.
    # Base "." means the data is one level further up.
    $paths = Get-Content (Join-Path $build 'civpaths.txt')
    $paths[0] = '.'
    $paths = $paths | ForEach-Object { if ($_ -like '..\..\*') { '..\' + $_ } else { $_ } }
    Set-Content -Path (Join-Path $dir 'civpaths.txt') -Value $paths -Encoding ascii
    Remove-Item (Join-Path $dir 'dp.ini'), (Join-Path $dir 'autotest_*.txt'), (Join-Path $dir 'autotest_*.png') -ErrorAction SilentlyContinue
    # profile: the shared one of the working copy (if any) with the test
    # settings on top; a nearly empty profile leaves e.g. the map plugin
    # settings in a state that asks for a library with an empty name
    $settings = [ordered]@{
        WindowedMode = 'Yes'; ScreenResWidth = '1024'; ScreenResHeight = '768'; TryWindowsResolution = 'No'
        FullScreenMovies = 'No'; SfxVolume = '0'; VoiceVolume = '0'; MusicVolume = '0'
        ClassicInterface = $(if ($Apolyton) { 'No' } else { 'Yes' })
        DisplayScale = '1'
    }
    $shared = Join-Path $ctpDir 'userprofile.txt'
    $profile = @(if (Test-Path $shared) { Get-Content $shared -Encoding latin1 | Where-Object { $_ -notmatch "^($($settings.Keys -join '|'))=" } })
    $profile += $settings.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }
    Set-Content -Path (Join-Path $dir 'userprofile.txt') -Encoding latin1 -Value $profile
    return $dir
}

# result file of one instance
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

$playArg = if ($Idle) { ' autoplay=0' } else { '' }
$showArg = if ($Show) { ' autoshow' } else { '' }

# --- single player comparison run: one instance, same profile, as many
# civilisations as the network game (the second human becomes an AI)
if ($Single) {
    $dir = Prepare-Instance 'autotest_single'
    $tourArg = ''
    if ($Tour) {
        # screenshots of all windows at the resolution the layouts were made for
        $tourArg = ' autotour'
        (Get-Content (Join-Path $dir 'userprofile.txt') -Encoding latin1) -replace 'ScreenResWidth=\d+', 'ScreenResWidth=1024' `
            -replace 'ScreenResHeight=\d+', 'ScreenResHeight=768' | Set-Content (Join-Path $dir 'userprofile.txt') -Encoding latin1
        Remove-Item (Join-Path $dir 'autotest_ui_*.png') -ErrorAction SilentlyContinue
    }
    Write-Host "Single player: $dir, rounds: $Turns"
    $p = Start-Process -FilePath (Join-Path $dir 'ctp2.exe') -WorkingDirectory $dir -PassThru `
        -ArgumentList "nointromovie autoturns=$Turns autoshots=$ShotEvery autoai=$AIPlayers autosingle$playArg$showArg$tourArg"
    if (-not $p.WaitForExit($TimeoutMinutes * 60 * 1000)) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
    $r = Read-Result $dir 'single'
    Write-Host ("single  {0}  {1}" -f ($(if ($r.ok) { 'OK  ' } else { 'FAIL' })), $r.text)
    $stats = Get-Content (Join-Path $dir 'autotest_log.txt') -ErrorAction SilentlyContinue | Select-String " stats round $Turns "
    if ($stats) {
        Write-Host "Game state in round ${Turns}:"
        $stats | ForEach-Object { Write-Host ('  ' + ($_.Line -split ' player ')[1]) }
    }
    if ($r.ok) { exit 0 } else { exit 1 }
}

$hostDir   = Prepare-Instance 'autotest_host'
$clientDir = Prepare-Instance 'autotest_client'

# network library with logging: both write dp.log next to the exe
if ($AnetLog) {
    $anetDll = Join-Path $root 'ctp2_code\libs\anet\x64\anet2l.dll'
    if (-not (Test-Path $anetDll)) { throw "No logging network library at $anetDll (anet.vcxproj, configuration Logging)" }
    foreach ($d in $hostDir, $clientDir) {
        Copy-Item $anetDll (Join-Path $d 'anet2.dll') -Force
        Set-Content -Path (Join-Path $d 'dp.ini') -Encoding ascii -Value @('[Debug]', 'All=1', 'ToLog=1', 'Logfile=dp.log')
        Remove-Item (Join-Path $d 'dp.log') -ErrorAction SilentlyContinue
    }
}

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

$common = "nointromovie autoturns=$Turns autoshots=$ShotEvery$playArg$showArg"

Write-Host "Host:   $hostDir"
Write-Host "Client: $clientDir  ($clientExe)"
Write-Host "Rounds: $Turns, AI civilisations: $AIPlayers"

$hostProc = Start-Process -FilePath (Join-Path $hostDir 'ctp2.exe') -WorkingDirectory $hostDir -PassThru `
    -ArgumentList "$common autohost autoai=$AIPlayers autoname=AutoHost"
Start-Sleep -Seconds 8

if (-not $JoinAddress) { $JoinAddress = "127.0.0.1:$Port" }
$clientArgs = "$common autojoin=$JoinAddress autoname=AutoClient"
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
$results = @( (Read-Result $hostDir 'host'), (Read-Result $clientDir 'client') )
Write-Host ''
foreach ($r in $results) { Write-Host ("{0,-7} {1}  {2}" -f $r.who, ($(if ($r.ok) { 'OK  ' } else { 'FAIL' })), $r.text) }

# --- how the game went: last stats of the host, screenshots of both
$stats = Get-Content (Join-Path $hostDir 'autotest_log.txt') -ErrorAction SilentlyContinue | Select-String ' stats round '
if ($stats) {
    # the last round both played (afterwards the AI takes over the client's civ)
    $lastRoundStats = ($stats[-1].Line -split ' stats round ')[1].Split(' ')[0]
    if ([int]$lastRoundStats -gt $Turns) { $lastRoundStats = $Turns }
    Write-Host ''
    Write-Host "Game state in round $lastRoundStats (host view):"
    $stats | Where-Object { $_.Line -like "* stats round $lastRoundStats *" } |
        ForEach-Object { Write-Host ('  ' + ($_.Line -split ' player ')[1]) }
}
foreach ($d in $hostDir, $clientDir) {
    $shots = @(Get-ChildItem $d -Filter 'autotest_round_*.png' -ErrorAction SilentlyContinue)
    if ($shots.Count) { Write-Host "Screenshots: $($shots.Count) in $d (autotest_round_<nnn>.png)" }
}

# --- desync check: the AI civilisations as host and client see them.
# The client's round counter runs one turn ahead; between the host's round N
# start and the client's round N+1 start only the host itself moves, so the
# AI values must be identical.
function Read-AiStats([string]$dir) {
    $m = @{}
    Get-Content (Join-Path $dir 'autotest_log.txt') -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_ -match ' stats round (\d+) player (\d+) ai: (.*)$') { $m["$($matches[1])/$($matches[2])"] = $matches[3] }
    }
    return $m
}
$hostAi   = Read-AiStats $hostDir
$clientAi = Read-AiStats $clientDir
$compared = 0; $mismatches = @()
foreach ($key in $hostAi.Keys) {
    $round, $player = $key.Split('/')
    if ([int]$round -ge $Turns) { continue }   # the client has left by then
    $ckey = "$([int]$round + 1)/$player"
    if (-not $clientAi.ContainsKey($ckey)) { continue }
    $compared++
    if ($hostAi[$key] -ne $clientAi[$ckey]) {
        $mismatches += "  round $round player ${player}: host '$($hostAi[$key])' client '$($clientAi[$ckey])'"
    }
}
# terrain at the end (both write autotest_map_end.txt when they quit; the
# environment flags may differ by the AI moves in between, terrain may not)
$hm = Get-Content (Join-Path $hostDir 'autotest_map_end.txt') -ErrorAction SilentlyContinue
$cm = Get-Content (Join-Path $clientDir 'autotest_map_end.txt') -ErrorAction SilentlyContinue
$mapText = 'end maps missing'
if ($hm -and $cm) {
    $terrainDiff = 0
    for ($i = 0; $i -lt [Math]::Min($hm.Count, $cm.Count); $i++) {
        if ($hm[$i].Split(' ')[2] -ne $cm[$i].Split(' ')[2]) { $terrainDiff++ }
    }
    $mapText = "terrain of $($hm.Count) map cells identical"
    if ($terrainDiff -or $hm.Count -ne $cm.Count) {
        $mismatches += "  map: $terrainDiff of $($hm.Count) cells have a different terrain"
    }
}

Write-Host ''
if ($mismatches.Count) {
    Write-Host "Desync check: $($mismatches.Count) differences between host and client ($compared AI values compared):"
    $mismatches | Sort-Object | ForEach-Object { Write-Host $_ }
} else {
    Write-Host "Desync check: $compared AI values identical on host and client, $mapText"
}

if ($Asan) {
    $asanOut = Join-Path $clientDir 'asan_output.txt'
    $n = (Select-String -Path $asanOut -Pattern 'ERROR: AddressSanitizer' -ErrorAction SilentlyContinue | Measure-Object).Count
    $w = (Select-String -Path $asanOut -Pattern 'WRITE of size|double-free|use-after-free' -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-Host "ASan: $n reports, $w writes/double frees/use-after-free  ($asanOut)"
}

if (($results | Where-Object { -not $_.ok }) -or $mismatches.Count) { Write-Host 'MULTIPLAYER TEST FAILED'; exit 1 }
Write-Host 'MULTIPLAYER TEST PASSED'
exit 0
