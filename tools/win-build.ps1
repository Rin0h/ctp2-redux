# Builds Call to Power II on Windows with the VS 2022 Build Tools without
# administrator rights.
#
#   pwsh tools/win-build.ps1                 # Final-SDL x64 (default)
#   pwsh tools/win-build.ps1 -Config Debug-SDL
#   pwsh tools/win-build.ps1 -Platform Win32
#
# What it does:
#   * extracts NASM from ./NASM into _local/nasm (needed by FFmpeg)
#   * copies the VC build targets into _local/VCTargets and adds nasm.props
#     there, because installing into "Program Files" needs admin rights
#   * sets CDKDIR (bison/flex) and creates <drive>:\tmp
#   * runs MSBuild on ctp2_code/ctp/civctp.sln with the installed toolset
#
# Result: ctp2_code/ctp/x64/ctp2.exe (or ctp2_code/ctp/ctp2.exe for Win32)

param(
    [string]$Config = 'Final-SDL',
    [string]$Platform = 'x64',
    [string]$Toolset = 'v143',
    [string]$Sdk = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$local = Join-Path $root '_local'
New-Item -ItemType Directory -Force $local | Out-Null

# --- locate Visual Studio / Build Tools -------------------------------------
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) { throw "vswhere.exe not found - install Visual Studio 2022 Build Tools" }
$vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vsPath) { throw "No Visual Studio with C++ tools found" }
$msbuild = Join-Path $vsPath 'MSBuild\Current\Bin\MSBuild.exe'
$vcTargetsSrc = Join-Path $vsPath 'MSBuild\Microsoft\VC\v170'

# --- Windows SDK version ----------------------------------------------------
if (-not $Sdk) {
    $inc = "${env:ProgramFiles(x86)}\Windows Kits\10\Include"
    $Sdk = (Get-ChildItem $inc -Directory | Where-Object { $_.Name -like '10.*' } | Sort-Object Name | Select-Object -Last 1).Name
}

# --- NASM -------------------------------------------------------------------
$nasmDir = Join-Path $local 'nasm'
$nasmExe = Get-ChildItem $nasmDir -Recurse -Filter nasm.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $nasmExe) {
    $zip = Get-ChildItem (Join-Path $root 'NASM') -Filter 'nasm-*-win64.zip' | Select-Object -First 1
    Expand-Archive -Path $zip.FullName -DestinationPath $nasmDir -Force
    $nasmExe = Get-ChildItem $nasmDir -Recurse -Filter nasm.exe | Select-Object -First 1
}
$env:NASMPATH = $nasmExe.DirectoryName + '\'

# --- local copy of the VC targets with the NASM build customization ---------
$vcTargets = Join-Path $local 'VCTargets\v170'
if (-not (Test-Path (Join-Path $vcTargets 'BuildCustomizations\nasm.targets'))) {
    New-Item -ItemType Directory -Force $vcTargets | Out-Null
    Copy-Item -Path (Join-Path $vcTargetsSrc '*') -Destination $vcTargets -Recurse -Force
    Copy-Item (Join-Path $root 'NASM\nasm.props'), (Join-Path $root 'NASM\nasm.targets'), (Join-Path $root 'NASM\nasm.xml') `
        -Destination (Join-Path $vcTargets 'BuildCustomizations') -Force
}

# --- CDKDIR and tmp ---------------------------------------------------------
$env:CDKDIR = Join-Path $root 'bin'
$tmp = (Split-Path -Qualifier $root) + '\tmp'
New-Item -ItemType Directory -Force $tmp | Out-Null

# --- build ------------------------------------------------------------------
$sln = Join-Path $root 'ctp2_code\ctp\civctp.sln'
$log = Join-Path $local "build-$Config-$Platform.log"
Write-Host "MSBuild $Config|$Platform toolset=$Toolset sdk=$Sdk"
& $msbuild $sln -t:Build "-p:Configuration=$Config" "-p:Platform=$Platform" "-p:PlatformToolset=$Toolset" `
    "-p:WindowsTargetPlatformVersion=$Sdk" "-p:VCTargetsPath=$vcTargets\" -m -nologo -v:minimal `
    -fl "-flp:LogFile=$log;Verbosity=normal"
if ($LASTEXITCODE -ne 0) { throw "Build failed, see $log" }

# --- ffmpeg.exe for the upscaling script (videos), from the same FFmpeg ------
if ($Platform -eq 'x64') {
    $smp = Join-Path $root 'ctp2_code\libs\FFmpeg-n6.1.2\SMP'
    foreach ($project in @('libpostproc', 'ffmpeg')) {
        & $msbuild (Join-Path $smp "$project.vcxproj") -t:Build -p:Configuration=Release "-p:Platform=$Platform" `
            "-p:PlatformToolset=$Toolset" "-p:WindowsTargetPlatformVersion=$Sdk" "-p:VCTargetsPath=$vcTargets\" `
            -p:BuildProjectReferences=false -m -nologo -v:minimal -fl "-flp:LogFile=$local\build-$project.log;Verbosity=normal" | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Build of $project failed, see $local\build-$project.log" }
    }
    Copy-Item (Join-Path $root 'ctp2_code\msvc\bin\x64\ffmpeg.exe') (Join-Path $root 'ctp2_code\ctp\x64\ffmpeg.exe') -Force
}
Write-Host "OK - see ctp2_code\ctp\$(if ($Platform -eq 'x64') { 'x64\' })ctp2*.exe"
