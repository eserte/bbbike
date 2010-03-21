# Run on a Debian system

BUILDDIR=	/tmp/bbbike-debian
BBBIKETARGETDIR=/usr/lib/BBBike
BUILDBBBIKEROOT=$(BUILDDIR)$(BBBIKETARGETDIR)
BBBIKEROOT=	$(shell pwd)/../..
BBBIKE_STABLE_VERSION=$(shell perl -I$(BBBIKEROOT) -MBBBikeVar -e 'print $$BBBike::STABLE_VERSION')
BBBIKE_DEBIAN_REVISION?=	1
MANPAGE=	/usr/share/man/man1/bbbike.1
BBBIKEDOCDIR=	/usr/share/doc/bbbike
PACKAGEDIR=	$(BBBIKEROOT)/distfiles
SKIPCOMPILE?=

all:	debian-package

debian-package: debian-prepare \
		debian-control \
		debian-copy-files \
		debian-compile \
		debian-man \
		debian-copyright \
		debian-menu \
		debian-symlinks \
		debian-build

debian-prepare:
	umask 022; mkdir $(BUILDDIR)
	umask 022; mkdir $(BUILDDIR)/DEBIAN
	chmod 755 $(BUILDDIR)
	chmod 755 $(BUILDDIR)/DEBIAN
	umask 022; ln -s $(BUILDDIR) bbbike

debian-control: $(BUILDDIR)/DEBIAN/control

$(BUILDDIR)/DEBIAN/control:  bbbike-var-tpl \
			     control.tpl
	umask 022; tpage --debug=undef --eval_perl --define BBBIKE_DEBIAN_REVISION=$(BBBIKE_DEBIAN_REVISION) control.tpl > $(BUILDDIR)/DEBIAN/control || rm -f $@
	umask 022; cp -f $(BUILDDIR)/DEBIAN/control control

.PHONY: bbbike-var-tpl
bbbike-var-tpl:
	cd $(BBBIKEROOT) && $(MAKE) BBBikeVar.tpl

debian-copy-files:
	umask 022; mkdir -p $(BUILDBBBIKEROOT)
	chmod 755 $(BUILDBBBIKEROOT)
	umask 022; cd $(BUILDBBBIKEROOT)/.. && tar xfvzp $(BBBIKEROOT)/distfiles/BBBike-$(BBBIKE_STABLE_VERSION).tar.gz
	rmdir $(BUILDBBBIKEROOT)
	umask 022; cd `dirname $(BUILDBBBIKEROOT)` && mv BBBike-$(BBBIKE_STABLE_VERSION) BBBike

debian-compile:
ifndef SKIPCOMPILE
	cd $(BUILDBBBIKEROOT)/ext && umask 022 && make ext && make clean
endif

debian-man:
	umask 022; mkdir -p `dirname $(BUILDDIR)$(MANPAGE)`
	umask 022; pod2man $(BBBIKEROOT)/bbbike.pod > $(BUILDDIR)$(MANPAGE)

debian-copyright:
	umask 022; mkdir -p $(BUILDDIR)$(BBBIKEDOCDIR)
	umask 022; perl > $(BUILDDIR)$(BBBIKEDOCDIR)/copyright -e \
	'print qq{Copyright (c) 1995-2010 Slaven Rezic. All rights reserved.\nThis is free software; you can redistribute it and/or modify it under the\nterms of the GNU General Public License, see the file\n/usr/share/common-licenses/GPL\n}'
	umask 022; piconv -f iso-8859-1 -t utf-8 < $(BUILDBBBIKEROOT)/CHANGES | gzip -9f > $(BUILDDIR)$(BBBIKEDOCDIR)/changelog.gz
	umask 022; gzip -9f < changelog.Debian > $(BUILDDIR)$(BBBIKEDOCDIR)/changelog.Debian.gz

debian-symlinks:
	umask 022; mkdir -p $(BUILDDIR)/usr/bin
	umask 022; ln -sf ../lib/BBBike/bbbike $(BUILDDIR)/usr/bin/bbbike
	umask 022; mkdir -p $(BUILDDIR)$(BBBIKEDOCDIR)
	umask 022; for i in README README.english; do \
	    echo "Symlink $(BBBIKETARGETDIR)/$$i ..."; \
	    ln -sf ../../../lib/BBBike/$$i $(BUILDDIR)$(BBBIKEDOCDIR)/$$i; \
	done
	umask 022; for i in README.english.html README.html bbbike.html bbbike_internals.html bbd.html podindex.html; do \
	    echo "Symlink $(BBBIKETARGETDIR)/$$i ..."; \
	    ln -sf ../../../lib/BBBike/doc/$$i $(BUILDDIR)$(BBBIKEDOCDIR)/$$i; \
	done

debian-menu:
	cd .. && umask 022 && dh_installmenu

debian-build:
	cd .. && umask 022 && dh_compress
	cd .. && umask 022 && sudo dh_fixperms
	find $(BUILDDIR) | xargs chmod ugo+r
	find $(BUILDDIR) -perm -u=x | xargs chmod go+x
	find $(BUILDDIR) | sudo xargs chown root:root
	cd .. && umask 022 && sudo dh_installdeb
	cd .. && umask 022 && sudo dh_md5sums
	cd .. && umask 022 && dh_builddeb --destdir $(PACKAGEDIR)

debian-clean:
	sudo rm -rf $(BUILDDIR)
	cd .. && dh_clean
	rm -f control
	rm -f bbbike
