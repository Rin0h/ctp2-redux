#ifndef __SERVERSELECTWINDOW_H__
#define __SERVERSELECTWINDOW_H__

#include "ns_window.h"
#include "aui_action.h"

// ctp2-redux: besides the Anet game server list this window offers a direct
// connection: host a game on a fixed port, or join a host by address.

class ServerSelectWindow : public ns_Window
{
public:

	ServerSelectWindow( AUI_ERRCODE *retval );
	virtual ~ServerSelectWindow();

protected:
	ServerSelectWindow() : ns_Window() {}
	AUI_ERRCODE	InitCommon( void );
	AUI_ERRCODE CreateControls( void );

public:
	void	Update( bool wait = false );
	void	UpdateMyAddress( void );
	void	CopyAddress( int which );   // 0 = IPv4 line, 1 = IPv6 line
	virtual AUI_ERRCODE Idle( void );

	enum CONTROL
	{
		CONTROL_FIRST = 0,

		CONTROL_TITLESTATICTEXT = CONTROL_FIRST,
		CONTROL_SELECTSERVERLISTBOX,
		CONTROL_OKBUTTON,
		CONTROL_CANCELBUTTON,
		CONTROL_DIRECTSTATICTEXT,
		CONTROL_DIRECTTEXTFIELD,
		CONTROL_DIRECTJOINBUTTON,
		CONTROL_DIRECTHOSTBUTTON,
		CONTROL_MYADDRESSSTATICTEXT,
		CONTROL_MYADDRESS6STATICTEXT,
		CONTROL_COPYBUTTON,
		CONTROL_COPY6BUTTON,

		CONTROL_LAST,
		CONTROL_MAX = CONTROL_LAST - CONTROL_FIRST
	};

protected:
	aui_Action *m_dbActionArray[ 1 ];

	// ctp2-redux: the own addresses, for the copy buttons
	MBCHAR	m_copyText[ 2 ][ 128 ];
	time_t	m_copiedAt[ 2 ];

	AUI_ACTION_BASIC(OKButtonAction);
	AUI_ACTION_BASIC(CancelButtonAction);
	AUI_ACTION_BASIC(ServerListBoxAction);
	AUI_ACTION_BASIC(DialogBoxPopDownAction);
	AUI_ACTION_BASIC(DirectJoinButtonAction);
	AUI_ACTION_BASIC(DirectHostButtonAction);
	AUI_ACTION_BASIC(DirectTextFieldAction);
	AUI_ACTION_BASIC(CopyButtonAction);
	AUI_ACTION_BASIC(Copy6ButtonAction);
};

#endif
