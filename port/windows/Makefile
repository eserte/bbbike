#
# $Id: Makefile,v 1.6 2007/07/28 21:05:20 eserte Exp eserte $
#

BBBIKEVER!=		perl -I../.. -MBBBikeVar -e 'print $$BBBike::WINDOWS_VERSION'
BBBIKEDEVELVER!=	perl -I../.. -MBBBikeVar -e 'print $$BBBike::VERSION'

#all: setup.exe
all: show-instructions make-windows-installer

show-instructions:
	-@if [ "$(BBBIKEVER)" != $(BBBIKEDEVELVER) ] ; then \
	    echo "The version is set to the current official BBBike version" ; \
	    echo "You can force the installer to use the new version by calling"; \
	    echo "the makefile with"; \
	    echo; \
	    echo "    make BBBIKEVER=$(BBBIKEDEVELVER)"; \
	    echo; \
	fi

make-BBBikeVar.tpl:
	cd ../.. && $(MAKE) BBBikeVar.tpl

make-winbindist:
	-cd ../.. && $(MAKE) winbindist-copy
# This is useful for testing directly on the /tmp directory
	-mkdir -p /tmp/BBBike-$(BBBIKEVER)-Windows/bbbike/tmp
	chmod 777 /tmp/BBBike-$(BBBIKEVER)-Windows/bbbike/tmp
	-mkdir -p /tmp/BBBike-$(BBBIKEVER)-Windows/bbbike/cache
	chmod 777 /tmp/BBBike-$(BBBIKEVER)-Windows/bbbike/cache

bbbike.iss: make-BBBikeVar.tpl make-winbindist bbbike.tpl.iss
	tpage --debug=undef --define VERSION=$(BBBIKEVER) --eval_perl bbbike.tpl.iss > bbbike.iss

make-windows-installer: bbbike.iss
	cp bbbike.iss /tmp/BBBike-$(BBBIKEVER)-Windows/
	chmod ugo+r /tmp/BBBike-$(BBBIKEVER)-Windows/bbbike.iss
	chmod ugo+w /tmp/BBBike-$(BBBIKEVER)-Windows
	@echo "Now start the Inno Setup Compiler with the bbbike.iss file"
	@echo "on T:\\BBBike-$(BBBIKEVER)-Windows (or Z:\\BBBike-$(BBBIKEVER)-Windows)"

devel:
	$(MAKE) make-windows-installer BBBIKEVER=$(BBBIKEDEVELVER)

