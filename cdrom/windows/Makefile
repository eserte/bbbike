#
# $Id: Makefile,v 1.5 2005/04/08 22:27:38 eserte Exp $
#

all: setup.exe

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
	cp bbbike.iss /tmp/BBBike-3.14-DEVEL-Windows
	chmod ugo+r /tmp/BBBike-3.14-DEVEL-Windows/bbbike.iss
	chmod ugo+w /tmp/BBBike-3.14-DEVEL-Windows
	@echo Now start the Inno Setup Compiler with the bbbike.iss file on T:
