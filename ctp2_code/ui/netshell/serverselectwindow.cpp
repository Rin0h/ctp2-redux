//----------------------------------------------------------------------------
//
// Project      : Call To Power 2
// File type    : C++ source
// Description  : Multiplayer server select window
// Id           : $Id$
//
//----------------------------------------------------------------------------
//
// Disclaimer
//
// THIS FILE IS NOT GENERATED OR SUPPORTED BY ACTIVISION.
//
// This material has been developed at apolyton.net by the Apolyton CtP2
// Source Code Project. Contact the authors at ctp2source@apolyton.net.
//
//----------------------------------------------------------------------------
//
// Compiler flags
//
// - None
//
//----------------------------------------------------------------------------
//
// Modifications from the original Activision code:
//
// - Initialized local variables. (Sep 9th 2005 Martin Gühmann)
//
//----------------------------------------------------------------------------

#include "c3.h"
#include <string>

#include "aui_ldl.h"
#include "aui_uniqueid.h"
#include "aui_static.h"
#include "aui_button.h"
#include "aui_textfield.h"

#include "c3_button.h"
#include "c3_static.h"
#include "c3textfield.h"
#include "StrDB.h"

#include <time.h>

#include "netshell.h"
#include "ns_customlistbox.h"

#include "serverselectwindow.h"
#include "autotest.h"                   // ctp2-redux test mode
#include "playerselectwindow.h"
#include "passwordscreen.h"
#include "dialogboxwindow.h"
#include "spnewgamewindow.h"              // spNew_ctp2_Button
#include "ctp2_button.h"
#ifdef __AUI_USE_SDL__
#include <SDL2/SDL_clipboard.h>
#endif

static DialogBoxWindow *s_dbw = NULL;
// When the "waiting for servers" dialog was opened. Without a reachable
// Anet server nothing ever answers, so the dialog is closed after a while
// to let the player use the direct connection controls.
static time_t s_dbwShown = 0;
static const sint32 k_WAIT_FOR_SERVERS_SECONDS = 6;

MBCHAR g_serverName[ 100 + 1 ] = "";

ServerSelectWindow::ServerSelectWindow(
	AUI_ERRCODE *retval )
	:
	ns_Window(
		retval,
		aui_UniqueId(),
		"serverselectwindow",
		0,
		AUI_WINDOW_TYPE_STANDARD )
{
	Assert( AUI_SUCCESS(*retval) );
	if ( !AUI_SUCCESS(*retval) ) return;

	*retval = InitCommon();
	Assert( AUI_SUCCESS(*retval) );
	if ( !AUI_SUCCESS(*retval) ) return;

	*retval = CreateControls();
	Assert( AUI_SUCCESS(*retval) );
}

AUI_ERRCODE ServerSelectWindow::InitCommon( void )
{
	m_controls = new aui_Control *[ m_numControls = CONTROL_MAX ];
	Assert( m_controls != NULL );
	if ( !m_controls ) return AUI_ERRCODE_MEMALLOCFAILED;
	memset( m_controls, 0, m_numControls * sizeof( aui_Control *) );

	m_dbActionArray[ 0 ] = new DialogBoxPopDownAction;
	Assert( m_dbActionArray[ 0 ] != NULL );
	if ( !m_dbActionArray[ 0 ] ) return AUI_ERRCODE_MEMALLOCFAILED;

	return AUI_ERRCODE_OK;
}

AUI_ERRCODE ServerSelectWindow::CreateControls( void )
{
	AUI_ERRCODE     errcode = AUI_ERRCODE_OK;
	aui_Control *   control = new c3_Static
	    (&errcode, aui_UniqueId(), "serverselectwindow.titlestatictext");
	Assert( AUI_NEWOK(control,errcode) );
	if ( !AUI_NEWOK(control,errcode) ) return errcode;
	m_controls[ CONTROL_TITLESTATICTEXT ] = control;

	control = new ns_ServerListBox(
		&errcode,
		aui_UniqueId(),
		"serverselectwindow.selectserverlistbox" );
	Assert( AUI_NEWOK(control,errcode) );
	if ( !AUI_NEWOK(control,errcode) ) return errcode;
	m_controls[ CONTROL_SELECTSERVERLISTBOX ] = control;

	control = new aui_Button(
		&errcode,
		aui_UniqueId(),
		"serverselectwindow.okbutton" );
	Assert( AUI_NEWOK(control,errcode) );
	if ( !AUI_NEWOK(control,errcode) ) return errcode;
	m_controls[ CONTROL_OKBUTTON ] = control;

	control = new aui_Button(
		&errcode,
		aui_UniqueId(),
		"serverselectwindow.cancelbutton" );
	Assert( AUI_NEWOK(control,errcode) );
	if ( !AUI_NEWOK(control,errcode) ) return errcode;
	m_controls[ CONTROL_CANCELBUTTON ] = control;

	control = new c3_Static(
		&errcode,
		aui_UniqueId(),
		"serverselectwindow.directstatictext" );
	Assert( AUI_NEWOK(control,errcode) );
	if ( !AUI_NEWOK(control,errcode) ) return errcode;
	m_controls[ CONTROL_DIRECTSTATICTEXT ] = control;

	control = new C3TextField(
		&errcode,
		aui_UniqueId(),
		"serverselectwindow.directtextfield" );
	Assert( AUI_NEWOK(control,errcode) );
	if ( !AUI_NEWOK(control,errcode) ) return errcode;
	m_controls[ CONTROL_DIRECTTEXTFIELD ] = control;

	// same oval button style as the game setup ("Profile")
	control = spNew_ctp2_Button(
		&errcode,
		"serverselectwindow",
		"directjoinbutton",
		NULL);
	Assert( AUI_NEWOK(control,errcode) );
	if ( !AUI_NEWOK(control,errcode) ) return errcode;
	m_controls[ CONTROL_DIRECTJOINBUTTON ] = control;

	// same oval button style as the game setup ("Profile")
	control = spNew_ctp2_Button(
		&errcode,
		"serverselectwindow",
		"directhostbutton",
		NULL);
	Assert( AUI_NEWOK(control,errcode) );
	if ( !AUI_NEWOK(control,errcode) ) return errcode;
	m_controls[ CONTROL_DIRECTHOSTBUTTON ] = control;

	control = new c3_Static(
		&errcode,
		aui_UniqueId(),
		"serverselectwindow.myaddressstatictext" );
	Assert( AUI_NEWOK(control,errcode) );
	if ( !AUI_NEWOK(control,errcode) ) return errcode;
	m_controls[ CONTROL_MYADDRESSSTATICTEXT ] = control;

	control = new c3_Static(
		&errcode,
		aui_UniqueId(),
		"serverselectwindow.myaddress6statictext" );
	Assert( AUI_NEWOK(control,errcode) );
	if ( !AUI_NEWOK(control,errcode) ) return errcode;
	m_controls[ CONTROL_MYADDRESS6STATICTEXT ] = control;

	control = spNew_ctp2_Button(
		&errcode,
		"serverselectwindow",
		"copybutton",
		NULL);
	Assert( AUI_NEWOK(control,errcode) );
	if ( !AUI_NEWOK(control,errcode) ) return errcode;
	m_controls[ CONTROL_COPYBUTTON ] = control;

	control = spNew_ctp2_Button(
		&errcode,
		"serverselectwindow",
		"copy6button",
		NULL);
	Assert( AUI_NEWOK(control,errcode) );
	if ( !AUI_NEWOK(control,errcode) ) return errcode;
	m_controls[ CONTROL_COPY6BUTTON ] = control;
	memset( m_copyText, 0, sizeof(m_copyText) );
	m_copiedAt[ 0 ] = m_copiedAt[ 1 ] = 0;

	aui_Ldl::SetupHeirarchyFromRoot( "serverselectwindow" );


	aui_Action *action;

	action = new OKButtonAction;
	Assert( action != NULL );
	if ( !action ) return AUI_ERRCODE_MEMALLOCFAILED;
	m_controls[ CONTROL_OKBUTTON ]->SetAction( action );

	action = new CancelButtonAction;
	Assert( action != NULL );
	if ( !action ) return AUI_ERRCODE_MEMALLOCFAILED;
	m_controls[ CONTROL_CANCELBUTTON ]->SetAction( action );

	action = new ServerListBoxAction;
	Assert( action != NULL );
	if ( !action ) return AUI_ERRCODE_MEMALLOCFAILED;
	m_controls[ CONTROL_SELECTSERVERLISTBOX ]->SetAction( action );

	action = new DirectJoinButtonAction;
	Assert( action != NULL );
	if ( !action ) return AUI_ERRCODE_MEMALLOCFAILED;
	m_controls[ CONTROL_DIRECTJOINBUTTON ]->SetAction( action );

	action = new DirectHostButtonAction;
	Assert( action != NULL );
	if ( !action ) return AUI_ERRCODE_MEMALLOCFAILED;
	m_controls[ CONTROL_DIRECTHOSTBUTTON ]->SetAction( action );

	action = new DirectTextFieldAction;
	Assert( action != NULL );
	if ( !action ) return AUI_ERRCODE_MEMALLOCFAILED;
	m_controls[ CONTROL_DIRECTTEXTFIELD ]->SetAction( action );

	action = new CopyButtonAction;
	Assert( action != NULL );
	if ( !action ) return AUI_ERRCODE_MEMALLOCFAILED;
	m_controls[ CONTROL_COPYBUTTON ]->SetAction( action );

	action = new Copy6ButtonAction;
	Assert( action != NULL );
	if ( !action ) return AUI_ERRCODE_MEMALLOCFAILED;
	m_controls[ CONTROL_COPY6BUTTON ]->SetAction( action );




	((aui_ListBox *)m_controls[ CONTROL_SELECTSERVERLISTBOX ])->
		SetForceSelect( TRUE );

	// ctp2-redux: the Activision game servers are gone, only the direct
	// connection is offered
	m_controls[ CONTROL_SELECTSERVERLISTBOX ]->Hide();
	m_controls[ CONTROL_OKBUTTON ]->Hide();
	m_controls[ CONTROL_COPYBUTTON ]->Hide();     // until the address is known
	m_controls[ CONTROL_COPY6BUTTON ]->Hide();

	Update();

	return AUI_ERRCODE_OK;
}

ServerSelectWindow::~ServerSelectWindow()
{
	delete m_dbActionArray[ 0 ];
}

void ServerSelectWindow::Update( bool wait )
{
	ns_ServerListBox *listbox = (ns_ServerListBox *)(FindControl( ServerSelectWindow::CONTROL_SELECTSERVERLISTBOX ));
	ns_ServerItem *item = (ns_ServerItem *)listbox->GetSelectedItem();
	c3_Button *b = (c3_Button *)(FindControl( ServerSelectWindow::CONTROL_OKBUTTON ));
	if(wait)
		if ( !s_dbw )
		{
			s_dbw = DialogBoxWindow::PopUp(
				"waitserverdialogboxwindow",
				m_dbActionArray );
			s_dbwShown = time(NULL);
		}
	UpdateMyAddress();
	if(item)
	{
		b->Enable(TRUE);

		static bool didThisAlready = false;
		if ( !didThisAlready )
		{
			NETFunc::Server *server = item->GetNetShellObject()->GetNETFuncObject();
			g_netfunc->SetServer( server );
			didThisAlready = true;

			((aui_ListBox *)m_controls[ CONTROL_SELECTSERVERLISTBOX ])->
				SetForceSelect( FALSE );

		}
	}
	else
	{
		b->Enable(FALSE);
	}
}

// Shows the own address ("host:port") next to the host button, so the host
// can tell the other players where to connect. Behind a router the player
// has to replace the local address by the public one.
#ifdef WIN32
// ctp2-redux: the IPv6 address this machine uses towards the internet, for
// players without a public IPv4 address (DS-Lite). A UDP socket "connected"
// to a public IPv6 address tells which source address the system picks; no
// packet is sent. winsock.h knows no IPv6, hence the local structure.
namespace
{
	struct SockAddrIn6
	{
		unsigned short family;
		unsigned short port;
		unsigned long  flowinfo;
		unsigned char  addr[16];
		unsigned long  scope;
	};

	bool GetMyIPv6(char *buf, size_t size)
	{
		const int k_AF_INET6 = 23;
		SOCKET s = socket(k_AF_INET6, SOCK_DGRAM, IPPROTO_UDP);
		if (s == INVALID_SOCKET)
			return false;

		SockAddrIn6 remote;
		memset(&remote, 0, sizeof(remote));
		remote.family = k_AF_INET6;
		remote.port   = htons(53);
		static const unsigned char k_public[16] =   // 2001:4860:4860::8888
			{ 0x20,0x01, 0x48,0x60, 0x48,0x60, 0,0, 0,0, 0,0, 0,0, 0x88,0x88 };
		memcpy(remote.addr, k_public, 16);

		SockAddrIn6 local;
		memset(&local, 0, sizeof(local));
		int len = sizeof(local);
		bool ok = connect(s, (sockaddr *)&remote, sizeof(remote)) == 0
		       && getsockname(s, (sockaddr *)&local, &len) == 0
		       && local.family == k_AF_INET6
		       && (local.addr[0] & 0xe0) == 0x20;          // global unicast 2000::/3
		closesocket(s);
		if (!ok)
			return false;

		// groups, longest run of zero groups as "::" (RFC 5952)
		unsigned int g[8];
		for (int i = 0; i < 8; i++)
			g[i] = (local.addr[2*i] << 8) | local.addr[2*i + 1];
		int bestStart = -1, bestLen = 1;
		for (int i = 0; i < 8; )
		{
			int j = i;
			while (j < 8 && g[j] == 0) j++;
			if (j - i > bestLen) { bestStart = i; bestLen = j - i; }
			i = (j == i) ? i + 1 : j;
		}
		std::string text;
		char part[8];
		for (int i = 0; i < 8; i++)
		{
			if (i == bestStart)
			{
				text += "::";
				i += bestLen - 1;
				continue;
			}
			if (!text.empty() && text[text.size() - 1] != ':')
				text += ':';
			sprintf(part, "%x", g[i]);
			text += part;
		}
		snprintf(buf, size, "%s", text.c_str());
		return true;
	}
}
#endif

void ServerSelectWindow::UpdateMyAddress( void )
{
	c3_Static *text = (c3_Static *)m_controls[ CONTROL_MYADDRESSSTATICTEXT ];
	if ( !text || !g_netfunc ) return;

	MBCHAR address[128] = "";
	if ( g_netfunc->GetMyAddress( address, sizeof(address) ) )
	{
		MBCHAR label[256];
		sprintf( label, "%s %s", g_theStringDB->GetNameStr("str_ldl_DIRECT_YOUR_ADDRESS"), address );
		text->SetText( label );
		snprintf( m_copyText[ 0 ], sizeof(m_copyText[ 0 ]), "%s", address );
	}
	else
	{
		text->SetText( "" );
		m_copyText[ 0 ][ 0 ] = 0;
	}

	// second line: the IPv6 address with the same port
	c3_Static *text6 = (c3_Static *)m_controls[ CONTROL_MYADDRESS6STATICTEXT ];
	if ( text6 )
	{
		MBCHAR v6[64];
		const char *port = strrchr( address, ':' );
#ifdef WIN32
		if ( port && GetMyIPv6( v6, sizeof(v6) ) )
		{
			MBCHAR label[256];
			sprintf( label, "IPv6: [%s]%s", v6, port );
			text6->SetText( label );
			snprintf( m_copyText[ 1 ], sizeof(m_copyText[ 1 ]), "[%s]%s", v6, port );
		}
		else
#endif
		{
			text6->SetText( "" );
			m_copyText[ 1 ][ 0 ] = 0;
		}
	}

	for ( int i = 0; i < 2; i++ )
	{
		aui_Control *b = m_controls[ i == 0 ? CONTROL_COPYBUTTON : CONTROL_COPY6BUTTON ];
		if ( !b ) continue;
		if ( m_copyText[ i ][ 0 ] ) b->Show(); else b->Hide();
	}
}

// Puts the own address into the clipboard; the button says "copied" for a
// moment (reset in Idle).
void ServerSelectWindow::CopyAddress( int which )
{
	if ( which < 0 || which > 1 || !m_copyText[ which ][ 0 ] ) return;

#ifdef __AUI_USE_SDL__
	SDL_SetClipboardText( m_copyText[ which ] );
#elif defined(WIN32)
	if ( OpenClipboard( NULL ) )
	{
		EmptyClipboard();
		size_t len = strlen( m_copyText[ which ] ) + 1;
		HGLOBAL mem = GlobalAlloc( GMEM_MOVEABLE, len );
		if ( mem )
		{
			memcpy( GlobalLock( mem ), m_copyText[ which ], len );
			GlobalUnlock( mem );
			SetClipboardData( CF_TEXT, mem );
		}
		CloseClipboard();
	}
#endif

	ctp2_Button *b = (ctp2_Button *)m_controls[ which == 0 ? CONTROL_COPYBUTTON : CONTROL_COPY6BUTTON ];
	if ( b ) b->SetText( g_theStringDB->GetNameStr("str_ldl_DIRECT_COPIED") );
	m_copiedAt[ which ] = time( NULL );
}

AUI_ERRCODE ServerSelectWindow::Idle( void )
{
	for ( int i = 0; i < 2; i++ )
	{
		if ( m_copiedAt[ i ] && time( NULL ) - m_copiedAt[ i ] >= 2 )
		{
			m_copiedAt[ i ] = 0;
			ctp2_Button *b = (ctp2_Button *)m_controls[ i == 0 ? CONTROL_COPYBUTTON : CONTROL_COPY6BUTTON ];
			if ( b ) b->SetText( g_theStringDB->GetNameStr("str_ldl_DIRECT_COPY") );
		}
	}

	if (g_netfunc)
	{
		if ( s_dbw && (g_netfunc->GetStatus() == NETFunc::PRECONNECT ||
		               time(NULL) - s_dbwShown >= k_WAIT_FOR_SERVERS_SECONDS) )
		{
			// Connected (or no answer): give the player the direct connection
			// controls, nobody waits for the old server list any more.
			DialogBoxWindow::PopDown( s_dbw );
			s_dbw = NULL;
			UpdateMyAddress();
		}

		while (NETFunc::Message * m = g_netfunc->GetMessage())
		{
			g_netfunc->HandleMessage(m);

			switch ( m->GetCode() )
			{
			case dp_SESSIONLOST_PACKET_ID:
				passwordscreen_displayMyWindow( PASSWORDSCREEN_MODE_CONNECTIONLOST );
				break;

			case dp_OBJECTDELTA_PACKET_ID:
				{
					dp_objectDelta_packet_t *   p =
					    (dp_objectDelta_packet_t *) m->GetBody();

					if (p->key[0] == dp_KEY_SERVERPINGS
					    && (p->status == dp_RES_CREATED || p->status == dp_RES_CHANGED)
					    && p->data.serv.loss_percent != 100 && s_dbw
					   )
					{
						DialogBoxWindow::PopDown(s_dbw);
						s_dbw = NULL;
					}
				}
				break;
			default:
				break;
			}

			delete m;
		}

		// ctp2-redux test mode: direct host or direct join
		if (autotest_Active() && (g_netfunc->GetStatus() == NETFunc::PRECONNECT ||
		                          g_netfunc->GetStatus() == NETFunc::LOGIN))
		{
			if (autotest_Step("shot-connect"))
				autotest_Screenshot("autotest_connect.png");
			else if (autotest_IsHost())
			{
				if (autotest_Step("direct-host"))
				{
					aui_Control *b = m_controls[ CONTROL_DIRECTHOSTBUTTON ];
					b->GetAction()->Execute( b, AUI_BUTTON_ACTION_EXECUTE, 0 );
				}
			}
			else if (!autotest_IsHost() && autotest_Step("direct-join"))
			{
				((aui_TextField *)m_controls[ CONTROL_DIRECTTEXTFIELD ])->SetFieldText( autotest_Address() );
				aui_Control *b = m_controls[ CONTROL_DIRECTJOINBUTTON ];
				b->GetAction()->Execute( b, AUI_BUTTON_ACTION_EXECUTE, 0 );
			}
		}

		if(g_netfunc->GetStatus() == NETFunc::START)
			g_netshell->GotoScreen( NetShell::SCREEN_CONNECTIONSELECT );
	}

	return AUI_ERRCODE_OK;
}

void ServerSelectWindow::ServerListBoxAction::Execute(
	aui_Control *control,
	uint32 action,
	uint32 data )
{
	ns_ServerListBox *listbox = (ns_ServerListBox *)control;
	switch ( action )
	{
	case AUI_LISTBOX_ACTION_SELECT:
		if(listbox->size())
			((ServerSelectWindow *)control->GetParent())->Update();
		break;

	case AUI_LISTBOX_ACTION_DOUBLECLICKSELECT:
	{
		sint32 index = listbox->ExtractDoubleClickedItem( data );
		aui_Item *item = listbox->GetItemByIndex( index );
		listbox->SelectItem( item );

		c3_Button *button = (c3_Button *)((ServerSelectWindow *)control->
			GetParentWindow())->FindControl( CONTROL_OKBUTTON );
		button->GetAction()->Execute( button, AUI_BUTTON_ACTION_EXECUTE, 0 );
		break;
	}

	default:
		break;
	}
}

void ServerSelectWindow::OKButtonAction::Execute(
	aui_Control *control,
	uint32 action,
	uint32 data )
{
	if ( action != (uint32)AUI_BUTTON_ACTION_EXECUTE ) return;

	ServerSelectWindow *w = (ServerSelectWindow *)control->GetParentWindow();
	ns_ServerListBox *listbox = (ns_ServerListBox *)(w->FindControl( ServerSelectWindow ::CONTROL_SELECTSERVERLISTBOX ));
	ns_ServerItem *item = (ns_ServerItem *)listbox->GetSelectedItem();

	if(item) {

		strncpy( g_serverName, item->GetText(), 100 );

		NETFunc::Server *server = item->GetNetShellObject()->GetNETFuncObject();
		g_netfunc->SetServer(server);
		g_netfunc->Login( "", "" );

		g_netshell->GotoScreen( NetShell::SCREEN_PLAYERSELECT );
	}
	else {

		strncpy( g_serverName, "", 100 );
	}
}

void ServerSelectWindow::CancelButtonAction::Execute(
	aui_Control *control,
	uint32 action,
	uint32 data )
{
	if ( action != (uint32)AUI_BUTTON_ACTION_EXECUTE ) return;

	strncpy( g_serverName, "", 100 );

	g_netfunc->Disconnect();
}

void ServerSelectWindow::DialogBoxPopDownAction::Execute(
	aui_Control *control,
	uint32 action,
	uint32 data )
{
	if ( action != (uint32)AUI_BUTTON_ACTION_EXECUTE ) return;

	g_netfunc->Disconnect();


	if ( s_dbw )
	{
		DialogBoxWindow::PopDown( s_dbw );
		s_dbw = NULL;
	}

	g_netshell->GotoScreen( NetShell::SCREEN_CONNECTIONSELECT );
}

// Join the lobby of a host at the address typed into the text field.
void ServerSelectWindow::DirectJoinButtonAction::Execute(
	aui_Control *control,
	uint32 action,
	uint32 data )
{
	if ( action != (uint32)AUI_BUTTON_ACTION_EXECUTE ) return;

	ServerSelectWindow *w = (ServerSelectWindow *)control->GetParentWindow();
	aui_TextField *field = (aui_TextField *)w->FindControl( ServerSelectWindow::CONTROL_DIRECTTEXTFIELD );
	c3_Static *info = (c3_Static *)w->FindControl( ServerSelectWindow::CONTROL_MYADDRESSSTATICTEXT );

	MBCHAR address[128];
	address[0] = 0;
	field->GetFieldText( address, sizeof(address) - 1 );

	// trim blanks
	MBCHAR *start = address;
	while ( *start == ' ' ) start++;
	size_t len = strlen( start );
	while ( len > 0 && start[len - 1] == ' ' ) start[--len] = 0;
	if ( len == 0 ) return;

	if ( s_dbw )
	{
		DialogBoxWindow::PopDown( s_dbw );
		s_dbw = NULL;
	}

	if ( g_netfunc->SetDirectAddress( start ) == NETFunc::OK )
	{
		strncpy( g_serverName, start, 100 );
		g_netshell->GotoScreen( NetShell::SCREEN_PLAYERSELECT );
	}
	else if ( info )
	{
		info->SetText( g_theStringDB->GetNameStr("str_ldl_DIRECT_NO_CONTACT") );
	}
}

// Host a game on this machine without an Anet game server.
void ServerSelectWindow::DirectHostButtonAction::Execute(
	aui_Control *control,
	uint32 action,
	uint32 data )
{
	if ( action != (uint32)AUI_BUTTON_ACTION_EXECUTE ) return;

	if ( s_dbw )
	{
		DialogBoxWindow::PopDown( s_dbw );
		s_dbw = NULL;
	}

	if ( g_netfunc->SetDirectHost() == NETFunc::OK )
	{
		strncpy( g_serverName, "", 100 );
		g_netshell->GotoScreen( NetShell::SCREEN_PLAYERSELECT );
	}
}

void ServerSelectWindow::CopyButtonAction::Execute(
	aui_Control *control,
	uint32 action,
	uint32 data )
{
	if ( action != (uint32)AUI_BUTTON_ACTION_EXECUTE ) return;
	((ServerSelectWindow *)control->GetParentWindow())->CopyAddress( 0 );
}

void ServerSelectWindow::Copy6ButtonAction::Execute(
	aui_Control *control,
	uint32 action,
	uint32 data )
{
	if ( action != (uint32)AUI_BUTTON_ACTION_EXECUTE ) return;
	((ServerSelectWindow *)control->GetParentWindow())->CopyAddress( 1 );
}

// Enter in the address field joins.
void ServerSelectWindow::DirectTextFieldAction::Execute(
	aui_Control *control,
	uint32 action,
	uint32 data )
{
	if ( action != (uint32)AUI_TEXTFIELD_ACTION_EXECUTE ) return;

	ServerSelectWindow *w = (ServerSelectWindow *)control->GetParentWindow();
	aui_Control *button = w->FindControl( ServerSelectWindow::CONTROL_DIRECTJOINBUTTON );
	if ( button && button->GetAction() )
		button->GetAction()->Execute( button, AUI_BUTTON_ACTION_EXECUTE, 0 );
}
