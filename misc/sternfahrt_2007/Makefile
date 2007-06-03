#
# $Id: Makefile,v 1.4 2007/06/02 11:54:49 eserte Exp $
#

BBBIKEDIR=		../..
MISCSRCDIR=		${BBBIKEDIR}/miscsrc

all:	sternfahrt2007.shp treffpunkte2007.shp

sternfahrt2007.shp:	sternfahrt2007.bbd
	$(MISCSRCDIR)/bbd2esri $> -o sternfahrt2007
	chmod 644 sternfahrt2007.*

treffpunkte2007.shp: treffpunkte2007.bbd
	$(MISCSRCDIR)/bbd2esri -shapetype point $> -o treffpunkte2007
	chmod 644 treffpunkte2007.*


test:
	perl sternfahrt.t

test-live:
	perl sternfahrt.t -live

.include "../../mapserver/brb/Makefile.radzeit.inc"
HTDOCS=	public

SSH=ssh -2 -p 5022
# wo kommt RSYNC original her?
RSYNC=rsync -e "$(SSH)"

sync:	copy-cgi-on-local-radzeit rsync-cgi \
	copy-data-on-local-radzeit rsync-data \
	rsync-map-html rsync-images \
	symlink-on-local-radzeit symlink-on-server

rsync-data:
	cd ${BBBIKEDIR}/projects/www.radzeit.de/$(HTDOCS)/mapserver/brb/data && \
	    $(RSYNC) -PvzL sternfahrt2007.* treffpunkte2007.* $(BBBIKE_RADZEIT_USER)@$(BBBIKE_RADZEIT_HOST):$(BBBIKE_RADZEIT_APACHE_DIR)/$(HTDOCS)/mapserver/brb/data/
	$(RSYNC) -PvzL treffpunkte2007.bbd $(BBBIKE_RADZEIT_USER)@$(BBBIKE_RADZEIT_HOST):$(BBBIKE_RADZEIT_APACHE_DIR)/BBBike/misc/sternfahrt_2007/
	$(SSH) -l $(BBBIKE_RADZEIT_USER) $(BBBIKE_RADZEIT_HOST) \
	    chmod ugo+r $(BBBIKE_RADZEIT_APACHE_DIR)/BBBike/misc/sternfahrt_2007/treffpunkte2007.bbd

copy-on-local-radzeit:	copy-data-on-local-radzeit \
			copy-cgi-on-local-radzeit

copy-data-on-local-radzeit:
	mkdir -p ${BBBIKEDIR}/projects/www.radzeit.de/BBBike/misc/sternfahrt_2007/
	cp -pf treffpunkte2007.bbd ${BBBIKEDIR}/projects/www.radzeit.de/BBBike/misc/sternfahrt_2007/
	chmod ugo+r ${BBBIKEDIR}/projects/www.radzeit.de/BBBike/misc/sternfahrt_2007/treffpunkte2007.bbd

rsync-map-html:
	cd ${BBBIKEDIR}/projects/www.radzeit.de/$(HTDOCS)/mapserver/brb && \
	    $(RSYNC) -PvzL sternfahrt2007* $(BBBIKE_RADZEIT_USER)@$(BBBIKE_RADZEIT_HOST):$(BBBIKE_RADZEIT_APACHE_DIR)/$(HTDOCS)/mapserver/brb/

rsync-images:
	$(RSYNC) -PvzL ${BBBIKEDIR}/images/stern2007_titel.jpg $(BBBIKE_RADZEIT_USER)@$(BBBIKE_RADZEIT_HOST):$(BBBIKE_RADZEIT_APACHE_DIR)/BBBike/images/

rsync-cgi:
	$(SSH) -l $(BBBIKE_RADZEIT_USER) $(BBBIKE_RADZEIT_HOST) \
	    mkdir -p $(BBBIKE_RADZEIT_APACHE_DIR)/BBBike/misc/sternfahrt_2007/
	$(RSYNC) -PvzL treffpunkte.cgi $(BBBIKE_RADZEIT_USER)@$(BBBIKE_RADZEIT_HOST):$(BBBIKE_RADZEIT_APACHE_DIR)/BBBike/misc/sternfahrt_2007/

copy-cgi-on-local-radzeit:
	mkdir -p ${BBBIKEDIR}/projects/www.radzeit.de/BBBike/misc/sternfahrt_2007/
	cp -pf treffpunkte.cgi ${BBBIKEDIR}/projects/www.radzeit.de/BBBike/misc/sternfahrt_2007/

symlink-on-server:
	$(SSH) -l $(BBBIKE_RADZEIT_USER) $(BBBIKE_RADZEIT_HOST) \
	    '[ -L $(BBBIKE_RADZEIT_APACHE_DIR)/cgi-bin/sternfahrt2007-treffpunkte.cgi ] || ln -s $(BBBIKE_RADZEIT_APACHE_DIR)/BBBike/misc/sternfahrt_2007/treffpunkte.cgi $(BBBIKE_RADZEIT_APACHE_DIR)/cgi-bin/sternfahrt2007-treffpunkte.cgi'

symlink-on-local-radzeit:
	cd ${BBBIKEDIR}/projects/www.radzeit.de/cgi-bin && \
	    [ -L sternfahrt2007-treffpunkte.cgi ] || ln -s ../BBBike/misc/sternfahrt_2007/treffpunkte.cgi sternfahrt2007-treffpunkte.cgi

