//----------------------------------------------------------------------------
//
// Project      : Call To Power 2
// File type    : C++ header
// Description  : Unattended multiplayer test mode (ctp2-redux)
//
//----------------------------------------------------------------------------
//
// Command line switches:
//   autohost              host a direct-connection game
//   autojoin=<addr>       join the host at <addr> ("127.0.0.1:21157")
//   autosingle            single player game instead (instant start), for
//                         comparing the AI with the network game
//   autoturns=<n>         stop after n rounds (default 20)
//   autoai=<n>            host only: number of AI civilisations (default 2)
//   autohumans=<n>        host only: human players to wait for (default 2)
//   autoname=<name>       player profile name
//   autoshow              keep the window visible (hidden by default)
//   autoshots=<n>         screenshot every n rounds (default 1, 0 = none)
//   autoplay=0            only end the turns; by default the test player
//                         settles, walks, fills build queues, picks research
//
// The game clicks through the netshell by itself, ends its own turns, and
// writes autotest_result.txt next to the executable before it quits:
//   result=ok|<reason>, rounds, resync_requests, resyncs_sent, crc_errors,
//   seconds. A missing file means the instance crashed or hung.
// Progress goes to autotest_log.txt, including a "stats" line per player
// and round (cities, units, gold, advances). Screenshots are taken at the
// start of the own turn: autotest_round_<nnn>.png.
//
//----------------------------------------------------------------------------

#ifndef AUTOTEST_H__
#define AUTOTEST_H__

void        autotest_ParseCommandLine(const char *cmdLine);
bool        autotest_Active();
bool        autotest_IsHost();
bool        autotest_Hidden();
const char *autotest_Address();
const char *autotest_PlayerName();
int         autotest_HumanPlayers();
int         autotest_AIPlayers();

// One-shot automation step: true exactly once per name, and only when the
// previous step is a moment ago, so the UI can settle in between.
bool        autotest_Step(const char *name);
void        autotest_Log(const char *format, ...);

// Hooks
void        autotest_NoteMainMenu();
void        autotest_Process(bool gameLoaded);   // every frame, CivApp::Process
void        autotest_NoteCRCError(const char *what);
void        autotest_NoteResyncRequest(int reason);
void        autotest_NoteResyncSent(int player);
void        autotest_Finish(const char *result);

#endif
