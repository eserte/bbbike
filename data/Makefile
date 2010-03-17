#
# $Id: Makefile,v 2.213 2009/02/18 22:53:47 eserte Exp $
#
# This Makefile is only usable with a modern version of BSD make (also known
# as "pmake"). The source for pmake can be found at
#
#   http://www.sourceforge.net/projects/srezic
#
# (This is a slightly modified version of the original pmake as found in
# the FreeBSD sources)
#
# pmake is also available as a standard Debian package, but a somewhat
# older version which has some minor problems:
# * the uppercase construct ${...:U} does not exist

.ifndef HOSTNAME
HOSTNAME	!= hostname
.endif

BBBIKEDIR=		..
MISCDIR=		$(BBBIKEDIR)/misc
MISCSRCDIR=		$(BBBIKEDIR)/miscsrc
DATADIR=		.
PERSISTENTTMPDIR=	$(BBBIKEDIR)/tmp

PERL?=			perl
# assume we have a modern perl (> 5.8.0, which has utf8 bugs) installed...
PERL_UTF8?=		${PERL}
NO_LOCALE=		env LANG=C LC_ALL=C LC_CTYPE=C
SED?=			${NO_LOCALE} sed
CUT?=			${NO_LOCALE} cut

HAFAS2HAFAS=		${PERL} ${MISCSRCDIR}/hafas2hafas -strict
CONVERT2HAFAS=		${PERL} ${MISCSRCDIR}/convert2hafas -strict
CONVERT_ORIG_FILE=	${MISCSRCDIR}/convert_orig_to_bbd
CONVERT_ORIG=		${PERL} ${CONVERT_ORIG_FILE}
CHECK_POINTS=		${PERL} ${MISCSRCDIR}/check_points
CHECK_STR_PLZ=		${PERL} ${MISCSRCDIR}/check_str_plz
CHECK_CONT=		${PERL} ${MISCSRCDIR}/check_cont
CHECK_DOUBLE=           ${PERL} ${MISCSRCDIR}/check_double
CHECK_NEIGHBOUR=	${PERL} ${MISCSRCDIR}/check_neighbour
CHECK_COUNT=		${PERL} ${MISCSRCDIR}/check_count
CHECK_HOUSENUMBERS=	${PERL} ${MISCSRCDIR}/check_housenumbers
CHECK_IMAGES=		${PERL} ${MISCSRCDIR}/check_images
CHECK_STATION_CATEGORY=	${PERL} ${MISCSRCDIR}/check_station_category
RESOLVE_STARS=		${PERL} ${MISCSRCDIR}/resolve_stars
SORTBYCAT=		${PERL} ${MISCSRCDIR}/sortbycat
SEARCH_INACCESSIBLE=	${PERL} ${MISCSRCDIR}/search_inaccessible_points
STEIGUNG_STAT=		${PERL} ${MISCSRCDIR}/steigung_stat
GREPSTRASSEN=		${PERL} ${MISCSRCDIR}/grepstrassen
REPLACESTRASSEN=	${PERL} ${MISCSRCDIR}/replacestrassen
GREPSTRASSEN_UTF8=	${PERL_UTF8} ${MISCSRCDIR}/grepstrassen
COMBINE_STREETS=	${PERL} ${MISCSRCDIR}/combine_streets.pl
COMBINE_OSM=		${PERL} ${MISCSRCDIR}/combineosm
TEMP_BLOCKINGS_TASKS=	${PERL} ${MISCSRCDIR}/temp_blockings_tasks

COMMENTS_PARTIAL=	comments_cyclepath comments_danger comments_ferry comments_misc \
			comments_mount comments_path comments_route \
			comments_tram comments_kfzverkehr comments_scenic

SOURCE_TARGETS=		strassen plaetze landstrassen landstrassen2 strassen_bab
SOURCE_TARGETS+=	flaechen
SOURCE_TARGETS+=	wasserstrassen wasserumland wasserumland2
SOURCE_TARGETS+=	sbahn sbahnhof rbahn rbahnhof
SOURCE_TARGETS+=	ubahn ubahnhof
SOURCE_TARGETS+=	faehren hoehe orte orte2 orte_city
SOURCE_TARGETS+=	ampeln ampelschaltung
SOURCE_TARGETS+=	plz potsdam deutschland grenzuebergaenge
SOURCE_TARGETS+=	sehenswuerdigkeit obst radwege
SOURCE_TARGETS+=	qualitaet_s qualitaet_l
SOURCE_TARGETS+=	handicap_s handicap_l
SOURCE_TARGETS+=	vorfahrt nolighting
SOURCE_TARGETS+=	housenumbers green brunnels
SOURCE_TARGETS+=	gesperrt gesperrt_car
.for i in u s r
SOURCE_TARGETS+=	gesperrt_$(i)
.endfor
SOURCE_TARGETS+=	${COMMENTS_PARTIAL} fragezeichen exits multi_bez_str

# These do not have a -orig file of their own, or another type of source file
COMPUTED_TARGETS=	sbahnhof_bg ubahnhof_bg berlin berlin_ortsteile
COMPUTED_TARGETS+=	radwege_exact mount
COMPUTED_TARGETS+=	temp_blockings/bbbike-temp-blockings-optimized.pl
COMPUTED_TARGETS+=	wasserstrassen-lowres
COMPUTED_TARGETS+=	kneipen
COMPUTED_TARGETS+=	fragezeichen-cooked

COOKED_TARGETS=		strassen-cooked landstrassen-cooked landstrassen2-cooked
TARGETS+=	${SOURCE_TARGETS} ${COOKED_TARGETS} ${COMPUTED_TARGETS}
BBD_TARGETS=	${TARGETS:S/^ampelschaltung$//:S/^multi_bez_str$//:S/^temp_blockings\/bbbike-temp-blockings-optimized.pl//}

XXX_NON_OTHER=	indoor outdoor prog checklater
XXX_TARGETS=	other ${XXX_NON_OTHER}

ALL_STREETS=		strassen landstrassen landstrassen2

TARGETS_DISABLED=	relation_gps 

WRITEABLE=	chmod u+w,ugo+r
READONLY=	chmod ugo+r,ugo-w
READABLE=	chmod ugo+r

# The locale was named de_DE.ISO_8859-1 in FreeBSD 4.x, but now with
# an underline less.
.ifdef .FreeBSD
GERMAN_LOCALE=de_DE.ISO8859-1
.else
# e.g. debian
GERMAN_LOCALE=de_DE.ISO-8859-1
.endif
SORT_GERMAN_LOCALE=	env LANG=${GERMAN_LOCALE} LC_CTYPE=${GERMAN_LOCALE} LC_ALL=${GERMAN_LOCALE} sort
SORT_NO_LOCALE=		env ${NO_LOCALE} sort

## This seems to generate better results:
COORDS_DATA_SORT_OPTS=	-f -t "|" -k 1,3
#COORDS_DATA_SORT_OPTS=

TODAY_DATE!=	date +'%Y%m%d'

######################################################################
# META TARGETS

.ORDER: targets data-images check .modified .rsync_include make_misc
all:	targets data-images check .modified .rsync_include make_misc

# These targets have to be rebuild once a day
.BEGIN:
	@$(PERL) -e 'for (@ARGV) { do { unlink($$_) and warn "Removed $$_\n" } if (-M $$_ >= 1) }' \
		.check_bbbike-temp-blockings-optimized \
		.check_dates \
		${PERSISTENTTMPDIR}/.check_fragezeichen-nextcheck.bbd \
		${PERSISTENTTMPDIR}/.check_fragezeichen-indoor-nextcheck.bbd \
		${PERSISTENTTMPDIR}/.check_fragezeichen-outdoor-nextcheck.bbd

targets:	${TARGETS}

targets-clean:
	-mkdir /tmp/old-data
	mv -f ${TARGETS} /tmp/old-data/

fix-permissions:
	$(READABLE) $(TARGETS) temp_blockings/bbbike-temp-blockings.pl temp_blockings/*.bbd

# Useful checks, but normally too slow for a quick build
# XXX merge with sort-Berlin.coords.data rule below?
slow-checks:	check-categories \
		check-names \
		.check_targets \
		inaccessible_strassen inaccessible_landstrassen \
		check-line-lengths check-dates \
		check-coords.data \
		persistent-tmp

persistent-tmp:	${PERSISTENTTMPDIR}/.check_fragezeichen-outdoor-nextcheck.bbd \
		${PERSISTENTTMPDIR}/fragezeichen-outdoor-nextcheck.bbd \
		${PERSISTENTTMPDIR}/.check_fragezeichen-indoor-nextcheck.bbd \
		${PERSISTENTTMPDIR}/fragezeichen-indoor-nextcheck.bbd \
		${PERSISTENTTMPDIR}/.check_fragezeichen-nextcheck.bbd \
		${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd \
		${PERSISTENTTMPDIR}/strassen_in_planung.bbd \
		${PERSISTENTTMPDIR}/projektierte_radstreifen.bbd \
		${PERSISTENTTMPDIR}/all-upload-fragezeichen.wpt \
		${PERSISTENTTMPDIR}/my-upload-fragezeichen.wpt \
		${PERSISTENTTMPDIR}/Berlin.coords.bbd \
		${PERSISTENTTMPDIR}/Potsdam.coords.bbd \
		${PERSISTENTTMPDIR}/non-faked-plaetze \
		${PERSISTENTTMPDIR}/non-faked-strassen \
		${PERSISTENTTMPDIR}/XXX.bbd \
		${PERSISTENTTMPDIR}/plz-b.bbd \
		persistent-tmp-from-opengeodb

.for i in $(XXX_TARGETS)
persistent-tmp:	${PERSISTENTTMPDIR}/XXX-$(i).bbd
.endfor

# even slower (about four minutes)
really-slow-checks:	check-crossings-important \
			check-nearest \
			check-crossings-less-important

######################################################################
# DATA FILE TARGETS

######################################################################
# STRASSEN UND PLÄTZE
strassen:	.strassen.tmp plaetze routing_helper-orig
	-@$(WRITEABLE) $@
	cat .strassen.tmp > $@~
	${GREPSTRASSEN} -v --namerx ' \(Potsdam\)' plaetze >> $@~
	${GREPSTRASSEN} -ignoreglobaldirectives -catrx . routing_helper-orig |\
	    ${REPLACESTRASSEN} -catexpr 's/.*/NN::igndisp/' >> $@~
	mv $@~ $@
	-@$(READONLY) $@

.strassen.tmp: strassen-orig
	$(CONVERT_ORIG) -keep-directive alias strassen-orig |\
	    ${REPLACESTRASSEN} -catexpr 's/NH/N/' > $@~
	mv $@~ $@

.for f in ${COOKED_TARGETS}
_f_raw_${f}:=${f:S/-cooked$//}
$f:	${_f_raw_${f}} inaccessible_landstrassen
	-@${WRITEABLE} $@
	$(PERL) -I${BBBIKEDIR} -I${BBBIKEDIR}/lib -MStrassen -e \
	    '$$s = Strassen->new($$ARGV[0]); $$ina = Strassen->new($$ARGV[1]); $$s->new_with_removed_points($$ina)->write("-")' \
	    ${_f_raw_${f}} inaccessible_landstrassen \
	    > $@~
	mv $@~ $@
	-@${READONLY} $@
.endfor

plaetze: plaetze-orig
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) plaetze-orig > plaetze~
	mv plaetze~ plaetze
	-@$(READONLY) $@

${PERSISTENTTMPDIR}/non-faked-plaetze: plaetze-orig
	-@$(WRITEABLE) $@
	${GREPSTRASSEN} -v -section "faked_plaetze" plaetze-orig | $(CONVERT_ORIG) > $@~
	mv $@~ $@
	-@$(READONLY) $@

${PERSISTENTTMPDIR}/non-faked-strassen: .strassen.tmp ${PERSISTENTTMPDIR}/non-faked-plaetze
	-@$(WRITEABLE) $@
	cat $> > $@
	-@$(READONLY) $@

inaccessible_strassen: strassen gesperrt
	-@$(WRITEABLE) $@
	-cp -f $@ /tmp/old_inaccessible_strassen
	${SEARCH_INACCESSIBLE} -street strassen -blocked gesperrt \
	    -blockedtype einbahn -blockedtype sperre \
	    > inaccessible_strassen~ && mv inaccessible_strassen~ inaccessible_strassen
	@if [ -e /tmp/old_inaccessible_strassen ] ; then \
	    diff -u /tmp/old_inaccessible_strassen $@; \
	fi
	@rm -f /tmp/old_inaccessible_strassen
	-@$(READONLY) $@

inaccessible_landstrassen: strassen landstrassen landstrassen2 gesperrt
	-@$(WRITEABLE) $@
	-cp -f $@ /tmp/old_inaccessible_landstrassen
	${SEARCH_INACCESSIBLE} -street strassen -street landstrassen \
	    -street landstrassen2 -street faehren -blocked gesperrt \
	    -blockedtype einbahn -blockedtype sperre \
	    > inaccessible_landstrassen~ && mv inaccessible_landstrassen~ inaccessible_landstrassen
	@if [ -e /tmp/old_inaccessible_landstrassen ] ; then \
	    diff -u /tmp/old_inaccessible_landstrassen $@; \
	fi
	@rm -f /tmp/old_inaccessible_landstrassen
	-@$(READONLY) $@

######################################################################
# OTHER DATA LAYERS

# sortbycat does not change the sort order of islands
wasserstrassen: wasserstrassen-orig
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) -keep-directive alias wasserstrassen-orig | $(SORTBYCAT) -ignore F:I > $@ \
	    || (rm -f $@; false)
	-@$(READONLY) $@

wasserumland: wasserumland-orig
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) -keep-directive alias wasserumland-orig | $(SORTBYCAT) -ignore F:I > $@ \
	    || (rm -f $@; false)
	-@$(READONLY) $@

wasserumland2: wasserumland2-orig
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) -keep-directive alias -unutf8ify wasserumland2-orig | $(SORTBYCAT) -ignore F:I > $@~
	[ -s $@~ ]
	mv $@~ $@
	-@$(READONLY) $@

# The output is not the prettiest, but we save some 100k
wasserstrassen-lowres:  wasserstrassen wasserumland wasserumland2 \
			Makefile $(MISCSRCDIR)/simplify_streets
	-@$(WRITEABLE) $@
	cat wasserstrassen wasserumland wasserumland2 |\
	    $(GREPSTRASSEN) --catrx '^(F:W1)$$' > $@~
	cat wasserstrassen wasserumland wasserumland2 |\
	    $(GREPSTRASSEN) --catrx '^(W1|W2|F:W|F:I)$$' --minarea 3 >> $@~
#	$(PERL) $(MISCSRCDIR)/simplify_streets -simplify-coefficient 0.04 $@~ > $@~~
	$(PERL) $(MISCSRCDIR)/simplify_streets -tolerance 300 -algorithm 'douglas-peucker' $@~ > $@~~
	rm $@~
	mv -f $@~~ $@
	-@$(READONLY) $@

flaechen: flaechen-orig
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) flaechen-orig > flaechen~
	mv $@~ $@
	-@$(READONLY) $@

green:	green-orig
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) $> > $@~
	mv $@~ $@
	-@$(READONLY) $@

brunnels:	brunnels-orig
	-@$(WRITEABLE) $@
	${GREPSTRASSEN} -v -preserveglobaldirectives -section 'S-Bahn' $> | $(CONVERT_ORIG) > $@~
	mv $@~ $@
	-@$(READONLY) $@

landstrassen: landstrassen-orig plaetze
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) -keep-directive alias landstrassen-orig > $@~
	${GREPSTRASSEN} --namerx ' \(Potsdam\)' plaetze >> $@~
	mv $@~ $@
	-rm -f landstrassen-cooked
	-@$(READONLY) $@

landstrassen2: landstrassen2-orig
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) -keep-directive alias landstrassen2-orig > $@~
	mv $@~ $@
	-rm -f landstrassen2-cooked
	-@$(READONLY) $@

strassen_bab: strassen_bab-orig
	-@$(WRITEABLE) $@
	cat strassen_bab-orig |\
		${GREPSTRASSEN} -v -sectionrx "Autobahnen in Planung" -preserveglobaldirectives |\
	    $(CONVERT_ORIG) > $@~
	mv $@~ $@
	-@$(READONLY) $@

# Get categories with:
# perl -nle '/\t(\S+)/ && print $1' sbahn-orig | sort -u
SBAHN_CATEGORIES=	SA SB SC S0 SBau

sbahn: sbahn-orig Makefile $(CONVERT_ORIG_FILE)
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) -strip-future-categories sbahn-orig > /tmp/sbahn
.for cat in $(SBAHN_CATEGORIES)
	$(GREPSTRASSEN) -catrx ^$(cat).* /tmp/sbahn | ${PERL} $(MISCSRCDIR)/merge_overlapping_streets.pl -sep "," - | $(COMBINE_STREETS) - | $(SORT_NO_LOCALE) > /tmp/sbahn-$(cat)
.endfor
	cat $(SBAHN_CATEGORIES:S/^/\/tmp\/sbahn-/) > sbahn~
	mv sbahn~ sbahn
	@rm -f $(SBAHN_CATEGORIES:S/^/\/tmp\/sbahn-/)
	@rm -f /tmp/sbahn
	-@$(READONLY) $@

sbahnhof:	sbahnhof-orig
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) sbahnhof-orig > sbahnhof~
	mv sbahnhof~ sbahnhof
	-@$(READONLY) $@

## Execute from bbbike root directory (evtl. mehrmals):
## XXX What for?
# cp -f data/Berlin.coords.data /tmp
# perl -Ilib -MObject::Iterate=iterate -MStrassen::Core -MTie::File -e '$s = Strassen->new("sbahnhof"); iterate { $p{$_->[Strassen::NAME]} = $_->[Strassen::COORDS][0] } $s; tie @f, "Tie::File", "/tmp/Berlin.coords.data" or die ; for (@f) { if (/^S-Bhf (.*?)\|.*\|$/ && $p{$1}) { $_ .= $p{$1}; warn "$1 $p{$1}" } }'

# See SBAHN_CATEGORIES comment
RBAHN_CATEGORIES=	RA RB RC R R0 RBau RG RP

rbahn: rbahn-orig Makefile $(CONVERT_ORIG_FILE)
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) -strip-future-categories rbahn-orig > /tmp/rbahn
.for cat in $(RBAHN_CATEGORIES)
	$(GREPSTRASSEN) -catrx ^$(cat).* /tmp/rbahn | ${PERL} $(MISCSRCDIR)/merge_overlapping_streets.pl -sep "," - | $(COMBINE_STREETS) - | $(SORT_NO_LOCALE) > /tmp/rbahn-$(cat)
.endfor
	cat $(RBAHN_CATEGORIES:S/^/\/tmp\/rbahn-/) > rbahn~
	mv rbahn~ rbahn
	@rm -f $(RBAHN_CATEGORIES:S/^/\/tmp\/rbahn-/)
	@rm -f /tmp/rbahn
	-@$(READONLY) $@

rbahnhof:	rbahnhof-orig
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) rbahnhof-orig > rbahnhof~
	mv rbahnhof~ rbahnhof
	-@$(READONLY) $@

ubahn: ubahn-orig $(CONVERT_ORIG_FILE)
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) -strip-future-categories ubahn-orig > ubahn~
	mv ubahn~ ubahn
	-@$(READONLY) $@

ubahnhof:	ubahnhof-orig
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) ubahnhof-orig > ubahnhof~
	mv ubahnhof~ ubahnhof
	-@$(READONLY) $@

## Execute from bbbike root directory (evtl. mehrmals):
## XXX What for?
# cp -f data/Berlin.coords.data /tmp
# perl -Ilib -MObject::Iterate=iterate -MStrassen::Core -MTie::File -e '$s = Strassen->new("ubahnhof"); iterate { $p{$_->[Strassen::NAME]} = $_->[Strassen::COORDS][0] } $s; tie @f, "Tie::File", "/tmp/Berlin.coords.data" or die $!; for (@f) { if (/^U-Bhf (.*?)\|.*\|$/ && $p{$1}) { $_ .= $p{$1}; warn "$1 $p{$1}" } }'

.for i in u s
$(i)bahnhof_bg:	$(i)bahnhof-orig
	-@$(WRITEABLE) $@
# XXX :U modifier does not work with older pmakes, need a workaround...
	(echo "#: title: Fahrradfreundliche Zugänge bei der $(i:U)-Bahn"; \
	 [ "$(i)" = "s" ] && echo "#: note: http://www.s-bahn-berlin.de/fahrplanundnetz/sbahnhof_anzeige.php?ID=103"; \
	 echo "#:") > $@~
	$(PERL) -I../lib -I.. -MStrassen::Core -MObject::Iterate=iterate -e '\
	$$s=Strassen->new(shift, UseLocalDirectives => 1);\
	$$new_s=Strassen->new;\
	iterate {\
	    my $$attr = $$s->get_directive($$s->pos)->{attributes};\
	    if ($$attr) {\
		$$attr = $$attr->[0]; \
		if ($$attr =~ s/\s+\((.*)\)//) {\
	            $$_->[Strassen::NAME] .= ": $$1";\
		}\
	        $$_->[Strassen::CAT] = $$attr;\
	        $$new_s->push($$_);\
	    }\
	} $$s;\
	print $$new_s->as_string' $> >> $@~
	mv $@~ $@
	-@$(READONLY) $@
.endfor

faehren: faehren-orig
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) faehren-orig > faehren~
	mv faehren~ faehren
	-@$(READONLY) $@

hoehe: hoehe-orig
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) hoehe-orig > hoehe~
	mv hoehe~ hoehe
	-@$(READONLY) $@

orte: orte-orig
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) -keep-directive alias -unutf8ify orte-orig | $(SORTBYCAT) > orte~
	[ -s orte~ ]
	mv orte~ orte
	-@$(READONLY) $@

orte2: orte2-orig
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) -keep-directive alias -unutf8ify orte2-orig | $(SORTBYCAT) > orte2~
	[ -s orte2~ ]
	mv orte2~ orte2
	-@$(READONLY) $@

orte_city: orte_city-orig
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) -keep-directive alias orte_city-orig | $(SORTBYCAT) > orte_city~
	mv orte_city~ orte_city
	-@$(READONLY) $@

ortsschilder: ortsschilder-orig
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) -unutf8ify ortsschilder-orig > ortsschilder~
	mv ortsschilder~ ortsschilder
	-@$(READONLY) $@

ampeln:	ampeln-orig
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) ampeln-orig > ampeln~
	mv ampeln~ ampeln
	-@$(READONLY) $@

ampelschaltung:	ampelschaltung-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) -ampelschaltung ampelschaltung-orig > ampelschaltung~
	mv ampelschaltung~ ampelschaltung
	-@$(READONLY) $@

gesperrt .gesperrt.tmp:	gesperrt-orig strassen landstrassen landstrassen2 comments_path routing_helper-orig
	-@$(WRITEABLE) gesperrt
	$(CONVERT2HAFAS) -specsperre=strassen,landstrassen,landstrassen2 \
	    -specsperre-exceptions=comments_path gesperrt-orig > .gesperrt.tmp
	$(REPLACESTRASSEN) -catexpr 's/:q\d//' < .gesperrt.tmp > gesperrt~
	${GREPSTRASSEN} -ignoreglobaldirectives -catrx ';$$' routing_helper-orig |\
	    ${REPLACESTRASSEN} -catexpr 's/.*/1::igndisp/' -revcoords >> gesperrt~
	mv gesperrt~ gesperrt
	-@$(READONLY) gesperrt

${PERSISTENTTMPDIR}/gesperrt-without-nocross:	gesperrt-orig strassen landstrassen landstrassen2
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) -specsperre=strassen,landstrassen,landstrassen2 \
	    -nonc gesperrt-orig > $@~
	mv $@~ $@
	-@$(READONLY) $@

.for i in u s r
gesperrt_$(i):	gesperrt_$(i)-orig $(i)bahn
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) gesperrt_$(i)-orig | ${PERL} $(MISCSRCDIR)/check_dates -filter > $@~
	mv $@~ $@
	-@$(READONLY) $@
.endfor

gesperrt_car:	gesperrt_car-orig strassen landstrassen landstrassen2 ${PERSISTENTTMPDIR}/gesperrt-without-nocross
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) -specsperre=strassen,landstrassen,landstrassen2 \
	    gesperrt_car-orig |\
	${RESOLVE_STARS} -sperrefile ${PERSISTENTTMPDIR}/gesperrt-without-nocross ${ALL_STREETS} - > gesperrt_car~
	mv gesperrt_car~ gesperrt_car
	-@$(READONLY) $@

plz berlin:	plz-orig
	-@$(WRITEABLE) plz berlin
	cat plz-orig | \
	    ${GREPSTRASSEN} -v -sectionrx "ortsteile" -preserveglobaldirectives | \
	    $(CONVERT2HAFAS) -basefile plz-orig -specborder=berlin - > plz~
	${COMBINE_STREETS} berlin > berlin~
	mv -f berlin~ berlin
	mv -f plz~ plz
	-@$(READONLY) plz berlin

berlin_ortsteile:	plz-orig
	-@$(WRITEABLE) $@
	cat plz-orig | \
	    ${GREPSTRASSEN} -sectionrx "ortsteile" -preserveglobaldirectives | \
	    $(CONVERT2HAFAS) -basefile plz-orig - > $@~
	mv -f $@~ $@
	-@$(READONLY) $@

potsdam:	potsdam-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) potsdam-orig > potsdam~
	mv -f potsdam~ potsdam
	${COMBINE_STREETS} potsdam > potsdam~
	mv -f potsdam~ potsdam
	-@$(READONLY) $@

deutschland:	deutschland-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) deutschland-orig > deutschland~
	mv deutschland~ deutschland
	-@$(READONLY) $@

grenzuebergaenge:	grenzuebergaenge-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) grenzuebergaenge-orig > grenzuebergaenge~
	mv grenzuebergaenge~ grenzuebergaenge
	-@$(READONLY) $@

sehenswuerdigkeit:	sehenswuerdigkeit-orig
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) -keep-directive alias -keep-directive section sehenswuerdigkeit-orig > sehenswuerdigkeit~
	mv sehenswuerdigkeit~ sehenswuerdigkeit
	-@$(READONLY) $@

obst:	obst-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) obst-orig > obst~
	mv obst~ obst
	-@$(READONLY) $@

radwege:	radwege-orig
	-@$(WRITEABLE) $@
	${PERL} ${MISCSRCDIR}/convert_radwege < radwege-orig | \
	    $(COMBINE_STREETS) - > $@~
	mv $@~ $@
	-@$(READONLY) $@

radwege_exact:	radwege-orig
	-@$(WRITEABLE) $@
## XXX combine streets is buggy, see strassen-combine.t test!
#	${PERL} ${MISCSRCDIR}/convert_radwege -exact < radwege-orig | \
#	    $(COMBINE_STREETS) - > $@~
	${PERL} ${MISCSRCDIR}/convert_radwege -exact < radwege-orig > $@~
	mv $@~ $@
	-@$(READONLY) $@

qualitaet_s:	qualitaet_s-orig
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) -strip-tendencies qualitaet_s-orig > qualitaet_s~
	mv qualitaet_s~ qualitaet_s
	-@$(READONLY) $@

qualitaet_l:	qualitaet_l-orig
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) -strip-tendencies qualitaet_l-orig > qualitaet_l~
	mv qualitaet_l~ qualitaet_l
	-@$(READONLY) $@

handicap_s:	handicap_s-orig berlin .gesperrt.tmp routing_helper-orig
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) -strip-tendencies handicap_s-orig > handicap_s~
	$(GREPSTRASSEN) -catrx ':q\d' < .gesperrt.tmp |\
	    $(GREPSTRASSEN) -inner berlin |\
	    $(REPLACESTRASSEN) -noglobaldirectives \
		-catexpr 's/.*:(q\d)/$$1::igndisp;/' \
		-nameexpr 's/(.*)/$$1: gegen die Einbahnstraßenrichtung, ggfs. schieben/' \
		>> handicap_s~
	${GREPSTRASSEN} -ignoreglobaldirectives -catrx '^q\d+;$$' routing_helper-orig |\
	    ${REPLACESTRASSEN} -catexpr 's/;/::igndisp;/' >> handicap_s~
	mv handicap_s~ handicap_s
	-@$(READONLY) $@

handicap_l:	handicap_l-orig berlin .gesperrt.tmp
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) -strip-tendencies handicap_l-orig > handicap_l~
	$(GREPSTRASSEN) -catrx ':q\d' < .gesperrt.tmp |\
	    $(GREPSTRASSEN) -outer berlin |\
	    $(REPLACESTRASSEN) -noglobaldirectives \
		-catexpr 's/.*:(q\d)/$$1::igndisp;/' \
		-nameexpr 's/(.*)/$$1: gegen die Einbahnstraßenrichtung, ggfs. schieben/' \
		>> handicap_l~
	mv handicap_l~ handicap_l
	-@$(READONLY) $@

vorfahrt:	vorfahrt-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) vorfahrt-orig > vorfahrt~
	mv vorfahrt~ vorfahrt
	-@$(READONLY) $@

# Old style using convert2hafas. Caution: convert_orig_to_bbd is not
# able to do some things yet necessary here, for example automatic
# Gefaelle generation in comments_mount or not combining X;X
# categories into X
.for f in ${COMMENTS_PARTIAL:Ncomments_route:Ncomments_ferry:Ncomments_misc:Ncomments_cyclepath}
${f}: ${f}-orig ${ALL_STREETS} ${PERSISTENTTMPDIR}/gesperrt-without-nocross
	-@$(WRITEABLE) $@
	cat ${f}-orig | \
	    ${GREPSTRASSEN} -v -sectionrx "ignorieren" | \
	    $(CONVERT2HAFAS) -basefile ${f}-orig - | \
	    ${RESOLVE_STARS} -sperrefile ${PERSISTENTTMPDIR}/gesperrt-without-nocross \
	        ${ALL_STREETS} - > $@~ && \
	mv $@~ $@
	-@$(READONLY) $@
.endfor

# Special target to remove "?" modifier from categories
comments_cyclepath: comments_cyclepath-orig ${ALL_STREETS} ${PERSISTENTTMPDIR}/gesperrt-without-nocross
	-@$(WRITEABLE) $@
	cat comments_cyclepath-orig | \
	    ${GREPSTRASSEN} -v -sectionrx "ignorieren" | \
	    $(CONVERT2HAFAS) -basefile comments_cyclepath-orig - | \
	    ${RESOLVE_STARS} -sperrefile ${PERSISTENTTMPDIR}/gesperrt-without-nocross \
	        ${ALL_STREETS} - | \
	    ${REPLACESTRASSEN} -catexpr 's/\?//' \
		> $@~ && \
	mv $@~ $@
	-@$(READONLY) $@

# New style using convert_orig_to_bbd. comments_route here,
# because of the need for alias and url directives. comments_ferry
# needs special as_of handler. comments_misc, because of a bug
# in convert2hafas
.for f in comments_route comments_ferry comments_misc
${f}: ${f}-orig ${ALL_STREETS} ${PERSISTENTTMPDIR}/gesperrt-without-nocross
	-@$(WRITEABLE) $@
	cat ${f}-orig | \
	    ${GREPSTRASSEN} -v -sectionrx "ignorieren" | \
	    $(CONVERT_ORIG) -keep-directive url -keep-directive alias -special as_of - | \
	    ${RESOLVE_STARS} -sperrefile ${PERSISTENTTMPDIR}/gesperrt-without-nocross \
	        ${ALL_STREETS} - > $@~ && \
	mv $@~ $@
	-@$(READONLY) $@
.endfor

relation_gps:	relation_gps-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) relation_gps-orig > relation_gps~
	mv relation_gps~ relation_gps
	-@$(READONLY) $@

nolighting:	nolighting-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) nolighting-orig > nolighting~
	mv nolighting~ nolighting
	-@$(READONLY) $@

housenumbers:	housenumbers-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) housenumbers-orig > housenumbers~
	mv housenumbers~ housenumbers
	-@$(READONLY) $@

mount:	strassen fragezeichen hoehe gesperrt
	-@$(WRITEABLE) $@
	$(STEIGUNG_STAT) -minmount 1.0 -commentscompatible -sperre gesperrt \
		-str strassen -str fragezeichen -i hoehe -o $@~
	mv $@~ $@
	-@$(READONLY) $@

exits:	exits-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) $> > $@~
	mv $@~ $@
	-@$(READONLY) $@

kneipen:	kneipen.yml
	-@$(WRITEABLE) $@
	${PERL} $(MISCSRCDIR)/yaml2bbd $> > $@~
	mv $@~ $@
	-@$(READONLY) $@

######################################################################
# DATA-SPECIFIC IMAGES
SEHENSWUERDIGKEIT_IMG_PNG_SRC=	\
				bodemuseum_klein \
				chinesisches_haus \
				fernsehturm \
				franzoesischer_dom \
				friedrichswerdersche_kirche_klein \
				heilandskirche_sacrow \
				hubbruecke_karnin \
				sanssouci \
				wasserturm_ostkreuz \

data-images:	${SEHENSWUERDIGKEIT_IMG_PNG_SRC:S/^/sehenswuerdigkeit_img\//:S/$/.gif/}

.for img in ${SEHENSWUERDIGKEIT_IMG_PNG_SRC}
_img_gif_${img}:=${img:S/^/sehenswuerdigkeit_img\//:S/$/.gif/}
_img_png_${img}:=${_img_gif_${img}:S/.gif$/.png/}
${_img_gif_${img}}: ${_img_png_${img}}
	convert ${_img_png_${img}} ${_img_gif_${img}}
.endfor

######################################################################
# MORE HELPER TARGETS

# This also creates .rsync_include
.modified:	${TARGETS}
	${PERL} ${MISCSRCDIR}/create_modified

multi_bez_str:	multi_bez_str-orig
	-@$(WRITEABLE) $@
	${PERL} ${MISCSRCDIR}/complete_multi_bez_str > $@~
	mv $@~ $@
	-@$(READONLY) $@

# Makefile in ../misc ausführen
# drat ... ich möchte nicht gmake verwenden :-(
make_misc:
	cd $(MISCDIR) && ${MAKE} ${MAKEFLAGS} 

# create Storable versions of data files
# handling of Storable files is up to twice as fast as normal bbd files, but not well-tested, so it is not done by default
STORABLE_TARGETS=${BBD_TARGETS:S/$/.st/}
storable:	${STORABLE_TARGETS}

.for i in ${BBD_TARGETS}
$i.st: $i
	$(PERL) -I.. -I../lib ../Strassen/Storable.pm -v -u -f $i $i.st
	$(READABLE) $i.st
.endfor

######################################################################
# FRAGEZEICHEN LAYER

# The fragezeichen-PHONY and .create_fragezeichen stuff is necessary
# to minimize dependencies (well...)

.PHONY:	fragezeichen

.PRECIOUS:	fragezeichen mount

fragezeichen:	.create_fragezeichen
	-@$(WRITEABLE) $@
	cmp -s .create_fragezeichen $@ && true || cp .create_fragezeichen $@
	-@$(READONLY) $@

fragezeichen-cooked:	fragezeichen strassen landstrassen landstrassen2
	-@${WRITEABLE} $@
	${PERL} ${MISCSRCDIR}/reduce_streets -delsinglepoint -reducelines fragezeichen \
	    strassen landstrassen landstrassen2 > $@~
	mv $@~ $@
	-@${READONLY} $@

# ::inwork => will maybe change to :inwork
#XXX in "-orig" transition: handicap_s-orig and gesperrt-orig always need to have the same base map!
.create_fragezeichen:	fragezeichen-orig ${DATADIR}/ampeln-orig \
		${PERSISTENTTMPDIR}/.fragezeichen-other-source \
		${SOURCE_TARGETS:S|^|${PERSISTENTTMPDIR}/.fragezeichen-|} \
		Makefile
	-@$(WRITEABLE) $@
	cat fragezeichen-orig |\
	        ${GREPSTRASSEN} -v -sectionrx "ignorieren" |\
	    ${CONVERT_ORIG} > $@~
	@echo "# added from ampeln-orig" >> $@~
	grep '?' ${DATADIR}/ampeln-orig | \
	    $(SED) -e 's/	\([^ ]*\)/ (\1)	?/' | \
	    ${CONVERT2HAFAS} -basefile ${DATADIR}/ampeln-orig -- - >> $@~
	@echo "# added from other sources: (${SOURCE_TARGETS})" >> $@~
	cat ${PERSISTENTTMPDIR}/.fragezeichen-other-source ${SOURCE_TARGETS:S|^|${PERSISTENTTMPDIR}/.fragezeichen-|} >> $@~
	cmp -s $@~ $@ && rm $@~ || mv $@~ $@
	touch .create_fragezeichen
	-@$(READONLY) $@

.for i in ${SOURCE_TARGETS}
${PERSISTENTTMPDIR}/.fragezeichen-$(i):	$(i)-orig
	${GREPSTRASSEN_UTF8} -special fragezeichen ${DATADIR}/$(i)-orig > /dev/null
	cp -f /tmp/fragezeichen_$(i)-orig.bbd $@
.endfor

######################################################################
# OTHER HELPER LAYERS, NOT INCLUDED IN STANDARD DIST

######################################################################
# PERSISTENT TEMPORARY DIRECTORY TARGETS

# Targets ../tmp/.XXX-{other,indoor,...}-{strassen,landstrassen,...}
.for i in ${SOURCE_TARGETS}
${XXX_TARGETS:C/^/${PERSISTENTTMPDIR}\/.XXX-/:C/$/-$(i)/}:	$(i)-orig
	${GREPSTRASSEN} \
	    -adddirectives XXX \
	    ${XXX_NON_OTHER:C/^/-adddirectives XXX_/} \
	    ${DATADIR}/$(i)-orig > /dev/null
	cp -f /tmp/XXX_$(i)-orig.bbd ${PERSISTENTTMPDIR}/.XXX-other-$(i)
.for xxxtype in ${XXX_NON_OTHER}
	cp -f /tmp/XXX_${xxxtype}_$(i)-orig.bbd ${PERSISTENTTMPDIR}/.XXX-${xxxtype}-$(i)
.endfor
.endfor

.for doormode in indoor outdoor
.ORDER: ${PERSISTENTTMPDIR}/fragezeichen-${doormode}-nextcheck.bbd ${PERSISTENTTMPDIR}/.check_fragezeichen-${doormode}-nextcheck.bbd
${PERSISTENTTMPDIR}/fragezeichen-${doormode}-nextcheck.bbd ${PERSISTENTTMPDIR}/.check_fragezeichen-${doormode}-nextcheck.bbd:	\
		Makefile \
		${SOURCE_TARGETS:S|$|-orig|} \
		${PERSISTENTTMPDIR}/bbbike-temp-blockings-optimized.bbd
	echo -n > ${PERSISTENTTMPDIR}/fragezeichen-${doormode}-nextcheck.bbd~
	echo "#: line_dash: 8, 5" >> ${PERSISTENTTMPDIR}/fragezeichen-${doormode}-nextcheck.bbd~
	echo "#: line_width: 5" >> ${PERSISTENTTMPDIR}/fragezeichen-${doormode}-nextcheck.bbd~
	echo "#:" >> ${PERSISTENTTMPDIR}/fragezeichen-${doormode}-nextcheck.bbd~
	${MISCSRCDIR}/create_fragezeichen_nextcheck.pl --${doormode}-mode \
	    --fragezeichen-mode fragezeichen-orig \
	    --no-fragezeichen-mode \
	    ${SOURCE_TARGETS:S|fragezeichen||:S|$|-orig|} \
	    ${PERSISTENTTMPDIR}/bbbike-temp-blockings-optimized.bbd \
		>> ${PERSISTENTTMPDIR}/fragezeichen-${doormode}-nextcheck.bbd~
	mv -f ${PERSISTENTTMPDIR}/fragezeichen-${doormode}-nextcheck.bbd~ ${PERSISTENTTMPDIR}/fragezeichen-${doormode}-nextcheck.bbd
	touch ${PERSISTENTTMPDIR}/.check_fragezeichen-${doormode}-nextcheck.bbd
.endfor

.ORDER: ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd ${PERSISTENTTMPDIR}/.check_fragezeichen-nextcheck.bbd
${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd ${PERSISTENTTMPDIR}/.check_fragezeichen-nextcheck.bbd:	\
		Makefile \
		ampeln-orig \
		fragezeichen-orig \
		gesperrt-orig \
		qualitaet_s-orig \
		qualitaet_l-orig \
		handicap_s-orig \
		handicap_l-orig \
		${PERSISTENTTMPDIR}/bbbike-temp-blockings-optimized.bbd \
		${PERSISTENTTMPDIR}/XXX-indoor.bbd \
		${PERSISTENTTMPDIR}/XXX-outdoor.bbd \
		${PERSISTENTTMPDIR}/XXX-other.bbd
	echo -n > ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd~
	echo "#: line_dash: 8, 5" >> ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd~
	echo "#: line_width: 5" >> ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd~
	echo "#:" >> ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd~
.for i in ampeln-orig fragezeichen-orig gesperrt-orig qualitaet_s-orig qualitaet_l-orig handicap_s-orig handicap_l-orig ${PERSISTENTTMPDIR}/bbbike-temp-blockings-optimized.bbd
	echo "############################################################" >> ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd~
	echo "# source: $(i)" >> ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd~
	${GREPSTRASSEN} -directive last_checked~. -special nextcheck $(i) > /dev/null
	cat /tmp/nextcheck.bbd >> ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd~
	${GREPSTRASSEN} -directive next_check~. -special nextcheck $(i) > /dev/null
	cat /tmp/nextcheck.bbd >> ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd~
.endfor
	echo "############################################################" >> ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd~
	echo "# source: fragezeichen-orig" >> ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd~
	echo "# (without next_check/last_checked)" >> ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd~
	${GREPSTRASSEN} -special nonextcheck fragezeichen-orig >> ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd~
.for i in indoor outdoor other
	echo "############################################################" >> ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd~
	echo "# source: XXX-$(i)" >> ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd~
	${GREPSTRASSEN} -directive last_checked~. -special nextcheck ${PERSISTENTTMPDIR}/XXX-$(i).bbd > /dev/null
	cat /tmp/nextcheck.bbd >> ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd~
	${GREPSTRASSEN} -directive next_check~. -special nextcheck ${PERSISTENTTMPDIR}/XXX-$(i).bbd > /dev/null
	cat /tmp/nextcheck.bbd >> ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd~
	${GREPSTRASSEN} -special nonextcheck ${PERSISTENTTMPDIR}/XXX-$(i).bbd >> ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd~
.endfor
	-rm -f /tmp/nextcheck.bbd
	mv -f ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd~ ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd
	touch ${PERSISTENTTMPDIR}/.check_fragezeichen-nextcheck.bbd

${PERSISTENTTMPDIR}/projektierte_radstreifen.bbd:	fragezeichen-orig
	cat fragezeichen-orig | ${GREPSTRASSEN} -sectionrx "projektierte Radstreifen" | ${CONVERT2HAFAS} -basefile fragezeichen-orig > $@

${PERSISTENTTMPDIR}/strassen_in_planung.bbd:	fragezeichen-orig
	cat fragezeichen-orig | ${GREPSTRASSEN} -sectionrx "Straßen in Planung" | ${CONVERT2HAFAS} -basefile fragezeichen-orig > $@

# XXX Hmmm, die "temporary"-Einträge könnten eigentlich nach fragezeichen wandern,
# aber nur, wenn sie nicht zusätzlich mit einer next_check/last_checked-Direktive
# versehen wurden... Siehe auch das TODO "Fragezeichen-Reorganisation"
#
# Target ../tmp/XXX-{other,indoor,...}.bbd
.for xxxtype in ${XXX_TARGETS:C/^/XXX-/}
${PERSISTENTTMPDIR}/${xxxtype}.bbd:	${SOURCE_TARGETS:S|^|${PERSISTENTTMPDIR}/.${xxxtype}-|} \
					handicap_s-orig gesperrt-orig
	echo -n > $@~
	echo "#: line_dash: 8, 5" >> $@~
	echo "#:" >> $@~
.for i in ${SOURCE_TARGETS}
	echo "############################################################" >> $@~
	echo "# source: $(i)" >> $@~
	cat ${i:S|^|${PERSISTENTTMPDIR}/.${xxxtype}-|} >> $@~
.endfor
	mv $@~ $@
.endfor

${PERSISTENTTMPDIR}/XXX.bbd: ${PERSISTENTTMPDIR}/XXX-other.bbd
	cat ${PERSISTENTTMPDIR}/XXX-other.bbd > $@~
	@echo "# source: handicap_s-orig and gesperrt-orig" >> $@~
	${GREPSTRASSEN} -directive temporary= \
	    ${DATADIR}/handicap_s-orig ${DATADIR}/gesperrt-orig | \
	    $(PERL) -nle '/(.*\t)(\S+)(.*)/ && !/\b(\d{4}-\d{2}-\d{2}|[0123]?\d\.[01]?\d\.\d{4})\b/ && print "Noch immer? $$1?::inwork$$3"' | \
	    ${CONVERT2HAFAS} -basefile ${DATADIR}/handicap_s-orig -- - >> $@~
	mv $@~ $@

${PERSISTENTTMPDIR}/plz-b.bbd:	$(PERSISTENTTMPDIR)/plz.sql
	grep -i berlin $> | ${PERL} $(MISCSRCDIR)/parse_mapbender_plz.pl > $@

$(PERSISTENTTMPDIR)/plz.sql:	$(PERSISTENTTMPDIR)/plz.zip
	cd `dirname $>` && unzip -q -o `basename $>`

$(PERSISTENTTMPDIR)/plz.zip:
	wget -O ${PERSISTENTTMPDIR}/plz.zip http://prdownloads.sourceforge.net/mapbender/plz.zip?download

${PERSISTENTTMPDIR}/Berlin.coords.bbd: Berlin.coords.data
	$(PERL) -F'\|' -nale 'print "@F[0,1,2]\tX $$F[3]" if $$F[3]' Berlin.coords.data > $@

Berlin.coords-by-citypart:
	mkdir -p ${PERSISTENTTMPDIR}/Berlin.coords-by-citypart
	$(PERL) -F'\|' -nale '\
	    if ($$F[3] && $$F[1]) {\
		my $$fh = $$fh{$$F[1]} || do {\
		    open $$fh{$$F[1]}, ">", "${PERSISTENTTMPDIR}/Berlin.coords-by-citypart/$$F[1]" or die $$!;\
		    $$fh{$$F[1]}\
		};\
		print $$fh "@F[0,1,2]\tX $$F[3]";\
	    }' Berlin.coords.data

Berlin.coords-by-zip:
	mkdir -p ${PERSISTENTTMPDIR}/Berlin.coords-by-zip
	$(PERL) -F'\|' -nale '\
	    if ($$F[3] && $$F[2]) {\
		my $$fh = $$fh{$$F[2]} || do {\
		    open $$fh{$$F[2]}, ">", "${PERSISTENTTMPDIR}/Berlin.coords-by-zip/$$F[2]" or die $$!;\
		    $$fh{$$F[2]}\
		};\
		print $$fh "@F[0,1,2]\tX $$F[3]";\
	    }' Berlin.coords.data

${PERSISTENTTMPDIR}/Potsdam.coords.bbd: Potsdam.coords.data
	$(PERL) -F'\|' -nale 'print "@F[0,1,2]\tX $$F[3]" if $$F[3]' Potsdam.coords.data > $@


OPENGEODB_D_ORTE_FILE=		DE.tab
OPENGEODB_D_ORTE_DISTURL=	http://fa-technik.adfc.de/Codierung/opengeodb/DE.tab
.if ${HOSTNAME} == "mom.herceg.de"
OPENGEODB_DIR=		/amd/vran/root/usr/ports/distfiles/opengeodb
.elif exists(/usr/ports/distfiles/opengeodb)
OPENGEODB_DIR=		/usr/ports/distfiles/opengeodb
.else
OPENGEODB_DIR=		${PERSISTENTTMPDIR}
.endif
OPENGEODB_D_ORTE_PATH=		${OPENGEODB_DIR}/${OPENGEODB_D_ORTE_FILE}

OPENGEODB_D_PLZ_FILE=		PLZ.tab
OPENGEODB_D_PLZ_DISTURL=	http://fa-technik.adfc.de/Codierung/opengeodb/PLZ.tab
OPENGEODB_D_PLZ_PATH=		${OPENGEODB_DIR}/${OPENGEODB_D_PLZ_FILE}

fetch-opengeodb:	${OPENGEODB_D_ORTE_PATH}

# NOTE: This will only fetch one version. To fetch a newer one, remove
# the old first.
${OPENGEODB_D_ORTE_PATH}:
	@echo -n "Should I fetch ${OPENGEODB_D_ORTE_DISTURL} to ${OPENGEODB_D_ORTE_PATH}? (CTRL-C to abort) "
# && true only for bugs in old pmake
	@read yn && true
	wget -O ${OPENGEODB_D_ORTE_PATH}~ ${OPENGEODB_D_ORTE_DISTURL}
	mv ${OPENGEODB_D_ORTE_PATH}~ ${OPENGEODB_D_ORTE_PATH}

${OPENGEODB_D_PLZ_PATH}:
	@echo -n "Should I fetch ${OPENGEODB_D_PLZ_DISTURL} to ${OPENGEODB_D_PLZ_PATH}? (CTRL-C to abort) "
# && true only for bugs in old pmake
	@read yn && true
	wget -O ${OPENGEODB_D_PLZ_PATH}~ ${OPENGEODB_D_PLZ_DISTURL}
	mv ${OPENGEODB_D_PLZ_PATH}~ ${OPENGEODB_D_PLZ_PATH}

persistent-tmp-from-opengeodb:	${PERSISTENTTMPDIR}/opengeodb-orte-DE.bbd

${PERSISTENTTMPDIR}/opengeodb-orte-DE.bbd:	${OPENGEODB_D_ORTE_PATH} ${MISCSRCDIR}/opengeodborte2bbd
	${PERL_UTF8} ${MISCSRCDIR}/opengeodborte2bbd ${OPENGEODB_D_ORTE_PATH} > $@

# About 70 failures for now. If I correct them all, enlarge the bbox.
.check_orte_opengeodb:	orte orte2 ${PERSISTENTTMPDIR}/opengeodb-orte-DE.bbd
	cat orte orte2 | grep -v '^#' | \
	    $(PERL) -pe 'if (m{^(.*)\|(.*)\t}) { print "$$1 $$2\n" } s{^([^\|\t]+).*}{$$1}' | \
	    sort -u > /tmp/orte_bbbike
	cat ${PERSISTENTTMPDIR}/opengeodb-orte-DE.bbd | \
	    ${PERL} ${MISCSRCDIR}/restrict_bbd_data.pl -bbox -59700,60100,116500,-44900 -strdata=- -o=- | \
	    $(PERL) -pe 's{(\s*\(.*\))?\t.*}{}' | sort -u > /tmp/orte_opengeodb
	diff -u /tmp/orte_bbbike /tmp/orte_opengeodb | grep '^\+'

# Die mit "laut adfc-karte" u.ä. gekennzeichneten Straßen extrahieren und
# nach .fragezeichen-other-source schreiben.
# XXX Very strange: with db4 on RedHat 8.0 I have to use O_RDWR instead of
# O_RDONLY, otherwise the oneliner will die without an error message.
# But O_RDWR does not work if the file is read-only, so still use O_RDONLY
# Now using Tie::File, which works everywhere
${PERSISTENTTMPDIR}/.fragezeichen-other-source:	${DATADIR}/qualitaet_s-orig ${DATADIR}/qualitaet_l-orig
	cd ${DATADIR} && \
	    $(PERL) -I${BBBIKEDIR} -I${BBBIKEDIR}/lib \
		-MStrassen::Core -MTie::File -MFcntl=O_RDONLY \
		-e 'for my $$file (qw(qualitaet_s-orig qualitaet_l-orig)) {\
			tie @l, "Tie::File", $$file, mode => O_RDONLY or \
		    	    die qq{Cannot open $$file: $$!};\
			for my $$i (1 .. $$#l) {\
			    if ($$l[$$i-1] =~ /\#:\s+unverified_by\s+(.*?):?\s*$$/i) {\
				my $$comment = "laut $$1";\
				my $$x = Strassen::parse($$l[$$i]);\
				$$x->[Strassen::NAME()] .= " " if $$x->[Strassen::NAME()] ne "";\
				$$x->[Strassen::NAME()] .= "($$comment)";\
				$$x->[Strassen::CAT()] = "?";\
				print Strassen::arr2line2($$x),"\n"\
			    }\
			}\
		    }' > /tmp/other-source-fragezeichen-orig
	${CONVERT2HAFAS} -basefile ${DATADIR}/qualitaet_s-orig /tmp/other-source-fragezeichen-orig > $@
	@rm -f /tmp/other-source-fragezeichen-orig

PREFIXMAP=sperr=SP,kopfstein=KP,qualität=QU,mäßig.geeignet=QU,radweg=RW,benutzungspflich=RW,bau=BA,vorfahrt=VF,name=NA,bezeichn=NA,vorfahrt=VF,ampel=AM

${PERSISTENTTMPDIR}/all-upload-fragezeichen.wpt:	fragezeichen Makefile
	${PERL} ${MISCSRCDIR}/bbd2gpsman.pl -filter nearby=200 \
	    -prefix XXX -match name \
	    -prefixmap ${PREFIXMAP} \
	    -symbol danger < fragezeichen > $@
	@echo gpsman with file $@

.PHONY: /tmp/upload-restricted-fragezeichen.wpt

/tmp/upload-restricted-fragezeichen.wpt:	fragezeichen
	@if [ "${RESTRICT_BBOX}" = "" ]; then \
	    echo Please define RESTRICT_BBOX in make line; \
	    false; \
	else \
	    true; \
	fi
	${PERL} ${MISCSRCDIR}/restrict_bbd_data.pl \
	    ${RESTRICT_BBOX:C/(^| )/ -bbox /g} \
	    -strdata $> -o - | \
	${PERL} ${MISCSRCDIR}/bbd2gpsman.pl -filter nearby=200 \
	    -prefix XXX -match name \
	    -prefixmap ${PREFIXMAP} \
	    -symbol danger > $@
	@echo gpsman with file $@

# The both bboxes are: Potsdam and central Berlin (Mitte,
# Friedrichshain, Kreuzberg)
${PERSISTENTTMPDIR}/my-upload-fragezeichen.wpt:	fragezeichen Makefile
	${MAKE} /tmp/upload-restricted-fragezeichen.wpt \
	    RESTRICT_BBOX="-8250,2025,-15000,-2675 16500,15375,4625,5984 26687,-316,9090,9005"
	cp -pf /tmp/upload-restricted-fragezeichen.wpt $@

temp_blockings/bbbike-temp-blockings-optimized.pl:	temp_blockings/bbbike-temp-blockings.pl .check_bbbike-temp-blockings-optimized
	-@$(WRITEABLE) $@
	${PERL} $(MISCSRCDIR)/check_bbbike_temp_blockings \
	    -action output_future_nonpermanent \
	    -action dump_future_as_perl > $@
	touch .check_bbbike-temp-blockings-optimized
	-@$(READONLY) $@

# XXX Optimierungsmöglichkeit: aus "fragezeichen" alle Strecken herausnehmen, die bereits auf Strecken in strassen+landstrassen matchen
# XXX vielleicht umbenennen: fragezeichen-approx-matches.bbd oder so
${PERSISTENTTMPDIR}/fragezeichen-matches.bbd:	fragezeichen ${DATADIR}/strassen ${DATADIR}/landstrassen ${DATADIR}/landstrassen2
	${PERL} $(MISCRSRCDIR)/match_bbd_data -incatrx . -v fragezeichen ${DATADIR}/strassen ${DATADIR}/landstrassen ${DATADIR}/landstrassen2 > /tmp/fragezeichen-matches.bbd
	mv /tmp/fragezeichen-matches.bbd ${PERSISTENTTMPDIR}/fragezeichen-matches.bbd


######################################################################
# CHECKS

# allow one error, and fail if the 2nd one is encountered
FOREVER_INTERVAL?=	30
FOREVER_TWO_ERRORS=	perl -MFcntl=:flock -e  'open LOCK, ">", ".check_forever.lck" or die $$!; flock LOCK, LOCK_EX|LOCK_NB or die $$!; @cmd=@ARGV; while() { system(@cmd); exit 2 if $$? == 2; $$count = $$? == 0 ? 0 : $$count+1; exit 1 if $$count >= 2; sleep $(FOREVER_INTERVAL) } unlink ".check_forever.lck"'

# Specify ADDITIONAL_CHECK_FOREVER_TARGETS make variable on command
# line for more things to do...
check-forever:
	-nice ${FOREVER_TWO_ERRORS} ${MAKE} check all ${PERSISTENTTMPDIR}/fragezeichen-outdoor-nextcheck.bbd ${ADDITIONAL_CHECK_FOREVER_TARGETS}
	@-alarm -nicedown
	@-xterm-conf -deiconify -raise
	xmessage "check-forever failed"

# Like check-forever, but build first, then check (all calls the check target)
all-forever:
	-nice ${FOREVER_TWO_ERRORS} ${MAKE} all
	@-alarm -nicedown
	@-xterm-conf -deiconify -raise
	xmessage "all-forever failed"

.OPTIONAL: .check_bbbike-temp-blockings-optimized

# It is legal for fragezeichen points to not be on strassen, so this is
# only informative...
check-fragezeichen:	/tmp/check-fragezeichen.bbd \
			/tmp/inaccessible-fragezeichen.bbd

/tmp/check-fragezeichen.bbd: fragezeichen strassen landstrassen landstrassen2
	${CHECK_POINTS} -warn -report fragezeichen strassen landstrassen landstrassen2 > $@

# This collects *all* inaccessible points, not only for fragezeichen
/tmp/inaccessible-fragezeichen.bbd: fragezeichen strassen landstrassen landstrassen2
	${SEARCH_INACCESSIBLE} -street strassen,landstrassen,landstrassen2,fragezeichen > $@

force_check: remove_checks check

remove_checks:
	rm -f .check_* .create_* .doublecheck_*

# checks
check:	report-checks do-checks

check-harder: check do-doublechecks

report-checks:
	@echo Now doing checks...

do-checks:	.check_empty_lines \
	.check_strassen1 .check_strassen2 .check_strassen_potsdam .check_strassen_cont .check_strassen_consecutive \
	.check_plaetze1 .check_plaetze2 .check_strassen_plaetze_unique \
	.check_hoehe .check_hoehe2 \
	.check_ampeln .check_ampeln2 \
	.check_gesperrt1 .check_gesperrt2 \
	.check_gesperrt_u2 .check_gesperrt_s2 .check_gesperrt_r2 \
	.check_gesperrt_car1 .check_gesperrt_car2 \
	.check_ubahnhof .check_ubahnhof2 .check_sbahnhof .check_sbahnhof2 \
	.check_rbahnhof .check_orte \
	.check_radwege .check_radwege2 \
	.check_ampelschaltung \
	.check_qualitaet_s .check_qualitaet_l .check_qualitaet2 \
	.check_handicap_s .check_handicap_l .check_handicap2 \
	.check_vorfahrt \
	.check_comments1 .check_comments2 .check_comments3 \
	.check_nolighting .check_nolighting2 \
	.check_housenumbers .check_sehenswuerdigkeit \
	.check_green .check_green2 \
	.check_brunnels .check_brunnels2 \
	.check_comments_ferry .check_comments_route \
	.check_comments_cyclepath_2 .check_comments_danger_2 \
	.check_comments_ferry_2 .check_comments_mount_2 \
	.check_comments_tram_2 .check_comments_kfzverkehr_2 \
	.check_comments_scenic_2 \
	.check_exits \
	.check_temp_blockings .check_grenzuebergaenge \
	.check_berlin .check_potsdam \
	.check_ortsschilder .check_ortsschilder2

.check_empty_lines:	*-orig
	for i in *-orig; do $(PERL) -nle '$$_ eq q{} and die $$ARGV' $$i; done

# check disabled targets
check-disabled:

.check_targets:	${BBD_TARGETS}
	${PERL} ${MISCSRCDIR}/check_bbd ${BBD_TARGETS}
	@touch $@

.check_strassen1:	.strassen.tmp add_str multi_bez_str-orig Berlin.coords.data
	$(CHECK_STR_PLZ) -data .strassen.tmp
	@touch $@

.check_strassen2:	strassen landstrassen landstrassen2
	$(CHECK_DOUBLE) -special strassen -linesegs strassen landstrassen landstrassen2
	@touch $@

.check_strassen_potsdam:	landstrassen add_str_potsdam Potsdam.coords.data
	-rm /tmp/potsdam-strassen
	${GREPSTRASSEN} --namerx ' \(Potsdam\)' landstrassen | perl -pe 's/\s+\(B\d+\)//' > /tmp/potsdam-strassen
	${CHECK_STR_PLZ} -addstr add_str_potsdam -ignoreplzwarnings -plzdata Potsdam.coords.data -data /tmp/potsdam-strassen
	rm /tmp/potsdam-strassen
	@touch $@

.check_strassen_cont:	.strassen.tmp str_cont_ausnahme
	$(CHECK_CONT) -data .strassen.tmp
	@touch $@

.check_strassen_consecutive: strassen
	@${PERL} -nle '\
	    next if /^(#|\()/; m{([^\t]+)} and do {\
		if ($$1 ne $$last && $$seen{$$1}) {\
		    if (!$$error_header_printed) {\
			print "*** The following streets are not consecutive in strassen";\
			$$error_header_printed = 1;\
		    }\
		    print "$$1";\
		}\
		$$last = $$1;\
		$$seen{$$1}++;\
	    };\
	    END { exit 1 if $$error_header_printed }\
	' strassen
	@touch $@

.check_plaetze1: plaetze .strassen.tmp landstrassen
	$(CHECK_POINTS) -catrx '^Pl$$' plaetze .strassen.tmp landstrassen
	@touch $@

.check_plaetze2: ${PERSISTENTTMPDIR}/non-faked-plaetze add_plaetze
	$(CHECK_STR_PLZ) -addstr add_plaetze -data ${PERSISTENTTMPDIR}/non-faked-plaetze -nomultibez
	@touch $@

.check_strassen_plaetze_unique:	strassen-orig plaetze-orig
	${CUT} -d"	" -f1 strassen-orig | sort -u > /tmp/strassen-names
	${CUT} -d"	" -f1 plaetze-orig  | sort -u > /tmp/plaetze-names
	duplicates=`sort /tmp/strassen-names /tmp/plaetze-names | grep -v '^#' | $(NO_LOCALE) uniq -d`; \
	if [ "$$duplicates" != "" ]; then \
	    echo "Found duplicates:"; \
	    echo "$$duplicates"; \
	    false; \
	fi
	@rm -f /tmp/strassen-names /tmp/plaetze-names
	@touch $@

.check_hoehe:	hoehe .strassen.tmp landstrassen landstrassen2 fragezeichen
	$(CHECK_POINTS) -catrx '^(X|\?|\?\?\?)$$' -namerx '^\d+(\.\d+)?$$' hoehe .strassen.tmp landstrassen landstrassen2 fragezeichen
	@touch $@

.check_hoehe2:	hoehe
	$(CHECK_DOUBLE) -points hoehe
	@touch $@

.check_ampeln:	ampeln .strassen.tmp landstrassen landstrassen2 fragezeichen
	$(CHECK_POINTS) -catrx '^(X|F|B|B0|Zbr|\?)(::inwork)?$$' ampeln .strassen.tmp landstrassen landstrassen2 fragezeichen
	@touch $@

.check_ampeln2:	ampeln
	$(CHECK_DOUBLE) -points ampeln
	@touch $@

# XXX not executed by default
.check_bahnuebergaenge: ampeln ubahn sbahn rbahn
	${GREPSTRASSEN} --catrx '^B' ampeln > /tmp/bahnuebergaenge
	${CHECK_POINTS} /tmp/bahnuebergaenge ubahn sbahn rbahn
	@touch $@

.check_ampelschaltung:	ampelschaltung-orig ampeln-orig
	$(CHECK_POINTS) -ampelschaltung ampelschaltung-orig ampeln-orig
	@touch $@

.check_ortsschilder:	ortsschilder .strassen.tmp landstrassen landstrassen2 fragezeichen
	$(CHECK_POINTS) -catrx '^OS$$' ortsschilder .strassen.tmp landstrassen landstrassen2 fragezeichen
	@touch $@

.check_ortsschilder2:	orte orte2 ortsschilder
	perl -MData::Dumper -I.. -I../lib -MStrassen::Core -e 'for $$o (qw(orte orte2)) { Strassen->new_stream($$o)->read_stream(sub { $$seen{$$_[0]->[0]}++; for (@{ $$_[1]->{alias} || [] }) { $$seen{$$_ }++ } }, UseLocalDirectives => 1) }; Strassen->new_stream("ortsschilder")->read_stream(sub { $$seen{$$_[0]->[0]}++ or $$error{$$_[0]->[0]}++ }); if (%error) { die Dumper(\%error) }' 
	@touch $@

# Interactive test
.check_ortsschilder_dist:	orte orte2 ortsschilder
	perl -Mopen=:locale  -MData::Dumper -I.. -I../lib -MStrassen::Util -MStrassen::Core -e 'for $$o (qw(orte orte2)) { Strassen->new_stream($$o)->read_stream(sub { $$pos{$$_[0]->[0]} = $$_[0]->[1][0]; $$cat{$$_[0]->[0]} = $$_[0]->[2] }) }; Strassen->new_stream("ortsschilder")->read_stream(sub { $$pos = $$_[0]->[1][0]; print int(Strassen::Util::strecke_s($$pos, $$pos{$$_[0]->[0]})) . " " . $$cat{$$_[0]->[0]} . " " . $$_[0]->[0] . "\n" }) ' | sort -nr | less

# XXX Information duplicated in Strassen::Cat
GESPERRT_CATRX='^(0:\d+(:-?\d+)?|1|1s(:q\d)?|2|3|3nocross|BNP:\d+(:-?\d+(:trailer=(no|\d+))?)?)(:inwork)?(::(igndisp|ignrte))?$$'

.check_gesperrt1:	gesperrt .strassen.tmp landstrassen landstrassen2 fragezeichen routing_helper-orig
	$(CHECK_POINTS) -catrx $(GESPERRT_CATRX) gesperrt .strassen.tmp landstrassen landstrassen2 fragezeichen routing_helper-orig
	@touch $@

# Second check is necessary because of the 3nocross entries!
# For the second check we could do a "grepstrassen -cat 3nocross" first
.check_gesperrt2:	gesperrt strassen landstrassen landstrassen2 fragezeichen
	$(CHECK_NEIGHBOUR) -type standard -data gesperrt \
		-against strassen -against landstrassen -against landstrassen2 -against fragezeichen
	$(CHECK_NEIGHBOUR) -type standard -data gesperrt-orig \
		-against strassen -against landstrassen -against landstrassen2 -against fragezeichen
	@touch $@

.for i in u s r
.check_gesperrt_$(i)2:	gesperrt_$(i) $(i)bahn
	$(CHECK_NEIGHBOUR) -type standard -data gesperrt_$(i) \
		-against $(i)bahn
	@touch $@
.endfor

# no need to check -catrx $(GESPERRT_CATRX) --- this is done elsewhere
.check_gesperrt_car1:	gesperrt_car .strassen.tmp landstrassen landstrassen2
	$(CHECK_POINTS) gesperrt_car .strassen.tmp landstrassen landstrassen2
	@touch $@

.check_gesperrt_car2:	gesperrt_car strassen landstrassen landstrassen2
	$(CHECK_NEIGHBOUR) -type standard -data gesperrt_car \
		-against strassen -against landstrassen -against landstrassen2
	@touch $@

.check_ubahnhof:	ubahnhof ubahn
	$(CHECK_STATION_CATEGORY) -special noinwork ubahnhof-orig ubahn
	@touch $@

.check_sbahnhof:	sbahnhof sbahn
	$(CHECK_STATION_CATEGORY) -special noinwork sbahnhof-orig sbahn
	@touch $@

.for i in u s
.check_$(i)bahnhof2:	$(i)bahnhof Berlin.coords.data
	grep -i '	$(i)[AB] ' $(i)bahnhof |\
	    $(SED) -e 's/ *(.*)//' -e 's/	.*//' -e 's/bhf\./bahnhof/' -e 's/Bhf\./Bahnhof/' |\
	    $(SORT_GERMAN_LOCALE) -u > /tmp/$(i)bahnhof1
	grep -i '^$(i)-Bhf' Berlin.coords.data |\
	    egrep -v 'S-Bhf (Fürstenbrunn)' |\
	    $(SED) -e 's/ *(.*)//' -e 's/S-Bhf //' -e 's/U-Bhf //' -e 's/|.*//' |\
	    $(SORT_GERMAN_LOCALE) -u > /tmp/$(i)bahnhof2
	diff /tmp/$(i)bahnhof1 /tmp/$(i)bahnhof2
	@rm -f /tmp/$(i)bahnhof1 /tmp/$(i)bahnhof2
	@touch $@
.endfor

.check_rbahnhof:	rbahnhof rbahn
	$(CHECK_STATION_CATEGORY) -special noinwork rbahnhof-orig rbahn
	@touch $@

.check_orte: orte orte2 orte_city
	$(CHECK_DOUBLE) -names orte orte2 orte_city
	@touch $@

.check_radwege:	radwege_exact strassen
	$(CHECK_NEIGHBOUR) -type standard -data radwege_exact
	@touch $@

.check_radwege2: radwege
	$(CHECK_DOUBLE) -linesegs radwege || (\
	    echo "Note: please check the generated radwege, not radwege-orig, but fix in radwege-orig!"; \
	    exit 1 \
	)
	@touch $@

.check_qualitaet_s:	qualitaet_s strassen fragezeichen ${PERSISTENTTMPDIR}/strassen_in_planung.bbd
	$(CHECK_NEIGHBOUR) -type standard -data qualitaet_s \
		-against strassen -against fragezeichen \
		-against ${PERSISTENTTMPDIR}/strassen_in_planung.bbd
	@touch $@

.check_qualitaet_l:	qualitaet_l landstrassen landstrassen2
	$(CHECK_NEIGHBOUR) -type standard -data qualitaet_l \
		-against landstrassen -against landstrassen2
	@touch $@

.check_qualitaet2:	qualitaet_s qualitaet_l
	$(CHECK_DOUBLE) -linesegs qualitaet_s qualitaet_l
	@touch $@

.check_handicap_s:	handicap_s strassen
	$(CHECK_NEIGHBOUR) -type standard -data handicap_s
	@touch $@

.check_handicap_l:	handicap_l landstrassen landstrassen2
	$(CHECK_NEIGHBOUR) -type standard -data handicap_l \
		-against landstrassen -against landstrassen2
	@touch $@

.check_handicap2:	handicap_s handicap_l
	$(CHECK_DOUBLE) -linesegs handicap_s handicap_l
	@touch $@

.check_vorfahrt:	vorfahrt strassen landstrassen landstrassen2 fragezeichen
	$(CHECK_NEIGHBOUR) -type standard -data vorfahrt \
		-against strassen -against landstrassen -against landstrassen2 \
		-against fragezeichen
	$(CHECK_COUNT) -type vorfahrt -data vorfahrt
	@touch $@

.for i in $(COMMENTS_PARTIAL)
.check_comments1:	.check_${i}_1

.check_${i}_1:	$i .strassen.tmp landstrassen landstrassen2 faehren fragezeichen
	$(CHECK_POINTS) $i .strassen.tmp landstrassen landstrassen2 faehren fragezeichen
	@touch $@

.endfor

.check_comments2:	$(COMMENTS_PARTIAL) strassen landstrassen landstrassen2 faehren fragezeichen
	$(CHECK_NEIGHBOUR) -type standard \
	    -against strassen -against landstrassen -against landstrassen2 \
	    -against faehren -against fragezeichen \
	    ${COMMENTS_PARTIAL:S/^/-data /g}
	@touch $@

.check_comments3:	$(COMMENTS_PARTIAL);
	@$(PERL) -I../lib -I.. -MStrassen::Core -MObject::Iterate=iterate -e '\
	for $$file (@ARGV) {\
	    $$s=Strassen->new($$file);\
	    iterate {\
		$$_->[Strassen::CAT] =~ m{^CP2;} and @{$$_->[Strassen::COORDS]} != 2 and push @errors, "*** $$file ($$_->[Strassen::NAME]): CP2; != 2 coordinates";\
		$$_->[Strassen::CAT] =~ m{^PI;} and @{$$_->[Strassen::COORDS]} < 3 and push @errors, "*** $$file ($$_->[Strassen::NAME]): PI; too few coordinates";\
		$$_->[Strassen::CAT] =~ m{^CP(;|$$)} and @{$$_->[Strassen::COORDS]} < 3 and push @errors, "*** $$file ($$_->[Strassen::NAME]): CP; too few coordinates";\
		$$_->[Strassen::CAT] =~ m{^P0} and push @errors, "*** $$file ($$_->[Strassen::NAME]): P0 is unsupported";\
	    } $$s;\
        }\
	die join "", @errors if @errors;\
	' $(COMMENTS_PARTIAL)
	@touch $@

.check_comments_ferry:	comments_ferry faehren
	$(CHECK_NEIGHBOUR) -type standard -against faehren -data comments_ferry
	@touch $@

.check_comments_route: comments_route strassen landstrassen landstrassen2 comments_ferry fragezeichen fragezeichen-orig
	$(CHECK_NEIGHBOUR) -type standard \
	    -against strassen \
	    -against landstrassen \
	    -against landstrassen2 \
	    -against comments_ferry \
	    -against fragezeichen \
	    -against fragezeichen-orig \
	    -data comments_route
	@touch $@

.for i in cyclepath danger ferry mount tram kfzverkehr scenic
.check_comments_$(i)_2:	comments_$(i)
	$(CHECK_DOUBLE) -linesegs comments_$(i)
	@touch $@
.endfor

.check_nolighting:	nolighting strassen landstrassen
	$(CHECK_NEIGHBOUR) -type standard -against strassen -against landstrassen -data nolighting
	@touch $@

.check_nolighting2:	nolighting
	$(CHECK_DOUBLE) -linesegs nolighting
	@touch $@

.check_housenumbers:	housenumbers-orig housenumbers .strassen.tmp
	$(CHECK_HOUSENUMBERS) housenumbers-orig
	$(CHECK_POINTS) -catrx '^HNR$$' -namerx '^(ALT|SINGLE|CONT) (\d+[a-z]?)?/(\d+[a-z]?)? (\d+[a-z]?)?/(\d+[a-z]?)?$$' housenumbers .strassen.tmp
	@touch $@

.check_sehenswuerdigkeit:	sehenswuerdigkeit
	$(CHECK_IMAGES) sehenswuerdigkeit
	@touch $@

.check_green:	green strassen landstrassen
	$(CHECK_NEIGHBOUR) -type standard -data green \
		-against strassen -against landstrassen
	@touch $@

.check_green2:	green
	$(CHECK_DOUBLE) -linesegs green
	@touch $@

.check_brunnels:	brunnels strassen landstrassen landstrassen2 wasserstrassen wasserumland wasserumland2 fragezeichen
	$(CHECK_NEIGHBOUR) -type standard -data brunnels \
	    -against strassen -against landstrassen -against landstrassen2 \
	    -against wasserstrassen -against wasserumland -against wasserumland2 \
	    -against fragezeichen
	@touch $@

.check_brunnels2:	brunnels
	$(CHECK_DOUBLE) -linesegs brunnels
	@touch $@

.check_exits:	exits \
		ubahnhof sbahnhof rbahnhof \
		.strassen.tmp landstrassen landstrassen2
	$(PERL) -I../lib -I.. -MStrassen::Core -MObject::Iterate=iterate -e '\
	$$s=Strassen->new(q{exits});\
	$$new_s=Strassen->new;\
	iterate {\
	    $$_->[Strassen::COORDS] = [@{$$_->[Strassen::COORDS]}[0, -1]];\
	    $$new_s->push($$_);\
	} $$s;\
	print $$new_s->as_string' > /tmp/exits-first-last
	$(CHECK_POINTS) /tmp/exits-first-last \
		ubahnhof sbahnhof rbahnhof \
		.strassen.tmp landstrassen landstrassen2
	@rm -f /tmp/exits-first-last
	@touch $@

.check_temp_blockings:	temp_blockings/*.bbd $(PERSISTENTTMPDIR)/bbbike-temp-blockings.bbd \
			strassen landstrassen landstrassen2 faehren
	cat temp_blockings/*.bbd > /tmp/all_temp_blockings.bbd
	cat $(PERSISTENTTMPDIR)/bbbike-temp-blockings.bbd >> /tmp/all_temp_blockings.bbd
	$(CHECK_NEIGHBOUR) -type standard -data /tmp/all_temp_blockings.bbd \
		-against strassen -against landstrassen -against landstrassen2 \
		-against faehren
	@rm -f /tmp/all_temp_blockings.bbd
	@touch $@

.check_grenzuebergaenge:	grenzuebergaenge .strassen.tmp landstrassen landstrassen2 fragezeichen deutschland
	$(CHECK_POINTS) -catrx '^GU$$' grenzuebergaenge .strassen.tmp landstrassen landstrassen2 fragezeichen
	$(CHECK_POINTS) grenzuebergaenge deutschland
	@touch $@

.for city in berlin potsdam
.check_$(city):	$(city)
	grep -v '^#' $(city) | perl -nle '$$line++; END { die "Expected exactly one line" if $$line != 1 }'
	@touch $@
.endfor

.check_add_str:	strassen add_str Berlin.coords.data
	false
	@touch $@

# For adjusting the buffer in BBBikeXS.xs.
# Please adjust the number according to MAXBUF and MAXPOINTS in BBBikeXS.xs.
check-line-lengths:	.check_line_lengths

.check_line_lengths:	$(TARGETS)
	MAXLEN=`for i in $(TARGETS); do \
	    $(PERL) -nle '$$max = length($$_) if length($$_) > $$max; END { print $$max }' < $$i; \
	done | sort -nr | head -1`; \
	[ $$MAXLEN -lt 12288 ] || ( echo $$MAXLEN; exit 1 )
	MAXPOINTS=`for i in $(TARGETS); do \
	    $(PERL) -nle '$$points = scalar split / /; $$max = $$points if $$points > $$max; END { print $$max }' < $$i; \
	done | sort -nr | head -1`; \
	[ $$MAXPOINTS -lt 1024 ] || ( echo $$MAXPOINTS; exit 1 )
	@touch $@

count-streets:
	@echo -n "Berlin:        "; grep -v "^(" strassen | ${CUT} -f1 -d"(" | sort -u | wc -l
	@echo -n "Landstraßen:   "; grep -v "^#" landstrassen landstrassen2 | ${CUT} -f1 | sort -u | wc -l
	@echo -n "  Potsdam:     "; fgrep "(Potsdam)" landstrassen | grep -v "^(" | ${CUT} -f1 -d"(" | sort -u | wc -l
	@echo -n "  Oranienburg: "; grep -v "^#" landstrassen | fgrep "(Oranienburg" | ${CUT} -f1 -d"(" | sort -u | wc -l

check-dates:	.check_dates

.check_dates:	*-orig ${MISCSRCDIR}/check_dates
	@(echo "Expired today (`date`)": ;\
	 ${PERL_UTF8} ${MISCSRCDIR}/check_dates *-orig ;\
	 echo "Expired in the next two weeks:" ;\
	 ${PERL_UTF8} ${MISCSRCDIR}/check_dates -reldays 14 *-orig ) 2>&1 | tee $@~
	mv $@~ $@

check-crossings:	check-crossings-important \
			check-crossings-less-important

.PRECIOUS:	${PERSISTENTTMPDIR}/crossings.bbd \
		${PERSISTENTTMPDIR}/crossings_gewaesser.bbd \
		${PERSISTENTTMPDIR}/crossings_bahn.bbd \
		${PERSISTENTTMPDIR}/crossings_gewaesser_ignore.bbd

check-crossings-important:	${PERSISTENTTMPDIR}/crossings.bbd

check-crossings-less-important:	${PERSISTENTTMPDIR}/crossings_gewaesser.bbd \
				${PERSISTENTTMPDIR}/crossings_bahn.bbd \
				${PERSISTENTTMPDIR}/crossings_gewaesser_ignore.bbd

check-categories:	.check_categories

.check_categories:	${BBD_TARGETS}
	@echo "Check categories..."
.for target in ${BBD_TARGETS}
	@echo " ${target}"
	@$(PERL_UTF8) -I../lib -I.. -MStrassen::Cat -e '\
	    exit !Strassen::Cat::check_file($$ARGV[0], BBBikeVersion => "3.16");\
	' ${target}
.endfor
	touch $@

check-names:	.check_names

.check_names:	${BBD_TARGETS}
	@echo "Check names..."
.for target in ${BBD_TARGETS}
	@echo " ${target}"
	@$(PERL_UTF8) -I../lib -I.. -MStrassen::Core -e '\
	    Strassen->new_stream(shift)->read_stream(sub { \
		die qq{Whitespace in "$$_[0]->[Strassen::NAME]"} \
		    if $$_[0]->[Strassen::NAME] =~ m{(^\s|\s$$)} \
	    })' ${target}
.endfor
	touch $@

${PERSISTENTTMPDIR}/crossings.bbd:	strassen landstrassen landstrassen2 \
					brunnels
	${PERL} ${MISCSRCDIR}/check_crossings -v-if-interactive \
	    -o $@~ -against brunnels \
	    strassen landstrassen landstrassen2
	mv $@~ $@

# XXX überirdische U-Bahnen?
# XXX Andreaskreuz
${PERSISTENTTMPDIR}/crossings_bahn.bbd:	strassen sbahn rbahn brunnels
	${PERL} ${MISCSRCDIR}/check_crossings -v-if-interactive \
	    -o $@~ -against brunnels \
	    strassen sbahn rbahn
	mv $@~ $@

# Note also the empty string in the -ignore option!
${PERSISTENTTMPDIR}/crossings_gewaesser.bbd:	\
					strassen wasserstrassen brunnels
	${PERL} ${MISCSRCDIR}/check_crossings -v-if-interactive \
	    -ignore "Fasaneriegraben,Packereigraben,Tränkegraben,Kraatzgraben,Teufelsseekanal,(See im Tiergarten),,Luiseninsel,Fennpfuhl,Heidekampgraben,Karpfenteich,Panke,Nordgraben,Tegeler Fließ,Hermsdorfer See,Wuhle,Neue Wuhle,Flutgraben,Kreuzgraben,Zingergraben,Iderfenngraben,Bäke,Bullengraben,Spektegraben,Bruchstückengraben,Fredersdorfer Mühlenfließ,Neuenhagener Mühlenfließ,Plumpengraben,Kleiner Jürgengraben,Rudower Fließ,Grützmachergraben" \
	    -o $@~ -against brunnels \
	    strassen wasserstrassen
	mv $@~ $@

${PERSISTENTTMPDIR}/crossings_gewaesser_ignore.bbd:	\
					strassen wasserstrassen brunnels
	${PERL} ${MISCSRCDIR}/check_crossings -v-if-interactive \
	    -o $@~ -against brunnels \
	    strassen wasserstrassen
	mv $@~ $@

######################################################################
# Checks for unhandled streets
BERLIN_PLZ_RANGES=10 12 13 14

unhandled-streets:	${BERLIN_PLZ_RANGES:S/^/${PERSISTENTTMPDIR}\/unhandled_streets_/:S/$/XXX.bbd/}

${PERSISTENTTMPDIR}/naked-fragezeichen:	fragezeichen-orig
	${REPLACESTRASSEN} -nameexpr 's{:.*}{}' < fragezeichen-orig > ${PERSISTENTTMPDIR}/naked-fragezeichen~
	mv ${PERSISTENTTMPDIR}/naked-fragezeichen~ ${PERSISTENTTMPDIR}/naked-fragezeichen

.for plz in ${BERLIN_PLZ_RANGES}
${PERSISTENTTMPDIR}/Berlin$(plz)XXX.coords.data:	Berlin.coords.data
	${PERL} -F'\|' -nale '$$F[2] =~ m{^$(plz)} and print' Berlin.coords.data |\
	    grep -v '[US]-Bhf ' | egrep -v ' \(Kolonie|Siedlung|Gaststätte|Insel|geplant\)' | egrep -v '^(Kolonie |KGA |Siedlung |Güterbahnhof )' \
		> ${PERSISTENTTMPDIR}/Berlin$(plz)XXX.coords.data~
	mv ${PERSISTENTTMPDIR}/Berlin$(plz)XXX.coords.data~ ${PERSISTENTTMPDIR}/Berlin$(plz)XXX.coords.data

${PERSISTENTTMPDIR}/unhandled_streets_$(plz)XXX.bbd:	${PERSISTENTTMPDIR}/Berlin$(plz)XXX.coords.data \
							strassen flaechen sehenswuerdigkeit brunnels \
							${PERSISTENTTMPDIR}/naked-fragezeichen
	-${CHECK_STR_PLZ} -plzdata ${PERSISTENTTMPDIR}/Berlin$(plz)XXX.coords.data -reversecheck \
		-data strassen -data flaechen -data sehenswuerdigkeit -data brunnels \
		-data ${PERSISTENTTMPDIR}/naked-fragezeichen > ${PERSISTENTTMPDIR}/unhandled_streets_$(plz)XXX.bbd~
	mv ${PERSISTENTTMPDIR}/unhandled_streets_$(plz)XXX.bbd~ ${PERSISTENTTMPDIR}/unhandled_streets_$(plz)XXX.bbd
.endfor

## Einzeiler zum Extrahieren einer Postleitzahl:
# perl -F'\|' -nale '$F[2] == 12489 and $F[3] and print "$F[0] $F[1]\tX $F[3]"' Berlin.coords.data > /tmp/12489.bbd

######################################################################

.ifdef .FreeBSD
check-coords.data:	check-Berlin.coords.data check-Potsdam.coords.data
.else
check-coords.data:
	@echo '*** check-coords.data target is only active under FreeBSD,'
	@echo '*** because of incompatible locale definitions'
.endif

.for city in Berlin Potsdam
check-$(city).coords.data:	.check_$(city)_coords_data

# Check for sortedness and unique records:
.check_$(city)_coords_data:: $(city).coords.data
	$(SORT_GERMAN_LOCALE) ${COORDS_DATA_SORT_OPTS} -c $(city).coords.data || \
	    ( $(SORT_GERMAN_LOCALE) ${COORDS_DATA_SORT_OPTS} $(city).coords.data | diff -u - $(city).coords.data; false )
	$(PERL) -nle '@l=split /\|/;\
	    if (++$$x{"@l[0..2]"} > 1) { die "Duplicate: @l" }\
	    if (@l < 2 || @l > 4) { die "Too less/many fields: @l" }\
	    if ($$l[2] !~ /^(|\d{5})$$/) { die "Not a ZIP: @l" }\
	' $(city).coords.data
	@touch $@
.endfor

check-Berlin.coords.data: .check_Berlin_coords_data_cityparts \
			  .check_Berlin_coords_data_zip

.check_Berlin_coords_data_cityparts: Berlin.coords.data
	${CUT} -d'|' -f2 Berlin.coords.data | sort -u |\
	    $(PERL) -I.. -MGeography::Berlin_DE -nle \
		'BEGIN { %cp = map {($$_,1)} Geography::Berlin_DE->get_all_subparts } !exists $$cp{$$_} and die "<$$_> not a citypart of Berlin"'
	@touch $@

.check_Berlin_coords_data_zip: Berlin.coords.data
	${CUT} -d'|' -f3 Berlin.coords.data | sort -u |\
	    $(PERL) -nle '($$_ < 10000 || $$_ > 15000) and die "<$$_> unexpected ZIP in Berlin"'
	@touch $@

# Heavy check, fails for now:
.check_Berlin_coords_data_zip2: Berlin.coords.data
	unzip -c $(MISCDIR)/opengeodb/Berlin_I.zip D_Berlin_Postleitzahlen > /tmp/D_Berlin_Postleitzahlen
	cat /tmp/D_Berlin_Postleitzahlen |\
	    $(PERL) -nle '/^(\d{5}) .. (.*)/ && print "$$1 .. $$2"' |\
	    sort -u > /tmp/plz_opengeodb
	$(PERL) -I $(BBBIKEDIR) -MGeography::Berlin_DE -F'\|' -nale \
	    'BEGIN {$$g=Geography::Berlin_DE->new } print "$$F[2] .. " . $$g->get_supercitypart_for_any($$F[1]) ' Berlin.coords.data |\
	    sort -u > /tmp/plz_bbbike
# Ausnahmen (der Reihe nach):
# - Str. 106 (bei mir)
# - hinter dem Ringcenter (opengeodb, folgende ebenso)
# - Nähe S-Bhf. Landsberger Allee
# - Nähe Müller-Breslau-Str.
# - Alexandrinenstr.?
# - Insulaner
	diff -u \
	    -I'13088.*Lichtenberg' \
	    -I'10367.*Friedrichshain-Kreuzberg' \
	    -I'10407.*Friedrichshain-Kreuzberg' \
	    -I'10623.*Mitte' \
	    -I'10969.*Mitte' \
	    -I'12169.*Tempelhof-Schöneberg' \
	    /tmp/plz_opengeodb /tmp/plz_bbbike
	@touch $@

check-nearest:	${PERSISTENTTMPDIR}/check_nearest.bbd do-check-nearest

${PERSISTENTTMPDIR}/check_nearest.bbd:	strassen landstrassen landstrassen2 fragezeichen brunnels faehren \
					check_nearest_ignore
	${PERL} ${MISCSRCDIR}/check_nearest -ignore check_nearest_ignore \
		-asbbd \
		-strfile strassen \
		-strfile landstrassen \
		-strfile landstrassen2 \
		-strfile fragezeichen \
		-strfile brunnels \
		-strfile faehren \
		> $@~
	mv $@~ $@

do-check-nearest:	.check-do-check-nearest

.check-do-check-nearest:	${PERSISTENTTMPDIR}/check_nearest.bbd
	$(PERL) -I${BBBIKEDIR} -I${BBBIKEDIR}/lib \
	    -MStrassen -MObject::Iterate=iterate -e \
	    '$$s = Strassen->new($$ARGV[0]);\
	     iterate { ($$dist) = $$_->[Strassen::NAME] =~ /^\S+\s+(\d+)/; if ( $$dist < 20 ) { system "head", "${PERSISTENTTMPDIR}/check_nearest.bbd"; die "Distance $$dist m found. Please check and add to check_nearest_ignore, if necessary."; }; } $$s' ${PERSISTENTTMPDIR}/check_nearest.bbd

.if 0
GNUmakefile: Makefile $(MISCRSRCDIR)/b2gmake
	$(MISCRSRCDIR)/b2gmake < Makefile > GNUmakefile
	chmod ugo+r GNUmakefile

GNUmakefile.mapfiles: Makefile.mapfiles $(MISCRSRCDIR)/b2gmake
	$(MISCRSRCDIR)/b2gmake < Makefile.mapfiles > GNUmakefile.mapfiles
	chmod ugo+r GNUmakefile.mapfiles
.else
GNUmakefile: Makefile
	$(PERL) -e 'print qq{all:\n\t\@echo "*** Sorry, your make program is not supported."\n\t\@echo "*** Please try pmake from the BSD project."\n\t\@echo "*** You can get it from http://www.sourceforge.net/projects/srezic"\n\t\@echo "*** Debian users may install the pmake package."\n\t\@echo ""\n\t\@false\n}' > $@
.endif

######################################################################
# Misc helpers

show-used-directives:
	${PERL} -nle '/^#: ([^\s:]+)/ and print $$1' *-orig | sort -u

######################################################################
# Berlin.coords.data etc. targets

sort-coords.data:	sort-Berlin.coords.data sort-Potsdam.coords.data

.for city in Berlin Potsdam
sort-$(city).coords.data:
	[ "`uname`" = FreeBSD ] && true || (echo "Sorting probably not correct on `uname`"; false)
	-@$(WRITEABLE) $(city).coords.data~
	mv $(city).coords.data $(city).coords.data~
	$(SORT_GERMAN_LOCALE) ${COORDS_DATA_SORT_OPTS} < $(city).coords.data~ > $(city).coords.data
	@$(READABLE) $(city).coords.data
	touch .check_$(city)_coords_data
.endfor


######################################################################
# TEMPORARY BLOCKINGS LAYER

temp_blockings/bbbike-temp-blockings.yml: temp_blockings/bbbike-temp-blockings.pl
	$(TEMP_BLOCKINGS_TASKS) pl_to_yml $> $@~
	$(TEMP_BLOCKINGS_TASKS) cmp_pl_and_yml $> $@~
	mv -f $@~ $@
	@$(READABLE) $@

$(PERSISTENTTMPDIR)/bbbike-temp-blockings-optimized.yml: temp_blockings/bbbike-temp-blockings-optimized.pl
	$(TEMP_BLOCKINGS_TASKS) pl_to_yml $> $@~
	mv -f $@~ $@
	@$(READABLE) $@

$(PERSISTENTTMPDIR)/bbbike-temp-blockings.bbd: temp_blockings/bbbike-temp-blockings.yml
	$(TEMP_BLOCKINGS_TASKS) yml_to_bbd $> > $@~
	mv -f $@~ $@

$(PERSISTENTTMPDIR)/bbbike-temp-blockings-optimized.bbd: $(PERSISTENTTMPDIR)/bbbike-temp-blockings-optimized.yml
	$(TEMP_BLOCKINGS_TASKS) yml_to_nonpermanent_bbd $> > $@~
	mv -f $@~ $@

$(PERSISTENTTMPDIR)/bbbike-temp-blockings-permanent.bbd: $(PERSISTENTTMPDIR)/bbbike-temp-blockings-optimized.yml
	$(TEMP_BLOCKINGS_TASKS) yml_to_permanent_bbd $> > $@~
	mv -f $@~ $@

######################################################################
# This will be removed someday if convert_orig_to_bbd is good enough

do-doublechecks:	.doublecheck_strassen.tmp \
			.doublecheck_plaetze \
			.doublecheck_non-faked-plaetze \
			.doublecheck_wasserstrassen \
			.doublecheck_wasserumland \
			.doublecheck_wasserumland2 \
			.doublecheck_flaechen \
			.doublecheck_green \
			.doublecheck_brunnels \
			.doublecheck_landstrassen \
			.doublecheck_landstrassen2 \
			.doublecheck_strassen_bab \
			.doublecheck_sbahnhof \
			.doublecheck_rbahnhof \
			.doublecheck_ubahnhof \
			.doublecheck_faehren \
			.doublecheck_hoehe \
			.doublecheck_orte \
			.doublecheck_orte2 \
			.doublecheck_orte_city \
			.doublecheck_ampeln \
			.doublecheck_gesperrt_u \
			.doublecheck_gesperrt_s \
			.doublecheck_gesperrt_r \
			.doublecheck_handicap_s \
			.doublecheck_handicap_l \
			.doublecheck_sehenswuerdigkeit

.for file in flaechen green plaetze landstrassen2 sbahnhof rbahnhof ubahnhof faehren hoehe ampeln
.doublecheck_$(file): $(file)
	-rm /tmp/$(file)-XXX
	$(CONVERT2HAFAS) $(file)-orig > /tmp/$(file)-XXX
	diff -u $(file) /tmp/$(file)-XXX
	rm /tmp/$(file)-XXX
	touch $@
.endfor

.doublecheck_strassen.tmp:	.strassen.tmp
	-rm /tmp/strassen-XXX
	$(CONVERT2HAFAS) strassen-orig > /tmp/strassen-XXX
	diff -I '#: alias:' -u .strassen.tmp /tmp/strassen-XXX
	rm /tmp/strassen-XXX
	touch $@

.doublecheck_non-faked-plaetze: ${PERSISTENTTMPDIR}/non-faked-plaetze
	-rm /tmp/non-faked-plaetze-XXX
	${GREPSTRASSEN} -v -section "faked_plaetze" plaetze-orig | $(CONVERT2HAFAS) -map H > /tmp/non-faked-plaetze-XXX
	diff -I '^#: *$$' -u ${PERSISTENTTMPDIR}/non-faked-plaetze /tmp/non-faked-plaetze-XXX
	rm /tmp/non-faked-plaetze-XXX
	touch $@

.for file in wasserstrassen wasserumland
.doublecheck_$(file): $(file)
	-rm /tmp/$(file)-XXX
	$(CONVERT2HAFAS) $(file)-orig | $(SORTBYCAT) -ignore F:I > /tmp/$(file)-XXX
	diff -I '#: alias:' -u $(file) /tmp/$(file)-XXX
	rm /tmp/$(file)-XXX
	touch $@
.endfor

.doublecheck_wasserumland2: wasserumland2
	-rm /tmp/wasserumland2-XXX
	$(CONVERT2HAFAS) -unutf8ify wasserumland2-orig | $(SORTBYCAT) -ignore F:I > /tmp/wasserumland2-XXX
	diff -I '#: alias:' -u wasserumland2 /tmp/wasserumland2-XXX
	rm /tmp/wasserumland2-XXX
	touch $@

.doublecheck_brunnels: brunnels
	-rm /tmp/brunnels-XXX
	${GREPSTRASSEN} -v -preserveglobaldirectives -section 'S-Bahn' $> | $(CONVERT2HAFAS) -map H > /tmp/brunnels-XXX
	diff -u brunnels /tmp/brunnels-XXX
	rm /tmp/brunnels-XXX
	touch $@

.doublecheck_landstrassen: landstrassen plaetze
	-rm /tmp/landstrassen-XXX
	$(CONVERT2HAFAS) landstrassen-orig > /tmp/landstrassen-XXX
	${GREPSTRASSEN} --namerx ' \(Potsdam\)' plaetze >> /tmp/landstrassen-XXX
	diff -I '#: alias:' -u landstrassen /tmp/landstrassen-XXX
	rm /tmp/landstrassen-XXX
	touch $@

.doublecheck_strassen_bab: strassen_bab
	-rm /tmp/strassen_bab-XXX
	cat strassen_bab-orig |\
		${GREPSTRASSEN} -v -sectionrx "Autobahnen in Planung" -preserveglobaldirectives |\
	    $(CONVERT2HAFAS) -basefile strassen_bab-orig > /tmp/strassen_bab-XXX
	diff -u strassen_bab /tmp/strassen_bab-XXX
	rm /tmp/strassen_bab-XXX
	touch $@

.for file in orte orte2
.doublecheck_$(file): $(file)
	-rm /tmp/$(file)-XXX
	$(CONVERT2HAFAS) -unutf8ify $(file)-orig | $(SORTBYCAT) > /tmp/$(file)-XXX
	diff -I '#: alias:' -u $(file) /tmp/$(file)-XXX
	rm /tmp/$(file)-XXX
	touch $@
.endfor

.doublecheck_orte_city: orte_city
	-rm /tmp/orte_city-XXX
	$(CONVERT2HAFAS) orte_city-orig | $(SORTBYCAT) > /tmp/orte_city-XXX
	diff -I '#: alias:' -u orte_city /tmp/orte_city-XXX
	rm /tmp/orte_city-XXX
	touch $@

.for i in u s r
.doublecheck_gesperrt_$(i):	gesperrt_$(i)-orig $(i)bahn
	-rm /tmp/gesperrt_$(i)-XXX
	$(CONVERT2HAFAS) gesperrt_$(i)-orig | ${PERL} $(MISCSRCDIR)/check_dates -filter > /tmp/gesperrt_$(i)-XXX
	diff -I '#: alias:' -u gesperrt_$(i) /tmp/gesperrt_$(i)-XXX
	touch $@
.endfor

.for i in s l
.doublecheck_handicap_$(i):	handicap_$(i)-orig
	-rm /tmp/handicap_$(i)-XXX
	$(CONVERT2HAFAS) handicap_$(i)-orig > /tmp/handicap_$(i)-XXX
	diff -I '#:.*temporary' -I '::igndisp' -I '^#:$$' -u handicap_$(i) /tmp/handicap_$(i)-XXX
	rm /tmp/handicap_$(i)-XXX
	touch $@
.endfor

.doublecheck_sehenswuerdigkeit: sehenswuerdigkeit
	-rm /tmp/sehenswuerdigkeit-XXX
	${CONVERT2HAFAS} sehenswuerdigkeit-orig > /tmp/sehenswuerdigkeit-XXX
	diff -I '#: alias:' -I '#: section:' -u sehenswuerdigkeit /tmp/sehenswuerdigkeit-XXX
	rm /tmp/sehenswuerdigkeit-XXX
	touch $@

######################################################################

.include "Makefile.mapfiles"
.include "Makefile.garmin"
