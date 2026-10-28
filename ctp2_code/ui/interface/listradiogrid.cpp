//----------------------------------------------------------------------------
//
// Project      : Call To Power 2
// File type    : C++ source
// Description  : List box shown as the original grid of radio buttons
//                (ctp2-redux classic interface)
//
//----------------------------------------------------------------------------

#include "c3.h"
#include "listradiogrid.h"

#include <algorithm>

#include "aui_ldl.h"
#include "aui_radio.h"
#include "aui_switchgroup.h"
#include "aui_uniqueid.h"
#include "aui_window.h"
#include "ctp2_listbox.h"
#include "ctp2_listitem.h"
#include "ctp2_Static.h"
#include "ldl_data.hpp"             // ldl_datablock

namespace
{
	void ListRadioGrid_Press(aui_Control * control, uint32 action, uint32 data, Cookie cookie)
	{
		if (action == (uint32)AUI_SWITCH_ACTION_ON)
			static_cast<ListRadioGrid *>(cookie.m_voidPtr)->Press(control);
	}

	sint32 BlockInt(ldl_datablock * block, char const * name, sint32 fallback)
	{
		sint32 const value = block ? block->GetInt(name) : 0;
		return value > 0 ? value : fallback;
	}
}

ListRadioGrid * ListRadioGrid::Create(aui_Window * window, ctp2_ListBox * list, char const * block)
{
	if (!window || !list || !aui_Ldl::IsValid(block)) return NULL;

	AUI_ERRCODE       errcode = AUI_ERRCODE_OK;
	aui_SwitchGroup * group   = new aui_SwitchGroup(&errcode, aui_UniqueId(), block);
	if (!AUI_NEWOK(group, errcode))
	{
		delete group;
		return NULL;
	}

	window->AddControl(group);
	list->Hide();

	return new ListRadioGrid(window, list, block, group);
}

ListRadioGrid::ListRadioGrid(aui_Window * window, ctp2_ListBox * list, char const * block, aui_SwitchGroup * group)
:
	m_window    (window),
	m_list      (list),
	m_block     (block),
	m_group     (group),
	m_radios    (),
	m_building  (false)
{
}

ListRadioGrid::~ListRadioGrid()
{
	Clear();
	m_window->RemoveControl(m_group->Id());
	delete m_group;
}

void ListRadioGrid::Clear()
{
	for (size_t i = 0; i < m_radios.size(); ++i)
	{
		if (m_radios[i])
		{
			m_group->RemoveSwitch(m_radios[i]->Id());
			delete m_radios[i];
		}
	}
	m_radios.clear();
}

void ListRadioGrid::Rebuild(sint32 wanted)
{
	Clear();

	ldl_datablock * block   = aui_Ldl::FindDataBlock(m_block.c_str());
	sint32 const    columns = BlockInt(block, "columns",   1);
	sint32 const    colW    = BlockInt(block, "colwidth",  151);
	sint32 const    rowH    = BlockInt(block, "rowheight", 30);
	sint32 const    count   = m_list->NumItems();
	sint32 const    rows    = std::max<sint32>(1, (count + columns - 1) / columns);

	std::string const radioBlock = m_block + ".Radio";
	aui_Item *        selected   = m_list->GetSelectedItem();

	m_building = true;
	for (sint32 i = 0; i < count; ++i)
	{
		ctp2_ListItem * item = (ctp2_ListItem *)m_list->GetItemByIndex(i);
		ctp2_Static *   text = (ctp2_Static *)item->GetChildByIndex(0);

		AUI_ERRCODE errcode = AUI_ERRCODE_OK;
		aui_Radio * radio   = new aui_Radio(&errcode, aui_UniqueId(), radioBlock.c_str(),
		                                    ListRadioGrid_Press, Cookie(this));
		if (!AUI_NEWOK(radio, errcode))
		{
			delete radio;
			radio = NULL;
		}
		m_radios.push_back(radio);
		if (!radio) continue;

		radio->Offset((i / rows) * colW, (i % rows) * rowH);
		radio->SetText(text ? text->GetText() : "");
		m_group->AddSwitch(radio);
		if (selected ? item == selected : item->GetUserDataSint32() == wanted)
			radio->SetState(1);
		radio->Enable(!item->IsDisabled());
	}
	m_building = false;
}

void ListRadioGrid::Press(aui_Control * control)
{
	if (m_building) return;

	for (size_t i = 0; i < m_radios.size(); ++i)
	{
		if (m_radios[i] == control)
		{
			m_list->SelectItem((sint32)i);
			return;
		}
	}
}
