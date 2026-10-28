//----------------------------------------------------------------------------
//
// Project      : Call To Power 2
// File type    : C++ source
// Description  : Unattended multiplayer test mode (ctp2-redux)
//
//----------------------------------------------------------------------------
//
// See autotest.h for the command line switches and the result file.
//
// The netshell windows call autotest_Step() from their Idle() functions and
// execute the same button actions a player would click. In the game itself
// autotest_Process() ends the local player's turn and quits after the
// requested number of rounds.
//
//----------------------------------------------------------------------------

#include "c3.h"
#include "autotest.h"

#include <chrono>
#include <cstdarg>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <set>
#include <string>

#ifdef WIN32
#include <windows.h>
#else
#include <unistd.h>
#endif

#include "aui_button.h"         // AUI_BUTTON_ACTION_EXECUTE
#include "netshell.h"           // NetShell::Enter, k_NS_FLAGS_CREATE
#include "network.h"            // g_network
#include "player.h"             // g_player
#include "SelItem.h"            // g_selected_item
#include "GameEventManager.h"   // g_gevManager
#include "sci_advancescreen.h"

namespace
{
	enum Role { ROLE_NONE, ROLE_HOST, ROLE_JOIN };

	Role        s_role          = ROLE_NONE;
	std::string s_address;
	std::string s_name;
	int         s_turns         = 20;
	int         s_aiPlayers     = 2;
	int         s_humanPlayers  = 2;
	bool        s_hidden        = true;

	std::set<std::string> s_stepsDone;
	double      s_lastStep      = 0.0;
	bool        s_mainMenuSeen  = false;
	bool        s_finished      = false;

	int         s_resyncRequests = 0;
	int         s_resyncsSent    = 0;
	int         s_crcErrors      = 0;
	int         s_lastRound      = -1;
	double      s_myTurnSince    = -1.0;
	double      s_lastEndTurn    = 0.0;

	std::chrono::steady_clock::time_point s_start = std::chrono::steady_clock::now();

	double Now()
	{
		return std::chrono::duration<double>(std::chrono::steady_clock::now() - s_start).count();
	}

	// Value of "key=value" in the command line, up to the next blank.
	bool ReadValue(const char *cmdLine, const char *key, std::string &value)
	{
		const char *p = strstr(cmdLine, key);
		if (!p) return false;
		p += strlen(key);
		const char *e = p;
		while (*e && *e != ' ' && *e != '\t' && *e != '"') e++;
		value.assign(p, e - p);
		return true;
	}
}

void autotest_ParseCommandLine(const char *cmdLine)
{
	if (!cmdLine) return;

	std::string v;
	if (ReadValue(cmdLine, "autojoin=", v) && !v.empty())
	{
		s_role    = ROLE_JOIN;
		s_address = v;
	}
	else if (strstr(cmdLine, "autohost"))
	{
		s_role = ROLE_HOST;
	}
	if (s_role == ROLE_NONE) return;

	if (ReadValue(cmdLine, "autoturns=", v))  s_turns        = atoi(v.c_str());
	if (ReadValue(cmdLine, "autoai=", v))     s_aiPlayers    = atoi(v.c_str());
	if (ReadValue(cmdLine, "autohumans=", v)) s_humanPlayers = atoi(v.c_str());
	if (ReadValue(cmdLine, "autoname=", v))   s_name         = v;
	if (strstr(cmdLine, "autoshow"))          s_hidden       = false;
	if (s_turns < 1) s_turns = 1;
	if (s_name.empty()) s_name = (s_role == ROLE_HOST) ? "AutoHost" : "AutoClient";

	remove("autotest_result.txt");
	FILE *f = fopen("autotest_log.txt", "w");
	if (f) fclose(f);
	autotest_Log("autotest: role=%s address=%s turns=%d ai=%d humans=%d name=%s",
	             s_role == ROLE_HOST ? "host" : "join", s_address.c_str(),
	             s_turns, s_aiPlayers, s_humanPlayers, s_name.c_str());
}

bool        autotest_Active()        { return s_role != ROLE_NONE; }
bool        autotest_IsHost()        { return s_role == ROLE_HOST; }
bool        autotest_Hidden()        { return s_hidden; }
const char *autotest_Address()       { return s_address.c_str(); }
const char *autotest_PlayerName()    { return s_name.c_str(); }
int         autotest_HumanPlayers()  { return s_humanPlayers; }
int         autotest_AIPlayers()     { return s_aiPlayers; }

void autotest_Log(const char *format, ...)
{
	FILE *f = fopen("autotest_log.txt", "a");
	if (!f) return;
	fprintf(f, "[%8.2f] ", Now());
	va_list args;
	va_start(args, format);
	vfprintf(f, format, args);
	va_end(args);
	fprintf(f, "\n");
	fclose(f);
}

bool autotest_Step(const char *name)
{
	if (!autotest_Active() || s_finished) return false;
	if (s_stepsDone.count(name)) return false;
	if (Now() - s_lastStep < 1.0) return false;   // let the UI settle

	s_stepsDone.insert(name);
	s_lastStep = Now();
	autotest_Log("step: %s", name);
	return true;
}

void autotest_NoteMainMenu()
{
	s_mainMenuSeen = true;
}

void autotest_NoteCRCError(const char *what)
{
	if (!autotest_Active()) return;
	s_crcErrors++;
	autotest_Log("CRC error: %s", what ? what : "");
}

void autotest_NoteResyncRequest(int reason)
{
	if (!autotest_Active()) return;
	s_resyncRequests++;
	autotest_Log("resync requested, reason %d", reason);
}

void autotest_NoteResyncSent(int player)
{
	if (!autotest_Active()) return;
	s_resyncsSent++;
	autotest_Log("resync sent to player %d", player);
}

void autotest_Finish(const char *result)
{
	if (!autotest_Active() || s_finished) return;
	s_finished = true;

	FILE *f = fopen("autotest_result.txt", "w");
	if (f)
	{
		fprintf(f, "result=%s\n", result);
		fprintf(f, "role=%s\n", s_role == ROLE_HOST ? "host" : "join");
		fprintf(f, "rounds=%d\n", s_lastRound);
		fprintf(f, "resync_requests=%d\n", s_resyncRequests);
		fprintf(f, "resyncs_sent=%d\n", s_resyncsSent);
		fprintf(f, "crc_errors=%d\n", s_crcErrors);
		fprintf(f, "seconds=%.0f\n", Now());
		fclose(f);
	}
	autotest_Log("finished: %s", result);

	// Quit right away: the result is written, a regular shutdown would only
	// make the other instance wait for a goodbye.
#ifdef WIN32
	ExitProcess(0);
#else
	_exit(0);
#endif
}

void autotest_Process(bool gameLoaded)
{
	if (!autotest_Active() || s_finished) return;

	if (!gameLoaded)
	{
		if (s_mainMenuSeen && autotest_Step("mainmenu-network"))
		{
			NetShell::Enter(k_NS_FLAGS_CREATE);
		}
		return;
	}

	if (!g_network.IsActive() || !g_selected_item || !g_player) return;

	const int me = g_network.GetPlayerIndex();
	if (me < 0 || !g_player[me]) return;

	const int round = g_player[me]->GetCurRound();
	if (round != s_lastRound)
	{
		s_lastRound = round;
		autotest_Log("round %d", round);
	}

	// The client quits first; the host plays one more round so it does not
	// leave while the client still waits for its turn.
	const int lastRound = s_turns + (autotest_IsHost() ? 1 : 0);
	if (round >= lastRound)
	{
		autotest_Finish("ok");
		return;
	}

	const bool myTurn =
		g_selected_item->GetCurPlayer() == g_selected_item->GetVisiblePlayer() &&
		g_network.IsMyTurn() &&
		(!g_network.IsHost() || g_network.ReadyToStart());

	static double s_lastDiag = 0.0;
	if (Now() - s_lastDiag > 10.0)
	{
		s_lastDiag = Now();
		autotest_Log("state: me %d cur %d visible %d myTurn %d ready %d round %d",
		             me, (int)g_selected_item->GetCurPlayer(), (int)g_selected_item->GetVisiblePlayer(),
		             (int)g_network.IsMyTurn(), (int)g_network.ReadyToStart(), round);
	}

	if (!myTurn)
	{
		s_myTurnSince = -1.0;
		return;
	}

	if (s_myTurnSince < 0.0)
		s_myTurnSince = Now();

	// Give the turn start a moment (city updates, messages), then end it;
	// retry every few seconds in case a request was swallowed.
	if (Now() - s_myTurnSince > 1.5 && Now() - s_lastEndTurn > 4.0)
	{
		if (sci_advancescreen_isOnScreen())
			sci_advancescreen_removeMyWindow(AUI_BUTTON_ACTION_EXECUTE);

		s_lastEndTurn = Now();
		autotest_Log("end turn (round %d)", round);
		g_gevManager->EndTurnRequest();
	}
}
