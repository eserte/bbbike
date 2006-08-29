#
# $Id: Makefile,v 1.4 2006/08/29 21:45:07 eserte Exp $
#

BBBIKEVER!=		perl -I../.. -MBBBikeVar -e 'print $$BBBike::WINDOWS_VERSION'
BBBIKEDEVELVER!=	perl -I../.. -MBBBikeVar -e 'print $$BBBike::VERSION'

#all: setup.exe
all: make-windows-installer

make-BBBikeVar.tpl:
	cd ../.. && $(MAKE) BBBikeVar.tpl

make-winbindist:
	-cd ../.. && $(MAKE) winbindist-copy
# This is useful for testing directly on the /tmp directory
	chmod 777 /tmp/BBBike-$(BBBIKEVER)-Windows/bbbike/tmp
	chmod 777 /tmp/BBBike-$(BBBIKEVER)-Windows/bbbike/cache

bbbike.iss: make-BBBikeVar.tpl make-winbindist bbbike.tpl.iss
	tpage --debug=undef --define VERSION=$(BBBIKEVER) --eval_perl bbbike.tpl.iss > bbbike.iss

make-windows-installer: bbbike.iss
	cp bbbike.iss /tmp/BBBike-$(BBBIKEVER)-Windows/
	chmod ugo+r /tmp/BBBike-$(BBBIKEVER)-Windows/bbbike.iss
	chmod ugo+w /tmp/BBBike-$(BBBIKEVER)-Windows
	@echo "Now start the Inno Setup Compiler with the bbbike.iss file on T: (or Z:)"

devel:
	$(MAKE) make-windows-installer BBBIKEVER=$(BBBIKEDEVELVER)

