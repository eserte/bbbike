#
# $Id: Makefile,v 2.7 2009/02/22 14:11:23 eserte Exp $
#

# XXX
# Note that this does not work anymore for modern systems:
# * -fwritable-support does not exist anymore in new gcc's, it seems
# * probably completely broken for 64bit systems
# Anyway this is of mainly historical interest.

EXE=
.if defined(PALM)
CC=		/usr/local/pilot/bin/m68k-palmos-coff-gcc
.endif
.if defined(W32)
CC=		gcc
EXE=		.exe
.endif
CFLAGS=		-g -I.

DATAOUT=	data/strassen.bin data/netz.bin
DATASRC=	data/strassen.c data/netz.c
DATAOBJ=	strassen.o netz.o

OBJS=		minibbbike.o route.o
.if defined(W32)
OBJS+=		conv.o
.endif

DATA_IN_PROG=1

ALLTARGETS=	minibbbike${EXE}

.if defined(DATA_IN_PROG)
CFLAGS+=	-DDATA_IN_PROG
OBJS+=		${DATAOBJ}
.else
ALLTARGETS+=	${DATAOUT}
.endif

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
.if defined(PALM)
	${MKDATA} -palm
.else
	${MKDATA}
.endif

${DATASRC}:	../data/strassen
	${MKDATA} -output c

Makefile.w32:	Makefile
	../miscsrc/b2dmake < Makefile > Makefile.w32
	chmod ugo+r Makefile.w32

GNUmakefile:	Makefile
	../miscsrc/b2gmake < Makefile > GNUmakefile
	chmod ugo+r GNUmakefile
