//----------------------------------------------------------------------------
//
// Project      : Call To Power 2
// File type    : C++ header
// Description  : Handing over the save game of an e-mail game (ctp2-redux)
//
//----------------------------------------------------------------------------
//
// After a turn in an e-mail game the save game for the next player is
// written to the desktop. The player can then
//   - send it with the default mail program (Simple MAPI: a new mail with
//     recipient, subject and the save game attached opens), or
//   - show the file in the explorer and send it by himself.
// Without a Simple MAPI mail program (webmail, new Outlook) sending falls
// back to showing the file plus a mailto: link with recipient and subject.
//
//----------------------------------------------------------------------------

#ifndef EMAILSEND_H__
#define EMAILSEND_H__

// The save game that was just written for the next player.
void emailsend_Remember(const char *path, const char *recipient, int round);

// Script functions SendEmailTurn() and ShowEmailTurnFile().
void emailsend_Send();
void emailsend_ShowFile();

#endif
