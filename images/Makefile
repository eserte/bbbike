#
# $Id: Makefile,v 1.18 2005/02/25 01:33:45 eserte Exp eserte $
#

# XXX needs MORE work

all:	favicon.ico srtbike.ico

small-berlinmap:
	../miscsrc/small_berlinmap.pl
	cp -f /tmp/berlin_small.png .
	cp -f /tmp/berlin_small.gif .
	cp -f /tmp/berlin_small.xpm .
	cp -f /tmp/berlin_small_hi.png .
	cp -f /tmp/berlin_small_hi.gif .
	cp -f /tmp/berlin_small_hi.xpm .
	chmod ogu+r berlin_small*.*

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

.SUFFIXES: .gif .xpm .png .wbmp .jpg

# .xpm.gif:
# 	convert $< $@
# 	chmod ugo+r $@

# .xpm.png:
# 	convert $< $@
# 	chmod ugo+r $@

.png.xpm:
	convert $< $@
	chmod ugo+r $@

.png.gif:
	convert $< $@
	chmod ugo+r $@

# .xpm.wbmp:
# 	convert $< $@
# 	chmod ugo+r $@

.png.wbmp:
	convert $< $@
	chmod ugo+r $@

.png.jpg:
	convert $< $@
	chmod ugo+r $@

png-to-gif:	\
		airport.gif \
		ampel_klein2_rahmen.gif \
		andreaskr.gif \
		andreaskr_klein.gif \
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
		zugbruecke_klein.gif \
		opt.gif \
		flag2_bl_centered.gif \
		flag_via_centered.gif \
		flag_ziel_centered.gif \
		usercross.gif \
		redcross.gif \
		vorfahrt_klein.gif \
		abc.gif \
		abc_hi.gif \

png-to-xpm:	\
		ampel.xpm \
		ampel_klein2_rahmen.xpm \
		andreaskr.xpm \
		apfel.xpm \
		birne.xpm \
		church.xpm \
		ferry.xpm \
		ferry_klein.xpm \
		flag2_bl.xpm \
		flag_ziel.xpm \
		kirsche.xpm \
		pflaume.xpm \
		sbahn.xpm \
		sbahn_klein.xpm \
		sbahn_mini.xpm \
		search_pref.xpm \
		star.xpm \
		steigung.xpm \
		ubahn.xpm \
		ubahn_klein.xpm \
		ubahn_mini.xpm \
		zugbruecke.xpm \
		zugbruecke_klein.xpm \
		hatched_ring.xpm \
		flag2_bl_centered.xpm \
		flag_via_centered.xpm \
		flag_ziel_centered.xpm \
		usercross.xpm \
		redcross.xpm \
		vorfahrt_klein.xpm \
		abc.xpm \
		abc_hi.xpm \

png-to-wbmp:	\
		flag2_bl.wbmp \

png-to-jpg:	\
		andreaskr_klein.jpg \
		ubahn.jpg \
		sbahn.jpg \
		ubahn_klein.jpg \
		sbahn_klein.jpg \
		ubahn_mini.jpg \
		sbahn_mini.jpg \


#XXX .PHONY: favicon.ico srtbike.ico
