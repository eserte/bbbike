#
# $Id: Makefile,v 1.24 2009/02/15 11:36:06 eserte Exp eserte $
#

PERL=			perl

BBBIKEDIR?=		..
MISCSRCDIR?=		${BBBIKEDIR}/miscsrc
DATADIR?=		${BBBIKEDIR}/data
CONVERT2HAFAS=		${MISCSRCDIR}/convert2hafas
CHECK_POINTS=		${PERL} ${MISCSRCDIR}/check_points
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
#	rm -rf /tmp/xxx /tmp/data.patch /tmp/datachange.log /tmp/data
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

rsync-uaprof:
	rsync -avz root@bbbike.radzeit.de:/var/www/domains/radzeit.de/www/BBBike/tmp/uaprof/ ../tmp/uaprof/

sparkassen_osm.bbd:	../data_berlin_osm_bbbike/_unhandled
	perl -nle '/(^Sparkasse|Berliner Sparkasse|operator:Sparkasse)/ and do { s{\tX }{\tIMG:/home/e/eserte/images/icons/sparkasse.gif }; print }' ../data_berlin_osm_bbbike/_unhandled > sparkassen_osm.bbd

citibank_osm.bbd:	../data_berlin_osm_bbbike/_unhandled
	perl -nle '/citibank/i and do { s{\tX }{\tIMG:/home/e/eserte/images/icons/citibank.gif }; print }' ../data_berlin_osm_bbbike/_unhandled > citibank_osm.bbd

######################################################################
# OSM downloads

OSM_DOWNLOAD_DIR=	download/osm
GERMANY_STATES=		berlin brandenburg hessen
GERMANY_STATES_RULES=	${GERMANY_STATES:S/^/download-/:S/$/.osm.bz2/}

osm-download-all:	${GERMANY_STATES_RULES}

.for land in ${GERMANY_STATES}
download-${land}.osm.bz2:
# cd just for checking:
	mkdir -p ${OSM_DOWNLOAD_DIR}
	cd ${OSM_DOWNLOAD_DIR} && true
	wget http://download.geofabrik.de/osm/europe/germany/${land}.osm.bz2 -O ${OSM_DOWNLOAD_DIR}/${land}.osm.bz2~
	mv ${OSM_DOWNLOAD_DIR}/${land}.osm.bz2~ ${OSM_DOWNLOAD_DIR}/${land}.osm.bz2
.endfor

# Use the already downloaded tiles
data_berlin_osm_bbbike:
	${MISCSRCDIR}/osm2bbd -v -f -o ../data_berlin_osm_bbbike download/osm/berlin/*.osm

# Download the prepared osm from geofabrik
data_berlin_brandenburg_osm_bbbike:	download-berlin.osm.bz2 download-brandenburg.osm.bz2
					convert-data_berlin_brandenburg_osm_bbbike

convert-data_berlin_brandenburg_osm_bbbike:
	${MISCSRCDIR}/osm2bbd -v -f -o ../data_berlin_brandenburg_osm_bbbike download/osm/berlin.osm.bz2 download/osm/brandenburg.osm.bz2
