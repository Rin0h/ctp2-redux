//----------------------------------------------------------------------------
//
// Project      : Call To Power 2
// File type    : C++ header
// Description  : List box shown as the original grid of radio buttons
//                (ctp2-redux classic interface)
//
//----------------------------------------------------------------------------

#ifndef LISTRADIOGRID_H__
#define LISTRADIOGRID_H__

#include <string>
#include <vector>

class aui_Control;
class aui_Radio;
class aui_SwitchGroup;
class aui_Window;
class ctp2_ListBox;

// The Apolyton Edition replaced the original radio buttons of the new game
// pop-ups by list boxes, filled from the databases. In the classic interface
// the list stays the model (it is filled, read and selected as before) but
// is hidden, and its items are shown as radio buttons. A click selects the
// list item, so the list's own select callback runs.
class ListRadioGrid
{
public:
	// The grid of the layout block, or NULL when the layout has none. The
	// block gives columns, colwidth and rowheight, its child block Radio the
	// look of the buttons.
	static ListRadioGrid * Create(aui_Window * window, ctp2_ListBox * list, char const * block);
	~ListRadioGrid();

	// One radio per list item, column by column. Marks the selected item,
	// or else the item with the user data wanted, without running the
	// select callback; takes over the enabled state of the items.
	void Rebuild(sint32 wanted = -1);

	void Press(aui_Control * control);

private:
	ListRadioGrid(aui_Window * window, ctp2_ListBox * list, char const * block, aui_SwitchGroup * group);
	void Clear();

	aui_Window *             m_window;
	ctp2_ListBox *           m_list;
	std::string              m_block;
	aui_SwitchGroup *        m_group;
	std::vector<aui_Radio *> m_radios;      // index = list index, NULL when not created
	bool                     m_building;
};

#endif
