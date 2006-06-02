.CURDIR?=	${CURDIR}
#
# $Id: Makefile,v 2.6 2003/08/14 05:17:43 eserte Exp $
#

EXE=
ifdef PALM
CC=		/usr/local/pilot/bin/m68k-palmos-coff-gcc
endif
ifdef W32
CC=		gcc
EXE=		.exe
endif
CFLAGS=		-g -I.

DATAOUT=	data/strassen.bin data/netz.bin
DATASRC=	data/strassen.c data/netz.c
DATAOBJ=	strassen.o netz.o

OBJS=		minibbbike.o route.o
ifdef W32
OBJS+=		conv.o
endif

DATA_IN_PROG=1

ALLTARGETS=	minibbbike${EXE}

ifdef DATA_IN_PROG
CFLAGS+=	-DDATA_IN_PROG
OBJS+=		${DATAOBJ}
else
ALLTARGETS+=	${DATAOUT}
endif

MKDATA=		perl ./mkdata.pl

all:	 ${ALLTARGETS} Makefile.w32 GNUmakefile

minibbbike${EXE}:	${OBJS}
	${CC} ${OBJS} -o minibbbike${EXE} -lm

minibbbike.o:	bbbike.h minibbbike.c
	${CC} ${CFLAGS} -c minibbbike.c -o minibbbike.o

route.o:	bbbike.h route.c
	${CC} ${CFLAGS} -c route.c -o route.o

conv.o:	conv.c
	${CC} ${CFLAGS} -c conv.c -o conv.o

strassen.o:	data/strassen.c
	${CC} ${CFLAGS} -fwritable-strings -c data/strassen.c -o strassen.o

netz.o:	data/netz.c
	${CC} ${CFLAGS} -fwritable-strings -c data/netz.c -o netz.o

clean:
	rm -f minibbbike *.o *.core data/strassen.c data/netz.c

${DATAOUT}:	../data/strassen
ifdef PALM
	${MKDATA} -palm
else
	${MKDATA}
endif

${DATASRC}:	../data/strassen
	${MKDATA} -output c

Makefile.w32:	Makefile
	../miscsrc/b2dmake < Makefile > Makefile.w32
	chmod ugo+r Makefile.w32

GNUmakefile:	Makefile
	../miscsrc/b2gmake < Makefile > GNUmakefile
	chmod ugo+r GNUmakefile
