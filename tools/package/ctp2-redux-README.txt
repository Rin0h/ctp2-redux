ctp2-redux – Call to Power II for today's PCs
=============================================
(Deutsch weiter unten)

What is it?
  A continuation of the Apolyton Edition of Call to Power II: 64-bit,
  sharp scaling for big screens, multiplayer over a direct connection
  (IPv6 too) and HD graphics and videos that the HD setup makes on your
  own PC from your own copy of the game.
  Project page: https://github.com/Rin0h/ctp2-redux

What you need
  Your own copy of Call to Power II (GOG or CD). This package contains no
  original graphics, videos or music.

Installation
  1. Best back up the game folder first (e.g. a copy of
     "C:\GOG Games\Call To Power 2"). The package replaces some files in
     ctp2_data with those of the Apolyton Edition.
  2. Unpack this package into the game folder (where ctp2_data and
     ctp2_program are) and let it replace files. The folders ctp2_data and
     ctp2_program of the package must land on those of the game, not in a
     new subfolder (Windows "Extract all" suggests one: remove it from the
     path).
  3. Start ctp2-redux-hd-setup.bat in the game folder. It creates the
     shortcut "Call to Power II (ctp2-redux)" on the desktop and in the
     game folder right away; making HD files is optional, you can close
     the window then.
  4. Play with that shortcut (or ctp2_program\ctp\x64\ctp2.exe).
     Important: the GOG shortcut and GOG Galaxy start the original
     ctp2.exe, which cannot read the new data and stops with an error
     ("Const.txt line 193").
     Window instead of full screen: put the line WindowedMode=Yes into
     ctp2_program\ctp\userprofile.txt.

Language
  The game speaks the language of your installation (English GOG version:
  English). The Apolyton Edition also brings the texts of other languages;
  to play with them put e.g. LanguageDirectory=german into
  ctp2_program\ctp\userprofile.txt (speech and videos stay those of your
  installation).

HD graphics and videos (optional)
  ctp2-redux-hd-setup.bat (see above) asks for the language of the
  assistant (English or German), shows the recommended factor and does four
  steps (interface, videos, terrain, units/cities), each of which can be
  done on its own, cancelled and continued later. The first time it
  downloads Real-ESRGAN from its GitHub page. The results only go to
  ctp2_data\redux_hires; deleting that folder undoes everything. A graphics
  card with Vulkan makes it a lot faster.

Licence
  Call to Power II is not free software. Activision released the source
  code in 2003 for personal, non-commercial use only (Licenses\LICENSE.md).
  ctp2-redux is free of charge and non-commercial. The included libraries
  have their own licences (folder Licenses); their source code and that of
  the game are on the project page.


ctp2-redux – Call to Power II für heutige PCs
=============================================

Was ist das?
  Eine Weiterentwicklung der Apolyton Edition von Call to Power II:
  64 Bit, scharfe Skalierung für große Bildschirme, Multiplayer über
  Direktverbindung (auch IPv6) und HD-Grafik und -Videos, die der
  HD-Assistent auf deinem eigenen PC aus deinem eigenen Spiel erzeugt.
  Projektseite: https://github.com/Rin0h/ctp2-redux

Was du brauchst
  Deine eigene Kopie von Call to Power II (GOG oder CD). Dieses Paket
  enthält keine Originalgrafiken, -videos oder -musik.

Installation
  1. Am besten vorher den Spielordner sichern (z.B. eine Kopie von
     "C:\GOG Games\Call To Power 2"). Das Paket ersetzt einige Dateien in
     ctp2_data durch die der Apolyton Edition.
  2. Den Inhalt dieses Pakets in den Spielordner entpacken (dorthin, wo
     ctp2_data und ctp2_program liegen) und Dateien ersetzen lassen. Die
     Ordner ctp2_data und ctp2_program des Pakets müssen auf denen des
     Spiels landen, nicht in einem neuen Unterordner (Windows »Alle
     extrahieren« schlägt einen vor: aus dem Pfad entfernen).
  3. ctp2-redux-hd-setup.bat im Spielordner starten. Es legt sofort die
     Verknüpfung »Call to Power II (ctp2-redux)« auf dem Desktop und im
     Spielordner an; HD-Dateien zu erzeugen ist freiwillig, das Fenster
     kann danach geschlossen werden.
  4. Mit dieser Verknüpfung spielen (oder ctp2_program\ctp\x64\ctp2.exe).
     Wichtig: Die GOG-Verknüpfung und GOG Galaxy starten die originale
     ctp2.exe, die die neuen Daten nicht lesen kann und mit einem Fehler
     abbricht (»Const.txt line 193«).
     Fenster statt Vollbild: in ctp2_program\ctp\userprofile.txt die Zeile
     WindowedMode=Yes eintragen.

Sprache
  Das Spiel spricht die Sprache deiner Installation (englische
  GOG-Version: Englisch). Die Apolyton Edition bringt auch die Texte
  anderer Sprachen mit; damit spielen: in
  ctp2_program\ctp\userprofile.txt z.B. LanguageDirectory=german
  eintragen (Sprachausgabe und Videos bleiben die deiner Installation).

HD-Grafik und -Videos (freiwillig)
  ctp2-redux-hd-setup.bat (siehe oben) fragt nach der Sprache des
  Assistenten (Deutsch oder Englisch), zeigt den empfohlenen Faktor und
  erledigt vier Schritte (Oberfläche, Videos, Gelände, Einheiten/Städte),
  die sich einzeln machen, abbrechen und später fortsetzen lassen. Er lädt
  beim ersten Mal Real-ESRGAN von dessen GitHub-Seite. Die Ergebnisse
  landen nur in ctp2_data\redux_hires; diesen Ordner löschen macht alles
  rückgängig. Eine Grafikkarte mit Vulkan macht es deutlich schneller.

Lizenz
  Call to Power II ist keine freie Software. Activision hat den Quellcode
  2003 nur für den persönlichen, nicht-kommerziellen Gebrauch freigegeben
  (Licenses\LICENSE.md). ctp2-redux ist kostenlos und nicht kommerziell.
  Die mitgelieferten Bibliotheken haben eigene Lizenzen (Ordner Licenses);
  ihr Quellcode und der des Spiels stehen auf der Projektseite.
