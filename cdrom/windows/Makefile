#
# $Id: Makefile,v 1.10 2005/12/14 19:35:42 eserte Exp $
#

all: setup.exe

# add -DACTIVEPERL if building for ActiveState Perl
setup.exe: setup.c
	gcc setup.c -static -o setup.exe
	strip setup.exe

