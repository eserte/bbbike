#
# $Id: Makefile,v 1.8 2008/01/24 21:05:07 eserte Exp $
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
	@echo "Note that an existing distribution directory from"
	@echo "a previous run of this Makefile is not removed or"
	@echo "remade. To do so, use"
	@echo
	@echo "    make BBBIKEVER=$(BBBIKEVER) BBBIKEDEVELVER=$(BBBIKEDEVELVER) winbindist-clean"
	@echo

make-BBBikeVar.tpl:
	cd ../.. && $(MAKE) BBBikeVar.tpl

winbindist-clean:
	-cd ../.. && $(MAKE) winbindist-clean

make-winbindist:
	-cd ../.. && $(MAKE) winbindist-copy BBBIKE_WINDOWS_VERSION=$(BBBIKEVER)
# This is useful for testing directly on the /tmp directory
	-mkdir -p /tmp/BBBike-$(BBBIKEVER)-Windows/bbbike/tmp
	chmod 777 /tmp/BBBike-$(BBBIKEVER)-Windows/bbbike/tmp
	-mkdir -p /tmp/BBBike-$(BBBIKEVER)-Windows/bbbike/cache
	chmod 777 /tmp/BBBike-$(BBBIKEVER)-Windows/bbbike/cache

patch-winbindist:
	-@if [ "$(BBBIKEVER)" = "3.16" ] ; then \
	    cp -p patches/3.16/bbbike_0.config /tmp/BBBike-$(BBBIKEVER)-Windows/bbbike/bbbike_0.config; \
	    chmod 644 /tmp/BBBike-$(BBBIKEVER)-Windows/bbbike/bbbike_0.config; \
	fi

bbbike.iss: make-BBBikeVar.tpl make-winbindist patch-winbindist bbbike.tpl.iss
	tpage --debug=undef --define VERSION=$(BBBIKEVER) --eval_perl bbbike.tpl.iss > bbbike.iss

make-windows-installer: bbbike.iss
	cp bbbike.iss /tmp/BBBike-$(BBBIKEVER)-Windows/
	chmod ugo+r /tmp/BBBike-$(BBBIKEVER)-Windows/bbbike.iss
	chmod ugo+w /tmp/BBBike-$(BBBIKEVER)-Windows
	@echo "Now start the Inno Setup Compiler with the bbbike.iss file"
	@echo "on T:\\BBBike-$(BBBIKEVER)-Windows (or Z:\\BBBike-$(BBBIKEVER)-Windows)"

devel:
	$(MAKE) make-windows-installer BBBIKEVER=$(BBBIKEDEVELVER)

strawberry-dist: make-BBBikeVar.tpl
	tpage --debug=undef --define use_strawberry=1 --define VERSION=3.17-DEVEL --eval_perl bbbike.tpl.iss > bbbike.iss
