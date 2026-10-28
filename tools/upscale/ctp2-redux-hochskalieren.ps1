# ctp2-redux: upscales the graphics of your own Call to Power II
# installation for the HD display (sharp scaling 2x to 4x).
#
#   ctp2-redux-hochskalieren.bat               (double-click, in the game folder)
#   powershell -File ctp2-redux-hochskalieren.ps1 [-Install <folder>] [-Scale 3] [-Force]
#
# Reads the images of the game (packages pic565.zfs/pat565.zfs and loose
# .tga files in graphics\pictures and graphics\patterns), enlarges them with
# Real-ESRGAN (model realesr-animevideov3, downloaded once from the official
# GitHub release) and writes them to ctp2_data\redux_hires\<scale>x. The
# original files are not touched; deleting redux_hires undoes everything.
# The game takes the HD version of an image when the folder for its
# scaling exists.
#
# Runs with Windows PowerShell 5.1 (part of Windows 10 and 11); the pixel
# work is done by a small C# class compiled at the start.

param(
    [string]$Install = '',
    [int]$Scale = 0,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$EsrganUrl  = 'https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-windows.zip'
$EsrganExe  = 'realesrgan-ncnn-vulkan.exe'
$Model      = 'realesr-animevideov3'

function Say([string]$text) { Write-Host $text }
function Fail([string]$text) { Write-Host ''; Write-Host "FEHLER: $text" -ForegroundColor Red; exit 1 }

# --- the installation ---------------------------------------------------------
if (-not $Install) { $Install = $PSScriptRoot }
$Install = (Resolve-Path $Install).Path
$data = Join-Path $Install 'ctp2_data'
if (-not (Test-Path (Join-Path $data 'default\graphics\pictures\pic565.zfs'))) {
    Fail "Keine Spieldaten gefunden unter '$data'. Das Skript gehoert in den Spielordner (dort, wo ctp2_data liegt)."
}

# the program folder (GOG: ctp2_program\ctp, working copy: ctp2_code\ctp)
$program = $null
foreach ($p in @('ctp2_program\ctp', 'ctp2_code\ctp')) {
    if (Test-Path (Join-Path $Install $p)) { $program = Join-Path $Install $p; break }
}

# --- the scaling --------------------------------------------------------------
function Get-ProfileScale {
    if (-not $program) { return $null }
    foreach ($f in @('userprofile.txt', 'x64\userprofile.txt')) {
        $path = Join-Path $program $f
        if (Test-Path $path) {
            $line = Select-String -Path $path -Pattern '^DisplayScale=(-?\d+)' | Select-Object -First 1
            if ($line) { return [int]$line.Matches[0].Groups[1].Value }
        }
    }
    return $null
}

function Get-AutoScale {
    # the same rule as the game: the largest factor that leaves 1024 x 768
    $mode = Get-CimInstance Win32_VideoController | Where-Object { $_.CurrentHorizontalResolution } | Select-Object -First 1
    if (-not $mode) { return 1 }
    $w = [int]$mode.CurrentHorizontalResolution; $h = [int]$mode.CurrentVerticalResolution
    $s = 1
    while ($s -lt 4 -and [math]::Floor($w / ($s + 1)) -ge 1024 -and [math]::Floor($h / ($s + 1)) -ge 768) { $s++ }
    return $s
}

if ($Scale -le 0) {
    $profileScale = Get-ProfileScale
    if ($null -eq $profileScale -or $profileScale -eq 0) {
        $Scale = Get-AutoScale
        Say "Skalierung: automatisch -> $Scale-fach"
    } elseif ($profileScale -lt 0) {
        Fail 'Die Skalierung ist im Spiel ausgeschaltet (Optionen -> Grafik). Stelle sie ein oder starte das Skript mit -Scale 2, 3 oder 4.'
    } else {
        $Scale = $profileScale
        Say "Skalierung laut Spielprofil: $Scale-fach"
    }
}
if ($Scale -lt 2 -or $Scale -gt 4) {
    Say "Bei $Scale-fach gibt es nichts hochzuskalieren (moeglich: 2, 3, 4)."
    exit 0
}

# --- the language folder (localized images override default ones) -----------
$language = 'english'
if ($program) {
    foreach ($f in @('civpaths.txt', 'x64\civpaths.txt')) {
        $path = Join-Path $program $f
        if (Test-Path $path) {
            $lines = @(Get-Content $path | Where-Object { $_.Trim() })
            if ($lines.Count -ge 4) { $language = $lines[3].Trim() }
            break
        }
    }
}

# --- folders --------------------------------------------------------------------
$hires   = Join-Path $data 'redux_hires'
$target  = Join-Path $hires "$($Scale)x"
$tools   = Join-Path $hires '_werkzeug'
$work    = Join-Path $hires '_arbeit'
$inDir   = Join-Path $work 'ein'
$outDir  = Join-Path $work 'aus'
$origDir = Join-Path $work 'original'
foreach ($d in @($target, $tools, $inDir, $outDir, $origDir)) { New-Item -ItemType Directory -Force $d | Out-Null }

# --- Real-ESRGAN, once ----------------------------------------------------------
$esrgan = Get-ChildItem -Path $tools -Recurse -Filter $EsrganExe -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $esrgan) {
    Say 'Lade Real-ESRGAN (einmalig, ca. 45 MB) von github.com/xinntao/Real-ESRGAN ...'
    $zip = Join-Path $tools 'realesrgan.zip'
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $EsrganUrl -OutFile $zip -UseBasicParsing
    } catch {
        Fail "Download fehlgeschlagen: $($_.Exception.Message)"
    }
    Expand-Archive -Path $zip -DestinationPath (Join-Path $tools 'realesrgan') -Force
    Remove-Item $zip
    $esrgan = Get-ChildItem -Path $tools -Recurse -Filter $EsrganExe | Select-Object -First 1
    if (-not $esrgan) { Fail 'Real-ESRGAN wurde nicht gefunden.' }
}

# --- the pixel work (C#) --------------------------------------------------------
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class Ctp2Assets
{
    // the transparent color: magenta, black for the mouse cursors
    public static bool BlackKey = false;
    static bool IsKey(int r, int g, int b)
    {
        if (BlackKey) return r == 0 && g == 0 && b == 0;
        return r >= 248 && g <= 7 && b >= 248;
    }

    // --- reading ---------------------------------------------------------------

    // the .rim entries of a .zfs package: name -> data
    public static Dictionary<string, byte[]> ReadZfs(string path)
    {
        byte[] data = File.ReadAllBytes(path);
        int nameLen  = BitConverter.ToInt32(data, 8);
        int perTable = BitConverter.ToInt32(data, 12);
        int pos      = BitConverter.ToInt32(data, 24);
        int entrySize = nameLen + 20;
        Dictionary<string, byte[]> result = new Dictionary<string, byte[]>(StringComparer.OrdinalIgnoreCase);
        while (pos != 0)
        {
            int next = BitConverter.ToInt32(data, pos);
            int p = pos + 4;
            for (int i = 0; i < perTable; i++, p += entrySize)
            {
                int end = p;
                while (end < p + nameLen && data[end] != 0) end++;
                string name = System.Text.Encoding.GetEncoding(28591).GetString(data, p, end - p);
                int offset = BitConverter.ToInt32(data, p + nameLen);
                int size   = BitConverter.ToInt32(data, p + nameLen + 8);
                int flags  = BitConverter.ToInt32(data, p + nameLen + 16);
                if (name.Length == 0 || (flags & 1) != 0) continue;
                byte[] entry = new byte[size];
                Buffer.BlockCopy(data, offset, entry, 0, size);
                result[name] = entry;
            }
            pos = next;
        }
        return result;
    }

    // RGB pixels (r,g,b per pixel, top row first) of a RIM (16 bit 565 or 555)
    public static byte[] DecodeRim(byte[] rim, out int width, out int height)
    {
        width  = BitConverter.ToUInt16(rim, 8);
        height = BitConverter.ToUInt16(rim, 10);
        int pitch = BitConverter.ToUInt16(rim, 12);
        bool is565 = (BitConverter.ToUInt16(rim, 14) & 1) != 0;
        byte[] rgb = new byte[width * height * 3];
        for (int y = 0; y < height; y++)
            for (int x = 0; x < width; x++)
                Expand(BitConverter.ToUInt16(rim, 16 + y * pitch + x * 2), is565, rgb, (y * width + x) * 3);
        return rgb;
    }

    // RGB pixels of a 16 bit Targa (555), uncompressed
    public static byte[] DecodeTga(byte[] tga, out int width, out int height)
    {
        int idLength = tga[0];
        int type = tga[2];
        width  = BitConverter.ToUInt16(tga, 12);
        height = BitConverter.ToUInt16(tga, 14);
        int depth = tga[16];
        bool topDown = (tga[17] & 0x20) != 0;
        if (type != 2 || depth != 16) throw new Exception("nur unkomprimierte 16-Bit-TGAs");
        int start = 18 + idLength;
        byte[] rgb = new byte[width * height * 3];
        for (int row = 0; row < height; row++)
        {
            int y = topDown ? row : height - 1 - row;
            for (int x = 0; x < width; x++)
                Expand(BitConverter.ToUInt16(tga, start + (row * width + x) * 2), false, rgb, (y * width + x) * 3);
        }
        return rgb;
    }

    static void Expand(int p, bool is565, byte[] rgb, int i)
    {
        int r, g, b;
        if (is565) { r = (p >> 11) & 31; g = (p >> 5) & 63; b = p & 31; g = (g << 2) | (g >> 4); }
        else       { r = (p >> 10) & 31; g = (p >> 5) & 31; b = p & 31; g = (g << 3) | (g >> 2); }
        rgb[i]     = (byte)((r << 3) | (r >> 2));
        rgb[i + 1] = (byte)g;
        rgb[i + 2] = (byte)((b << 3) | (b >> 2));
    }

    // --- before the upscaling --------------------------------------------------

    // the transparent areas filled with the neighbouring colors, so the
    // upscaler does not blur magenta into the edges
    public static byte[] FillTransparent(byte[] rgb, int width, int height)
    {
        byte[] img = (byte[])rgb.Clone();
        bool[] key = new bool[width * height];
        int open = 0;
        for (int i = 0; i < key.Length; i++)
            if (IsKey(img[i * 3], img[i * 3 + 1], img[i * 3 + 2])) { key[i] = true; open++; }
        if (open == 0 || open == key.Length) return img;

        for (int pass = 0; pass < 64 && open > 0; pass++)
        {
            bool[] filled = new bool[key.Length];
            for (int y = 0; y < height; y++)
                for (int x = 0; x < width; x++)
                {
                    int i = y * width + x;
                    if (!key[i]) continue;
                    int r = 0, g = 0, b = 0, n = 0;
                    for (int dy = -1; dy <= 1; dy++)
                        for (int dx = -1; dx <= 1; dx++)
                        {
                            int xx = x + dx, yy = y + dy;
                            if (xx < 0 || yy < 0 || xx >= width || yy >= height) continue;
                            int j = yy * width + xx;
                            if (key[j]) continue;
                            r += img[j * 3]; g += img[j * 3 + 1]; b += img[j * 3 + 2]; n++;
                        }
                    if (n == 0) continue;
                    img[i * 3] = (byte)(r / n); img[i * 3 + 1] = (byte)(g / n); img[i * 3 + 2] = (byte)(b / n);
                    filled[i] = true;
                }
            for (int i = 0; i < key.Length; i++) if (filled[i]) { key[i] = false; open--; }
        }
        return img;
    }

    public static void SavePng(byte[] rgb, int width, int height, string path)
    {
        using (Bitmap bmp = new Bitmap(width, height, PixelFormat.Format24bppRgb))
        {
            BitmapData bd = bmp.LockBits(new Rectangle(0, 0, width, height), ImageLockMode.WriteOnly, PixelFormat.Format24bppRgb);
            byte[] row = new byte[bd.Stride];
            for (int y = 0; y < height; y++)
            {
                for (int x = 0; x < width; x++)
                {
                    int i = (y * width + x) * 3;
                    row[x * 3] = rgb[i + 2]; row[x * 3 + 1] = rgb[i + 1]; row[x * 3 + 2] = rgb[i];
                }
                Marshal.Copy(row, 0, new IntPtr(bd.Scan0.ToInt64() + (long)y * bd.Stride), bd.Stride);
            }
            bmp.UnlockBits(bd);
            bmp.Save(path, ImageFormat.Png);
        }
    }

    public const string MaskSuffix = "__maske";

    // the original (with the transparent areas) and the image for the
    // upscaler; with transparent areas also their mask (white = visible),
    // which goes through the upscaler too: it turns the pixel steps of the
    // outlines into clean lines
    public static void Export(byte[] rgb, int width, int height, string name, string inDir, string origDir)
    {
        SavePng(rgb, width, height, Path.Combine(origDir, name + ".png"));
        SavePng(FillTransparent(rgb, width, height), width, height, Path.Combine(inDir, name + ".png"));

        byte[] mask = new byte[rgb.Length];
        bool anyKey = false, anyVisible = false;
        for (int i = 0; i < width * height; i++)
        {
            bool key = IsKey(rgb[i * 3], rgb[i * 3 + 1], rgb[i * 3 + 2]);
            byte v = key ? (byte)0 : (byte)255;
            mask[i * 3] = v; mask[i * 3 + 1] = v; mask[i * 3 + 2] = v;
            if (key) anyKey = true; else anyVisible = true;
        }
        if (anyKey && anyVisible)
            SavePng(mask, width, height, Path.Combine(inDir, name + MaskSuffix + ".png"));
    }

    // --- after the upscaling ---------------------------------------------------

    static byte[] LoadPng(string path, out int width, out int height)
    {
        using (Bitmap src = new Bitmap(path))
        using (Bitmap bmp = src.Clone(new Rectangle(0, 0, src.Width, src.Height), PixelFormat.Format24bppRgb))
        {
            width = bmp.Width; height = bmp.Height;
            BitmapData bd = bmp.LockBits(new Rectangle(0, 0, width, height), ImageLockMode.ReadOnly, PixelFormat.Format24bppRgb);
            byte[] rgb = new byte[width * height * 3];
            byte[] row = new byte[bd.Stride];
            for (int y = 0; y < height; y++)
            {
                Marshal.Copy(new IntPtr(bd.Scan0.ToInt64() + (long)y * bd.Stride), row, 0, bd.Stride);
                for (int x = 0; x < width; x++)
                {
                    int i = (y * width + x) * 3;
                    rgb[i] = row[x * 3 + 2]; rgb[i + 1] = row[x * 3 + 1]; rgb[i + 2] = row[x * 3];
                }
            }
            bmp.UnlockBits(bd);
            return rgb;
        }
    }

    // Catmull-Rom weight
    static double Cubic(double t)
    {
        t = Math.Abs(t);
        if (t < 1) return 1.5 * t * t * t - 2.5 * t * t + 1;
        if (t < 2) return -0.5 * t * t * t + 2.5 * t * t - 4 * t + 2;
        return 0;
    }

    // the transparent areas at the new size: the mask of the original sampled
    // smoothly and cut at one half, so round edges follow the shape instead
    // of the pixel steps of the original
    static bool[] ScaleMask(byte[] orig, int ow, int oh, int scale)
    {
        double[] opaque = new double[ow * oh];
        for (int i = 0; i < opaque.Length; i++)
            opaque[i] = IsKey(orig[i * 3], orig[i * 3 + 1], orig[i * 3 + 2]) ? 0 : 1;

        int tw = ow * scale, th = oh * scale;
        bool[] key = new bool[tw * th];
        for (int y = 0; y < th; y++)
        {
            double sy = (y + 0.5) / scale - 0.5;
            int iy = (int)Math.Floor(sy);
            for (int x = 0; x < tw; x++)
            {
                double sx = (x + 0.5) / scale - 0.5;
                int ix = (int)Math.Floor(sx);
                double sum = 0, weight = 0;
                for (int dy = -1; dy <= 2; dy++)
                {
                    int yy = Math.Min(Math.Max(iy + dy, 0), oh - 1);
                    double wy = Cubic(sy - (iy + dy));
                    for (int dx = -1; dx <= 2; dx++)
                    {
                        int xx = Math.Min(Math.Max(ix + dx, 0), ow - 1);
                        double wgt = wy * Cubic(sx - (ix + dx));
                        sum += wgt * opaque[yy * ow + xx];
                        weight += wgt;
                    }
                }
                key[y * tw + x] = sum / weight < 0.5;
            }
        }
        return key;
    }

    // the upscaled image with the transparent areas of the original as a
    // 16 bit Targa (555) for the game
    public static void Import(string upscaled, string original, int scale, string tgaPath)
    {
        int w, h, ow, oh;
        byte[] up = LoadPng(upscaled, out w, out h);
        byte[] orig = LoadPng(original, out ow, out oh);
        int tw = ow * scale, th = oh * scale;
        if (w != tw || h != th) throw new Exception("unerwartete Groesse " + w + "x" + h);

        // the transparent areas: the upscaled mask cut at one half, else
        // the mask of the original sampled smoothly
        bool[] key;
        string maskPath = Path.Combine(Path.GetDirectoryName(upscaled),
                                       Path.GetFileNameWithoutExtension(upscaled) + MaskSuffix + ".png");
        int mw = 0, mh = 0;
        byte[] mask = File.Exists(maskPath) ? LoadPng(maskPath, out mw, out mh) : null;
        if (mask != null && mw == tw && mh == th)
        {
            key = new bool[tw * th];
            for (int i = 0; i < key.Length; i++) key[i] = mask[i * 3 + 1] < 128;
        }
        else
            key = ScaleMask(orig, ow, oh, scale);

        byte[] tga = new byte[18 + tw * th * 2];
        tga[2] = 2;
        BitConverter.GetBytes((ushort)tw).CopyTo(tga, 12);
        BitConverter.GetBytes((ushort)th).CopyTo(tga, 14);
        tga[16] = 16;
        tga[17] = 0;      // bottom row first, as the game reads them
        for (int y = 0; y < th; y++)
            for (int x = 0; x < tw; x++)
            {
                int p;
                if (key[y * tw + x])
                    p = BlackKey ? 0 : (31 << 10) | 31;
                else
                {
                    int i = (y * tw + x) * 3;
                    p = ((up[i] >> 3) << 10) | ((up[i + 1] >> 3) << 5) | (up[i + 2] >> 3);
                    // keep upscaled pixels from turning into the transparent color
                    if (!BlackKey && p == ((31 << 10) | 31)) p = (31 << 10) | 30;
                    if (BlackKey && p == 0) p = (1 << 10) | (1 << 5) | 1;
                }
                BitConverter.GetBytes((ushort)p).CopyTo(tga, 18 + ((th - 1 - y) * tw + x) * 2);
            }
        File.WriteAllBytes(tgaPath, tga);
    }
}
'@

# --- collect the images (later sources override earlier ones, like the game) --
Say "Spielordner: $Install"
Say "Sprache: $language, Ziel: $target"
$rims  = @{}
$loose = @{}
foreach ($dir in @('default', $language)) {
    foreach ($kind in @(@{ folder = 'pictures'; zfs = 'pic565.zfs' }, @{ folder = 'patterns'; zfs = 'pat565.zfs' })) {
        $base = Join-Path $data "$dir\graphics\$($kind.folder)"
        $zfs = Join-Path $base $kind.zfs
        if (Test-Path $zfs) {
            $entries = [Ctp2Assets]::ReadZfs($zfs)
            foreach ($name in $entries.Keys) {
                if ($name -like '*.rim') { $rims[[IO.Path]::GetFileNameWithoutExtension($name).ToLower()] = $entries[$name] }
            }
        }
        if (Test-Path $base) {
            foreach ($f in Get-ChildItem -Path $base -Filter '*.tga') {
                $loose[$f.BaseName.ToLower()] = $f.FullName
            }
        }
    }
}
# a loose .tga overrides the picture of the package; where both exist the
# package version is kept as <name>_rim (the classic interface asks for
# name.rim to get the original picture, see LoadHD in the game)
$sources = [ordered]@{}
foreach ($name in $rims.Keys) {
    $key = $name
    if ($loose.ContainsKey($name)) { $key = $name + '_rim' }
    $sources[$key] = @{ rim = $rims[$name] }
}
foreach ($name in $loose.Keys) { $sources[$name] = @{ tga = $loose[$name] } }
# the mouse cursors (black is their transparent color)
foreach ($dir in @('default', $language)) {
    $base = Join-Path $data "$dir\graphics\cursors"
    if (Test-Path $base) {
        foreach ($f in Get-ChildItem -Path $base -Filter '*.tga') { $sources[$f.BaseName.ToLower()] = @{ tga = $f.FullName; black = $true } }
    }
}
Say "Bilder gefunden: $($sources.Count)"

# --- export (only what is not done yet) -----------------------------------------
$todo = @()
foreach ($name in $sources.Keys) {
    if (-not $Force -and (Test-Path (Join-Path $target "$name.tga"))) { continue }
    $src = $sources[$name]
    $w = 0; $h = 0
    try {
        if ($src.rim) { $rgb = [Ctp2Assets]::DecodeRim($src.rim, [ref]$w, [ref]$h) }
        else          { $rgb = [Ctp2Assets]::DecodeTga([IO.File]::ReadAllBytes($src.tga), [ref]$w, [ref]$h) }
        if ($w -lt 1 -or $h -lt 1) { continue }
        [Ctp2Assets]::BlackKey = [bool]$src.black
        [Ctp2Assets]::Export($rgb, $w, $h, $name, $inDir, $origDir)
        $todo += $name
    } catch {
        Say "  uebersprungen: $name ($($_.Exception.Message))"
    }
}
if ($todo.Count -eq 0) {
    Say 'Alles schon hochskaliert. (Mit -Force neu erzeugen.)'
    Remove-Item -Recurse -Force $work
    exit 0
}
Say "Hochzuskalieren: $($todo.Count) Bilder"

# --- upscale --------------------------------------------------------------------
Say "Skaliere mit Real-ESRGAN ($Model, $Scale-fach) ... das kann je nach Grafikkarte einige Minuten dauern."
function Invoke-Esrgan([string[]]$extra) {
    # its progress goes to stderr; a log keeps PowerShell from taking it as an error
    $quoted = @('-i', "`"$inDir`"", '-o', "`"$outDir`"", '-n', $Model, '-s', "$Scale", '-f', 'png') + $extra
    $process = Start-Process -FilePath $esrgan.FullName -ArgumentList $quoted -NoNewWindow -Wait -PassThru `
        -RedirectStandardError (Join-Path $work 'esrgan.log') -RedirectStandardOutput (Join-Path $work 'esrgan-out.log')
    return $process.ExitCode
}
Invoke-Esrgan @() | Out-Null
$done = @(Get-ChildItem -Path $outDir -Filter '*.png').Count
if ($done -lt $todo.Count) {
    Say 'Mit der Grafikkarte ging es nicht, versuche es mit dem Prozessor (langsam) ...'
    Invoke-Esrgan @('-g', '-1') | Out-Null
}

# --- import ---------------------------------------------------------------------
$ok = 0
foreach ($name in $todo) {
    $up = Join-Path $outDir "$name.png"
    if (-not (Test-Path $up)) { Say "  fehlt: $name"; continue }
    try {
        [Ctp2Assets]::BlackKey = [bool]$sources[$name].black
        [Ctp2Assets]::Import($up, (Join-Path $origDir "$name.png"), $Scale, (Join-Path $target "$name.tga"))
        $ok++
    } catch {
        Say "  fehlgeschlagen: $name ($($_.Exception.Message))"
    }
}
Remove-Item -Recurse -Force $work

Say ''
Say "Fertig: $ok von $($todo.Count) Bildern in $target."
Say 'Die HD-Bilder gelten fuer die eingestellte Skalierung. Rueckgaengig: den Ordner redux_hires loeschen.'
