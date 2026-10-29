# Builds the release package of ctp2-redux: a zip to unpack into the game
# folder of an installed Call to Power II (GOG or CD), next to ctp2_data and
# ctp2_program.
#
#   pwsh tools/make-release.ps1              # -> _local/release/ctp2-redux-<date>.zip
#   pwsh tools/make-release.ps1 -Version 2026-11-01
#
# Contents:
#   ctp2_program\ctp\x64\   the program (Final-SDL x64 of tools/win-build.ps1),
#                           its release DLLs and ffmpeg.exe for the HD setup;
#                           laid out like ctp2_code\ctp\x64 of the working copy,
#                           so music, saves and profile of the installation count
#   ctp2_data\, Scenarios\  the data files of the repository (Apolyton Edition
#                           and ctp2-redux): texts, layouts, Apolyton graphics
#   ctp2-redux-hd-setup.bat the HD setup (with its two .ps1), in the game folder
#   ctp2-redux-README.txt, Licenses\  instructions (English, German) and the licences
#
# Never in the package: files that are byte for byte original game files
# (see $originals), the upscaled files (redux_hires), files the game writes
# itself (nguid.ctp, feif.dat, profiles, saves), debug builds.

param(
    [string]$Version = (Get-Date -Format 'yyyy-MM-dd')
)

$ErrorActionPreference = 'Stop'
$root  = Split-Path -Parent $PSScriptRoot
$build = Join-Path $root 'ctp2_code\ctp\x64'
$out   = Join-Path $root '_local\release'
$name  = "ctp2-redux-$Version"
$stage = Join-Path $out $name

# repository files that are identical to files of the original game (checked
# against the GOG version, 2026-10-29); the player has them already
$originals = @(
    'ctp2_data/default/graphics/pictures/CnBG.tga',
    'Scenarios/AlexanderTheGreat/scen0000/scenicon.tga'
)

if (-not (Test-Path (Join-Path $build 'ctp2.exe'))) { throw "No build in $build - run tools/win-build.ps1 first" }
if (-not (Test-Path (Join-Path $build 'ffmpeg.exe'))) { throw "No ffmpeg.exe in $build - tools/win-build.ps1 builds it" }
if (Get-Process ctp2 -ErrorAction SilentlyContinue) { throw 'A ctp2.exe is running - close it first' }

Write-Host "Package $name"
Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $stage | Out-Null

# --- program -------------------------------------------------------------------
$program = Join-Path $stage 'ctp2_program\ctp\x64'
New-Item -ItemType Directory -Force $program | Out-Null
foreach ($f in 'ctp2.exe', 'ffmpeg.exe', 'SDL2.dll', 'SDL2_image.dll', 'SDL2_mixer.dll', 'anet2.dll',
               'tiff.dll', 'zlibwapi.dll', 'anet.inf', 'appstr.txt', 'civpaths.txt') {
    Copy-Item (Join-Path $build $f) $program
}
# map and network plugins: the release ones (the debug twins end in d.dll)
foreach ($sub in 'dll\map', 'dll\net') {
    $target = Join-Path $program $sub
    New-Item -ItemType Directory -Force $target | Out-Null
    $dlls = Get-ChildItem (Join-Path $build $sub) -Filter *.dll
    foreach ($dll in $dlls) {
        $release = $dll.BaseName -replace 'd$', ''
        $isDebugTwin = ($release -ne $dll.BaseName) -and ($dlls | Where-Object { $_.BaseName -eq $release })
        if (-not $isDebugTwin) { Copy-Item $dll.FullName $target }
    }
}
Write-Host "  program: $((Get-ChildItem $program -Recurse -File).Count) files"

# --- data ------------------------------------------------------------------------
$files = git -C $root ls-files ctp2_data Scenarios
$copied = 0
foreach ($rel in $files) {
    if ($originals -contains $rel) { continue }
    if ($rel -like '*.scc') { continue }               # Visual SourceSafe leftovers
    $target = Join-Path $stage $rel
    New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
    Copy-Item (Join-Path $root $rel) $target
    $copied++
}
Write-Host "  data: $copied files"

# --- HD setup, instructions, licences ------------------------------------------
Copy-Item (Join-Path $root 'tools\upscale\*') $stage
Copy-Item (Join-Path $PSScriptRoot 'package\ctp2-redux-README.txt') $stage
$licences = Join-Path $stage 'Licenses'
New-Item -ItemType Directory -Force $licences | Out-Null
$libs = Join-Path $root 'ctp2_code\libs'
$licenceFiles = [ordered]@{
    'LICENSE.md'                                 = Join-Path $root 'LICENSE.md'
    'EULA - Source Code for CTP2.md'             = Join-Path $root 'EULA - Source Code for CTP2.md'
    'Activision CTP2 Source Code_Readme.txt'     = Join-Path $root 'Activision CTP2 Source Code_Readme.txt'
    'Apolyton CTP2 Source Code_Readme.txt'       = Join-Path $root 'Apolyton CTP2 Source Code_Readme.txt'
    'SDL2-LICENSE.txt'                           = Join-Path $libs 'SDL2-2.30.12\LICENSE.txt'
    'SDL2_image-LICENSE.txt'                     = Join-Path $libs 'SDL2_image-2.8.8\LICENSE.txt'
    'SDL2_mixer-LICENSE.txt'                     = Join-Path $libs 'SDL2_mixer-2.8.1\LICENSE.txt'
    'FFmpeg-COPYING.LGPLv2.1.txt'                = Join-Path $libs 'FFmpeg-n6.1.2\COPYING.LGPLv2.1'
    'FFmpeg-LICENSE.md'                          = Join-Path $libs 'FFmpeg-n6.1.2\LICENSE.md'
    'Anet-LICENSE.txt'                           = Join-Path $libs 'anet\LICENSE'
    'zlib-LICENSE.txt'                           = Join-Path $libs 'zlib-1.3.1\LICENSE'
    'libtiff-LICENSE.md'                         = Join-Path $libs 'tiff-4.7.0\LICENSE.md'
    'FreeType-license.txt'                       = Join-Path $libs 'freetype-1.3.1\license.txt'
}
foreach ($entry in $licenceFiles.GetEnumerator()) { Copy-Item $entry.Value (Join-Path $licences $entry.Key) }
Set-Content -Path (Join-Path $licences 'SOURCE.txt') -Encoding utf8 -Value @(
    "ctp2-redux $Version, commit $(git -C $root rev-parse --short HEAD)",
    'Source code of the game and of all included libraries (FFmpeg, SDL, Anet, ...):',
    'https://github.com/Rin0h/ctp2-redux'
)

# --- zip ---------------------------------------------------------------------------
$zip = Join-Path $out "$name.zip"
Remove-Item $zip -ErrorAction SilentlyContinue
Push-Location $stage
try { tar.exe -a -c -f $zip * } finally { Pop-Location }
if ($LASTEXITCODE -ne 0) { throw 'tar failed' }
Write-Host ("Done: {0} ({1:N1} MB)" -f $zip, ((Get-Item $zip).Length / 1MB))
