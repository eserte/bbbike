#
# $Id: Makefile,v 2.9 2004/05/02 21:08:12 eserte Exp $
#

BBBIKEDIR=		..
MISCDIR=		$(BBBIKEDIR)/misc
MISCSRCDIR=		$(BBBIKEDIR)/miscsrc

#XXX del:
#BERLINMAP2HAFAS=	${MISCSRCDIR}/berlinmap2hafas -strict
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
STEIGUNG_STAT=		${MISCSRCDIR}/steigung_stat

COMMENTS_PARTIAL=	comments_cyclepath comments_ferry comments_misc \
			comments_mount comments_path comments_route \
			comments_tram comments_kfzverkehr

TARGETS=	strassen plaetze landstrassen landstrassen2 flaechen
TARGETS+=	wasserstrassen wasserumland wasserumland2
TARGETS+=	sbahn sbahnhof sbahnhof_bg rbahn rbahnhof
TARGETS+=	ubahn ubahnhof ubahnhof_bg
TARGETS+=	faehren hoehe orte orte2 orte_city ampeln ampelschaltung
TARGETS+=	gesperrt gesperrt_car
.for i in u s r
TARGETS+=	gesperrt_$(i)
.endfor
TARGETS+=	plz berlin potsdam deutschland
TARGETS+=	sehenswuerdigkeit obst radwege radwege_exact
TARGETS+=	qualitaet_s qualitaet_l
TARGETS+=	handicap_s handicap_l
TARGETS+=	label vorfahrt relation_gps nolighting
TARGETS+=	housenumbers green brunnels mount
TARGETS+=	${COMMENTS_PARTIAL}

WRITEABLE=	chmod u+w,ugo+r
READONLY=	chmod ugo+r,ugo-w

all:	targets check .modified .rsync_include make_misc

targets:	${TARGETS}

# Useful checks, but normally too slow for a quick build
# XXX merge with sort-Berlin.coords.data rule below?
slow-checks:	inaccessible_strassen check-line-lengths check-dates check-Berlin.coords.data

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

#XXX vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# radwege werden leicht anders konvertiert (approx. 1m Abweichung), aber
# noch tolerierbar
#
# XXX Hx,y nach x,y umwandeln!
#
# diff sieht zurzeit gut aus, Konvertierung kann erfolgen, wenn Tools
# wie insert_points etc. funktionieren
#
# Call with:
#   make -k origconvert origconvert-all
#
# Quick diff between both directories:
#
# diff --exclude="*~" --exclude="*.st" --exclude="*-info" --exclude="*.desc" --exclude=BASE --exclude=".check*" --exclude=".nextrun*" --exclude=".*" --exclude="*-orig" --exclude "GNUmakefile*" --exclude "*.coords.data" --exclude RCS --exclude README --exclude "add_*" --exclude "inaccessible_strassen" --exclude "innerberliner_grenze" --exclude "kinos" --exclude "kneipen" --exclude "restaurants*" --exclude "old" --exclude "oldcoord" --exclude "orig" --exclude "multi_bez_str" --exclude "sehenswuerdigkeit_img" --exclude "str_cont_ausnahme" --exclude "umsteigebhf" -ru /tmp/convert ~/src/bbbike/data | less
#
#   and:
#
# diff /tmp/convert/ampelschaltung-orig.txt  ~/src/bbbike/misc/ampelschaltung.txt
#
# Vorgehensweise zur Konvertierung:
# - Datei-orig einchecken und wieder auschecken
# - "make origconvert" (mindestens für diese Datei) aufrufen
# - zur Sicherheit: "diff /tmp/convert/datei datei" aufrufen
# - zur Sicherheit: wc -l auf beide -orig-Versionen aufrufen (sollte gleich sein)
# - Datei-orig nach oldcoord verschieben
# - mv /tmp/convert/datei-orig hierher
# - Eintrag in BASE korrigieren
# - zur Sicherheit "make" aufrufen
# - datei-orig mit inkrementierten Version einchecken
#   logeintrag: map transition (B => H)

ORIGCONVERTDIR=/tmp/convert
TARGETS2=$(TARGETS:Nampelschaltung:Nrbahn:Nrbahnhof:Nplz:Nradwege_exact:Nmount:Nberlin:S/$/-orig/)
TARGETS3=$(TARGETS2:S/^/$(ORIGCONVERTDIR)\//)

origconvert:	$(ORIGCONVERTDIR) $(TARGETS3) \
		$(ORIGCONVERTDIR)/rbahn-orig \
		$(ORIGCONVERTDIR)/plz-orig \
		$(ORIGCONVERTDIR)/fragezeichen-orig \
		$(ORIGCONVERTDIR)/ampelschaltung-orig \
		$(ORIGCONVERTDIR)/ampelschaltung-orig.txt

origconvert-all:	origconvert-all1 origconvert-all2

origconvert-all1:
	cd $(ORIGCONVERTDIR) && env BBBIKE_DATADIR=$(ORIGCONVERTDIR) make BBBIKEDIR=${.CURDIR}/..

origconvert-all2:
	cd $(ORIGCONVERTDIR) && env BBBIKE_DATADIR=$(ORIGCONVERTDIR) make -f ${.CURDIR}/../misc/Makefile BBBIKEDIR=${.CURDIR}/.. DATADIR=$(ORIGCONVERTDIR)


.PHONY: $(ORIGCONVERTDIR)

$(ORIGCONVERTDIR):
	if [ ! -d $(ORIGCONVERTDIR) ] ; then \
	    mkdir $(ORIGCONVERTDIR); \
	fi
	cp -f Makefile $(ORIGCONVERTDIR)
	cp -f Makefile.mapfiles $(ORIGCONVERTDIR)
	cat BASE $(MISCDIR)/BASE | perl -pe 's/\t+./\tH/' > $(ORIGCONVERTDIR)/BASE

.for f in $(TARGETS2)
$(ORIGCONVERTDIR)/$f:	$f
	env BBBIKE_DATADIR=$(ORIGCONVERTDIR) $(CONVERT2HAFAS) -keepeverything $f > $(ORIGCONVERTDIR)/$f
.endfor

$(ORIGCONVERTDIR)/rbahn-orig: rbahn-orig
	env BBBIKE_DATADIR=$(ORIGCONVERTDIR) $(CONVERT2HAFAS) -keepeverything rbahn-orig > $(ORIGCONVERTDIR)/rbahn-orig

$(ORIGCONVERTDIR)/plz-orig: plz-orig
	env BBBIKE_DATADIR=$(ORIGCONVERTDIR) $(CONVERT2HAFAS) -keepeverything plz-orig > $(ORIGCONVERTDIR)/plz-orig

$(ORIGCONVERTDIR)/fragezeichen-orig: ../misc/fragezeichen-orig
	env BBBIKE_DATADIR=$(ORIGCONVERTDIR) $(CONVERT2HAFAS) -keepeverything ../misc/fragezeichen-orig > $(ORIGCONVERTDIR)/fragezeichen-orig

$(ORIGCONVERTDIR)/ampelschaltung-orig: ampelschaltung-orig
	env BBBIKE_DATADIR=$(ORIGCONVERTDIR) $(CONVERT2HAFAS) -ampelschaltung -keepeverything ampelschaltung-orig > $(ORIGCONVERTDIR)/ampelschaltung-orig

$(ORIGCONVERTDIR)/ampelschaltung-orig.txt: ../misc/ampelschaltung-orig.txt
	env BBBIKE_DATADIR=$(ORIGCONVERTDIR) $(CONVERT2HAFAS) -ampelschaltung2 -keepeverything ../misc/ampelschaltung-orig.txt > $(ORIGCONVERTDIR)/ampelschaltung-orig.txt

#strassen-orig:	oldcoord/strassen-orig
#	env BBBIKE_DATADIR=$(ORIGCONVERTDIR) $(CONVERT2HAFAS) -frommap B -keepeverything $> > $@

######################################################################
# 2. Phase
# Alle Dateien, die E oder andere Prefixe haben:
ORIGCONVERT2DIR=/tmp/convert2
TARGETS4=
TARGETS4+=ampeln-orig
TARGETS4+=brunnels-orig
TARGETS4+=comments_cyclepath-orig
TARGETS4+=comments_ferry-orig
TARGETS4+=comments_kfzverkehr-orig
TARGETS4+=comments_misc-orig
TARGETS4+=comments_mount-orig
TARGETS4+=comments_route-orig
TARGETS4+=deutschland-orig
TARGETS4+=faehren-orig
TARGETS4+=flaechen-orig
TARGETS4+=gesperrt-orig
TARGETS4+=gesperrt_car-orig
TARGETS4+=green-orig
TARGETS4+=handicap_l-orig
TARGETS4+=hoehe-orig
TARGETS4+=landstrassen-orig
TARGETS4+=landstrassen2-orig
TARGETS4+=obst-orig
TARGETS4+=orte-orig
TARGETS4+=orte2-orig
TARGETS4+=potsdam-orig
TARGETS4+=qualitaet_l-orig
TARGETS4+=qualitaet_s-orig
TARGETS4+=rbahn-orig
TARGETS4+=relation_gps-orig
TARGETS4+=sbahn-orig
TARGETS4+=sbahnhof-orig
TARGETS4+=sbahnhof_bg-orig
TARGETS4+=sehenswuerdigkeit-orig
TARGETS4+=vorfahrt-orig
TARGETS4+=wasserstrassen-orig
TARGETS4+=wasserumland-orig
TARGETS4+=wasserumland2-orig
TARGETS5=$(TARGETS4:S/^/$(ORIGCONVERT2DIR)\//)

.for f in $(TARGETS4)
$(ORIGCONVERT2DIR)/$f:	$f
	env BBBIKE_DATADIR=$(ORIGCONVERT2DIR) $(CONVERT2HAFAS) -keepcomment -keeppointattrib -noautodescent $f > $(ORIGCONVERT2DIR)/$f
.endfor

origconvert2:	$(ORIGCONVERT2DIR) $(TARGETS5)

$(ORIGCONVERT2DIR):
	if [ ! -d $(ORIGCONVERT2DIR) ] ; then \
	    mkdir $(ORIGCONVERT2DIR); \
	fi
	cp -f Makefile $(ORIGCONVERT2DIR)
	cp -f Makefile.mapfiles $(ORIGCONVERT2DIR)
	if [ ! -e $(ORIGCONVERT2DIR)/strassen ] ; then \
	    cp strassen $(ORIGCONVERT2DIR); \
	fi
	cat BASE $(MISCDIR)/BASE | perl -pe 's/\t+./\tH/' > $(ORIGCONVERT2DIR)/BASE

origconvert2-all:
	cd $(ORIGCONVERT2DIR) && env BBBIKE_DATADIR=$(ORIGCONVERT2DIR) make BBBIKEDIR=${.CURDIR}/..

# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

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

gesperrt:	gesperrt-orig strassen landstrassen landstrassen2
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) -specsperre=strassen,landstrassen,landstrassen2 gesperrt-orig > gesperrt
	-@$(READONLY) $@

.for i in u s r
gesperrt_$(i):	gesperrt_$(i)-orig $(i)bahn
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) gesperrt_$(i)-orig | $(MISCSRCDIR)/check_dates -filter > gesperrt_$(i)
	-@$(READONLY) $@
.endfor

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

comments_cyclepath: comments_cyclepath-orig
	-@$(WRITEABLE) $@
	cat $> | $(CONVERT2HAFAS) -basefile $> - | \
	    $(RESOLVE_STARS) strassen landstrassen landstrassen2 - > $@
	-@$(READONLY) $@

comments_ferry: comments_ferry-orig
	-@$(WRITEABLE) $@
	cat $> | $(CONVERT2HAFAS) -basefile $> - | \
	    $(RESOLVE_STARS) strassen landstrassen landstrassen2 - > $@
	-@$(READONLY) $@

comments_misc: comments_misc-orig
	-@$(WRITEABLE) $@
	cat $> | $(CONVERT2HAFAS) -basefile $> - | \
	    $(RESOLVE_STARS) strassen landstrassen landstrassen2 - > $@
	-@$(READONLY) $@

comments_mount: comments_mount-orig
	-@$(WRITEABLE) $@
	cat $> | $(CONVERT2HAFAS) -basefile $> - | \
	    $(RESOLVE_STARS) strassen landstrassen landstrassen2 - > $@
	-@$(READONLY) $@

comments_path: comments_path-orig
	-@$(WRITEABLE) $@
	cat $> | $(CONVERT2HAFAS) -basefile $> - | \
	    $(RESOLVE_STARS) strassen landstrassen landstrassen2 - > $@
	-@$(READONLY) $@

comments_route: comments_route-orig
	-@$(WRITEABLE) $@
	cat $> | $(CONVERT2HAFAS) -basefile $> - | \
	    $(RESOLVE_STARS) strassen landstrassen landstrassen2 - > $@
	-@$(READONLY) $@

comments_tram: comments_tram-orig
	-@$(WRITEABLE) $@
	cat $> | $(CONVERT2HAFAS) -basefile $> - | \
	    $(RESOLVE_STARS) strassen landstrassen landstrassen2 - > $@
	-@$(READONLY) $@

comments_kfzverkehr: comments_kfzverkehr-orig
	-@$(WRITEABLE) $@
	cat $> | $(CONVERT2HAFAS) -basefile $> - | \
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

mount:	strassen hoehe
	-@$(WRITEABLE) $@
	$(STEIGUNG_STAT) -minmount 1.0 -commentscompatible -str strassen -i hoehe -o $@
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

remove_nextruns:
	rm -f .nextrun_*

# checks
check:	.check_strassen1 .check_strassen2 \
	.check_plaetze1 .check_plaetze2 .check_hoehe \
	.check_ampeln .check_gesperrt1 .check_gesperrt2 \
	.check_gesperrt_u2 .check_gesperrt_s2 .check_gesperrt_r2 \
	.check_gesperrt_car1 .check_gesperrt_car2 \
	.check_ubahnhof .check_sbahnhof .check_orte \
	.check_radwege .check_ampelschaltung \
	.check_qualitaet_s .check_qualitaet_l \
	.check_handicap_s .check_handicap_l \
	.check_label .check_vorfahrt \
	.check_comments1 .check_comments2 .check_nolighting \
	.check_housenumbers .check_sehenswuerdigkeit .check_green \
	.check_brunnels .check_comments_ferry \
	.check_temp_blockings \

.check_strassen1:	.strassen.tmp add_str multi_bez_str
	$(CHECK_STR_PLZ) -data .strassen.tmp
	@touch $@

.check_strassen2:	.strassen.tmp str_cont_ausnahme
	$(CHECK_CONT) -data .strassen.tmp
	@touch $@

.check_plaetze1: plaetze .strassen.tmp
	$(CHECK_POINTS) plaetze .strassen.tmp
	@touch $@

.check_plaetze2: plaetze add_plaetze
	$(CHECK_STR_PLZ) -addstr add_plaetze -data plaetze -nomultibez
	@touch $@

.check_hoehe:	hoehe .strassen.tmp landstrassen landstrassen2 
	$(CHECK_POINTS) hoehe .strassen.tmp landstrassen landstrassen2
	@touch $@

.check_ampeln:	ampeln .strassen.tmp landstrassen landstrassen2
	$(CHECK_POINTS) ampeln .strassen.tmp landstrassen landstrassen2
	@touch $@

.check_ampelschaltung:	ampelschaltung-orig ampeln-orig
	$(CHECK_POINTS) -ampelschaltung ampelschaltung-orig ampeln-orig
	@touch $@

.check_gesperrt1:	gesperrt .strassen.tmp landstrassen landstrassen2
	$(CHECK_POINTS) gesperrt .strassen.tmp landstrassen landstrassen2
	@touch $@

.check_gesperrt2:	gesperrt strassen landstrassen landstrassen2
	$(CHECK_NEIGHBOUR) -type standard -data gesperrt \
		-against strassen -against landstrassen -against landstrassen2
	@touch $@

.for i in u s r
.check_gesperrt_$(i)2:	gesperrt_$(i) $(i)bahn
	$(CHECK_NEIGHBOUR) -type standard -data gesperrt_$(i) \
		-against $(i)bahn
	@touch $@
.endfor

.check_gesperrt_car1:	gesperrt_car .strassen.tmp landstrassen landstrassen2
	$(CHECK_POINTS) gesperrt_car .strassen.tmp landstrassen landstrassen2
	@touch $@

.check_gesperrt_car2:	gesperrt_car strassen landstrassen landstrassen2
	$(CHECK_NEIGHBOUR) -type standard -data gesperrt_car \
		-against strassen -against landstrassen -against landstrassen2
	@touch $@

.check_ubahnhof:	ubahnhof ubahn
	$(CHECK_POINTS) ubahnhof ubahn
	@touch $@

.check_sbahnhof:	sbahnhof sbahn
	$(CHECK_POINTS) sbahnhof sbahn
	@touch $@

.check_orte: orte orte2 orte_city
	$(CHECK_DOUBLE) orte orte2 orte_city
	@touch $@

.check_radwege:	radwege_exact strassen
	$(CHECK_NEIGHBOUR) -type standard -data radwege_exact
	@touch $@

.check_qualitaet_s:	qualitaet_s strassen
	$(CHECK_NEIGHBOUR) -type standard -data qualitaet_s
	@touch $@

.check_qualitaet_l:	qualitaet_l landstrassen landstrassen2
	$(CHECK_NEIGHBOUR) -type standard -origmap GISmap -data qualitaet_l \
		-against landstrassen -against landstrassen2
	@touch $@

.check_handicap_s:	handicap_s strassen
	$(CHECK_NEIGHBOUR) -type standard -data handicap_s
	@touch $@

.check_handicap_l:	handicap_l landstrassen landstrassen2
	$(CHECK_NEIGHBOUR) -type standard -origmap GISmap -data handicap_l \
		-against landstrassen -against landstrassen2
	@touch $@

.check_label:	label .strassen.tmp landstrassen landstrassen2
	$(CHECK_POINTS) label .strassen.tmp landstrassen landstrassen2
	@touch $@

.check_vorfahrt:	vorfahrt strassen landstrassen landstrassen2
	$(CHECK_NEIGHBOUR) -type standard -data vorfahrt \
		-against strassen -against landstrassen -against landstrassen2
	$(CHECK_COUNT) -type vorfahrt -data vorfahrt
	@touch $@

.for i in $(COMMENTS_PARTIAL)
.check_comments1:	.check_${i}_1

.check_${i}_1:	$i .strassen.tmp landstrassen landstrassen2 faehren
	$(CHECK_POINTS) $i .strassen.tmp landstrassen landstrassen2 faehren
	@touch $@

.check_comments2:	.check_${i}_2

.check_${i}_2:	$i strassen landstrassen landstrassen2 faehren
	$(CHECK_NEIGHBOUR) -type standard \
	    -against strassen -against landstrassen -against landstrassen2 \
	    -against faehren -data $i
	@touch $@
.endfor

.check_comments_ferry:	comments_ferry faehren
	$(CHECK_NEIGHBOUR) -type standard -against faehren -data comments_ferry
	@touch $@

.check_nolighting:	nolighting strassen
	$(CHECK_NEIGHBOUR) -type standard -data nolighting
	@touch $@

.check_housenumbers:	housenumbers-orig housenumbers .strassen.tmp
	$(CHECK_HOUSENUMBERS) housenumbers-orig
	$(CHECK_POINTS) housenumbers .strassen.tmp
	@touch $@

.check_sehenswuerdigkeit:	sehenswuerdigkeit
	$(CHECK_IMAGES) sehenswuerdigkeit
	@touch $@

.check_green:	green strassen landstrassen
	$(CHECK_NEIGHBOUR) -type standard -data green \
		-against strassen -against landstrassen
	@touch $@

# XXX against landstrassen, too?
.check_brunnels:	brunnels strassen landstrassen landstrassen2
	$(CHECK_NEIGHBOUR) -type standard -data brunnels \
	    -against strassen -against landstrassen -against landstrassen2
	@touch $@

.check_temp_blockings:	${MISCDIR}/temp_blockings/*.bbd strassen
	cat ${MISCDIR}/temp_blockings/*.bbd > /tmp/all_temp_blockings.bbd
	$(CHECK_NEIGHBOUR) -type standard -data /tmp/all_temp_blockings.bbd -against strassen
	rm -f /tmp/all_temp_blockings.bbd
	@touch $@

#.PHONY: .modified

# This also creates .rsync_include
.modified:	${TARGETS}
	${MISCSRCDIR}/create_modified

# XXX maybe create also a ".check_" rule
sort-Berlin.coords.data:
	mv Berlin.coords.data Berlin.coords.data~
	env LC_ALL=de_DE.ISO_8859-1 sort < Berlin.coords.data~ > Berlin.coords.data

# For adjusting the buffer in BBBikeXS.xs.
# Please adjust the number according to MAXBUF and MAXPOINTS in BBBikeXS.xs.
check-line-lengths:	.check_line_lengths

.check_line_lengths:	$(TARGETS)
	MAXLEN=`for i in $(TARGETS); do \
	    perl -nle '$$max = length($$_) if length($$_) > $$max; END { print $$max }' < $$i; \
	done | sort -nr | head -1`; \
	[ $$MAXLEN -lt 12288 ] || ( echo $$MAXLEN; exit 1 )
	MAXPOINTS=`for i in $(TARGETS); do \
	    perl -nle '$$points = scalar split / /; $$max = $$points if $$points > $$max; END { print $$max }' < $$i; \
	done | sort -nr | head -1`; \
	[ $$MAXPOINTS -lt 1024 ] || ( echo $$MAXPOINTS; exit 1 )
	@touch $@

count-streets:
	@echo -n "Berlin:  "; cut -f1 -d"(" strassen | sort -u | wc -l
	@echo -n "Potsdam: "; fgrep "(Potsdam)" landstrassen | cut -f1 -d"(" | sort -u | wc -l

check-dates:	.check_dates

.check_dates:	*-orig
	${MISCSRCDIR}/check_dates $>
	@touch $@

check-crossings:	.check_crossings

.check_crossings:	strassen landstrassen landstrassen2 brunnels
	${MISCSRCDIR}/check_crossings -o /tmp/crossings.bbd -against brunnels \
	    strassen landstrassen landstrassen2
	@touch $@

check-Berlin.coords.data:	.check_Berlin_coords_data

.check_Berlin_coords_data: Berlin.coords.data
	env LC_ALL=de_DE.ISO_8859-1 sort -c Berlin.coords.data || \
	    ( env LC_ALL=de_DE.ISO_8859-1 sort Berlin.coords.data | diff -u - Berlin.coords.data; false )
	@touch $@

GNUmakefile: Makefile ../miscsrc/b2gmake
	../miscsrc/b2gmake < Makefile > GNUmakefile
	chmod ugo+r GNUmakefile

GNUmakefile.mapfiles: Makefile.mapfiles ../miscsrc/b2gmake
	../miscsrc/b2gmake < Makefile.mapfiles > GNUmakefile.mapfiles
	chmod ugo+r GNUmakefile.mapfiles

.include "Makefile.mapfiles"
