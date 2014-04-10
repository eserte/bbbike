#
# This Makefile is only usable with a modern version of BSD make (also known
# as "pmake"). The source for pmake can be found at
#
#   http://www.sourceforge.net/projects/srezic
#
# (This is a slightly modified version of the original pmake as found in
# the FreeBSD sources)
#
# Debian users may use freebsd-make resp. fmake from the freebsd-buildutils
# package.

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

VALID_DATE?=		today

HAFAS2HAFAS=		${PERL} ${MISCSRCDIR}/hafas2hafas -strict
CONVERT2HAFAS=		${PERL} ${MISCSRCDIR}/convert2hafas -strict
CONVERT_ORIG_FILE=	${MISCSRCDIR}/convert_orig_to_bbd
CONVERT_ORIG=		${PERL} ${CONVERT_ORIG_FILE}
CONVERT_RADWEGE=	${PERL} ${MISCSRCDIR}/convert_radwege
CHECK_POINTS=		${PERL} ${MISCSRCDIR}/check_points
CHECK_STR_PLZ=		${PERL} ${MISCSRCDIR}/check_str_plz
CHECK_CONT=		${PERL} ${MISCSRCDIR}/check_cont
CHECK_DOUBLE=           ${PERL} ${MISCSRCDIR}/check_double
CHECK_NEIGHBOUR=	${PERL} ${MISCSRCDIR}/check_neighbour
CHECK_COUNT=		${PERL} ${MISCSRCDIR}/check_count
CHECK_HOUSENUMBERS=	${PERL} ${MISCSRCDIR}/check_housenumbers
CHECK_IMAGES=		${PERL} ${MISCSRCDIR}/check_images
CHECK_STATION_CATEGORY=	${PERL} ${MISCSRCDIR}/check_station_category
CHECK_COMMENTS=		${PERL} ${MISCSRCDIR}/check_comments
RESOLVE_STARS=		${PERL} ${MISCSRCDIR}/resolve_stars
SORTBYCAT=		${PERL} ${MISCSRCDIR}/sortbycat
SEARCH_INACCESSIBLE=	${PERL} ${MISCSRCDIR}/search_inaccessible_points
STEIGUNG_STAT=		${PERL} ${MISCSRCDIR}/steigung_stat
GREPSTRASSEN=		${PERL} ${MISCSRCDIR}/grepstrassen
GREPSTRASSEN_VALID=	${GREPSTRASSEN} -valid ${VALID_DATE} -preserveglobaldirectives
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
SOURCE_TARGETS+=	faehren hoehe orte orte2 orte_city ortsschilder
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
SOURCE_TARGETS+=	${COMMENTS_PARTIAL} fragezeichen exits
SOURCE_TARGETS+=	culdesac

# These do not have a -orig file of their own, or another type of source file
COMPUTED_TARGETS=	sbahnhof_bg ubahnhof_bg berlin berlin_ortsteile
COMPUTED_TARGETS+=	radwege_exact mount
COMPUTED_TARGETS+=	temp_blockings/bbbike-temp-blockings-optimized.pl
COMPUTED_TARGETS+=	wasserstrassen-lowres
COMPUTED_TARGETS+=	kneipen
COMPUTED_TARGETS+=	fragezeichen-cooked
COMPUTED_TARGETS+=	inaccessible_strassen inaccessible_landstrassen oldnames

# These are not computed, but useful mentioned here for fixing
# permissions
NON_TARGETS=		upgrade_scope_hint

INTERMEDIATE_TARGETS=	.strassen.tmp \
			${PERSISTENTTMPDIR}/gesperrt-with-handicaps \
			${PERSISTENTTMPDIR}/gesperrt-orig-valid \
			${PERSISTENTTMPDIR}/gesperrt-without-nocross \
			${PERSISTENTTMPDIR}/radwege-orig-valid

COOKED_TARGETS=		strassen-cooked landstrassen-cooked landstrassen2-cooked
TARGETS+=	${SOURCE_TARGETS} ${COOKED_TARGETS} ${COMPUTED_TARGETS}
BBD_TARGETS=	${TARGETS:S/^ampelschaltung$//:S/^temp_blockings\/bbbike-temp-blockings-optimized.pl//:S/^oldnames$//}

XXX_NON_OUTDOOR=	indoor prog checklater
XXX_TARGETS=		outdoor ${XXX_NON_OUTDOOR}

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

.if defined(AUTOMATED_TESTING) && ${AUTOMATED_TESTING}
CHECK_RECURRENCES_PREWARN_DAYS=		23
CHECK_RECURRING_TEMP_BLOCKINGS_TARGET=	.check_recurring_temp_blockings_automated
.else
CHECK_RECURRENCES_PREWARN_DAYS?=	30
CHECK_RECURRING_TEMP_BLOCKINGS_TARGET=	.check_recurring_temp_blockings
.endif

######################################################################
# META TARGETS

all:	targets data-images check .WAIT .modified .WAIT make_misc

# Some targets have to be rebuild once a day. These should depend on
# ".check_daily"
.BEGIN:
	@$(PERL) -e '$$_ = ".check_daily"; if (!-e $$_ || -M $$_ >= 1) { open my $$fh, ">", $$_ or die "Cannot touch $$_" }'

targets:	${TARGETS}

targets-clean:
	-mkdir /tmp/old-data
	-mkdir /tmp/old-tmp-data
	-mv -f ${INTERMEDIATE_TARGETS} /tmp/old-tmp-data/
	mv -f ${TARGETS} /tmp/old-data/

fix-permissions:
	for i in $(TARGETS) $(NON_TARGETS) temp_blockings/bbbike-temp-blockings.pl temp_blockings/*.bbd; do \
	     [ -e $$i ] && $(READABLE) $$i || echo "$$i does not exist, skip fix-permission task"; \
	done

# Useful checks, but normally too slow for a quick build
# XXX merge with sort-Berlin.coords.data rule below?
slow-checks:	check-categories \
		check-names \
		.check_targets \
		inaccessible_strassen inaccessible_landstrassen ${PERSISTENTTMPDIR}/inaccessible_landstrassen+fragezeichen \
		check-coords.data \
		persistent-tmp

persistent-tmp:	fragezeichen-outdoor \
		fragezeichen-outdoor-nextcheck \
		${PERSISTENTTMPDIR}/fragezeichen-indoor-nextcheck.bbd \
		${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd \
		${PERSISTENTTMPDIR}/fragezeichen-nextcheck.org \
		${PERSISTENTTMPDIR}/sourceid-current.yml \
		$(PERSISTENTTMPDIR)/sourceid-all.yml \
		${PERSISTENTTMPDIR}/Berlin.coords.bbd \
		${PERSISTENTTMPDIR}/Potsdam.coords.bbd \
		${PERSISTENTTMPDIR}/non-faked-plaetze \
		${PERSISTENTTMPDIR}/non-faked-strassen \
		${PERSISTENTTMPDIR}/XXX.bbd \
		${PERSISTENTTMPDIR}/plz-b.bbd \
		${PERSISTENTTMPDIR}/berlin-fragezeichen-poi.gpx \
		osm-watch-lists

rare-persistent-tmp:	\
		${PERSISTENTTMPDIR}/all-upload-fragezeichen.wpt \
		${PERSISTENTTMPDIR}/my-upload-fragezeichen.wpt \
		${PERSISTENTTMPDIR}/strassen_in_planung.bbd \
		${PERSISTENTTMPDIR}/projektierte_radstreifen.bbd

# popular targets
fragezeichen-outdoor-nextcheck:	${PERSISTENTTMPDIR}/fragezeichen-outdoor-nextcheck.bbd

fragezeichen-outdoor:		${PERSISTENTTMPDIR}/fragezeichen-outdoor.bbd

osm-watch-lists:	${PERSISTENTTMPDIR}/osm_watch_list \
			${PERSISTENTTMPDIR}/osm_watch_list_brandenburg

.for i in $(XXX_TARGETS)
persistent-tmp:	${PERSISTENTTMPDIR}/XXX-$(i).bbd
.endfor

# more checks, but even slower (about four minutes)
really-slow-checks:	check-nearest \
			check-crossings-important \
			check-urls \
			plz-test

plz-test:
	cd $(BBBIKEDIR) && prove t/plz.t

# this adds also "check-crossings-less-important", but the results of
# these checks there were never looked at, so really not important...
unimportant-slow-checks:	really-slow-checks \
				check-crossings-less-important

######################################################################
# DATA FILE TARGETS

######################################################################
# STRASSEN UND PLƒTZE
strassen:	.strassen.tmp plaetze routing_helper-orig
	-@$(WRITEABLE) $@
	cat .strassen.tmp > $@~
	${GREPSTRASSEN} -v --namerx ' \(Potsdam\)' plaetze >> $@~
	${GREPSTRASSEN} -ignoreglobaldirectives -ignorelocaldirectives -catrx . routing_helper-orig |\
	    ${REPLACESTRASSEN} -catexpr 's/.*/NN::igndisp/' >> $@~
	mv $@~ $@
	-@$(READONLY) $@

# XXX old rule, may be deleted some day
XXX-strassen-tmp-without-NH:
	$(CONVERT_ORIG) -keep-directive alias -keep-old-name -5y strassen-orig |\
	    ${REPLACESTRASSEN} -catexpr 's/NH/N/' > $@~
	mv .strassen.tmp~ .strassen.tmp

.strassen.tmp: strassen-orig .check_daily
	${GREPSTRASSEN_VALID} strassen-orig |\
	    $(CONVERT_ORIG) -keep-directive alias -keep-old-name -5y > .strassen.tmp~
	mv $@~ $@

.for f in ${COOKED_TARGETS}
_f_raw_${f}:=${f:S/-cooked$//}
$f:	${_f_raw_${f}} inaccessible_landstrassen
	-@${WRITEABLE} $@
	$(PERL) -I${BBBIKEDIR} -I${BBBIKEDIR}/lib -MStrassen -e \
	    '$$s = Strassen->new($$ARGV[0], UseLocalDirectives => 1); $$ina = Strassen->new($$ARGV[1]); $$s->new_with_removed_points($$ina)->write("-")' \
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
	${SEARCH_INACCESSIBLE} -street strassen -blocked gesperrt \
	    -blockedtype einbahn -blockedtype sperre \
	    > new.$@~
	@if [ -e $@ ] ; then \
	    diff -u $@ new.$@~ || \
		(echo "*** If this is OK, then"; echo "        rm $@"; echo "    and rerun make"; false); \
	fi
	mv new.$@~ $@
	-@$(READONLY) $@

inaccessible_landstrassen: strassen landstrassen landstrassen2 faehren gesperrt
	-@$(WRITEABLE) $@
	${SEARCH_INACCESSIBLE} -street strassen -street landstrassen \
	    -street landstrassen2 -street faehren -blocked gesperrt \
	    -blockedtype einbahn -blockedtype sperre \
	    > new.$@~
	@if [ -e $@ ] ; then \
	    diff -u $@ new.$@~ || \
		(echo "*** If this is OK, then"; echo "        rm $@"; echo "    and rerun make"; false); \
	fi
	mv new.$@~ $@
	-@$(READONLY) $@

${PERSISTENTTMPDIR}/inaccessible_landstrassen+fragezeichen: strassen landstrassen landstrassen2 faehren gesperrt fragezeichen inaccessible_landstrassen
	-@$(WRITEABLE) $@
	${SEARCH_INACCESSIBLE} -street strassen -street landstrassen \
	    -street landstrassen2 -street faehren -street fragezeichen -blocked gesperrt \
	    -blockedtype einbahn -blockedtype sperre \
	    > $@~
	@if diff inaccessible_landstrassen $@~ | grep '^>' ; then \
	    echo "Please make sure all non-ignored fragezeichen records are connected"; \
	    false; \
	fi
	mv $@~ $@
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
	$(CONVERT_ORIG) -keep-directive alias -unutf8ify landstrassen2-orig > $@~
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
	-@rm -f /tmp/sbahn
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
	-@rm -f /tmp/rbahn
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
	$(CONVERT_ORIG) -keep-directive alias -unutf8ify rbahnhof-orig > rbahnhof~
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
# :U modifier does not work with older pmakes, so don't use it,
# instead use the echo | tr construct...
	(i_upper=`echo $(i) | tr '[:lower:]' '[:upper:]'`; echo "#: title: Fahrradfreundliche Zug‰nge bei der $$i_upper-Bahn"; \
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

ampeln:	ampeln-orig .check_daily
	-@$(WRITEABLE) $@
	${GREPSTRASSEN_VALID} ampeln-orig | \
	    ${GREPSTRASSEN} -v -catrx '^[FX]0' -preserveglobaldirectives | \
	    ${CONVERT_ORIG} > ampeln~
	mv ampeln~ ampeln
	-@$(READONLY) $@

ampelschaltung:	ampelschaltung-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) -ampelschaltung ampelschaltung-orig > ampelschaltung~
	mv ampelschaltung~ ampelschaltung
	-@$(READONLY) $@

gesperrt:	${PERSISTENTTMPDIR}/gesperrt-with-handicaps comments_path routing_helper-orig
	-@$(WRITEABLE) $@
	$(REPLACESTRASSEN) -catexpr 's/:q\d//' < ${PERSISTENTTMPDIR}/gesperrt-with-handicaps > $@~
	${GREPSTRASSEN} -ignoreglobaldirectives -ignorelocaldirectives -catrx ';$$' routing_helper-orig |\
	    ${REPLACESTRASSEN} -catexpr 's/.*/1::igndisp/' -revcoords >> $@~
	mv $@~ $@
	-@$(READONLY) $@

${PERSISTENTTMPDIR}/gesperrt-with-handicaps:	${PERSISTENTTMPDIR}/gesperrt-orig-valid \
						strassen landstrassen landstrassen2 comments_path
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) -specsperre=strassen,landstrassen,landstrassen2 \
	        -specsperre-exceptions=comments_path ${PERSISTENTTMPDIR}/gesperrt-orig-valid |\
	    ${RESOLVE_STARS} ${ALL_STREETS} - > $@~
	mv $@~ $@
	-@$(READONLY) $@

${PERSISTENTTMPDIR}/gesperrt-without-nocross:	${PERSISTENTTMPDIR}/gesperrt-orig-valid strassen landstrassen landstrassen2
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) -specsperre=strassen,landstrassen,landstrassen2 \
	    -nonc ${PERSISTENTTMPDIR}/gesperrt-orig-valid > $@~
	mv $@~ $@
	-@$(READONLY) $@

${PERSISTENTTMPDIR}/gesperrt-orig-valid:	gesperrt-orig .check_daily
	-@$(WRITEABLE) $@
	${GREPSTRASSEN_VALID} gesperrt-orig > $@~
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
	$(CONVERT2HAFAS) -specsperre=strassen,landstrassen,landstrassen2 gesperrt_car-orig |\
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

radwege:	${PERSISTENTTMPDIR}/radwege-orig-valid
	-@$(WRITEABLE) $@
	${CONVERT_RADWEGE} < ${PERSISTENTTMPDIR}/radwege-orig-valid | \
	    $(COMBINE_STREETS) - > $@~
	mv $@~ $@
	-@$(READONLY) $@

radwege_exact:	${PERSISTENTTMPDIR}/radwege-orig-valid
	-@$(WRITEABLE) $@
## XXX combine streets is buggy, see strassen-combine.t test!
#	${CONVERT_RADWEGE} -exact < ${PERSISTENTTMPDIR}/radwege-orig-valid | \
#	    $(COMBINE_STREETS) - > $@~
	${CONVERT_RADWEGE} -exact < ${PERSISTENTTMPDIR}/radwege-orig-valid > $@~
	mv $@~ $@
	-@$(READONLY) $@

${PERSISTENTTMPDIR}/radwege-orig-valid:	radwege-orig .check_daily
	-@$(WRITEABLE) $@
	${GREPSTRASSEN_VALID} radwege-orig > $@~
	mv $@~ $@
	-@$(READONLY) $@

qualitaet_s:	qualitaet_s-orig
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) -keep-directive valid -strip-tendencies qualitaet_s-orig |\
	    ${GREPSTRASSEN_VALID} > qualitaet_s~
	mv qualitaet_s~ qualitaet_s
	-@$(READONLY) $@

qualitaet_l:	qualitaet_l-orig
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) -keep-directive valid -strip-tendencies qualitaet_l-orig  |\
	    ${GREPSTRASSEN_VALID} > qualitaet_l~
	mv qualitaet_l~ qualitaet_l
	-@$(READONLY) $@

handicap_s:	handicap_s-orig berlin ${PERSISTENTTMPDIR}/gesperrt-with-handicaps routing_helper-orig
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) -strip-tendencies handicap_s-orig > handicap_s~
	$(GREPSTRASSEN) -catrx ':q\d' < ${PERSISTENTTMPDIR}/gesperrt-with-handicaps |\
	    $(GREPSTRASSEN) -inner berlin |\
	    $(REPLACESTRASSEN) -noglobaldirectives \
		-catexpr 's/.*:(q\d)/$$1::igndisp;/' \
		-nameexpr 's/(.*)/$$1: gegen die Einbahnstraﬂenrichtung, ggfs. schieben/' \
		>> handicap_s~
	${GREPSTRASSEN} -ignoreglobaldirectives -ignorelocaldirectives -catrx '^q\d+;$$' routing_helper-orig |\
	    ${REPLACESTRASSEN} -catexpr 's/;/::igndisp;/' >> handicap_s~
	mv handicap_s~ handicap_s
	-@$(READONLY) $@

handicap_l:	handicap_l-orig berlin ${PERSISTENTTMPDIR}/gesperrt-with-handicaps
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) -strip-tendencies handicap_l-orig > handicap_l~
	$(GREPSTRASSEN) -catrx ':q\d' < ${PERSISTENTTMPDIR}/gesperrt-with-handicaps |\
	    $(GREPSTRASSEN) -outer berlin |\
	    $(REPLACESTRASSEN) -noglobaldirectives \
		-catexpr 's/.*:(q\d)/$$1::igndisp;/' \
		-nameexpr 's/(.*)/$$1: gegen die Einbahnstraﬂenrichtung, ggfs. schieben/' \
		>> handicap_l~
	mv handicap_l~ handicap_l
	-@$(READONLY) $@

vorfahrt:	vorfahrt-orig .check_daily
	-@$(WRITEABLE) $@
	${GREPSTRASSEN_VALID} vorfahrt-orig | \
	    ${CONVERT_ORIG} > vorfahrt~
	mv vorfahrt~ vorfahrt
	-@$(READONLY) $@

# Old style using convert2hafas. Caution: convert_orig_to_bbd is not
# able to do some things yet necessary here, for example automatic
# Gefaelle generation in comments_mount or not combining X;X
# categories into X
.for f in ${COMMENTS_PARTIAL:Ncomments_route:Ncomments_ferry:Ncomments_misc:Ncomments_cyclepath}
${f}: ${f}-orig ${ALL_STREETS} ${PERSISTENTTMPDIR}/gesperrt-without-nocross .check_daily
	-@$(WRITEABLE) $@
	${GREPSTRASSEN_VALID} ${f}-orig | \
	    ${GREPSTRASSEN} -v -directive 'ignore=' | \
	    $(CONVERT2HAFAS) -basefile ${f}-orig - | \
	    ${RESOLVE_STARS} -sperrefile ${PERSISTENTTMPDIR}/gesperrt-without-nocross \
	        ${ALL_STREETS} - > $@~
	mv $@~ $@
	-@$(READONLY) $@
.endfor

# Special target to remove "?" modifier from categories
comments_cyclepath: comments_cyclepath-orig ${ALL_STREETS} ${PERSISTENTTMPDIR}/gesperrt-without-nocross
	-@$(WRITEABLE) $@
	cat comments_cyclepath-orig | \
	    ${GREPSTRASSEN} -v -directive 'ignore=' | \
	    $(CONVERT2HAFAS) -basefile comments_cyclepath-orig - | \
	    ${RESOLVE_STARS} -sperrefile ${PERSISTENTTMPDIR}/gesperrt-without-nocross \
	        ${ALL_STREETS} - | \
	    ${REPLACESTRASSEN} -catexpr 's/\?//g' \
		> $@~
	mv $@~ $@
	-@$(READONLY) $@

# New style using convert_orig_to_bbd. comments_route here,
# because of the need for alias and url directives. comments_ferry
# needs special as_of handler. comments_misc, because of a bug
# in convert2hafas
.for f in comments_route comments_ferry comments_misc
${f}: ${f}-orig ${ALL_STREETS} ${PERSISTENTTMPDIR}/gesperrt-without-nocross .check_daily
	-@$(WRITEABLE) $@
	${GREPSTRASSEN_VALID} ${f}-orig | \
	    ${GREPSTRASSEN} -v -directive 'ignore=' | \
	    $(CONVERT_ORIG) -keep-directive url -keep-directive alias -special as_of - | \
	    ${RESOLVE_STARS} -sperrefile ${PERSISTENTTMPDIR}/gesperrt-without-nocross \
	        ${ALL_STREETS} - > $@~
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
	$(STEIGUNG_STAT) -die-on-fatal -minmount 1.0 -commentscompatible -sperre gesperrt \
		-str strassen -str fragezeichen -i hoehe -o $@~
	mv $@~ $@
	-@$(READONLY) $@

exits:	exits-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) $> > $@~
	mv $@~ $@
	-@$(READONLY) $@

culdesac:	culdesac-orig
	-@$(WRITEABLE) $@
	cat $> | \
	    ${GREPSTRASSEN} -preserveglobaldirectives -v -directive 'ignore=' | \
	    ${CONVERT2HAFAS} - > $@~
	mv $@~ $@
	-@$(READONLY) $@

kneipen:	kneipen.yml
	-@$(WRITEABLE) $@
	${PERL} $(MISCSRCDIR)/yaml2bbd $> > $@~
	mv $@~ $@
	-@$(READONLY) $@

oldnames:	strassen Berlin.coords.data
	-@$(WRITEABLE) $@
	${PERL} $(MISCSRCDIR)/oldname2plz > $@~
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

.modified:	${TARGETS} ${NON_TARGETS}
	${PERL} ${MISCSRCDIR}/create_modified

# Makefile in ../misc ausf¸hren
# drat ... ich mˆchte nicht gmake verwenden :-(
make_misc:
	cd $(MISCDIR) && ${MAKE} ${MAKEFLAGS} 

# Create Storable versions of data files
# handling of Storable files is up to twice as fast as normal bbd files, but not well-tested, so it is not done by default
#
# This target assumes that all bbd files are up-to-date.
STORABLE_TARGETS=${BBD_TARGETS:S/$/.st/}
storable:
.for i in ${BBD_TARGETS}
	@if [ ! -e $i.st -o $i.st -ot $i ] ; then \
	    $(PERL) -I.. -I../lib ../Strassen/Storable.pm -v -u -f $i $i.st; \
	    $(READABLE) $i.st; \
	fi
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
		${PERSISTENTTMPDIR}/.fragezeichen-bbbike-temp-blockings-optimized \
		Makefile
	-@$(WRITEABLE) $@
	cat fragezeichen-orig |\
	        ${GREPSTRASSEN} -v -directive 'ignore=' |\
	        ${GREPSTRASSEN} -special filternextcheck |\
	    ${CONVERT_ORIG} > $@~
	@echo "# added from ampeln-orig" >> $@~
	grep '?' ${DATADIR}/ampeln-orig | \
	    $(SED) -e 's/	\([^ ]*\)/ (\1)	?/' | \
	    ${CONVERT2HAFAS} -basefile ${DATADIR}/ampeln-orig -- - >> $@~
	@echo "# added from other ${PERSISTENTTMPDIR}/.fragezeichen-other-source" >> $@~
	cat ${PERSISTENTTMPDIR}/.fragezeichen-other-source >> $@~
	@echo "# added from other sources: (${SOURCE_TARGETS})" >> $@~
	cat ${SOURCE_TARGETS:S|^|${PERSISTENTTMPDIR}/.fragezeichen-|} >> $@~
	@echo "# added from bbbike-temp-blockings-optimized" >> $@~
	cat ${PERSISTENTTMPDIR}/.fragezeichen-bbbike-temp-blockings-optimized >> $@~
	cmp -s $@~ $@ && rm $@~ || mv $@~ $@
	touch .create_fragezeichen
	-@$(READONLY) $@

.for i in ${SOURCE_TARGETS}
${PERSISTENTTMPDIR}/.fragezeichen-$(i):	$(i)-orig
	${GREPSTRASSEN_UTF8} -special fragezeichen ${DATADIR}/$(i)-orig > /dev/null
	cp -f /tmp/fragezeichen_$(i)-orig.bbd $@
.endfor

${PERSISTENTTMPDIR}/.fragezeichen-bbbike-temp-blockings-optimized:	${PERSISTENTTMPDIR}/bbbike-temp-blockings-optimized.bbd
	${GREPSTRASSEN_UTF8} -special fragezeichen $> > /dev/null
	cp -f /tmp/fragezeichen_bbbike-temp-blockings-optimized.bbd.bbd $@

######################################################################
# OTHER HELPER LAYERS, NOT INCLUDED IN STANDARD DIST

######################################################################
# PERSISTENT TEMPORARY DIRECTORY TARGETS

# Targets ../tmp/.XXX-{outdoor,indoor,...}-{strassen,landstrassen,...}
.for i in ${SOURCE_TARGETS}
${XXX_TARGETS:C/^/${PERSISTENTTMPDIR}\/.XXX-/:C/$/-$(i)/}:	$(i)-orig
	${GREPSTRASSEN} \
	    -adddirectives XXX \
	    ${XXX_NON_OUTDOOR:C/^/-adddirectives XXX_/} \
	    ${DATADIR}/$(i)-orig > /dev/null
	cp -f /tmp/XXX_$(i)-orig.bbd ${PERSISTENTTMPDIR}/.XXX-outdoor-$(i)
.for xxxtype in ${XXX_NON_OUTDOOR}
	cp -f /tmp/XXX_${xxxtype}_$(i)-orig.bbd ${PERSISTENTTMPDIR}/.XXX-${xxxtype}-$(i)
.endfor
.endfor

.for doormode in indoor outdoor
${PERSISTENTTMPDIR}/fragezeichen-${doormode}-nextcheck.bbd:	\
		.check_daily \
		Makefile \
		${SOURCE_TARGETS:S|$|-orig|} \
		${PERSISTENTTMPDIR}/bbbike-temp-blockings-optimized.bbd
	${MISCSRCDIR}/create_fragezeichen_nextcheck.pl --preamble --${doormode}-mode \
	    --fragezeichen-mode fragezeichen-orig \
	    --no-fragezeichen-mode \
	    ${SOURCE_TARGETS:S|fragezeichen||:S|$|-orig|} \
	    ${PERSISTENTTMPDIR}/bbbike-temp-blockings-optimized.bbd \
		> ${PERSISTENTTMPDIR}/fragezeichen-${doormode}-nextcheck.bbd~
	mv -f ${PERSISTENTTMPDIR}/fragezeichen-${doormode}-nextcheck.bbd~ ${PERSISTENTTMPDIR}/fragezeichen-${doormode}-nextcheck.bbd
.endfor

${PERSISTENTTMPDIR}/fragezeichen-outdoor.bbd:	\
		.check_daily \
		Makefile \
		${SOURCE_TARGETS:S|$|-orig|} \
		${PERSISTENTTMPDIR}/bbbike-temp-blockings-optimized.bbd
	${MISCSRCDIR}/create_fragezeichen_nextcheck.pl --preamble \
	    --coloring '#6c0000 +1w #b05555 +1m #ec8888 +6m #f2a0a0 +1y #fcc8c8 +5y #fdd8d8 +100y #fde0e0'\
	    --outdoor-mode \
	    --fragezeichen-mode fragezeichen-orig \
	    --no-fragezeichen-mode \
	    ${SOURCE_TARGETS:S|fragezeichen||:S|$|-orig|} \
	    ${PERSISTENTTMPDIR}/bbbike-temp-blockings-optimized.bbd \
		> ${PERSISTENTTMPDIR}/fragezeichen-outdoor.bbd~
	mv -f ${PERSISTENTTMPDIR}/fragezeichen-outdoor.bbd~ ${PERSISTENTTMPDIR}/fragezeichen-outdoor.bbd

${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd:	\
		.check_daily \
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
		${PERSISTENTTMPDIR}/XXX-outdoor.bbd
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
.for i in indoor outdoor
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

${PERSISTENTTMPDIR}/fragezeichen-nextcheck.org:	*-orig ${PERSISTENTTMPDIR}/bbbike-temp-blockings-optimized.bbd
	-@$(WRITEABLE) $@
	${MISCSRCDIR}/fragezeichen2org.pl *-orig ${PERSISTENTTMPDIR}/bbbike-temp-blockings-optimized.bbd > $@~
	mv $@~ $@
	-@$(READONLY) $@

# exact distances, but slower, especially if dist.db is missing or fresh
fragezeichen-nextcheck.org-exact-dist:
	-@$(WRITEABLE) ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.org
	${MISCSRCDIR}/fragezeichen2org.pl --plan-dir=${HOME}/.bbbike/gps_uploads --with-searches-weight --dist-dbfile=${PERSISTENTTMPDIR}/dist.db *-orig ${PERSISTENTTMPDIR}/bbbike-temp-blockings-optimized.bbd > ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.org~
	mv ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.org~ ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.org
	-@$(READONLY) ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.org

# Like fragezeichen-nextcheck.org-exact-dist, but using the home coordinate for both start/goal
${PERSISTENTTMPDIR}/fragezeichen-nextcheck-home-home.org:	*-orig ${PERSISTENTTMPDIR}/bbbike-temp-blockings-optimized.bbd
	-@$(WRITEABLE) $@
	centerc=`perl -nle 'm{centerc.*\x27(\d+,\d+)\x27} and print $$1' ~/.bbbike/config`; \
	    ${MISCSRCDIR}/fragezeichen2org.pl --dist-dbfile=${PERSISTENTTMPDIR}/dist.db -centerc $$centerc -center2c $$centerc *-orig ${PERSISTENTTMPDIR}/bbbike-temp-blockings-optimized.bbd > $@~
	mv $@~ $@
	-@$(READONLY) $@

${PERSISTENTTMPDIR}/projektierte_radstreifen.bbd:	fragezeichen-orig
	cat fragezeichen-orig | ${GREPSTRASSEN} -sectionrx "projektierte Radstreifen" | ${CONVERT2HAFAS} -basefile fragezeichen-orig > $@

${PERSISTENTTMPDIR}/strassen_in_planung.bbd:	fragezeichen-orig
	cat fragezeichen-orig | ${GREPSTRASSEN} -sectionrx "Straﬂen in Planung" | ${CONVERT2HAFAS} -basefile fragezeichen-orig > $@

# XXX Hmmm, die "temporary"-Eintr‰ge kˆnnten eigentlich nach fragezeichen wandern,
# aber nur, wenn sie nicht zus‰tzlich mit einer next_check/last_checked-Direktive
# versehen wurden... Siehe auch das TODO "Fragezeichen-Reorganisation"
#
# Target ../tmp/XXX-{outdoor,indoor,...}.bbd
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

${PERSISTENTTMPDIR}/XXX.bbd: ${PERSISTENTTMPDIR}/XXX-outdoor.bbd
	cat ${PERSISTENTTMPDIR}/XXX-outdoor.bbd > $@~
	@echo "# source: handicap_s-orig and gesperrt-orig" >> $@~
	${GREPSTRASSEN} -directive temporary= \
	    ${DATADIR}/handicap_s-orig ${DATADIR}/gesperrt-orig | \
	    $(PERL) -nle '/(.*\t)(\S+)(.*)/ && !/\b(\d{4}-\d{2}-\d{2}|[0123]?\d\.[01]?\d\.\d{4})\b/ && print "Noch immer? $$1?::inwork$$3"' | \
	    ${CONVERT2HAFAS} -basefile ${DATADIR}/handicap_s-orig -- - >> $@~
	mv $@~ $@

${PERSISTENTTMPDIR}/plz-b.bbd:	$(PERSISTENTTMPDIR)/plz.sql
	grep -i berlin $> | ${PERL} $(MISCSRCDIR)/parse_mapbender_plz.pl > $@

$(PERSISTENTTMPDIR)/plz.sql:	$(PERSISTENTTMPDIR)/plz.zip
	cd `dirname $>` && unzip -q -o `basename $>` plz.sql
	touch -r $(PERSISTENTTMPDIR)/plz.zip $(PERSISTENTTMPDIR)/plz.sql

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

# Die mit "laut adfc-karte" u.‰. gekennzeichneten Straﬂen extrahieren und
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

PREFIXMAP=sperr=SP,kopfstein=KP,qualit‰t=QU,m‰ﬂig.geeignet=QU,radweg=RW,benutzungspflich=RW,bau=BA,vorfahrt=VF,name=NA,bezeichn=NA,vorfahrt=VF,ampel=AM

# XXX not really in use...
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
# XXX not really in use...
${PERSISTENTTMPDIR}/my-upload-fragezeichen.wpt:	fragezeichen Makefile
	${MAKE} /tmp/upload-restricted-fragezeichen.wpt \
	    RESTRICT_BBOX="-8250,2025,-15000,-2675 16500,15375,4625,5984 26687,-316,9090,9005"
	cp -pf /tmp/upload-restricted-fragezeichen.wpt $@

temp_blockings/bbbike-temp-blockings-optimized.pl:	temp_blockings/bbbike-temp-blockings.pl .check_daily \
							strassen faehren landstrassen landstrassen2
	-@$(WRITEABLE) $@
	${PERL} $(MISCSRCDIR)/check_bbbike_temp_blockings \
	    -action output_future_nonrecurring \
	    -action dump_future_as_perl > $@~
	mv $@~ $@
	-@$(READONLY) $@

# Another fragezeichen POI approach: restrict to whole
# of Berlin, use only the center coordinate, use
# the fragezeichen-nextcheck.bbd file as input,
# create a gpx file
${PERSISTENTTMPDIR}/berlin-fragezeichen-poi.gpx: ${PERSISTENTTMPDIR}/fragezeichen-outdoor-nextcheck-middlepoint.bbd
	-@$(WRITEABLE) $@
	${PERL} ${MISCSRCDIR}/restrict_bbd_data.pl \
		-polygon-bbd berlin \
		-strdata $> \
		-o - |\
	    ${PERL} ${MISCSRCDIR}/bbd2gpsman.pl \
		-filter nearby=200 \
		-prefix XXX \
		-match name \
		-prefixmap ${PREFIXMAP} \
		-symbol danger |\
	    ${PERL} ${MISCSRCDIR}/gpsman2gpx - > $@
	-@$(READONLY) $@

${PERSISTENTTMPDIR}/fragezeichen-outdoor-nextcheck-middlepoint.bbd: ${PERSISTENTTMPDIR}/fragezeichen-outdoor-nextcheck.bbd
	-@$(WRITEABLE) $@
	${REPLACESTRASSEN} -coordsexpr 'my @c = split / /, $$_; $$_ = $$c[@c/2]' $> > $@
	-@$(READONLY) $@

# XXX Optimierungsmˆglichkeit: aus "fragezeichen" alle Strecken herausnehmen, die bereits auf Strecken in strassen+landstrassen matchen
# XXX vielleicht umbenennen: fragezeichen-approx-matches.bbd oder so
${PERSISTENTTMPDIR}/fragezeichen-matches.bbd:	fragezeichen ${DATADIR}/strassen ${DATADIR}/landstrassen ${DATADIR}/landstrassen2
	${PERL} $(MISCRSRCDIR)/match_bbd_data -incatrx . -v fragezeichen ${DATADIR}/strassen ${DATADIR}/landstrassen ${DATADIR}/landstrassen2 > /tmp/fragezeichen-matches.bbd
	mv /tmp/fragezeichen-matches.bbd ${PERSISTENTTMPDIR}/fragezeichen-matches.bbd

${PERSISTENTTMPDIR}/osm_watch_list:		*-orig ${PERSISTENTTMPDIR}/bbbike-temp-blockings-optimized.bbd
	-@$(WRITEABLE) $@
	${MISCSRCDIR}/bbd_to_osm_watch_list *-orig ${PERSISTENTTMPDIR}/bbbike-temp-blockings-optimized.bbd > $@~
	mv $@~ $@
	-@$(READONLY) $@

${PERSISTENTTMPDIR}/osm_watch_list_brandenburg:	*-orig ${PERSISTENTTMPDIR}/bbbike-temp-blockings-optimized.bbd
	-@$(WRITEABLE) $@
	${MISCSRCDIR}/bbd_to_osm_watch_list -filter-region brb *-orig ${PERSISTENTTMPDIR}/bbbike-temp-blockings-optimized.bbd > $@~
	mv $@~ $@
	-@$(READONLY) $@

######################################################################
# CHECKS

# allow one error, and fail if the 2nd one is encountered
FOREVER_INTERVAL?=	30
FOREVER_TWO_ERRORS=	perl -MFcntl=:flock -e  '@cmd=@ARGV; while() { { open my $$LOCK, ">", ".check_forever.lck" or die $$!; flock $$LOCK, LOCK_EX|LOCK_NB or die $$!; system(@cmd); exit 2 if $$? == 2; $$count = $$? == 0 ? 0 : $$count+1; exit 1 if $$count >= 2; } unlink ".check_forever.lck"; sleep $(FOREVER_INTERVAL) }'
.if exists($(HOME)/bin/sh/cron-wrapper)
CRON_WRAPPER=$(HOME)/bin/sh/cron-wrapper
.else
CRON_WRAPPER=
.endif

# Specify ADDITIONAL_CHECK_FOREVER_TARGETS make variable on command
# line for more things to do...
check-forever:
	-nice ${FOREVER_TWO_ERRORS} ${CRON_WRAPPER} ${MAKE} check all fragezeichen-outdoor-nextcheck fragezeichen-outdoor ${ADDITIONAL_CHECK_FOREVER_TARGETS}
	@-alarm -nicedown
	@-xterm-conf -deiconify -raise
	xmessage "check-forever failed"

# Like check-forever, but build first, then check (all calls the check target)
all-forever:
	-nice ${FOREVER_TWO_ERRORS} ${CRON_WRAPPER} ${MAKE} fragezeichen-outdoor-nextcheck fragezeichen-outdoor all
	@-alarm -nicedown
	@-xterm-conf -deiconify -raise
	xmessage "all-forever failed"

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
	.check_missing_streets \
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
	.check_culdesac .check_culdesac_2 .check_culdesac_3 \
	.check_temp_blockings .check_grenzuebergaenge \
	.check_berlin .check_potsdam \
	.check_ortsschilder .check_ortsschilder2 \
	${CHECK_RECURRING_TEMP_BLOCKINGS_TARGET}

.check_empty_lines:	*-orig
	for i in *-orig; do $(PERL) -nle '$$_ eq q{} and die $$ARGV' $$i; done

# check disabled targets
check-disabled:

.check_targets:	${BBD_TARGETS}
	${PERL} ${MISCSRCDIR}/check_bbd ${BBD_TARGETS}
	@touch $@

.check_strassen1:	.strassen.tmp add_str Berlin.coords.data
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
	$(CHECK_POINTS) plaetze .strassen.tmp landstrassen
	@touch $@

.check_plaetze2: ${PERSISTENTTMPDIR}/non-faked-plaetze add_plaetze
	$(CHECK_STR_PLZ) -addstr add_plaetze -data ${PERSISTENTTMPDIR}/non-faked-plaetze
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

.check_missing_streets: ${MISCSRCDIR}/missing_streets.pl strassen fragezeichen-orig Berlin.coords.data
	${MISCSRCDIR}/missing_streets.pl
	@touch $@

.check_hoehe:	hoehe .strassen.tmp landstrassen landstrassen2 fragezeichen
	$(CHECK_POINTS) -namerx '^\d+(\.\d+)?$$' hoehe .strassen.tmp landstrassen landstrassen2 fragezeichen
	@touch $@

.check_hoehe2:	hoehe
	$(CHECK_DOUBLE) -points hoehe
	@touch $@

.check_ampeln:	ampeln .strassen.tmp landstrassen landstrassen2 fragezeichen
	$(CHECK_POINTS) ampeln .strassen.tmp landstrassen landstrassen2 fragezeichen
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
	$(CHECK_POINTS) ortsschilder .strassen.tmp landstrassen landstrassen2 fragezeichen
	@touch $@

.check_ortsschilder2:	orte orte2 ortsschilder-orig
	perl -MData::Dumper -I.. -I../lib -MStrassen::Core -e '$$seen{"Berlin"} = 1; for $$o (qw(orte orte2)) { Strassen->new_stream($$o)->read_stream(sub { my($$r) = @_; my $$label = $$r->[0]; $$seen{$$label}++; }) }; Strassen->new_stream("ortsschilder-orig")->read_stream(sub { my($$r, $$dir) = @_; my $$label = "@{ $$dir->{linked} || [] }" || $$r->[0]; $$seen{$$label}++ or $$error{$$label}++ }, UseLocalDirectives => 1); if (%error) { die Dumper(\%error) }' 
	@touch $@

# Interactive test
.check_ortsschilder_dist:	orte orte2 ortsschilder-orig
	perl -MData::Dumper -I.. -I../lib -MStrassen::Util -MStrassen::Core -Mopen=:locale -e 'for $$o (qw(orte orte2)) { Strassen->new_stream($$o)->read_stream(sub { my($$r) = @_; my $$label = $$r->[0]; $$pos{$$label} = $$r->[1][0]; $$cat{$$label} = $$r->[2] }) }; Strassen->new_stream("ortsschilder-orig")->read_stream(sub { my($$r, $$dir) = @_; my $$label = "@{ $$dir->{linked} || [] }" || $$r->[0]; $$pos = $$r->[1][0]; printf "%.1fkm cat=%s %s\n", Strassen::Util::strecke_s($$pos, $$pos{$$label})/1000, $$cat{$$label}, $$label }, UseLocalDirectives => 1) ' | sort -nr | less

.check_gesperrt1:	gesperrt .strassen.tmp landstrassen landstrassen2 fragezeichen routing_helper-orig
	$(CHECK_POINTS) gesperrt .strassen.tmp landstrassen landstrassen2 fragezeichen routing_helper-orig
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

.check_gesperrt_car1:	gesperrt_car .strassen.tmp landstrassen landstrassen2 strassen_bab
	$(CHECK_POINTS) gesperrt_car .strassen.tmp landstrassen landstrassen2 strassen_bab
	@touch $@

.check_gesperrt_car2:	gesperrt_car strassen landstrassen landstrassen2 strassen_bab
	$(CHECK_NEIGHBOUR) -type standard -data gesperrt_car \
		-against strassen -against landstrassen -against landstrassen2 -against strassen_bab
	@touch $@

.check_ubahnhof:	ubahnhof ubahn
	$(CHECK_STATION_CATEGORY) ubahnhof-orig ubahn
	@touch $@

.check_sbahnhof:	sbahnhof sbahn
	$(CHECK_STATION_CATEGORY) sbahnhof-orig sbahn
	@touch $@

.for i in u s
.check_$(i)bahnhof2:	$(i)bahnhof Berlin.coords.data
	grep -i '	$(i)[AB] ' $(i)bahnhof |\
	    $(SED) -e 's/ *(.*)//' -e 's/	.*//' -e 's/bhf\./bahnhof/' -e 's/Bhf\./Bahnhof/' |\
	    $(SORT_GERMAN_LOCALE) -u > /tmp/$(i)bahnhof1
	grep -i '^$(i)-Bhf' Berlin.coords.data |\
	    egrep -v 'S-Bhf (F¸rstenbrunn)' |\
	    $(SED) -e 's/ *(.*)//' -e 's/S-Bhf //' -e 's/U-Bhf //' -e 's/|.*//' |\
	    $(SORT_GERMAN_LOCALE) -u > /tmp/$(i)bahnhof2
	diff /tmp/$(i)bahnhof1 /tmp/$(i)bahnhof2
	@rm -f /tmp/$(i)bahnhof1 /tmp/$(i)bahnhof2
	@touch $@
.endfor

.check_rbahnhof:	rbahnhof rbahn
	$(CHECK_STATION_CATEGORY) rbahnhof-orig rbahn
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

.check_${i}_1:	$i strassen landstrassen landstrassen2 faehren fragezeichen
	$(CHECK_POINTS) $i strassen landstrassen landstrassen2 faehren fragezeichen
	@touch $@

.endfor

.check_comments2:	$(COMMENTS_PARTIAL) strassen landstrassen landstrassen2 faehren fragezeichen
	$(CHECK_NEIGHBOUR) -type standard \
	    -against strassen -against landstrassen -against landstrassen2 \
	    -against faehren -against fragezeichen \
	    ${COMMENTS_PARTIAL:S/^/-data /g}
	@touch $@

.check_comments3:	$(COMMENTS_PARTIAL)
	${CHECK_COMMENTS} ${COMMENTS_PARTIAL}
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
	$(CHECK_POINTS) -namerx '^(ALT|SINGLE|CONT) (\d+[a-z]?)?/(\d+[a-z]?)? (\d+[a-z]?)?/(\d+[a-z]?)?$$' housenumbers .strassen.tmp
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

${CHECK_RECURRING_TEMP_BLOCKINGS_TARGET}: temp_blockings/bbbike-temp-blockings.pl .check_daily
	${TEMP_BLOCKINGS_TASKS} check_recurrences --prewarn-days=${CHECK_RECURRENCES_PREWARN_DAYS} temp_blockings/bbbike-temp-blockings.pl
	@touch $@

.check_grenzuebergaenge:	grenzuebergaenge .strassen.tmp landstrassen landstrassen2 fragezeichen deutschland
	$(CHECK_POINTS) grenzuebergaenge .strassen.tmp landstrassen landstrassen2 fragezeichen
	$(CHECK_POINTS) grenzuebergaenge deutschland
	@touch $@

.check_culdesac:	culdesac .strassen.tmp landstrassen landstrassen2 fragezeichen
	$(CHECK_POINTS) culdesac .strassen.tmp landstrassen landstrassen2 fragezeichen
	@touch $@

# Check also the orig variant, because currently too much is
# ignored...
.check_culdesac_2:	culdesac-orig .strassen.tmp landstrassen landstrassen2 fragezeichen
	$(CHECK_POINTS) culdesac-orig .strassen.tmp landstrassen landstrassen2 fragezeichen
	@touch $@

.check_culdesac_3:	culdesac-orig
	$(CHECK_DOUBLE) -points culdesac-orig
	@touch $@

.for city in berlin potsdam
.check_$(city):	$(city)
	grep -v '^#' $(city) | perl -nle '$$line++; END { die "Expected exactly one line" if $$line != 1 }'
	@touch $@
.endfor

.check_add_str:	strassen add_str Berlin.coords.data
	false
	@touch $@

count-streets:
	@echo -n "Berlin:        "; grep -v "^#" strassen                            | grep -v "^(" | grep -v '\[.*\]' | ${CUT} -f1 | sort -u | wc -l
	@echo -n "Landstraﬂen:   "; grep -v "^#" landstrassen landstrassen2 | ${CUT} -f1 | sort -u | wc -l
	@echo -n "  Potsdam:     "; grep -v "^#" landstrassen | fgrep "(Potsdam)"    | grep -v "^(" | grep -v '\[.*\]' | ${CUT} -f1 | sort -u | wc -l
	@echo -n "  Oranienburg: "; grep -v "^#" landstrassen | fgrep "(Oranienburg" | grep -v "^(" | grep -v '\[.*\]' | ${CUT} -f1 | sort -u | wc -l

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

check-categories:	${BBD_TARGETS:S/^/.check_categories_/:S/\//_/g}

.for target in ${BBD_TARGETS}
.check_categories_${target:S/\//_/g}:	${target}
	$(PERL_UTF8) -I../lib -I.. -MStrassen::Cat -e '\
	    exit !Strassen::Cat::check_file($$ARGV[0], BBBikeVersion => "data-update");\
	' ${target}
	touch $@
.endfor

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
	    -ignorerx "^Alt-Friedrichsfelde, linker Gehweg" \
	    -o $@~ -against brunnels \
	    strassen landstrassen landstrassen2
	mv $@~ $@

# XXX ¸berirdische U-Bahnen?
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
	    -ignore "Fasaneriegraben,Packereigraben,Tr‰nkegraben,Kraatzgraben,Teufelsseekanal,(See im Tiergarten),,Luiseninsel,Fennpfuhl,Heidekampgraben,Karpfenteich,Panke,Nordgraben,Tegeler Flieﬂ,Hermsdorfer See,Neue Wuhle,Flutgraben,Kreuzgraben,Zingergraben,Iderfenngraben,B‰ke,Bullengraben,Spektegraben,Bruchst¸ckengraben,Fredersdorfer M¸hlenflieﬂ,Neuenhagener M¸hlenflieﬂ,Plumpengraben,Kleiner J¸rgengraben,Rudower Flieﬂ,Gr¸tzmachergraben,Kanal I,Kanal II,Kanal III,Kanal IV,Kanal V,Kanal in Neu-Venedig" \
	    -o $@~ -against brunnels \
	    strassen wasserstrassen
	mv $@~ $@

${PERSISTENTTMPDIR}/crossings_gewaesser_ignore.bbd:	\
					strassen wasserstrassen brunnels
	${PERL} ${MISCSRCDIR}/check_crossings -v-if-interactive \
	    -o $@~ -against brunnels \
	    strassen wasserstrassen
	mv $@~ $@

check-urls: ${PERSISTENTTMPDIR}/url_checks.log

${PERSISTENTTMPDIR}/url_checks.log:	comments_route-orig comments_ferry-orig
	${PERL} ${MISCSRCDIR}/url_checker.pl -v -log ${PERSISTENTTMPDIR}/url_checks.log~ $>
	mv ${PERSISTENTTMPDIR}/url_checks.log~ ${PERSISTENTTMPDIR}/url_checks.log

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
	    grep -v '[US]-Bhf ' | egrep -v ' \(Kolonie|Siedlung|Gastst‰tte|Insel|geplant\)' | egrep -v '^(Kolonie |KGA |Siedlung |G¸terbahnhof )' \
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
# - N‰he S-Bhf. Landsberger Allee
# - N‰he M¸ller-Breslau-Str.
# - Alexandrinenstr.?
# - Insulaner
	diff -u \
	    -I'13088.*Lichtenberg' \
	    -I'10367.*Friedrichshain-Kreuzberg' \
	    -I'10407.*Friedrichshain-Kreuzberg' \
	    -I'10623.*Mitte' \
	    -I'10969.*Mitte' \
	    -I'12169.*Tempelhof-Schˆneberg' \
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

check-nearest-ignore-remove-unconsumed:
	${PERL} ${MISCSRCDIR}/check_nearest -ignore check_nearest_ignore \
		-asbbd \
		-strfile strassen \
		-strfile landstrassen \
		-strfile landstrassen2 \
		-strfile fragezeichen \
		-strfile brunnels \
		-strfile faehren \
		-remove-unconsumed-ignore \
		> /dev/null

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
# GNUmakefile is now static
.endif

######################################################################
# Misc helpers

show-used-directives:
	${PERL} -nle '/^#: ([^\s:]+)/ and print $$1' *-orig | sort -u

######################################################################
# Berlin.coords.data etc. targets

sort-coords.data:	sort-Berlin.coords.data sort-Potsdam.coords.data

# XXX It is considered to use a platform-independent approach to
# do the sorting. A favorite approach is using Unicode::Collate, a
# core perl module. But some problems:
# - the diff is huge, mainly due to a bug in FreeBSD's "sort -f" implementation
# - Unicode::Collate is significantly slower
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

$(PERSISTENTTMPDIR)/bbbike-temp-blockings-optimized.bbd: $(PERSISTENTTMPDIR)/bbbike-temp-blockings-optimized.yml
	$(TEMP_BLOCKINGS_TASKS) yml_to_bbd $> > $@~
	mv -f $@~ $@

$(PERSISTENTTMPDIR)/bbbike-temp-blockings.bbd: temp_blockings/bbbike-temp-blockings.yml
	$(TEMP_BLOCKINGS_TASKS) yml_to_bbd $> > $@~
	mv -f $@~ $@

$(PERSISTENTTMPDIR)/bbbike-temp-blockings-nonrecurring.bbd: $(PERSISTENTTMPDIR)/bbbike-temp-blockings-optimized.yml
	$(TEMP_BLOCKINGS_TASKS) yml_to_nonrecurring_bbd $> > $@~
	mv -f $@~ $@

$(PERSISTENTTMPDIR)/bbbike-temp-blockings-recurring.bbd: $(PERSISTENTTMPDIR)/bbbike-temp-blockings-optimized.yml
	$(TEMP_BLOCKINGS_TASKS) yml_to_recurring_bbd $> > $@~
	mv -f $@~ $@

$(PERSISTENTTMPDIR)/sourceid-all.yml: $(PERSISTENTTMPDIR)/bbbike-temp-blockings.bbd handicap_s-orig gesperrt-orig fragezeichen-orig radwege-orig
	$(MISCSRCDIR)/bbd_to_sourceid_exists $> > $@~
	mv -f $@~ $@

$(PERSISTENTTMPDIR)/sourceid-current.yml: $(PERSISTENTTMPDIR)/bbbike-temp-blockings-optimized.bbd handicap_s-orig gesperrt-orig fragezeichen-orig radwege-orig
	$(MISCSRCDIR)/bbd_to_sourceid_exists $> > $@~
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
	diff -I '#: alias:' -I '#: oldname' -u .strassen.tmp /tmp/strassen-XXX
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
