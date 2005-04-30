#
# $Id: Makefile,v 1.8 2005/04/30 09:26:37 eserte Exp $
#

# XXX Get from BBBikeVar
BBBIKEVER=3.14

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
