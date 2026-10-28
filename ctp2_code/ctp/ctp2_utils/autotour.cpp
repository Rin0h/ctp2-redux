//----------------------------------------------------------------------------
//
// Project      : Call To Power 2
// File type    : C++ source
// Description  : Test mode: open the game windows one by one and take a
//                screenshot of each (ctp2-redux)
//
//----------------------------------------------------------------------------
//
// Used with the autotour switch (see autotest.h) to check the interface
// layouts without clicking: every window is opened the way its key or
// button opens it, drawn for a moment, saved as autotest_ui_<nn>_<name>.png
// and closed again.
//
// Left out: the key mapping screen (closing it saves the key map into the
// game data) and the battle view (needs a running battle).
//
//----------------------------------------------------------------------------

#include "c3.h"
#include "autotour.h"
#include "autotest.h"

#include <chrono>
#include <cstdio>

#include "player.h"                 // g_player
#include "SelItem.h"                // g_selected_item
#include "UnitDynArr.h"
#include "Army.h"
#include "ArmyData.h"
#include "aui_button.h"             // AUI_BUTTON_ACTION_EXECUTE
#include "screenutils.h"
#include "citywindow.h"
#include "ScienceManagementDialog.h"
#include "sci_advancescreen.h"
#include "trademanager.h"
#include "unitmanager.h"
#include "armymanagerwindow.h"
#include "diplomacywindow.h"
#include "intelligencewindow.h"
#include "infowindow.h"
#include "EditQueue.h"
#include "graphicsscreen.h"
#include "gameplayoptions.h"
#include "soundscreen.h"
#include "ProfileEdit.h"
#include "helptile.h"
#include "dipwizard.h"
#include "sciencevictorydialog.h"

namespace
{
	Player *Me()
	{
		return g_selected_item ? g_player[g_selected_item->GetVisiblePlayer()] : NULL;
	}

	Unit FirstCity()
	{
		Player *p = Me();
		if (p && p->m_all_cities && p->m_all_cities->Num() > 0)
			return p->m_all_cities->Access(0);
		return Unit();
	}

	void Nothing() {}

	void OpenCity()       { Unit c = FirstCity(); if (c.IsValid()) CityWindow::Display(c); }
	void CloseCity()      { CityWindow::Hide(); }
	void OpenCityStatus() { open_CityStatus(); }
	void OpenCivStatus()  { open_CivStatus(); }
	void OpenScience()    { open_ScienceStatus(); }
	void CloseScience()   { ScienceManagementDialog::Close(); }
	void OpenAdvances()   { sci_advancescreen_displayMyWindow(NULL, k_SCI_INCLUDE_CANCEL); }
	void CloseAdvances()  { if (sci_advancescreen_isOnScreen()) sci_advancescreen_removeMyWindow(AUI_BUTTON_ACTION_EXECUTE); }
	void OpenLibrary()    { open_GreatLibrary(); }
	void CloseLibrary()   { close_GreatLibrary(); }
	void OpenTrade()      { TradeManager::Display(); TradeManager::SetMode(TRADE_MANAGER_MARKET); }
	void CloseTrade()     { TradeManager::Hide(); }
	void OpenUnits()      { open_UnitStatus(); }
	void CloseUnits()     { UnitManager::Hide(); }
	void OpenArmy()
	{
		Player *p = Me();
		if (!p || !p->m_all_armies || p->m_all_armies->Num() == 0) return;
		Army a = p->m_all_armies->Access(0);
		if (a.IsValid() && a.Num() > 0)
			g_selected_item->SetSelectUnit(a[0]);
		ArmyManagerWindow::Display();
	}
	void CloseArmy()      { ArmyManagerWindow::Hide(); }
	void OpenDiplomacy()  { open_Diplomacy(); }
	void CloseDiplomacy() { DiplomacyWindow::Hide(); }
	void OpenIntel()      { IntelligenceWindow::Display(); }
	void CloseIntel()     { IntelligenceWindow::Hide(); }
	void OpenScore()      { InfoWindow::SelectScoreTab(); }
	void OpenWonders()    { InfoWindow::SelectWonderTab(); }
	void OpenRanking()    { InfoWindow::SelectRankingTab(); }
	void CloseInfo()      { InfoWindow::Close(); }
	void OpenQueue()      { Unit c = FirstCity(); if (c.IsValid()) EditQueue::Display(c); }
	void CloseQueue()     { EditQueue::Hide(); }
	void OpenOptions()    { open_OptionsScreen(1); }
	void CloseOptions()   { close_OptionsScreen(); }
	void OpenGraphics()   { graphicsscreen_displayMyWindow(); }
	void CloseGraphics()  { graphicsscreen_removeMyWindow(AUI_BUTTON_ACTION_EXECUTE); }
	void OpenGameplay()   { gameplayoptions_displayMyWindow(); }
	void CloseGameplay()  { gameplayoptions_removeMyWindow(AUI_BUTTON_ACTION_EXECUTE); }
	void OpenSound()      { soundscreen_displayMyWindow(); }
	void CloseSound()     { soundscreen_removeMyWindow(AUI_BUTTON_ACTION_EXECUTE); }
	void OpenProfile()    { ProfileEdit::Display(); }
	void CloseProfile()   { ProfileEdit::Hide(); }
	void OpenTile()       { Unit c = FirstCity(); if (c.IsValid()) helptile_displayData(c.RetPos()); }
	void CloseTile()      { if (helptile_isShown()) helptile_closeWindow(); }
	void OpenWizard()     { if (DipWizard::CanInitiateRightNow()) DipWizard::Display(); }
	void CloseWizard()    { DipWizard::Hide(); }
	void OpenGaia()       { ScienceVictoryDialog::Open(); }
	void CloseGaia()      { ScienceVictoryDialog::Close(); }

	struct TourWindow
	{
		const char *name;
		void      (*open)();
		void      (*close)();
	};

	const TourWindow k_windows[] =
	{
		{ "map",          Nothing,        Nothing        },
		{ "city",         OpenCity,       CloseCity      },
		{ "citystatus",   OpenCityStatus, close_CityStatus },
		{ "civstatus",    OpenCivStatus,  close_CivStatus  },
		{ "science",      OpenScience,    CloseScience   },
		{ "advances",     OpenAdvances,   CloseAdvances  },
		{ "library",      OpenLibrary,    CloseLibrary   },
		{ "trade",        OpenTrade,      CloseTrade     },
		{ "units",        OpenUnits,      CloseUnits     },
		{ "army",         OpenArmy,       CloseArmy      },
		{ "diplomacy",    OpenDiplomacy,  CloseDiplomacy },
		{ "intelligence", OpenIntel,      CloseIntel     },
		{ "dipwizard",    OpenWizard,     CloseWizard    },
		{ "info_score",   OpenScore,      CloseInfo      },
		{ "info_wonders", OpenWonders,    CloseInfo      },
		{ "info_ranking", OpenRanking,    CloseInfo      },
		{ "buildqueue",   OpenQueue,      CloseQueue     },
		{ "gaia",         OpenGaia,       CloseGaia      },
		{ "tileinfo",     OpenTile,       CloseTile      },
		{ "options",      OpenOptions,    CloseOptions   },
		{ "graphics",     OpenGraphics,   CloseGraphics  },
		{ "gameplay",     OpenGameplay,   CloseGameplay  },
		{ "sound",        OpenSound,      CloseSound     },
		{ "profile",      OpenProfile,    CloseProfile   },
	};
	const int k_count = sizeof(k_windows) / sizeof(k_windows[0]);

	double Seconds()
	{
		static const auto start = std::chrono::steady_clock::now();
		return std::chrono::duration<double>(std::chrono::steady_clock::now() - start).count();
	}
}

bool autotour_Process()
{
	static int    s_index = 0;
	static int    s_phase = 0;   // 0 open, 1 screenshot, 2 close
	static double s_since = 0.0;

	if (s_index >= k_count)
		return false;

	const TourWindow &w = k_windows[s_index];
	switch (s_phase)
	{
	case 0:
		close_AllScreens();
		autotest_Log("tour: %s", w.name);
		w.open();
		s_since = Seconds();
		s_phase = 1;
		break;

	case 1:
		if (Seconds() - s_since > 1.5)   // let it draw
		{
			char path[96];
			snprintf(path, sizeof(path), "autotest_ui_%02d_%s.png", s_index + 1, w.name);
			autotest_Screenshot(path);
			s_since = Seconds();
			s_phase = 2;
		}
		break;

	case 2:
		if (Seconds() - s_since > 0.5)
		{
			w.close();
			close_AllScreens();
			s_index++;
			s_phase = 0;
		}
		break;
	}
	return true;
}
