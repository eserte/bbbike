#
# $Id: Makefile,v 1.20 2004/06/10 07:26:59 eserte Exp $
#

# See also comments in correct_data.pl

#   Analyse der Dateien, die korrigiert werden müssen #######################
#
#   Bereits Dateien im GPS-Format:
#   - misc/mps_examples: sind GPS-Daten, also bereits "korrigiert"
#   - misc/geonet: sind GPS-Daten
#   - misc/gps_data: sind GPS-Daten
#   - misc/gelbeseiten: Daten innerhalb Berlins, ausserdem mit Telbuch*.pm
#     erzeugt, also GPS-Daten
#   - miscsrc/senat_b: sind GPS- oder Vermessungsdaten
#
#   Dateien, die nicht konvertiert werden brauchen:
#   - ampelschaltung-orig und ampelschaltung-orig.txt, da es sich um reine
#     Berliner Daten handelt
#   - misc/old: ist alt, kann also ignoriert werden
#   - misc/*.bbd: bis auf weblinks.bbd handelt es sich um Berliner Daten.
#     weblinks.bbd ist sowieso recht ungenau, aber trotzdem einmalig
#     eine Probekorrektur vornehmen
#   - miscsrc/condat/kinos.bbd: alt, kann ignoriert werden
#   - tmp: kann ignoriert werden, -uncorrected-Dateien könnten danach
#     gelöscht werden
#   - babybike/data/fragezeichen.bbd: ein symlink
#   - projects/radlstadtplan_muenchen: ignorieren
#   - projects/solarmove/data: innerhalb Berlins, muss nicht konvertiert
#     werden
#   - projects/www.radzeit.de: wird von data etc. kopiert
#   - misc/sternfahrt_2003: lohnt nicht mehr (?), sind nach der großen
#     Konvertierung also "falsch" --- trotzdem versuchen
#
#   Dateien, für die eine Konvertierung vorhanden und getestet ist:
#
#   Dateien, für die eine Konvertierung vorhanden und NICHT getestet ist:
#   - data/*-orig (make rule conv-orig)
#   - misc/temp_blockings: müssen konvertiert werden (einige Brandenburger
#     Dateien sind nämlich dabei) (make rule conv-temp-blockings)
#   - .bbr-Dateien (in meinem ~/.bbbike/route-Verzeichnis) auch
#     konvertieren, correct_data.pl hat jetzt .bbr support mit -bbr
#     (make rule conv-bbr)
#   - misc/sternfahrt_2004: sollte korrigiert werden, bzw. die -corrected.bbd
#     -Dateien nach .bbd umbenannt werden (manuell, siehe unten)
#
#   Dateien, die noch behandelt werden müssen:
#     keine mehr!
#
# - Schritte zur Konvertierung:
#   - Ausführen
#     make realclean
#XXX clean bbr/**?
#     make init
#     make conv-orig
#     make conv-temp-blockings
#     make conv-bbr
#      XXX missing XXX
#     make diff
#
#   - alle konvertierten Dateien müssen händisch mit diff kontrolliert werden!
#
#   - Dateien in ~/.bbbike/route/... => RCS
#   - data => data/old, data_corrected => data
#   - make test
#   - misc/temp_blockings => data/old, RCS-Dateien retten
#   - alle Programmreferenzen und MANIFESTe und CVS checkins für
#     temp_blockings ändern
#   - make test mit temp_blockings-Tests
#   - ci -r4 oder so ähnlich durchführen
#   - misc/sternfahrt_2004: corrected-Dateien nach .bbd umbenennen
#     Makefile anpassen

# .if !exists(Makefile.inc)
# .error Please execute "touch -t 197001010000 Makefile.inc"
# .else
# .include "Makefile.inc"
# .endif

MISCDIR=		../misc
MISCSRCDIR=		../miscsrc

DATADIR=		../data
CONV=			${MISCSRCDIR}/correct_data.pl
TARGETS!=		make -f ../data/Makefile -V TARGETS
TARGETS+=		inaccessible_strassen
CONVDB=			conv.db
CONVDB_MODTIME=		.conv.db.modtime
CONVLINE2=		${CONV} -minpoints=5 -refdist 10000,20000,40000,80000,120000 -convdata ${CONVDB} -inberlincheck -keepeverything
CONVLINE_BBR=		${CONVLINE2} -bbr

all:	conv

######################################################################

# XXX ampelschaltung-orig ausschliessen
conv-orig:
	for i in ../data/*-orig; do \
	    if [ "`basename $$i`" != "ampelschaltung-orig" ] ; \
		then \
	        echo "$$i -> `basename $$i`"; \
	        ${CONVLINE2} $$i > `basename $$i`; \
	    fi \
	done
	@echo "ampelschaltung-orig"
	cp -f ../data/ampelschaltung-orig ampelschaltung-orig
	@echo "fragezeichen-orig"
	${CONVLINE2} ../misc/fragezeichen-orig > fragezeichen-orig
	@echo "ampelschaltung-orig.txt"
	cp -f ../misc/ampelschaltung-orig.txt ampelschaltung-orig.txt

conv-temp-blockings:
	-mkdir temp_blockings
	for i in ../misc/temp_blockings/*.bbd; do \
	    echo "$$i -> temp_blockings/`basename $$i`"; \
	    ${CONVLINE2} $$i > temp_blockings/`basename $$i`; \
	done

conv-bbr:
	-mkdir -p bbr/tmp bbr/touren bbr/vorschlaege bbr/wanderungen
	for i in $(HOME)/.bbbike/route/*.bbr; do \
	    target=bbr/`basename $$i`; \
	    if [ ! -e $$target ] ; then \
	        echo "$$i -> $$target"; \
	        ${CONVLINE_BBR} $$i > $$target; \
	    fi \
	done
	for dir in $(HOME)/.bbbike/route/*; do \
	    if [ -d $$dir ] ; then \
	        echo "Directory $$dir"; \
		for i in $$dir/*.bbr; do \
		    target=bbr/`basename $$dir`/`basename $$i`; \
		    if [ ! -e $$target ] ; then \
			echo "$$i -> $$target"; \
			${CONVLINE_BBR} $$i > $$target; \
		    fi \
		done; \
	    fi \
	done

diff:
	for i in *-orig; do \
	    diff -u $$i ../data/$$i | more; \
	done

######################################################################

conv:	build-orig \
	${TARGETS} fragezeichen Berlin.coords.data Potsdam.coords.data \
	permissions

build-orig:
	cd ${DATADIR} && make

ampelschaltung:	${DATADIR}/ampelschaltung
	cp -fp ${DATADIR}/ampelschaltung .

# Should handle any conversions correctly, but there aren't any anymore...
radwege:	radwege_exact
	${MISCSRCDIR}/convert_radwege < radwege_exact > radwege

.for target in $(TARGETS:Nampelschaltung:Nradwege)
${target}:	${DATADIR}/${target}
	${CONV} -minpoints=5 -refdist 10000,20000,40000,80000,120000 -convdata ${CONVDB} -verboseoutput $> > $@~ && mv -f $@~ $@
.endfor

# XXX don't duplicate cmdline
fragezeichen:	${MISCDIR}/fragezeichen
	${CONV} -minpoints=5 -refdist 10000,20000,40000,80000,120000 -convdata ${CONVDB} -verboseoutput $> > $@~ && mv -f $@~ $@

Berlin.coords.data:	${DATADIR}/Berlin.coords.data
	cp -pf $> $@

# XXX hmmm... this should really be converted
Potsdam.coords.data:	${DATADIR}/Potsdam.coords.data
	cp -pf $> $@

permissions:
	chmod ugo+r *

clean:
	rm -rf $(TARGETS)

# Building ${CONVDB} is expensive ... try to save it first
realclean:	clean
	-mv -f ${CONVDB} /tmp
	rm -rf ${CONVDB} ${CONVDB_MODTIME}

init:	init-ident init-ostsee

# Iterate over all files mentioned in BASE and convert the B$x,$y
# notation, if necessary. This should be the first step if starting
# the conversion from an empty directory. This should also be called
# every time new points were added in the ${DATADIR} files!!!
#
# If something went wrong it's probably best to:
#    make realclean init all
#
# The second line assumes that all radwege are in Berlin. If this is not
# the case, I have to switch to something like PostGIS & truly_inside
# the Berlin borders or such.

# These coordinates form a rectangle contained completely in Berlin. This is
# used to minimize the number of point_in_polygon calls.
INNER_BERLIN_COORDS=-5400 19500 20800 1950

init-ident:	/tmp/berlin_polygon.bbd pre-init-ident do-init-ident

/tmp/berlin_polygon.bbd: ${DATADIR}/berlin
	${MISCSRCDIR}/combine_streets.pl -closedpolygon $> > $@

pre-init-ident:
	[ ! -e ${CONVDB} ] && touch -t 197001010000 ${CONVDB} || true
	touch -r ${CONVDB} ${CONVDB_MODTIME}

do-init-ident:
	cd ${DATADIR} && perl -w -I.. -I../lib -MKarte -MStrassen -MObject::Iterate=iterate -MList::Util=max,min -MDB_File -MVectorUtil=point_in_grid,point_in_polygon -e '\
Karte::preload(":all");\
$$berlin = Strassen->new("/tmp/berlin_polygon.bbd");\
@polygon = map { [ split /,/, $$_ ] } @{ $$berlin->get(0)->[Strassen::COORDS] };\
$$minx = min map { $$_->[0] } @polygon;\
$$miny = min map { $$_->[1] } @polygon;\
$$maxx = max map { $$_->[0] } @polygon;\
$$maxy = max map { $$_->[1] } @polygon;\
tie %db, "DB_File", "${.CURDIR}/${CONVDB}", O_RDWR|O_CREAT, 0600 or die 1;\
open(B, "BASE") or die 2;\
@base = <B>;\
close B;\
for (@base) {\
 ($$file,$$type) = split /\s+/;\
 next if $$file eq "ampelschaltung-orig";\
 next if -M $$file >= -M "${.CURDIR}/${CONVDB_MODTIME}";\
 warn "$$file...\n";\
 $$s=Strassen->new($$file);\
 iterate {\
  for my $$c (@{ $$_->[Strassen::COORDS] }) {\
   $$c =~ s/^:.*://;\
   next if $$c !~ /^[-+]?\d+,[-+]?\d+$$/;\
   next if exists $$db{$$c};\
   my($$px,$$py) = split /,/, $$c;\
   if    ($$file eq "plz-orig") { }\
   elsif (point_in_grid($$px,$$py,qw(${INNER_BERLIN_COORDS}))) { }\
   elsif (!point_in_grid($$px,$$py,$$minx,$$miny,$$maxx,$$maxy)) { next }\
   elsif (point_in_polygon([$$px,$$py],\@polygon)) { }\
   else  { next }\
   $$db{$$c} = $$c\
  }\
 } $$s;\
}'

#	cd ${DATADIR} && perl -I.. -I../lib -MStrassen -MObject::Iterate=iterate -MDB_File -e '\
#exit(0) if -M "radwege" >= -M "${.CURDIR}/${CONVDB_MODTIME}";\
#warn "radwege...\n";\
#tie %db, "DB_File", "${.CURDIR}/${CONVDB}", O_RDWR|O_CREAT, 0600 or die;\
#$$s=Strassen->new("radwege");\
#iterate {\
# for my $$c (@{ $$_->[Strassen::COORDS] }) { $$db{$$c} = $$c }\
#} $$s'

# Special handling for Ostsee (see comments in wasserumland2-orig).
# This should be the second step if starting the conversion from an
# empty directory.
init-ostsee:
	perl -w -MDB_File -e 'tie %db, "DB_File", "${CONVDB}", O_RDWR, 0600 or die; $$db{$$_} = $$_ for (qw(6556,269275 129023,269530 -212543,268820 6556,269275))'

.include "${DATADIR}/Makefile.mapfiles"
