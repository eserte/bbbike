#
# $Id: Makefile,v 1.17 2004/11/27 12:09:03 eserte Exp $
#

BBBIKEDIR?=		..
MISCSRCDIR?=		${BBBIKEDIR}/miscsrc
DATADIR?=		${BBBIKEDIR}/data
CONVERT2HAFAS=		${MISCSRCDIR}/convert2hafas
CHECK_POINTS=		${MISCSRCDIR}/check_points
GREPSTRASSEN=		${MISCSRCDIR}/grepstrassen

TARGETS=	ampelschaltung.txt

# XXX sp of writable/writeable?
WRITEABLE=	chmod u+w,ugo+r
READONLY=	chmod ugo+r,ugo-w

all:	check targets

targets:	${TARGETS}

ampelschaltung.txt:	ampelschaltung-orig.txt
	-@$(WRITEABLE) $@
	${CONVERT2HAFAS} -keepcomment -ampelschaltung2 \
		ampelschaltung-orig.txt > ampelschaltung.txt
	-@$(READONLY) $@

# checks
check:	.check_ampelschaltung2

.check_ampelschaltung2:	ampelschaltung-orig.txt ${DATADIR}/ampeln-orig
	$(CHECK_POINTS) -ampelschaltung2 -warn \
		ampelschaltung-orig.txt ${DATADIR}/ampeln-orig
	@touch .check_ampelschaltung2

tkbabybike-screenshot:
	cd screenshots && $(MAKE) tkbabybike-screenshot
