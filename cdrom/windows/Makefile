#
# $Id: Makefile,v 1.9 2005/06/04 10:08:23 eserte Exp $
#

BBBIKEVER!=	perl -I../.. -MBBBikeVar -e 'print $$BBBike::VERSION'

#all: setup.exe
all: make-windows-installer

# add -DACTIVEPERL if building for ActiveState Perl
setup.exe: setup.c
	gcc setup.c -static -o setup.exe
	strip setup.exe

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
