//	vbbbikecmdw.h:	Header for vbbbikecmdw class
//=======================================================================

#ifndef vbbbikeCMDW_H
#define vbbbikeCMDW_H

#include <v/vcmdwin.h>	// So we can use vCmdWindow
#include <v/vmenu.h>	// For the menu pane
#include <v/vutil.h>	// For V Utilities
#include <v/vcmdpane.h> // command pane
#include <v/vstatusp.h>	// For the status pane

#ifdef vDEBUG
#include <v/vdebug.h>
#endif

#include "vbbbikecnv.h"	// vbbbikeCanvasPane
#include "vbbbikedlg.h"	// vbbbikeDialog

const ItemVal M_Dump = 1;

    class vbbbikeCmdWindow : public vCmdWindow
      {
	friend int AppMain(int, char**);	// allow AppMain access

      public:		//---------------------------------------- public
	vbbbikeCmdWindow(char*, int, int);
	virtual ~vbbbikeCmdWindow();
	virtual void WindowCommand(ItemVal id, ItemVal val, CmdType cType);
	virtual void KeyIn(vKey keysym, unsigned int shift);

      protected:	//--------------------------------------- protected

      private:		//--------------------------------------- private

	// Standard elements
	vMenuPane* vbbbikeMenu;		// For the menu bar
	vbbbikeCanvasPane* vbbbikeCanvas;		// For the canvas
	vCommandPane* vbbbikeCmdPane;	// for the command pane
	vStatusPane* vbbbikeStatus;		// For the status bar

	// Dialogs associated with CmdWindow

	vbbbikeDialog* vbbbikeDlg;

      };
#endif
