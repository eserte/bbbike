#
# $Id: Makefile,v 1.3 2005/12/17 00:34:39 eserte Exp $
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
