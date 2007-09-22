#
# $Id: Makefile,v 1.2 2007/09/22 08:23:21 eserte Exp $
#

BBD2MAPSERVHTML=../../miscsrc/bbd2mapservhtml.pl

all:	kreisfahrt2007.html kreisfahrt2007_googlemaps.html

kreisfahrt2007.html:	kreisfahrt2007.bbr Makefile ${BBD2MAPSERVHTML}
	${BBD2MAPSERVHTML} -title "Kreisfahrt 2007" kreisfahrt2007.bbr > kreisfahrt2007.html

kreisfahrt2007_googlemaps.html:	kreisfahrt2007.bbr Makefile ${BBD2MAPSERVHTML}
	${BBD2MAPSERVHTML} -title "Kreisfahrt 2007" -imagetype googlemaps kreisfahrt2007.bbr > kreisfahrt2007_googlemaps.html
