# ctp2-redux – Call to Power II for today's PCs

This is a fork of the [Apolyton Call to Power II Source Code Project](https://github.com/civctp2/civctp2)
with three goals:

1. **Runs on modern Windows PCs** out of the box: 64-bit build, current Visual
   Studio toolchain, sensible defaults for high-resolution screens.
2. **Multiplayer that works again**: LAN play and direct-IP internet play
   without the long-gone Activision lobby servers.
3. **Upscaled graphics and videos**: tools that upscale the original sprites,
   tiles, UI pictures and Indeo videos on your own machine, plus the engine
   changes needed to display them.

The roadmap, findings from the code analysis and the current status live in
[PLAN.md](PLAN.md). Work happens on the `redux` branch, `master` mirrors
upstream.

### Status (October 2026)

- Builds with Visual Studio 2022 Build Tools (MSVC 14.44) without admin
  rights: `pwsh tools/win-build.ps1` → `ctp2_code/ctp/x64/ctp2.exe`.
- Starts and plays the intro video through FFmpeg.
- Multiplayer over a **direct connection** (host / join by IP address, no
  lobby server): 50+ rounds without a crash in manual tests. Network crashes
  found with AddressSanitizer are fixed. Host and client go straight from
  their profile to the game setup (nation, rules), no chat lobby. The
  network menu only offers what still works: direct connection, TCP/IP LAN,
  hotseat and e-mail (no IPX, no list of the long-gone Activision servers).
  The direct connection also works over **IPv6** (e.g. `[2001:db8::1]:21157`),
  for internet connections without a public IPv4 address (DS-Lite); the
  window shows the own IPv6 address next to the IPv4 one.
- **E-mail games**: after a turn the game offers to send the save game with
  the default mail program (Simple MAPI, e.g. Thunderbird or classic Outlook:
  a new mail with recipient, subject and the save game attached opens) or to
  show the file for sending it by hand.
- **Automated multiplayer test**: two instances play a game against each
  other in the background, see [below](#automated-multiplayer-test).
- **Classic interface** (profile option `ClassicInterface`, on by default):
  the screens and windows of the original game from 2000 instead of the
  ones the Apolyton Edition redesigned (main menu, new game pop-ups, city
  window with tabs, domestic manager, diplomacy wizard, army manager); the
  Apolyton additions are fitted into them. The layouts are in
  `ctp2_data/classic`; switched off, the game shows the Apolyton interface.
- Upscaling: analysis done, implementation not started.

### Automated multiplayer test

`tools/mptest.ps1` starts a host and a client of your build on the same PC.
They click through the network screens by themselves, play a
direct-connection game against each other and end their turns. No window
opens and the game is silent. Nobody needs to click anything.

```
pwsh tools/mptest.ps1                    # 20 rounds, 2 AI civilisations
pwsh tools/mptest.ps1 -Turns 50 -AIPlayers 3
pwsh tools/mptest.ps1 -Show              # watch both game windows
pwsh tools/mptest.ps1 -ShotEvery 5       # screenshot every 5th round (0 = none)
pwsh tools/mptest.ps1 -Asan              # client built with AddressSanitizer
pwsh tools/mptest.ps1 -Single -Turns 40  # single player run for comparison
pwsh tools/mptest.ps1 -AnetLog           # network library with logging (dp.log)
pwsh tools/mptest.ps1 -JoinAddress '[::1]:21157'   # client joins over IPv6
```

It needs a Final-SDL x64 build (`tools/win-build.ps1`) and the game data in
the working copy. The exit code is 0 if the test passed. A test passes when:

- both instances reach the requested round, without a crash or a hang;
- there are no database checksum (CRC) errors;
- the client never asked the host for a resync. A resync request means the
  client's game state drifted away from the host's;
- host and client log identical values (cities, units, gold, advances) for
  the AI civilisations. The client's round counter runs one turn ahead, so
  the host's round N is compared with the client's round N+1. Between those
  two moments only the host itself moves;
- the terrain of every map cell is the same on host and client at the end.

**What you get:**
- a summary in the console, including cities, units, gold and advances per
  player in the last round both instances played;
- the folders `ctp2_code/ctp/autotest_host` and `ctp2_code/ctp/autotest_client`
  (copies of the build, git-ignored), each containing:
  - `autotest_log.txt`: steps, rounds, a stats line per player and round,
    a detail line (build queue, production, science, tax, government,
    population, research), resync and CRC events;
  - `autotest_map_end.txt`: terrain and flags of every map cell at the end;
  - `autotest_result.txt`: the machine-readable result;
  - `autotest_round_<nnn>.png`: a screenshot of the own turn start, taken
    even while the window is hidden; `autotest_connect.png` and
    `autotest_setup.png` show the connection window and the game setup.

**How it works:** the script passes command-line switches to the game,
implemented in `ctp2_code/ctp/ctp2_utils/autotest.cpp`:

| Switch | Meaning |
|---|---|
| `autohost` | host a direct-connection game |
| `autojoin=<addr>` | join the host at `<addr>`, e.g. `127.0.0.1:21157` |
| `autoturns=<n>` | stop after n rounds (default 20) |
| `autoai=<n>` | host only: number of AI civilisations (default 2) |
| `autohumans=<n>` | host only: human players to wait for (default 2) |
| `autoname=<name>` | player profile name |
| `autoshots=<n>` | screenshot every n rounds (default 1, 0 = none) |
| `autoplay=0` | test player only ends its turns (default: plays, see below) |
| `autosingle` | single player game (instant start) with as many civilisations, for comparison |
| `autoshow` | keep the window visible (hidden by default) |

The network windows press the same buttons a player would press. In the
game, each test player plays a simple turn before ending it:
- settlers found a city where they stand, if that is allowed;
- other units walk one step to a free neighbouring tile (no attacks);
- every empty build queue gets a random buildable unit or building;
- if no research is set, it picks a random one.

These actions use the same game events and city and player calls as the
keyboard and the city screen. So a client's actions travel to the host
exactly like real clicks. The random choices come from the test's own
random generator, never from the game's. `mptest.ps1 -Idle` switches the
playing off. The AI civilisations play normally. In hidden mode the game uses a software renderer and does not
draw to the screen. Edge scrolling is also off, because the mouse is
outside the hidden window and the map would otherwise scroll forever.

The game does the rest of the way itself: with a direct connection the host
goes straight from the profile to the game setup, and a client joins the
host's game as soon as it is listed. A client may arrive before or after the
host created the game.

### Game files and licence

*Call to Power II* is not free software. Activision released the source code in
2003 for personal, non-commercial use only (see [LICENSE.md](LICENSE.md)).
The game data (graphics, videos, music, text) is **not** part of this
repository and must come from your own copy of the game (GOG or CD). For the
same reason this project never distributes upscaled versions of the original
assets, only the scripts that create them locally from your own installation.

### Upstream

- Apolyton project: https://github.com/civctp2/civctp2
- Forums: https://apolyton.net/forum/other-games/call-to-power-2/ctp2-source-code-project
- Original readme files: [Activision](Activision%20CTP2%20Source%20Code_Readme.txt),
  [Apolyton](Apolyton%20CTP2%20Source%20Code_Readme.txt)
- Latest upstream release: [Apolyton Edition 2025-01-20](https://github.com/civctp2/civctp2/releases/tag/Apolyton-Edition-2025-01-20)

## About the code base

This is the Apolyton version of the *Call to Power II* (CTP2) source code based on the released source code from Activision, that did not include the patch. The code has been stripped of comments, but is otherwise complete as far as Activision's code goes. It was originally built with Microsoft Visual Studio 6.0. In the mean time the Apolyton code was modified so that it works with later versions.
This version also builds on Linux (i386 and x86_64), Ubuntu, Pandora, and Pyra.

On Linux and Windows, CTP2 builds as 32 and 64 bit application, these use SDL2 for display. On Windows also legacy Direct X builds are available. These are mainly for reference to check that the SDL port is complete. The Direct X versions build as 32 and 64 bit versions. However, CTP2 requires 16 bpp graphics support, which is only available for 32 bit programs, and thus 64 bit CTP2 Direct X versions refuse to start.

Note that the game files are not included in this repository, you can get them from the original CD or from the [GoG version](https://www.gog.com/game/call_to_power_2).

![screenshot](screenshot.png "screenshot of CTP2 running on Linux")
![Advance-Graph](Advance-Graph/Advance_english.png "generated Advance-Graph as PNG, SVG and PDF")

## Clone and complete your working copy

First, clone this repository into a directory of your choice. It will contain, beside some others, the following subdirectories:

* `ctp2_code`
* `ctp2_data`
* `Scenarios`

The directory `ctp2_code` contains the source code and will contain the generated executable. The directory `ctp2_data` contains the data files, such as sounds, images, and the database text files that contain all data for the game objects such as move points for units.

Even so the source code of CTP2 has been published, CTP2 is not free software. That means, we cannot distribute CTP2 and its code as a standalone product. Therefore, you have to add in the missing components from your copy of CTP2.

If you already have a copy of CTP2 installed, you can just copy everything from this repository into your installation, which is typically found in `C:\Program Files\Activision\Call to Power II\`.

If you do not have a copy already installed, you can get the files from the CD. The CD contains two files civlang.ctp and civmain.ctp (the extensions might differ). These files are zip files. The file civmain.ctp contains all files that are common to all language versions, civlang.ctp contains all files specific to your language version. Unzip these files and copy their content over your working copy without replacing files that already exist.

If you have the GoG version, use `innoextract` to extract all the required files (you can `sudo apt install innoextract` if you need) from the `setup_call_to_power2_2.0.0.13.exe` windows installer.
For example `innoextract -m -I app  setup_call_to_power2_2.0.0.13.exe` will extract the `app`folder that contains all the game files, which are in the same subfolders as in the CD version: `ctp2_data`, `ctp2_program` and `Scenarios`. Copy these folders over your working copy without replacing files that already exist. Now you should have those directories in your working copy.

* `ctp2_code`
* `ctp2_data`
* `Scenarios`
* `ctp2_program`

The folder `ctp2_program` is a stripped down version of `ctp2_code` without the source code and is the version that was shipped with the game. It is not needed for compiling and running the game. If it is an from a previous installation and you have some save games you want to use in your working copy then copy the folder `/ctp2_program/ctp/save/` and all its content to `/ctp2_code/ctp/save/`.

## Install the music and videos

The Windows version supports CD audio music, and the Linux version supports ripped CD music files compressed as ogg (like found in the GoG version). The Audio tracks in the GoG version are named `Track02.ogg` to `Track11.ogg` and in the `ctp2_program/ctp/music` folder, which should be copied to `ctp2_code/ctp/music`, if you want to use them in your working copy.

The music and the videos are not needed for the playing CTP2. However, if you want to use them you can just use the CD on Windows. However, the GoG audio tracks are not supported on Windows, but you can play them in another player such as VLC, while playing the game.

As the Linux version does not support direct play from the CD-ROM, you need to rip the music-files from the CD and put them on your disk. The music-files can be ripped with [`crip`](http://bach.dynet.com/crip/) or `cdparanoia`.

Alternatively, you can download the music-files from YouTube. For that, go in the terminal to the directory `ctp2_code/ctp/music` (create it if necessary) and run the following code:

```
youtube-dl  -x -t -i --audio-format vorbis --audio-quality 0 'https://www.youtube.com/watch?v=DtQBlVirrkU&list=PL5Z8d0ZfZ8SbHNEFnlR3jckHDmuZjBUaT'
mln -s 'Call to Power 2 - * - *' Track{#1+1}.ogg
i=11; files=(Track*.ogg); for ((f=${#files[@]}-1; f>=0; f--)); do track=$(printf "Track%02d.ogg" $i); mv "${files[$f]}" $track; ((i--)); done
```

You may have to install `youtube-dl` and `mln`.

If you want to play the videos in the game, copy them from the directory `Setup/data/Max/ctp2_data/default/videos/` on the CD to `ctp2_data/default/videos/` of your installation. You can also do this on Windows if you do not want to have the CD in your drive.

You may have to re-encode the videos, however we are not sure about that, because we do not have a CD and a working CD-ROM drive to test it. It might be enough to install the right codec. For re-encoding you can execute the following line from the `ctp2_data/default/videos/` directory:

```
shell> for i in `ls /media/cdrom/Setup/data/Max/ctp2_data/default/videos/`; do mencoder -ovc lavc -lavcopts vcodec=mpeg4  -srate 44100 -af resample=44100 -oac lavc  /media/cdrom/Setup/data/Max/ctp2_data/default/videos/$i -o $i; done 
```

This will also copy the videos to that directory.

## Building on Windows

**Quick way (this fork):** run `pwsh tools/win-build.ps1` from the repository root. It needs the Visual Studio 2022 Build Tools with the C++ workload and a Windows SDK, extracts NASM itself and does not need administrator rights. The result is `ctp2_code/ctp/x64/ctp2.exe` (Final-SDL, x64). The manual steps below still apply if you want to work inside Visual Studio.

CTP2 was originally built on Windows with Visual Studio 6. Today, the code compiles on Visual Studio 2017 and 2019 and probably also later. The code has not been compiled on Windows with any other compiler than the Visual Studio compiler. Beside a version of Visual Studio you need:

1. The Windows SDK installed on your computer
2. Install Nasm if you want to build SDL builds. A zip-file with the 64 bit windows version and its license is included in the [./NASM](./NASM) subdirectory. You can get the latest version from http://www.nasm.us/pub/nasm/releasebuilds/<!-- Comment so that the full stop does not fuse to the URL -->. The two executables inside go into C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\VC if you use the 32 bit version of Visual Studio 2017. Adjust the path accordingly if you use a later version or the 64 bit version. The other files in the NASM directory go to C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\VC\VCTargets\BuildCustomizations\. Again adjust the path according to your version if needed.
2. An environment variable named CDKDIR on your computer. In Windows XP/2000, go to Control
Panel->System->Environment Variables, and add it, with it's value set to [your source path]/ctp2/bin, the directory with bison, flex, and other tools in it. On Windows 10 it is Control
Panel->System->Advanced System Settings->Environment Variables or PC Settings->Info->Advanced System Settings->Environment Variables or press Windows+Pause ->Advanced System Settings->Environment Variables
3. A tmp directory in the root directory of the hard drive or SSD where the code is. If your source code working copy is on drive C: then create C:\tmp. If you have the code on another drive such as E: than it is E:\tmp.

Once all these are in place, open the Visual Studio project file [your source path]/ctp2_code/ctp/civctp.sln in Visual Studio. The project comes with several configurations for several platforms.

The platforms are Win32, x64, ARM, and ARM64. Currently the code compiles on all platforms, but it does not link on ARM and AM64 as the library files for SDL2 and FFmpeg. A possibility would be to integrate the source of `SDL2` and compile the libraries with the project. `FFmpeg` requires Nasm that produces assembler files for various x86 based platforms, unfortunately not for ARM. `FFmpeg` is for video support and can be disabled if the preprocessor macro and the "..\msvc\lib\*" libraries are removed from the project settings. If build on ARM/ARM64 you need ARM/ARM64 version of `flex` and `byacc`.

The configurations are:

* Debug: (DirectX build) Unoptimized debug build, with logging, asserts, and a memory leak detector.
* Final: (DirectX build) The build that was shipped with the game.
* Logging: (DirectX build) Like Final but with logging, which is very useful for AI debugging.
* Release: (DirectX build) Not really needed, it is close to the Final version but does not include the CD check that the Final version originally includedand, it is unoptimized, and seems to include some testing features.
* Debug-SDL: (SDL build) Unoptimized debug build, with logging, asserts, and a memory leak detector.
* Final-SDL: (SDL build) The build that was shipped with the game.
* Logging-SDL: (SDL build) Like Final but with logging, which is very useful for AI debugging.

These configurations generate the executables in [your source path]/ctp2_code/ctp/ for Win32 and in [your source path]/ctp2_code/ctp/x64/ for x64 builds. The executables are called:
<br>

| Configuration   | Executable      |
|-----------------|-----------------|
|Debug            | ctp2-dbg-dx.exe |
|Final            | ctp2-dx.exe     |
|Logging          | ctp2-dbg-dx.exe |
|Release          | ctp2-log-dx.exe |
|Debug-SDL        | ctp2-dbg.exe    |
|Final-SDL        | ctp2.exe        |
|Logging-SDL      | ctp2-log.exe    |

CTP2 can directly be run from Visual Studio, to do so press F5 if you want to run it on the debugger, which will be slow and does not make sense for a Final version. To run without debugging, press Ctrl F5. If necessary, CTP2 will be built, first. Make sure that the start project is set to ctp2, it should be bold in the side menu, otherwise Visual Studio may try to start something else such as Crater.dll, and since it is a dll it will not start. 

## Building on Linux

You will probably need GCC 5.x or later to build. The code doesn't seem to build on GCC 4.8.

You will need SDL 2.0, SDL_Mixer 2.0, SDL_Image 2.0. To be able to play movies you also need ffmpeg libraries (some).
You will also need `byacc` and `flex`.
On Debian and friends, use `sudo apt install libsdl2-dev libsdl2-mixer-dev libsdl2-image-dev libtiff-dev libavcodec-dev libavformat-dev libswscale-dev byacc flex` to install them all.

The build itself is pretty classing and straight forward:

```
./autogen.sh
CFLAGS="$CFLAGS -O3 -fuse-ld=gold" CXXFLAGS="$CXXFLAGS -O3 -fuse-ld=gold" ./configure --enable-silent-rules
make -j$(nproc)
```

Movie playback (e.g. the intro movie) requires passing `--enable-ffmpeg4movies` to `configure`, in addition to having the ffmpeg libraries installed - it is off by default because the FFmpeg API still changes a lot. Without it, the game builds and runs fine, it just won't play any movies.

If you need logging and still an optimized version for long playtesting to figure out what the AI does for instance use:

```
./autogen.sh
CFLAGS="$CFLAGS -O0 -fuse-ld=gold" CXXFLAGS="$CXXFLAGS -O0 -fuse-ld=gold" ./configure --enable-silent-rules --enable-logging
make -j$(nproc)
```

If you need more such as memory leak detection, asserts and being able to use the debugger efficently use then build a debug version:

```
./autogen.sh
CFLAGS="$CFLAGS -g -O0 -fno-omit-frame-pointer -fuse-ld=gold" CXXFLAGS="$CXXFLAGS -g -O0 -fno-omit-frame-pointer -fuse-ld=gold" ./configure --enable-silent-rules --enable-debug
make -j$(nproc)
```

Most optimizations are completely disabled at -O0 even if individual optimization flags are specified. In case CTP2 becomes to slow to be useful you can use higher levels of optimization such as -O1, or -O2.

With `make clean` you can delete all intermedia and output for a clean rebuild. You can look at `./configure` for more options, but there aren't many.

Also, note that `make -j$(nproc)` may fail the first time. Some files are auto-generated and the make dependencies don't catch that.

Finally, you may have to use gold instead of ld for link (add `-fuse-ld=gold` to your CFLAGS & CXXFLAGS if needed).

If you get the message on the terminal: `Failed to load module "atk-bridge"`. Install at-spi with `sudo apt install at-spi`.

### Running

When everything is ready, simply go to the program folder, for example with `cd ~/ctp2/ctp2_code/ctp` and launch the game with `./ctp2` or you can also type `./ctp2_code/ctp/ctp2` ifyour in the folder `~/ctp2/`.

### Installation

CTP2 can be installed on your Linux computer for all users in principle. Just run `make install` in the root folder of your working copy. However, this is not tested and so it is unknown whether this installs everything needed.

## Contributing

If you want to contribute to this project check out the [contributing guide lines](CONTRIBUTING.md). There you can learn about pull requests, coding style, tabs and spaces, debug tools, graphics, and get a few tips about using Visual Studio if you are unfamiliar with it.

## Included Libraries

This project includes several third party libraries, to whhich their respective licenses apply:
<br>

| Library           | Type             | Readme                                                | License                                                         | Repository / Web Site                                               |
|-------------------|------------------|-------------------------------------------------------|-----------------------------------------------------------------|---------------------------------------------------------------------|
| Anet              | Source           | [Readme](./ctp2_code/libs/anet/README.md)             | [LGPL](./ctp2_code/libs/anet/LICENSE)                           |                                                                     |
| FFmpeg-n6.1.2     | Source           | [Readme](./ctp2_code/libs/FFmpeg-n6.1.2/README.md)    | [Licenses](./ctp2_code/libs/FFmpeg-n6.1.2/LICENSE.md)           | [Web Site](https://ffmpeg.org/download.html#releases)               |
| Freetype-1.3.1    | Source           | [Readme](./ctp2_code/libs/freetype-1.3.1/README)      | [FreeType Project](./ctp2_code/libs/freetype-1.3.1/license.txt) | [Web Site](https://freetype.org/download.html)                      |
| SDL2_image-2.8.8  | Library          | [Readme](./ctp2_code/libs/SDL2_image-2.8.8/README.txt)| [Custom](./ctp2_code/libs/SDL2_image-2.8.8/LICENSE.txt)         | [Repository](https://github.com/libsdl-org/SDL_image/releases)      |
| SDL2_mixer-2.8.1  | Library          | [Readme](./ctp2_code/libs/SDL2_mixer-2.8.1/README.txt)| [Custom](./ctp2_code/libs/SDL2_mixer-2.8.1/LICENSE.txt)         | [Repository](https://github.com/libsdl-org/SDL_mixer/releases)      |
| SDL2-2.30.12      | Library          | [Readme](./ctp2_code/libs/SDL2-2.30.12/README.md)     | [Custom](./ctp2_code/libs/SDL2-2.30.12/LICENSE.txt)             | [Repository](https://github.com/libsdl-org/SDL/releases)            |
| Tiff-4.7.0        | Source           | [Readme](./ctp2_code/libs/tiff-4.7.0/README.md)       | [LibTIFF](./ctp2_code/libs/tiff-4.7.0/LICENSE.md)               | [Repository](https://libtiff.gitlab.io/libtiff/releases/index.html) |
| Zlib-1.3.1        | Source           | [Readme](./ctp2_code/libs/zlib-1.3.1/README)          | [LibTIFF](./ctp2_code/libs/zlib-1.3.1/LICENSE)                  | [Repository](https://github.com/madler/zlib/releases)               |
| Nasm-2.16.03      | Win x64 Binary   |                                                       | [Inside Zip File](./NASM/nasm-2.16.03-win64.zip)                | [Repository](http://www.nasm.us/pub/nasm/releasebuilds)             |
| Byacc             | Win x86 Binary   | [Readme](./bin/byacc-README)                          | Public Domain                                                   | [Repository](https://invisible-island.net/byacc)                    |
| Flex-2.5.4        | Win x86 Binary   |                                                       | [Custom](./bin/flex-COPYING)                                    | [Repository](https://github.com/westes/flex/releases)               |
| Win-Linux-Tools   | Win x86 Binaries |                                                       | [GNU GPL](./bin/GNUGeneralPublicLicence2.txt)                   |                                                                     |

## Converting old Linux save-games to new unified format

The old format of Linux save-games was not compatible with that of windows save-games. The format is now unified such that each OS can open save-games from the other. However, due to this, old Linux save-games need to be converted to the new format if you want to continue with those under the new ctp2 version (after [22dd1804804](https://github.com/civctp2/civctp2/commit/22dd180480445561bbbcd3efc60f08d2fe5c53e5)). A [game-converter-version](https://github.com/civctp2/civctp2/releases/tag/GameConverter) was created for this purpose (see, [#77](https://github.com/civctp2/civctp2/pull/77)), which can load the old format but saves games to the new format.

---

## Deutsch

**ctp2-redux** ist ein Fork des [Apolyton Call to Power II Source Code Project](https://github.com/civctp2/civctp2) mit drei Zielen:

1. **Läuft auf heutigen Windows-PCs** ohne Bastelei: 64-Bit-Build, aktuelle
   Visual-Studio-Werkzeuge, sinnvolle Voreinstellungen für hochauflösende
   Bildschirme.
2. **Multiplayer, der wieder funktioniert**: LAN-Spiele und Internet-Spiele
   per direkter IP, ohne die längst abgeschalteten Activision-Lobbyserver.
3. **Hochskalierte Grafik und Videos**: Werkzeuge, die Sprites, Kacheln,
   Oberflächenbilder und die Indeo-Videos auf dem eigenen Rechner
   hochskalieren, plus die nötigen Änderungen in der Engine. Das funktioniert
   mit jeder Sprachfassung, auch mit der deutschen.

Fahrplan, Erkenntnisse aus der Code-Analyse und der aktuelle Stand stehen in
[PLAN.md](PLAN.md). Gearbeitet wird auf dem Branch `redux`, `master`
spiegelt das Upstream-Projekt.

### Stand (Oktober 2026)

- Baut mit den Visual Studio 2022 Build Tools (MSVC 14.44) ohne Adminrechte:
  `pwsh tools/win-build.ps1` → `ctp2_code/ctp/x64/ctp2.exe`.
- Startet und spielt das Intro-Video über FFmpeg ab.
- Multiplayer über **Direktverbindung** (Hosten bzw. Beitreten per
  IP-Adresse, ohne Lobbyserver): in Handtests über 50 Runden ohne Absturz.
  Die Netzwerkabstürze, die AddressSanitizer gefunden hat, sind behoben.
  Host und Client kommen vom Profil direkt ins Spiel-Setup (Nation, Regeln),
  ohne Chat-Lobby. Das Netzwerkmenü bietet nur noch an, was funktioniert:
  Direktverbindung, TCP/IP-LAN, Hotseat und E-Mail (kein IPX, keine Liste der
  abgeschalteten Activision-Server). Die Direktverbindung klappt auch über
  **IPv6** (z.B. `[2001:db8::1]:21157`), für Anschlüsse ohne öffentliche
  IPv4-Adresse (DS-Lite); das Fenster zeigt die eigene IPv6-Adresse mit an.
- **E-Mail-Spiele**: Nach dem Zug bietet das Spiel an, den Spielstand mit dem
  Standard-Mailprogramm zu verschicken (Simple MAPI, z.B. Thunderbird oder
  klassisches Outlook: eine neue Mail mit Empfänger, Betreff und Spielstand
  als Anhang öffnet sich) oder die Datei zum selbst Verschicken zu zeigen.
- **Automatischer Multiplayer-Test**: Zwei Instanzen spielen im Hintergrund
  gegeneinander, siehe unten.
- **Klassische Oberfläche** (Profiloption `ClassicInterface`, Standard an):
  die Bildschirme und Fenster des Originals von 2000 statt der von der
  Apolyton Edition umgestalteten (Hauptmenü, Fenster von „Neues Spiel“,
  Stadtfenster mit Reitern, Inlandsmanager, Diplomatie-Assistent,
  Truppenmanager); die Apolyton-Ergänzungen sind darin eingepasst. Die
  Layouts liegen in `ctp2_data/classic`; ausgeschaltet zeigt das Spiel die
  Apolyton-Oberfläche.
- Hochskalierung: Analyse abgeschlossen, Umsetzung steht aus.

### Automatischer Multiplayer-Test

`tools/mptest.ps1` startet einen Host und einen Client des eigenen Builds
auf demselben PC. Beide klicken sich selbst durch die Netzwerkbildschirme,
spielen eine Partie über Direktverbindung gegeneinander und beenden ihre
Züge. Es öffnet sich kein Fenster, das Spiel ist stumm, und niemand muss
etwas anklicken.

```
pwsh tools/mptest.ps1                    # 20 Runden, 2 KI-Völker
pwsh tools/mptest.ps1 -Turns 50 -AIPlayers 3
pwsh tools/mptest.ps1 -Show              # beide Spielfenster ansehen
pwsh tools/mptest.ps1 -ShotEvery 5       # Bild jede 5. Runde (0 = keine)
pwsh tools/mptest.ps1 -Asan              # Client mit AddressSanitizer
pwsh tools/mptest.ps1 -Single -Turns 40  # Einzelspieler-Lauf zum Vergleich
pwsh tools/mptest.ps1 -AnetLog           # Netzwerkbibliothek mit Protokoll (dp.log)
pwsh tools/mptest.ps1 -JoinAddress '[::1]:21157'   # Client tritt über IPv6 bei
```

Voraussetzung sind ein Final-SDL-x64-Build (`tools/win-build.ps1`) und die
Spieldaten in der Arbeitskopie. Exit-Code 0 heißt bestanden. Der Test ist
bestanden, wenn:

- beide Instanzen die gewünschte Runde erreichen, ohne Absturz oder Hänger;
- keine Prüfsummenfehler (CRC) der Datenbanken auftreten;
- der Client nie einen Neuabgleich beim Host anfordert. Eine solche
  Anforderung bedeutet, dass der Spielstand des Clients von dem des Hosts
  abgewichen ist;
- Host und Client für die KI-Völker dieselben Werte protokollieren (Städte,
  Einheiten, Gold, Fortschritte). Der Rundenzähler des Clients läuft einen
  Zug voraus, deshalb wird Runde N des Hosts mit Runde N+1 des Clients
  verglichen. Zwischen diesen beiden Momenten zieht nur der Host selbst;
- am Ende jedes Kartenfeld bei Host und Client dasselbe Gelände hat.

**Was man bekommt:**
- eine Zusammenfassung in der Konsole, mit Städten, Einheiten, Gold und
  Fortschritten je Spieler in der letzten gemeinsam gespielten Runde;
- die Ordner `ctp2_code/ctp/autotest_host` und `ctp2_code/ctp/autotest_client`
  (Kopien des Builds, von git ignoriert), jeweils mit:
  - `autotest_log.txt`: Schritte, Runden, eine Statuszeile je Spieler und
    Runde, eine Detailzeile (Bauschleife, Produktion, Forschung, Steuer,
    Regierung, Bevölkerung, Forschungsziel), Neuabgleich- und CRC-Ereignisse;
  - `autotest_map_end.txt`: Gelände und Flags jedes Kartenfelds am Ende;
  - `autotest_result.txt`: das Ergebnis in maschinenlesbarer Form;
  - `autotest_round_<nnn>.png`: ein Bild vom eigenen Zugbeginn, auch bei
    verstecktem Fenster; `autotest_connect.png` und `autotest_setup.png`
    zeigen das Verbindungsfenster und das Spiel-Setup.

**Wie es funktioniert:** Das Skript übergibt dem Spiel Kommandozeilen-
Schalter, umgesetzt in `ctp2_code/ctp/ctp2_utils/autotest.cpp`. Die Tabelle
der Schalter steht im englischen Teil oben. Die Netzwerkfenster drücken
dieselben Knöpfe wie ein Spieler. Im Spiel macht jeder Testspieler einen
einfachen Zug, bevor er ihn beendet:
- Siedler gründen dort, wo sie stehen, eine Stadt, wenn das erlaubt ist;
- andere Einheiten gehen ein Feld auf ein freies Nachbarfeld (keine
  Angriffe);
- jede leere Bauschleife bekommt eine zufällige baubare Einheit oder ein
  Gebäude;
- ist keine Forschung gewählt, wählt er eine zufällig.

Diese Aktionen nutzen dieselben Spielereignisse und Stadt- und
Spieleraufrufe wie Tastatur und Stadtbildschirm. Die Aktionen eines Clients
gehen deshalb genau wie echte Klicks an den Host. Der Zufall kommt aus einem
eigenen Zufallsgenerator des Tests, nie aus dem des Spiels.
`mptest.ps1 -Idle` schaltet das Spielen ab. Die KI-Völker spielen normal. Im versteckten Modus nutzt das Spiel einen
Software-Renderer und zeichnet nicht auf den Bildschirm. Außerdem ist das
Rand-Scrollen aus, denn die Maus liegt außerhalb des versteckten Fensters
und die Karte würde sonst endlos scrollen.

Den Rest des Weges geht das Spiel selbst: Bei einer Direktverbindung kommt
der Host vom Profil direkt ins Spiel-Setup, und ein Client tritt dem Spiel
des Hosts bei, sobald es angezeigt wird. Der Client darf vor oder nach dem
Anlegen des Spiels kommen.

### Spieldaten und Lizenz

*Call to Power II* ist keine freie Software. Activision hat den Quellcode 2003
ausschließlich für den persönlichen, nicht-kommerziellen Gebrauch
freigegeben (siehe [LICENSE.md](LICENSE.md)). Die Spieldaten (Grafik, Videos,
Musik, Texte) sind **nicht** Teil dieses Repositories und müssen aus der
eigenen Kopie des Spiels stammen (GOG oder CD). Aus demselben Grund verteilt
dieses Projekt keine hochskalierten Fassungen der Originaldateien, sondern nur
die Skripte, die sie lokal aus der eigenen Installation erzeugen. Das gilt
auch für die deutschen Videos: Wer die deutsche Fassung besitzt, erzeugt sich
die hochskalierten Videos daraus selbst.

### Bauen unter Windows (Kurzfassung)

1. Visual Studio 2022 Build Tools mit C++-Workload und Windows SDK installieren.
2. Repository klonen und die Spieldaten der eigenen Installation hineinkopieren
   (Ordner `ctp2_data` und `Scenarios`, ohne vorhandene Dateien zu überschreiben).
3. `pwsh tools/win-build.ps1` ausführen.
4. `ctp2_code/ctp/x64/ctp2.exe` starten. Für den Fensterbetrieb eine
   `userprofile.txt` neben der exe mit `WindowedMode=Yes` anlegen.

Die ausführliche englische Anleitung steht oben.
