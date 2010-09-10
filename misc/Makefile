# NOTE: use BSD make (pmake or freebsd-make on some systems!)
#

PERL=			perl

BBBIKEDIR?=		${.CURDIR}/..
BBBIKEMISCDIR?=		${.CURDIR}
BBBIKETMPDIR?=		${BBBIKEDIR}/tmp
BBBIKEAUXDIR?=		${HOME}/src/bbbike-aux
BBBIKEMKGMAPDIR?=	${BBBIKEMISCDIR}/mkgmap
MISCSRCDIR?=		${BBBIKEDIR}/miscsrc
DATADIR?=		${BBBIKEDIR}/data
CONVERT2HAFAS=		${MISCSRCDIR}/convert2hafas
CHECK_POINTS=		${PERL} ${MISCSRCDIR}/check_points
GREPSTRASSEN=		${MISCSRCDIR}/grepstrassen

TARGETS=	ampelschaltung.txt

# XXX sp of writable/writeable?
WRITEABLE=	chmod u+w,ugo+r
READONLY=	chmod ugo+r,ugo-w

TODAY_DATE!=	date +'%Y%m%d'

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
	(echo "#: encoding: utf-8"; \
	 echo "#:"; \
	 perl -nle '/(^Sparkasse|Berliner Sparkasse|operator:Sparkasse)/ and do { s{\tX }{\tIMG:${BBBIKEAUXDIR}/images/sparkasse.gif }; print }' ../data_berlin_osm_bbbike/_unhandled) > sparkassen_osm.bbd~
	mv sparkassen_osm.bbd~ sparkassen_osm.bbd

targobank_osm.bbd:	../data_berlin_osm_bbbike/_unhandled
	(echo "#: encoding: utf-8"; \
	 echo "#:"; \
	 perl -nle '/(citibank|targobank)/i and do { s{\tX }{\tIMG:${BBBIKEAUXDIR}/images/targobank.png }; print }' ../data_berlin_osm_bbbike/_unhandled) > targobank_osm.bbd~
	mv targobank_osm.bbd~ targobank_osm.bbd

upload-personal: $(HOME)/.bbbike/personal.wpt
	gpsman readput GPSMan WP $(HOME)/.bbbike/personal.wpt

$(HOME)/.bbbike/personal.wpt:	$(HOME)/.bbbike/personal.bbd
	${GREPSTRASSEN} -catrx ':GPS' $(HOME)/.bbbike/personal.bbd | ${MISCSRCDIR}/bbd2gpsman.pl -symbol danger > $(HOME)/.bbbike/personal.wpt

######################################################################
# OSM downloads

OSM_DOWNLOAD_DIR=	download/osm
GERMANY_STATES=		berlin brandenburg hamburg hessen mecklenburg-vorpommern sachsen sachsen-anhalt schleswig-holstein
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

######################################################################
# Berlin+Brandenburg

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

# Currently brandenburg.osm.bz2 contains also berlin
data_berlin_brandenburg_osm_bbbike_untiled:
	${MISCSRCDIR}/osm2bbd -map bbbike -v -f -o ../data_berlin_brandenburg_osm_bbbike download/osm/brandenburg.osm.bz2
	${MISCSRCDIR}/osm2bbd-postprocess ../data_berlin_brandenburg_osm_bbbike

######################################################################
# Berlin (only)

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

MKGMAP_VER?=	1624
.if exists(/opt/mkgmap-r$(MKGMAP_VER)/mkgmap.jar)
MKGMAP?=	java -Xmx1024m -jar /opt/mkgmap-r${MKGMAP_VER}/mkgmap.jar
.else
MKGMAP?=	java -Xmx1024m -jar /usr/local/src/mkgmap-r${MKGMAP_VER}/mkgmap.jar
.endif

# on mosor: /usr/lib/jvm/java-6-sun/bin/java -jar /opt/mkgmap-r1247/mkgmap.jar

bbbikemap-for-garmin:	${BBBIKETMPDIR}/bbbike_routable_gmapsupp.img
	@echo "Set the garmin device into USB mass storage mode."
	@echo "Then execute:"
	@echo "   mount /mnt/garmin"
	@echo "   cp ${BBBIKETMPDIR}/bbbike_routable_gmapsupp.img /mnt/garmin/garmin/gmapsupp.img"
	@echo "   umount /mnt/garmin"

.PHONY: ${BBBIKETMPDIR}/bbbike_routable.osm
${BBBIKETMPDIR}/bbbike_routable.osm:
# Do not use ${BBBIKETMPDIR} here, but a relative path against data,
# so the remake rule really works
	cd ../data && ${MAKE} ../tmp/bbbike_routable.osm

${BBBIKETMPDIR}/bbbike_routable_gmapsupp.img: ${BBBIKETMPDIR}/bbbike_routable.img ${BBBIKEMKGMAPDIR}/typ/M000002a.TYP
	cd ${BBBIKETMPDIR} && \
	    ${MKGMAP} --family-id=42 --family-name="Slavens Map" \
	       --gmapsupp bbbike_routable.img ${BBBIKEMKGMAPDIR}/typ/M000002a.TYP
	mv ${BBBIKETMPDIR}/gmapsupp.img ${BBBIKETMPDIR}/bbbike_routable_gmapsupp.img

${BBBIKETMPDIR}/bbbike_routable.img: ${BBBIKETMPDIR}/bbbike_routable.osm ${BBBIKEMKGMAPDIR}/srt-style/*
	[ -r ${BBBIKEMKGMAPDIR}/srt-style ]
	cd ${BBBIKETMPDIR} && \
	    ${MKGMAP} --description="BBBike Routable" --mapname=12117006 \
		--country-name=Germany --country-abbr=DE \
	        --latin1 --net --route --draw-priority=15 --style-file=${BBBIKEMKGMAPDIR}/srt-style \
	        ${BBBIKETMPDIR}/bbbike_routable.osm  && \
	    mv -f 12117006.img bbbike_routable.img 

######################################################################
# Sourceforge release targets

do-garmindata-dist:	${BBBIKETMPDIR}/bbbike_routable_gmapsupp.img
	rm -rf /tmp/bbbike-b_de-garmin
	mkdir /tmp/bbbike-b_de-garmin
	(echo "Eine auf BBBike-Daten basierende Berlin-Karte für Garmin-Geräte."; \
	 echo "Erzeugt mithilfe von mkgmap."; \
	 echo ""; \
	 echo "Einschränkungen:"; \
	 echo "* Zurzeit ist es nicht möglich, die Karte zusammen mit anderen"; \
	 echo "  Karten gleichzeitig zu installieren. Es ist empfohlen, von"; \
	 echo "  einer bereits installierten Karte ein Backup zu machen."; \
	 echo ""; \
	 echo "Installation:"; \
	 echo "* Das Garmin-Gerät über USB an einen PC anschließen und mounten"; \
	 echo "  oder alternativ die Micro-SD-Karte in ein Kartenlesegerät legen."; \
	 echo "* Eine existierende .../garmin/gmapsupp.img sollte gesichert werden."; \
	 echo "* Die Datei bbbike_routable_gmapsupp.img als .../garmin/gmapsupp.img kopieren."; \
	 echo ""; \
	 echo "Fragen per E-Mail an: slaven AT rezic DOT de"; \
	) | perl -pe 's{$$}{\r}' > /tmp/bbbike-b_de-garmin/README.txt
	rsync --archive --cvs-exclude ${BBBIKETMPDIR}/bbbike_routable_gmapsupp.img /tmp/bbbike-b_de-garmin/
	cd /tmp && \
	    zip -r bbbike-b_de-garmin-$(TODAY_DATE).zip bbbike-b_de-garmin

garmindata-sf-release:	do-garmindata-dist
	@echo "Go to https://sourceforge.net/downloads/bbbike/bbbikedata-b_de/"
	@echo "Create a YYYYMMDD directory and upload /tmp/bbbike-b_de-garmin-$(TODAY_DATE).zip"
#	@echo "Really upload bbbike-b_de-garmin-$(TODAY_DATE).zip to SourceForge?"
#	@cd /tmp && ls -l bbbike-b_de-garmin-$(TODAY_DATE).zip
#	@echo "Press CTRL-C to abort. Return to continue release."
#	@read yn
#	cd /tmp && sf-upload -groupid 19142 -packageid 207826 -r $(TODAY_DATE) -f bbbike-b_de-garmin-$(TODAY_DATE).zip
