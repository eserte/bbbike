#
# $Id: Makefile,v 1.74 2009/06/07 21:08:29 eserte Exp $
#

# Please run this file with BSD make (often called pmake).
# It is assumed that this directory is an subdirectory of the bbbike
# distribution like this:
#	.../bbbike
#	.../bbbike/mapserver/brb
#
# Variables marked with *** are first candidates for configuration.

# Absolute path to the bbbike source directory.
# It should be really absolute, because this directory may be replicated to
# elsewhere (e.g. in the projects/radzeit Makefile).
# As a fallback, we use ../..
.if exists(/home/e/eserte/src/bbbike)
ABS_LOCAL_BBBIKE_DIR=	/home/e/eserte/src/bbbike
.else
ABS_LOCAL_BBBIKE_DIR!=	perl -MCwd=realpath -e 'print realpath("../..")'
.endif
BBBIKE_DATA_DIR=	$(ABS_LOCAL_BBBIKE_DIR)/data
BBBIKE_MISCSRC_DIR=	$(ABS_LOCAL_BBBIKE_DIR)/miscsrc

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

OSNAME!=	uname

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
LOCAL_HOST=		localhost						# ***
RADZEIT_APACHE_DIR=	${BBBIKE_RADZEIT_APACHE_DIR}
RADZEIT_HOST=		${BBBIKE_RADZEIT_HOST}

# Standard dimensions of mapserver image:
IMGWIDTH?=	550							# ***
IMGHEIGHT?=	550							# ***
IMAGECOLOR?=	225 225 225

#####################################################################
# Various destination system configurations

RADZEIT_APACHE_DIR_LOCAL=	$(ABS_LOCAL_BBBIKE_DIR)/projects/www.radzeit.de

.if ${TARGET} == "automatic"
BBBIKECGI_CONFIG_LOCAL=	../../cgi/bbbike.cgi.config
WWW_HOST?=		localhost
BBBIKE_CGI_RELURL?=	/bbbike/cgi
BBBIKE_HTML_RELURL?=	/bbbike/html
MAPSERVER_RELURL?=	/bbbike/mapserver/brb
BBBIKE_URL?=		http://$(WWW_HOST)$(BBBIKE_CGI_RELURL)/bbbike.cgi
MAPSERVER_URL?=		http://$(WWW_HOST)$(MAPSERVER_RELURL)
BBBIKE_IMAGES_RELURL?=	/bbbike/images
MAPSERVER_DIR=		$(LOCAL_BBBIKE_DIR)/mapserver/brb
IMAGE_DIR=		$(LOCAL_BBBIKE_DIR)/images
IMAGE_SUFFIX=		gif
.if exists(/etc/debian_version)
FONTS_LIST?=		fonts-debian.list
.else
FONTS_LIST?=		fonts-biokovo.list
.endif
.endif

.if ${TARGET} == "radzeit.herceg.de"

RADZEIT_HOST=		radzeit.herceg.de
RADZEIT_APACHE_DIR=	$(RADZEIT_APACHE_DIR_LOCAL)
BBBIKE_MAPSERVER_URL=	http://$(RADZEIT_HOST)/cgi-bin/mapserv

.elif ${TARGET} == "bbbike.hosteurope.herceg.de"

RADZEIT_HOST=		bbbike.hosteurope.herceg.de
RADZEIT_APACHE_DIR_LOCAL=	$(ABS_LOCAL_BBBIKE_DIR)/projects/bbbike.de-hosteurope
RADZEIT_APACHE_DIR=	$(RADZEIT_APACHE_DIR_LOCAL)
BBBIKE_MAPSERVER_URL=	http://$(RADZEIT_HOST)/cgi-bin/mapserv

.elif ${TARGET} == "hosteurope"

# compatibility with usage of old ...RADZEIT... vars
BBBIKE_RADZEIT_USER=	${BBBIKE_HOSTEUROPE_USER}
BBBIKE_RADZEIT_HOST=	${BBBIKE_HOSTEUROPE_HOST}
BBBIKE_RADZEIT_APACHE_DIR=${BBBIKE_HOSTEUROPE_APACHE_DIR}

.endif

.if ${TARGET} == "local"

HOST=			$(LOCAL_HOST)
MAPSERVER_DIR=		$(LOCAL_BBBIKE_DIR)/mapserver/brb
# Relative URL to this directory and to the mapserv binary:
MAPSERVER_RELURL=	/bbbike/mapserver/brb				# ***
MAPSERVER_PROG_RELURL?=	/cgi/mapserv.cgi				# ***
MAPSERVER_URL=		http://$(HOST)$(MAPSERVER_RELURL)
MAPSERVER_PROG_URL?=	http://$(HOST)$(MAPSERVER_PROG_RELURL)
# Filesystem path of the mapserv binary:
MAPSERVER_PROG_FSPATH?=	/home/e/eserte/www/cgi/mapserv.cgi		# ***
IMAGE_DIR=		$(LOCAL_BBBIKE_DIR)/images
# Relative URL to the bbbike html and cgi directories:
BBBIKE_HTML_RELURL=	/bbbike/html					# ***
BBBIKE_CGI_RELURL=	/bbbike/cgi					# ***
BBBIKE_IMAGES_RELURL=	/bbbike/images					# ***
BBBIKECGI_CONFIG=	$(ABS_LOCAL_BBBIKE_DIR)/cgi/bbbike.cgi.config
BBBIKECGI_CONFIG_LOCAL=	$(BBBIKECGI_CONFIG)
BBBIKE_URL=		http://$(HOST)$(BBBIKE_CGI_RELURL)/bbbike.cgi
# Which kind of images should be generated:
IMAGE_SUFFIX=		gif # was: png					# ***
# File with the font mapping for this host:
.if exists(/etc/debian_version)
FONTS_LIST?=		fonts-debian.list
.else
FONTS_LIST?=		fonts-biokovo.list				# ***
.endif
# The unix user of the webserver process:
WWW_USER=		eserte						# ***

.elif ${TARGET} == "radzeit" || ${TARGET} == "radzeit.herceg.de"

HOST=			$(RADZEIT_HOST)
HTDOCS=			public
MAPSERVER_DIR=		$(RADZEIT_APACHE_DIR)/$(HTDOCS)/mapserver/brb
MAPSERVER_RELURL=	/mapserver/brb
MAPSERVER_URL=		http://$(HOST)$(MAPSERVER_RELURL)
#MAPSERVER_PROG_RELURL=	/cgi-bin/mapserv
#MAPSERVER_PROG_URL=	http://$(HOST)$(MAPSERVER_PROG_RELURL)
BBBIKECGI_CONFIG=	$(RADZEIT_APACHE_DIR)/cgi-bin/bbbike.cgi.config
BBBIKECGI_CONFIG_LOCAL=	$(RADZEIT_APACHE_DIR_LOCAL)/cgi-bin/bbbike.cgi.config
MAPSERVER_PROG_RELURL=	$(BBBIKE_MAPSERVER_URL:C/^http:\/\/[^\/]+//)
MAPSERVER_PROG_URL=	$(BBBIKE_MAPSERVER_URL)
MAPSERVER_VERSION=	3.6.6
IMAGE_DIR=		$(RADZEIT_APACHE_DIR)/BBBike/images
BBBIKE_HTML_RELURL=	/BBBike/html
BBBIKE_CGI_RELURL=	/cgi-bin
BBBIKE_IMAGES_RELURL=	/BBBike/images
BBBIKE_URL=		http://$(HOST)$(BBBIKE_CGI_RELURL)/bbbike.cgi
IMAGE_SUFFIX=		gif

.if ${TARGET} == "radzeit"
WWW_USER=		www
.elif ${TARGET} == "radzeit.herceg.de"
WWW_USER=		eserte
.endif

.if ${TARGET} == "radzeit"
FONTS_LIST=		fonts-radzeit.list
.elif ${TARGET} == "radzeit.herceg.de" && exists(/etc/debian_version)
FONTS_LIST=		fonts-debian.list
.elif ${TARGET} == "radzeit.herceg.de"
FONTS_LIST=		fonts-biokovo.list
.endif

.elif ${TARGET} == "hosteurope" || ${TARGET} == "bbbike.hosteurope.herceg.de"

HOST=			$(RADZEIT_HOST)
HTDOCS=			public
MAPSERVER_DIR=		$(RADZEIT_APACHE_DIR)/$(HTDOCS)/mapserver/brb
MAPSERVER_RELURL=	/mapserver/brb
MAPSERVER_URL=		http://$(HOST)$(MAPSERVER_RELURL)
#MAPSERVER_PROG_RELURL=	/cgi-bin/mapserv
#MAPSERVER_PROG_URL=	http://$(HOST)$(MAPSERVER_PROG_RELURL)
BBBIKECGI_CONFIG=	$(RADZEIT_APACHE_DIR)/cgi-bin/bbbike.cgi.config
BBBIKECGI_CONFIG_LOCAL=	$(RADZEIT_APACHE_DIR_LOCAL)/cgi-bin/bbbike.cgi.config
MAPSERVER_PROG_RELURL=	$(BBBIKE_MAPSERVER_URL:C/^http:\/\/[^\/]+//)
MAPSERVER_PROG_URL=	$(BBBIKE_MAPSERVER_URL)
MAPSERVER_VERSION=	5
IMAGE_DIR=		$(RADZEIT_APACHE_DIR)/BBBike/images
BBBIKE_HTML_RELURL=	/BBBike/html
BBBIKE_CGI_RELURL=	/cgi-bin
BBBIKE_IMAGES_RELURL=	/BBBike/images
BBBIKE_URL=		http://$(HOST)$(BBBIKE_CGI_RELURL)/bbbike.cgi
IMAGE_SUFFIX=		png

.if ${TARGET} == "hosteurope"
WWW_USER=		www-data
.elif ${TARGET} == "bbbike.hosteurope.herceg.de"
WWW_USER=		eserte
.endif

.if ${TARGET} == "hosteurope"
FONTS_LIST=		fonts-debian.list
.elif ${TARGET} == "bbbike.hosteurope.herceg.de" && exists(/etc/debian_version)
FONTS_LIST=		fonts-debian.list
.elif ${TARGET} == "bbbike.hosteurope.herceg.de"
FONTS_LIST=		fonts-biokovo.list
.endif

.endif

######################################################################

TPAGE?=		tpage --compile_ext=.ttc --compile_dir=/tmp/bbbikettc-${TARGET}

SCOPES=		brb b inner-b wide p

# All Template-Toolkit variables
ALL_TPL_DEFINES=\
	--define MAPSERVER_DIR="$(MAPSERVER_DIR)" \
	--define MAPSERVER_RELURL="$(MAPSERVER_RELURL)" \
	--define MAPSERVER_URL="$(MAPSERVER_URL)" \
	--define MAPSERVER_PROG_RELURL="$(MAPSERVER_PROG_RELURL)" \
	--define MAPSERVER_PROG_URL="$(MAPSERVER_PROG_URL)" \
	--define MAPSERVER_PROG_FSPATH="$(MAPSERVER_PROG_FSPATH)" \
	--define MAPSERVER_VERSION="$(MAPSERVER_VERSION)" \
	--define IMAGE_DIR="$(IMAGE_DIR)" \
	--define BBBIKE_HTML_RELURL="$(BBBIKE_HTML_RELURL)" \
	--define BBBIKE_URL="$(BBBIKE_URL)" \
	--define BBBIKE_URL_ENC=`perl -MURI::Escape -e 'print uri_escape(shift)' $(BBBIKE_URL)` \
	--define BBBIKE_CGI_RELURL="$(BBBIKE_CGI_RELURL)" \
	--define BBBIKE_IMAGES_RELURL="$(BBBIKE_IMAGES_RELURL)" \
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
	--define SMALLDEVICE=0 \
	--define SCOPES_STRING="$(SCOPES)" \


# Distfiles for dist-* rules
DISTFILES=\
	Makefile \
	Makefile.${TARGET}.inc \
	brb-ipaq.map-tpl \
	brb.css \
	brb.html-tpl \
	brb.js-tpl \
	brb.map-tpl \
	brb.map-inc \
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
	std.inc


#XXX should not hardcode the year
DISTFILES_STERNFAHRT_2004=\
	sternfahrt2004/sternfahrt2004.html-tpl \
	sternfahrt2004/sternfahrt2004_init.html-tpl \
	sternfahrt2004/after_strassen_annotations.inc \
	sternfahrt2004/after_marker.inc

DISTFILES_STERNFAHRT_2005=\
	sternfahrt2005/sternfahrt2005.html-tpl \
	sternfahrt2005/sternfahrt2005_init.html-tpl \
	sternfahrt2005/after_strassen_annotations.inc \
	sternfahrt2005/after_marker.inc \
	sternfahrt2005/sternfahrt2005.inc

DISTFILES_STERNFAHRT_2006=\
	sternfahrt2006/sternfahrt2006.html-tpl \
	sternfahrt2006/sternfahrt2006_init.html-tpl \
	sternfahrt2006/after_strassen_annotations.inc \
	sternfahrt2006/after_marker.inc \
	sternfahrt2006/sternfahrt2006.inc

DISTFILES_STERNFAHRT_2007=\
	sternfahrt2007/sternfahrt2007_init.html-tpl \
	sternfahrt2007/after_strassen_annotations.inc \
	sternfahrt2007/after_marker.inc \
	sternfahrt2007/sternfahrt2007.inc

RADZEIT_DIST_DIR=/tmp/radzeit_mapserver_dist

# Variables slurped in from bbbike/Makefile.PL
ADD_MAKEFILE_VARS=\
	RSYNC \
	BBBIKE_RADZEIT_USER BBBIKE_RADZEIT_HOST BBBIKE_RADZEIT_APACHE_DIR \
	BBBIKE_HOSTEUROPE_USER BBBIKE_HOSTEUROPE_HOST BBBIKE_HOSTEUROPE_APACHE_DIR \

# Variables slurped in from BBBikeVar.pm
ADD_BBBIKEVAR_VARS=\
	BBBIKE_MAPSERVER_URL \
	BBBIKE_MAPSERVER_DIRECT \
	BBBIKE_SF_WWW \
	EMAIL \

# Variables slurped in from bbbike.cgi.config (without sigil)
ADD_BBBIKECGICONFIG_VARS=\
	MAPSERVER_PROG_RELURL|mapserver_prog_relurl\
	MAPSERVER_PROG_URL|mapserver_prog_url\

MAPFILES=	$(SCOPES:S/^/brb-/:S/$/.map/)
MAPFILES_EXTRA=	brb.map
IPAQ_MAPFILES=	$(SCOPES:S/^/brb-ipaq-/:S/$/.map/)
IPAQ_MAPFILES_EXTRA=	brb-ipaq.map
HTMLFILES=	brb.html brb_init.html brb.js help.html query_header.html query_footer.html index.html \
		radroute.html
TEMPORARIES=	radroute_body.html
######################################################################

.MAIN: all

.BEGIN:
.if !exists(Makefile.${TARGET}.inc)
	touch -t 197001010000 Makefile.${TARGET}.inc
.endif
.if make(all) || make(build-all)
.if !exists(.built_for.${TARGET})
	touch -t 197001010000 Makefile.${TARGET}.inc
.endif
.endif

all:	build-all

clean:
	rm -f ${MAPFILES} ${MAPFILES_EXTRA} ${IPAQ_MAPFILES} ${IPAQ_MAPFILES_EXTRA} ${HTMLFILES} ${TEMPORARIES}

build-all: Makefile.${TARGET}.inc .WAIT maps html misc .WAIT .built_for.${TARGET}

.built_for.${TARGET}:
	rm -f .built_for.*
	touch .built_for.${TARGET}

maps:	${MAPFILES} ${MAPFILES_EXTRA} ${IPAQ_MAPFILES} ${IPAQ_MAPFILES_EXTRA}

html:	${HTMLFILES}

misc:	tmp-directory permissions crontab check-crontab httpd.conf

Makefile.${TARGET}.inc:	${ABS_LOCAL_BBBIKE_DIR}/Makefile \
			${ABS_LOCAL_BBBIKE_DIR}/BBBikeVar.pm \
			${ABS_LOCAL_BBBIKE_DIR}/BBBikeMapserver.pm \
			Makefile
	rm $@
	touch $@
	chmod ugo+r $@
	echo "### DO NOT EDIT. Automatically created by Makefile" >> $@
.for makefile_var in $(ADD_MAKEFILE_VARS)
	echo -n "$(makefile_var)=	" >> $@
	${MAKE} -f ${ABS_LOCAL_BBBIKE_DIR}/Makefile -V $(makefile_var) >> $@
.endfor
.for bbbikevar_var in $(ADD_BBBIKEVAR_VARS)
	echo -n "$(bbbikevar_var)=	" >> $@
	perl -I${ABS_LOCAL_BBBIKE_DIR} -MBBBikeVar -e 'print $$BBBike::$(bbbikevar_var), "\n"' >> $@
.endfor
.for bbbikecgiconfig_var in $(ADD_BBBIKECGICONFIG_VARS)
	echo -n "${bbbikecgiconfig_var:C/\\|.*//}=	" >> $@
	perl -e 'require "${BBBIKECGI_CONFIG_LOCAL}"; print $$${bbbikecgiconfig_var:C/.*\\|//}, "\n"' >> $@
.endfor
	echo -n "ALL_LAYERS=	" >> $@
	perl -I${ABS_LOCAL_BBBIKE_DIR} -MBBBikeMapserver -e 'print join(" ", BBBikeMapserver::all_layers()), "\n"' >> $@

.SUFFIXES:	.html-tpl .html .map-tpl .map .js-tpl .js .conf-tpl

.html-tpl.html:	Makefile Makefile.${TARGET}.inc std.inc
	$(TPAGE) $(ALL_TPL_DEFINES) ${.ALLSRC:M*tpl} > $@
	chmod ugo+r $@

# Additional dependency ("last updated date")
brb.html:	data/strassen.shp

.js-tpl.js:	Makefile Makefile.${TARGET}.inc
	$(TPAGE) $(ALL_TPL_DEFINES) ${.ALLSRC:M*tpl} > $@
	chmod ugo+r $@

.map-tpl.map:	Makefile Makefile.${TARGET}.inc
	$(TPAGE) $(ALL_TPL_DEFINES) ${.ALLSRC:M*tpl} > $@
	chmod ugo+r $@

.conf-tpl.conf:	Makefile Makefile.${TARGET}.inc
	$(TPAGE) $(ALL_TPL_DEFINES) ${.ALLSRC:M*tpl} > $@
	chmod ugo+r $@

######################################################################
# maps

.brb.map:	brb.map-tpl brb.map-inc Makefile Makefile.${TARGET}.inc
	$(TPAGE) $(ALL_TPL_DEFINES) ${.ALLSRC:M*tpl} > $@
	chmod ugo+r $@

brb.map:	brb-brb.map
	[ -L $@ ] || ln -s brb-brb.map $@

.for scope in $(SCOPES)
brb-$(scope).map:	.brb.map mkroutemap
	${BRBDIR}/mkroutemap -force -scope $(scope) .brb.map $@
	chmod ugo+r $@
.endfor

######################################################################
# ipaq maps

.brb-ipaq.map:	brb-ipaq.map-tpl brb.map-inc Makefile Makefile.${TARGET}.inc
	$(TPAGE) $(ALL_TPL_DEFINES) ${.ALLSRC:M*tpl} > $@
	chmod ugo+r $@

brb-ipaq.map:	brb-ipaq-brb.map
	[ -L $@ ] || ln -s brb-ipaq-brb.map $@

.for scope in $(SCOPES)
brb-ipaq-$(scope).map:	.brb-ipaq.map mkroutemap
	${BRBDIR}/mkroutemap -force -scope $(scope) .brb-ipaq.map $@
	chmod ugo+r $@
.endfor

######################################################################
# Temporaries

# Für 2003 sollten Symlinks im mapserver-Rootverzeichnis auf die Dateien
# in sternfahrt2003 zeigen (backward compatibility)

STERNFARTEN= 2003 2004 2006 2006 2007

#.PHONY: ${STERNFAHRTEN:S/^/sternfahrt/g}

.PHONY: sternfahrt2003 sternfahrt2004 sternfahrt2005 sternfahrt2006 sternfahrt2007

# XXX Makefile problems?!

#.for year in 2004 2003 # ${STERNFAHRTEN}

STERNFAHRT2007_TARGETS=sternfahrt2007/sternfahrt2007.html \
		sternfahrt2007.html \
		sternfahrt2007/sternfahrt2007_init.html \
		sternfahrt2007_init.html \
		sternfahrt2007/sternfahrt2007.map \
		sternfahrt2007.map \
		data/sternfahrt2007.dbf \
		data/sternfahrt2007.shp \
		data/sternfahrt2007.shx \
		data/treffpunkte2007.dbf \
		data/treffpunkte2007.shp \
		data/treffpunkte2007.shx

.for scope in $(SCOPES)
STERNFAHRT2007_TARGETS+=sternfahrt2007/sternfahrt2007-$(scope).map
# and the symlink:
STERNFAHRT2007_TARGETS+=sternfahrt2007-$(scope).map
.endfor

sternfahrt2007:	$(STERNFAHRT2007_TARGETS)

STERNFAHRT_2007_DEFINES=\
	--define MAPNAME="sternfahrt2007" \
	--define EXTENT="4658 7874 13542 16766" \
	--define TEMPLATE="sternfahrt2007" \
	--define INCLUDE_AFTER_STRASSEN_ANNOTATIONS="sternfahrt2007/after_strassen_annotations.inc" \
	--define INCLUDE_AFTER_MARKER="sternfahrt2007/after_marker.inc" \
	--define REFMAP_REGION_EXTENT="-15700 -14985 37034 37749" \

sternfahrt2007/.sternfahrt2007.map:	brb.map-tpl Makefile Makefile.${TARGET}.inc
	$(TPAGE) $(ALL_TPL_DEFINES) $(STERNFAHRT_2007_DEFINES) brb.map-tpl > $@
	chmod ugo+r $@

.for scope in $(SCOPES)
sternfahrt2007/sternfahrt2007-$(scope).map:	sternfahrt2007/.sternfahrt2007.map mkroutemap
	${BRBDIR}/mkroutemap -force -scope $(scope) sternfahrt2007/.sternfahrt2007.map $@ || rm -f $@
	chmod ugo+r $@

sternfahrt2007-$(scope).map:	sternfahrt2007/sternfahrt2007-$(scope).map
	[ -L $@ ] || ln -s sternfahrt2007/sternfahrt2007-$(scope).map
.endfor

sternfahrt2007/sternfahrt2007.map:	sternfahrt2007/sternfahrt2007-brb.map
	cd sternfahrt2007 && ([ -L sternfahrt2007.map ] || ln -s sternfahrt2007-brb.map sternfahrt2007.map)

sternfahrt2007.map: sternfahrt2007/sternfahrt2007.map
	[ -L $@ ] || ln -s sternfahrt2007/sternfahrt2007.map

sternfahrt2007/sternfahrt2007.html:	brb.html-tpl sternfahrt2007/sternfahrt2007.inc Makefile Makefile.${TARGET}.inc
	$(TPAGE) $(ALL_TPL_DEFINES) --define INCLUDE_FILE=sternfahrt2007/sternfahrt2007.inc brb.html-tpl > $@
	chmod ugo+r $@

sternfahrt2007.html:	sternfahrt2007/sternfahrt2007.html
	[ -L $@ ] || ln -s sternfahrt2007/sternfahrt2007.html

sternfahrt2007_init.html:	sternfahrt2007/sternfahrt2007_init.html
	[ -L $@ ] || ln -s sternfahrt2007/sternfahrt2007_init.html

# Can't use relative paths here, because the stuff is copied to
# .../projects/www.radzeit.de/...
.for i in sternfahrt2007.dbf sternfahrt2007.shp sternfahrt2007.shx treffpunkte2007.dbf treffpunkte2007.shp treffpunkte2007.shx
data/$i:
	[ -e $(ABS_LOCAL_BBBIKE_DIR)/misc/sternfahrt_2007/$i ] || (cd $(ABS_LOCAL_BBBIKE_DIR)/misc/sternfahrt_2007 && ${MAKE})
	cd data && \
	    [ -L $i ] || ln -s $(ABS_LOCAL_BBBIKE_DIR)/misc/sternfahrt_2007/$i
.endfor

#.endfor

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

radroute.html:	radroute_header.html \
		radroute_body.html \
		radroute_footer.html
	cat	radroute_header.html \
		radroute_body.html \
		radroute_footer.html > $@
	chmod ugo+r $@

radroute_body.html:	$(BBBIKE_DATA_DIR)/comments_route-orig \
			$(BBBIKE_MISCSRC_DIR)/bbd2mapservhtml.pl \
			$(BBBIKE_MISCSRC_DIR)/grepstrassen \
			Makefile
	$(BBBIKE_MISCSRC_DIR)/grepstrassen -v -sectionrx ignorieren $(BBBIKE_DATA_DIR)/comments_route-orig |\
	    $(BBBIKE_MISCSRC_DIR)/grepstrassen -v -sectionrx "In Routenliste ignorieren" |\
	    perl -pe 's{(Flaeming-Skate)\s+\(.*\)\t}{$$1\t}' |\
	    $(BBBIKE_MISCSRC_DIR)/bbd2mapservhtml.pl \
		-bbbikeurl $(BBBIKE_URL) \
		-email $(EMAIL) \
		-linklist -preferalias -partialhtml \
		-headlines \
		-mapscale 1:40000 \
		-center city=Berlin_DE -centernearest \
		-althandling \
		-onlyonedirection \
		> $@

######################################################################
# misc

tmp-directory:
	mkdir -p tmp

permissions:
	chmod ugo+r brb.map-inc
	chmod ugo+rx,ug+w tmp
	chmod ugo+rx,ug+w .
.if exists(/etc/debian_version)
	[ "`stat --format=%G tmp`" = "www-data" ] || sudo chgrp www-data tmp && true
	[ "`stat --format=%G .`"   = "www-data" ] || sudo chgrp www-data .   && true
.endif

# XXX not used by default, because it disturbs the normal deployment
# process
permissions-FreeBSD:
.if ${OSNAME} == FreeBSD
	[ "`stat -f %Sg tmp`" = "www" ] || sudo chgrp www tmp && true
	[ "`stat -f %Sg .`"   = "www" ] || sudo chgrp www .   && true
.endif

crontab:	crontab.tpl Makefile Makefile.${TARGET}.inc
	$(TPAGE) $(ALL_TPL_DEFINES) ${.ALLSRC:M*tpl} > $@
	chmod ugo+r $@

httpd.conf:	httpd.conf-tpl Makefile Makefile.${TARGET}.inc
	$(TPAGE) $(ALL_TPL_DEFINES) ${.ALLSRC:M*tpl} > $@
	chmod ugo+r $@

check-crontab:
	@(crontab -l | grep -q mapserver/brb/cleanup) && \
		echo "Crontab entry already installed" || \
		echo "*** You want probably to install the crontab"

######################################################################
# dists

#XXX remove the sternfahrt2005 productions to own rule
dist-any:	# build-all
	[ ! -d $(RADZEIT_DIST_DIR) ] || \
	    rm -rf $(RADZEIT_DIST_DIR)
	mkdir $(RADZEIT_DIST_DIR)
	chmod ugo+rx $(RADZEIT_DIST_DIR)
	$(MAKE) $(MAKEFLAGS) TARGET=$(TARGET) ABS_LOCAL_BBBIKE_DIR=$(ABS_LOCAL_BBBIKE_DIR) Makefile.${TARGET}.inc
	cp -pf $(DISTFILES) $(FONTS_LIST) $(RADZEIT_DIST_DIR)
	-mkdir $(RADZEIT_DIST_DIR)/sternfahrt2007
	chmod ugo+rx $(RADZEIT_DIST_DIR)/sternfahrt2007
	cp -pf $(DISTFILES_STERNFAHRT_2007) $(RADZEIT_DIST_DIR)/sternfahrt2007
	cp -pR data $(RADZEIT_DIST_DIR)
	cp -pR graphics $(RADZEIT_DIST_DIR)
	-mkdir $(RADZEIT_DIST_DIR)/tmp
	chmod ugo+rx $(RADZEIT_DIST_DIR)/tmp
	cd $(RADZEIT_DIST_DIR) && \
	    $(MAKE) $(MAKEFLAGS) TARGET=$(TARGET) ABS_LOCAL_BBBIKE_DIR=$(ABS_LOCAL_BBBIKE_DIR) all

######################################################################
# Download: http://mapserver.gis.umn.edu/dist/mapserver-3.6.4.tar.gz

# Patches für 3.6.3/3.6.4 sind unter
# /mnt/i386/usr/local/src/from_vran/mapserver/private-patches* vorhanden

# Um mapserver zu bauen, sind folgende configure-Aufrufe notwendig:
# bbbike.radzeit.de: sh configure --with-jpeg=/usr/src/jpeg-6b --with-freetype=/usr/X11R6

# GD 2.0.x ist bevorzugt zu verwenden, da die Textausgabe dort
# wesentlich besser funktioniert.

# Freetype 2.1.2 sollte nicht verwendet werden, da Textwinkel dort
# falsch berechnet werden (benötigt ein Minus in Zeile 404 von
# maplabel.c, mapserver 3.6.3)

# On bbbike.radzeit.de, use the mapserv-3.6.6 binary instead of the
# mapserv-3.6.4 binary. The latter seems to segfault more often.
# But the 3.6.6 version has other problems: no transparency with pngs (see
# the S-Bahn symbol), wrong rendering of oneway symbols (lines instead of
# arrows)

# To configure the current (2005-05) CVS version on FreeBSD use
#    sh configure --with-freetype=/usr/local/bin --with-gd=/usr/local --with-png=/usr/local --with-jpeg=/usr/local --with-xpm=/usr/X11R6 --with-libiconv=/usr/local --with-pdf=/usr/local
# Mind a possible mismatch: /usr/local/include/gd* vs. /usr/local/include/gd/gd*

# New compile of CVS version on bbbike.radzeit.de
# - bison/yacc was missing, got it from http://www.slackware.at/data/slackware-10.0/slackware/d/
#   and installed it with installpkg 

# Tried mapserver 4.4.x on FreeBSD-amd64 6.2 as a package. Unfortunately there
# are a lot of segfaults, and the detailmap images for bbbike.cgi do not
# work at all.
#
# Some investigation: it seems that the problem is a premature "break" in
# a switch in mapfile.c near line 1881. This problem seems to be fixed in the
# latest CVS version.
#
# But there's another interesting problem: the index files created on a
# 32 bit system does not seem to be compatible on a 64 bit system. Be
# cautious when deploying the mapserver data files to the radzeit server!

# To configure the current (2008-02) SVN version on FreeBSD use
#     ./configure --with-gd=/usr/local --with-pdf=/usr/local --with-png=/usr/local --with-jpeg=/usr/local --with-freetype=/usr/local --with-xpm=/usr/X11R6
# Still problems with PNGs with alpha channels.
