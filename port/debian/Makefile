#
# $Id: Makefile,v 1.1 2005/04/11 22:44:02 eserte Exp $
#

BUILDDIR=/tmp/bbbike-debian

all:	debian-package

debian-package: debian-prepare \
		$(BUILDDIR)/DEBIAN/control \
		debian-copy-files \
		debian-build

debian-prepare:
	mkdir -p $(BUILDDIR)/DEBIAN
	chmod 755 $(BUILDDIR)
	chmod 755 $(BUILDDIR)/DEBIAN

$(BUILDDIR)/DEBIAN/control:  ../../BBBikeVar.tpl \
			     control.tpl
	tpage --debug=undef --eval_perl control.tpl > $(BUILDDIR)/DEBIAN/control

debian-copy-files:
	mkdir -p $(BUILDDIR)/usr/local/BBBike
	chmod 755 $(BUILDDIR)/usr/local/BBBike
	cp -Rpv /usr/local/BBBike/ $(BUILDDIR)/usr/local/BBBike/

debian-build:
	dpkg -b $(BUILDDIR)
