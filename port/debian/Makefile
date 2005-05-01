#
# $Id: Makefile,v 1.1 2005/04/11 22:44:02 eserte Exp eserte $
#

BUILDDIR=	/tmp/bbbike-debian
BUILDBBBIKEROOT=$(BUILDDIR)/usr/local/BBBike
BBBIKEROOT=	../..

all:	debian-package

debian-package: debian-prepare \
		$(BUILDDIR)/DEBIAN/control \
		debian-copy-files \
		debian-compile \
		debian-symlinks \
		debian-build

debian-prepare:
	mkdir -p $(BUILDDIR)/DEBIAN
	chmod 755 $(BUILDDIR)
	chmod 755 $(BUILDDIR)/DEBIAN

$(BUILDDIR)/DEBIAN/control:  $(BBBIKEROOT)/BBBikeVar.tpl \
			     control.tpl
	tpage --debug=undef --eval_perl control.tpl > $(BUILDDIR)/DEBIAN/control

debian-copy-files:
	mkdir -p $(BUILDBBBIKEROOT)
	chmod 755 $(BUILDBBBIKEROOT)
	cd $(BBBIKEROOT) && umask 022 && perl -MExtUtils::Manifest=manicopy,maniread -e '$$fs=maniread(q{MANIFEST}); manicopy($$fs,q{$(BUILDDIR)/usr/local/BBBike}, q{cp})'

debian-compile:
	cd $(BBBIKEROOT)/ext && umask 022 && make ext && make clean

debian-symlinks:
	mkdir -p $(BUILDDIR)/usr/bin
	rm -f $(BUILDDIR)/usr/bin/bbbike
	ln -s ../local/BBBike/bbbike $(BUILDDIR)/usr/bin/bbbike

debian-build:
	dpkg -b $(BUILDDIR)
