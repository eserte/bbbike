#
# $Id: Makefile,v 1.82 2003/07/09 21:26:23 eserte Exp eserte $
#

MISCDIR=		../misc
MISCSRCDIR=		../miscsrc

BERLINMAP2HAFAS=	${MISCSRCDIR}/berlinmap2hafas -strict
HAFAS2HAFAS=		${MISCSRCDIR}/hafas2hafas -strict
CONVERT2HAFAS=		${MISCSRCDIR}/convert2hafas -strict
CHECK_POINTS=		${MISCSRCDIR}/check_points
CHECK_STR_PLZ=		${MISCSRCDIR}/check_str_plz
CHECK_CONT=		${MISCSRCDIR}/check_cont
CHECK_DOUBLE=           ${MISCSRCDIR}/check_double
CHECK_NEIGHBOUR=	${MISCSRCDIR}/check_neighbour
CHECK_COUNT=		${MISCSRCDIR}/check_count
CHECK_HOUSENUMBERS=	${MISCSRCDIR}/check_housenumbers
CHECK_IMAGES=		${MISCSRCDIR}/check_images
RESOLVE_STARS=		${MISCSRCDIR}/resolve_stars
SORTBYCAT=		${MISCSRCDIR}/sortbycat
SEARCH_INACCESSIBLE=	${MISCSRCDIR}/search_inaccessible_points

TARGETS=	strassen plaetze landstrassen landstrassen2 flaechen
TARGETS+=	wasserstrassen wasserumland wasserumland2
TARGETS+=	sbahn sbahnhof sbahnhof_bg rbahn rbahnhof
TARGETS+=	ubahn ubahnhof ubahnhof_bg
TARGETS+=	faehren hoehe orte orte2 orte_city ampeln ampelschaltung
TARGETS+=	gesperrt gesperrt_car plz berlin potsdam deutschland
TARGETS+=	sehenswuerdigkeit obst radwege radwege_exact
TARGETS+=	qualitaet_s qualitaet_l
TARGETS+=	handicap_s handicap_l
TARGETS+=	label vorfahrt comments relation_gps nolighting
TARGETS+=	housenumbers green brunnels

WRITEABLE=	chmod u+w,ugo+r
READONLY=	chmod ugo+r,ugo-w

all:	targets check .modified .rsync_include make_misc

targets:	${TARGETS}

# Useful checks, but normally too slow for a quick build
slow-checks:	inaccessible_strassen check-line-lengths check-dates
	env LC_ALL=de_DE.ISO_8859-1 sort -c Berlin.coords.data || \
	    ( env LC_ALL=de_DE.ISO_8859-1 sort Berlin.coords.data | diff -u - Berlin.coords.data; false )

# even slower (about four minutes)
really-slow-checks:	check-crossings

# XXX do also landstrassen (at least Potsdam):
inaccessible_strassen: strassen gesperrt
	-@$(WRITEABLE) $@
	${SEARCH_INACCESSIBLE} -street strassen -blocked gesperrt \
	    -blockedtype einbahn -blockedtype sperre \
	    > inaccessible_strassen~ && mv inaccessible_strassen~ inaccessible_strassen
	-@$(READONLY) $@

strassen:	.strassen.tmp plaetze
	-@$(WRITEABLE) $@
	cat $> > $@
	-@$(READONLY) $@

.strassen.tmp: strassen-orig
	$(CONVERT2HAFAS) strassen-orig > .strassen.tmp

plaetze: plaetze-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) plaetze-orig > plaetze
	-@$(READONLY) $@

# XXX sortbycat sollte die Inseln von der Sortierung ausschließen ---
# sie sollten weiterhin an den zugehörigen Gewässsern "kleben"
wasserstrassen: wasserstrassen-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) wasserstrassen-orig | $(SORTBYCAT) > wasserstrassen
	-@$(READONLY) $@

wasserumland: wasserumland-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) wasserumland-orig | $(SORTBYCAT) > wasserumland
	-@$(READONLY) $@

wasserumland2: wasserumland2-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) wasserumland2-orig | $(SORTBYCAT) > wasserumland2
	-@$(READONLY) $@

flaechen: flaechen-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) flaechen-orig > flaechen
	-@$(READONLY) $@

green:	green-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) $> > $@
	-@$(READONLY) $@

brunnels:	brunnels-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) $> > $@
	-@$(READONLY) $@

landstrassen: landstrassen-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) landstrassen-orig > landstrassen
	-@$(READONLY) $@

landstrassen2: landstrassen2-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) landstrassen2-orig > landstrassen2
	-@$(READONLY) $@

sbahn:	sbahn-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) sbahn-orig > sbahn
	-@$(READONLY) $@

sbahnhof:	sbahnhof-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) sbahnhof-orig > sbahnhof
	-@$(READONLY) $@

sbahnhof_bg:	sbahnhof_bg-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) $> > $@
	-@$(READONLY) $@

rbahn rbahnhof:	rbahn-orig
	-@$(WRITEABLE) rbahn rbahnhof
	$(CONVERT2HAFAS) -bahnhof=rbahnhof rbahn-orig > rbahn
	-@$(READONLY) rbahn rbahnhof

ubahn: ubahn-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) ubahn-orig > ubahn
	-@$(READONLY) $@

ubahnhof:	ubahnhof-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) ubahnhof-orig > ubahnhof
	-@$(READONLY) $@

ubahnhof_bg:	ubahnhof_bg-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) $> > $@
	-@$(READONLY) $@

faehren: faehren-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) faehren-orig > faehren
	-@$(READONLY) $@

hoehe: hoehe-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) hoehe-orig > hoehe
	-@$(READONLY) $@

orte: orte-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) orte-orig | $(SORTBYCAT) > orte
	-@$(READONLY) $@

orte2: orte2-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) orte2-orig | $(SORTBYCAT) > orte2
	-@$(READONLY) $@

orte_city: orte_city-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) orte_city-orig | $(SORTBYCAT) > orte_city
	-@$(READONLY) $@

ampeln:	ampeln-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) ampeln-orig > ampeln
	-@$(READONLY) $@

ampelschaltung:	ampelschaltung-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) -ampelschaltung ampelschaltung-orig > ampelschaltung
	-@$(READONLY) $@

gesperrt:	gesperrt-orig strassen landstrassen
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) -specsperre=strassen,landstrassen gesperrt-orig > gesperrt
	-@$(READONLY) $@

gesperrt_car:	gesperrt_car-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) gesperrt_car-orig > gesperrt_car
	-@$(READONLY) $@

plz berlin:	plz-orig
	-@$(WRITEABLE) plz berlin
	$(CONVERT2HAFAS) -specborder=berlin plz-orig > plz
	-@$(READONLY) plz berlin

potsdam:	potsdam-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) potsdam-orig > potsdam
	-@$(READONLY) $@

deutschland:	deutschland-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) deutschland-orig > deutschland
	-@$(READONLY) $@

sehenswuerdigkeit:	sehenswuerdigkeit-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) sehenswuerdigkeit-orig > sehenswuerdigkeit
	-@$(READONLY) $@

obst:	obst-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) obst-orig > obst
	-@$(READONLY) $@

radwege:	radwege-orig
	-@$(WRITEABLE) $@
	${MISCSRCDIR}/convert_radwege < radwege-orig > radwege
	-@$(READONLY) $@

radwege_exact:	radwege-orig
	-@$(WRITEABLE) $@
	${MISCSRCDIR}/convert_radwege -exact < radwege-orig > radwege_exact
	-@$(READONLY) $@

qualitaet_s:	qualitaet_s-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) qualitaet_s-orig > qualitaet_s
	-@$(READONLY) $@

qualitaet_l:	qualitaet_l-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) qualitaet_l-orig > qualitaet_l
	-@$(READONLY) $@

handicap_s:	handicap_s-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) handicap_s-orig > handicap_s
	-@$(READONLY) $@

handicap_l:	handicap_l-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) handicap_l-orig > handicap_l
	-@$(READONLY) $@

label:	label-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) label-orig > label
	-@$(READONLY) $@

vorfahrt:	vorfahrt-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) vorfahrt-orig > vorfahrt
	-@$(READONLY) $@

# really should check against strassen etc. too
comments:	comments_cyclepath-orig \
		comments_ferry-orig \
		comments_misc-orig \
		comments_mount-orig \
		comments_path-orig \
		comments_route-orig \
		comments_tram-orig
	-@$(WRITEABLE) $@
	cat $> | $(CONVERT2HAFAS) -map B - | \
	    $(RESOLVE_STARS) strassen landstrassen landstrassen2 - > $@
	-@$(READONLY) $@

relation_gps:	relation_gps-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) relation_gps-orig > relation_gps
	-@$(READONLY) $@

nolighting:	nolighting-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) nolighting-orig > nolighting
	-@$(READONLY) $@

housenumbers:	housenumbers-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) housenumbers-orig > housenumbers
	-@$(READONLY) $@

# Makefile in ../misc ausführen
# drat ... ich möchte nicht gmake verwenden :-(
make_misc:
	cd $(MISCDIR) && ${MAKE} #${MAKEFLAGS} 

# create Storable versions of data files
# handling of Storable files is slower, so it is not done by default
storable:
	for i in $(TARGETS); do \
	    perl -I.. -I../lib ../Strassen/Storable.pm -v -u -f $$i $$i.st; \
	done

force_check: remove_checks check

remove_checks:
	rm -f .check_*

# checks
check:	.check_strassen1 .check_strassen2 \
	.check_plaetze1 .check_plaetze2 .check_hoehe \
	.check_ampeln .check_gesperrt1 .check_gesperrt2 \
	.check_gesperrt_car1 .check_gesperrt_car2 \
	.check_ubahnhof .check_sbahnhof .check_orte \
	.check_radwege .check_ampelschaltung \
	.check_qualitaet_s .check_qualitaet_l \
	.check_handicap_s .check_handicap_l \
	.check_label .check_vorfahrt \
	.check_comments1 .check_comments2 .check_nolighting \
	.check_housenumbers .check_sehenswuerdigkeit .check_green \
	.check_brunnels \

.check_strassen1:	.strassen.tmp add_str multi_bez_str
	$(CHECK_STR_PLZ) -data .strassen.tmp
	@touch .check_strassen1

.check_strassen2:	.strassen.tmp str_cont_ausnahme
	$(CHECK_CONT) -data .strassen.tmp
	@touch .check_strassen2

.check_plaetze1: plaetze .strassen.tmp
	$(CHECK_POINTS) plaetze .strassen.tmp
	@touch .check_plaetze1

.check_plaetze2: plaetze add_plaetze
	$(CHECK_STR_PLZ) -addstr add_plaetze -data plaetze -nomultibez
	@touch .check_plaetze2

.check_hoehe:	hoehe .strassen.tmp landstrassen landstrassen2 
	$(CHECK_POINTS) hoehe .strassen.tmp landstrassen landstrassen2
	@touch .check_hoehe

.check_ampeln:	ampeln .strassen.tmp landstrassen landstrassen2
	$(CHECK_POINTS) ampeln .strassen.tmp landstrassen landstrassen2
	@touch .check_ampeln

.check_ampelschaltung:	ampelschaltung-orig ampeln-orig
	$(CHECK_POINTS) -ampelschaltung ampelschaltung-orig ampeln-orig
	@touch .check_ampelschaltung

.check_gesperrt1:	gesperrt .strassen.tmp landstrassen landstrassen2
	$(CHECK_POINTS) gesperrt .strassen.tmp landstrassen landstrassen2
	@touch .check_gesperrt1

.check_gesperrt2:	gesperrt strassen landstrassen landstrassen2
	$(CHECK_NEIGHBOUR) -type standard -data gesperrt \
		-against strassen -against landstrassen -against landstrassen2
	@touch .check_gesperrt2

.check_gesperrt_car1:	gesperrt_car .strassen.tmp landstrassen landstrassen2
	$(CHECK_POINTS) gesperrt_car .strassen.tmp landstrassen landstrassen2
	@touch .check_gesperrt_car1

.check_gesperrt_car2:	gesperrt_car strassen landstrassen landstrassen2
	$(CHECK_NEIGHBOUR) -type standard -data gesperrt_car \
		-against strassen -against landstrassen -against landstrassen2
	@touch .check_gesperrt_car2

.check_ubahnhof:	ubahnhof ubahn
	$(CHECK_POINTS) ubahnhof ubahn
	@touch .check_ubahnhof

.check_sbahnhof:	sbahnhof sbahn
	$(CHECK_POINTS) sbahnhof sbahn
	@touch .check_sbahnhof

.check_orte: orte orte2 orte_city
	$(CHECK_DOUBLE) orte orte2 orte_city
	@touch .check_orte

.check_radwege:	radwege_exact strassen
	$(CHECK_NEIGHBOUR) -type standard -data radwege_exact
	@touch .check_radwege

.check_qualitaet_s:	qualitaet_s strassen
	$(CHECK_NEIGHBOUR) -type standard -data qualitaet_s
	@touch .check_qualitaet_s

.check_qualitaet_l:	qualitaet_l landstrassen landstrassen2
	$(CHECK_NEIGHBOUR) -type standard -origmap GISmap -data qualitaet_l \
		-against landstrassen -against landstrassen2
	@touch .check_qualitaet_l

.check_handicap_s:	handicap_s strassen
	$(CHECK_NEIGHBOUR) -type standard -data handicap_s
	@touch .check_handicap_s

.check_handicap_l:	handicap_l landstrassen landstrassen2
	$(CHECK_NEIGHBOUR) -type standard -origmap GISmap -data handicap_l \
		-against landstrassen -against landstrassen2
	@touch .check_handicap_l

.check_label:	label .strassen.tmp landstrassen landstrassen2
	$(CHECK_POINTS) label .strassen.tmp landstrassen landstrassen2
	@touch .check_label

.check_vorfahrt:	vorfahrt strassen landstrassen landstrassen2
	$(CHECK_NEIGHBOUR) -type standard -data vorfahrt \
		-against strassen -against landstrassen -against landstrassen2
	$(CHECK_COUNT) -type vorfahrt -data vorfahrt
	@touch .check_vorfahrt

.check_comments1:	comments .strassen.tmp landstrassen landstrassen2 faehren
	$(CHECK_POINTS) comments .strassen.tmp landstrassen landstrassen2 faehren
	@touch .check_comments1

.check_comments2:	comments strassen landstrassen landstrassen2 faehren
	$(CHECK_NEIGHBOUR) -type standard \
		-against strassen -against landstrassen -against landstrassen2 \
		-against faehren -data comments
	@touch .check_comments2

.check_nolighting:	nolighting strassen
	$(CHECK_NEIGHBOUR) -type standard -data nolighting
	@touch .check_nolighting

.check_housenumbers:	housenumbers-orig housenumbers .strassen.tmp
	$(CHECK_HOUSENUMBERS) housenumbers-orig
	$(CHECK_POINTS) housenumbers .strassen.tmp
	@touch .check_housenumbers

.check_sehenswuerdigkeit:	sehenswuerdigkeit
	$(CHECK_IMAGES) sehenswuerdigkeit
	@touch .check_sehenswuerdigkeit

.check_green:	green strassen landstrassen
	$(CHECK_NEIGHBOUR) -type standard -data green \
		-against strassen -against landstrassen
	@touch .check_green

# XXX against landstrassen, too?
.check_brunnels:	brunnels strassen
	$(CHECK_NEIGHBOUR) -type standard -data brunnels
	@touch .check_brunnels

#.PHONY: .modified

# This also creates .rsync_include
.modified:	${TARGETS}
	${MISCSRCDIR}/create_modified

sort-Berlin.coords.data:
	mv Berlin.coords.data Berlin.coords.data~
	env LC_ALL=de_DE.ISO_8859-1 sort < Berlin.coords.data~ > Berlin.coords.data

# For adjusting the buffer in BBBikeXS.xs.
# Please adjust the number according to MAXBUF and MAXPOINTS in BBBikeXS.xs.
check-line-lengths:
	MAXLEN=`for i in $(TARGETS); do \
	    perl -nle '$$max = length($$_) if length($$_) > $$max; END { print $$max }' < $$i; \
	done | sort -nr | head -1`; \
	[ $$MAXLEN -lt 12288 ] || ( echo $$MAXLEN; exit 1 )
	MAXPOINTS=`for i in $(TARGETS); do \
	    perl -nle '$$points = scalar split / /; $$max = $$points if $$points > $$max; END { print $$max }' < $$i; \
	done | sort -nr | head -1`; \
	[ $$MAXPOINTS -lt 1024 ] || ( echo $$MAXPOINTS; exit 1 )

count-streets:
	cut -f1 -d"	" strassen | sort -u | wc -l

check-dates:
	${MISCSRCDIR}/check_dates *-orig

check-crossings:
	${MISCSRCDIR}/check_crossings strassen brunnels

.include "Makefile.mapfiles"
