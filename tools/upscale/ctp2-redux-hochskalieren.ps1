# ctp2-redux: upscales the graphics of your own Call to Power II
# installation for the HD display (sharp scaling 2x to 4x).
#
#   ctp2-redux-hochskalieren.bat               (double-click: setup window,
#                                               ctp2-redux-hd-setup.ps1)
#   powershell -File ctp2-redux-hochskalieren.ps1 [-Install <folder>] [-Scale 3] [-Force]
#                                               [-NoImages] [-NoVideos] [-NoTerrain] [-Status]
#                                               [-Language de|en]
#
# -Status only counts what is done (lines "##STATUS bilder|videos <done> <total>")
# for the setup window, which runs the work in steps.
#
# Reads the images of the game (packages pic565.zfs/pat565.zfs and loose
# .tga files in graphics\pictures and graphics\patterns), enlarges them with
# Real-ESRGAN (model realesr-animevideov3, downloaded once from the official
# GitHub release) and writes them to ctp2_data\redux_hires\<scale>x. The
# original files are not touched; deleting redux_hires undoes everything.
# The game takes the HD version of an image when the folder for its
# scaling exists.
#
# The videos (videos\*.avi) go the same way frame by frame and become
# redux_hires\<scale>x\videos\<name>.mkv (H.264 by Windows Media Foundation,
# the sound stays). For that the script needs ffmpeg.exe next to it, built
# from the FFmpeg sources of the game (LGPL).
#
# Runs with Windows PowerShell 5.1 (part of Windows 10 and 11); the pixel
# work is done by a small C# class compiled at the start.

param(
    [string]$Install = '',
    [int]$Scale = 0,
    [switch]$Force,
    [switch]$NoImages,
    [switch]$NoVideos,
    [switch]$NoTerrain,
    [string]$TerrainModel = 'realesrgan-x4plus',   # terrain: photo model (2026-10-28 comparison)
    [switch]$Status,
    [string]$Language = ''
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$EsrganUrl  = 'https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-windows.zip'
$EsrganExe  = 'realesrgan-ncnn-vulkan.exe'
$Model      = 'realesr-animevideov3'

# messages in German or English (default: the language of Windows)
if (-not $Language) { $Language = if ([Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'de') { 'de' } else { 'en' } }
function L([string]$de, [string]$en) { if ($Language -eq 'en') { return $en } return $de }
function Say([string]$text) { Write-Host $text }
# for the setup window (ctp2-redux-hd-setup.ps1): part, done, total
function Progress([string]$part, [int]$done, [int]$total) { Write-Host "##FORTSCHRITT $part $done $total" }
function Fail([string]$text) { Write-Host ''; Write-Host "$(L 'FEHLER' 'ERROR'): $text" -ForegroundColor Red; exit 1 }

# --- the installation ---------------------------------------------------------
if (-not $Install) { $Install = $PSScriptRoot }
$Install = (Resolve-Path $Install).Path
$data = Join-Path $Install 'ctp2_data'
if (-not (Test-Path (Join-Path $data 'default\graphics\pictures\pic565.zfs'))) {
    Fail (L "Keine Spieldaten gefunden unter '$data'. Das Skript gehoert in den Spielordner (dort, wo ctp2_data liegt)." "No game data found in '$data'. The script belongs in the game folder (where ctp2_data is).")
}

# the program folder (GOG: ctp2_program\ctp, working copy: ctp2_code\ctp)
$program = $null
foreach ($p in @('ctp2_program\ctp', 'ctp2_code\ctp')) {
    if (Test-Path (Join-Path $Install $p)) { $program = Join-Path $Install $p; break }
}
# its files (profile, paths) count first where the game runs (x64 in a build)
$programFirst = ''
if ($program -and (Test-Path (Join-Path $program 'x64\ctp2.exe'))) { $programFirst = 'x64\' }
function ProgramFile([string]$name) {
    if (-not $program) { return $null }
    foreach ($sub in @($programFirst, 'x64\', '')) {
        $path = Join-Path $program ($sub + $name)
        if (Test-Path $path) { return $path }
    }
    return $null
}

# --- the scaling --------------------------------------------------------------
function Get-ProfileScale {
    if (-not $program) { return $null }
    $path = ProgramFile 'userprofile.txt'
    if ($path) {
        $line = Select-String -Path $path -Pattern '^DisplayScale=(-?\d+)' | Select-Object -First 1
        if ($line) { return [int]$line.Matches[0].Groups[1].Value }
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
        Say (L "Skalierung: automatisch -> $Scale-fach" "Scaling: automatic -> $($Scale)x")
    } elseif ($profileScale -lt 0) {
        Fail (L 'Die Skalierung ist im Spiel ausgeschaltet (Optionen -> Grafik). Stelle sie ein oder starte das Skript mit -Scale 2, 3 oder 4.' "Scaling is off in the game (Options -> Graphics). Turn it on or start the script with -Scale 2, 3 or 4.")
    } else {
        $Scale = $profileScale
        Say (L "Skalierung laut Spielprofil: $Scale-fach" "Scaling from the game profile: $($Scale)x")
    }
}
if ($Scale -lt 2 -or $Scale -gt 4) {
    Say (L "Bei $Scale-fach gibt es nichts hochzuskalieren (moeglich: 2, 3, 4)." "Nothing to upscale at $($Scale)x (possible: 2, 3, 4).")
    exit 0
}

# --- the language folder (localized images override default ones) -----------
# like the game: LanguageDirectory of the profile, else the 4th line of civpaths
$gameLanguage = 'english'
$path = ProgramFile 'civpaths.txt'
if ($path) {
    $lines = @(Get-Content $path | Where-Object { $_.Trim() })
    if ($lines.Count -ge 4) { $gameLanguage = $lines[3].Trim() }
}
$path = ProgramFile 'userprofile.txt'
if ($path) {
    $line = Select-String -Path $path -Pattern '^LanguageDirectory=(\S+)' | Select-Object -First 1
    if ($line) { $gameLanguage = $line.Matches[0].Groups[1].Value }
}

# --- folders --------------------------------------------------------------------
$hires   = Join-Path $data 'redux_hires'
$target  = Join-Path $hires "$($Scale)x"
$tools   = Join-Path $hires '_werkzeug'
$work    = Join-Path $hires '_arbeit'
$inDir   = Join-Path $work 'ein'
$outDir  = Join-Path $work 'aus'
$origDir = Join-Path $work 'original'
foreach ($d in @($target, $tools, $inDir, $outDir, $origDir)) {
    if ($Status -and $d -eq $target) { continue }
    New-Item -ItemType Directory -Force $d | Out-Null
}
# images the game has but that cannot be read count as done
$skippedList = Join-Path $target '_uebersprungen.txt'
# the language the images and videos were made for: localized ones differ,
# so after a change of language a part counts as not done
function MadeForOtherLanguage([string]$part) {
    $file = Join-Path $target "_sprache_$part.txt"
    if (-not (Test-Path $file)) { return $false }
    return ((Get-Content $file -TotalCount 1).Trim() -ne $gameLanguage)
}
function MarkLanguage([string]$part) {
    Set-Content -Path (Join-Path $target "_sprache_$part.txt") -Value $gameLanguage
}
$redoImages = $Force -or (MadeForOtherLanguage 'bilder')
$redoVideos = $Force -or (MadeForOtherLanguage 'videos')
$skipped = @{}
if (Test-Path $skippedList) { foreach ($n in Get-Content $skippedList) { $skipped[$n] = $true } }

# --- Real-ESRGAN, once ----------------------------------------------------------
$esrgan = Get-ChildItem -Path $tools -Recurse -Filter $EsrganExe -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $esrgan -and -not $Status) {
    Say (L 'Lade Real-ESRGAN (einmalig, ca. 45 MB) von github.com/xinntao/Real-ESRGAN ...' "Downloading Real-ESRGAN (once, about 45 MB) from github.com/xinntao/Real-ESRGAN ...")
    $zip = Join-Path $tools 'realesrgan.zip'
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $EsrganUrl -OutFile $zip -UseBasicParsing
    } catch {
        Fail (L "Download fehlgeschlagen: $($_.Exception.Message)" "Download failed: $($_.Exception.Message)")
    }
    Expand-Archive -Path $zip -DestinationPath (Join-Path $tools 'realesrgan') -Force
    Remove-Item $zip
    $esrgan = Get-ChildItem -Path $tools -Recurse -Filter $EsrganExe | Select-Object -First 1
    if (-not $esrgan) { Fail (L 'Real-ESRGAN wurde nicht gefunden.' "Real-ESRGAN was not found.") }
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

    public static byte[] LoadPng(string path, out int width, out int height)
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

// The terrain of the map (gtset565.til): base tiles, transitions, hats,
// rivers and improvements, exported for the upscaler and taken back into
// the in-memory format of the game (see TileSet::ScaleUp).
public static class Ctp2Tiles
{
    const int W = 94, H = 48, GRID = 72;
    const int Diamond = 2304;   // pixels of the tile diamond
    const int Transitions = 4;
    // kinds of the pixels of an overlay
    const byte Clear = 0, Copy = 1, Shadow = 2, Colorize = 3;

    class Overlay { public int Start, End; public byte[] Kind; public ushort[] Color; }

    static byte[] data;
    static List<int> baseNums = new List<int>();
    static Dictionary<int, ushort[]> bases = new Dictionary<int, ushort[]>();
    static List<int[]> transKeys = new List<int[]>();          // from, to, k
    static List<ushort[]> transData = new List<ushort[]>();
    static Dictionary<string, Overlay> overlays = new Dictionary<string, Overlay>();
    static int[][] layout = new int[Transitions][];            // stream index per diamond pixel

    static int Start(int y) { return y < 24 ? 2 * (23 - y) : 2 * (y - 24); }

    static ushort U16(int p) { return BitConverter.ToUInt16(data, p); }

    static ushort[] Words(int p, int count)
    {
        ushort[] w = new ushort[count];
        for (int i = 0; i < count; i++) w[i] = U16(p + 2 * i);
        return w;
    }

    // the kinds and colors of a tile image (RLE as in tileutils_EncodeTile16)
    static Overlay DecodeOverlay(int p)
    {
        Overlay o = new Overlay();
        o.Start = U16(p); o.End = U16(p + 2);
        int rows = o.End - o.Start + 1;
        int table = p + 4, rowsData = table + 2 * rows;
        o.Kind = new byte[(o.End + 1) * W];
        o.Color = new ushort[(o.End + 1) * W];
        for (int j = 0; j < rows; j++)
        {
            ushort offset = U16(table + 2 * j);
            if (offset == 0xFFFF) continue;
            int q = rowsData + 2 * offset, x = 0, y = o.Start + j;
            ushort tag;
            do
            {
                tag = U16(q); q += 2;
                int kind = (tag >> 8) & 0xF, len = tag & 0xFF;
                for (int i = 0; i < len; i++, x++)
                {
                    if (x >= W) { if (kind == 0xC) q += 2; continue; }
                    int at = y * W + x;
                    if (kind == 0xC) { o.Kind[at] = Copy; o.Color[at] = U16(q); q += 2; }
                    else if (kind == 0xD) o.Kind[at] = Shadow;
                    else if (kind == 0xB) o.Kind[at] = Colorize;
                }
            } while ((tag & 0xF000) == 0);
        }
        return o;
    }

    public static int Load(string path)
    {
        data = File.ReadAllBytes(path);
        int p = 0;
        int transforms = U16(p); p += 2 + transforms * 15 * 2;
        int tcount = BitConverter.ToInt32(data, p); int tsize = BitConverter.ToInt32(data, p + 4); p += 8;
        for (int i = 0; i < tcount; i++)
        {
            int from = (short)U16(p), to = (short)U16(p + 2); p += 4;
            for (int k = 0; k < Transitions; k++, p += tsize)
            {
                transKeys.Add(new int[] { from, to, k });
                transData.Add(Words(p, tsize / 2));
            }
        }
        int nbase = BitConverter.ToInt32(data, p); p += 4;
        for (int i = 0; i < nbase; i++)
        {
            int num = U16(p); int tlen = U16(p + 4); p += 6;
            if (tlen == 2 * Diamond) { baseNums.Add(num); bases[num] = Words(p, tlen / 2); }
            p += tlen;
            int hlen = U16(p); p += 2;
            if (hlen > 0) overlays["hat_" + num] = DecodeOverlay(p);
            p += hlen;
        }
        int rivers = U16(p); p += 2;
        for (int i = 0; i < rivers; i++)
        {
            p += 20;
            int len = BitConverter.ToInt32(data, p); p += 4;
            if (len > 0) overlays["riv_" + i] = DecodeOverlay(p);
            p += len;
        }
        int improvements = U16(p); p += 2;
        for (int i = 0; i < improvements; i++)
        {
            int num = U16(p); int len = BitConverter.ToInt32(data, p + 2); p += 6;
            if (len > 0) overlays["imp_" + num] = DecodeOverlay(p);
            p += len;
        }

        // the stream layout of each transition: the same 352 pixels in every tile
        foreach (int num in baseNums)
        {
            ushort[] tile = bases[num];
            for (int k = 0; k < Transitions; k++)
            {
                if (layout[k] != null) continue;
                int[] index = new int[W * H];
                int n = 0, i = 0;
                for (int y = 0; y < H; y++)
                    for (int x = 0; x < W; x++)
                    {
                        index[y * W + x] = -1;
                        bool inside = x >= Start(y) && x < W - Start(y);
                        if (inside && tile[i++] == k) index[y * W + x] = n++;
                    }
                if (n >= 100) layout[k] = index;
            }
        }
        return baseNums.Count + transData.Count + overlays.Count;
    }

    static readonly byte[] Magenta = { 255, 0, 255 };

    static void Put(byte[] rgb, int at, ushort color)
    {
        int r = (color >> 11) & 31, g = (color >> 5) & 63, b = color & 31;
        rgb[at * 3] = (byte)((r << 3) | (r >> 2));
        rgb[at * 3 + 1] = (byte)((g << 2) | (g >> 4));
        rgb[at * 3 + 2] = (byte)((b << 3) | (b >> 2));
    }

    static void Fill(byte[] rgb)
    {
        for (int i = 0; i < rgb.Length; i += 3) { rgb[i] = 255; rgb[i + 1] = 0; rgb[i + 2] = 255; }
    }

    static void SaveFilled(byte[] rgb, int w, int h, string path)
    {
        Ctp2Assets.BlackKey = false;
        Ctp2Assets.SavePng(Ctp2Assets.FillTransparent(rgb, w, h), w, h, path);
    }

    // the images for the upscaler (unknown pixels filled from the neighbours,
    // so the diamonds get no dark fringes)
    public static void Export(string dir)
    {
        foreach (int num in baseNums)
        {
            byte[] rgb = new byte[W * H * 3]; Fill(rgb);
            ushort[] tile = bases[num];
            int i = 0;
            for (int y = 0; y < H; y++)
                for (int x = Start(y); x < W - Start(y); x++, i++)
                    if (tile[i] >= 4) Put(rgb, y * W + x, tile[i]);
            SaveFilled(rgb, W, H, Path.Combine(dir, "t_base_" + num + ".png"));
        }
        for (int t = 0; t < transData.Count; t++)
        {
            int k = transKeys[t][2];
            if (layout[k] == null) continue;
            byte[] rgb = new byte[W * H * 3]; Fill(rgb);
            ushort[] stream = transData[t];
            for (int at = 0; at < W * H; at++)
                if (layout[k][at] >= 0 && layout[k][at] < stream.Length) Put(rgb, at, stream[layout[k][at]]);
            SaveFilled(rgb, W, H, Path.Combine(dir, "t_tr_" + t + ".png"));
        }
        foreach (KeyValuePair<string, Overlay> e in overlays)
        {
            Overlay o = e.Value;
            int h = o.End + 1;
            byte[] rgb = new byte[W * h * 3]; Fill(rgb);
            byte[] mask = new byte[W * h * 3];
            bool any = false;
            for (int at = 0; at < W * h; at++)
                if (o.Kind[at] == Copy) { Put(rgb, at, o.Color[at]); mask[at * 3] = mask[at * 3 + 1] = mask[at * 3 + 2] = 255; any = true; }
            if (!any) continue;
            SaveFilled(rgb, W, h, Path.Combine(dir, "t_" + e.Key + ".png"));
            Ctp2Assets.SavePng(mask, W, h, Path.Combine(dir, "t_" + e.Key + Ctp2Assets.MaskSuffix + ".png"));
        }
    }

    static ushort To565(byte[] rgb, int at)
    {
        int r = rgb[at * 3] >> 3, g = rgb[at * 3 + 1] >> 2, b = rgb[at * 3 + 2] >> 3;
        return (ushort)((r << 11) | (g << 5) | b);
    }

    static byte[] Upscaled(string dir, string name, int w, int h)
    {
        string path = Path.Combine(dir, name + ".png");
        if (!File.Exists(path)) return null;
        int uw, uh;
        byte[] rgb = Ctp2Assets.LoadPng(path, out uw, out uh);
        return (uw == w && uh == h) ? rgb : null;
    }

    static List<byte[]> records = new List<byte[]>();

    static void Record(int type, int k, int a, int b, List<ushort> words)
    {
        byte[] r = new byte[10 + words.Count * 2];
        r[0] = (byte)type; r[1] = (byte)k;
        BitConverter.GetBytes((ushort)a).CopyTo(r, 2);
        BitConverter.GetBytes((ushort)b).CopyTo(r, 4);
        BitConverter.GetBytes(words.Count).CopyTo(r, 6);
        for (int i = 0; i < words.Count; i++) BitConverter.GetBytes(words[i]).CopyTo(r, 10 + 2 * i);
        records.Add(r);
    }

    // a tile image in the RLE of the game: rows encoded once each, runs of
    // at most 255, the last one marked as end of line; NULL when too large
    static List<ushort> EncodeOverlay(byte[] kind, ushort[] color, int w, int start, int end)
    {
        List<ushort> offsets = new List<ushort>(), runs = new List<ushort>();
        for (int y = start; y <= end; y++)
        {
            bool empty = true;
            for (int x = 0; x < w; x++) if (kind[y * w + x] != Clear) { empty = false; break; }
            if (empty) { offsets.Add(0xFFFF); continue; }
            if (runs.Count >= 0xFFFF) return null;
            offsets.Add((ushort)runs.Count);
            int xx = 0, last = 0;
            while (xx < w)
            {
                byte k = kind[y * w + xx];
                int len = 1;
                while (xx + len < w && kind[y * w + xx + len] == k && len < 255) len++;
                int id = k == Copy ? 0xC : k == Shadow ? 0xD : k == Colorize ? 0xB : 0xA;
                last = runs.Count;
                runs.Add((ushort)((id << 8) | len));
                if (k == Copy) for (int i = 0; i < len; i++) runs.Add(color[y * w + xx + i]);
                xx += len;
            }
            runs[last] = (ushort)(runs[last] | 0xE000);
        }
        if (runs.Count > 0xFFFF) return null;
        List<ushort> words = new List<ushort>();
        words.Add((ushort)start); words.Add((ushort)end);
        words.AddRange(offsets); words.AddRange(runs);
        return words;
    }

    // the upscaled images in the format of the game, as one file
    // the upscaled images from factor 'from' down to factor 's' (bicubic)
    public static void Resize(string dir, int s, int from)
    {
        foreach (string path in Directory.GetFiles(dir, "*.png"))
        {
            using (Bitmap src = new Bitmap(path))
            using (Bitmap dst = new Bitmap(src.Width * s / from, src.Height * s / from, PixelFormat.Format24bppRgb))
            {
                using (Graphics g = Graphics.FromImage(dst))
                {
                    g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
                    g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
                    using (ImageAttributes edges = new ImageAttributes())
                    {
                        edges.SetWrapMode(System.Drawing.Drawing2D.WrapMode.TileFlipXY);
                        g.DrawImage(src, new Rectangle(0, 0, dst.Width, dst.Height), 0, 0, src.Width, src.Height, GraphicsUnit.Pixel, edges);
                    }
                }
                src.Dispose();
                dst.Save(path, ImageFormat.Png);
            }
        }
    }

    public static int Import(string dir, int s, string target)
    {
        records.Clear();
        int ws = W * s, hs = H * s;
        foreach (int num in baseNums)
        {
            byte[] up = Upscaled(dir, "t_base_" + num, ws, hs);
            if (up == null) continue;
            ushort[] tile = bases[num];
            // the source pixel of every diamond position
            int[] srcIndex = new int[W * H];
            int i = 0;
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                    srcIndex[y * W + x] = (x >= Start(y) && x < W - Start(y)) ? i++ : -1;
            List<ushort> words = new List<ushort>();
            for (int y = 0; y < hs; y++)
            {
                int st = s * Start(y / s);
                for (int x = st; x < ws - st; x++)
                {
                    ushort src = tile[srcIndex[(y / s) * W + x / s]];
                    if (src < 4) { words.Add(src); continue; }   // transition marker
                    ushort c = To565(up, y * ws + x);
                    words.Add(c < 4 ? (ushort)4 : c);
                }
            }
            Record(1, 0, num, 0, words);
        }
        for (int t = 0; t < transData.Count; t++)
        {
            int k = transKeys[t][2];
            if (layout[k] == null) continue;
            byte[] up = Upscaled(dir, "t_tr_" + t, ws, hs);
            if (up == null) continue;
            List<ushort> words = new List<ushort>();
            for (int y = 0; y < hs; y++)
            {
                int st = s * Start(y / s);
                for (int x = st; x < ws - st; x++)
                    if (layout[k][(y / s) * W + x / s] >= 0) words.Add(To565(up, y * ws + x));
            }
            Record(2, k, transKeys[t][0], transKeys[t][1], words);
        }
        foreach (KeyValuePair<string, Overlay> e in overlays)
        {
            Overlay o = e.Value;
            int h = o.End + 1;
            byte[] up = Upscaled(dir, "t_" + e.Key, ws, h * s);
            byte[] mask = Upscaled(dir, "t_" + e.Key + Ctp2Assets.MaskSuffix, ws, h * s);
            if (up == null) continue;
            byte[] kind = new byte[ws * h * s];
            ushort[] color = new ushort[ws * h * s];
            for (int y = 0; y < h * s; y++)
                for (int x = 0; x < ws; x++)
                {
                    int at = y * ws + x;
                    byte src = o.Kind[(y / s) * W + x / s];
                    bool visible = mask != null ? mask[at * 3 + 1] >= 128 : src == Copy;
                    if (visible) { kind[at] = Copy; color[at] = To565(up, at); }
                    else if (src == Shadow || src == Colorize) kind[at] = src;
                }
            List<ushort> words = EncodeOverlay(kind, color, ws, o.Start * s, o.End * s + s - 1);
            if (words == null) continue;
            string[] parts = e.Key.Split('_');
            int type = parts[0] == "hat" ? 3 : parts[0] == "riv" ? 4 : 5;
            Record(type, 0, int.Parse(parts[1]), 0, words);
        }

        using (FileStream f = File.Create(target))
        {
            byte[] head = new byte[16];
            System.Text.Encoding.ASCII.GetBytes("CTPHDT1").CopyTo(head, 0);
            BitConverter.GetBytes(s).CopyTo(head, 8);
            BitConverter.GetBytes(records.Count).CopyTo(head, 12);
            f.Write(head, 0, head.Length);
            foreach (byte[] r in records) f.Write(r, 0, r.Length);
        }
        return records.Count;
    }
}
'@

Say (L "Spielordner: $Install" "Game folder: $Install")
Say (L "Sprache: $gameLanguage, Ziel: $target" "Language: $gameLanguage, target: $target")

# --- upscale (the work folder must hold only the pictures of this step) -------
function Invoke-Esrgan([string]$from, [string]$to, [string]$format, [string]$part, [string]$model = $Model, [int]$factor = $Scale) {
    # its progress goes to stderr; a log keeps PowerShell from taking it as an error
    $quoted = @('-i', "`"$from`"", '-o', "`"$to`"", '-n', $model, '-s', "$factor", '-f', $format)
    $count = @(Get-ChildItem -Path $from -File).Count
    foreach ($extra in @(@(), @('-g', '-1'))) {
        if ($extra.Count) { Say (L 'Mit der Grafikkarte ging es nicht, versuche es mit dem Prozessor (langsam) ...' "The graphics card did not work, trying the processor (slow) ...") }
        $process = Start-Process -FilePath $esrgan.FullName -ArgumentList ($quoted + $extra) -NoNewWindow -PassThru `
            -RedirectStandardError (Join-Path $work 'esrgan.log') -RedirectStandardOutput (Join-Path $work 'esrgan-out.log')
        while (-not $process.WaitForExit(1000)) { Progress $part (@(Get-ChildItem -Path $to -File).Count) $count }
        $done = @(Get-ChildItem -Path $to -File).Count
        Progress $part $done $count
        if ($done -ge $count) { return $true }
    }
    return $false
}

# --- collect the images (later sources override earlier ones, like the game) --
$ok = 0
if (-not $NoImages) {
    $rims  = @{}
    $loose = @{}
    foreach ($dir in @('default', $gameLanguage)) {
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
    foreach ($dir in @('default', $gameLanguage)) {
        $base = Join-Path $data "$dir\graphics\cursors"
        if (Test-Path $base) {
            foreach ($f in Get-ChildItem -Path $base -Filter '*.tga') { $sources[$f.BaseName.ToLower()] = @{ tga = $f.FullName; black = $true } }
        }
    }
    Say (L "Bilder gefunden: $($sources.Count)" "Images found: $($sources.Count)")
    if ($Status) {
        $done = @($sources.Keys | Where-Object { -not $redoImages -and ($skipped[$_] -or (Test-Path (Join-Path $target "$_.tga"))) }).Count
        Write-Host "##STATUS bilder $done $($sources.Count)"
        $sources = [ordered]@{}
    }

    # --- export (only what is not done yet) -----------------------------------------
    $todo = @()
    $n = 0
    foreach ($name in $sources.Keys) {
        if (($n++ % 100) -eq 0) { Progress 'vorbereiten' $n $sources.Count }
        if (-not $redoImages -and ($skipped[$name] -or (Test-Path (Join-Path $target "$name.tga")))) { continue }
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
            Say (L "  uebersprungen: $name ($($_.Exception.Message))" "  skipped: $name ($($_.Exception.Message))")
            if (-not $skipped[$name]) { Add-Content -Path $skippedList -Value $name; $skipped[$name] = $true }
        }
    }
    if ($todo.Count -eq 0) {
        Say (L 'Bilder: alles schon hochskaliert. (Mit -Force neu erzeugen.)' "Images: all upscaled already. (-Force makes them again.)")
    } else {
        Say (L "Hochzuskalieren: $($todo.Count) Bilder" "To upscale: $($todo.Count) images")
        Say (L "Skaliere mit Real-ESRGAN ($Model, $Scale-fach) ... das kann je nach Grafikkarte einige Minuten dauern." "Upscaling with Real-ESRGAN ($Model, $($Scale)x) ... depending on the graphics card this takes some minutes.")
        Invoke-Esrgan $inDir $outDir 'png' 'bilder' | Out-Null

        # --- import -----------------------------------------------------------------
        $n = 0
        foreach ($name in $todo) {
            if (($n++ % 100) -eq 0) { Progress 'einlesen' $n $todo.Count }
            $up = Join-Path $outDir "$name.png"
            if (-not (Test-Path $up)) { Say (L "  fehlt: $name" "  missing: $name"); continue }
            try {
                [Ctp2Assets]::BlackKey = [bool]$sources[$name].black
                [Ctp2Assets]::Import($up, (Join-Path $origDir "$name.png"), $Scale, (Join-Path $target "$name.tga"))
                $ok++
            } catch {
                Say (L "  fehlgeschlagen: $name ($($_.Exception.Message))" "  failed: $name ($($_.Exception.Message))")
            }
        }
        Say (L "Bilder: $ok von $($todo.Count) fertig." "Images: $ok of $($todo.Count) done.")
        if ($ok -eq $todo.Count) { MarkLanguage 'bilder' }
    }
}

# --- the terrain of the map (base tiles, transitions, hats, rivers, roads) ------
# goes to one file in the format of the game, which reads it when the map
# is drawn in the pixels of the frame (TileSet::ScaleUp)
$tileSource  = Join-Path $data 'default\graphics\tiles\gtset565.til'
$terrainFile = Join-Path $target 'tiles\gtset565.hd'
if ($Status) {
    $done = if ((Test-Path $terrainFile) -and -not $Force) { 1 } else { 0 }
    Write-Host "##STATUS gelaende $done 1"
} elseif (-not $NoTerrain) {
    if (-not (Test-Path $tileSource)) {
        Say (L 'Gelaende: gtset565.til nicht gefunden.' 'Terrain: gtset565.til not found.')
    } elseif ((Test-Path $terrainFile) -and -not $Force) {
        Say (L 'Gelaende: schon hochskaliert.' 'Terrain: upscaled already.')
    } else {
        $tilesIn  = Join-Path $work 'gelaende_ein'
        $tilesOut = Join-Path $work 'gelaende_aus'
        foreach ($d in @($tilesIn, $tilesOut, (Split-Path $terrainFile))) { New-Item -ItemType Directory -Force $d | Out-Null }
        $count = [Ctp2Tiles]::Load($tileSource)
        Say (L "Gelaende: $count Teile (Kacheln, Uebergaenge, Berge und Waelder, Fluesse, Ausbauten)" "Terrain: $count parts (tiles, transitions, hills and forests, rivers, improvements)")
        [Ctp2Tiles]::Export($tilesIn)
        # models of the realesrgan-x4 family only make 4x; their results are
        # made smaller to the scale
        $terrainFactor = if ($TerrainModel -like 'realesrgan-x4*') { 4 } else { $Scale }
        if (Invoke-Esrgan $tilesIn $tilesOut 'png' 'gelaende' $TerrainModel $terrainFactor) {
            if ($terrainFactor -ne $Scale) { [Ctp2Tiles]::Resize($tilesOut, $Scale, $terrainFactor) }
            $made = [Ctp2Tiles]::Import($tilesOut, $Scale, $terrainFile)
            Say (L "Gelaende: $made Teile fertig." "Terrain: $made parts done.")
        } else {
            Say (L 'Gelaende: Hochskalieren fehlgeschlagen.' 'Terrain: upscaling failed.')
        }
    }
}

# --- the videos -------------------------------------------------------------------
# ffmpeg.exe is built with the game (FFmpeg, LGPL) and comes with the release
$ffmpeg = $null
foreach ($p in @($PSScriptRoot, $Install, $program, $(if ($program) { Join-Path $program 'x64' }),
                 (Join-Path $Install 'ctp2_code\msvc\bin\x64'))) {
    if ($p -and (Test-Path (Join-Path $p 'ffmpeg.exe'))) { $ffmpeg = Join-Path $p 'ffmpeg.exe'; break }
}

function Invoke-Ffmpeg([string[]]$arguments) {
    $quoted = @('-hide_banner', '-y') + ($arguments | ForEach-Object { if ($_ -match '[\s%]') { "`"$_`"" } else { $_ } })
    $process = Start-Process -FilePath $ffmpeg -ArgumentList $quoted -NoNewWindow -Wait -PassThru `
        -RedirectStandardError (Join-Path $work 'ffmpeg.log') -RedirectStandardOutput (Join-Path $work 'ffmpeg-out.log')
    return $process.ExitCode
}

$videos = [ordered]@{}
foreach ($dir in @('default', $gameLanguage)) {
    $base = Join-Path $data "$dir\videos"
    if (Test-Path $base) {
        foreach ($f in Get-ChildItem -Path $base -Filter '*.avi') { $videos[$f.BaseName.ToLower()] = $f.FullName }
    }
}
$videoDir = Join-Path $target 'videos'
$videoTodo = @($videos.Keys | Where-Object { -not $NoVideos } | Where-Object { $redoVideos -or -not (Test-Path (Join-Path $videoDir "$_.mkv")) })
if ($Status) {
    $done = @($videos.Keys | Where-Object { -not $redoVideos -and (Test-Path (Join-Path $videoDir "$_.mkv")) }).Count
    Write-Host "##STATUS videos $done $($videos.Count)"
    Remove-Item -Recurse -Force $work
    exit 0
}
$videoOk = 0
if ($NoVideos) {
    # not wanted
} elseif (-not $ffmpeg) {
    Say (L 'Videos: ffmpeg.exe nicht gefunden (gehoert neben dieses Skript), Videos bleiben im Original.' "Videos: ffmpeg.exe not found (belongs next to this script), the videos stay original.")
} elseif ($videoTodo.Count -eq 0) {
    Say (L 'Videos: alles schon hochskaliert.' "Videos: all upscaled already.")
} else {
    New-Item -ItemType Directory -Force $videoDir | Out-Null
    Say (L "Videos: $($videoTodo.Count) hochzuskalieren, je etwa eine halbe Minute ..." "Videos: $($videoTodo.Count) to upscale ...")
    $frames   = Join-Path $work 'video_ein'
    $upFrames = Join-Path $work 'video_aus'
    $bitrate  = "$([int]($Scale * $Scale * 500))k"
    $n = 0
    foreach ($name in $videoTodo) {
        $n++
        Say "  ($n/$($videoTodo.Count)) $name"
        Progress 'videos' ($n - 1) $videoTodo.Count
        $source = $videos[$name]
        foreach ($d in @($frames, $upFrames)) {
            Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue
            New-Item -ItemType Directory -Force $d | Out-Null
        }
        # the frame rate of the original (all of them have 15)
        Invoke-Ffmpeg @('-i', $source) | Out-Null
        $rate = '15'
        $match = Select-String -Path (Join-Path $work 'ffmpeg.log') -Pattern '([\d.]+) fps' | Select-Object -First 1
        if ($match) { $rate = $match.Matches[0].Groups[1].Value }

        if ((Invoke-Ffmpeg @('-i', $source, '-fps_mode', 'passthrough', (Join-Path $frames '%05d.bmp'))) -ne 0) {
            Say (L "    uebersprungen: Video nicht lesbar" "    skipped: video not readable"); continue
        }
        if (-not (Invoke-Esrgan $frames $upFrames 'webp' 'videobilder')) { Say (L "    uebersprungen: Hochskalieren fehlgeschlagen" "    skipped: upscaling failed"); continue }

        # H.264 by Windows (Media Foundation), MPEG-4 where that is missing; the sound stays
        # written under a temporary name, so a cancelled run leaves no half video
        $out = Join-Path $videoDir "$name.tmp.mkv"
        $encodeFrom = @('-framerate', $rate, '-i', (Join-Path $upFrames '%05d.webp'), '-i', $source, '-map', '0:v', '-map', '1:a?', '-c:a', 'copy')
        $code = Invoke-Ffmpeg ($encodeFrom + @('-c:v', 'h264_mf', '-b:v', $bitrate, '-pix_fmt', 'nv12', $out))
        if ($code -ne 0) { $code = Invoke-Ffmpeg ($encodeFrom + @('-c:v', 'mpeg4', '-q:v', '2', $out)) }
        if ($code -eq 0) { Move-Item -Force $out (Join-Path $videoDir "$name.mkv"); $videoOk++ } else { Remove-Item $out -ErrorAction SilentlyContinue; Say (L "    fehlgeschlagen (siehe ffmpeg)" "    failed (see ffmpeg)") }
    }
    Progress 'videos' $videoTodo.Count $videoTodo.Count
    Say (L "Videos: $videoOk von $($videoTodo.Count) fertig." "Videos: $videoOk of $($videoTodo.Count) done.")
    if ($videoOk -eq $videoTodo.Count) { MarkLanguage 'videos' }
}
Remove-Item -Recurse -Force $work

Say ''
Say (L "Fertig. HD-Dateien in $target." "Done. HD files in $target.")
Say (L 'Die HD-Dateien gelten fuer die eingestellte Skalierung. Rueckgaengig: den Ordner redux_hires loeschen.' "The HD files are for the chosen scaling. To undo: delete the folder redux_hires.")
