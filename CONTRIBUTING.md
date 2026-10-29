# Building on ctp2-redux

ctp2-redux is a fork of the
[Apolyton CTP2 Source Code Project](https://github.com/civctp2/civctp2) with
its own goals (see the [README](README.md)); the roadmap and all decisions
so far are in [PLAN.md](PLAN.md).

**Want to change something? Fork it.** You are welcome to fork ctp2-redux
or to take any of its changes into your own fork – please credit it, e.g.
"based on / contains changes from
[ctp2-redux by RinoLetsPlay](https://github.com/Rin0h/ctp2-redux)", and
keep the credit of the Apolyton project and Activision as well. The licence
of the source code still applies to every fork: personal and
non-commercial use only ([LICENSE.md](LICENSE.md)).

The notes below are how this fork is made; they may help you with yours.

## Ground rules of this fork

- **No original game files.** Never commit graphics, videos, music or texts
  of the original game, and never their upscaled versions
  (`ctp2_data/redux_hires` is ignored for that reason). The HD files are
  only ever made on the player's PC from their own copy. Call to Power II
  is not free software: the source code may only be used for personal,
  non-commercial purposes ([LICENSE.md](LICENSE.md)).
- **Vanilla look.** The game should look and play like the original from
  2000, with the bug fixes of the Apolyton Edition. The classic interface
  is the default; new things are fitted into it in the original style.
- **Rules stay as they are.** The rules and the balance of the game are
  not changed silently; every such change is a decision of its own and
  written down in PLAN.md.
- **The developers' vision.** Unfinished features of the original
  developers are completed only where the code or the game data prove what
  was intended (dead code, layouts, unused texts); the evidence goes into
  the commit message and PLAN.md.
- **Windows first.** The fork is developed and tested on Windows x64. The
  upstream Linux build files are still in the tree but not maintained.

## Building and testing

- Build with `pwsh tools/win-build.ps1` (Visual Studio 2022 Build Tools, no
  administrator rights needed), see the README.
- Before a change is committed, the automated tests run – they need no
  clicking and keep the game windows hidden:
  - `pwsh tools/mptest.ps1 -Turns 20` – host and client play a network game
    and must stay in sync;
  - `pwsh tools/mptest.ps1 -Single -Tour -Scale 3` – screenshots of all
    menu screens and game windows (`autotest_ui_*.png`); look at the ones
    your change touches. Add a tour step in
    `ctp2_code/ctp/ctp2_utils/autotour.cpp` for a new window.
- Bug fixes that also apply to the Apolyton Edition are worth offering
  upstream as well.

## Code style

The code follows the style Activision used:

- **Names** are camel case. Variables start with a small letter. Member
  variables are prefixed with `m_`, static members with `s_` (or `sm_`),
  globals with `g_`; local variables have no prefix. Enums are all caps.
- **Indentation** with tabs, a tab is 4 spaces wide; alignment with
  spaces. Do not unalign aligned code. Put large white-space clean-ups in
  commits of their own, never mixed with functional changes.
- **Comments, names and commit messages** in English. Mark larger
  additions of this fork with `ctp2-redux:` in a comment, so they can be
  told apart from the original code.
- **Text files** of the game (`ctp2_data/<language>/gamedata/*.txt`) are
  Latin-1, not UTF-8. A new string goes into `add_str.txt` of *every*
  language folder – translated where you can, the English text otherwise.
- **Commit messages:** a short summary line, a blank line, then what and
  why ([How to Write a Git Commit Message](https://cbea.ms/git-commit/)).

## Debugging help

- **AI test:** start a game and save it before doing anything. Open the
  chat window with the apostrophe key (`'`), enter `/attach 1` (if the
  player on screen is player 1) and `/rnd 200`: the AI plays 200 turns
  while you watch. With an old save game, also enter `/reloadslic`. More
  commands are in `ChatWindow::CheckForEasterEggs` in
  `ctp2_code/ui/interface/ChatBox.cpp`.
- **Logging:** the `Debug-SDL` and `Logging-SDL` configurations write log
  files to `logs` next to the program (`ctp2_code/ctp/x64/logs`). The
  flags are set in `main_InitializeLogs` in `ctp2_code/ctp/civ3_main.cpp`
  and defined in `ctp2_code/ctp/ctp2_utils/c3debug.h`.
- **Leaks:** the debug build reports memory leaks on exit to
  `CTP_LEAKS_99999.TXT` (stacks top to bottom) and
  `CTP_LEAKS_ALT_99999.TXT` (bottom to top, so shared parts line up) next
  to the program. "None" is how it should be.
- **Crashes of the release build:** set `LINK=/DEBUG` before
  `tools/win-build.ps1` to get `ctp2.pdb`; the addresses in `crash.txt`
  can then be resolved with `llvm-symbolizer --obj=ctp2.exe` (part of the
  Visual Studio Build Tools).
