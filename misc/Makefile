# NOTE: use BSD make (pmake or freebsd-make or fmake on some systems!)
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
CHECK_NEIGHBOUR=	${PERL} ${MISCSRCDIR}/check_neighbour
CHECK_POINTS=		${PERL} ${MISCSRCDIR}/check_points
GREPSTRASSEN=		${MISCSRCDIR}/grepstrassen
OSM2BBD=		${PERL} ${MISCSRCDIR}/osm2bbd
OSM2BBD_POSTPROCESS=	${PERL} ${MISCSRCDIR}/osm2bbd-postprocess

TARGETS=	ampelschaltung.txt abdeckung.bbd

COPYRIGHT_MESSAGE=	Slaven Rezic - www.bbbike.de

# XXX sp of writable/writeable?
WRITEABLE=	chmod u+w,ugo+r
READONLY=	chmod ugo+r,ugo-w

TODAY_DATE!=	date +'%Y%m%d'
UNAME!=		uname
.if ${UNAME} == "Darwin"
# bsdmake from homebrew cannot cope with :tl modifier, so set this without
OS=darwin
.else
OS=${UNAME:tl}
.endif
USER!=		id -n -u

all:	check validate targets

targets:	${TARGETS}

ampelschaltung.txt:	ampelschaltung-orig.txt
	-@$(WRITEABLE) $@
	grep -v '^#WPT:' ampelschaltung-orig.txt | \
	    ${CONVERT2HAFAS} -keepcomment -ampelschaltung2 \
	    > ampelschaltung.txt
	-@$(READONLY) $@

abdeckung.bbd: abdeckung.bbd-orig ../data/berlin_ortsteile
	cat abdeckung.bbd-orig | ${MISCSRCDIR}/berlin_cityparts_to_bbd.pl -inbbd -cat 'F:#0000ff|stiplite.xbm' > abdeckung.bbd~
	mv -f abdeckung.bbd~ abdeckung.bbd
	-@$(READONLY) $@

# checks
check:	.check_ampelschaltung2 .check_ampelschaltung_rules

validate:	${BBBIKETMPDIR}/.validate_garmin_devcap

${BBBIKETMPDIR}/.validate_garmin_devcap: garmin_devcap.kwalify garmin_devcap.yaml
	${PERL} -S pkwalify -f garmin_devcap.kwalify garmin_devcap.yaml
	touch ${BBBIKETMPDIR}/.validate_garmin_devcap

.check_ampelschaltung2:	ampelschaltung-orig.txt ${DATADIR}/ampeln-orig
	$(CHECK_POINTS) -ampelschaltung2 -warn \
		ampelschaltung-orig.txt ${DATADIR}/ampeln-orig
	@touch .check_ampelschaltung2

.check_ampelschaltung_rules:	ampelschaltung_rules.bbd \
				${DATADIR}/strassen ${DATADIR}/landstrassen ${DATADIR}/landstrassen2 ${DATADIR}/fragezeichen
	$(CHECK_NEIGHBOUR) -type standard -data ampelschaltung_rules.bbd \
		-against ${DATADIR}/strassen -against ${DATADIR}/landstrassen -against ${DATADIR}/landstrassen2 \
		-against ${DATADIR}/fragezeichen
	@touch $@

tkbabybike-screenshot:
	cd screenshots && $(MAKE) tkbabybike-screenshot

######################################################################
# Upload personal.bbd

upload-personal: upload-personal-gpi

upload-personal-gpi: $(HOME)/.bbbike/personal.gpi
	@echo "Please execute the following as as root:"
	@echo ""
	@echo "    mount /mnt/garmin && cp $(HOME)/.bbbike/personal.gpi /mnt/garmin/garmin/poi/ && umount /mnt/garmin"
	@echo ""

$(HOME)/.bbbike/personal.gpi:	$(HOME)/.bbbike/personal.bbd
	${GREPSTRASSEN} -catrx ':GPS' $> | ${MISCSRCDIR}/bbd2gpx - | gpsbabel -i gpx -o garmin_gpi,alerts=0,category="Personal" /dev/stdin $@~
	mv $@~ $@

upload-personal-gpsman: $(HOME)/.bbbike/personal.wpt
	gpsman readput GPSMan WP $(HOME)/.bbbike/personal.wpt

$(HOME)/.bbbike/personal.wpt:	$(HOME)/.bbbike/personal.bbd
	${GREPSTRASSEN} -catrx ':GPS' $> | ${MISCSRCDIR}/bbd2gpsman.pl -symbol danger > $(HOME)/.bbbike/personal.wpt

######################################################################
# OSM downloads

OSM_DOWNLOAD_DIR=	download/osm
GERMANY_STATES=			berlin brandenburg hamburg hessen mecklenburg-vorpommern sachsen sachsen-anhalt schleswig-holstein
GERMANY_STATES_BZ2_RULES=	${GERMANY_STATES:S/^/download-/:S/$/.osm.bz2/}
GERMANY_STATES_PBF_RULES=	${GERMANY_STATES:S/^/download-/:S/$/.osm.pbf/}
EUROPE_COUNTRIES=		germany croatia bosnia-herzegovina czech_republic
EUROPE_COUNTRIES_BZ2_RULES=	${EUROPE_COUNTRIES:S/^/download-/:S/$/.osm.bz2/}
EUROPE_COUNTRIES_BZ2_RULES=	${EUROPE_COUNTRIES:S/^/download-/:S/$/.osm.pbf/}

osm-download-all:	osm-download-geofabrik-bz2 reload-tiled-berlin

osm-download-geofabrik-bz2:	${GERMANY_STATES_BZ2_RULES} ${EUROPE_COUNTRIES_BZ2_RULES}

.for land in ${GERMANY_STATES}
download-${land}.osm.bz2:
# cd just for checking:
	mkdir -p ${OSM_DOWNLOAD_DIR}
	cd ${OSM_DOWNLOAD_DIR} && true
	wget http://download.geofabrik.de/europe/germany/${land}-latest.osm.bz2 -O ${OSM_DOWNLOAD_DIR}/${land}.osm.bz2~
	mv ${OSM_DOWNLOAD_DIR}/${land}.osm.bz2~ ${OSM_DOWNLOAD_DIR}/${land}.osm.bz2

download-${land}.osm.pbf:
# cd just for checking:
	mkdir -p ${OSM_DOWNLOAD_DIR}
	cd ${OSM_DOWNLOAD_DIR} && true
	wget http://download.geofabrik.de/europe/germany/${land}-latest.osm.pbf -O ${OSM_DOWNLOAD_DIR}/${land}.osm.pbf~
	mv ${OSM_DOWNLOAD_DIR}/${land}.osm.pbf~ ${OSM_DOWNLOAD_DIR}/${land}.osm.pbf
.endfor

.for land in ${EUROPE_COUNTRIES}
download-${land}.osm.bz2:
# cd just for checking:
	mkdir -p ${OSM_DOWNLOAD_DIR}
	cd ${OSM_DOWNLOAD_DIR} && true
	wget http://download.geofabrik.de/europe/${land}-latest.osm.bz2 -O ${OSM_DOWNLOAD_DIR}/${land}.osm.bz2~
	mv ${OSM_DOWNLOAD_DIR}/${land}.osm.bz2~ ${OSM_DOWNLOAD_DIR}/${land}.osm.bz2

download-${land}.osm.pbf:
# cd just for checking:
	mkdir -p ${OSM_DOWNLOAD_DIR}
	cd ${OSM_DOWNLOAD_DIR} && true
	wget http://download.geofabrik.de/europe/${land}-latest.osm.pbf -O ${OSM_DOWNLOAD_DIR}/${land}.osm.pbf~
	mv ${OSM_DOWNLOAD_DIR}/${land}.osm.pbf~ ${OSM_DOWNLOAD_DIR}/${land}.osm.pbf
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

BERLIN_OSM_BZ2?=	download/osm/berlin.osm.bz2

# XXX maybe bzip2 (on the fly) the output?
split-berlin-brandenburg-from-germany:	${OSM_DOWNLOAD_DIR}/germany.osm.bz2
	java -jar ${OSMOSIS_JAR} --rx ${OSM_DOWNLOAD_DIR}/germany.osm.bz2 --bb top=53.42 bottom=51.44 left=11.6 right=14.8 --wx ${OSM_DOWNLOAD_DIR}/berlin-brandenburg-splitted.osm

# This target takes about 25 minutes on a 1.7MHz machine (2009-04-20)
convert-splitted-berlin-brandenburg:
	${OSM2BBD} -country de -lang de -map bbbike -v -f -o ../data_berlin_brandenburg_osm_bbbike ${OSM_DOWNLOAD_DIR}/berlin-brandenburg-splitted.osm
	${OSM2BBD_POSTPROCESS} ../data_berlin_brandenburg_osm_bbbike

convert-data_berlin_brandenburg_osm_bbbike:
	${OSM2BBD} -country de -lang de -map bbbike -v -f -o ../data_berlin_brandenburg_osm_bbbike ${BERLIN_OSM_BZ2} download/osm/brandenburg.osm.bz2
	${OSM2BBD_POSTPROCESS} ../data_berlin_brandenburg_osm_bbbike

# Currently brandenburg.osm.bz2 contains also berlin
data_berlin_brandenburg_osm_bbbike_untiled:
	${OSM2BBD} -map bbbike -v -f -o ../data_berlin_brandenburg_osm_bbbike download/osm/brandenburg.osm.bz2
	${OSM2BBD_POSTPROCESS} ../data_berlin_brandenburg_osm_bbbike

######################################################################
# Berlin (only)

# Alternative tiled Berlin data
reload-tiled-berlin:
	cd download/osm/berlin && ${MISCSRCDIR}/downloadosm -reload .

download-tiled-berlin:
	cd download/osm && mkdir -p berlin && cd berlin && \
	    ${MISCSRCDIR}/downloadosm 13.08 52.41 13.77 52.45 -o .

data_berlin_osm_bbbike_tiled:
	${OSM2BBD} -map bbbike -v -f -o ../data_berlin_osm_bbbike download/osm/berlin
	${OSM2BBD_POSTPROCESS} ../data_berlin_osm_bbbike

data_berlin_osm_bbbike: data_berlin_osm_bbbike_untiled

data_berlin_osm_bbbike_untiled:
	${OSM2BBD} -map bbbike -experiment handle_relations -v -f -o ../data_berlin_osm_bbbike ${BERLIN_OSM_BZ2}
	${OSM2BBD_POSTPROCESS} ../data_berlin_osm_bbbike

# WGS84 version - note that still bbbike and bbbike.cgi cannot handle this correctly
data_berlin_osm_untiled:
	${OSM2BBD} -experiment add_postal_code -v -f -o ../data_berlin_osm ${BERLIN_OSM_BZ2}
	${OSM2BBD_POSTPROCESS} ../data_berlin_osm

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
	${OSM2BBD} -map bbbike -country hr -o /tmp/data_dalmatia download/osm/dalmatia -f \
	    -nosplitlonglines -experiment coastline_hack \
	    -experiment polar_coord_hack

dalmatia-test-osm2bbd-postprocess1:
	${OSM2BBD_POSTPROCESS} /tmp/data_dalmatia -only-coastline-hack -coastline-hack-anchor sw

dalmatia-test-osm2bbd-postprocess2:
	${OSM2BBD_POSTPROCESS} /tmp/data_dalmatia -dataset-title Dalmatia

######################################################################
# Testing for saechsische schweiz
saechsische-schweiz-test:	saechsische-schweiz-test-osm2bbd \
		saechsische-schweiz-test-osm2bbd-postprocess

download-tiled-saechsische-schweiz:
	cd download/osm && mkdir -p saechsische-schweiz && cd saechsische-schweiz && \
	    ${MISCSRCDIR}/downloadosm -step 0.1 13.8 51 14.5 50.7 -o .

saechsische-schweiz-test-osm2bbd:
	${OSM2BBD} -map bbbike -country de -o /tmp/data_saechsische-schweiz download/osm/saechsische-schweiz -f \
	    -experiment polar_coord_hack

saechsische-schweiz-test-osm2bbd-postprocess:
	${OSM2BBD_POSTPROCESS} /tmp/data_saechsische-schweiz -dataset-title "S�chsische Schweiz"

######################################################################
# Testing for berlin
berlin-test:	berlin-test-osm2bbd \
		berlin-test-osm2bbd-postprocess2

berlin-test-osm2bbd:
	${OSM2BBD} -map bbbike -country de -o /tmp/data_berlin download/osm/berlin -f \
	    -experiment polar_coord_hack

berlin-test-osm2bbd-postprocess2:
	${OSM2BBD_POSTPROCESS} /tmp/data_berlin

######################################################################
# Building for garmin with custom .typ file

#MKGMAP_VER?=	1624
## Used between 2011-07 (approx.) and 2012-07
#MKGMAP_VER?=	2009
## Used since 2012-07
MKGMAP_VER?=	2310
.if exists(/opt/mkgmap-r$(MKGMAP_VER)/mkgmap.jar)
MKGMAP?=	java -Xmx1024m -jar /opt/mkgmap-r${MKGMAP_VER}/mkgmap.jar
.else
MKGMAP?=	java -Xmx1024m -jar /usr/local/src/mkgmap-r${MKGMAP_VER}/mkgmap.jar
.endif

# on mosor: /usr/lib/jvm/java-6-sun/bin/java -jar /opt/mkgmap-r1247/mkgmap.jar

BBBIKE_ROUTABLE_GMAPSUPP_SOURCES=	${BBBIKETMPDIR}/bbbike_routable.img

BBBIKE_FAT_ROUTABLE_GMAPSUPP_SOURCES=	${BBBIKETMPDIR}/bbbike_routable_gmapsupp.img
.if exists(${BBBIKETMPDIR}/fragezeichen-outdoor-categorized.img)
BBBIKE_FAT_ROUTABLE_GMAPSUPP_SOURCES+=	${BBBIKETMPDIR}/fragezeichen-outdoor-categorized.img
.endif
.if exists(${BBBIKETMPDIR}/trafficlightmap20.img)
BBBIKE_FAT_ROUTABLE_GMAPSUPP_SOURCES+=	${BBBIKETMPDIR}/trafficlightmap20.img
.endif
.if exists(${BBBIKETMPDIR}/trafficlightmap25.img)
BBBIKE_FAT_ROUTABLE_GMAPSUPP_SOURCES+=	${BBBIKETMPDIR}/trafficlightmap25.img
.endif

bbbikemap-for-garmin:	bbbikemap-for-garmin-create bbbikemap-for-garmin-transfer-${OS}

bbbikemap-for-garmin-create: ${BBBIKE_FAT_ROUTABLE_GMAPSUPP_SOURCES}

bbbikemap-for-garmin-transfer-freebsd:
	@echo "Set the garmin device into USB mass storage mode."
	@echo -n "Type y to copy the files to /mnt/garmin: "
	@read yn && [ "$$yn" = "y" ]
	@echo "Waiting max. 30s for /dev/da1s1 to appear"
	for i in `seq 30`; do test -e /dev/da1s1 && break; sleep 1; done
	@echo "Ready to mount and sync"
	mount /mnt/garmin && rsync -vP ${BBBIKE_FAT_ROUTABLE_GMAPSUPP_SOURCES} /mnt/garmin/garmin/ && umount /mnt/garmin

bbbikemap-for-garmin-transfer-linux:
	@echo "Set the garmin device into USB mass storage mode and mount device (e.g. with nautilus)."
	@echo "Waiting max. 30s for /media/${USER}/*/garmin to appear"
	for i in `seq 30`; do [ $$(ls /media/${USER}/*/garmin | wc -l) -gt 0 ] && break; sleep 1; done
	@echo "Type y to do the following: "
	rsync --dry-run -vP ${BBBIKE_FAT_ROUTABLE_GMAPSUPP_SOURCES} /media/${USER}/*/garmin/
	@echo -n "(y/N) "
	@read yn && [ "$$yn" = "y" ]
	rsync -vP ${BBBIKE_FAT_ROUTABLE_GMAPSUPP_SOURCES} /media/${USER}/*/garmin/
	@echo "Please unmount manually"

bbbikemap-for-garmin-transfer-any:
	@echo "Set the garmin device into USB mass storage mode."
	${PERL} -w -I.. -I../lib -MGPS::BBBikeGPS::MountedDevice -e '@img = @ARGV; GPS::BBBikeGPS::MountedDevice->maybe_mount(sub { my $$dir = shift; system("rsync", "-vP", @img, "$$dir/garmin/"); 1 }, garmin_disk_type => "card")' ${BBBIKE_FAT_ROUTABLE_GMAPSUPP_SOURCES}

.PHONY: ${BBBIKETMPDIR}/bbbike_routable.osm
${BBBIKETMPDIR}/bbbike_routable.osm:
# Do not use ${BBBIKETMPDIR} here, but a relative path against data,
# so the remake rule really works
	cd ../data && ${MAKE} ../tmp/bbbike_routable.osm

${BBBIKETMPDIR}/bbbike_routable_gmapsupp.img: ${BBBIKE_ROUTABLE_GMAPSUPP_SOURCES} ${BBBIKEMKGMAPDIR}/typ/M000002a.TYP
	cd ${BBBIKETMPDIR} && \
	    ${MKGMAP} --family-id=1211 --family-name="BBBike Berlin" \
	       --description="BBBike Berlin" \
	       --index \
	       --gmapsupp ${BBBIKE_ROUTABLE_GMAPSUPP_SOURCES} ${BBBIKEMKGMAPDIR}/typ/M000002a.TYP
	mv ${BBBIKETMPDIR}/gmapsupp.img ${BBBIKETMPDIR}/bbbike_routable_gmapsupp.img

${BBBIKETMPDIR}/bbbike_routable.img: ${BBBIKETMPDIR}/bbbike_routable.osm ${BBBIKEMKGMAPDIR}/srt-style/*
	[ -r ${BBBIKEMKGMAPDIR}/srt-style ]
	cd ${BBBIKETMPDIR} && \
	    ${MKGMAP} --description="BBBike Routable" --mapname=12117006 \
		--country-name=Germany --country-abbr=DE \
	        --copyright-message="${COPYRIGHT_MESSAGE}" \
	        --latin1 --net --route --draw-priority=15 --style-file=${BBBIKEMKGMAPDIR}/srt-style \
	        --index \
	        ${BBBIKETMPDIR}/bbbike_routable.osm  && \
	    [ -s 12117006.img ] && \
	    mv -f 12117006.img bbbike_routable.img 

######################################################################
# typ2legend

typ-legend-all: typ-legend-bbbike typ-legend-osm

typ-legend-bbbike: ${BBBIKETMPDIR}/typ_legend/index.html

${BBBIKETMPDIR}/typ_legend/index.html:	${BBBIKEMKGMAPDIR}/typ/M000002a.TXT ${MISCSRCDIR}/typ2legend.pl
	${PERL} ${MISCSRCDIR}/typ2legend.pl < ${BBBIKEMKGMAPDIR}/typ/M000002a.TXT -f -o ${BBBIKETMPDIR}/typ_legend -title "Legende f�r die BBBike-Garmin-Karte" -keep polygon/0x0a,polygon/0x0c,polygon/0x0d,polygon/0x16,polygon/0x19,polygon/0x1a,polygon/0x3c,polygon/0x4e,polygon/0x50,line/0x01,line/0x03,line/0x04,line/0x05,line/0x06,line/0x0f,line/0x13,line/0x14,line/0x1a,line/0x1c,line/0x1e,line/0x2c,line/0x2d,line/0x2e,line/0x2f,line/0x30,line/0x31,line/0x32,line/0x33,line/0x34,line/0x35,line/0x36,line/0x37,line/0x38,line/0x39,line/0x3a,line/0x3b,line/0x3c,line/0x3d,line/0x3e,line/0x3f,point/0x70,point/0x71,point/0x74/0x01,point/0x74/0x02

typ-legend-osm: ${BBBIKETMPDIR}/typ_osm_legend/index.html

${BBBIKETMPDIR}/typ_osm_legend/index.html:	${BBBIKEMKGMAPDIR}/typ/M000002a.TXT ${MISCSRCDIR}/typ2legend.pl
	${PERL} ${MISCSRCDIR}/typ2legend.pl < ${BBBIKEMKGMAPDIR}/typ/M000002a.TXT -f -o ${BBBIKETMPDIR}/typ_osm_legend -title "Legende f�r die OSM-Garmin-Karte"

######################################################################
# Sourceforge release targets

do-garmindata-dist:	${BBBIKETMPDIR}/bbbike_routable_gmapsupp.img typ-legend-bbbike
	rm -rf /tmp/bbbike-b_de-garmin
	mkdir /tmp/bbbike-b_de-garmin
	(echo "Eine auf BBBike-Daten basierende Berlin-Karte f�r Garmin-Ger�te."; \
	 echo "Erzeugt mithilfe von mkgmap."; \
	 echo ""; \
	 echo "Einschr�nkungen:"; \
	 echo "* Zurzeit ist es nicht m�glich, die Karte zusammen mit anderen"; \
	 echo "  Karten gleichzeitig zu installieren. Es ist empfohlen, von"; \
	 echo "  einer bereits installierten Karte ein Backup zu machen."; \
	 echo ""; \
	 echo "Installation:"; \
	 echo "* Das Garmin-Ger�t �ber USB an einen PC anschlie�en und mounten"; \
	 echo "  oder alternativ die Micro-SD-Karte in ein Kartenleseger�t legen."; \
	 echo "* Eine existierende .../garmin/gmapsupp.img sollte gesichert werden."; \
	 echo "* Die Datei bbbike_routable_gmapsupp.img als .../garmin/gmapsupp.img kopieren."; \
	 echo ""; \
	 echo "Kartenlegende:"; \
	 echo "* Eine Legende der Karte ist in der ZIP-Datei unter map_legend/index.html"; \
	 echo "  zu finden."; \
	 echo ""; \
	 echo "Fragen per E-Mail an: slaven AT rezic DOT de"; \
	) | perl -pe 's{$$}{\r}' > /tmp/bbbike-b_de-garmin/README.txt
	rsync --archive --cvs-exclude ${BBBIKETMPDIR}/bbbike_routable_gmapsupp.img /tmp/bbbike-b_de-garmin/
	rsync --archive --cvs-exclude ${BBBIKETMPDIR}/typ_legend/ /tmp/bbbike-b_de-garmin/map_legend/
	cd /tmp && \
	    zip -r bbbike-b_de-garmin-$(TODAY_DATE).zip bbbike-b_de-garmin

garmindata-sf-release:	do-garmindata-dist garmindata-sf-release-show-notice

garmindata-sf-release-show-notice:
	@echo "Upload the file:"
	@echo ""
	@echo "    rsync -v /tmp/bbbike-b_de-garmin-$(TODAY_DATE).zip eserte@frs.sourceforge.net:/home/frs/project/bbbike/bbbikedata-b_de/$(TODAY_DATE)/"
	@echo ""
	@echo "Then check if things were created correctly in "
	@echo "    https://sourceforge.net/downloads/bbbike/bbbikedata-b_de"
	@echo "    https://sourceforge.net/downloads/bbbike/bbbikedata-b_de/$(TODAY_DATE)"
