#
# $Id: Makefile,v 1.18 2006/09/14 21:29:29 eserte Exp $
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

update-from-andreasm:
	rm -rf /tmp/xxx /tmp/data.patch /tmp/datachange.log /tmp/data
	@echo "Please save mail containing patch as /tmp/xxx <RETURN>"
	@read yn
	cd /tmp/ && metamail -w xxx
	mkdir /tmp/data
	cd $(HOME)/src/bbbike/data && cp Berlin.coords.data *-orig /tmp/data
	cd $(HOME)/src/bbbike/data && rsync -av temp_blockings/ /tmp/data/temp_blockings/
	cd /tmp/data/ && patch -p1 < ../data.patch
	cd /tmp/data/ && tkincorporate . $(HOME)/src/bbbike/data
	$(HOME)/src/bbbike/miscsrc/datachangelog2bbd /tmp/datachange.log > /tmp/d.bbd
	@echo "Please merge/append datachange.log manually."
	@echo "Are there any .rej files?"
	cd $(HOME)/src/bbbike/data && make check all

