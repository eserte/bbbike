//	vbbbikedlg.h:	Header for vbbbikeDialog class
//=======================================================================

#ifndef vbbbikeDIALOG_H
#define vbbbikeDIALOG_H
#include <v/vdialog.h>

    class vbbbikeCmdWindow;

    class vbbbikeDialog : public vDialog
      {
      public:		//---------------------------------------- public
	vbbbikeDialog(vBaseWindow* bw, char* title = "vBBBike");
	virtual ~vbbbikeDialog();		// Destructor
	virtual void DialogCommand(ItemVal,ItemVal,CmdType); // action selected
	void AddDefaultCmds();		// to add the defined commands

      protected:	//--------------------------------------- protected

      private:		//--------------------------------------- private

	vbbbikeCmdWindow* _myCmdWin;
      };
#endif
