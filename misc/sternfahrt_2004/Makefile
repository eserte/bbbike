#
# $Id: Makefile,v 1.3 2004/05/08 21:20:43 eserte Exp $
#

MISCSRCDIR=		../../miscsrc
CONV=			${MISCSRCDIR}/correct_data.pl
CONVDB=			../../data_corrected/conv.db

all:	sternfahrt2004.shp treffpunkte2004.shp

sternfahrt2004-corrected.bbd: sternfahrt2004.bbd
	${CONV} -minpoints=5 -refdist 10000,20000,40000,80000,120000 -convdata ${CONVDB} -verboseoutput $> > $@~ && mv -f $@~ $@

treffpunkte2004-corrected.bbd: treffpunkte2004.bbd
	${CONV} -minpoints=5 -refdist 10000,20000,40000,80000,120000 -convdata ${CONVDB} -verboseoutput $> > $@~ && mv -f $@~ $@

sternfahrt2004.shp:	sternfahrt2004-corrected.bbd
	$(HOME)/src/bbbike/miscsrc/bbd2esri $> -o sternfahrt2004
	chmod 644 sternfahrt2004.*

treffpunkte2004.shp: treffpunkte2004-corrected.bbd
	$(HOME)/src/bbbike/miscsrc/bbd2esri -shapetype point $> -o treffpunkte2004
	chmod 644 treffpunkte2004.*

rsync:	rsync-data rsync-map-html rsync-images

rsync-data:
	cd $(HOME)/src/bbbike/projects/www.radzeit.de/htdocs/mapserver/brb/data && rsync -PvzL sternfahrt2004.* treffpunkte2004.* root@www.radzeit.de:/usr/local/apache/radzeit/htdocs/mapserver/brb/data/

rsync-map-html:
	cd $(HOME)/src/bbbike/projects/www.radzeit.de/htdocs/mapserver/brb && rsync -PvzL sternfahrt2004* root@www.radzeit.de:/usr/local/apache/radzeit/htdocs/mapserver/brb/

rsync-images:
	rsync -PvzL $(HOME)/src/bbbike/images/stern2004_titel.jpg root@www.radzeit.de:/usr/local/apache/radzeit/BBBike/images/
