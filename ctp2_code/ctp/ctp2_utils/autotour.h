//----------------------------------------------------------------------------
//
// Project      : Call To Power 2
// File type    : C++ header
// Description  : Test mode: screenshot tour of the game windows (ctp2-redux)
//
//----------------------------------------------------------------------------

#ifndef AUTOTOUR_H__
#define AUTOTOUR_H__

// One step of the tour, called every frame during the own turn. Returns
// true while the tour is still running.
bool autotour_Process();

// The screens before a game (main menu, single player screen, new game
// screen and its pop-ups), called every frame at the main menu. Returns
// true while running; afterwards the main menu is shown again.
bool autotour_ProcessShell();

#endif
