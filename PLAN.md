# Call to Power II – Modern-PC-Fork: Plan

Stand: 2026-10-27. Fork von github.com/civctp2/civctp2 (Apolyton Edition).
Arbeitsbranch: `redux` (master bleibt Spiegel von upstream).

## Ziele

1. Läuft auf heutigen Windows-PCs (x64, hohe Auflösungen, ohne Bastelei).
2. Multiplayer funktioniert wieder: LAN und Internet per direkter IP, ohne die
   abgeschalteten Activision-Lobbyserver.
3. Grafiken und Videos hochskaliert (lokal per KI erzeugt, nie im Repo).

## Rechtlicher Rahmen (LICENSE.md, Activision-EULA 2003)

- Nur privat und nicht-kommerziell. Kein Verkauf, keine Spenden-Pakete.
- Die Spieldaten (ctp2_data, Videos, Musik) gehören nicht zum Quellcode und
  dürfen nicht verteilt werden. Jeder Spieler braucht seine eigene Kopie
  (GOG oder CD).
- Deshalb: hochskalierte Assets werden **nie** ins Repo oder in Releases
  gepackt. Das Repo liefert nur Werkzeuge und Skripte, die aus der eigenen
  Installation lokal ein hochskaliertes Asset-Set erzeugen.

## Umgebung auf diesem PC

| Was | Wo |
|---|---|
| Quellcode | D:\ctp2 |
| Original (GOG) | E:\GOG Games\Call To Power 2 |
| Build-Skript | `pwsh tools/win-build.ps1` (ohne Adminrechte) |
| Ergebnis | ctp2_code\ctp\x64\ctp2.exe (Final-SDL, x64) |
| Lokale Hilfsdateien | D:\ctp2\_local (NASM, VC-Targets, Logs, nicht im Git) |
| Spieldaten im Arbeitsverzeichnis | ctp2_data, Scenarios, ctp2_code/ctp/music (aus GOG kopiert, git-ignoriert) |

Fensterbetrieb zum Testen: `ctp2_code\ctp\x64\userprofile.txt` mit
`WindowedMode=Yes`, `ScreenResWidth/Height`.

## Phase 1 – Build und Lauffähigkeit (erledigt 2026-10-27)

- [x] Klon, Build-Umgebung ohne Admin (NASM, lokale VC-Targets, CDKDIR, D:\tmp)
- [x] MSVC-14.44-Fixes: Anet comm*-Prototypen, FFmpeg `max_align_t`
- [x] Final-SDL x64 baut und startet (Intro-Video läuft über FFmpeg)
- [ ] Fork auf GitHub anlegen, Branch `redux` pushen (braucht `gh auth login`)
- [ ] CI-Workflow (GitHub Actions, windows-latest) für den Windows-Build
- [ ] Spielstart ohne userprofile.txt prüfen: sinnvolle Standardauflösung
      (Desktop-Auflösung, Fenster statt Vollbild beim ersten Start)
- [ ] Bekannte Win-11-Probleme aus upstream prüfen (Issue #432 „Freezing“)

## Phase 2 – Multiplayer

Befund (Code-Analyse 2026-10-27):
- Nichts ist abgeschaltet. Der Multiplayer-Button (`ui/interface/initialplayscreen.cpp`)
  führt in die Netshell (`ui/netshell/`), die über NETFunc die Anet-Bibliothek
  (`libs/anet`, `anet2.dll`) ansteuert.
- Transporte sind DLLs, gebaut nach `x64\dll\net\`: `winets2.dll` = „Internet“
  (UDP, zufälliger Port 21100–21299), `wudplan.dll` = „TCP/IP LAN“ (UDP 21157,
  Broadcast), `wipx2.dll` = IPX (auf heutigem Windows nutzlos).
  Gesucht werden sie zur Laufzeit in `<exe>\dll\net\` (`civapp.cpp` setzt
  `NETFunc::s_DllPath`), der Build-Ausgabeort passt also.
- LAN braucht keinen Server: ohne Antwort auf den Broadcast erstellt der
  Client selbst die Lobby-Sitzung.
- Internet braucht zwingend einen Anet-Gameserver: Liste aus `bootserv.txt`
  oder eingebaute Defaults (`libs/anet/src/dp/enumsrv2.c`), dann
  `dpSetGameServerEx` + `dpOpen`. Es gibt kein Eingabefeld für eine IP.
  Anet selbst kann per Adresse beitreten (`dpResolveHostname` + `dpOpen`
  mit `adrMaster`, Muster in `dp2.c` beim `-a=`-Startparameter), die Netshell
  nutzt das nur nicht.
- 32-Bit- und 64-Bit-Builds können nicht miteinander spielen (Paketgrößen,
  `recordLen`-Prüfung der Transporte). Netshell-Pakete kopieren rohe
  native Typen (`netfunc.h` Push/Pop).
- Lokale IP kommt aus `gethostname`/`gethostbyname` (`wstcp.c`): bei VPN-
  oder Hyper-V-Adaptern wird leicht das falsche Interface gewählt.
- Kein NAT-Traversal. Der Host muss seinen UDP-Port weiterleiten.
- Server-Quellcode liegt bei: `libs/anet/src/linux/server/` (Linux, UDP 21157).
  Session-Typ-Abweichung beachten: Spiel sendet Typ 0, `anet.inf` sagt 1504.

Stand 2026-10-27 (abends): **Direktverbindung bis in die Lobby funktioniert**
(zwei Instanzen auf einem PC, Host über „Spiel hosten“, Client über
„Beitreten“ mit 127.0.0.1:21157; beide sehen sich, Ping 20 ms).
Nebenbefund: die drei Anet-Community-Server (911.alink.bz911.net,
alink.iondriver.com, play.interstate76.com) antworten noch, der klassische
Serverweg ist also ebenfalls einen Test wert.

Kernproblem, das dafür gelöst wurde: Anet identifiziert Mitspieler über
Adressen, die sie selbst über sich melden (öffentlich, LAN), nicht über die
Verbindung, über die sie erreichbar sind. Ein Rechner tritt so unter bis zu
drei Adressen auf und bekam mehrere Verbindungen, die sich gegenseitig
zurücksetzten. Regel jetzt in `libs/anet/src/dp/dpio.c`: ein Rechner = die
Menge aller Adressen, unter denen er je aufgetreten ist (Alias-Liste je
Verbindung, Verlauf der eigenen Adressen, SYN-Dubletten per Paketnummer,
Zielportprüfung statt exakter Adresse). Dazu in `dp2.c`: Sitzungsmaster wird
über die getippte Adresse angesprochen, eigener Eintrag wird auch über
frühere eigene Adressen erkannt.

Plan:
1. **Spielstart über Direktverbindung testen:** Host erstellt Spiel aus der
   Lobby, Client tritt bei, Start, erste Runden. Dann Test mit LAN-Adresse
   statt 127.0.0.1 und ein echter Test über zwei Anschlüsse.
2. **Direkte IP – Rest:** eigene Adresse im Fenster zeigt die lokale
   Adresse; hinter einem Router muss der Host seine öffentliche IP selbst
   kennen (Hinweistext). Eigener Ping in der Lobby zeigt 2000 (kosmetisch).
3. **Robustheit:** feste Pakettypen (sint32 statt long/bool/enum) in den
   Netshell-Paketen; Interface-Wahl bei mehreren Adaptern; nur x64 ausliefern.
4. **Optional Serverbrowser:** eigenen Anet-Server betreiben und in
   `bootserv.txt` eintragen; nötig nur, wenn Spiele öffentlich gelistet
   werden sollen. Alternative ohne Code: VPN mit Broadcast (ZeroTier/Radmin)
   + LAN-Modus.
5. **Desync-Test:** gleiche Partie über viele Runden, `net_crc`-Prüfungen
   beobachten, SLIC-Stände von Host und Client gleich halten.

## Phase 3 – Hochskalierte Grafik

Befund (Code-Analyse 2026-10-27):
- Gesamter Renderpfad ist 16 Bit (555/565), fest verdrahtet in
  `ctp/civ3_main.cpp` (C3UI mit 16 bpp).
- Kachelgröße ist Compile-Konstante: 94x72 Raster, 94x48 Raute
  (`gfx/tilesys/tileset.h`), rund 230 Verwendungen. Zoomstufen sind feste
  Pixeltabellen (`gfx/tilesys/tiledmap.cpp`), Sprites werden nur
  **herunter**skaliert (Bresenham), nie hoch.
- Sprites (.spr): RLE in 16-Bit-Wörtern, Lauflänge 8 Bit, Zeilenoffsets u16,
  pro Sprite Vollbild + halbe „Mini“-Version. Einheiten 96x72.
- Tiles (.til): rohe 16-Bit-Pixel, Längenfelder u16. Quellen liegen als
  TGA im Repo: `ctp2_data/default/graphics/tiles/gtset/` (807 TGAs) +
  `gtset.src` → .til lässt sich neu bauen.
- UI-Bilder: lose .tga überschreiben .rim aus den .zfs-Paketen (kein
  Umpacken nötig). Layouts (.ldl) in absoluten Pixeln, Hintergründe
  1024x768.
- Videos: Indeo 5, 320x192, 15 fps, Wiedergabe über FFmpeg
  (`ui/aui_sdl/aui_sdlmovie.cpp`), jedes FFmpeg-Format spielbar, wird aufs
  Zielrechteck skaliert.

Stufenplan:
1. **Videos (schnellster Gewinn):** Skript `tools/upscale/videos.py`:
   AVI → PNG-Frames → Real-ESRGAN/Video-Upscaler (RTX 5090, lokal) →
   H.264/HEVC 1280x768 (4x). Ablage in `ctp2_data/default/videos/` der
   eigenen Installation. Code: Rechtecke in `wondermovie.ldl`/`intromovie.ldl`
   vergrößern bzw. Videofenster an Bildschirm koppeln.
2. **UI-Grafiken 2x:** .rim aus pic555/565.zfs entpacken (ReadZFS oder
   eigener Python-Reader, Format ist trivial), per ESRGAN 2x, als .tga
   ablegen. Code: globaler UI-Skalierungsfaktor (Layout-Pixel × Faktor,
   Fonts × Faktor), 16-Bit bleibt vorerst.
3. **Terrain 2x:** TGAs in `gtset/` hochskalieren, `gtset.src` neu
   einlesen → .til. Code: `k_TILE_*` und Zoomtabellen auf Laufzeitwerte
   × Asset-Skalierung umstellen; 2x passt noch in die u16-Felder.
4. **Sprites 2x:** Export per eingebautem Sprite-Editor/Konsolenbefehl
   (`c3cmdline.cpp`, `runspriteeditor`) → TGA-Frames → ESRGAN → neu
   kodieren. Encoder muss Läufe > 255 Pixel teilen; Hotpoints/Offsets
   skalieren. Für 4x braucht es ein neues .spr/.til-Format mit u32-Feldern.
5. **Optional 32 Bit:** großer Umbau (pixelutils, SpriteLow555/565,
   tiledraw-Assembler, Blitter). Erst nach 2x.

Vorgabe des Besitzers (2026-10-27): **ein Skript, das den Pfad der
Spielinstallation bekommt und das Upscaling vor Ort beim Spieler
durchführt.** Wir bieten selbst keine Grafiken oder Videos an. Das Skript
muss also beim Spieler lauffähig sein (Windows, Python-frei oder mit
mitgeliefertem Runtime, GPU optional mit CPU-Fallback), prüft die
Installation, legt Sicherungen an und schreibt nur in die eigene
Installation. Die deutsche Fassung (Texte, Videos im Sprachordner) wird dabei
genauso behandelt wie die englische.

KI-Hochskalierung für die Entwicklung läuft lokal in D:\AI (vorhandene
Tools). Modelle und Lizenzen vor Nutzung prüfen (Real-ESRGAN: BSD-3), damit
das Skript die Modelle beim Spieler nachladen darf.

## Vanilla-Optik (Entscheidung 2026-10-27)

Besitzer-Vorgabe: Das Spiel soll aussehen wie das Original (Titelbild,
Menüs, Hinweistexte, Branding, Oberfläche), Apolyton-Bugfixes bleiben.
Entschieden: **Optik vanilla, Regeln Apolyton.** KI-Verbesserungen und die
Regeloptionen bleiben (Standardwerte sind seit 2009 ohnehin Original),
Oberfläche und Branding gehen auf Originalstand. Unsere eigenen Ergänzungen
(Direktverbindung) fügen sich in den Vanilla-Stil ein.

Apolyton-Änderungen zur Orientierung (Analyse 2026-10-27): 66 von 74
Regeldateien, alle 14 KI-Dateien, 102 neue Oberflächendateien geändert bzw.
neu; neue Regeloptionen, 8 neue Völker, Mausrad, politische Minikarte,
Bauanzeige, neue Diagramme, Apolyton-Titelbild und Disclaimer.
Originalspielstände (Patch 1.1) lassen sich laden. Multiplayer gegen die
Originalversion ist nicht möglich, alle brauchen denselben Build.

Aufgaben:
1. Liste der Apolyton-Oberflächenänderungen erstellen (Titelbild, Menü-
   Layouts, Strings mit „Apolyton“, neue Fenster) und je Punkt entscheiden:
   zurück auf Original oder behalten (reine Komfortfunktionen wie Mausrad
   bleiben, sichtbares Branding geht).
2. Originalgrafiken für Titel und Menüs aus der eigenen Installation nutzen
   (nicht ins Repo), Layouts entsprechend anpassen.

## Offene Fragen an den Besitzer

- GitHub-Login für den Fork (`gh auth login`).
- Zielauflösung für Videos (1280x768 = 4x, oder 1920x1152 = 6x)?
- Zweiter PC/Laptop im LAN für echte Multiplayer-Tests vorhanden?
