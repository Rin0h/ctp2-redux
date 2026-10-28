# ctp2-redux: setup window for the HD files of your own Call to Power II
# installation, in German or English. Guides through game folder, scaling
# and the steps (1 interface images, 2 videos, 3 map later) and runs
# ctp2-redux-hochskalieren.ps1 with a progress bar. Each step can be done on
# its own and cancelled; the next run goes on where it stopped. It can also
# remove the HD files again.
#
#   ctp2-redux-hochskalieren.bat               (double-click, in the game folder)
#   powershell -File ctp2-redux-hd-setup.ps1 [-Install <folder>] [-Lang de|en]
#
# For tests: -Screenshots <folder> draws every page into a PNG there (off
# screen, nothing is changed) and quits.
#
# Runs with Windows PowerShell 5.1 (Windows Forms); the file is saved as
# UTF-8 with BOM so that 5.1 reads the umlauts.

param(
    [string]$Install = '',
    [string]$Lang = '',
    [string]$Screenshots = ''
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -Namespace Ctp2Setup -Name Native -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
[void][Ctp2Setup.Native]::SetProcessDPIAware()
[Windows.Forms.Application]::EnableVisualStyles()

# the windows are laid out for 96 dpi and enlarged by the Windows scaling
# (fonts in points follow it by themselves)
function Set-DpiScale($f) {
    $g = $f.CreateGraphics()
    $factor = $g.DpiX / 96.0
    $g.Dispose()
    if ($factor -gt 1.01) { $f.Scale((New-Object Drawing.SizeF $factor, $factor)) }
}

$engine = Join-Path $PSScriptRoot 'ctp2-redux-hochskalieren.ps1'

# --- texts ------------------------------------------------------------------------
$texts = @{
    de = @{
        Title          = 'ctp2-redux – HD-Einrichtung'
        Back           = '< Zurück'
        Next           = 'Weiter >'
        Cancel         = 'Abbrechen'
        Create         = 'Erzeugen'
        Finish         = 'Fertigstellen'
        Welcome1       = ('Dieser Assistent erzeugt aus deiner eigenen Call-to-Power-II-Installation HD-Fassungen ' +
                          'der Spielgrafik: Oberflächenbilder, Mauszeiger, Videos und das Gelände der Karte werden mit künstlicher ' +
                          'Intelligenz (Real-ESRGAN) auf deinem Rechner hochgerechnet.')
        Welcome2       = ('Deine Originaldateien bleiben unverändert. Die HD-Dateien landen im Ordner ' +
                          'ctp2_data\redux_hires; das Spiel nimmt sie automatisch, wenn die Skalierung passt.')
        Welcome3       = 'Die Arbeit ist in Schritte geteilt, die du dir einteilen kannst.'
        ModeCreate     = 'HD-Dateien erzeugen oder ergänzen'
        ModeRemove     = 'HD-Dateien entfernen (zurück zur Originalgrafik)'
        ClickNext      = 'Klicke auf »Weiter«, um fortzufahren.'
        FolderAsk      = 'In welchem Ordner ist Call to Power II installiert? (Dort liegt der Ordner ctp2_data.)'
        Browse         = 'Durchsuchen …'
        BrowseTitle    = 'Ordner von Call to Power II (mit ctp2_data darin) wählen'
        FolderOk       = '✔ Spieldaten gefunden (Sprache: {0}).'
        FolderHasHD    = 'Es gibt dort schon HD-Dateien.'
        FolderBad      = '✖ Hier ist kein Call to Power II (ctp2_data\default\graphics\pictures\pic565.zfs fehlt).'
        ScaleOption    = '{0}-fach – Spielfläche {1} x {2}, Bilder und Schrift {0}-mal so groß'
        Recommended    = ' (empfohlen)'
        ScaleIntro     = 'Dein Bildschirm: {0} x {1}, empfohlen: {2}-fach. Im Spiel eingestellt: {3}.'
        ScaleNone      = 'nicht eingestellt (automatisch)'
        ScaleAuto      = 'automatisch ({0}-fach)'
        ScaleOff       = 'aus'
        ScaleFixed     = '{0}-fach'
        SetProfile     = 'Im Spiel dieselbe Skalierung einstellen (sonst: Optionen → Grafik → Skalierung)'
        ScaleNote      = ('Das Spiel nimmt die HD-Dateien nur, wenn seine Skalierung zur gewählten passt. ' +
                          'Bei kleineren Bildschirmen (unter 2048x1536) lohnt sich HD nicht.')
        StepsIntro     = ('Die Arbeit ist in Schritte geteilt. Du kannst sie einzeln nacheinander erledigen, ' +
                          'jederzeit abbrechen und später weitermachen – fertige Dateien bleiben erhalten.')
        Step1          = 'Schritt 1 – Oberfläche: Bilder und Mauszeiger'
        Step2          = 'Schritt 2 – Videos: Intro und Wunder-Filme'
        Step3          = 'Schritt 3 – Gelände: Kacheln, Küsten, Flüsse, Berge, Wälder, Straßen'
        Step3Note      = '{0} · ca. {1} MB · etwa eine Minute'
        Step4          = 'Schritt 4 – Einheiten, Städte und Güter auf der Karte'
        Step4Later     = 'folgt in einer späteren Version'
        Terrain        = 'Teil'
        RunTerrain     = 'Gelände wird hochgerechnet: {0} %'
        Step1Note      = '{0} · ca. {1} MB · wenige Minuten'
        Step2Note      = "{0} · ca. {1} MB`ndauert lange: je Video ca. eine halbe Minute mit schneller Grafikkarte, mit schwächerer mehrere Minuten"
        NoFfmpeg       = 'ffmpeg.exe fehlt neben dem Spiel oder diesem Assistenten – Videos bleiben im Original.'
        Force          = 'Bereits erzeugte Dateien neu erzeugen'
        Checking       = 'Prüfe, was schon fertig ist …'
        StateNone      = 'nichts gefunden'
        StateDone      = 'erledigt ({0} {1})'
        StateOpen      = 'offen ({0} {1})'
        StatePart      = 'teilweise erledigt: {0} von {1} {2}'
        Images         = 'Bilder'
        Videos         = 'Videos'
        AllDone        = 'Alle verfügbaren Schritte sind für diese Skalierung erledigt.'
        EsrganDownload = 'Beim ersten Mal wird Real-ESRGAN (ca. 45 MB, BSD-Lizenz) von github.com geladen.'
        FreeSpace      = 'Freier Speicher auf {0}: {1} GB'
        GpuNote        = 'Eine Grafikkarte mit Vulkan beschleunigt die Berechnung stark; ohne geht es (sehr langsam) mit dem Prozessor.'
        Starting       = 'Starte …'
        RunPrepare     = 'Bilder werden vorbereitet ({0} von {1}) …'
        RunImages      = 'Bilder werden hochgerechnet: {0} %'
        RunImport      = 'Bilder werden übernommen ({0} von {1}) …'
        RunVideo       = 'Video {0} von {1}: Bild {2} von {3}'
        StartGame      = 'Call to Power II jetzt starten'
        DoneOk         = 'Die gewählten Schritte sind fertig.'
        DoneWhere      = "Die HD-Dateien für {0}-fache Skalierung liegen in:`n{1}`n`nDas Spiel nimmt sie, solange seine Skalierung {0}-fach ist (Optionen → Grafik → Skalierung)."
        DoneOpen       = "`n`nNoch offen: {0}. Starte den Assistenten einfach später noch einmal."
        DoneAll        = "`n`nRückgängig machen: diesen Assistenten noch einmal starten und »HD-Dateien entfernen« wählen."
        DoneFail       = 'Das hat leider nicht geklappt.'
        DoneFailText   = "Fehler: {0}`n`nDas Protokoll liegt in:`n{1}"
        SeeLog         = 'Siehe Protokoll.'
        NoHD           = 'Es gibt keine HD-Dateien.'
        NoHDText       = 'In diesem Spielordner gibt es keine HD-Dateien; das Spiel nutzt die Originalgrafik.'
        RemoveAsk      = "Alle HD-Dateien in`n{0}`nlöschen?"
        Removed        = 'Die HD-Dateien sind entfernt.'
        RemovedText    = 'Das Spiel nutzt wieder die Originalgrafik. Die Skalierung im Spiel bleibt, wie sie ist (Optionen → Grafik).'
        CancelAsk      = 'Die Berechnung abbrechen? Bereits fertige Dateien bleiben erhalten, beim nächsten Mal geht es dort weiter.'
        Cancelled      = 'Abgebrochen.'
        CancelledText  = 'Die Berechnung wurde abgebrochen. Bereits fertige Dateien bleiben erhalten; starte den Assistenten erneut, um weiterzumachen.'
        CloseAsk       = 'Die Berechnung läuft noch. Abbrechen und schließen?'
        EngineMissing  = 'ctp2-redux-hochskalieren.ps1 fehlt neben diesem Assistenten.'
        Heads          = @(
            @('Willkommen', 'HD-Grafik und -Videos für Call to Power II (ctp2-redux)'),
            @('Spielordner', 'Wo ist das Spiel installiert?'),
            @('Skalierung', 'Wie stark soll das Spiel vergrößert werden?'),
            @('Schritte', 'Welche Schritte sollen jetzt erledigt werden?'),
            @('Erzeugen', 'Die HD-Dateien werden jetzt auf deinem Rechner berechnet.'),
            @('Fertig', ''))
    }
    en = @{
        Title          = 'ctp2-redux – HD setup'
        Back           = '< Back'
        Next           = 'Next >'
        Cancel         = 'Cancel'
        Create         = 'Create'
        Finish         = 'Finish'
        Welcome1       = ('This assistant makes HD versions of the game graphics from your own Call to Power II ' +
                          'installation: interface images, mouse cursors, videos and the terrain of the map are upscaled on your computer ' +
                          'with artificial intelligence (Real-ESRGAN).')
        Welcome2       = ('Your original files stay untouched. The HD files go to the folder ctp2_data\redux_hires; ' +
                          'the game takes them automatically when the scaling matches.')
        Welcome3       = 'The work is split into steps that you can plan as you like.'
        ModeCreate     = 'Create or complete the HD files'
        ModeRemove     = 'Remove the HD files (back to the original graphics)'
        ClickNext      = 'Click "Next" to continue.'
        FolderAsk      = 'In which folder is Call to Power II installed? (The folder ctp2_data is there.)'
        Browse         = 'Browse …'
        BrowseTitle    = 'Choose the folder of Call to Power II (with ctp2_data in it)'
        FolderOk       = '✔ Game data found (language: {0}).'
        FolderHasHD    = 'There are HD files already.'
        FolderBad      = '✖ No Call to Power II here (ctp2_data\default\graphics\pictures\pic565.zfs is missing).'
        ScaleOption    = '{0}x – playing area {1} x {2}, images and text {0} times as large'
        Recommended    = ' (recommended)'
        ScaleIntro     = 'Your screen: {0} x {1}, recommended: {2}x. Set in the game: {3}.'
        ScaleNone      = 'not set (automatic)'
        ScaleAuto      = 'automatic ({0}x)'
        ScaleOff       = 'off'
        ScaleFixed     = '{0}x'
        SetProfile     = 'Set the same scaling in the game (otherwise: Options → Graphics → Scaling)'
        ScaleNote      = ('The game only takes the HD files when its scaling matches the chosen one. ' +
                          'For smaller screens (below 2048x1536) HD is not worth it.')
        StepsIntro     = ('The work is split into steps. You can do them one after the other, cancel at any ' +
                          'time and go on later – finished files are kept.')
        Step1          = 'Step 1 – Interface: images and mouse cursors'
        Step2          = 'Step 2 – Videos: intro and wonder movies'
        Step3          = 'Step 3 – Terrain: tiles, coasts, rivers, hills, forests, roads'
        Step3Note      = '{0} · about {1} MB · about a minute'
        Step4          = 'Step 4 – Units, cities and goods on the map'
        Step4Later     = 'comes with a later version'
        Terrain        = 'part'
        RunTerrain     = 'Upscaling the terrain: {0} %'
        Step1Note      = '{0} · about {1} MB · a few minutes'
        Step2Note      = "{0} · about {1} MB`ntakes long: about half a minute per video with a fast graphics card, several minutes with a slower one"
        NoFfmpeg       = 'ffmpeg.exe is missing next to the game or this assistant – the videos stay original.'
        Force          = 'Create already finished files again'
        Checking       = 'Checking what is done already …'
        StateNone      = 'nothing found'
        StateDone      = 'done ({0} {1})'
        StateOpen      = 'open ({0} {1})'
        StatePart      = 'partly done: {0} of {1} {2}'
        Images         = 'images'
        Videos         = 'videos'
        AllDone        = 'All available steps are done for this scaling.'
        EsrganDownload = 'The first time, Real-ESRGAN (about 45 MB, BSD licence) is downloaded from github.com.'
        FreeSpace      = 'Free space on {0}: {1} GB'
        GpuNote        = 'A graphics card with Vulkan speeds the work up a lot; without one it runs (very slowly) on the processor.'
        Starting       = 'Starting …'
        RunPrepare     = 'Preparing images ({0} of {1}) …'
        RunImages      = 'Upscaling images: {0} %'
        RunImport      = 'Taking over images ({0} of {1}) …'
        RunVideo       = 'Video {0} of {1}: frame {2} of {3}'
        StartGame      = 'Start Call to Power II now'
        DoneOk         = 'The chosen steps are done.'
        DoneWhere      = "The HD files for {0}x scaling are in:`n{1}`n`nThe game takes them as long as its scaling is {0}x (Options → Graphics → Scaling)."
        DoneOpen       = "`n`nStill open: {0}. Just start the assistant again later."
        DoneAll        = "`n`nTo undo it: start this assistant again and choose ""Remove the HD files""."
        DoneFail       = 'That did not work, sorry.'
        DoneFailText   = "Error: {0}`n`nThe log is in:`n{1}"
        SeeLog         = 'See the log.'
        NoHD           = 'There are no HD files.'
        NoHDText       = 'There are no HD files in this game folder; the game uses the original graphics.'
        RemoveAsk      = "Delete all HD files in`n{0}?"
        Removed        = 'The HD files are removed.'
        RemovedText    = 'The game uses the original graphics again. The scaling in the game stays as it is (Options → Graphics).'
        CancelAsk      = 'Cancel the work? Finished files are kept, the next run goes on from there.'
        Cancelled      = 'Cancelled.'
        CancelledText  = 'The work was cancelled. Finished files are kept; start the assistant again to go on.'
        CloseAsk       = 'The work is still running. Cancel it and close?'
        EngineMissing  = 'ctp2-redux-hochskalieren.ps1 is missing next to this assistant.'
        Heads          = @(
            @('Welcome', 'HD graphics and videos for Call to Power II (ctp2-redux)'),
            @('Game folder', 'Where is the game installed?'),
            @('Scaling', 'How much should the game be enlarged?'),
            @('Steps', 'Which steps should be done now?'),
            @('Creating', 'The HD files are being made on your computer now.'),
            @('Done', ''))
    }
}

# --- the language of the assistant (asked first) ----------------------------------
function Select-Language {
    $f = New-Object Windows.Forms.Form
    $f.AutoScaleMode   = 'None'
    $f.Font            = New-Object Drawing.Font 'Segoe UI', 10
    $f.Text            = 'ctp2-redux'
    $f.ClientSize      = New-Object Drawing.Size 360, 150
    $f.FormBorderStyle = 'FixedDialog'
    $f.MaximizeBox     = $false
    $f.MinimizeBox     = $false
    $f.StartPosition   = 'CenterScreen'
    $l = New-Object Windows.Forms.Label
    $l.Text = "Sprache des Assistenten wählen`nChoose the language of the assistant"
    $l.SetBounds(20, 16, 320, 44)
    $f.Controls.Add($l)
    $script:chosen = $null
    $x = 20
    foreach ($lang in @(@('de', 'Deutsch'), @('en', 'English'))) {
        $b = New-Object Windows.Forms.Button
        $b.Text = $lang[1]
        $b.Tag  = $lang[0]
        $b.SetBounds($x, 80, 150, 40)
        $b.add_Click({ $script:chosen = $this.Tag; $f.Close() })
        $f.Controls.Add($b)
        if ([Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq $lang[0]) { $f.AcceptButton = $b; $f.ActiveControl = $b }
        $x += 170
    }
    Set-DpiScale $f
    [void]$f.ShowDialog()
    return $script:chosen
}
$lang = if ($Lang) { $Lang } else { Select-Language }
if (-not $lang) { exit 0 }
$T = $texts[$lang]
$title = $T.Title

# --- the installation -------------------------------------------------------------
function Get-GameInfo([string]$folder) {
    if (-not $folder -or -not (Test-Path $folder)) { return $null }
    $folder = (Resolve-Path $folder).Path
    $data = Join-Path $folder 'ctp2_data'
    if (-not (Test-Path (Join-Path $data 'default\graphics\pictures\pic565.zfs'))) { return $null }

    $info = @{ Folder = $folder; Data = $data; Program = $null; Language = 'english'; Profile = $null; ProfileScale = $null; Exe = $null }
    foreach ($p in @('ctp2_program\ctp', 'ctp2_code\ctp')) {
        if (Test-Path (Join-Path $folder $p)) { $info.Program = Join-Path $folder $p; break }
    }
    $civpathsRead = $false
    $profileLanguage = $null
    if ($info.Program) {
        # where the game runs first (x64 in a build)
        $subs = if (Test-Path (Join-Path $info.Program 'x64\ctp2.exe')) { @('x64', '') } else { @('', 'x64') }
        foreach ($sub in $subs) {
            $dir = if ($sub) { Join-Path $info.Program $sub } else { $info.Program }
            if (-not $info.Exe -and (Test-Path (Join-Path $dir 'ctp2.exe'))) { $info.Exe = Join-Path $dir 'ctp2.exe' }
            $paths = Join-Path $dir 'civpaths.txt'
            if (-not $civpathsRead -and (Test-Path $paths)) {
                $civpathsRead = $true
                $lines = @(Get-Content $paths | Where-Object { $_.Trim() })
                if ($lines.Count -ge 4 -and -not $profileLanguage) { $info.Language = $lines[3].Trim() }
            }
            $profileFile = Join-Path $dir 'userprofile.txt'
            if (-not $info.Profile -and (Test-Path $profileFile)) {
                $info.Profile = $profileFile
                $line = Select-String -Path $profileFile -Pattern '^DisplayScale=(-?\d+)' | Select-Object -First 1
                if ($line) { $info.ProfileScale = [int]$line.Matches[0].Groups[1].Value }
                # the game takes LanguageDirectory of the profile before civpaths
                $line = Select-String -Path $profileFile -Pattern '^LanguageDirectory=(\S+)' | Select-Object -First 1
                if ($line) { $profileLanguage = $line.Matches[0].Groups[1].Value; $info.Language = $profileLanguage }
            }
        }
    }
    return $info
}

function Find-GameFolder {
    $candidates = @($Install, $PSScriptRoot, (Split-Path $PSScriptRoot), (Split-Path (Split-Path $PSScriptRoot)))
    # GOG keeps the folder of its games in the registry
    foreach ($key in @('HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games', 'HKLM:\SOFTWARE\GOG.com\Games')) {
        if (Test-Path $key) {
            foreach ($game in Get-ChildItem $key -ErrorAction SilentlyContinue) {
                $props = Get-ItemProperty $game.PSPath -ErrorAction SilentlyContinue
                if ($props.gameName -like '*Call to Power*' -and $props.path) { $candidates += $props.path }
            }
        }
    }
    $candidates += @('C:\GOG Games\Call To Power 2', "${env:ProgramFiles(x86)}\GOG Galaxy\Games\Call To Power 2")
    foreach ($c in $candidates) {
        if ($c -and (Get-GameInfo $c)) { return (Resolve-Path $c).Path }
    }
    return ''
}

function Find-Ffmpeg($info) {
    foreach ($p in @($PSScriptRoot, $info.Folder, $info.Program, $(if ($info.Program) { Join-Path $info.Program 'x64' }),
                     (Join-Path $info.Folder 'ctp2_code\msvc\bin\x64'))) {
        if ($p -and (Test-Path (Join-Path $p 'ffmpeg.exe'))) { return $true }
    }
    return $false
}

# the same rule as the game: the largest factor that leaves 1024 x 768
$screen = [Windows.Forms.Screen]::PrimaryScreen.Bounds
$autoScale = 1
while ($autoScale -lt 4 -and [math]::Floor($screen.Width / ($autoScale + 1)) -ge 1024 -and
       [math]::Floor($screen.Height / ($autoScale + 1)) -ge 768) { $autoScale++ }

# --- the window -------------------------------------------------------------------
$form = New-Object Windows.Forms.Form
$form.AutoScaleMode   = 'None'
$form.Font            = New-Object Drawing.Font 'Segoe UI', 9
$form.Text            = $title
$form.ClientSize      = New-Object Drawing.Size 640, 520
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox     = $false
$form.StartPosition   = 'CenterScreen'

$header = New-Object Windows.Forms.Panel
$header.SetBounds(0, 0, 640, 70)
$header.BackColor = [Drawing.Color]::White
$form.Controls.Add($header)

$headTitle = New-Object Windows.Forms.Label
$headTitle.SetBounds(20, 12, 600, 24)
$headTitle.Font = New-Object Drawing.Font 'Segoe UI', 12, ([Drawing.FontStyle]::Bold)
$header.Controls.Add($headTitle)

$headText = New-Object Windows.Forms.Label
$headText.SetBounds(22, 40, 600, 22)
$header.Controls.Add($headText)

foreach ($y in 70, 468) {
    $rule = New-Object Windows.Forms.Label
    $rule.SetBounds(0, $y, 640, 2)
    $rule.BorderStyle = 'Fixed3D'
    $form.Controls.Add($rule)
}

function New-Button([string]$text, [int]$x) {
    $b = New-Object Windows.Forms.Button
    $b.Text = $text
    $b.SetBounds($x, 480, 100, 28)
    $form.Controls.Add($b)
    return $b
}
$backButton   = New-Button $T.Back 300
$nextButton   = New-Button $T.Next 404
$cancelButton = New-Button $T.Cancel 520

function New-Page {
    $p = New-Object Windows.Forms.Panel
    $p.SetBounds(20, 85, 600, 370)
    $p.Visible = $false
    $form.Controls.Add($p)
    return $p
}
function Add-Label($page, [string]$text, [int]$y, [int]$height = 20, [int]$x = 0) {
    $l = New-Object Windows.Forms.Label
    $l.Text = $text
    $l.SetBounds($x, $y, 600 - $x, $height)
    $page.Controls.Add($l)
    return $l
}
function Add-Check($page, [string]$text, [int]$y, [bool]$bold = $false) {
    $box = New-Object Windows.Forms.CheckBox
    $box.Text = $text
    $box.SetBounds(0, $y, 590, 24)
    if ($bold) { $box.Font = New-Object Drawing.Font 'Segoe UI', 9, ([Drawing.FontStyle]::Bold) }
    $page.Controls.Add($box)
    return $box
}
function Add-Radio($page, [string]$text, [int]$y) {
    $r = New-Object Windows.Forms.RadioButton
    $r.Text = $text
    $r.SetBounds(0, $y, 580, 24)
    $page.Controls.Add($r)
    return $r
}

# page 0: welcome
$pageWelcome = New-Page
Add-Label $pageWelcome $T.Welcome1 0 60 | Out-Null
Add-Label $pageWelcome $T.Welcome2 64 44 | Out-Null
Add-Label $pageWelcome $T.Welcome3 112 22 | Out-Null
$radioCreate = Add-Radio $pageWelcome $T.ModeCreate 160
$radioCreate.Checked = $true
$radioRemove = Add-Radio $pageWelcome $T.ModeRemove 186
Add-Label $pageWelcome $T.ClickNext 280 22 | Out-Null

# page 1: game folder
$pageFolder = New-Page
Add-Label $pageFolder $T.FolderAsk 0 22 | Out-Null
$folderBox = New-Object Windows.Forms.TextBox
$folderBox.SetBounds(0, 30, 480, 24)
$pageFolder.Controls.Add($folderBox)
$browseButton = New-Object Windows.Forms.Button
$browseButton.Text = $T.Browse
$browseButton.SetBounds(488, 28, 110, 28)
$pageFolder.Controls.Add($browseButton)
$folderStatus = Add-Label $pageFolder '' 70 80

# page 2: scaling
$pageScale = New-Page
$scaleIntro = Add-Label $pageScale '' 0 44
$scaleRadios = @{}
$y = 52
foreach ($s in 2, 3, 4) {
    $text = $T.ScaleOption -f $s, [math]::Floor($screen.Width / $s), [math]::Floor($screen.Height / $s)
    if ($s -eq $autoScale) { $text += $T.Recommended }
    $scaleRadios[$s] = Add-Radio $pageScale $text $y
    $y += 28
}
$setProfileBox = Add-Check $pageScale $T.SetProfile 150
$setProfileBox.Checked = $true
$scaleNote = Add-Label $pageScale $T.ScaleNote 184 60

# page 3: the steps (each can be done on its own, a cancelled one goes on
# where it stopped)
$pageParts = New-Page
Add-Label $pageParts $T.StepsIntro 0 40 | Out-Null
$imagesBox  = Add-Check $pageParts $T.Step1 46 $true
$imagesNote = Add-Label $pageParts '' 70 22 20
$videosBox  = Add-Check $pageParts $T.Step2 100 $true
$videosNote = Add-Label $pageParts '' 124 40 20
$terrainBox  = Add-Check $pageParts $T.Step3 170 $true
$terrainNote = Add-Label $pageParts '' 194 22 20
$spritesBox  = Add-Check $pageParts $T.Step4 224 $true
$spritesBox.Enabled = $false
Add-Label $pageParts $T.Step4Later 248 22 20 | Out-Null
$forceBox  = Add-Check $pageParts $T.Force 276
$partsNote = Add-Label $pageParts '' 304 66

# page 4: progress
$pageRun = New-Page
$runStatus = Add-Label $pageRun $T.Starting 0 22
$progress = New-Object Windows.Forms.ProgressBar
$progress.SetBounds(0, 28, 598, 24)
$progress.Maximum = 1000
$pageRun.Controls.Add($progress)
$logBox = New-Object Windows.Forms.TextBox
$logBox.Multiline  = $true
$logBox.ReadOnly   = $true
$logBox.ScrollBars = 'Vertical'
$logBox.Font       = New-Object Drawing.Font 'Consolas', 8.5
$logBox.SetBounds(0, 64, 598, 302)
$pageRun.Controls.Add($logBox)

# page 5: done
$pageDone = New-Page
$doneText = Add-Label $pageDone '' 0 170
$startGameBox = Add-Check $pageDone $T.StartGame 190

$pages = @($pageWelcome, $pageFolder, $pageScale, $pageParts, $pageRun, $pageDone)

# --- state ------------------------------------------------------------------------
$script:page       = 0
$script:info       = $null
$script:process    = $null
$script:logFile    = $null
$script:logPos     = 0
$script:result     = $null
$script:videoIndex = 0
$script:videoTotal = 0
# what is done per scaling: @{ bilder = @(done, total); videos = @(done, total) }
$script:status     = @{}

function Get-SelectedScale { foreach ($s in 2, 3, 4) { if ($scaleRadios[$s].Checked) { return $s } }; return 3 }

function Update-FolderStatus {
    $script:info = Get-GameInfo $folderBox.Text.Trim()
    $script:status = @{}
    if ($script:info) {
        $folderStatus.ForeColor = [Drawing.Color]::DarkGreen
        $text = $T.FolderOk -f $script:info.Language
        if (Test-Path (Join-Path $script:info.Data 'redux_hires')) { $text += "`n" + $T.FolderHasHD }
        $folderStatus.Text = $text
    } else {
        $folderStatus.ForeColor = [Drawing.Color]::DarkRed
        $folderStatus.Text = $T.FolderBad
    }
    $nextButton.Enabled = [bool]$script:info
}

function Get-StepStatus([int]$s) {
    if ($script:status.ContainsKey($s)) { return $script:status[$s] }
    $form.Cursor = 'WaitCursor'
    $partsNote.Text = $T.Checking
    $form.Refresh()
    $psi = New-Object Diagnostics.ProcessStartInfo 'powershell.exe', `
        "-NoProfile -ExecutionPolicy Bypass -File `"$engine`" -Install `"$($script:info.Folder)`" -Scale $s -Status"
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow  = $true
    $psi.RedirectStandardOutput = $true
    $p = [Diagnostics.Process]::Start($psi)
    $out = $p.StandardOutput.ReadToEnd()
    $p.WaitForExit()
    $result = @{ bilder = @(0, 0); videos = @(0, 0); gelaende = @(0, 0) }
    foreach ($m in [regex]::Matches($out, '##STATUS (\w+) (\d+) (\d+)')) {
        $result[$m.Groups[1].Value] = @([int]$m.Groups[2].Value, [int]$m.Groups[3].Value)
    }
    $form.Cursor = 'Default'
    $script:status[$s] = $result
    return $result
}

function Get-StepText($counts, [string]$what) {
    if ($counts[1] -eq 0) { return $T.StateNone }
    if ($counts[0] -ge $counts[1]) { return $T.StateDone -f $counts[1], $what }
    if ($counts[0] -eq 0) { return $T.StateOpen -f $counts[1], $what }
    return $T.StatePart -f $counts[0], $counts[1], $what
}

function Test-StepDone($counts) { return $counts[1] -gt 0 -and $counts[0] -ge $counts[1] }

# the steps of a scaling that are still open, as text
function Get-OpenSteps([int]$s) {
    $st = Get-StepStatus $s
    $open = @()
    if (-not (Test-StepDone $st.bilder)) { $open += $T.Step1 }
    if ((Find-Ffmpeg $script:info) -and -not (Test-StepDone $st.videos)) { $open += $T.Step2 }
    if (-not (Test-StepDone $st.gelaende)) { $open += $T.Step3 }
    return $open
}

function Update-Parts {
    $s = Get-SelectedScale
    $f = ($s * $s) / 9.0
    $st = Get-StepStatus $s
    $imagesDone = Test-StepDone $st.bilder
    $videosDone = Test-StepDone $st.videos
    $terrainDone = Test-StepDone $st.gelaende
    $hasFfmpeg  = Find-Ffmpeg $script:info

    $imagesNote.Text = $T.Step1Note -f (Get-StepText $st.bilder $T.Images), [int](660 * $f)
    $videosBox.Enabled = $hasFfmpeg
    $videosNote.Text = if ($hasFfmpeg) { $T.Step2Note -f (Get-StepText $st.videos $T.Videos), [int](390 * $f) } else { $T.NoFfmpeg }
    $terrainNote.Text = $T.Step3Note -f (Get-StepText $st.gelaende $T.Terrain), [int](25 * $f)

    # only the next open step is ticked, so a slow computer does one at a time
    $imagesBox.Checked  = -not $imagesDone
    $videosBox.Checked  = $hasFfmpeg -and $imagesDone -and -not $videosDone
    $terrainBox.Checked = $imagesDone -and ($videosDone -or -not $hasFfmpeg) -and -not $terrainDone

    $notes = @()
    if ($imagesDone -and ($videosDone -or -not $hasFfmpeg) -and $terrainDone) { $notes += $T.AllDone }
    $tool = Get-ChildItem -Path (Join-Path $script:info.Data 'redux_hires\_werkzeug') -Recurse -Filter 'realesrgan-ncnn-vulkan.exe' -ErrorAction SilentlyContinue
    if (-not $tool) { $notes += $T.EsrganDownload }
    try {
        $drive = New-Object IO.DriveInfo ([IO.Path]::GetPathRoot($script:info.Folder))
        $notes += $T.FreeSpace -f $drive.Name, [int]($drive.AvailableFreeSpace / 1GB)
    } catch { }
    $notes += $T.GpuNote
    $partsNote.Text = $notes -join "`n"
    Update-CreateButton
}

function Update-CreateButton {
    if ($script:page -eq 3) { $nextButton.Enabled = $imagesBox.Checked -or $videosBox.Checked -or $terrainBox.Checked }
}

function Show-Page([int]$n) {
    $script:page = $n
    for ($i = 0; $i -lt $pages.Count; $i++) { $pages[$i].Visible = ($i -eq $n) }
    $headTitle.Text = $T.Heads[$n][0]
    if ($T.Heads[$n][1]) { $headText.Text = $T.Heads[$n][1] }
    $backButton.Enabled   = ($n -ge 1 -and $n -le 3)
    $nextButton.Enabled   = $true
    $nextButton.Text      = $T.Next
    $cancelButton.Enabled = $true
    $cancelButton.Text    = $T.Cancel
    switch ($n) {
        1 { Update-FolderStatus }
        2 {
            $current = switch ($script:info.ProfileScale) {
                $null   { $T.ScaleNone }
                0       { $T.ScaleAuto -f $autoScale }
                -1      { $T.ScaleOff }
                default { $T.ScaleFixed -f $script:info.ProfileScale }
            }
            $scaleIntro.Text = $T.ScaleIntro -f $screen.Width, $screen.Height, $autoScale, $current
            $wanted = if ($script:info.ProfileScale -ge 2) { $script:info.ProfileScale } elseif ($autoScale -ge 2) { $autoScale } else { 2 }
            if (-not ($scaleRadios.Values | Where-Object { $_.Checked })) { $scaleRadios[[int]$wanted].Checked = $true }
            $setProfileBox.Enabled = [bool]$script:info.Profile
            if (-not $script:info.Profile) { $setProfileBox.Checked = $false }
        }
        3 { $nextButton.Text = $T.Create; Update-Parts }
        4 { $nextButton.Enabled = $false }
        5 {
            $backButton.Enabled   = $false
            $cancelButton.Enabled = $false
            $nextButton.Text      = $T.Finish
        }
    }
}

# --- running the work script --------------------------------------------------------
$oem = [Text.Encoding]::GetEncoding([Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage)

function Set-Progress([double]$fraction) {
    $progress.Value = [int]([math]::Max(0, [math]::Min(1, $fraction)) * 1000)
}

function Read-Log {
    if (-not $script:logFile -or -not (Test-Path $script:logFile)) { return }
    $stream = [IO.File]::Open($script:logFile, 'Open', 'Read', 'ReadWrite')
    try {
        if ($stream.Length -le $script:logPos) { return }
        $stream.Position = $script:logPos
        $bytes = New-Object byte[] ($stream.Length - $script:logPos)
        $read = $stream.Read($bytes, 0, $bytes.Length)
        # only whole lines; the rest comes with the next tick
        $last = [Array]::LastIndexOf($bytes, [byte]10, $read - 1)
        if ($last -lt 0) { return }
        $script:logPos += $last + 1
        $text = $oem.GetString($bytes, 0, $last + 1)
    } finally { $stream.Close() }

    # the share of each chosen step: images a few minutes, terrain about one,
    # videos most of the time
    $weights = @(@($imagesBox.Checked, 1.0), @($terrainBox.Checked, 0.5), @($videosBox.Checked, 4.0))
    $sum = 0.0; foreach ($w in $weights) { if ($w[0]) { $sum += $w[1] } }
    $segments = @(); $at = 0.0
    foreach ($w in $weights) {
        $share = if ($w[0] -and $sum -gt 0) { $w[1] / $sum } else { 0.0 }
        $segments += ,@($at, $share); $at += $share
    }
    foreach ($l in ($text -split "`r?`n")) {
        if ($l -match '^##FORTSCHRITT (\S+) (\d+) (\d+)') {
            $part = $Matches[1]; $done = [int]$Matches[2]; $total = [math]::Max(1, [int]$Matches[3])
            $f = $done / $total
            switch ($part) {
                'vorbereiten' { $runStatus.Text = $T.RunPrepare -f $done, $total; Set-Progress ($segments[0][0] + 0.1 * $f * $segments[0][1]) }
                'bilder'      { $runStatus.Text = $T.RunImages -f [int](100 * $f);  Set-Progress ($segments[0][0] + (0.1 + 0.8 * $f) * $segments[0][1]) }
                'einlesen'    { $runStatus.Text = $T.RunImport -f $done, $total;  Set-Progress ($segments[0][0] + (0.9 + 0.1 * $f) * $segments[0][1]) }
                'gelaende'    { $runStatus.Text = $T.RunTerrain -f [int](100 * $f); Set-Progress ($segments[1][0] + $f * $segments[1][1]) }
                'videos'      { $script:videoIndex = $done; $script:videoTotal = $total }
                'videobilder' { $runStatus.Text = $T.RunVideo -f ($script:videoIndex + 1), $script:videoTotal, $done, $total }
            }
            if ($part -eq 'videos' -or $part -eq 'videobilder') {
                $inner = if ($part -eq 'videobilder') { $f } else { 0 }
                Set-Progress ($segments[2][0] + $segments[2][1] * ($script:videoIndex + $inner) / [math]::Max(1, $script:videoTotal))
            }
        } elseif ($l.Trim()) {
            $logBox.AppendText($l.TrimEnd() + "`r`n")
            if ($l -match '^(FEHLER|ERROR): (.*)') { $script:result = $Matches[2] }
        }
    }
}

$timer = New-Object Windows.Forms.Timer
$timer.Interval = 400
$timer.add_Tick({
    Read-Log
    if ($script:process -and $script:process.HasExited) {
        $timer.Stop()
        Read-Log
        $code = $script:process.ExitCode
        $script:process = $null
        Complete-Run ($code -eq 0)
    }
})

function Start-Run {
    $s = Get-SelectedScale
    if ($setProfileBox.Checked -and $script:info.Profile) {
        # the game profile is Latin-1
        $latin1 = [Text.Encoding]::GetEncoding(28591)
        $text = [IO.File]::ReadAllText($script:info.Profile, $latin1)
        if ($text -match '(?m)^DisplayScale=-?\d+') { $text = $text -replace '(?m)^DisplayScale=-?\d+', "DisplayScale=$s" }
        else { $text = $text.TrimEnd() + "`r`nDisplayScale=$s`r`n" }
        [IO.File]::WriteAllText($script:info.Profile, $text, $latin1)
        $script:info.ProfileScale = $s
    }

    $script:logFile = Join-Path $env:TEMP "ctp2-redux-hd-$PID.log"
    Remove-Item $script:logFile -ErrorAction SilentlyContinue
    $script:logPos     = 0
    $script:result     = $null
    $script:videoIndex = 0
    $script:videoTotal = 0
    $logBox.Clear()
    $runStatus.Text = $T.Starting
    Set-Progress 0

    $flags = "-Scale $s -Language $lang"
    if (-not $imagesBox.Checked) { $flags += ' -NoImages' }
    if (-not $videosBox.Checked) { $flags += ' -NoVideos' }
    if (-not $terrainBox.Checked) { $flags += ' -NoTerrain' }
    if ($forceBox.Checked)       { $flags += ' -Force' }
    $command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$engine`" -Install `"$($script:info.Folder)`" $flags > `"$($script:logFile)`" 2>&1"
    $psi = New-Object Diagnostics.ProcessStartInfo 'cmd.exe', "/c `"$command`""
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow  = $true
    $script:process = [Diagnostics.Process]::Start($psi)
    $timer.Start()
}

function Stop-Run {
    if ($script:process -and -not $script:process.HasExited) {
        & taskkill.exe /T /F /PID $script:process.Id 2>&1 | Out-Null
        $script:process.WaitForExit(5000) | Out-Null
    }
    $timer.Stop()
    $script:process = $null
    Start-Sleep -Milliseconds 500
    Remove-Item -Recurse -Force (Join-Path $script:info.Data 'redux_hires\_arbeit') -ErrorAction SilentlyContinue
}

function Complete-Run([bool]$ok) {
    Set-Progress 1
    $s = Get-SelectedScale
    if ($ok) {
        $headText.Text = $T.DoneOk
        $text = $T.DoneWhere -f $s, (Join-Path $script:info.Data "redux_hires\$($s)x")
        $script:status.Remove($s)
        $open = @(Get-OpenSteps $s)
        $text += if ($open.Count) { $T.DoneOpen -f ($open -join ', ') } else { $T.DoneAll }
        $doneText.Text = $text
    } else {
        $headText.Text = $T.DoneFail
        $reason = if ($script:result) { $script:result } else { $T.SeeLog }
        $doneText.Text = $T.DoneFailText -f $reason, $script:logFile
    }
    $startGameBox.Enabled = [bool]$script:info.Exe
    $startGameBox.Checked = $ok -and [bool]$script:info.Exe
    Show-Page 5
}

function Remove-HD {
    $hires = Join-Path $script:info.Data 'redux_hires'
    if (-not (Test-Path $hires)) {
        $headText.Text = $T.NoHD
        $doneText.Text = $T.NoHDText
    } else {
        $answer = [Windows.Forms.MessageBox]::Show($form, ($T.RemoveAsk -f $hires), $title, 'YesNo', 'Question')
        if ($answer -ne 'Yes') { return }
        $form.Cursor = 'WaitCursor'
        Remove-Item -Recurse -Force $hires
        $form.Cursor = 'Default'
        $headText.Text = $T.Removed
        $doneText.Text = $T.RemovedText
    }
    $startGameBox.Enabled = [bool]$script:info.Exe
    $startGameBox.Checked = $false
    Show-Page 5
}

# --- buttons ----------------------------------------------------------------------
$browseButton.add_Click({
    $dialog = New-Object Windows.Forms.FolderBrowserDialog
    $dialog.Description = $T.BrowseTitle
    if ($folderBox.Text -and (Test-Path $folderBox.Text)) { $dialog.SelectedPath = $folderBox.Text }
    if ($dialog.ShowDialog($form) -eq 'OK') { $folderBox.Text = $dialog.SelectedPath }
})
$folderBox.add_TextChanged({ Update-FolderStatus })
foreach ($r in $scaleRadios.Values) { $r.add_CheckedChanged({ if ($script:page -eq 3) { Update-Parts } }) }
$imagesBox.add_CheckedChanged({ Update-CreateButton })
$videosBox.add_CheckedChanged({ Update-CreateButton })
$terrainBox.add_CheckedChanged({ Update-CreateButton })

$backButton.add_Click({ if ($script:page -gt 0) { Show-Page ($script:page - 1) } })

$nextButton.add_Click({
    switch ($script:page) {
        0 { Show-Page 1 }
        1 { if ($radioRemove.Checked) { Remove-HD } else { Show-Page 2 } }
        2 { Show-Page 3 }
        3 {
            Show-Page 4
            Start-Run
        }
        5 {
            if ($startGameBox.Checked -and $script:info.Exe) {
                Start-Process -FilePath $script:info.Exe -WorkingDirectory (Split-Path $script:info.Exe)
            }
            $form.Close()
        }
    }
})

$cancelButton.add_Click({
    if ($script:page -eq 4 -and $script:process) {
        $answer = [Windows.Forms.MessageBox]::Show($form, $T.CancelAsk, $title, 'YesNo', 'Question')
        if ($answer -ne 'Yes') { return }
        Stop-Run
        $headText.Text = $T.Cancelled
        $doneText.Text = $T.CancelledText
        $startGameBox.Enabled = $false
        $startGameBox.Checked = $false
        Show-Page 5
    } else {
        $form.Close()
    }
})

$form.add_FormClosing({
    param($source, $e)
    if ($script:process -and -not $script:process.HasExited) {
        $answer = [Windows.Forms.MessageBox]::Show($form, $T.CloseAsk, $title, 'YesNo', 'Warning')
        if ($answer -ne 'Yes') { $e.Cancel = $true; return }
        Stop-Run
    }
})

# --- start ------------------------------------------------------------------------
if (-not (Test-Path $engine)) {
    [Windows.Forms.MessageBox]::Show($T.EngineMissing, $title, 'OK', 'Error') | Out-Null
    exit 1
}
$folderBox.Text = Find-GameFolder
Show-Page 0
Set-DpiScale $form
if ($Screenshots) {
    # every page once, drawn off screen
    $form.StartPosition = 'Manual'
    $form.Location = New-Object Drawing.Point -20000, -20000
    $form.add_Shown({
        New-Item -ItemType Directory -Force $Screenshots | Out-Null
        function Save-Shot([string]$name) {
            $form.Refresh()
            $bitmap = New-Object Drawing.Bitmap $form.Width, $form.Height
            $form.DrawToBitmap($bitmap, (New-Object Drawing.Rectangle 0, 0, $form.Width, $form.Height))
            $bitmap.Save((Join-Path $Screenshots "$lang-$name.png"))
            $bitmap.Dispose()
        }
        Save-Shot '0-welcome'
        Show-Page 1; Save-Shot '1-folder'
        Show-Page 2; Save-Shot '2-scale'
        Show-Page 3; Save-Shot '3-steps'
        # a real run of step 1 (quick when its files exist), profile untouched
        $imagesBox.Checked = $true
        $videosBox.Checked = $false
        $terrainBox.Checked = $false
        $setProfileBox.Checked = $false
        Show-Page 4
        Start-Run
        $shot = $false
        while ($script:process -or $script:page -eq 4) {
            [Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 100
            if (-not $shot -and $logBox.Text.Length -gt 0) { Save-Shot '4-run'; $shot = $true }
        }
        Save-Shot '5-done'
        $form.Close()
    })
}
[void]$form.ShowDialog()
