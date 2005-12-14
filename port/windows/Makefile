#
# $Id: Makefile,v 1.2 2005/12/14 19:35:24 eserte Exp eserte $
#

BBBIKEVER!=	perl -I../.. -MBBBikeVar -e 'print $$BBBike::WINDOWS_VERSION'

#all: setup.exe
all: make-windows-installer

make-BBBikeVar.tpl:
	cd ../.. && $(MAKE) BBBikeVar.tpl

make-winbindist:
	-cd ../.. && $(MAKE) winbindist-copy

bbbike.iss: make-BBBikeVar.tpl make-winbindist bbbike.tpl.iss
	tpage --debug=undef --eval_perl bbbike.tpl.iss > bbbike.iss

make-windows-installer: bbbike.iss
	cp bbbike.iss /tmp/BBBike-$(BBBIKEVER)-Windows/
	chmod ugo+r /tmp/BBBike-$(BBBIKEVER)-Windows/bbbike.iss
	chmod ugo+w /tmp/BBBike-$(BBBIKEVER)-Windows
	@echo Now start the Inno Setup Compiler with the bbbike.iss file on T:
