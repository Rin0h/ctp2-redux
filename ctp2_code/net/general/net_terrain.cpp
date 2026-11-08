//----------------------------------------------------------------------------
//
// Project      : Call To Power 2
// File type    : C++ source
// Description  : Multiplayer terrain improvement packet handling.
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
#include "net_terrain.h"

#include "gstypes.h"            // TERRAIN_TYPES
#include "network.h"
#include "net_util.h"
#include "TerrImprove.h"
#include "TerrImprovePool.h"
#include "World.h"              // g_theWorld
#include "player.h"             // g_player
#include "tiledmap.h"           // g_tiledMap
#include "TerrainImprovementRecord.h"   // g_theTerrainImprovementDB
#include "TerrainRecord.h"      // g_theTerrainDB

//----------------------------------------------------------------------------
//
// Name       : NetTerrainImprovement::NetTerrainImprovement
//
// Description: Constructor
//
// Parameters : TerrainImprovementData *data: The terrain improvement data to
//                                            send/retrieve.
//
// Globals    : -
//
// Returns    : -
//
// Remark(s)  : -
//
//----------------------------------------------------------------------------
NetTerrainImprovement::NetTerrainImprovement(TerrainImprovementData * data)
:   m_data  (data)
{ ; }

//----------------------------------------------------------------------------
//
// Name       : NetTerrainImprovement::Packetize
//
// Description: Generate an application data packet to transmit.
//
// Parameters : buf         : buffer to store the message
//
// Globals    : -
//
// Returns    : -
//
// Remark(s)  : -
//
//----------------------------------------------------------------------------
void NetTerrainImprovement::Packetize(uint8 *buf, uint16 &size)
{
	buf[0] = k_PACKET_TERRAIN_ID >> 8;
	buf[1] = k_PACKET_TERRAIN_ID & 0xff;

	size = 2;
	PUSHLONG(m_data->m_id);
	PUSHBYTE((uint8)m_data->m_owner);
	PUSHBYTE((uint8)m_data->m_type);
	PUSHSHORT((uint16)m_data->m_point.x);
	PUSHSHORT((uint16)m_data->m_point.y);
	PUSHSHORT((uint16)m_data->m_turnsToComplete);
	PUSHBYTE((unsigned char) m_data->m_transformType);
	PUSHLONG(m_data->m_materialCost);
}

//----------------------------------------------------------------------------
//
// Name       : NetFeatTracker::Unpacketize
//
// Description: Retrieve the data from a received application data packet.
//
// Parameters : id          : Sender identification?
//              buf         : Buffer with received message
//              size        : Length of received message (in bytes)
//
// Globals    : -
//
// Returns    : -
//
// Remark(s)  : -
//
//----------------------------------------------------------------------------
void NetTerrainImprovement::Unpacketize(uint16 id, uint8 *buf, uint16 size)
{
	Assert(MAKE_CIV3_ID(buf[0], buf[1]) == k_PACKET_TERRAIN_ID);
	sint32 pos = 2;
	MapPoint oldpoint;
	PLAYER_INDEX oldOwner = -1;

	TerrainImprovement imp;
	PULLLONGTYPE(imp, TerrainImprovement);

	// ctp2-redux: owner, type, position and terrain are checked before the
	// object changes (the terrain is 255 for "none")
	{
		sint32 p = 6;
		net_Need(p, 1 + 1 + 2 + 2 + 2 + 1, size);
		NET_PLAYER(buf[p]);
		NET_INDEX(buf[p + 1], g_theTerrainImprovementDB->NumRecords());
		MapPoint at(static_cast<sint16>(getshort(&buf[p + 2])), static_cast<sint16>(getshort(&buf[p + 4])));
		NET_POS(at);
		NET_CHECK(buf[p + 8] < g_theTerrainDB->NumRecords() || buf[p + 8] == 0xff);
	}
	g_network.CheckReceivedObject((uint32)imp);

	if(!g_theTerrainImprovementPool->IsValid(imp)) {
		m_data = new TerrainImprovementData(imp);
	} else {
		m_data = g_theTerrainImprovementPool->AccessTerrainImprovement(imp);
		oldpoint = m_data->m_point;
		oldOwner = m_data->m_owner;
	}

	pos = 6;
	PULLBYTE(m_data->m_owner);
	PULLBYTETYPE(m_data->m_type, TERRAIN_IMPROVEMENT);
	PULLSHORT(m_data->m_point.x);
	PULLSHORT(m_data->m_point.y);
	PULLSHORT(m_data->m_turnsToComplete);
	PULLBYTETYPE(m_data->m_transformType,TERRAIN_TYPES);
	PULLLONG(m_data->m_materialCost);

	if(!g_theTerrainImprovementPool->IsValid(imp)) {
		g_theTerrainImprovementPool->HackSetKey(((uint32)imp & k_ID_KEY_MASK) + 1);
		g_theTerrainImprovementPool->Insert(m_data);
		g_theWorld->InsertImprovement(imp, m_data->m_point);
		g_tiledMap->RedrawTile(&m_data->m_point);
		g_player[NET_PLAYER(m_data->m_owner)]->AddImprovement(imp);
	} else {
		if(oldpoint != m_data->m_point) {

			g_theWorld->RemoveImprovement(imp, oldpoint);
			g_theWorld->InsertImprovement(imp, m_data->m_point);

			g_tiledMap->RedrawTile(&oldpoint);
			g_tiledMap->RedrawTile(&m_data->m_point);
		}

		if(oldOwner != m_data->m_owner) {

			g_player[NET_PLAYER(oldOwner)]->RemoveImprovementReferences(imp);
			g_player[NET_PLAYER(m_data->m_owner)]->AddImprovement(imp);
		}
	}
}
