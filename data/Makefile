#
# $Id: Makefile,v 2.37 2004/12/29 21:48:52 eserte Exp $
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
GREPSTRASSEN=		${MISCSRCDIR}/grepstrassen
COMBINE_STREETS=	${MISCSRCDIR}/combine_streets.pl

COMMENTS_PARTIAL=	comments_cyclepath comments_ferry comments_misc \
			comments_mount comments_path comments_route \
			comments_tram comments_kfzverkehr

SOURCE_TARGETS=		strassen plaetze landstrassen landstrassen2 flaechen
SOURCE_TARGETS+=	wasserstrassen wasserumland wasserumland2
SOURCE_TARGETS+=	sbahn sbahnhof rbahn
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
SOURCE_TARGETS+=	${COMMENTS_PARTIAL} fragezeichen exits

# These do not have a -orig file of their own
COMPUTED_TARGETS=	sbahnhof_bg ubahnhof_bg rbahnhof berlin
COMPUTED_TARGETS+=	radwege_exact mount
COMPUTED_TARGETS+=	temp_blockings/bbbike-temp-blockings-optimized.pl

COOKED_TARGETS=		strassen-cooked landstrassen-cooked landstrassen2-cooked
TARGETS+=	${SOURCE_TARGETS} ${COMPUTED_TARGETS} ${COOKED_TARGETS}

ALL_STREETS=		strassen landstrassen landstrassen2

TARGETS_DISABLED=	label relation_gps 

WRITEABLE=	chmod u+w,ugo+r
READONLY=	chmod ugo+r,ugo-w

## XXX what is write, what is wrong?
#COORDS_DATA_SORT_OPTS=	-f -t "|" -k 1,3
COORDS_DATA_SORT_OPTS=

all:	targets check .modified .rsync_include make_misc

# These targets have to be rebuild once a day
.BEGIN:
	@perl -e 'for (@ARGV) { do { unlink($$_) and warn "Removed $$_\n" } if (-M $$_ >= 1) }' \
		.check_bbbike-temp-blockings-optimized .check_dates

targets:	${TARGETS}

targets-clean:
	mv -f ${TARGETS} /tmp

# Useful checks, but normally too slow for a quick build
# XXX merge with sort-Berlin.coords.data rule below?
slow-checks:	inaccessible_strassen inaccessible_landstrassen \
		check-line-lengths check-dates check-Berlin.coords.data \
		persistent-tmp

persistent-tmp:	${PERSISTENTTMPDIR}/projektierte_radstreifen.bbd \
		${PERSISTENTTMPDIR}/strassen_in_planung.bbd \
		${PERSISTENTTMPDIR}/all-upload-fragezeichen.wpt \
		${PERSISTENTTMPDIR}/my-upload-fragezeichen.wpt

# even slower (about four minutes)
really-slow-checks:	check-crossings check-nearest

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

strassen:	.strassen.tmp plaetze
	-@$(WRITEABLE) $@
	cat $> > $@
	-rm -f strassen-cooked
	-@$(READONLY) $@

.strassen.tmp: strassen-orig
	$(CONVERT2HAFAS) strassen-orig > $@~
	cp $@~ $@
	rm $@~

.for f in ${COOKED_TARGETS}
_f_raw_${f}:=${f:S/-cooked$//}
$f:	${_f_raw_${f}} inaccessible_landstrassen
	-@${WRITEABLE} $@
	perl -I${BBBIKEDIR} -I${BBBIKEDIR}/lib -MStrassen -e \
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
	$(CONVERT2HAFAS) landstrassen-orig > $@~
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

# Get categories with:
# perl -nle '/\t(\S+)/ && print $1' sbahn | sort -u
SBAHN_CATEGORIES=	SA SB SC S0

sbahn: sbahn-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) sbahn-orig > /tmp/sbahn
.for cat in $(SBAHN_CATEGORIES)
	$(GREPSTRASSEN) -cat $(cat) /tmp/sbahn | ../miscsrc/merge_overlapping_streets.pl -sep "," - | $(COMBINE_STREETS) - | sort > /tmp/sbahn-$(cat)
.endfor
	cat $(SBAHN_CATEGORIES:S/^/\/tmp\/sbahn-/) > sbahn
	-@$(READONLY) $@

sbahnhof:	sbahnhof-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) sbahnhof-orig > sbahnhof
	-@$(READONLY) $@

## Execute from bbbike root directory (evtl. mehrmals):
# cp -f data/Berlin.coords.data /tmp
# perl -Ilib -MObject::Iterate=iterate -MStrassen::Core -MTie::File -e '$s = Strassen->new("sbahnhof"); iterate { $p{$_->[Strassen::NAME]} = $_->[Strassen::COORDS][0] } $s; tie @f, "Tie::File", "/tmp/Berlin.coords.data" or die ; for (@f) { if (/^S-Bhf (.*?)\|.*\|$/ && $p{$1}) { $_ .= $p{$1}; warn "$1 $p{$1}" } }'

# See SBAHN_CATEGORIES comment
RBAHN_CATEGORIES=	RA RB RC R R0

rbahn rbahnhof: rbahn-orig
	-@$(WRITEABLE) rbahn rbahnhof
	$(CONVERT2HAFAS) -bahnhof=rbahnhof rbahn-orig > /tmp/rbahn
.for cat in $(RBAHN_CATEGORIES)
	$(GREPSTRASSEN) -cat $(cat) /tmp/rbahn | ../miscsrc/merge_overlapping_streets.pl -sep "," - | $(COMBINE_STREETS) - | sort > /tmp/rbahn-$(cat)
.endfor
	cat $(RBAHN_CATEGORIES:S/^/\/tmp\/rbahn-/) > rbahn
	-@$(READONLY) rbahn rbahnhof

ubahn: ubahn-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) ubahn-orig > ubahn
	-@$(READONLY) $@

ubahnhof:	ubahnhof-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) ubahnhof-orig > ubahnhof
	-@$(READONLY) $@

## Execute from bbbike root directory (evtl. mehrmals):
# cp -f data/Berlin.coords.data /tmp
# perl -Ilib -MObject::Iterate=iterate -MStrassen::Core -MTie::File -e '$s = Strassen->new("ubahnhof"); iterate { $p{$_->[Strassen::NAME]} = $_->[Strassen::COORDS][0] } $s; tie @f, "Tie::File", "/tmp/Berlin.coords.data" or die $!; for (@f) { if (/^U-Bhf (.*?)\|.*\|$/ && $p{$1}) { $_ .= $p{$1}; warn "$1 $p{$1}" } }'

.for i in u s
$(i)bahnhof_bg:	$(i)bahnhof-orig
	-@$(WRITEABLE) $@
	perl -I../lib -I.. -MStrassen::Core -MObject::Iterate=iterate -e '\
	$$s=Strassen->new(shift, UseLocalDirectives => 1);\
	$$new_s=Strassen->new;\
	iterate {\
	    my $$attr = $$s->get_directive($$s->pos)->{attributes};\
	    if ($$attr) {\
		if ($$attr =~ s/\s+\((.*)\)//) {\
	            $$_->[Strassen::NAME] .= ": $$1";\
		}\
	        $$_->[Strassen::CAT] = $$attr;\
	        $$new_s->push($$_);\
	    }\
	} $$s;\
	print $$new_s->as_string' $> > $@
	-@$(READONLY) $@
.endfor

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
	$(CONVERT2HAFAS) -specsperre=strassen,landstrassen,landstrassen2 gesperrt-orig > $@~
	cp $@~ $@
	rm $@~
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
	${MISCSRCDIR}/convert_radwege < radwege-orig | $(COMBINE_STREETS) - > radwege
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

.for f in ${COMMENTS_PARTIAL}
${f}: ${f}-orig ${ALL_STREETS}
	-@$(WRITEABLE) $@
	cat ${f}-orig | $(CONVERT2HAFAS) -basefile ${f}-orig - | \
	    $(RESOLVE_STARS) ${ALL_STREETS} - > $@~ && \
	mv $@~ $@
	-@$(READONLY) $@
.endfor

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

exits:	exits-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) $> > $@
	-@$(READONLY) $@

# ::inwork => will maybe change to :inwork
#XXX in "-orig" transition: handicap_s-orig and gesperrt-orig always need to have the same base map!
fragezeichen:	fragezeichen-orig ${DATADIR}/ampeln-orig \
		.fragezeichen-other-source \
		${SOURCE_TARGETS:S|^|.fragezeichen-|}
	-@$(WRITEABLE) $@
	cat fragezeichen-orig |\
	        ${GREPSTRASSEN} -v -sectionrx "projektierte Radstreifen" |\
	        ${GREPSTRASSEN} -v -sectionrx "Straﬂen in Planung" |\
	    ${CONVERT2HAFAS} -basefile fragezeichen-orig > $@
	grep '?' ${DATADIR}/ampeln-orig | \
	    ${CONVERT2HAFAS} -basefile ${DATADIR}/ampeln-orig -- - >> $@
	${MISCSRCDIR}/temporary_streets.pl \
	    ${DATADIR}/handicap_s-orig ${DATADIR}/gesperrt-orig | \
	    perl -nle '/(.*\t)(\S+)(.*)/ && !/\b(\d{4}-\d{2}-\d{2}|[0123]?\d\.[01]?\d\.\d{4})\b/ && print "Noch immer? $$1?::inwork$$3"' | \
	    ${CONVERT2HAFAS} -basefile ${DATADIR}/handicap_s-orig -- - >> $@
	cat .fragezeichen-other-source >> $@
.for i in ${SOURCE_TARGETS:S|^|.fragezeichen-|}
	cat $(i) >> $@
.endfor
	-@$(READONLY) $@

.for i in ${SOURCE_TARGETS}
.fragezeichen-$(i):	$(i)-orig
	${GREPSTRASSEN} -special fragezeichen ${DATADIR}/$(i)-orig > /dev/null
	cp -f /tmp/fragezeichen_$(i)-orig.bbd $@
.endfor

${PERSISTENTTMPDIR}/projektierte_radstreifen.bbd:	fragezeichen-orig
	cat fragezeichen-orig | ${GREPSTRASSEN} -sectionrx "projektierte Radstreifen" | ${CONVERT2HAFAS} -basefile fragezeichen-orig > $@

${PERSISTENTTMPDIR}/strassen_in_planung.bbd:	fragezeichen-orig
	cat fragezeichen-orig | ${GREPSTRASSEN} -sectionrx "Straﬂen in Planung" | ${CONVERT2HAFAS} -basefile fragezeichen-orig > $@

# Die mit "laut adfc-karte" u.‰. gekennzeichneten Straﬂen extrahieren und
# nach .fragezeichen-other-source schreiben.
# XXX Very strange: with db4 on RedHat 8.0 I have to use O_RDWR instead of
# O_RDONLY, otherwise the oneliner will die without an error message.
# But O_RDWR does not work if the file is read-only, so still use O_RDONLY
# Now using Tie::File, which works everywhere
.fragezeichen-other-source:	${DATADIR}/qualitaet_s-orig ${DATADIR}/qualitaet_l-orig
	cd ${DATADIR} && \
	    perl -I${BBBIKEDIR} -I${BBBIKEDIR}/lib \
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

${PERSISTENTTMPDIR}/my-upload-fragezeichen.wpt:	fragezeichen Makefile
	${MAKE} /tmp/upload-restricted-fragezeichen.wpt \
	    RESTRICT_BBOX="-8250,2025,-15000,-2675 16500,15375,4625,8125"
	cp -pf /tmp/upload-restricted-fragezeichen.wpt $@

temp_blockings/bbbike-temp-blockings-optimized.pl:	temp_blockings/bbbike-temp-blockings.pl .check_bbbike-temp-blockings-optimized
	-@$(WRITEABLE) $@
	$(MISCSRCDIR)/check_bbbike_temp_blockings \
	    -action output_future \
	    -action dump_future_as_perl > $@
	touch .check_bbbike-temp-blockings-optimized
	-@$(READONLY) $@

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

# Makefile in ../misc ausf¸hren
# drat ... ich mˆchte nicht gmake verwenden :-(
make_misc:
	cd $(MISCDIR) && ${MAKE} ${MAKEFLAGS} 

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
check:	report-checks do-checks

report-checks:
	@echo Now doing checks...

do-checks:	.check_strassen1 .check_strassen2 \
	.check_plaetze1 .check_plaetze2 .check_strassen_plaetze_unique \
	.check_hoehe \
	.check_ampeln .check_gesperrt1 .check_gesperrt2 \
	.check_gesperrt_u2 .check_gesperrt_s2 .check_gesperrt_r2 \
	.check_gesperrt_car1 .check_gesperrt_car2 \
	.check_ubahnhof .check_sbahnhof .check_orte \
	.check_radwege .check_ampelschaltung \
	.check_qualitaet_s .check_qualitaet_l \
	.check_handicap_s .check_handicap_l \
	.check_vorfahrt \
	.check_comments1 .check_comments2 .check_nolighting \
	.check_housenumbers .check_sehenswuerdigkeit .check_green \
	.check_brunnels .check_comments_ferry \
	.check_exits \
	.check_temp_blockings \

check-disabled:	.check_label

.check_strassen1:	.strassen.tmp add_str multi_bez_str Berlin.coords.data
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

.check_strassen_plaetze_unique:	strassen-orig plaetze-orig
	cut -d"	" -f1 strassen-orig | sort -u > /tmp/strassen-names
	cut -d"	" -f1 plaetze-orig  | sort -u > /tmp/plaetze-names
	duplicates=`sort /tmp/strassen-names /tmp/plaetze-names | uniq -d`; \
	if [ "$$duplicates" != "" ]; then \
	    echo "Found duplicates:"; \
	    echo "$$duplicates"; \
	    false; \
	fi
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

.check_vorfahrt:	vorfahrt strassen landstrassen landstrassen2
	$(CHECK_NEIGHBOUR) -type standard -data vorfahrt \
		-against strassen -against landstrassen -against landstrassen2
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
	$(CHECK_POINTS) housenumbers .strassen.tmp
	@touch $@

.check_sehenswuerdigkeit:	sehenswuerdigkeit
	$(CHECK_IMAGES) sehenswuerdigkeit
	@touch $@

.check_green:	green strassen landstrassen
	$(CHECK_NEIGHBOUR) -type standard -data green \
		-against strassen -against landstrassen
	@touch $@

.check_brunnels:	brunnels strassen landstrassen landstrassen2 wasserstrassen wasserumland wasserumland2
	$(CHECK_NEIGHBOUR) -type standard -data brunnels \
	    -against strassen -against landstrassen -against landstrassen2 \
	    -against wasserstrassen -against wasserumland -against wasserumland2
	@touch $@

.check_exits:	exits \
		ubahnhof sbahnhof rbahnhof \
		.strassen.tmp landstrassen landstrassen2
	perl -I../lib -I.. -MStrassen::Core -MObject::Iterate=iterate -e '\
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

.check_temp_blockings:	temp_blockings/*.bbd strassen
	cat temp_blockings/*.bbd > /tmp/all_temp_blockings.bbd
	$(CHECK_NEIGHBOUR) -type standard -data /tmp/all_temp_blockings.bbd -against strassen -against landstrassen -against landstrassen2
	rm -f /tmp/all_temp_blockings.bbd
	@touch $@

#.PHONY: .modified

# This also creates .rsync_include
.modified:	${TARGETS}
	${MISCSRCDIR}/create_modified

sort-Berlin.coords.data:
	mv Berlin.coords.data Berlin.coords.data~
	env LC_ALL=de_DE.ISO_8859-1 sort ${COORDS_DATA_SORT_OPTS} < Berlin.coords.data~ > Berlin.coords.data
	touch .check_Berlin_coords_data

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
	@echo -n "Berlin:  "; grep -v "^(" strassen | cut -f1 -d"(" | sort -u | wc -l
	@echo -n "Potsdam: "; fgrep "(Potsdam)" landstrassen | grep -v "^(" | cut -f1 -d"(" | sort -u | wc -l

check-dates:	.check_dates

.check_dates:	*-orig ${MISCSRCDIR}/check_dates
	@echo Expired today:
	@${MISCSRCDIR}/check_dates *-orig
	@echo Expired in the next two weeks:
	@${MISCSRCDIR}/check_dates -reldays 14 *-orig
	@touch $@

check-crossings:	.check_crossings

.check_crossings:	strassen landstrassen landstrassen2 brunnels
	${MISCSRCDIR}/check_crossings -v \
	    -o /tmp/crossings.bbd -against brunnels \
	    strassen landstrassen landstrassen2
	@touch $@

## Einzeiler zum Extrahieren einer Postleitzahl:
# perl -F'\|' -nale '$F[2] == 12489 and $F[3] and print "$F[0] $F[1]\tX $F[3]"' Berlin.coords.data > /tmp/12489.bbd

check-Berlin.coords.data:	.check_Berlin_coords_data

.check_Berlin_coords_data: Berlin.coords.data
	env LC_ALL=de_DE.ISO_8859-1 sort ${COORDS_DATA_SORT_OPTS} -c Berlin.coords.data || \
	    ( env LC_ALL=de_DE.ISO_8859-1 sort ${COORDS_DATA_SORT_OPTS} Berlin.coords.data | diff -u - Berlin.coords.data; false )
	@touch $@

check-nearest:	${PERSISTENTTMPDIR}/check_nearest.bbd do-check-nearest

${PERSISTENTTMPDIR}/check_nearest.bbd:	strassen landstrassen landstrassen2 fragezeichen brunnels faehren
	${MISCSRCDIR}/check_nearest -asbbd \
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
	perl -I${BBBIKEDIR} -I${BBBIKEDIR}/lib \
	    -MStrassen -MObject::Iterate=iterate -e \
	    '$$s = Strassen->new($$ARGV[0]);\
	     iterate { ($$dist) = $$_->[Strassen::NAME] =~ /^\S+\s+(\d+)/; die "Distance $$dist m found" if $$dist < 14 } $$s' ${PERSISTENTTMPDIR}/check_nearest.bbd

GNUmakefile: Makefile ../miscsrc/b2gmake
	../miscsrc/b2gmake < Makefile > GNUmakefile
	chmod ugo+r GNUmakefile

GNUmakefile.mapfiles: Makefile.mapfiles ../miscsrc/b2gmake
	../miscsrc/b2gmake < Makefile.mapfiles > GNUmakefile.mapfiles
	chmod ugo+r GNUmakefile.mapfiles

######################################################################
# Temporary rules

temp_blockings/bbbike-temp-blockings.yml: temp_blockings/bbbike-temp-blockings.pl
	perl -MYAML -e '$$YAML::UseBlock = 1; do $$ARGV[0]; die if not @temp_blocking; YAML::DumpFile($$ARGV[1], \@temp_blocking)' $> $@
	perl -MData::Compare -MYAML -e 'do $$ARGV[0]; die if not @temp_blocking; die if not Compare(\@temp_blocking, YAML::LoadFile($$ARGV[1]))' $> $@

######################################################################

.include "Makefile.mapfiles"
