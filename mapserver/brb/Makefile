#
# $Id: Makefile,v 1.5 2003/07/09 07:26:57 eserte Exp $
#

# Please run this file with BSD make (often called pmake).
# It is assumed that this directory is an subdirectory of the bbbike
# distribution like this:
#	.../bbbike
#	.../bbbike/mapserver/brb
#
# Variables marked with *** are first candidates for configuration.

# XXX should not be necessary!
# Absolute path to the bbbike source directory.
ABS_LOCAL_BBBIKE_DIR=	/home/e/eserte/src/bbbike			 # ***

# BRBDIR is the current directory. Do not use .CURDIR, because it may be
# called via "make -f" from another directory.
.if exists(${ABS_LOCAL_BBBIKE_DIR})
BRBDIR?=	${ABS_LOCAL_BBBIKE_DIR}/mapserver/brb
.else
BRBDIR?=	.
.endif
VPATH=		${BRBDIR}

# TARGET: set to destination system to build mapserver for
TARGET?=	local

# Auto-set TARGET for some well-known rules
.if make(dist-radzeit)
TARGET=		radzeit
.elif make(dist-radzeit.herceg.de)
TARGET=		radzeit.herceg.de
.endif

# XXX Hmmm. This should be done automatically somehow.
.if !exists(Makefile.${TARGET}.inc)
# This line may fail for older pmake versions. Please do as this line
# says (executing the touch command):
.error Please execute "touch -t 197001010000 Makefile.${TARGET}.inc"
.else
.include "Makefile.${TARGET}.inc"
.endif

LOCAL_BBBIKE_DIR=	${.CURDIR:H:H}
# The hostname of the web server:
LOCAL_HOST=		www						# ***
RADZEIT_APACHE_DIR=	${BBBIKE_RADZEIT_APACHE_DIR}
RADZEIT_HOST=		${BBBIKE_RADZEIT_HOST}

# Standard dimensions of mapserver image:
IMGWIDTH?=	550							# ***
IMGHEIGHT?=	550							# ***
IMAGECOLOR?=	225 225 225

#####################################################################
# Various destination system configurations

.if ${TARGET} == "radzeit.herceg.de"

RADZEIT_HOST=		radzeit.herceg.de
RADZEIT_APACHE_DIR=	/home/e/eserte/src/bbbike/projects/www.radzeit.de
BBBIKE_MAPSERVER_URL=	http://radzeit.herceg.de/cgi-bin/mapserv

.endif

.if ${TARGET} == "devpc01"
ABS_LOCAL_BBBIKE_DIR=	/home/slavenr/work2/bbbike
MAPSERVER_PROG_FSPATH=	/home/slavenr/work2/mapserver/mapserv.cgi
# XXX port number or not?
LOCAL_HOST=		localhost:8080
FONTS_LIST=		fonts-devpc01.list
.endif

.if ${TARGET} == "local" || ${TARGET} == "devpc01"

HOST=			$(LOCAL_HOST)
MAPSERVER_DIR=		$(LOCAL_BBBIKE_DIR)/mapserver/brb
# Relative URL to this directory:
MAPSERVER_RELURL=	/~eserte/mapserver/brb				# ***
MAPSERVER_URL=		http://$(HOST)$(MAPSERVER_RELURL)
# Relative URL to the mapserv binary:
MAPSERVER_PROG_RELURL=	/~eserte/cgi/mapserv.cgi			# ***
MAPSERVER_PROG_URL=	http://$(HOST)$(MAPSERVER_PROG_RELURL)
# Filesystem path of the mapserv binary:
MAPSERVER_PROG_FSPATH?=	/home/e/eserte/www/cgi/mapserv.cgi		# ***
IMAGE_DIR=		$(LOCAL_BBBIKE_DIR)/images
# Relative URL to the bbbike html and cgi directories (not important):
BBBIKE_HTML_RELURL=	/~eserte/bbbike/html				# ***
BBBIKE_CGI_RELURL=	/~eserte/bbbike/cgi				# ***
BBBIKE_URL=		http://$(HOST)$(BBBIKE_CGI_RELURL)/bbbike.cgi
# Which kind of images should be generated:
IMAGE_SUFFIX=		png # was: gif					# ***
# File with the font mapping for this host:
FONTS_LIST?=		fonts-vran.list					# ***
# The unix user of the webserver process:
WWW_USER=		eserte						# ***
TARGET_DIR=		${.CURDIR}

.elif ${TARGET} == "spiff"

HOST=			spiff
MAPSERVER_DIR=		$(LOCAL_BBBIKE_DIR)/mapserver/brb-spiff
MAPSERVER_RELURL=	/~eserte/mapserver/brb-spiff
MAPSERVER_URL=		http://$(HOST)$(MAPSERVER_RELURL)
MAPSERVER_PROG_RELURL=	/~eserte/cgi/mapserv-linux.cgi
MAPSERVER_PROG_URL=	http://$(HOST)$(MAPSERVER_PROG_RELURL)
IMAGE_DIR=		$(LOCAL_BBBIKE_DIR)/images
BBBIKE_HTML_RELURL=	/~eserte/bbbike/html
BBBIKE_CGI_RELURL=	/~eserte/bbbike/cgi
BBBIKE_URL=		http://$(HOST)$(BBBIKE_CGI_RELURL)/bbbike.cgi
IMAGE_SUFFIX=		png
FONTS_LIST=		fonts-spiff.list
WWW_USER=		eserte
TARGET_DIR=		${.CURDIR:H}/brb-spiff

.elif ${TARGET} == "radzeit" || ${TARGET} == "radzeit.herceg.de"

HOST=			$(RADZEIT_HOST)
MAPSERVER_DIR=		$(RADZEIT_APACHE_DIR)/htdocs/mapserver/brb
MAPSERVER_RELURL=	/mapserver/brb
MAPSERVER_URL=		http://$(HOST)$(MAPSERVER_RELURL)
#MAPSERVER_PROG_RELURL=	/cgi-bin/mapserv
#MAPSERVER_PROG_URL=	http://$(HOST)$(MAPSERVER_PROG_RELURL)
MAPSERVER_PROG_RELURL=	$(BBBIKE_MAPSERVER_URL:C/^http:\/\/[^\/]+//)
MAPSERVER_PROG_URL=	$(BBBIKE_MAPSERVER_URL)
# XXX should be changed to BBBike for real production
IMAGE_DIR=		$(RADZEIT_APACHE_DIR)/BBBike/images
BBBIKE_HTML_RELURL=	/BBBike/html
BBBIKE_CGI_RELURL=	/cgi-bin
BBBIKE_URL=		http://$(HOST)$(BBBIKE_CGI_RELURL)/bbbike.cgi
IMAGE_SUFFIX=		png
.if ${TARGET} == "radzeit"
FONTS_LIST=		fonts-radzeit.list
WWW_USER=		www
TARGET_DIR=		${.CURDIR:H}/brb-radzeit
.elif ${TARGET} == "radzeit.herceg.de"
FONTS_LIST=		fonts-vran.list
WWW_USER=		eserte
TARGET_DIR=		${.CURDIR:H}/brb-radzeit.herceg.de
.endif

.endif

######################################################################

# All Template-Toolkit variables
ALL_TPL_DEFINES=\
	--define MAPSERVER_DIR="$(MAPSERVER_DIR)" \
	--define MAPSERVER_RELURL="$(MAPSERVER_RELURL)" \
	--define MAPSERVER_URL="$(MAPSERVER_URL)" \
	--define MAPSERVER_PROG_RELURL="$(MAPSERVER_PROG_RELURL)" \
	--define MAPSERVER_PROG_URL="$(MAPSERVER_PROG_URL)" \
	--define MAPSERVER_PROG_FSPATH="$(MAPSERVER_PROG_FSPATH)" \
	--define IMAGE_DIR="$(IMAGE_DIR)" \
	--define BBBIKE_HTML_RELURL="$(BBBIKE_HTML_RELURL)" \
	--define BBBIKE_URL="$(BBBIKE_URL)" \
	--define BBBIKE_CGI_RELURL="$(BBBIKE_CGI_RELURL)" \
	--define IMAGE_SUFFIX="$(IMAGE_SUFFIX)" \
	--define FONTS_LIST="$(FONTS_LIST)" \
	--define WWW_USER="$(WWW_USER)" \
	--define ALL_LAYERS="$(ALL_LAYERS)" \
	--define EMAIL="$(EMAIL)" \
	--define BBBIKE_SF_WWW="$(BBBIKE_SF_WWW)" \
	--define IMGWIDTH="$(IMGWIDTH)" \
	--define IMGHEIGHT="$(IMGHEIGHT)" \
	--define IMAGECOLOR="$(IMAGECOLOR)" \
	--define EDITWARNHTML="<!-- DO NOT EDIT. Created automatically from ${.ALLSRC:M*tpl} -->" \
	--define EDITWARNJS="/* DO NOT EDIT. Created automatically from ${.ALLSRC:M*tpl} */" \
	--define EDITWARNMAP="\#\# DO NOT EDIT. Created automatically from ${.ALLSRC:M*tpl}" \
	--define SMALLDEVICE=0

# Distfiles for dist-* rules
DISTFILES=\
	Makefile \
	Makefile.${TARGET}.inc \
	brb-ipaq.map-tpl \
	brb.css \
	brb.html-tpl \
	brb.js-tpl \
	brb.map-tpl \
	brb_init.html-tpl \
	cleanup \
	crontab.tpl \
	empty.html \
	help.html-tpl \
	mkroutemap \
	query.html \
	query_footer.html-tpl \
	query_footer2.html \
	query_header.html-tpl \
	query_header2.html \


RADZEIT_DIST_DIR=/tmp/radzeit_mapserver_dist
SPIFF_DIST_DIR=/home/e/eserte/src/bbbike/mapserver/brb-spiff

# Variables slurped in from bbbike/Makefile.PL
ADD_MAKEFILE_VARS=\
	RSYNC \
	BBBIKE_RADZEIT_USER BBBIKE_RADZEIT_HOST BBBIKE_RADZEIT_APACHE_DIR \

# Variables slurped in from BBBikeVar.pm
ADD_BBBIKEVAR_VARS=\
	BBBIKE_MAPSERVER_URL \
	BBBIKE_MAPSERVER_DIRECT \
	BBBIKE_SF_WWW \
	EMAIL \

MAPFILES=	brb.map brb-b.map brb-wide.map
HTMLFILES=	brb.html brb_init.html brb.js help.html query_header.html query_footer.html index.html
######################################################################

all:	build-all

clean:
	rm -f ${MAPFILES} ${HTMLFILES}

build-all: Makefile.${TARGET}.inc maps html misc

maps:	${MAPFILES}

html:	${HTMLFILES}

misc:	crontab httpd.conf

Makefile.${TARGET}.inc:	${ABS_LOCAL_BBBIKE_DIR}/Makefile ${ABS_LOCAL_BBBIKE_DIR}/BBBikeVar.pm Makefile
	rm $@
	touch $@
	chmod ugo+r $@
	echo "### DO NOT EDIT. Automatically created" >> $@
.for makefile_var in $(ADD_MAKEFILE_VARS)
	@echo -n "$(makefile_var)=	" >> $@
	@${MAKE} -f ${ABS_LOCAL_BBBIKE_DIR}/Makefile -V $(makefile_var) >> $@
.endfor
.for bbbikevar_var in $(ADD_BBBIKEVAR_VARS)
	@echo -n "$(bbbikevar_var)=	" >> $@
	perl -I${ABS_LOCAL_BBBIKE_DIR} -MBBBikeVar -e 'print $$BBBike::$(bbbikevar_var), "\n"' >> $@
.endfor
	@echo -n "ALL_LAYERS=	" >> $@
	perl -I${ABS_LOCAL_BBBIKE_DIR} -MBBBikeMapserver -e 'print join(" ", BBBikeMapserver::all_layers()), "\n"' >> $@

.SUFFIXES:	.html-tpl .html .map-tpl .map .js-tpl .js .conf-tpl

.html-tpl.html:	Makefile Makefile.${TARGET}.inc
	tpage $(ALL_TPL_DEFINES) ${.ALLSRC:M*tpl} > $@
	chmod ugo+r $@

.js-tpl.js:	Makefile Makefile.${TARGET}.inc
	tpage $(ALL_TPL_DEFINES) ${.ALLSRC:M*tpl} > $@
	chmod ugo+r $@

.map-tpl.map:	Makefile Makefile.${TARGET}.inc
	tpage $(ALL_TPL_DEFINES) ${.ALLSRC:M*tpl} > $@
	chmod ugo+r $@

.conf-tpl.conf:	Makefile Makefile.${TARGET}.inc
	tpage $(ALL_TPL_DEFINES) ${.ALLSRC:M*tpl} > $@
	chmod ugo+r $@

######################################################################
# maps

brb-b.map:	brb.map mkroutemap
	${BRBDIR}/mkroutemap -force -scope city brb.map brb-b.map
	chmod ugo+r $@

brb-wide.map:	brb.map mkroutemap
	${BRBDIR}/mkroutemap -force -scope wideregion brb.map brb-wide.map
	chmod ugo+r $@

# XXX temporary:
# zur Zeit auch kein Unterschied...
brb-devel.map:	brb.map
	sed -e 's/\.gif/\.png/g' < $> > $@

brb-ipaq.map:

######################################################################
# Temporaries
.PHONY: sternfahrt2003
sternfahrt2003:	sternfahrt2003/sternfahrt2003.html sternfahrt2003/sternfahrt2003_init.html sternfahrt2003/sternfahrt2003-b.map

sternfahrt2003/sternfahrt2003-b.map:	sternfahrt2003/sternfahrt2003.map mkroutemap
	${BRBDIR}/mkroutemap -force -scope city sternfahrt2003/sternfahrt2003.map sternfahrt2003/sternfahrt2003-b.map
	chmod ugo+r $@

######################################################################
# html

index.html:	brb_init.html
	-rm -f index.html
	ln -s brb_init.html index.html

check-html:	brb.html brb_init.html help.html empty.html
	-for html_file in $>; do \
	    echo "*** $$html_file"; \
	    tidy -eq $$html_file; \
	done

######################################################################
# misc

crontab:	crontab.tpl Makefile
	tpage $(ALL_TPL_DEFINES) ${.ALLSRC:M*tpl} > $@
	chmod ugo+r $@

httpd.conf:	httpd.conf-tpl Makefile
	tpage $(ALL_TPL_DEFINES) ${.ALLSRC:M*tpl} > $@
	chmod ugo+r $@

######################################################################
# dists

dist-radzeit:	# build-all
	[ ${TARGET} = "radzeit" ]
	[ ! -d $(RADZEIT_DIST_DIR) ] && mkdir $(RADZEIT_DIST_DIR) || true
	chmod ugo+rx $(RADZEIT_DIST_DIR)
	cp -pf $(DISTFILES) fonts-radzeit.list $(RADZEIT_DIST_DIR)
	cp -pR data $(RADZEIT_DIST_DIR)
	cp -pR graphics $(RADZEIT_DIST_DIR)
	-mkdir $(RADZEIT_DIST_DIR)/tmp
	chmod ugo+rx $(RADZEIT_DIST_DIR)/tmp
	cd $(RADZEIT_DIST_DIR) && $(MAKE) $(MAKEFLAGS) TARGET=radzeit

dist-radzeit.herceg.de:	# build-all
	[ ${TARGET} = "radzeit.herceg.de" ]
	[ ! -d $(RADZEIT_DIST_DIR) ] && mkdir $(RADZEIT_DIST_DIR) || true
	chmod ugo+rx $(RADZEIT_DIST_DIR)
	cp -pf $(DISTFILES) fonts-vran.list $(RADZEIT_DIST_DIR)
	cp -pR data $(RADZEIT_DIST_DIR)
	cp -pR graphics $(RADZEIT_DIST_DIR)
	-mkdir $(RADZEIT_DIST_DIR)/tmp
	chmod ugo+rx $(RADZEIT_DIST_DIR)/tmp
	cd $(RADZEIT_DIST_DIR) && $(MAKE) $(MAKEFLAGS) TARGET=radzeit.herceg.de

rsync-radzeit:
	[ ! -d $(RADZEIT_DIST_DIR) ] && ( echo Please execute ${MAKE} dist-radzeit first; false ) || true
	cd $(RADZEIT_DIST_DIR) && rsync -Pvzrt . $(BBBIKE_RADZEIT_USER)@$(BBBIKE_RADZEIT_HOST):$(RADZEIT_APACHE_DIR)/htdocs/mapserver/brb/

dist-spiff:
	[ ! -d $(SPIFF_DIST_DIR) ] && mkdir $(SPIFF_DIST_DIR) || true
	chmod ugo+rx $(SPIFF_DIST_DIR)
	cp -pf $(DISTFILES) fonts-spiff.list $(SPIFF_DIST_DIR)
	cp -pR data $(SPIFF_DIST_DIR)
	cp -pR graphics $(SPIFF_DIST_DIR)
	-mkdir $(SPIFF_DIST_DIR)/tmp
	chmod ugo+rx $(SPIFF_DIST_DIR)/tmp
	cd $(SPIFF_DIST_DIR) && $(MAKE) $(MAKEFLAGS) TARGET=spiff

######################################################################
# Download: http://mapserver.gis.umn.edu/dist/mapserver-3.6.4.tar.gz

# Patches für 3.6.3/3.6.4 sind unter
# vran:/usr/local/src/mapserver/private-patches* vorhanden

# Um mapserver zu bauen, sind folgende configure-Aufrufe notwendig:
# vran:           sh configure --with-freetype=/usr/local --with-jpeg=/usr/local --with-gd=/usr/local
# www.radzeit.de: sh configure --with-jpeg=/usr/src/jpeg-6b --with-freetype=/usr/X11R6
# spiff:          sh configure

# GD 2.0.x ist bevorzugt zu verwenden, da die Textausgabe dort
# wesentlich besser funktioniert.

# Freetype 2.1.2 sollte nicht verwendet werden, da Textwinkel dort
# falsch berechnet werden (benötigt ein Minus in Zeile 404 von
# maplabel.c, mapserver 3.6.3)

# To compile 3.7 from CVS
# vran:           sh configure --with-freetype=/usr/local --with-jpeg=/usr/local --with-gd=/usr/local --with-png=/usr/local --with-xpm=/usr/X11R6 --with-ming=/usr/local
# then hand-edit Makefile: MING_INC=-I/usr/local/include/ming
# and add -lming to MING_LIB
