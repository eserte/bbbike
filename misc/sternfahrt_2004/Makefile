#
# $Id: Makefile,v 1.4 2004/06/10 21:55:29 eserte Exp $
#

BBBIKEDIR=		../..
MISCSRCDIR=		${BBBIKEDIR}/miscsrc
#CONV=			${MISCSRCDIR}/correct_data.pl
#CONVDB=			${BBBIKEDIR}/data_corrected/conv.db

all:	sternfahrt2004.shp treffpunkte2004.shp

# sternfahrt2004-corrected.bbd: sternfahrt2004.bbd
# 	${CONV} -minpoints=5 -refdist 10000,20000,40000,80000,120000 -convdata ${CONVDB} -verboseoutput $> > $@~ && mv -f $@~ $@

# treffpunkte2004-corrected.bbd: treffpunkte2004.bbd
# 	${CONV} -minpoints=5 -refdist 10000,20000,40000,80000,120000 -convdata ${CONVDB} -verboseoutput $> > $@~ && mv -f $@~ $@

sternfahrt2004.shp:	sternfahrt2004.bbd
	$(MISCSRCDIR)/bbd2esri $> -o sternfahrt2004
	chmod 644 sternfahrt2004.*

treffpunkte2004.shp: treffpunkte2004.bbd
	$(MISCSRCDIR)/bbd2esri -shapetype point $> -o treffpunkte2004
	chmod 644 treffpunkte2004.*

rsync:	rsync-cgi rsync-data rsync-map-html rsync-images symlink-on-server

rsync-data:
	cd ${BBBIKEDIR}/projects/www.radzeit.de/htdocs/mapserver/brb/data && rsync -PvzL sternfahrt2004.* treffpunkte2004.* root@www.radzeit.de:/usr/local/apache/radzeit/htdocs/mapserver/brb/data/
	rsync -PvzL treffpunkte2004.bbd root@www.radzeit.de:/usr/local/apache/radzeit/BBBike/misc/sternfahrt_2004/

rsync-map-html:
	cd ${BBBIKEDIR}/projects/www.radzeit.de/htdocs/mapserver/brb && rsync -PvzL sternfahrt2004* root@www.radzeit.de:/usr/local/apache/radzeit/htdocs/mapserver/brb/

rsync-images:
	rsync -PvzL ${BBBIKEDIR}/images/stern2004_titel.jpg root@www.radzeit.de:/usr/local/apache/radzeit/BBBike/images/

rsync-cgi:
	ssh -l root www.radzeit.de mkdir -p /usr/local/apache/radzeit/BBBike/misc/sternfahrt_2004/
	rsync -PvzL treffpunkte.cgi root@www.radzeit.de:/usr/local/apache/radzeit/BBBike/misc/sternfahrt_2004/

symlink-on-server:
	ssh -l root www.radzeit.de ln -s /usr/local/apache/radzeit/BBBike/misc/sternfahrt_2004/treffpunkte.cgi /usr/local/apache/radzeit/cgi-bin/sternfahrt2004-treffpunkte.cgi
