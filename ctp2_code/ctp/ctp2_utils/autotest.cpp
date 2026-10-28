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
#include "autotour.h"

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
#include "initialplaywindow.h"  // initialplayscreen_instantPress
#include "profileDB.h"          // g_theProfileDB
#include "aui_ldl.h"            // aui_Ldl::GetObject
#include "Gold.h"
#include "Advances.h"
#include "UnitDynArr.h"
#include "Army.h"
#include "ArmyData.h"
#include "citydata.h"
#include "BldQue.h"
#include "World.h"
#include "Cell.h"
#include "MapPoint.h"
#include "UnitRecord.h"
#include "BuildingRecord.h"
#include "Globals.h"
#include "GameSettings.h"        // g_theGameSettings              // k_GAME_OBJ_TYPE_*
#include <random>
#ifdef __AUI_USE_SDL__
#include "aui_sdlui.h"          // aui_SDLUI::RequestScreenshot
#endif

namespace
{
	enum Role { ROLE_NONE, ROLE_HOST, ROLE_JOIN, ROLE_SINGLE };

	const char *RoleName(Role r)
	{
		return r == ROLE_HOST ? "host" : r == ROLE_JOIN ? "join" : "single";
	}

	Role        s_role          = ROLE_NONE;
	std::string s_address;
	std::string s_name;
	int         s_turns         = 20;
	int         s_aiPlayers     = 2;
	int         s_humanPlayers  = 2;
	bool        s_hidden        = true;
	int         s_shotEvery     = 1;
	bool        s_play          = true;
	bool        s_tour          = false;
	int         s_playedRound   = -1;
	int         s_lastShotRound = -1;

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
	double      s_quitAt         = -1.0;

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

	// Play the own civilisation a little, through the same game events and
	// city/player calls the user interface uses, so the actions travel over
	// the network like real clicks. Uses its own random generator: the
	// game's generator must stay in step with the other instance.
	void PlayTurn(int me, int round)
	{
		Player *p = g_player[me];
		if (!p || !p->m_all_armies || !p->m_all_cities) return;

		static std::mt19937 rng(12345u + 977u * (unsigned)me);
		int settles = 0, moves = 0, builds = 0;

		// research
		sint32 adv = p->m_advances->GetResearching();
		if (adv < 0 || p->HasAdvance(adv) || !p->m_advances->CanResearch(adv))
		{
			std::vector<sint32> options;
			for (sint32 a = 0; a < p->m_advances->GetNum(); a++)
				if (p->m_advances->CanResearch(a)) options.push_back(a);
			if (!options.empty())
			{
				adv = options[rng() % options.size()];
				p->SetResearching(adv);
				autotest_Log("play: research %d", (int)adv);
			}
		}

		// armies: settlers found a city where possible, the others walk
		for (sint32 i = 0; i < p->m_all_armies->Num(); i++)
		{
			Army army = p->m_all_armies->Access(i);
			if (!army.IsValid()) continue;
			MapPoint pos;
			army.GetPos(pos);
			Cell *cell = g_theWorld->GetCell(pos);

			if (army.CanSettle(pos) && !cell->HasCity() && !cell->GetCityOwner().IsValid())
			{
				g_gevManager->AddEvent(GEV_INSERT_Tail, GEV_SettleOrder, GEA_Army, army.m_id, GEA_End);
				settles++;
				continue;
			}

			// one step into a free, enterable neighbour cell (no attacks)
			for (int tries = 0; tries < 8; tries++)
			{
				WORLD_DIRECTION d = (WORLD_DIRECTION)(rng() % 8);
				MapPoint next;
				if (!pos.GetNeighborPosition(d, next)) continue;
				Cell *nc = g_theWorld->GetCell(next);
				if (nc->GetNumUnits() > 0 || nc->HasCity() || !army.CanEnter(next)) continue;
				g_gevManager->AddEvent(GEV_INSERT_Tail, GEV_MoveToOrder, GEA_Army, army.m_id,
				                       GEA_Direction, d, GEA_End);
				moves++;
				break;
			}
		}

		// cities: something buildable into every empty build queue
		for (sint32 i = 0; i < p->m_all_cities->Num(); i++)
		{
			Unit city = p->m_all_cities->Access(i);
			CityData *cd = city.IsValid() ? city.GetCityData() : NULL;
			if (!cd || cd->GetBuildQueue()->GetLen() > 0) continue;

			std::vector<std::pair<sint32, sint32> > options;   // category, type
			for (sint32 t = 0; t < g_theUnitDB->NumRecords(); t++)
				if (cd->CanBuildUnit(t)) options.push_back(std::make_pair((sint32)k_GAME_OBJ_TYPE_UNIT, t));
			for (sint32 t = 0; t < g_theBuildingDB->NumRecords(); t++)
				if (cd->CanBuildBuilding(t)) options.push_back(std::make_pair((sint32)k_GAME_OBJ_TYPE_IMPROVEMENT, t));
			if (options.empty()) continue;

			std::pair<sint32, sint32> pick = options[rng() % options.size()];
			if (pick.first == k_GAME_OBJ_TYPE_UNIT) cd->BuildUnit(pick.second);
			else                                     cd->BuildImprovement(pick.second);
			builds++;
		}

		autotest_Log("play: round %d settle %d move %d build %d", round, settles, moves, builds);
	}

	// terrain type and environment flags per cell, for comparing host and client
	void DumpMap(const char *path)
	{
		FILE *f = g_theWorld ? fopen(path, "w") : NULL;
		if (!f) return;
		MapPoint pos;
		for (pos.y = 0; pos.y < g_theWorld->GetYHeight(); pos.y++)
			for (pos.x = 0; pos.x < g_theWorld->GetXWidth(); pos.x++)
			{
				Cell *c = g_theWorld->GetCell(pos);
				fprintf(f, "%d %d %d %08x\n", (int)pos.x, (int)pos.y, (int)c->GetTerrain(), (unsigned)c->GetEnv());
			}
		fclose(f);
	}

	void LogGameInfo()
	{
		static bool done = false;
		if (done || !g_theWorld) return;
		done = true;
		int land = 0;
		MapPoint pos;
		for (pos.x = 0; pos.x < g_theWorld->GetXWidth(); pos.x++)
			for (pos.y = 0; pos.y < g_theWorld->GetYHeight(); pos.y++)
				if (!g_theWorld->IsWater(pos)) land++;
		autotest_Log("game: map %dx%d, land cells %d, difficulty %d, profile difficulty %d risk %d",
		             (int)g_theWorld->GetXWidth(), (int)g_theWorld->GetYHeight(), land,
		             g_theGameSettings ? (int)g_theGameSettings->GetDifficulty() : -1,
		             (int)g_theProfileDB->GetDifficulty(), (int)g_theProfileDB->GetRiskLevel());
	}

	void LogStats(int round)
	{
		for (int i = 0; i < k_MAX_PLAYERS; i++)
		{
			Player *p = g_player[i];
			if (!p || p->IsDead()) continue;
			int known = 0;
			for (sint32 a = 0; p->m_advances && a < p->m_advances->GetNum(); a++)
				if (p->m_advances->HasAdvance(a)) known++;
			autotest_Log("stats round %d player %d %s: cities %d units %d gold %d advances %d",
			             round, i, p->IsRobot() ? "ai" : "human",
			             p->GetAllCitiesList() ? (int)p->GetAllCitiesList()->Num() : -1,
			             p->GetAllUnitList()   ? (int)p->GetAllUnitList()->Num()   : -1,
			             p->m_gold             ? (int)p->m_gold->GetLevel()        : -1,
			             known);

			// what the civilisation is doing (not compared host/client)
			int qlen = -1, qcat = -1, qtype = -1, store = -1, prod = -1, sci = 0, pop = 0, food = -1, partial = -1, growth = -1;
			double foodNet = 0.0, foodGross = 0.0;
			double sciTax = -1.0;
			p->GetScienceTaxRate(sciTax);
			if (p->m_all_cities && p->m_all_cities->Num() > 0)
			{
				CityData *cd = p->m_all_cities->Access(0).GetCityData();
				BuildQueue *q = cd->GetBuildQueue();
				qlen  = q->GetLen();
				if (q->GetHead()) { qcat = q->GetHead()->m_category; qtype = q->GetHead()->m_type; }
				store = cd->GetStoredCityProduction();
				food  = cd->GetStoredCityFood();
				partial = cd->GetPartialPopulation();
				growth  = cd->GetGrowthRate();
				foodNet   = cd->GetNetCityFood();
				foodGross = cd->GetGrossCityFood();
				prod  = cd->GetNetCityProduction();
				for (sint32 c = 0; c < p->m_all_cities->Num(); c++)
				{
					sci += p->m_all_cities->Access(c).GetCityData()->GetScience();
					pop += p->m_all_cities->Access(c).GetCityData()->PopCount();
				}
			}
			autotest_Log("detail round %d player %d: queue %d head %d/%d stored %d prod %d science %d tax %.2f gov %d pop %d researching %d armies %d food %d net %.1f gross %.1f partial %d growth %d",
			             round, i, qlen, qcat, qtype, store, prod, sci, sciTax, (int)p->GetGovernmentType(), pop,
			             p->m_advances ? (int)p->m_advances->GetResearching() : -1,
			             p->m_all_armies ? (int)p->m_all_armies->Num() : -1, food, foodNet, foodGross, partial, growth);
		}
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
	else if (strstr(cmdLine, "autosingle"))
	{
		s_role = ROLE_SINGLE;
	}
	if (s_role == ROLE_NONE) return;

	if (ReadValue(cmdLine, "autoturns=", v))  s_turns        = atoi(v.c_str());
	if (ReadValue(cmdLine, "autoai=", v))     s_aiPlayers    = atoi(v.c_str());
	if (ReadValue(cmdLine, "autohumans=", v)) s_humanPlayers = atoi(v.c_str());
	if (ReadValue(cmdLine, "autoname=", v))   s_name         = v;
	if (ReadValue(cmdLine, "autoshots=", v))  s_shotEvery    = atoi(v.c_str());
	if (strstr(cmdLine, "autotour"))          s_tour         = true;
	if (ReadValue(cmdLine, "autoplay=", v))   s_play         = atoi(v.c_str()) != 0;
	if (strstr(cmdLine, "autoshow"))          s_hidden       = false;
	if (s_turns < 1) s_turns = 1;
	if (s_name.empty()) s_name = (s_role == ROLE_HOST) ? "AutoHost" : (s_role == ROLE_JOIN) ? "AutoClient" : "AutoSingle";

	remove("autotest_result.txt");
	FILE *f = fopen("autotest_log.txt", "w");
	if (f) fclose(f);
	autotest_Log("autotest: role=%s address=%s turns=%d ai=%d humans=%d name=%s",
	             RoleName(s_role), s_address.c_str(),
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

void autotest_Screenshot(const char *path)
{
#ifdef __AUI_USE_SDL__
	aui_SDLUI::RequestScreenshot(path);
	autotest_Log("screenshot %s", path);
#endif
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
		fprintf(f, "role=%s\n", RoleName(s_role));
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
		if (s_role == ROLE_SINGLE)
		{
			// as many civilisations as in the network test: the humans
			// there are one human and AIs here (+1 for the barbarians)
			// classic interface: the single player screen too
			bool const spScreen = aui_Ldl::GetObject("InitPlayWindow", "SPButton") && aui_Ldl::IsValid("SPWindow");
			if (s_tour && s_mainMenuSeen && autotest_Step("shot-mainmenu"))
				autotest_Screenshot("autotest_ui_00_mainmenu.png");
			else if (s_tour && spScreen && autotest_Step("open-spscreen"))
				initialplayscreen_spPress(NULL, AUI_BUTTON_ACTION_EXECUTE, 0, Cookie());
			else if (s_tour && spScreen && autotest_Step("shot-spscreen"))
				autotest_Screenshot("autotest_ui_00_spscreen.png");
			else if (s_tour && spScreen && autotest_Step("close-spscreen"))
				spscreen_returnPress(NULL, AUI_BUTTON_ACTION_EXECUTE, 0, Cookie());
			else if (s_mainMenuSeen && autotest_Step("mainmenu-single"))
			{
				g_theProfileDB->SetNPlayers(s_humanPlayers + s_aiPlayers + 1);
				initialplayscreen_instantPress(NULL, AUI_BUTTON_ACTION_EXECUTE, 0, NULL);
			}
		}
		else if (s_mainMenuSeen && autotest_Step("mainmenu-network"))
		{
			NetShell::Enter(k_NS_FLAGS_CREATE);
		}
		return;
	}

	const bool single = (s_role == ROLE_SINGLE);
	if ((!single && !g_network.IsActive()) || !g_selected_item || !g_player) return;

	const int me = single ? (int)g_selected_item->GetVisiblePlayer() : g_network.GetPlayerIndex();
	if (me < 0 || !g_player[me]) return;

	const int round = g_player[me]->GetCurRound();
	if (round != s_lastRound)
	{
		s_lastRound = round;
		autotest_Log("round %d", round);
		LogGameInfo();   // once
		LogStats(round);
	}

	// The client ends its turn of the last round and quits a moment later;
	// the host's round with the same number starts right after that turn
	// (the client's counter runs one turn ahead), so the host quits then.
	// Like that nobody waits for a player that has already left.
	if ((autotest_IsHost() || single) ? round >= s_turns : (s_quitAt > 0.0 && Now() >= s_quitAt))
	{
		DumpMap("autotest_map_end.txt");
		autotest_Finish("ok");
		return;
	}

	const bool myTurn =
		g_selected_item->GetCurPlayer() == g_selected_item->GetVisiblePlayer() &&
		(single || (g_network.IsMyTurn() && (!g_network.IsHost() || g_network.ReadyToStart())));

	static double s_lastDiag = 0.0;
	if (Now() - s_lastDiag > 10.0)
	{
		s_lastDiag = Now();
		std::string rounds;
		for (int i = 0; i < k_MAX_PLAYERS; i++)
			if (g_player[i])
				rounds += " " + std::to_string(i) + ":" + std::to_string(g_player[i]->GetCurRound())
				        + (g_player[i]->IsRobot() ? "a" : g_player[i]->IsNetwork() ? "n" : "h");
		autotest_Log("state: me %d cur %d visible %d myTurn %d ready %d round %d, rounds%s",
		             me, (int)g_selected_item->GetCurPlayer(), (int)g_selected_item->GetVisiblePlayer(),
		             (int)g_network.IsMyTurn(), (int)g_network.ReadyToStart(), round, rounds.c_str());
	}

	if (!myTurn)
	{
		s_myTurnSince = -1.0;
		return;
	}

	if (s_myTurnSince < 0.0)
		s_myTurnSince = Now();

	// Turn: after a moment (city updates, messages) play the civilisation,
	// take the screenshot when the actions are through, then end the turn.
	const double playAt = 1.0;
	const double shotAt = s_play ? 2.5 : 1.0;
	const double endAt  = s_play ? 3.0 : 1.5;

	if (s_play && round != s_playedRound && Now() - s_myTurnSince > playAt)
	{
		s_playedRound = round;
		if (sci_advancescreen_isOnScreen())
			sci_advancescreen_removeMyWindow(AUI_BUTTON_ACTION_EXECUTE);
		PlayTurn(me, round);
	}

	// Screenshot tour of the windows in the first round with a city; the
	// test ends with it.
	if (s_tour && round >= 1 && Now() - s_myTurnSince > 2.0)
	{
		if (autotour_Process())
			return;
		autotest_Finish("ok");
		return;
	}

	if (s_shotEvery > 0 && round % s_shotEvery == 0 && round != s_lastShotRound &&
	    Now() - s_myTurnSince > shotAt)
	{
		s_lastShotRound = round;
#ifdef __AUI_USE_SDL__
		char path[64];
		snprintf(path, sizeof(path), "autotest_round_%03d.png", round);
		autotest_Screenshot(path);
#endif
	}

	// Retry the end of turn every few seconds in case a request was swallowed.
	if (Now() - s_myTurnSince > endAt && Now() - s_lastEndTurn > 4.0)
	{
		if (sci_advancescreen_isOnScreen())
			sci_advancescreen_removeMyWindow(AUI_BUTTON_ACTION_EXECUTE);

		s_lastEndTurn = Now();
		autotest_Log("end turn (round %d)", round);
		g_gevManager->EndTurnRequest();

		if (s_role == ROLE_JOIN && round >= s_turns && s_quitAt < 0.0)
			s_quitAt = Now() + 3.0;   // let the end of turn reach the host
	}
}
