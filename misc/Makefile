#
# $Id: Makefile,v 1.15 2004/05/16 11:21:05 eserte Exp $
#

BBBIKEDIR?=		..
MISCSRCDIR?=		${BBBIKEDIR}/miscsrc
DATADIR?=		${BBBIKEDIR}/data
CONVERT2HAFAS=		${MISCSRCDIR}/convert2hafas
CHECK_POINTS=		${MISCSRCDIR}/check_points
GREPSTRASSEN=		${MISCSRCDIR}/grepstrassen

TARGETS=	fragezeichen ampelschaltung.txt

# XXX sp of writable/writeable?
WRITEABLE=	chmod u+w,ugo+r
READONLY=	chmod ugo+r,ugo-w

all:	check targets

targets:	${TARGETS}

# ::inwork => will maybe change to :inwork
#XXX in "-orig" transition: handicap_s-orig and gesperrt-orig always need to have the same base map!
fragezeichen:	fragezeichen-orig ${DATADIR}/ampeln-orig \
		/tmp/other-source-fragezeichen Makefile \
		${DATADIR}/handicap_s-orig ${DATADIR}/gesperrt-orig
	-@$(WRITEABLE) $@
	cat fragezeichen-orig | ${GREPSTRASSEN} -v -sectionrx "projektierte Radstreifen" | ${CONVERT2HAFAS} -basefile fragezeichen-orig > fragezeichen
	grep '?' ${DATADIR}/ampeln-orig | \
	    ${CONVERT2HAFAS} -basefile ${DATADIR}/ampeln-orig -- - >> fragezeichen
	${MISCSRCDIR}/temporary_streets.pl \
	    ${DATADIR}/handicap_s-orig ${DATADIR}/gesperrt-orig | \
	    perl -nle '/(.*\t)(\S+)(.*)/ && !/\b(\d{4}-\d{2}-\d{2}|[0123]?\d\.[01]?\d\.\d{4})\b/ && print "Noch immer? $$1?::inwork$$3"' | \
	    ${CONVERT2HAFAS} -basefile ${DATADIR}/handicap_s-orig -- - >> fragezeichen
	cat /tmp/other-source-fragezeichen >> fragezeichen
	-@$(READONLY) $@

# Die mit "laut adfc-karte" u.‰. gekennzeichneten Straﬂen extrahieren und
# nach other-source-fragezeichen schreiben.
# XXX Very strange: with db4 on RedHat 8.0 I have to use O_RDWR instead of
# O_RDONLY, otherwise the oneliner will die without an error message.
# But O_RDWR does not work if the file is read-only, so still use O_RDONLY
/tmp/other-source-fragezeichen:	${DATADIR}/qualitaet_s-orig ${DATADIR}/qualitaet_l-orig
	cd ${DATADIR} && perl -I${BBBIKEDIR} -I${BBBIKEDIR}/lib -MStrassen::Core -MDB_File -e 'for my $$file (qw(qualitaet_s-orig qualitaet_l-orig)) { tie @l, "DB_File", $$file, O_RDONLY, 0, $$DB_RECNO or die qq{Cannot open $$file: $$!}; for my $$i (1 .. $$#l) { if ($$l[$$i-1] =~ /\#:\s+unverified_by\s+(.*?):?\s*$$/i) { my $$comment = "laut $$1"; my $$x = Strassen::parse($$l[$$i]); $$x->[Strassen::NAME()] .= " ($$comment)"; $$x->[Strassen::CAT()] = "?"; print Strassen::arr2line2($$x),"\n" } } }' > /tmp/other-source-fragezeichen-orig
	${CONVERT2HAFAS} -basefile ${DATADIR}/qualitaet_s-orig /tmp/other-source-fragezeichen-orig > /tmp/other-source-fragezeichen

PREFIXMAP=sperr=SP,kopfstein=KP,qualit‰t=QU,m‰ﬂig.geeignet=QU,radweg=RW,bau=BA,vorfahrt=VF

/tmp/upload-fragezeichen.wpt:	fragezeichen
	${MISCSRCDIR}/bbd2gpsman.pl -filter nearby=200 \
	    -prefix XXX -match name \
	    -prefixmap ${PREFIXMAP} \
	    -symbol danger < $> > $@
	@echo gpsman with file $@

/tmp/upload-restricted-fragezeichen.wpt:	fragezeichen
	@if [ "${RESTRICT_BBOX}" = "" ]; then \
	    echo Please define RESTRICT_BBOX in make line; \
	    false; \
	else \
	    true; \
	fi
	${MISCSRCDIR}/restrict_bbd_data.pl -bbox ${RESTRICT_BBOX} -strdata $> -o - | ${MISCSRCDIR}/bbd2gpsman.pl -filter nearby=200 \
	    -prefix XXX -match name \
	    -prefixmap ${PREFIXMAP} \
	    -symbol danger > $@
	@echo gpsman with file $@

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
