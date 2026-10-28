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

Stand 2026-10-27 (spät): **erstes Spiel über Direktverbindung läuft** (Debug-
Build, zwei Instanzen auf einem PC): Beitritt, Start, Städte gegründet, mehrere
Runden, Zugreihenfolge auf beiden Seiten gleich, Erträge beim Client, keine
Heap- oder Datenbank-Abgleichsfehler. Behobene Ursachen: Netshell-`Message`
ohne Kopierschutz (Doppelfreigabe beim Beitritt), fehlgeschlagene
Verbindung wurde als verbunden behandelt (Hänger bei „TCP/IP LAN“ mit zwei
Instanzen), Debug-only Pufferüberlauf beim Kartengenerator-Namen.
Das angezeigte Jahr ist der Rundenzähler des jeweils eigenen Spielers; bei
nacheinander laufenden Zügen weicht es um eine Runde ab, das ist normal.

Stand 2026-10-27 (Nacht): **Release-Version über Direktverbindung: über 50
Runden ohne Absturz** (Host `x64a\ctp2.exe`, Client `x64b\ctp2.exe`,
127.0.0.1:21157). Ursache des früheren Absturzes beim Spielstart mit einem
AddressSanitizer-Build des Clients gefunden: Kartenanzeige schrieb nach dem
Neuanlegen der Spieler in das freigegebene Sichtfeld des alten Spielers;
dazu doppelte Freigabe zusammengesetzter Netzwerkpakete. Offene harmlose
Lesefehler laut ASan: ThroneDB-Tokenizer, Chat-Textfeld, Karten-Icon-Encoder.
ASan-Build: `civctp.vcxproj` mit `-p:EnableASAN=true`, Ausgabe nach
`_local/asan/out`, Start über `_local/asan/start-client-asan.bat`.

Stand 2026-10-28: **Automatischer Multiplayer-Test** `tools/mptest.ps1`.
Startet Host und Client unsichtbar auf diesem PC (Kopien des Builds in
`ctp2_code/ctp/autotest_host` und `autotest_client`, ohne Ton), beide
klicken sich selbst durch Netshell und Spiel-Setup, beenden ihre Züge und
schreiben `autotest_result.txt`. Bestanden = beide erreichen die Runde, kein
Absturz/Hänger, keine CRC-Fehler, keine Resync-Anforderung.
`-Turns N -AIPlayers K -ShotEvery N -Show -Asan`. Spielseitig: Schalter
`autohost`, `autojoin=<adresse>`, `autoturns=`, `autoai=`, `autoname=`,
`autoshots=`, `autoshow` (`ctp/ctp2_utils/autotest.cpp`). Verlauf sichtbar
über Statuszeilen je Spieler und Runde (Städte, Einheiten, Gold,
Fortschritte) und `autotest_round_<nnn>.png` vom eigenen Zugbeginn, auch
bei verstecktem Fenster. Bedienung ausführlich im README. Die Testspieler
spielen einfache Züge (Stadt gründen, Einheiten ziehen, Bauschleife füllen,
Forschung wählen) über dieselben Aufrufe wie die Oberfläche, also auch
Client→Host-Aktionen. Desync-Prüfung: KI-Werte Host Runde N = Client Runde
N+1. Noch offen: Angriffe/Kämpfe, Diplomatie, Handel im Test; die
KI-Ansätze für einen Client-Roboterspieler (`CtpAi::NetworkClientBeginTurn`)
sind halb fertig, der KI-Planer läuft auf Clients nicht.

Geklärt (2026-10-28): Im Netzwerkspiel entwickeln sich alle Völker
langsamer als im Einzelspieler (je 3 Läufe à 40 Runden: KI 1,0 statt 2,1
Städte, 4,5 statt 6 Fortschritte). Ursache ist die Startausstattung, kein
Fehler: Im Netzwerk-Setup („Regeln“: „Gold:“ 100, „Siedler:“ 1) bekommt
jedes Volk gleich viele Startsiedler (`s_networkSettlers`, aus den
„PW points“ des Setups), im Einzelspieler bekommt die KI
`AIStartUnits` je nach Schwierigkeit plus einen Extra-Siedler bei
schlechter Startposition (`gameinit.cpp:449-477`). Wachstum, Nahrung,
Steuern, Bauschleifen und Zugbeginn laufen in beiden Modi gleich (gemessen
mit den Detailzeilen und Zählern je Zugbeginn). Entscheidung des Besitzers:
bleibt so (Vanilla); wer mehr will, stellt im Setup „Siedler:“ höher. Auch
im Einzelspieler gründet die KI in 40 Runden keine Stadt aus einem selbst
gebauten Siedler, der Anfang ist einfach langsam. Für den Schnelltest
reicht, dass die KI wirklich spielt. Unsichtbar heißt: verstecktes Fenster,
Software-Renderer ohne Present, kein Rand-Scrollen (die Maus liegt außerhalb
und `CivApp::ProcessUI` scrollte sonst endlos).

Stand 2026-10-28 (Mittag): **Direktverbindung ohne Chat-Lobby.** Host:
„Spiel hosten“ → Profil → Spiel-Setup; Client: „Beitreten“ → Profil →
Spiel-Setup des Hosts. Umgesetzt mit `NETFunc::DirectAuto`: Lobby,
Vorlagenauswahl und Passwortfrage drücken ihre Knöpfe einmal pro
Direktverbindung selbst („Erstellen“, „Neu“, kein Passwort bzw. „Beitreten“,
sobald das Spiel gelistet ist). Wer im Setup „Zurück“ wählt, bleibt in der
Lobby. Dabei behoben: ein Client, der nach dem Anlegen des Spiels kam, sah es
nie. Er legt mangels Lobby des Hosts eine eigene an und ist damit
„standalone master“; `dpRequestObjectDeltas` meldete dann nur die eigenen
Sitzungen, spätere Aktualisierungen des Hosts trugen identische Daten und
lösten nichts aus (`libs/anet/src/dp/deltas.c`, jetzt auch die bekannten
fremden Sitzungen). Gefunden mit `mptest.ps1 -AnetLog` (dp.log beider
Instanzen). Lobby und Vorlagenauswahl bleiben auf diesem Weg versteckt
(sichtbar erst wieder nach „Zurück“), ein wartender Client sieht den
Dialog „Lobby wird betreten“. Netzwerkmenü aufgeräumt (Wunsch des
Besitzers): IPX wird nicht mehr angeboten, die tote Activision-Serverliste
ist ausgeblendet, das Fenster heißt „Direktverbindung“ und zeigt nur Adresse
+ „Beitreten“, „Spiel hosten“ und die eigene Adresse (Knopfstil wie im
Spiel-Setup). TCP/IP-LAN, Hotseat und E-Mail bleiben. Der Test macht Bilder
vom Verbindungsfenster und vom Spiel-Setup (`autotest_connect.png`,
`autotest_setup.png`).

Plan:
1. **Weitere Tests:** LAN-Adresse statt 127.0.0.1, dann ein echter Test über
   zwei Anschlüsse (Port 21157 UDP weiterleiten).
2. ~~**Direkt ins Spiel-Setup (Wunsch des Besitzers):**~~ erledigt, s. o. Host
   „Spiel hosten“ → Profil → direkt Spiel-Setup (Spielsitzung sofort
   anlegen); Client „Beitreten“ → Profil → direkt ins Spiel-Setup des Hosts
   (erste Spielsitzung aus dem abonnierten Sitzungsverzeichnis). Serverweg
   behält die Lobby.
3. **Direkte IP – Rest:** eigene Adresse im Fenster zeigt die lokale
   Adresse; hinter einem Router muss der Host seine öffentliche IP selbst
   kennen (Hinweistext). Eigener Ping in der Lobby zeigt 2000 (kosmetisch).
4. **Robustheit:** feste Pakettypen (sint32 statt long/bool/enum) in den
   Netshell-Paketen; Interface-Wahl bei mehreren Adaptern; nur x64 ausliefern.
   „TCP/IP LAN“ mit zwei Instanzen auf einem PC scheitert am festen Port
   21157 (zweite Instanz bekommt jetzt sauber einen Netzwerkfehler).
5. **Optional Serverbrowser:** eigenen Anet-Server betreiben und in
   `bootserv.txt` eintragen; nötig nur, wenn Spiele öffentlich gelistet
   werden sollen. Alternative ohne Code: VPN mit Broadcast (ZeroTier/Radmin)
   + LAN-Modus.
6. **Desync-Test:** gleiche Partie über viele Runden, `net_crc`-Prüfungen
   beobachten, SLIC-Stände von Host und Client gleich halten.

### IPv6 (2026-10-28)

Für Anschlüsse ohne öffentliche IPv4 (DS-Lite) kann jetzt über IPv6 gehostet
und beigetreten werden. Umsetzung als Wrapper nur in der Internet-
Transport-DLL (`libs/anet/src/win/winets/wstcp.c`, `wstcpdll.c`), weil Anet
selbst feste 6-Byte-Adressen hat (`dp_MAX_ADR_LEN` 10, Schlüssel ≤ 12 Byte):
Dual-Stack-Socket (IPv4 kommt als `::ffff:a.b.c.d`), jede IPv6-Gegenstelle
bekommt eine Ersatzadresse 240.0.0.n (reserviert, im Netz nie vergeben),
eine Tabelle übersetzt zurück. Eingabe `[2a02:…]:21157` oder ohne Port,
Hostnamen über `getaddrinfo` (IPv4 bevorzugt). Das Verbindungsfenster zeigt
unter der IPv4- auch die globale IPv6-Adresse (Quelladresse des Systems für
IPv6-Internetverkehr). TCP/IP-LAN bleibt IPv4. Getestet mit `[::1]` und der
globalen IPv6 dieses PCs (`mptest.ps1 -JoinAddress`), dp.log bestätigt den
IPv6-Weg. Offen: echter Test über zwei Anschlüsse (Router muss UDP 21157
auch für IPv6 freigeben, z.B. Fritzbox „Freigaben“); mit 3+ menschlichen
Spielern prüfen, ob Clients direkt miteinander reden (die Ersatzadressen
gelten nur auf dem eigenen Rechner).

### E-Mail-Spiele (2026-10-28)

Original: nach dem Zug speichert das Spiel „CTP2 Email To <adresse> (Turn N).c2g“
auf den Desktop, verschickt wird von Hand. Jetzt hat die Meldung „nächster
Spieler“ zusätzlich „Per E-Mail senden“ (Simple MAPI `MAPISendMail` im
eigenen Thread; ohne MAPI-Mailprogramm Rückfall auf Explorer + `mailto:`)
und „Datei zeigen“ (`ctp/ctp2_utils/emailsend.cpp`, Skriptfunktionen
`SendEmailTurn()`/`ShowEmailTurnFile()`). Mit Thunderbird vom Besitzer
getestet. Offen/Idee: Empfangsseite erleichtern (z.B. „Spiel laden“ schlägt
neue Züge aus dem Downloads-Ordner vor).

## Phase 2b – Gleichzeitige Züge (nach Phase 2, Wunsch des Besitzers)

Heute laufen Netzwerkspiele nacheinander (Spielart „Normal“, „Zeitrunden“,
„Übernehmen“, „Städte-Zeitspiel“ unterscheiden sich nur im Zeitlimit). Im
Code gibt es `k_GAME_STYLE_SIMULTANEOUS` (`net/general/network.h`), der Wert
wird aber nirgends ausgewertet und hat keinen Knopf: nie fertig geworden.

Ziel wie in modernen Civ-Teilen: alle Menschen ziehen gleichzeitig, die KI
zieht gesammelt am Rundenende, danach gemeinsamer Rundenwechsel.

Günstig: Das Netz ist schon host-autoritativ (Clients schicken Aktionen,
Host führt aus und verteilt), Konflikte entscheidet der Host in
Ankunftsreihenfolge. Jeder Spieler hat einen eigenen Rundenzähler; die
Zeit-Spielarten bringen Timer und automatisches Rundenende mit.

Schwierig: rund 265 Stellen fragen „wer ist dran“ (`GetCurPlayer()`);
Produktion/Wachstum/Forschung laufen heute beim Zugbeginn je Spieler;
Regeln für Angriffe und Diplomatie während der andere zieht; Absicherung
gegen Desync über lange Partien.

Vorgehen:
1. Bestandsaufnahme aller `GetCurPlayer()`- und Zugbeginn-Stellen, je Stelle
   Einordnung (unkritisch / muss umgebaut werden). Danach Aufwandsschätzung.
2. Rundenmodell: gemeinsamer Rundenstart (Erträge aller Spieler), freie
   Phase für alle Menschen, „fertig“-Status je Spieler, KI-Phase, Wechsel.
3. Konfliktregeln (Kampf, Bewegung auf dasselbe Feld, Diplomatie).
4. Neue Spielart „Gleichzeitig“ im Spiel-Setup, optional mit Zeitlimit.
5. Lange automatisierte Testpartien mit CRC-Prüfung.

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

## Klassische Oberfläche (Entscheidung 2026-10-28)

Besitzer: „Die alte UI war um so vieles besser. Wir nehmen die und passen die
neuen Sachen darauf an.“ Dazu wählbar: klassisch oder Apolyton.

Umsetzung:
- Profiloption `ClassicInterface` (Standard an) hängt `ctp2_data\classic`
  als vorrangigen Datenordner ein (`InitDataIncludePath`, vor den RuleSets,
  Mods behalten Vorrang). Dort liegen nur die klassischen Fassungen; was
  fehlt, kommt aus der Apolyton-Fassung. Beide Sätze haben dieselben
  Steuerelemente, nur Anordnung/Aussehen unterscheiden sich, deshalb läuft
  der Code mit beiden. Umschalten in den Optionen (wirksam nach Neustart).
- Grundlage: Original-Layouts aus der GOG-Installation
  (`ctp2_data\english\uidata\layouts`; die Git-Historie beginnt erst 2005
  mit bereits geänderten Fassungen).
- Je Fenster: Original nehmen, die von Apolyton hinzugefügten Felder im
  Originalstil einsetzen, Bild prüfen.

Bestandsaufnahme (37 geänderte + 2 neue Layouts, Struktur-Diff):
- Nur Geometrie/Aussehen: DiplomacyDetails, diplomacywindow, infoscreen,
  intelligence, victoryscreen, scenario, profileedit, wondermovie,
  c3utilitydialog; dazu km_screen (neue Tastenfunktionen), ns_strings
  (Kartenformen), ctp_template (Rahmenwerte) mit inhaltlichen Ergänzungen.
- Listeneinträge mit „box“-Rahmen (Code sucht neue Namen): science,
  sciencevictory, unitmanager, cityespionage, dipwizard, editqueue.
- Neue Felder: citywindow (völlig neu: Spezialisten, Garnison, Effizienz),
  civstatus (Regler optimieren), citystatus (Stadtmanager, Spezialisten),
  controlpanel (2 Kartenknöpfe, politische Karte), armymanager, battleview,
  trademanager, greatlibrary, helptile, graphics/gameplayoptions/options,
  spnewgame (Hauptmenü + Disclaimer = Branding), spnewgamepopups
  (Regeloptionen), custommap, scenarioeditor, ns_launch, ns_selcnct,
  ns_selserv (unsere Direktverbindung); neu: ctp2.ldl, LanguageScreen.ldl.

Stand: erledigt sind Hauptmenü und Einzelspieler-Untermenü
(`classic\default\uidata\layouts\spnewgame.ldl`; Original-Untermenü-Code aus
dem Activision-Import zurückgeholt; Hintergründe als `*.rim` direkt aus dem
Bildpaket, damit lose Apolyton-Bilder sie nicht überdecken; Lizenzhinweis
auf dem Startbildschirm: englischer Activision-Satz, ctp2-redux von
RinoLetsPlay - Falco Alex mit impressum@rinoletsplay.de, Apolyton Edition).
Achtung: Commit 9e512ec trägt versehentlich die Nachricht des Vorgängers.

Neues Spiel (`classic\default\uidata\layouts\spnewgamepopups.ldl`, erzeugt
aus der Apolyton-Fassung, nur die geänderten Fenster ersetzt):
- Nation: Original-Raster aus Optionsknöpfen statt Liste, 5 Spalten für die
  70 Völker (Fenster 800x545), Herrschername und Geschlecht darunter.
- Schwierigkeit: die zwei Spalten Optionsknöpfe des Originals.
- Beides über `ListRadioGrid` (`ui\interface\listradiogrid.*`): Die Liste
  bleibt verborgen das Modell (Einträge kommen aus den Datenbanken, Mods mit
  anderer Anzahl funktionieren), das Raster zeigt sie als Knöpfe. Layout:
  Block mit `columns`, `colwidth`, `rowheight` und Unterblock `Radio`.
- Spieler: Originalfenster 400x250 mit den Apolyton-Drehreglern.
- Unverändert übernommen, weil schon im Originalstil: Hauptfenster (nur
  Kartentyp und Editor ergänzt), Kartengröße (identisch), Kartenform
  (Uranuswelt ergänzt), Sonderregeln (15 statt 2 Schalter, gleiche Optik),
  eigene Karte (Schieberegler).
- Die kleinen Magenta-Ecken der Knöpfe gab es im Original genauso (kein
  Farbschlüssel für diese Bilder), bleiben daher.
Stadtfenster (`classic\default\uidata\layouts\citywindow.ldl`, erzeugt aus
dem Original-Layout): wieder das kompakte Fenster mit den fünf Reitern
Produktion, Inventar, Experten, Status, Einheiten. Apolyton hatte 2009 die
Reiter entfernt und alles auf eine große Fläche gelegt (Commit 324159212),
dabei alle Pfade umbenannt. Der Code nutzt weiter die Apolyton-Namen;
`cw_Path` in citywindow.cpp sucht ein fehlendes Steuerelement im passenden
Reiter des Originals (Tabelle `s_classicPlaces`), so laufen beide Layouts.
Apolyton-Ergänzungen im Originalstil: Reichsmanager-Knopf unten, im Reiter
Experten „Optimiere Spezialisten“ und Nahrung/Produktion/Gold aus Handel,
im Reiter Status Runden bis Wachstum, Kriminalität, Bekehrungsverlust und
Lizenzgebühren. Zurückgeholt aus dem Original: die Beschreibung des
Bauobjekts und des gewählten Gebäudes mit Links in die Bibliothek
(`EditQueue::SetItemDescription`, jetzt öffentlich).
Reichsstatus/Inlandsmanager (`civstatus.ldl`, Entscheidung 2026-10-28:
„Original + Reiter Details“): Originalfenster 576x384; Apolyton hatte es
2009 auf 800x558 vergrößert, um Nahrung, Produktion und Wirtschaft nach
Quellen aufzuschlüsseln. Diese Aufschlüsselung ist jetzt der dritte Reiter
„Details“ (Wissenschaft und Gold nebeneinander), der Details-Knopf öffnet
ihn; Reiter 1 zeigt die Original-Zusammenfassung plus „Optimiere
Schieber“. `ce_GetObject`/`ce_SetText` in CauseAndEffectTab.cpp.
Diplomatie-Assistent (`dipwizard.ldl`, Entscheidung: Original): wieder
576x384; das Diplomatenbild von Apolyton (2007) entfällt, das Original hatte
keins (Platz war auskommentiert).
Übrige Fenster (Bestandsaufnahme 2026-10-28): Stadtstatus, Bauliste,
Handel, Einheiten, Wissenschaft, Info, Bibliothek usw. haben schon
Originalgröße und -optik, Apolyton hat dort nur Spalten/Knöpfe ergänzt
oder Listen um ein paar Pixel ausgerichtet (Commit 914e8c947) – bleiben.
Truppenmanager (`armymanager.ldl`): wieder 485x225; Liste zeigt die
Truppennamen (etwas breiter), Truppentext zwischen den Knöpfen, kleine
Einheitensymbole (`am_UnitIcon` wählt nach Feldgröße).
Steuerleiste und Szenario-Editor: nur kleine Ergänzungen im Originalstil,
bleiben. Damit sind alle Fenster durch; offen ist der Umschalter in den
Optionen (bisher nur Profilzeile `ClassicInterface=Yes/No`).
Hinweis Besitzer: Die Oberfläche muss später ohnehin skaliert werden, damit
sie unter anderen Auflösungen läuft; Plan dazu folgt.

Werkzeug: Bildschirmtour im Testmodus (`tools\mptest.ps1 -Single -Tour`:
erst Hauptmenü, Einzelspieler-Menü, Neues Spiel und seine Fenster als
`autotest_ui_00*.png`, dann im Spiel die Spielfenster), damit jedes Fenster
ohne Klicken geprüft werden kann. Danach Skalierung (intern kleiner rendern,
scharf ganzzahlig hochskalieren).

## Offene Fragen an den Besitzer

- GitHub-Login für den Fork (`gh auth login`).
- Zielauflösung für Videos (1280x768 = 4x, oder 1920x1152 = 6x)?
- Zweiter PC/Laptop im LAN für echte Multiplayer-Tests vorhanden?
