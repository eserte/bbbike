#
# $Id: Makefile,v 1.14 2003/12/22 19:56:20 eserte Exp $
#

# XXX needs MORE work

all:	favicon.ico srtbike.ico

favicon.ico:	/tmp/bbbike_favicon1.ppm /tmp/bbbike_favicon2.ppm
	ppmtowinicon -andppms -output /tmp/favicon.ico~ \
	    /tmp/bbbike_favicon1.ppm /tmp/bbbike_favicon2.ppm

srtbike.ico:	/tmp/bbbike_favicon1.ppm /tmp/bbbike_favicon2.ppm
	giftopnm srtbike32.gif > /tmp/bbbike_favicon3.ppm
	ppmcolormask white /tmp/bbbike_favicon3.ppm > /tmp/bbbike_favicon4.ppm
	ppmtowinicon -andppms -output /tmp/srtbike.ico~ \
	    /tmp/bbbike_favicon1.ppm /tmp/bbbike_favicon2.ppm \
	    /tmp/bbbike_favicon3.ppm /tmp/bbbike_favicon4.ppm

bbbike_splash.xpm: srtbike.xpm
	../miscsrc/splash_logo.pl
	mv /tmp/bbbike_splash.xpm $@
	chmod 644 $@

bbbike_splash_tkbabybike.xpm: srtbike.xpm
	../miscsrc/splash_logo.pl -logo=tkbabybike
	mv /tmp/bbbike_splash.xpm $@
	chmod 644 $@

# temporaries
/tmp/bbbike_favicon1.ppm:
	giftopnm srtbike16.gif > /tmp/bbbike_favicon1.ppm

/tmp/bbbike_favicon2.ppm:
	ppmcolormask white /tmp/bbbike_favicon1.ppm > /tmp/bbbike_favicon2.ppm

.SUFFIXES: .gif .xpm .png .wbmp

.xpm.gif:
	convert $> $@
	chmod ugo+r $@

.xpm.png:
	convert $> $@
	chmod ugo+r $@

.xpm.wbmp:
	convert $> $@
	chmod ugo+r $@

xpm-to-gif:	\
		airport.gif \
		ampel_klein2_rahmen.gif \
		apfel.gif \
		birne.gif \
		church.gif \
		ferry.gif \
		ferry_klein.gif \
		flag2_bl.gif \
		flag_via.gif \
		flag_ziel.gif \
		hatched_ring.gif \
		hospital.gif \
		kino_klein.gif \
		kirsche.gif \
		kopfstein_klein.gif \
		kopfstein_klein_grey.gif \
		monument.gif \
		movehand.gif \
		pflaume.gif \
		sbahn.gif \
		sbahn_klein.gif \
		sbahn_mini.gif \
		search_pref.gif \
		star.gif \
		steigung.gif \
		ubahn_klein.gif \
		ubahn_mini.gif \
		zugbruecke.gif \
		opt.gif \


xpm-to-png:	\
		ampel.png \
		ampel_klein2_rahmen.png \
		andreaskr.png \
		apfel.png \
		birne.png \
		church.png \
		ferry.png \
		ferry_klein.png \
		flag2_bl.png \
		flag_ziel.png \
		kirsche.png \
		pflaume.png \
		sbahn.png \
		sbahn_klein.png \
		sbahn_mini.png \
		star.png \
		steigung.png \
		ubahn.png \
		ubahn_klein.png \
		ubahn_mini.png \
		zugbruecke.png \

png-to-xpm:
	convert hatched_ring.png hatched_ring.xpm
	chmod ugo+r hatched_ring.xpm

xpm-to-wbmp:	\
		flag2_bl.wbmp \


#XXX .PHONY: favicon.ico srtbike.ico
