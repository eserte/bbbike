//	vbbbikeapp.h:	Header for vbbbikeApp class
//=======================================================================

#ifndef vbbbikeAPP_H
#define vbbbikeAPP_H

// Include standard V files as needed

#ifdef vDEBUG
#include <v/vdebug.h>
#endif

#include <v/vapp.h>
#include <v/vawinfo.h>

#include "vbbbikecmdw.h"	// we use vbbbikeCommandWindow

#include "strassen.h"
#include "memstrassen.h"
#include "bbbike.h"

    class vbbbikeApp : public vApp
      {
	friend int AppMain(int, char**);	// allow AppMain access

      public:		//---------------------------------------- public

	vbbbikeApp(char* name, int sdi = 0, int h = 0, int w = 0);
	virtual ~vbbbikeApp();

	// Routines from vApp that are normally overridden

	virtual vWindow* NewAppWin(vWindow* win, char* name, int w, int h,
		vAppWinInfo* winInfo);

	virtual void Exit(void);

#if V_VersMajor == 1 && V_VersMinor <= 19
	virtual void CloseAppWin(vWindow* win);
#else
	virtual int CloseAppWin(vWindow*);
#endif

	virtual void AppCommand(vWindow* win, ItemVal id, ItemVal val, CmdType cType);

	virtual void KeyIn(vWindow*, vKey, unsigned int);

	// New routines for this particular app

	Strassen **str;
	int strCount;

	struct route **route;
	int routeSlot;

	bool waitForGoal; // waitForStart
	koordptr_t startPtr;

      protected:	//--------------------------------------- protected

      private:		//--------------------------------------- private

	vbbbikeCmdWindow* _vbbbikeCmdWin;		// Pointer to instance of first window

      };
#endif
