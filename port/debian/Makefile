#
# $Id: Makefile,v 1.3 2005/11/19 00:44:59 eserte Exp $
#

BUILDDIR=	/tmp/bbbike-debian
BBBIKETARGETDIR=/usr/lib/BBBike
BUILDBBBIKEROOT=$(BUILDDIR)$(BBBIKETARGETDIR)
BBBIKEROOT=	$(shell pwd)/../..
BBBIKE_STABLE_VERSION=$(shell perl -I$(BBBIKEROOT) -MBBBikeVar -e 'print $$BBBike::STABLE_VERSION')
MANPAGE=	/usr/local/man/man1/bbbike.1

all:	debian-package

debian-package: debian-prepare \
		$(BUILDDIR)/DEBIAN/control \
		debian-copy-files \
		debian-compile \
		debian-man \
		debian-copyright \
		debian-symlinks \
		debian-build

debian-prepare:
	umask 022
	mkdir $(BUILDDIR)
	mkdir $(BUILDDIR)/DEBIAN
	chmod 755 $(BUILDDIR)
	chmod 755 $(BUILDDIR)/DEBIAN

$(BUILDDIR)/DEBIAN/control:  $(BBBIKEROOT)/BBBikeVar.tpl \
			     control.tpl
	umask 022
	tpage --debug=undef --eval_perl control.tpl > $(BUILDDIR)/DEBIAN/control || rm -f $@

debian-copy-files:
	umask 022
	mkdir -p $(BUILDBBBIKEROOT)
	chmod 755 $(BUILDBBBIKEROOT)
	cd $(BUILDBBBIKEROOT)/.. && tar xfvzp $(BBBIKEROOT)/distfiles/BBBike-$(BBBIKE_STABLE_VERSION).tar.gz
	rmdir $(BUILDBBBIKEROOT)
	cd `dirname $(BUILDBBBIKEROOT)` && mv BBBike-$(BBBIKE_STABLE_VERSION) BBBike

# debian-copy-files:
#	umask 022
# 	mkdir -p $(BUILDBBBIKEROOT)
# 	chmod 755 $(BUILDBBBIKEROOT)
# 	cd $(BBBIKEROOT) && umask 022 && perl -MExtUtils::Manifest=manicopy,maniread -e '$$fs=maniread(q{MANIFEST}); manicopy($$fs,q{$(BUILDBBBIKEROOT)}, q{cp})'

debian-compile:
	umask 022
	cd $(BBBIKEROOT)/ext && umask 022 && make ext && make clean

debian-man:
	umask 022
	mkdir -p `dirname $(BUILDBBBIKEROOT)$(MANPAGE)`
	pod2man $(BBBIKEROOT)/bbbike.pod > $(BUILDBBBIKEROOT)$(MANPAGE)

debian-copyright:
	umask 022
	mkdir -p $(BUILDDIR)/usr/share/doc/bbbike
	perl > $(BUILDDIR)/usr/share/doc/bbbike/copyright -e \
	'print qq{Copyright (c) 1995-2005 Slaven Rezic. All rights reserved.\nThis is free software; you can redistribute it and/or modify it under the\nterms of the GNU General Public License, see the file\n/usr/share/common-licenses/GPL\n}'

debian-symlinks:
	umask 022
	mkdir -p $(BUILDDIR)/usr/bin
	rm -f $(BUILDDIR)/usr/bin/bbbike
	ln -s $(BBBIKETARGETDIR)/bbbike $(BUILDDIR)/usr/bin/bbbike

debian-build:
	umask 022
	dpkg -b $(BUILDDIR)

debian-clean:
	rm -rf $(BUILDDIR)
