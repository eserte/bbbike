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

all:	check validate targets

targets:	${TARGETS}

ampelschaltung.txt:	ampelschaltung-orig.txt
	-@$(WRITEABLE) $@
	grep -v '^#WPT:' ampelschaltung-orig.txt | \
	    ${CONVERT2HAFAS} -keepcomment -ampelschaltung2 \
	    > ampelschaltung.txt
	-@$(READONLY) $@

# checks
check:	.check_ampelschaltung2

validate:
	pkwalify -f garmin_devcap.kwalify garmin_devcap.yaml

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

sparkassen_osm.bbd:	../data_berlin_osm_bbbike/_unhandled
	perl -nle '/(^Sparkasse|Berliner Sparkasse|operator:Sparkasse)/ and do { s{\tX }{\tIMG:/home/e/eserte/images/icons/sparkasse.gif }; print }' ../data_berlin_osm_bbbike/_unhandled > sparkassen_osm.bbd~
	mv sparkassen_osm.bbd~ sparkassen_osm.bbd

citibank_osm.bbd:	../data_berlin_osm_bbbike/_unhandled
	perl -nle '/citibank/i and do { s{\tX }{\tIMG:/home/e/eserte/images/icons/citibank.gif }; print }' ../data_berlin_osm_bbbike/_unhandled > citibank_osm.bbd~
	mv citibank_osm.bbd~ citibank_osm.bbd

upload-personal: $(HOME)/.bbbike/personal.wpt
	gpsman readput GPSMan WP $(HOME)/.bbbike/personal.wpt

$(HOME)/.bbbike/personal.wpt:	$(HOME)/.bbbike/personal.bbd
	${GREPSTRASSEN} -catrx ':GPS' $(HOME)/.bbbike/personal.bbd | ${MISCSRCDIR}/bbd2gpsman.pl -symbol danger > $(HOME)/.bbbike/personal.wpt

######################################################################
# OSM downloads

OSM_DOWNLOAD_DIR=	download/osm
GERMANY_STATES=		berlin brandenburg hamburg hessen mecklenburg-vorpommern sachsen sachsen-anhalt
GERMANY_STATES_RULES=	${GERMANY_STATES:S/^/download-/:S/$/.osm.bz2/}
EUROPE_COUNTRIES=	germany croatia bosnia-herzegovina czech_republic
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

# WGS84 version - note that still bbbike and bbbike.cgi cannot handled this correctly
data_berlin_osm_untiled:
	${MISCSRCDIR}/osm2bbd -experiment add_postal_code -v -f -o ../data_berlin_osm download/osm/berlin.osm.bz2
	${MISCSRCDIR}/osm2bbd-postprocess ../data_berlin_osm

######################################################################
# Various downloads

# with -step 0.1: ca. 0:07 h download time, 70 tiles:
# (formerly with -step 0.01: ca. 1:24 h download time, 7020 tiles)
download-tiled-uckermark:
	cd download/osm && mkdir -p uckermark && cd uckermark && \
	    ${MISCSRCDIR}/downloadosm -step 0.1 13.1 53.4 14.5 52.9 -o .

# with -step 0.1: ca. 0:05 h download time, 45 tiles:
# (formerly with -step 0.01: ca. 0:42 h download time, 3619 tiles)
download-tiled-usedom:
	cd download/osm && mkdir -p usedom && cd usedom && \
	    ${MISCSRCDIR}/downloadosm -step 0.1 13.6 54.2 14.5 53.7 -o .

# with -step 0.1: ca. 0:10 h download time, 6 tiles:
# (formerly with -step 0.01: ca. 0:30 h download time, 551 tiles)
download-tiled-potsdam:
	cd download/osm && mkdir -p potsdam && cd potsdam && \
	    ${MISCSRCDIR}/downloadosm -step 0.1 12.9 52.5 13.2 52.3 -o .

######################################################################
# Testing for dalmatia
dalmatia-test:	dalmatia-test-osm2bbd \
		dalmatia-test-osm2bbd-postprocess1 \
		dalmatia-test-osm2bbd-postprocess2

download-tiled-dalmatia:
	cd download/osm && mkdir -p dalmatia && cd dalmatia && \
	    ${MISCSRCDIR}/downloadosm -step 0.1 14.8 42.5 18.2 44.4 -o .

dalmatia-test-osm2bbd:
	${MISCSRCDIR}/osm2bbd -map bbbike -country hr -o /tmp/data_dalmatia download/osm/dalmatia -f \
	    -nosplitlonglines -experiment coastline_hack \
	    -experiment polar_coord_hack

dalmatia-test-osm2bbd-postprocess1:
	${MISCSRCDIR}/osm2bbd-postprocess /tmp/data_dalmatia -only-coastline-hack -coastline-hack-anchor sw

dalmatia-test-osm2bbd-postprocess2:
	${MISCSRCDIR}/osm2bbd-postprocess /tmp/data_dalmatia -dataset-title Dalmatia

######################################################################
# Testing for saechsische schweiz
saechsische-schweiz-test:	saechsische-schweiz-test-osm2bbd \
		saechsische-schweiz-test-osm2bbd-postprocess

download-tiled-saechsische-schweiz:
	cd download/osm && mkdir -p saechsische-schweiz && cd saechsische-schweiz && \
	    ${MISCSRCDIR}/downloadosm -step 0.1 13.8 51 14.5 50.7 -o .

saechsische-schweiz-test-osm2bbd:
	${MISCSRCDIR}/osm2bbd -map bbbike -country de -o /tmp/data_saechsische-schweiz download/osm/saechsische-schweiz -f \
	    -experiment polar_coord_hack

saechsische-schweiz-test-osm2bbd-postprocess:
	${MISCSRCDIR}/osm2bbd-postprocess /tmp/data_saechsische-schweiz -dataset-title "Sächsische Schweiz"

######################################################################
# Testing for berlin
berlin-test:	berlin-test-osm2bbd \
		berlin-test-osm2bbd-postprocess2

berlin-test-osm2bbd:
	${MISCSRCDIR}/osm2bbd -map bbbike -country de -o /tmp/data_berlin download/osm/berlin -f \
	    -experiment polar_coord_hack

berlin-test-osm2bbd-postprocess2:
	${MISCSRCDIR}/osm2bbd-postprocess /tmp/data_berlin

######################################################################
# Building for garmin with custom .typ file
# Currently works only on mosor

bbbikemap-for-garmin:	/tmp/gmapsupp.img
	@echo "Set the garmin device into USB mass storage mode."
	@echo "Then execute:"
	@echo "   mount /mnt/garmin"
	@echo "   cp /tmp/gmapsupp.img /mnt/garmin/garmin/gmapsupp.img"
	@echo "   umount /mnt/garmin"

.PHONY: ../tmp/bbbike_routable.osm
../tmp/bbbike_routable.osm:
	cd ../data && ${MAKE} ../tmp/bbbike_routable.osm

/tmp/gmapsupp.img: /tmp/bbbike_routable.img
	[ -r /home/eserte/src/bbbike-aux/mkgmap/typ/M000002a.TYP ]
	cd /tmp && \
	    /usr/lib/jvm/java-6-sun/bin/java -jar /opt/mkgmap-r1247/mkgmap.jar --family-id=42 \
	       --gmapsupp bbbike_routable.img /home/eserte/src/bbbike-aux/mkgmap/typ/M000002a.TYP

/tmp/bbbike_routable.img: ../tmp/bbbike_routable.osm
	[ -r /home/eserte/src/bbbike-aux/mkgmap/srt-style ]
	cd /tmp && \
	    /usr/lib/jvm/java-6-sun/bin/java -Xmx1024m -jar /opt/mkgmap-r1247/mkgmap.jar --mapname=12117006 \
	        --latin1 --draw-priority=5 --style-file=/home/eserte/src/bbbike-aux/mkgmap/srt-style \
	        /home/eserte/src/bbbike/tmp/bbbike_routable.osm  && \
	    mv -f 12117006.img bbbike_routable.img 
