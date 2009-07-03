#
# $Id: Makefile,v 1.25 2009/04/04 11:23:09 eserte Exp $
#

PERL=			perl

BBBIKEDIR?=		${.CURDIR}/..
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
	rsync -avz root@bbbike.de:/var/www/domains/radzeit.de/www/BBBike/tmp/uaprof/ ../tmp/uaprof/

sparkassen_osm.bbd:	../data_berlin_osm_bbbike/_unhandled
	perl -nle '/(^Sparkasse|Berliner Sparkasse|operator:Sparkasse)/ and do { s{\tX }{\tIMG:/home/e/eserte/images/icons/sparkasse.gif }; print }' ../data_berlin_osm_bbbike/_unhandled > sparkassen_osm.bbd~
	mv sparkassen_osm.bbd~ sparkassen_osm.bbd

citibank_osm.bbd:	../data_berlin_osm_bbbike/_unhandled
	perl -nle '/citibank/i and do { s{\tX }{\tIMG:/home/e/eserte/images/icons/citibank.gif }; print }' ../data_berlin_osm_bbbike/_unhandled > citibank_osm.bbd~
	mv citibank_osm.bbd~ citibank_osm.bbd

######################################################################
# OSM downloads

OSM_DOWNLOAD_DIR=	download/osm
GERMANY_STATES=		berlin brandenburg hamburg hessen mecklenburg-vorpommern sachsen sachsen-anhalt
GERMANY_STATES_RULES=	${GERMANY_STATES:S/^/download-/:S/$/.osm.bz2/}
EUROPE_COUNTRIES=	germany croatia
EUROPE_COUNTRIES_RULES=	${EUROPE_COUNTRIES:S/^/download-/:S/$/.osm.bz2/}

osm-download-all:	osm-download-geofabrik reload-tiled-berlin

osm-download-geofabrik:	${GERMANY_STATES_RULES} ${EUROPE_COUNTRIES_RULES}

.for land in ${GERMANY_STATES}
download-${land}.osm.bz2:
# cd just for checking:
	mkdir -p ${OSM_DOWNLOAD_DIR}
	cd ${OSM_DOWNLOAD_DIR} && true
	wget http://download.geofabrik.de/osm/europe/germany/${land}.osm.bz2 -O ${OSM_DOWNLOAD_DIR}/${land}.osm.bz2~
	mv ${OSM_DOWNLOAD_DIR}/${land}.osm.bz2~ ${OSM_DOWNLOAD_DIR}/${land}.osm.bz2
.endfor

.for land in ${EUROPE_COUNTRIES}
download-${land}.osm.bz2:
# cd just for checking:
	mkdir -p ${OSM_DOWNLOAD_DIR}
	cd ${OSM_DOWNLOAD_DIR} && true
	wget http://download.geofabrik.de/osm/europe/${land}.osm.bz2 -O ${OSM_DOWNLOAD_DIR}/${land}.osm.bz2~
	mv ${OSM_DOWNLOAD_DIR}/${land}.osm.bz2~ ${OSM_DOWNLOAD_DIR}/${land}.osm.bz2
.endfor

# Download the prepared osm from geofabrik
# XXX very problematic because streets between Berlin and Brandenburg are not connected!
#data_berlin_brandenburg_osm_bbbike:	download-berlin.osm.bz2 download-brandenburg.osm.bz2 \
#					convert-data_berlin_brandenburg_osm_bbbike

data_berlin_brandenburg_osm_bbbike:	download-germany.osm.bz2 \
					split-berlin-brandenburg-from-germany \
					convert-splitted-berlin-brandenburg

.if exists(/opt/osmosis-0.24.1-java5/osmosis.jar)
OSMOSIS_JAR=	/opt/osmosis-0.24.1-java5/osmosis.jar
.else
OSMOSIS_JAR=	/usr/local/src/osmosis-0.24.1-java5/osmosis.jar
.endif

# XXX maybe bzip2 (on the fly) the output?
split-berlin-brandenburg-from-germany:	${OSM_DOWNLOAD_DIR}/germany.osm.bz2
	java -jar ${OSMOSIS_JAR} --rx ${OSM_DOWNLOAD_DIR}/germany.osm.bz2 --bb top=53.42 bottom=51.44 left=11.6 right=14.8 --wx ${OSM_DOWNLOAD_DIR}/berlin-brandenburg-splitted.osm

# This target takes about 25 minutes on a 1.7MHz machine (2009-04-20)
convert-splitted-berlin-brandenburg:
	${MISCSRCDIR}/osm2bbd -country de -lang de -map bbbike -v -f -o ../data_berlin_brandenburg_osm_bbbike ${OSM_DOWNLOAD_DIR}/berlin-brandenburg-splitted.osm
	${MISCSRCDIR}/osm2bbd-postprocess ../data_berlin_brandenburg_osm_bbbike

convert-data_berlin_brandenburg_osm_bbbike:
	${MISCSRCDIR}/osm2bbd -country de -lang de -map bbbike -v -f -o ../data_berlin_brandenburg_osm_bbbike download/osm/berlin.osm.bz2 download/osm/brandenburg.osm.bz2
	${MISCSRCDIR}/osm2bbd-postprocess ../data_berlin_brandenburg_osm_bbbike

# Alternative tiled Berlin data
reload-tiled-berlin:
	cd download/osm/berlin && ${MISCSRCDIR}/downloadosm -reload .

download-tiled-berlin:
	cd download/osm && mkdir -p berlin && cd berlin && \
	    ${MISCSRCDIR}/downloadosm 13.08 52.41 13.77 52.45 -o .

data_berlin_osm_bbbike:
	${MISCSRCDIR}/osm2bbd -map bbbike -v -f -o ../data_berlin_osm_bbbike download/osm/berlin
	${MISCSRCDIR}/osm2bbd-postprocess ../data_berlin_osm_bbbike

data_berlin_osm_bbbike_untiled:
	${MISCSRCDIR}/osm2bbd -map bbbike -v -f -o ../data_berlin_osm_bbbike download/osm/berlin.osm.bz2
	${MISCSRCDIR}/osm2bbd-postprocess ../data_berlin_osm_bbbike

######################################################################
# Various downloads

download-tiled-uckermark:
	cd download/osm && mkdir -p uckermark && cd uckermark && \
	    ${MISCSRCDIR}/downloadosm 13.19 53.47 14.48 52.94 -o .

download-tiled-usedom:
	cd download/osm && mkdir -p usedom && cd usedom && \
	    ${MISCSRCDIR}/downloadosm 13.67 54.18 14.43 53.72 -o .

download-tiled-potsdam:
	cd download/osm && mkdir -p potsdam && cd potsdam && \
	    ${MISCSRCDIR}/downloadosm 12.91 52.50 13.19 52.32 -o .

######################################################################
# Testing for dalmatia
dalmatia-test:	dalmatia-test-osm2bbd \
		dalmatia-test-osm2bbd-postprocess1 \
		dalmatia-test-osm2bbd-postprocess2

dalmatia-test-osm2bbd:
	${MISCSRCDIR}/osm2bbd -map bbbike -country hr -o /tmp/data_dalmatien download/osm/dalmatien -f \
	    -nosplitlonglines -experiment coastline_hack \
	    -experiment polar_coord_hack

dalmatia-test-osm2bbd-postprocess1:
	${MISCSRCDIR}/osm2bbd-postprocess /tmp/data_dalmatien -only-coastline-hack -coastline-hack-anchor sw

dalmatia-test-osm2bbd-postprocess2:
	${MISCSRCDIR}/osm2bbd-postprocess /tmp/data_dalmatien -dataset-title Dalmatia

######################################################################
# Testing for berlin
berlin-test:	berlin-test-osm2bbd \
		berlin-test-osm2bbd-postprocess2

berlin-test-osm2bbd:
	${MISCSRCDIR}/osm2bbd -map bbbike -country de -o /tmp/data_berlin download/osm/berlin -f \
	    -experiment polar_coord_hack

berlin-test-osm2bbd-postprocess2:
	${MISCSRCDIR}/osm2bbd-postprocess /tmp/data_berlin
