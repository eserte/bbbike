#
# $Id: Makefile,v 1.50 2008/08/21 20:00:35 eserte Exp $
#

# XXX needs MORE work

# Note: with netpbm 10.31 (the version of the netpbm-devel FreeBSD port as
# of April 2007) dumps core with ppmtowinicon. super-stable netpbm 10.26.42
# seems to work.

# Maybe use "icotool -c" for windows ico creation instead?

all:	favicon.ico srtbike.ico \
	png-to-xpm \
	png-to-gif \
	png-to-wbmp \
	png-to-jpg

small-berlinmap:
	../miscsrc/small_berlinmap.pl
	cp -f /tmp/berlin_small.png .
	cp -f /tmp/berlin_small.gif .
	cp -f /tmp/berlin_small.xpm .
	cp -f /tmp/berlin_small_hi.png .
	cp -f /tmp/berlin_small_hi.gif .
	cp -f /tmp/berlin_small_hi.xpm .
	chmod ogu+r berlin_small*.*

favicon.ico:	/tmp/bbbike_favicon1.ppm /tmp/bbbike_favicon2.pgm
	ppmtowinicon -andpgms -output /tmp/favicon.ico~ \
	    /tmp/bbbike_favicon1.ppm /tmp/bbbike_favicon2.pgm

srtbike.ico:	/tmp/bbbike_favicon1.ppm /tmp/bbbike_favicon2.pgm
	giftopnm srtbike32.gif > /tmp/bbbike_favicon3.ppm
	ppmcolormask white /tmp/bbbike_favicon3.ppm | ppmtopgm > /tmp/bbbike_favicon4.pgm
	ppmtowinicon -andpgms -output /tmp/srtbike.ico~ \
	    /tmp/bbbike_favicon1.ppm /tmp/bbbike_favicon2.pgm \
	    /tmp/bbbike_favicon3.ppm /tmp/bbbike_favicon4.pgm

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

/tmp/bbbike_favicon2.pgm:
	ppmcolormask white /tmp/bbbike_favicon1.ppm | ppmtopgm > /tmp/bbbike_favicon2.pgm

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

# .gif.xpm:
# 	convert $< $@
# 	chmod ugo+r $@

# The following gifs are not generated automatically with ImageMagick
# (quality would be too bad):
#    mosque.gif
#
png-to-gif:	\
		abc.gif \
		abc_hi.gif \
		achtung.gif \
		airport.gif \
		ampel_klein2_rahmen.gif \
		ampelf.gif \
		ampelf_klein.gif \
		ampelf_klein2.gif \
		andreaskr.gif \
		andreaskr_klein.gif \
		apfel.gif \
		aufzug.gif \
		aufzug_klein.gif \
		aufzug_klein2.gif \
		bab_table_16.gif \
		bab_table_32.gif \
		bbbike_google.gif \
		birne.gif \
		bundesstrasse_table_16.gif \
		bundesstrasse_table_32.gif \
		cal.gif \
		car.gif \
		cemetery_bg.gif \
		church.gif \
		droga_krajowa_table_16.gif \
		droga_krajowa_table_32.gif \
		eisenbahn.gif \
		eisenbahn_klein.gif \
		eisenbahn_mini.gif \
		eisenbahn_stillg.gif \
		eisenbahn_stillg_klein.gif \
		eisenbahn_stillg_mini.gif \
		ferry.gif \
		ferry_klein.gif \
		flag2_bl.gif \
		flag2_bl_centered.gif \
		flag_via.gif \
		flag_via_centered.gif \
		flag_ziel.gif \
		flag_ziel_centered.gif \
		gefaelle.gif \
		grenzuebergang_16.gif \
		grenzuebergang_32.gif \
		hatched_ring.gif \
		hospital.gif \
		kino_klein.gif \
		kirsche.gif \
		kopfstein_klein.gif \
		kopfstein_klein_grey.gif \
		kreisverkehr.gif \
		legend_blocked.gif \
		legend_blockedroute.gif \
		legend_carry.gif \
		legend_narrowpassage.gif \
		legend_oneway.gif \
		mapserver_logo.gif \
		monument.gif \
		movehand.gif \
		museum.gif \
		newlayer.gif \
		notrailer.gif \
		opt.gif \
		pflaume.gif \
		printer.gif \
		printer_narrow.gif \
		rampe.gif \
		redcross.gif \
		sbahn.gif \
		sbahn_klein.gif \
		sbahn_mini.gif \
		search_pref.gif \
		steigung.gif \
		strassenbahn.gif \
		strassenbahn_klein.gif \
		synagogue.gif \
		theater.gif \
		touristinfo.gif \
		ubahn_klein.gif \
		ubahn_mini.gif \
		usercross.gif \
		vorfahrt.gif \
		vorfahrt_klein.gif \
		zugbruecke.gif \
		zugbruecke_klein.gif \

png-to-xpm:	\
		abc.xpm \
		abc_hi.xpm \
		achtung.xpm \
		ampel.xpm \
		ampel_klein2_rahmen.xpm \
		ampelf.xpm \
		ampelf_klein.xpm \
		ampelf_klein2.xpm \
		andreaskr.xpm \
		apfel.xpm \
		aufzug.xpm \
		aufzug_klein.xpm \
		aufzug_klein2.xpm \
		bbbike_google.xpm \
		birne.xpm \
		cal.xpm \
		car.xpm \
		church.xpm \
		eisenbahn.xpm \
		eisenbahn_klein.xpm \
		eisenbahn_mini.xpm \
		eisenbahn_stillg.xpm \
		eisenbahn_stillg_klein.xpm \
		eisenbahn_stillg_mini.xpm \
		ferry.xpm \
		ferry_klein.xpm \
		flag2_bl.xpm \
		flag2_bl_centered.xpm \
		flag_via_centered.xpm \
		flag_ziel.xpm \
		flag_ziel_centered.xpm \
		gefaelle.xpm \
		hatched_ring.xpm \
		kirsche.xpm \
		kreisverkehr.xpm \
		mapserver_logo.xpm \
		mosque.xpm \
		museum.xpm \
		newlayer.xpm \
		notrailer.xpm \
		pflaume.xpm \
		printer.xpm \
		printer_narrow.xpm \
		rampe.xpm \
		redcross.xpm \
		sbahn.xpm \
		sbahn_klein.xpm \
		sbahn_mini.xpm \
		search_pref.xpm \
		star.xpm \
		steigung.xpm \
		strassenbahn.xpm \
		strassenbahn_klein.xpm \
		synagogue.xpm \
		theater.xpm \
		touristinfo.xpm \
		ubahn.xpm \
		ubahn_klein.xpm \
		ubahn_mini.xpm \
		usercross.xpm \
		vorfahrt.xpm \
		vorfahrt_klein.xpm \
		zugbruecke.xpm \
		zugbruecke_klein.xpm \

png-to-wbmp:	\
		flag2_bl.wbmp \

png-to-jpg:	\
		andreaskr_klein.jpg \
		sbahn.jpg \
		sbahn_klein.jpg \
		sbahn_mini.jpg \
		ubahn.jpg \
		ubahn_klein.jpg \
		ubahn_mini.jpg \
		zugbruecke_klein.jpg \

# .PHONY: star.gif

# star.xpm:	star.gif
# 	convert $< $@
# 	chmod ugo+r $@

#XXX .PHONY: favicon.ico srtbike.ico

# Creation of bundesstrasse_table_32.png:
#   Fetched http://upload.wikimedia.org/wikipedia/commons/8/80/Bundesstra%C3%9Fe_1_number.svg
#     convert -background none -scale 32 Bundesstraße_1_number.svg /tmp/bundesstrasse_table_32.png
#   Removed the number with GIMP

# Creation of bab_table_32.png:
#   Fetched http://upload.wikimedia.org/wikipedia/commons/a/a6/Bundesautobahn_10_number.svg
#     convert -background none -scale 32 Bundesautobahn_10_number.svg  /tmp/bab_table_32.png
#   Removed the number with GIMP

# Creation of droga_krajowa_table_32.png
#   Fetched http://upload.wikimedia.org/wikipedia/commons/f/fb/Tabliczka_DK10.svg
# and converted like above

# All 16 versions: same procedure, only with -scale 16

# star.png start.png, via.png, ziel.png should NOT be used to create corresponding gifs
# This also means that there cannot be any makefile rules gif -> xpm, because this
# would fire the corresponding png -> gif rule.
# dest.png was used to create dest.gif (by GIMP), but looks ugly

# Creation of ampelf*noalpha.png
#
#   pngtopnm -alpha ampelf_klein_noalpha.png > /tmp/a.ppm
#   pngtopnm ampelf_klein_noalpha.png > /tmp/b.ppm
#   pnmtopng -alpha /tmp/a.ppm /tmp/b.ppm > ampelf_klein_noalpha.png
#
# This is the only way I found to make sure that the alpha mask
# is not preserved. What I want is just transparency.

# Creation of grenzuebergang_*.png
#   Fetched http://upload.wikimedia.org/wikipedia/commons/8/80/Zeichen_392.svg
#   Edited in gimp:
#     removed text
#     made black bar narrower
#     made red circle border broader
