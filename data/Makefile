#
# $Id: Makefile,v 2.136 2007/04/25 23:14:23 eserte Exp eserte $
#
# This Makefile is only usable with a modern version of BSD make (also known
# as "pmake"). The source for pmake can be found at
#
#   http://www.sourceforge.net/projects/srezic
#
# (This is a slightly modified version of the original pmake as found in
# the FreeBSD sources)

BBBIKEDIR=		..
MISCDIR=		$(BBBIKEDIR)/misc
MISCSRCDIR=		$(BBBIKEDIR)/miscsrc
DATADIR=		.
PERSISTENTTMPDIR=	$(BBBIKEDIR)/tmp

#XXX del:
#BERLINMAP2HAFAS=	${MISCSRCDIR}/berlinmap2hafas -strict
HAFAS2HAFAS=		${MISCSRCDIR}/hafas2hafas -strict
CONVERT2HAFAS=		${MISCSRCDIR}/convert2hafas -strict
CONVERT_ORIG=		${MISCSRCDIR}/convert_orig_to_bbd
CHECK_POINTS=		${MISCSRCDIR}/check_points
CHECK_STR_PLZ=		${MISCSRCDIR}/check_str_plz
CHECK_CONT=		${MISCSRCDIR}/check_cont
CHECK_DOUBLE=           ${MISCSRCDIR}/check_double
CHECK_NEIGHBOUR=	${MISCSRCDIR}/check_neighbour
CHECK_COUNT=		${MISCSRCDIR}/check_count
CHECK_HOUSENUMBERS=	${MISCSRCDIR}/check_housenumbers
CHECK_IMAGES=		${MISCSRCDIR}/check_images
CHECK_STATION_CATEGORY=	${MISCSRCDIR}/check_station_category
RESOLVE_STARS=		${MISCSRCDIR}/resolve_stars
SORTBYCAT=		${MISCSRCDIR}/sortbycat
SEARCH_INACCESSIBLE=	${MISCSRCDIR}/search_inaccessible_points
STEIGUNG_STAT=		${MISCSRCDIR}/steigung_stat
GREPSTRASSEN=		${MISCSRCDIR}/grepstrassen
# perl5.8.0 has utf8 bugs
.if ${HOST} == "devpc01.iconmobile.de"
PERL_UTF8=		perl5.8.7
.else
PERL_UTF8=		perl5.8.8
.endif
PERL=			perl
SED=			env LANG=C sed
GREPSTRASSEN_UTF8=	${PERL_UTF8} ${MISCSRCDIR}/grepstrassen
COMBINE_STREETS=	${MISCSRCDIR}/combine_streets.pl

COMMENTS_PARTIAL=	comments_cyclepath comments_ferry comments_misc \
			comments_mount comments_path comments_route \
			comments_tram comments_kfzverkehr comments_scenic

SOURCE_TARGETS=		strassen plaetze landstrassen landstrassen2 strassen_bab
SOURCE_TARGETS+=	flaechen
SOURCE_TARGETS+=	wasserstrassen wasserumland wasserumland2
SOURCE_TARGETS+=	sbahn sbahnhof rbahn rbahnhof
SOURCE_TARGETS+=	ubahn ubahnhof
SOURCE_TARGETS+=	faehren hoehe orte orte2 orte_city
SOURCE_TARGETS+=	ampeln ampelschaltung
SOURCE_TARGETS+=	plz potsdam deutschland
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
COMPUTED_TARGETS=	sbahnhof_bg ubahnhof_bg berlin
COMPUTED_TARGETS+=	radwege_exact mount
COMPUTED_TARGETS+=	temp_blockings/bbbike-temp-blockings-optimized.pl
COMPUTED_TARGETS+=	wasserstrassen-lowres
COMPUTED_TARGETS+=	kneipen

COOKED_TARGETS=		strassen-cooked landstrassen-cooked landstrassen2-cooked
TARGETS+=	${SOURCE_TARGETS} ${COMPUTED_TARGETS} ${COOKED_TARGETS}

ALL_STREETS=		strassen landstrassen landstrassen2

TARGETS_DISABLED=	label relation_gps 

WRITEABLE=	chmod u+w,ugo+r
READONLY=	chmod ugo+r,ugo-w
READABLE=	chmod ugo+r

# The locale was named de_DE.ISO_8859-1 in FreeBSD 4.x, but now with
# an underline less.
SORT_NO_LOCALE=	env LC_ALL=de_DE.ISO8859-1 sort

## XXX what is write, what is wrong?
#COORDS_DATA_SORT_OPTS=	-f -t "|" -k 1,3
COORDS_DATA_SORT_OPTS=

######################################################################
# META TARGETS

.ORDER: targets check .modified .rsync_include make_misc
all:	targets check .modified .rsync_include make_misc

# These targets have to be rebuild once a day
.BEGIN:
	@$(PERL) -e 'for (@ARGV) { do { unlink($$_) and warn "Removed $$_\n" } if (-M $$_ >= 1) }' \
		.check_bbbike-temp-blockings-optimized \
		.check_dates \
		${PERSISTENTTMPDIR}/.check_fragezeichen-nextcheck.bbd

targets:	${TARGETS}

targets-clean:
	-mkdir /tmp/old-data
	mv -f ${TARGETS} /tmp/old-data/

# Useful checks, but normally too slow for a quick build
# XXX merge with sort-Berlin.coords.data rule below?
slow-checks:	check-categories \
		inaccessible_strassen inaccessible_landstrassen \
		check-line-lengths check-dates \
		check-coords.data \
		persistent-tmp

persistent-tmp:	${PERSISTENTTMPDIR}/projektierte_radstreifen.bbd \
		${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd \
		${PERSISTENTTMPDIR}/.check_fragezeichen-nextcheck.bbd \
		${PERSISTENTTMPDIR}/strassen_in_planung.bbd \
		${PERSISTENTTMPDIR}/all-upload-fragezeichen.wpt \
		${PERSISTENTTMPDIR}/my-upload-fragezeichen.wpt \
		${PERSISTENTTMPDIR}/Berlin.coords.bbd \
		${PERSISTENTTMPDIR}/Potsdam.coords.bbd \
		${PERSISTENTTMPDIR}/non-faked-plaetze \
		${PERSISTENTTMPDIR}/non-faked-strassen \
		${PERSISTENTTMPDIR}/XXX.bbd \
		${PERSISTENTTMPDIR}/plz-b.bbd \
		persistent-tmp-from-opengeodb

# even slower (about four minutes)
really-slow-checks:	check-crossings-important \
			check-nearest \
			check-crossings-less-important

######################################################################
# DATA FILE TARGETS

######################################################################
# STRASSEN UND PLƒTZE
strassen:	.strassen.tmp plaetze
	-@$(WRITEABLE) $@
	cat .strassen.tmp > $@
	${GREPSTRASSEN} -v --namerx ' \(Potsdam\)' plaetze >> $@
	#-rm -f strassen-cooked
	-@$(READONLY) $@

.strassen.tmp: strassen-orig
	$(CONVERT2HAFAS) strassen-orig > $@~
	cp $@~ $@
	rm $@~

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
	$(CONVERT2HAFAS) plaetze-orig > plaetze
	-@$(READONLY) $@

${PERSISTENTTMPDIR}/non-faked-plaetze: plaetze-orig
	-@$(WRITEABLE) $@
	${GREPSTRASSEN} -v -section "faked_plaetze" plaetze-orig | $(CONVERT2HAFAS) -map H > $@~
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
	-@$(READONLY) $@

inaccessible_landstrassen: strassen landstrassen landstrassen2 gesperrt
	-@$(WRITEABLE) $@
	-cp -f $@ /tmp/old_inaccessible_landstrassen
	${SEARCH_INACCESSIBLE} -street strassen -street landstrassen \
	    -street landstrassen2 -blocked gesperrt \
	    -blockedtype einbahn -blockedtype sperre \
	    > inaccessible_landstrassen~ && mv inaccessible_landstrassen~ inaccessible_landstrassen
	@if [ -e /tmp/old_inaccessible_landstrassen ] ; then \
	    diff -u /tmp/old_inaccessible_landstrassen $@; \
	fi
	-@$(READONLY) $@

######################################################################
# OTHER DATA LAYERS

# sortbycat does not change the sort order of islands
wasserstrassen: wasserstrassen-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) wasserstrassen-orig | $(SORTBYCAT) -ignore F:I > $@ \
	    || (rm -f $@; false)
	-@$(READONLY) $@

wasserumland: wasserumland-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) wasserumland-orig | $(SORTBYCAT) -ignore F:I > $@ \
	    || (rm -f $@; false)
	-@$(READONLY) $@

wasserumland2: wasserumland2-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) wasserumland2-orig | $(SORTBYCAT) -ignore F:I > $@ \
	    || (rm -f $@; false)
	-@$(READONLY) $@

# The output is not the prettiest, but we save some 100k
wasserstrassen-lowres:  wasserstrassen wasserumland wasserumland2 \
			Makefile $(MISCSRCDIR)/simplify_streets
	-@$(WRITEABLE) $@
	cat wasserstrassen wasserumland wasserumland2 |\
	    $(GREPSTRASSEN) --catrx '^(F:W1)$$' > $@~
	cat wasserstrassen wasserumland wasserumland2 |\
	    $(GREPSTRASSEN) --catrx '^(W1|W2|F:W)$$' --minarea 3 >> $@~
	$(MISCSRCDIR)/simplify_streets -simplify-coefficient 0.04 $@~ > $@~~
	rm $@~
	mv -f $@~~ $@
	-@$(READONLY) $@

flaechen: flaechen-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) flaechen-orig > flaechen~
	cp $@~ $@
	rm $@~
	-@$(READONLY) $@

green:	green-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) $> > $@~
	mv $@~ $@
	-@$(READONLY) $@

brunnels:	brunnels-orig
	-@$(WRITEABLE) $@
	${GREPSTRASSEN} -v -section 'S-Bahn' $> | $(CONVERT2HAFAS) -map H > $@~
	mv $@~ $@
	-@$(READONLY) $@

landstrassen: landstrassen-orig plaetze
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) landstrassen-orig > $@~
	${GREPSTRASSEN} --namerx ' \(Potsdam\)' plaetze >> $@~
	cp $@~ $@
	rm $@~
	-rm -f landstrassen-cooked
	-@$(READONLY) $@

landstrassen2: landstrassen2-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) landstrassen2-orig > $@~
	cp $@~ $@
	rm $@~
	-rm -f landstrassen2-cooked
	-@$(READONLY) $@

strassen_bab: strassen_bab-orig
	-@$(WRITEABLE) $@
	cat strassen_bab-orig |\
		${GREPSTRASSEN} -v -sectionrx "Autobahnen in Planung" |\
	    $(CONVERT2HAFAS) -basefile strassen_bab-orig > $@~
	cp $@~ $@
	rm $@~
	-@$(READONLY) $@

# Get categories with:
# perl -nle '/\t(\S+)/ && print $1' sbahn-orig | sort -u
SBAHN_CATEGORIES=	SA SB SC S0 SBau

sbahn: sbahn-orig
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) -strip-future-categories sbahn-orig > /tmp/sbahn
.for cat in $(SBAHN_CATEGORIES)
	$(GREPSTRASSEN) -cat $(cat) /tmp/sbahn | $(MISCSRCDIR)/merge_overlapping_streets.pl -sep "," - | $(COMBINE_STREETS) - | sort > /tmp/sbahn-$(cat)
.endfor
	cat $(SBAHN_CATEGORIES:S/^/\/tmp\/sbahn-/) > sbahn~
	mv sbahn~ sbahn
	-@$(READONLY) $@

sbahnhof:	sbahnhof-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) sbahnhof-orig > sbahnhof~
	mv sbahnhof~ sbahnhof
	-@$(READONLY) $@

## Execute from bbbike root directory (evtl. mehrmals):
## XXX What for?
# cp -f data/Berlin.coords.data /tmp
# perl -Ilib -MObject::Iterate=iterate -MStrassen::Core -MTie::File -e '$s = Strassen->new("sbahnhof"); iterate { $p{$_->[Strassen::NAME]} = $_->[Strassen::COORDS][0] } $s; tie @f, "Tie::File", "/tmp/Berlin.coords.data" or die ; for (@f) { if (/^S-Bhf (.*?)\|.*\|$/ && $p{$1}) { $_ .= $p{$1}; warn "$1 $p{$1}" } }'

# See SBAHN_CATEGORIES comment
RBAHN_CATEGORIES=	RA RB RC R R0 RBau RG RP

rbahn: rbahn-orig Makefile
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) -strip-future-categories rbahn-orig > /tmp/rbahn
.for cat in $(RBAHN_CATEGORIES)
	$(GREPSTRASSEN) -cat $(cat) /tmp/rbahn | $(MISCSRCDIR)/merge_overlapping_streets.pl -sep "," - | $(COMBINE_STREETS) - | sort > /tmp/rbahn-$(cat)
.endfor
	cat $(RBAHN_CATEGORIES:S/^/\/tmp\/rbahn-/) > rbahn~
	mv rbahn~ rbahn
	-@$(READONLY) $@

rbahnhof:	rbahnhof-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) rbahnhof-orig > rbahnhof~
	mv rbahnhof~ rbahnhof
	-@$(READONLY) $@

ubahn: ubahn-orig
	-@$(WRITEABLE) $@
	$(CONVERT_ORIG) -strip-future-categories ubahn-orig > ubahn~
	mv ubahn~ ubahn
	-@$(READONLY) $@

ubahnhof:	ubahnhof-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) ubahnhof-orig > ubahnhof~
	mv ubahnhof~ ubahnhof
	-@$(READONLY) $@

## Execute from bbbike root directory (evtl. mehrmals):
## XXX What for?
# cp -f data/Berlin.coords.data /tmp
# perl -Ilib -MObject::Iterate=iterate -MStrassen::Core -MTie::File -e '$s = Strassen->new("ubahnhof"); iterate { $p{$_->[Strassen::NAME]} = $_->[Strassen::COORDS][0] } $s; tie @f, "Tie::File", "/tmp/Berlin.coords.data" or die $!; for (@f) { if (/^U-Bhf (.*?)\|.*\|$/ && $p{$1}) { $_ .= $p{$1}; warn "$1 $p{$1}" } }'

.for i in u s
$(i)bahnhof_bg:	$(i)bahnhof-orig
	-@$(WRITEABLE) $@
	(echo "#: title: Fahrradfreundliche Zug‰nge bei der $(i:U)-Bahn"; \
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
	$(CONVERT2HAFAS) faehren-orig > faehren~
	mv faehren~ faehren
	-@$(READONLY) $@

hoehe: hoehe-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) hoehe-orig > hoehe~
	mv hoehe~ hoehe
	-@$(READONLY) $@

orte: orte-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) -unutf8ify orte-orig | $(SORTBYCAT) > orte~
	[ -s orte~ ]
	mv orte~ orte
	-@$(READONLY) $@

orte2: orte2-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) -unutf8ify orte2-orig | $(SORTBYCAT) > orte2~
	[ -s orte2~ ]
	mv orte2~ orte2
	-@$(READONLY) $@

orte_city: orte_city-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) orte_city-orig | $(SORTBYCAT) > orte_city~
	mv orte_city~ orte_city
	-@$(READONLY) $@

ampeln:	ampeln-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) ampeln-orig > ampeln~
	mv ampeln~ ampeln
	-@$(READONLY) $@

ampelschaltung:	ampelschaltung-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) -ampelschaltung ampelschaltung-orig > ampelschaltung~
	mv ampelschaltung~ ampelschaltung
	-@$(READONLY) $@

gesperrt:	gesperrt-orig strassen landstrassen landstrassen2 comments_path
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) -specsperre=strassen,landstrassen,landstrassen2 \
	    -specsperre-exceptions=comments_path gesperrt-orig > $@~
	mv $@~ $@
	-@$(READONLY) $@

${PERSISTENTTMPDIR}/gesperrt-without-nocross:	gesperrt-orig strassen landstrassen landstrassen2
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) -specsperre=strassen,landstrassen,landstrassen2 \
	    -nonc gesperrt-orig > $@~
	mv $@~ $@
	-@$(READONLY) $@

.for i in u s r
gesperrt_$(i):	gesperrt_$(i)-orig $(i)bahn
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) gesperrt_$(i)-orig | $(MISCSRCDIR)/check_dates -filter > $@~
	mv $@~ $@
	-@$(READONLY) $@
.endfor

gesperrt_car:	gesperrt_car-orig strassen landstrassen landstrassen2
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) -specsperre=strassen,landstrassen,landstrassen2 \
	    gesperrt_car-orig > gesperrt_car~
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

# Not a default rule yet:
berlin_ortsteile:	plz-orig
	-@$(WRITEABLE) $@
	cat plz-orig | \
	    ${GREPSTRASSEN} -sectionrx "ortsteile" | \
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

sehenswuerdigkeit:	sehenswuerdigkeit-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) sehenswuerdigkeit-orig > sehenswuerdigkeit~
	mv sehenswuerdigkeit~ sehenswuerdigkeit
	-@$(READONLY) $@

obst:	obst-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) obst-orig > obst~
	mv obst~ obst
	-@$(READONLY) $@

radwege:	radwege-orig
	-@$(WRITEABLE) $@
	${MISCSRCDIR}/convert_radwege < radwege-orig > radwege-orig~
	cat radwege-orig~ | $(COMBINE_STREETS) - > $@ \
	    || (rm -f $@; false)
	rm -f radwege-orig~
	-@$(READONLY) $@

radwege_exact:	radwege-orig
	-@$(WRITEABLE) $@
	${MISCSRCDIR}/convert_radwege -exact < radwege-orig > $@ \
	    || (rm -f $@; false)
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

handicap_s:	handicap_s-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) handicap_s-orig > handicap_s~
	mv handicap_s~ handicap_s
	-@$(READONLY) $@

handicap_l:	handicap_l-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) handicap_l-orig > handicap_l~
	mv handicap_l~ handicap_l
	-@$(READONLY) $@

label:	label-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) label-orig > label~
	mv label~ label
	-@$(READONLY) $@

vorfahrt:	vorfahrt-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) vorfahrt-orig > vorfahrt~
	mv vorfahrt~ vorfahrt
	-@$(READONLY) $@

.for f in ${COMMENTS_PARTIAL}
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

mount:	strassen fragezeichen hoehe
	-@$(WRITEABLE) $@
	$(STEIGUNG_STAT) -minmount 1.0 -commentscompatible \
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
	$(MISCSRCDIR)/yaml2bbd $> > $@~
	mv $@~ $@
	-@$(READONLY) $@

######################################################################
# MORE HELPER TARGETS

# This also creates .rsync_include
.modified:	${TARGETS}
	${MISCSRCDIR}/create_modified

multi_bez_str:	multi_bez_str-orig
	-@$(WRITEABLE) $@
	${MISCSRCDIR}/complete_multi_bez_str > $@~
	mv $@~ $@
	-@$(READONLY) $@

# Makefile in ../misc ausf¸hren
# drat ... ich mˆchte nicht gmake verwenden :-(
make_misc:
	cd $(MISCDIR) && ${MAKE} ${MAKEFLAGS} 

# create Storable versions of data files
# handling of Storable files is slower, so it is not done by default
storable:
	for i in $(TARGETS); do \
	    $(PERL) -I.. -I../lib ../Strassen/Storable.pm -v -u -f $$i $$i.st; \
	done

######################################################################
# FRAGEZEICHEN LAYER

# The fragezeichen-PHONY and .create_fragezeichen stuff is necessary
# to minimize dependencies (well...)

.PHONY:	fragezeichen

.PRECIOUS:	fragezeichen

fragezeichen:	.create_fragezeichen
	-@$(WRITEABLE) $@
	cmp -s .create_fragezeichen $@ && true || cp .create_fragezeichen $@
	-@$(READONLY) $@

# ::inwork => will maybe change to :inwork
#XXX in "-orig" transition: handicap_s-orig and gesperrt-orig always need to have the same base map!
.create_fragezeichen:	fragezeichen-orig ${DATADIR}/ampeln-orig \
		.fragezeichen-other-source \
		${SOURCE_TARGETS:S|^|.fragezeichen-|} \
		Makefile
	-@$(WRITEABLE) $@
	cat fragezeichen-orig |\
	        ${GREPSTRASSEN} -v -sectionrx "ignorieren" |\
	    ${CONVERT2HAFAS} -basefile fragezeichen-orig > $@~
	@echo "# added from ampeln-orig" >> $@~
	grep '?' ${DATADIR}/ampeln-orig | \
	    $(SED) -e 's/	\([^ ]*\)/ (\1)	?/' | \
	    ${CONVERT2HAFAS} -basefile ${DATADIR}/ampeln-orig -- - >> $@~
	@echo "# added from handicap_s-orig and gesperrt-orig" >> $@~
	${MISCSRCDIR}/temporary_streets.pl \
	    ${DATADIR}/handicap_s-orig ${DATADIR}/gesperrt-orig | \
	    $(PERL) -nle '/(.*\t)(\S+)(.*)/ && !/\b(\d{4}-\d{2}-\d{2}|[0123]?\d\.[01]?\d\.\d{4})\b/ && print "Noch immer? $$1?::inwork$$3"' | \
	    ${CONVERT2HAFAS} -basefile ${DATADIR}/handicap_s-orig -- - >> $@~
	@echo "# added from other sources: (${SOURCE_TARGETS})" >> $@~
	cat .fragezeichen-other-source ${SOURCE_TARGETS:S|^|.fragezeichen-|} >> $@~
	cmp -s $@~ $@ && rm $@~ || mv $@~ $@
	touch .create_fragezeichen
	-@$(READONLY) $@

.for i in ${SOURCE_TARGETS}
.fragezeichen-$(i):	$(i)-orig
	${GREPSTRASSEN_UTF8} -special fragezeichen ${DATADIR}/$(i)-orig > /dev/null
	cp -f /tmp/fragezeichen_$(i)-orig.bbd $@
.endfor

######################################################################
# OTHER HELPER LAYERS, NOT INCLUDED IN STANDARD DIST

######################################################################
# PERSISTENT TEMPORARY DIRECTORY TARGETS

.for i in ${SOURCE_TARGETS}
${PERSISTENTTMPDIR}/.XXX-$(i):	$(i)-orig
	${GREPSTRASSEN} -adddirectives XXX ${DATADIR}/$(i)-orig > /dev/null
	cp -f /tmp/XXX_$(i)-orig.bbd $@
.endfor

${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd ${PERSISTENTTMPDIR}/.check_fragezeichen-nextcheck.bbd:	\
		Makefile \
		ampeln-orig \
		fragezeichen-orig \
		gesperrt-orig \
		qualitaet_s-orig \
		qualitaet_l-orig \
		handicap_s-orig \
		handicap_l-orig
	echo -n > ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd
	echo "#: line_dash: 8, 5" >> ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd
	echo "#:" >> ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd
.for i in ampeln-orig fragezeichen-orig gesperrt-orig qualitaet_s-orig qualitaet_l-orig handicap_s-orig handicap_l-orig
	echo "############################################################" >> ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd
	echo "# source: $(i)" >> ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd
	${GREPSTRASSEN} -directive last_checked~. -special nextcheck $(i) > /dev/null
	cat /tmp/nextcheck.bbd >> ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd
	${GREPSTRASSEN} -directive next_check~. -special nextcheck $(i) > /dev/null
	cat /tmp/nextcheck.bbd >> ${PERSISTENTTMPDIR}/fragezeichen-nextcheck.bbd
.endfor
	touch ${PERSISTENTTMPDIR}/.check_fragezeichen-nextcheck.bbd

${PERSISTENTTMPDIR}/projektierte_radstreifen.bbd:	fragezeichen-orig
	cat fragezeichen-orig | ${GREPSTRASSEN} -sectionrx "projektierte Radstreifen" | ${CONVERT2HAFAS} -basefile fragezeichen-orig > $@

${PERSISTENTTMPDIR}/strassen_in_planung.bbd:	fragezeichen-orig
	cat fragezeichen-orig | ${GREPSTRASSEN} -sectionrx "Straﬂen in Planung" | ${CONVERT2HAFAS} -basefile fragezeichen-orig > $@

${PERSISTENTTMPDIR}/XXX.bbd:	${SOURCE_TARGETS:S|^|${PERSISTENTTMPDIR}/.XXX-|}
	cat ${SOURCE_TARGETS:S|^|${PERSISTENTTMPDIR}/.XXX-|} > $@

${PERSISTENTTMPDIR}/plz-b.bbd:	$(PERSISTENTTMPDIR)/plz.sql
	grep -i berlin $> | $(MISCSRCDIR)/parse_mapbender_plz.pl > $@

$(PERSISTENTTMPDIR)/plz.sql:	$(PERSISTENTTMPDIR)/plz.zip
	cd `dirname $>` && unzip -q -o `basename $>`

$(PERSISTENTTMPDIR)/plz.zip:
	wget -O ${PERSISTENTTMPDIR}/plz.zip http://prdownloads.sourceforge.net/mapbender/plz.zip?download

${PERSISTENTTMPDIR}/Berlin.coords.bbd: Berlin.coords.data
	$(PERL) -F'\|' -nale 'print "@F[0,1,2]\tX $$F[3]" if $$F[3]' Berlin.coords.data > $@

${PERSISTENTTMPDIR}/Potsdam.coords.bbd: Potsdam.coords.data
	$(PERL) -F'\|' -nale 'print "@F[0,1,2]\tX $$F[3]" if $$F[3]' Potsdam.coords.data > $@


OPENGEODB_ORTE_ZIP=		opengeodb-0.2.4d-UTF8-text-orte.zip
OPENGEODB_ORTE_FILE=		${OPENGEODB_ORTE_ZIP:S/.zip/.txt/}
OPENGEODB_ORTE_DISTURL=	http://prdownloads.sourceforge.net/opengeodb/${OPENGEODB_ORTE_ZIP}
OPENGEODB_REGION=	BB MV
.if ${HOST} == "mom.herceg.de"
OPENGEODB_DIR=		/amd/vran/root/usr/ports/distfiles/opengeodb
.elif exists(/usr/ports/distfiles/opengeodb)
OPENGEODB_DIR=		/usr/ports/distfiles/opengeodb
.else
OPENGEODB_DIR=		${PERSISTENTTMPDIR}
.endif
OPENGEODB_ORTE_PATH=		${OPENGEODB_DIR}/${OPENGEODB_ORTE_FILE}
OPENGEODB_ORTE_ZIPPATH=	${OPENGEODB_DIR}/${OPENGEODB_ORTE_ZIP}

fetch-opengeodb:	${OPENGEODB_ORTE_ZIPPATH}
extract-opengeodb:	${OPENGEODB_ORTE_PATH}

${OPENGEODB_ORTE_ZIPPATH}:
	@echo -n "Should I fetch ${OPENGEODB_ORTE_DISTURL} to ${OPENGEODB_ORTE_ZIPPATH}? (CTRL-C to abort) "
# && true only for bugs in old pmake
	@read yn && true
	wget -O ${OPENGEODB_ORTE_ZIPPATH}~ ${OPENGEODB_ORTE_DISTURL}
	mv ${OPENGEODB_ORTE_ZIPPATH}~ ${OPENGEODB_ORTE_ZIPPATH}

${OPENGEODB_ORTE_PATH}:	${OPENGEODB_ORTE_ZIPPATH}
	cd ${OPENGEODB_DIR} && unzip ${OPENGEODB_ORTE_ZIP}
	touch ${OPENGEODB_ORTE_PATH}

persistent-tmp-from-opengeodb:	${OPENGEODB_REGION:S/^/${PERSISTENTTMPDIR}\/opengeodb-orte-/:S/$/-DE.bbd/}

.for region in BB MV
${PERSISTENTTMPDIR}/opengeodb-orte-${region}-DE.bbd:	${OPENGEODB_ORTE_PATH} ${MISCSRCDIR}/opengeodborte2bbd
	${PERL_UTF8} ${MISCSRCDIR}/opengeodborte2bbd -restrictland ${region} -restrictcountry DE ${OPENGEODB_ORTE_PATH} > $@
.endfor

# About 70 failures for now. If I correct them all, enlarge the bbox.
.check_orte_opengeodb:	orte orte2 ${PERSISTENTTMPDIR}/opengeodb-orte-BB-DE.bbd
	cat orte orte2 | grep -v '^#' | $(PERL) -pe 's{^([^\|\t]+).*}{$$1}' | sort > /tmp/orte_bbbike
	cat ${PERSISTENTTMPDIR}/opengeodb-orte-BB-DE.bbd | \
	    ${MISCSRCDIR}/restrict_bbd_data.pl -bbox -59700,60100,116500,-44900 -strdata=- -o=- | \
	    $(PERL) -pe 's{(\s*\(.*\))?\t.*}{}' | sort > /tmp/orte_opengeodb
	diff -u /tmp/orte_bbbike /tmp/orte_opengeodb | grep '^\+'

# Die mit "laut adfc-karte" u.‰. gekennzeichneten Straﬂen extrahieren und
# nach .fragezeichen-other-source schreiben.
# XXX Very strange: with db4 on RedHat 8.0 I have to use O_RDWR instead of
# O_RDONLY, otherwise the oneliner will die without an error message.
# But O_RDWR does not work if the file is read-only, so still use O_RDONLY
# Now using Tie::File, which works everywhere
.fragezeichen-other-source:	${DATADIR}/qualitaet_s-orig ${DATADIR}/qualitaet_l-orig
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
				$$x->[Strassen::NAME()] .= " ($$comment)";\
				$$x->[Strassen::CAT()] = "?";\
				print Strassen::arr2line2($$x),"\n"\
			    }\
			}\
		    }' > /tmp/other-source-fragezeichen-orig
	${CONVERT2HAFAS} -basefile ${DATADIR}/qualitaet_s-orig /tmp/other-source-fragezeichen-orig > $@

PREFIXMAP=sperr=SP,kopfstein=KP,qualit‰t=QU,m‰ﬂig.geeignet=QU,radweg=RW,benutzungspflich=RW,bau=BA,vorfahrt=VF,name=NA,bezeichn=NA,vorfahrt=VF,ampel=AM

${PERSISTENTTMPDIR}/all-upload-fragezeichen.wpt:	fragezeichen Makefile
	${MISCSRCDIR}/bbd2gpsman.pl -filter nearby=200 \
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
	${MISCSRCDIR}/restrict_bbd_data.pl \
	    ${RESTRICT_BBOX:C/(^| )/ -bbox /g} \
	    -strdata $> -o - | \
	${MISCSRCDIR}/bbd2gpsman.pl -filter nearby=200 \
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
	$(MISCSRCDIR)/check_bbbike_temp_blockings \
	    -action output_future \
	    -action dump_future_as_perl > $@
	touch .check_bbbike-temp-blockings-optimized
	-@$(READONLY) $@

# XXX Optimierungsmˆglichkeit: aus "fragezeichen" alle Strecken herausnehmen, die bereits auf Strecken in strassen+landstrassen matchen
# XXX vielleicht umbenennen: fragezeichen-approx-matches.bbd oder so
${PERSISTENTTMPDIR}/fragezeichen-matches.bbd:	fragezeichen ${DATADIR}/strassen ${DATADIR}/landstrassen ${DATADIR}/landstrassen2
	$(MISCRSRCDIR)/match_bbd_data -incatrx . -v fragezeichen ${DATADIR}/strassen ${DATADIR}/landstrassen ${DATADIR}/landstrassen2 > /tmp/fragezeichen-matches.bbd
	mv /tmp/fragezeichen-matches.bbd ${PERSISTENTTMPDIR}/fragezeichen-matches.bbd


######################################################################
# CHECKS

check-forever:
	-nice forever -30 -i make check all
	@-alarm -nicedown
	xmessage "check-forever failed"

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
	rm -f .check_* .create_*

# checks
check:	report-checks do-checks

report-checks:
	@echo Now doing checks...

do-checks:	.check_empty_lines \
	.check_strassen1 .check_strassen_cont \
	.check_plaetze1 .check_plaetze2 .check_strassen_plaetze_unique \
	.check_hoehe \
	.check_ampeln .check_gesperrt1 .check_gesperrt2 \
	.check_gesperrt_u2 .check_gesperrt_s2 .check_gesperrt_r2 \
	.check_gesperrt_car1 .check_gesperrt_car2 \
	.check_ubahnhof .check_ubahnhof2 .check_sbahnhof .check_sbahnhof2 \
	.check_rbahnhof .check_orte \
	.check_radwege .check_ampelschaltung \
	.check_qualitaet_s .check_qualitaet_l \
	.check_handicap_s .check_handicap_l \
	.check_vorfahrt \
	.check_comments1 .check_comments2 .check_nolighting \
	.check_housenumbers .check_sehenswuerdigkeit .check_green \
	.check_brunnels .check_comments_ferry \
	.check_exits \
	.check_temp_blockings \

.check_empty_lines:	*-orig
	for i in *-orig; do $(PERL) -nle '$$_ eq q{} and die $$ARGV' $$i; done

check-disabled:	.check_label

.check_strassen1:	.strassen.tmp add_str multi_bez_str-orig Berlin.coords.data
	$(CHECK_STR_PLZ) -data .strassen.tmp
	@touch $@

.check_strassen_cont:	.strassen.tmp str_cont_ausnahme
	$(CHECK_CONT) -data .strassen.tmp
	@touch $@

.check_plaetze1: plaetze .strassen.tmp landstrassen
	$(CHECK_POINTS) -catrx '^Pl$$' plaetze .strassen.tmp landstrassen
	@touch $@

.check_plaetze2: ${PERSISTENTTMPDIR}/non-faked-plaetze add_plaetze
	$(CHECK_STR_PLZ) -addstr add_plaetze -data ${PERSISTENTTMPDIR}/non-faked-plaetze -nomultibez
	@touch $@

.check_strassen_plaetze_unique:	strassen-orig plaetze-orig
	cut -d"	" -f1 strassen-orig | sort -u > /tmp/strassen-names
	cut -d"	" -f1 plaetze-orig  | sort -u > /tmp/plaetze-names
	duplicates=`sort /tmp/strassen-names /tmp/plaetze-names | grep -v '^#' | uniq -d`; \
	if [ "$$duplicates" != "" ]; then \
	    echo "Found duplicates:"; \
	    echo "$$duplicates"; \
	    false; \
	fi
	@touch $@

.check_hoehe:	hoehe .strassen.tmp landstrassen landstrassen2 fragezeichen
	$(CHECK_POINTS) -catrx '^(X|\?|\?\?\?)$$' -namerx '^\d+(\.\d+)?$$' hoehe .strassen.tmp landstrassen landstrassen2 fragezeichen
	@touch $@

.check_ampeln:	ampeln .strassen.tmp landstrassen landstrassen2 fragezeichen
	$(CHECK_POINTS) -catrx '^(X|F|B|B0|Zbr|\?)(::inwork)?$$' ampeln .strassen.tmp landstrassen landstrassen2 fragezeichen
	@touch $@

.check_ampelschaltung:	ampelschaltung-orig ampeln-orig
	$(CHECK_POINTS) -ampelschaltung ampelschaltung-orig ampeln-orig
	@touch $@

GESPERRT_CATRX='^(0:\d+(:-?\d+)?|1|1s|2|3|BNP:\d+(:-?\d+)?)(:inwork)?$$'

.check_gesperrt1:	gesperrt .strassen.tmp landstrassen landstrassen2
	$(CHECK_POINTS) -catrx $(GESPERRT_CATRX) gesperrt .strassen.tmp landstrassen landstrassen2
	@touch $@

# Second check is necessary because of the 3nocross entries!
# For the second check we could do a "grepstrassen -cat 3nocross" first
.check_gesperrt2:	gesperrt strassen landstrassen landstrassen2
	$(CHECK_NEIGHBOUR) -type standard -data gesperrt \
		-against strassen -against landstrassen -against landstrassen2
	$(CHECK_NEIGHBOUR) -type standard -data gesperrt-orig \
		-against strassen -against landstrassen -against landstrassen2
	@touch $@

.for i in u s r
.check_gesperrt_$(i)2:	gesperrt_$(i) $(i)bahn
	$(CHECK_NEIGHBOUR) -type standard -data gesperrt_$(i) \
		-against $(i)bahn
	@touch $@
.endfor

.check_gesperrt_car1:	gesperrt_car .strassen.tmp landstrassen landstrassen2
	$(CHECK_POINTS) -catrx $(GESPERRT_CATRX) gesperrt_car .strassen.tmp landstrassen landstrassen2
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
	    $(SORT_NO_LOCALE) -u > /tmp/$(i)bahnhof1
	grep -i '^$(i)-Bhf' Berlin.coords.data |\
	    egrep -v 'S-Bhf (F¸rstenbrunn)' |\
	    egrep -v 'U-Bhf (Hauptbahnhof|Unter den Linden|Bundestag)' |\
	    $(SED) -e 's/ *(.*)//' -e 's/S-Bhf //' -e 's/U-Bhf //' -e 's/|.*//' |\
	    $(SORT_NO_LOCALE) -u > /tmp/$(i)bahnhof2
	diff /tmp/$(i)bahnhof1 /tmp/$(i)bahnhof2
	@touch $@
.endfor

.check_rbahnhof:	rbahnhof rbahn
	$(CHECK_STATION_CATEGORY) -special noinwork rbahnhof-orig rbahn
	@touch $@

.check_orte: orte orte2 orte_city
	$(CHECK_DOUBLE) orte orte2 orte_city
	@touch $@

.check_radwege:	radwege_exact strassen
	$(CHECK_NEIGHBOUR) -type standard -data radwege_exact
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

.check_handicap_s:	handicap_s strassen
	$(CHECK_NEIGHBOUR) -type standard -data handicap_s
	@touch $@

.check_handicap_l:	handicap_l landstrassen landstrassen2
	$(CHECK_NEIGHBOUR) -type standard -data handicap_l \
		-against landstrassen -against landstrassen2
	@touch $@

.check_label:	label .strassen.tmp landstrassen landstrassen2
	$(CHECK_POINTS) label .strassen.tmp landstrassen landstrassen2
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

.check_comments_ferry:	comments_ferry faehren
	$(CHECK_NEIGHBOUR) -type standard -against faehren -data comments_ferry
	@touch $@

.check_nolighting:	nolighting strassen
	$(CHECK_NEIGHBOUR) -type standard -data nolighting
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

.check_brunnels:	brunnels strassen landstrassen landstrassen2 wasserstrassen wasserumland wasserumland2 fragezeichen
	$(CHECK_NEIGHBOUR) -type standard -data brunnels \
	    -against strassen -against landstrassen -against landstrassen2 \
	    -against wasserstrassen -against wasserumland -against wasserumland2 \
	    -against fragezeichen
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
	@touch $@

.check_temp_blockings:	temp_blockings/*.bbd $(PERSISTENTTMPDIR)/bbbike-temp-blockings.bbd \
			strassen landstrassen landstrassen2 faehren
	cat temp_blockings/*.bbd > /tmp/all_temp_blockings.bbd
	cat $(PERSISTENTTMPDIR)/bbbike-temp-blockings.bbd >> /tmp/all_temp_blockings.bbd
	$(CHECK_NEIGHBOUR) -type standard -data /tmp/all_temp_blockings.bbd \
		-against strassen -against landstrassen -against landstrassen2 \
		-against faehren
	rm -f /tmp/all_temp_blockings.bbd
	@touch $@

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
	@echo -n "Berlin:      "; grep -v "^(" strassen | cut -f1 -d"(" | sort -u | wc -l
	@echo -n "Potsdam:     "; fgrep "(Potsdam)" landstrassen | grep -v "^(" | cut -f1 -d"(" | sort -u | wc -l
	@echo -n "Landstraﬂen: "; grep -v "^#" landstrassen landstrassen2 | cut -f1 | sort -u | wc -l

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

.check_categories:	${TARGETS}
	@echo "Check categories..."
.for target in ${TARGETS}
	@echo " ${target}"
	@$(PERL_UTF8) -I../lib -I.. -MStrassen::Cat -e '\
	    if ($$ARGV[0] =~ m{^(ampelschaltung|multi_bez_str|.*/bbbike-temp-blockings-optimized.pl|kneipen)$$}) {\
		print "  Skip $$ARGV[0]...\n";\
		exit 0;\
	    }\
	    exit !Strassen::Cat::check_file($$ARGV[0]);\
	' ${target}
.endfor
	touch $@

${PERSISTENTTMPDIR}/crossings.bbd:	strassen landstrassen landstrassen2 \
					brunnels
	${MISCSRCDIR}/check_crossings -v \
	    -o $@~ -against brunnels \
	    strassen landstrassen landstrassen2
	mv $@~ $@

# XXX ¸berirdische U-Bahnen?
# XXX Andreaskreuz
${PERSISTENTTMPDIR}/crossings_bahn.bbd:	strassen sbahn rbahn brunnels
	${MISCSRCDIR}/check_crossings -v \
	    -o $@~ -against brunnels \
	    strassen sbahn rbahn
	mv $@~ $@

# Note also the empty string in the -ignore option!
${PERSISTENTTMPDIR}/crossings_gewaesser.bbd:	\
					strassen wasserstrassen brunnels
	${MISCSRCDIR}/check_crossings -v \
	    -ignore "Fasaneriegraben,Packereigraben,Tr‰nkegraben,Teufelsseekanal,(See im Tiergarten),,Luiseninsel,Fennpfuhl,Heidekampgraben,Karpfenteich,Panke,Nordgraben,Tegeler Flieﬂ,Hermsdorfer See,Wuhle,Neue Wuhle,Flutgraben,Kreuzgraben,Zingergraben,Iderfenngraben,B‰ke,Bullengraben,Spektegraben" \
	    -o $@~ -against brunnels \
	    strassen wasserstrassen
	mv $@~ $@

${PERSISTENTTMPDIR}/crossings_gewaesser_ignore.bbd:	\
					strassen wasserstrassen brunnels
	${MISCSRCDIR}/check_crossings -v \
	    -o $@~ -against brunnels \
	    strassen wasserstrassen
	mv $@~ $@

## Einzeiler zum Extrahieren einer Postleitzahl:
# perl -F'\|' -nale '$F[2] == 12489 and $F[3] and print "$F[0] $F[1]\tX $F[3]"' Berlin.coords.data > /tmp/12489.bbd

check-coords.data:	check-Berlin.coords.data check-Potsdam.coords.data

.for city in Berlin Potsdam
check-$(city).coords.data:	.check_$(city)_coords_data

# Check for sortedness and unique records:
.check_$(city)_coords_data:: $(city).coords.data
	$(SORT_NO_LOCALE) ${COORDS_DATA_SORT_OPTS} -c $(city).coords.data || \
	    ( $(SORT_NO_LOCALE) ${COORDS_DATA_SORT_OPTS} $(city).coords.data | diff -u - $(city).coords.data; false )
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
	cut -d'|' -f2 Berlin.coords.data | sort -u |\
	    $(PERL) -I.. -MGeography::Berlin_DE -nle \
		'BEGIN { %cp = map {($$_,1)} Geography::Berlin_DE->get_all_subparts } !exists $$cp{$$_} and die "<$$_> not a citypart of Berlin"'
	@touch $@

.check_Berlin_coords_data_zip: Berlin.coords.data
	cut -d'|' -f3 Berlin.coords.data | sort -u |\
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
	${MISCSRCDIR}/check_nearest -ignore check_nearest_ignore \
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
	     iterate { ($$dist) = $$_->[Strassen::NAME] =~ /^\S+\s+(\d+)/; die "Distance $$dist m found" if $$dist < 20 } $$s' ${PERSISTENTTMPDIR}/check_nearest.bbd

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
# Berlin.coords.data etc. targets

sort-coords.data:	sort-Berlin.coords.data sort-Potsdam.coords.data

.for city in Berlin Potsdam
sort-$(city).coords.data:
	[ "`uname`" = FreeBSD ] && true || (echo "Sorting probably not correct on `uname`"; false)
	-@$(WRITEABLE) $(city).coords.data~
	mv $(city).coords.data $(city).coords.data~
	$(SORT_NO_LOCALE) ${COORDS_DATA_SORT_OPTS} < $(city).coords.data~ > $(city).coords.data
	@$(READABLE) $(city).coords.data
	touch .check_$(city)_coords_data
.endfor


######################################################################
# TEMPORARY BLOCKINGS LAYER

temp_blockings/bbbike-temp-blockings.yml: temp_blockings/bbbike-temp-blockings.pl
	$(PERL) -MYAML -e '\
	    $$YAML::UseBlock = 1;\
	    do $$ARGV[0];\
	    die 1 if not @temp_blocking;\
	    YAML::DumpFile($$ARGV[1], \@temp_blocking);\
	' $> $@~
	$(PERL) -MData::Compare -MData::Dumper -MYAML -e '\
	    do $$ARGV[0];\
	    $$y = YAML::LoadFile($$ARGV[1]);\
	    die 2 if not @temp_blocking;\
	    $$Data::Dumper::Sortkeys = 1;\
	    if (not Compare(\@temp_blocking, $$y)) {\
	        open(F1, "> /tmp/1"); print F1 Data::Dumper->new([\@temp_blocking],[])->Dump; \
	        open(F2, "> /tmp/2"); print F2 Data::Dumper->new([$$y],[])->Dump; \
		system("diff -u /tmp/1 /tmp/2 | less"); \
	    }\
	' $> $@~
	mv -f $@~ $@
	@$(READABLE) $@

$(PERSISTENTTMPDIR)/bbbike-temp-blockings.bbd: temp_blockings/bbbike-temp-blockings.yml
	$(PERL) -MYAML -e '\
		$$x = YAML::LoadFile($$ARGV[0]);\
		for (@$$x) {\
		    $$d = $$_->{data};\
		    next if not $$d;\
		    $$t = $$_->{text};\
		    $$t =~ s/[\n\t]/ /g;\
		    $$d =~ s/^/$$t /gm;\
		    print $$d;\
		}\
	' $> > $@

######################################################################
# CGPSMAPPER TARGETS

.if exists(/usr/local/bin/cgpsmapper-static)
CGPSMAPPER?=	/usr/local/bin/cgpsmapper-static
.elif exists(/usr/ports/distfiles/from_vran/cgpsmapper/cgpsmapper0081static)
CGPSMAPPER?=	/usr/ports/distfiles/from_vran/cgpsmapper/cgpsmapper0081static
.else
CGPSMAPPER?=	/usr/ports/distfiles/cgpsmapper/cgpsmapper0081static
.endif

.if exists(/usr/local/bin/sendmap17Lstatic)
SENDMAP?=	/usr/local/bin/sendmap17Lstatic
.elif exists(/usr/ports/distfiles/from_vran/cgpsmapper/sendmap17Lstatic)
SENDMAP?=	/usr/ports/distfiles/from_vran/cgpsmapper/sendmap17Lstatic
.else
SENDMAP?=	/usr/ports/distfiles/cgpsmapper/sendmap17Lstatic
.endif

.if ${HOST} == "devpc01.iconmobile.de"
# for some reason 115200 does not work...
SENDMAP_ARGS?=	-s57600
.else
SENDMAP_ARGS?=
.endif

# cuaa0 on *BSD, ttyS0 on Linux
.if exists(/dev/cuaa0)
GPSPORT?=	/dev/cuaa0
.else
GPSPORT?=	/dev/ttyS0
.endif

BBD2POLISH?=	${MISCSRCDIR}/bbd2polish

CGPSMAPPER_FILES=	bbbike brb wide fragezeichen
CGPSMAPPER_MP_FILES=	${CGPSMAPPER_FILES:S/$/.mp/:S/^/${PERSISTENTTMPDIR}\//}
CGPSMAPPER_IMG_FILES=	${CGPSMAPPER_FILES:S/$/.img/:S/^/${PERSISTENTTMPDIR}\//}

cgpsmapper-output:	${CGPSMAPPER_MP_FILES}

cgpsmapper-images:	${CGPSMAPPER_IMG_FILES}

cgpsmapper-upload:	cgpsmapper-images
	@echo "Approx. upload time: half an hour for 1,7 MB data"
	-${SENDMAP} ${GPSPORT} ${SENDMAP_ARGS} ${CGPSMAPPER_IMG_FILES}

${PERSISTENTTMPDIR}/bbbike.mp:	${BBD2POLISH} \
				strassen wasserstrassen flaechen sbahn ubahn berlin faehren fragezeichen
	${BBD2POLISH} -mapset b > $@

${PERSISTENTTMPDIR}/brb.mp:	${BBD2POLISH} \
				orte landstrassen wasserumland rbahn potsdam
	${BBD2POLISH} -mapset brb > $@

${PERSISTENTTMPDIR}/wide.mp:	${BBD2POLISH} \
				orte2 landstrassen2 wasserumland2 deutschland
	${BBD2POLISH} -mapset wide > $@

${PERSISTENTTMPDIR}/fragezeichen.mp:	${BBD2POLISH} \
				fragezeichen
	${BBD2POLISH} -mapset fragezeichen > $@

.for i in ${CGPSMAPPER_FILES}
${PERSISTENTTMPDIR}/$i.img: ${PERSISTENTTMPDIR}/$i.mp
	-${CGPSMAPPER} ${PERSISTENTTMPDIR}/$i.mp
.endfor

######################################################################

.include "Makefile.mapfiles"
