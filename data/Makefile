#
# $Id: Makefile,v 2.23 2004/07/22 21:26:46 eserte Exp $
#

BBBIKEDIR=		..
MISCDIR=		$(BBBIKEDIR)/misc
MISCSRCDIR=		$(BBBIKEDIR)/miscsrc
DATADIR=		.

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

TARGETS=	strassen plaetze landstrassen landstrassen2 flaechen
TARGETS+=	wasserstrassen wasserumland wasserumland2
TARGETS+=	sbahn sbahnhof sbahnhof_bg rbahn rbahnhof
TARGETS+=	ubahn ubahnhof ubahnhof_bg
TARGETS+=	faehren hoehe orte orte2 orte_city ampeln ampelschaltung
TARGETS+=	plz berlin potsdam deutschland
TARGETS+=	sehenswuerdigkeit obst radwege radwege_exact
TARGETS+=	qualitaet_s qualitaet_l
TARGETS+=	handicap_s handicap_l
TARGETS+=	vorfahrt nolighting
TARGETS+=	housenumbers green brunnels mount
TARGETS+=	gesperrt gesperrt_car
.for i in u s r
TARGETS+=	gesperrt_$(i)
.endfor
TARGETS+=	${COMMENTS_PARTIAL} fragezeichen

TARGETS_DISABLED=	label relation_gps 

WRITEABLE=	chmod u+w,ugo+r
READONLY=	chmod ugo+r,ugo-w

## XXX what is write, what is wrong?
#COORDS_DATA_SORT_OPTS=	-f -t "|" -k 1,3
COORDS_DATA_SORT_OPTS=

all:	targets check .modified .rsync_include make_misc

targets:	${TARGETS}

targets-clean:
	mv -f ${TARGETS} /tmp

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

.strassen.tmp: strassen-orig
	$(CONVERT2HAFAS) strassen-orig > $@ || (rm -f .strassen.tmp; false)

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
	$(CONVERT2HAFAS) landstrassen-orig > landstrassen
	-@$(READONLY) $@

landstrassen2: landstrassen2-orig
	-@$(WRITEABLE) $@
	$(CONVERT2HAFAS) landstrassen2-orig > landstrassen2
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
	.check_temp_blockings \

check-disabled:	.check_label

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

# XXX against landstrassen, too?
.check_brunnels:	brunnels strassen landstrassen landstrassen2
	$(CHECK_NEIGHBOUR) -type standard -data brunnels \
	    -against strassen -against landstrassen -against landstrassen2
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
	env LC_ALL=de_DE.ISO_8859-1 sort ${COORDS_DATA_SORT_OPTS} -c Berlin.coords.data || \
	    ( env LC_ALL=de_DE.ISO_8859-1 sort ${COORDS_DATA_SORT_OPTS} Berlin.coords.data | diff -u - Berlin.coords.data; false )
	@touch $@

check-nearest:
	${MISCSRCDIR}/check_nearest strassen

GNUmakefile: Makefile ../miscsrc/b2gmake
	../miscsrc/b2gmake < Makefile > GNUmakefile
	chmod ugo+r GNUmakefile

GNUmakefile.mapfiles: Makefile.mapfiles ../miscsrc/b2gmake
	../miscsrc/b2gmake < Makefile.mapfiles > GNUmakefile.mapfiles
	chmod ugo+r GNUmakefile.mapfiles

.include "Makefile.mapfiles"
