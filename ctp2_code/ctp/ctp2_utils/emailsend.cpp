//----------------------------------------------------------------------------
//
// Project      : Call To Power 2
// File type    : C++ source
// Description  : Handing over the save game of an e-mail game (ctp2-redux)
//
//----------------------------------------------------------------------------
//
// See emailsend.h.
//
// MAPISendMail shows the mail program's compose window and only returns
// when the player has sent or discarded the mail, so it runs in a thread of
// its own; the game keeps drawing meanwhile.
//
//----------------------------------------------------------------------------

#include "c3.h"
#include "emailsend.h"

#include <cstdio>
#include <string>

#include "StrDB.h"              // g_theStringDB

#ifdef WIN32
#include <windows.h>
#include <shellapi.h>
#include <objbase.h>
#include <mapi.h>
#include <thread>
#endif

namespace
{
	std::string s_path;
	std::string s_recipient;
	int         s_round = 0;

	// Text from the string database, with an English fallback.
	std::string Text(const char *id, const char *fallback)
	{
		const char *s = g_theStringDB ? g_theStringDB->GetNameStr(id) : NULL;
		return (s && *s) ? s : fallback;
	}

	std::string Subject()
	{
		char buf[256];
		snprintf(buf, sizeof(buf), Text("EMAIL_TURN_SUBJECT", "Call to Power II: your turn (round %d)").c_str(), s_round);
		return buf;
	}

	std::string FileName()
	{
		size_t slash = s_path.find_last_of("\\/");
		return slash == std::string::npos ? s_path : s_path.substr(slash + 1);
	}

#ifdef WIN32
	std::string UrlEncode(const std::string &s)
	{
		static const char hex[] = "0123456789ABCDEF";
		std::string out;
		for (unsigned char c : s)
		{
			if (isalnum(c) || c == '-' || c == '_' || c == '.' || c == '@')
				out += (char)c;
			else
			{
				out += '%';
				out += hex[c >> 4];
				out += hex[c & 15];
			}
		}
		return out;
	}

	void ShowFileInExplorer(const std::string &path)
	{
		std::string args = "/select,\"" + path + "\"";
		ShellExecuteA(NULL, "open", "explorer.exe", args.c_str(), NULL, SW_SHOWNORMAL);
	}

	// No Simple MAPI mail program: show the file and open a new mail
	// through mailto: (recipient and subject, the file has to be added by
	// hand).
	void Fallback(const std::string &path, const std::string &to, const std::string &subject)
	{
		ShowFileInExplorer(path);
		std::string url = "mailto:" + UrlEncode(to) + "?subject=" + UrlEncode(subject);
		ShellExecuteA(NULL, "open", url.c_str(), NULL, NULL, SW_SHOWNORMAL);
	}

	void SendThread(std::string path, std::string to, std::string subject, std::string body, std::string name)
	{
		CoInitializeEx(NULL, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);

		ULONG result = MAPI_E_FAILURE;
		HMODULE mapi = LoadLibraryA("mapi32.dll");
		LPMAPISENDMAIL send = mapi ? (LPMAPISENDMAIL)GetProcAddress(mapi, "MAPISendMail") : NULL;
		if (send)
		{
			std::string address = "SMTP:" + to;

			MapiRecipDesc recipient;
			ZeroMemory(&recipient, sizeof(recipient));
			recipient.ulRecipClass = MAPI_TO;
			recipient.lpszName     = (LPSTR)to.c_str();
			recipient.lpszAddress  = (LPSTR)address.c_str();

			MapiFileDesc file;
			ZeroMemory(&file, sizeof(file));
			file.nPosition    = (ULONG)-1;
			file.lpszPathName = (LPSTR)path.c_str();
			file.lpszFileName = (LPSTR)name.c_str();

			MapiMessage message;
			ZeroMemory(&message, sizeof(message));
			message.lpszSubject  = (LPSTR)subject.c_str();
			message.lpszNoteText = (LPSTR)body.c_str();
			message.nRecipCount  = to.empty() ? 0 : 1;
			message.lpRecips     = to.empty() ? NULL : &recipient;
			message.nFileCount   = 1;
			message.lpFiles      = &file;

			result = send(0, 0, &message, MAPI_DIALOG | MAPI_LOGON_UI, 0);
		}
		if (mapi)
			FreeLibrary(mapi);

		// Discarding the mail is the player's decision, anything else means
		// there is no usable mail program.
		if (result != SUCCESS_SUCCESS && result != MAPI_USER_ABORT)
			Fallback(path, to, subject);

		CoUninitialize();
	}
#endif
}

void emailsend_Remember(const char *path, const char *recipient, int round)
{
	s_path      = path ? path : "";
	s_recipient = recipient ? recipient : "";
	s_round     = round;
}

void emailsend_Send()
{
	if (s_path.empty())
		return;
#ifdef WIN32
	std::string body = Text("EMAIL_TURN_BODY",
		"Your turn in Call to Power II. Save the attached file and open it with \"Load game\".");
	std::thread(SendThread, s_path, s_recipient, Subject(), body, FileName()).detach();
#endif
}

void emailsend_ShowFile()
{
	if (s_path.empty())
		return;
#ifdef WIN32
	ShowFileInExplorer(s_path);
#endif
}
