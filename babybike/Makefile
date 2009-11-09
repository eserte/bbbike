#
# $Id: Makefile,v 1.50 2005/07/22 23:35:01 eserte Exp $
#

# Prerequisites:
#   perl5.003-Dist mit Gtk bundled (nur für babybike, nicht for tkbabybike)
#   pppd auf iPAQ bereit gemacht (siehe WiKi)
#   rsync-Daemon auf iPAQ bereit gemacht (Verzeichnis erstellen)
#   ssh auf iPAQ bereit gemacht (keygen etc.)
#   Zeichensatz 5x7-ISO8859-1 kopieren, ins fonts.alias eintragen und rehash
#      machen

IPAQUSER=		root
IPAQHOST=		ipaq
IPAQTMPDEST=		$(IPAQUSER)@$(IPAQHOST):/tmp
IPAQTMPBBBIKEDEST=	$(IPAQTMPDEST)/bbbike
IPAQTMPBBBIKE=		/tmp/bbbike
IPAQSTABLEDEST=		root@ipaq:/usr/local
RSYNC?=			rsync -e ssh -Pv
DISTDEST?=		/tmp/bbbike
BBBIKEDIR?=		..
MISCSRCDIR?=		../miscsrc
DATADIR?=		../data

# BIG only useable for tiled images
BIG_GEOMETRY=		3000x2250
NORMAL_GEOMETRY=	1500x1125
# saves approx. 9 MB RAM memory (4 MB for babybike process, 5 MB for X server)
# (but tiles are better, anyway)
SMALL_GEOMETRY=		800x600
GEOMETRY=		$(NORMAL_GEOMETRY)
# -bbox ist hier für Prenzlau bis Köthen optimiert
BRB_BBOX=		-90550,106350,105550,-81650

# find perl scripts and modules
FIND_PERL_SCRIPTS=-type f -a \( -name "*.pm" -o -name "*.pl" -o -name "*.cgi" -o -name "tkbabybike" -o -name "babybike" \)

REMOVE_COMMENTS=	grep -v '^\#'

all:

update: update_data images

######################################################################
# Data

# update_potsdam_data ist evtl. aufwändig, deshalb nicht default
update_data:	data/strassen.gz data/landstrassen.gz \
		data/ubahn.gz data/sbahn.gz update_rest

update_rest:
	chmod +w data/Berlin.coords.data
	gzip -9 < ${DATADIR}/gesperrt > data/gesperrt.gz
	gzip -9 < ${DATADIR}/gesperrt_car > data/gesperrt_car.gz
	gzip -9 < ${DATADIR}/sbahnhof > data/sbahnhof.gz
	gzip -9 < ${DATADIR}/ubahnhof > data/ubahnhof.gz
	gzip -9 < ${DATADIR}/qualitaet_s > data/qualitaet_s.gz
	gzip -9 < ${DATADIR}/fragezeichen > data/fragezeichen.gz
	cat ${DATADIR}/orte ${DATADIR}/orte2 | $(REMOVE_COMMENTS) | gzip -9 > data/orte.gz
#	../miscsrc/create_plz_file '(Potsdam)' ${DATADIR}/landstrassen > /tmp/Potsdam.coords.data
	grep '[^|]$$' ${DATADIR}/Berlin.coords.data > /tmp/Berlin.coords.data-noempty
#	env LC_ALL=de_DE.ISO_8859-1 cat /tmp/Berlin.coords.data-noempty /tmp/Potsdam.coords.data | sort > data/Berlin.coords.data
	env LC_ALL=de_DE.ISO_8859-1 cat /tmp/Berlin.coords.data-noempty ${DATADIR}/Potsdam.coords.data | sort > data/Berlin.coords.data

# Potsdam: remove strings like (B1) and (F1.1) as this turns to be
# problematic for data_berlin_and_potsdam. Also make all B into HH streets.
data/strassen.gz: ${DATADIR}/strassen ${DATADIR}/landstrassen
	rm -f data/strassen
	cp ${DATADIR}/strassen data/strassen
	chmod +w data/strassen
	#perl -nle '/\Q(Potsdam)/ && do { s/\s+\([BF][\d\.]+\)//; s/\tB/\tHH/; print }' ${DATADIR}/landstrassen >> data/strassen
	bbox=`perl -I.. -I../lib -MStrassen -MStrassen::CoreHeavy -e '$$s=MultiStrassen->new("berlin","potsdam");@bbox = $$s->bbox; $$bbox[$$_]-=500 for (0..1); $$bbox[$$_]+=500 for (2..3); print join(",", @bbox)'`; \
		${MISCSRCDIR}/restrict_bbd_data.pl -bbox $$bbox -scope region -datadir ${DATADIR} -strdata landstrassen -o - | perl -nle 's/\s+\([BF][\d\.]+\)//; s/\tB/\tHH/; print' >> data/strassen
	gzip -9f data/strassen

# # "large" landstrassen.gz
# data/landstrassen.gz:	data/strassen.gz \
# 			${DATADIR}/strassen \
# 			${DATADIR}/landstrassen ${DATADIR}/landstrassen2
# 	(zcat data/strassen.gz; \
# 	 cat ${DATADIR}/strassen ${DATADIR}/landstrassen ${DATADIR}/landstrassen2) | \
# 	 $(REMOVE_COMMENTS) | sort | uniq -u | \
# 	 ${MISCSRCDIR}/restrict_bbd_data.pl -bbox $(BRB_BBOX) -strdata=- -o=- | \
# 	 gzip -9 > $@

# "small" landstrassen.gz
data/landstrassen.gz:	data/strassen.gz \
			${DATADIR}/strassen \
			${DATADIR}/landstrassen
	(zcat data/strassen.gz; \
	 cat ${DATADIR}/strassen ${DATADIR}/landstrassen) | \
	 $(REMOVE_COMMENTS) | sort | uniq -u | \
	 ${MISCSRCDIR}/restrict_bbd_data.pl -bbox $(BRB_BBOX) -strdata=- -o=- | \
	 gzip -9 > $@

data/ubahn.gz:	${DATADIR}/ubahn
	gzip -9 < $> > $@

data/sbahn.gz:	${DATADIR}/sbahn
	gzip -9 < $> > $@

# XXX Move theses two rules to data/Makefile as slow_slow_checks
# make a s/(s)traße$/$1tr./g on the data
/tmp/allestrassenberlins:
	../miscsrc/telefonbuch_strassen2001.pl -createallestr

update_potsdam_data: /tmp/allestrassenberlins
	fgrep "(Potsdam)" /tmp/allestrassenberlins | ../miscsrc/convert_coordsys t2001 -addx -130 -addy 260 | ../miscsrc/bbd2plzfile.pl -allestrassenberlins > ${DATADIR}/Potsdam.coords.data

######################################################################
# IMAGES

images: image_berlin image_brb image_small_berlin image_berlin_tiles image_brb_tiles

######################################################################
# Berlin Tiles
image_berlin_tiles:	do-image-berlin tile-image-berlin

do-image-berlin:
	[ -d images/berlin_tiles ] || mkdir images/berlin_tiles
	../miscsrc/bbbikedraw.pl -datadirs data \
	    -outtype png \
	    -mapserver \
	    -geometry $(BIG_GEOMETRY) -ipaq -nooutline -fillimage \
	    -drawtypes str,flaechen,wasser,faehren,ubahn,ubahnname,sbahn,sbahnname,rbahn,berlin,ort,obst \
	    -minplacecat 0 \
	    -o /tmp/berlin.png -dimfile images/berlin_tiles/berlin.dim
	pngtopnm /tmp/berlin.png > /tmp/berlin.ppm

tile-image-berlin:
	[ -d images/berlin_tiles ] || mkdir images/berlin_tiles
	../miscsrc/tilemap -hardlink -image /tmp/berlin.ppm -destdir images/berlin_tiles -geometry 100x100 -conf /tmp/berlin.conf

cleanup-berlin-tiles:
	cd images/berlin_tiles && rm -f *.xpm *.xpm.gz

######################################################################
# Brandenburg Tiles
image_brb_tiles:	do-image-brb tile-image-brb

# -mapserver oder nicht?
do-image-brb:
	../miscsrc/bbbikedraw.pl -geometry $(BIG_GEOMETRY) -ipaq -nooutline\
	    -outtype png \
	    -mapserver \
	    -minplacecat 0 \
	    -scope region -drawtypes str,wasser,rbahn,berlin,ort \
	    -bbox $(BRB_BBOX) \
	    -o /tmp/brb.png -dimfile images/brb_tiles/brb.dim
	pngtopnm /tmp/brb.png > /tmp/brb.ppm

tile-image-brb:
	-mkdir images/brb_tiles
	../miscsrc/tilemap -hardlink -image /tmp/brb.ppm -destdir images/brb_tiles -geometry 100x100 -conf /tmp/brb.conf

cleanup-brb-tiles:
	cd images/brb_tiles && rm -f *.xpm *.xpm.gz

######################################################################
# Old rules
# keine ubahnname/sbahnname - zu kleine Karte!
image_berlin:
	../miscsrc/bbbikedraw.pl -datadirs data \
	    -outtype png \
	    -geometry $(GEOMETRY) -ipaq -nooutline -fillimage \
	    -drawtypes str,flaechen,wasser,ubahn,sbahn,berlin,ort \
	    -o images/berlin.png -dimfile images/berlin.dim
#	pngtopnm images/berlin.png | ppmtogif > images/berlin.gif
# ppmtoxpm seems to generate wrong code (a color "D65" without hashmark...)
#	pngtopnm images/berlin.png | ppmtoxpm | gzip -9 > images/berlin.xpm.gz
# so use ImageMagick
	convert images/berlin.png /tmp/berlin.xpm
	gzip -9 < /tmp/berlin.xpm > images/berlin.xpm.gz

# high quality image with ImageMagick, but SLOW!!!
image_berlin2:
	../miscsrc/bbbikedraw.pl -imagemagick -outtype png -datadirs data \
	    -outtype png \
	    -geometry $(GEOMETRY) -ipaq -nooutline -fillimage \
	    -drawtypes str,flaechen,wasser,ubahn,sbahn,berlin,ort \
	    -o /tmp/berlin.png -dimfile images/berlin.dim
#	pngtopnm /tmp/berlin.png | ppmtoxpm | gzip -9 > images/berlin.xpm.gz
	convert /tmp/berlin.png /tmp/berlin.xpm
	gzip -9 < /tmp/berlin.xpm > images/berlin.xpm.gz

# Should not be used ... rather draw fragezeichen as a bbd layer
# Also, still uses ppmtoxpm instead of convert
image_berlin_fragezeichen:
	../miscsrc/bbbikedraw.pl -datadirs data \
	    -outtype png \
	    -geometry $(GEOMETRY) -ipaq -nooutline -fillimage \
	    -drawtypes str,flaechen,wasser,berlin,ort,fragezeichen \
	    -o images/berlin.png -dimfile images/berlin.dim
	pngtopnm images/berlin.png | ppmtoxpm | gzip -9 > images/berlin.xpm.gz

image_brb:
	../miscsrc/bbbikedraw.pl -geometry $(GEOMETRY) -ipaq -nooutline\
	    -outtype png \
	    -minplacecat 1 \
	    -scope region -drawtypes str,wasser,rbahn,berlin,ort \
	    -o images/brb.png -dimfile images/brb.dim
#	pngtopnm images/brb.png | ppmtogif > images/brb.gif
#	pngtopnm images/brb.png | ppmtoxpm | gzip -9 > images/brb.xpm.gz
	convert images/brb.png /tmp/brb.xpm
	gzip -9 < /tmp/brb.xpm > images/brb.xpm.gz

######################################################################
# Overview button
image_small_berlin:
	../miscsrc/small_berlinmap.pl -geometry 60x45 -normbg '#c0c0c0' -fill -includepotsdam
	cp /tmp/berlin_small.dim images
	giftopnm /tmp/berlin_small.gif | ppmtoxpm > images/berlin_small.xpm

# ImageMagick: mit Antialiasing, aber sieht etwas blass aus
# Außerdem müsste die Potsdamer Grenze richtig geschlossen werden, damit
# filledpolygon richtig funktioniert
image_small_berlin2:
	../miscsrc/combine_streets.pl -closedpolygon ${DATADIR}/berlin | sed -e 's/	Z/	F:Z/' > /tmp/berlin
	../miscsrc/combine_streets.pl ${DATADIR}/potsdam | sed -e 's/	Z/	F:Z/' > /tmp/potsdam
	../miscsrc/small_berlinmap.pl -nogif -imagemagick -geometry 60x45 -normbg '#c0c0c0' -borderfiles /tmp/berlin,/tmp/potsdam
	cp /tmp/berlin_small.dim images
	pngtopnm /tmp/berlin_small.png | ppmtoxpm > images/berlin_small.xpm

######################################################################
# Rsync

# host ipaq = 10.0.0.2 on my machine
# auf ipaq-Seite muss laufen:
#    rsync --daemon
#    sshd
rsync:
	$(RSYNC) --exclude .xvpics --cvs-exclude --exclude oldlib/ \
	    --include "*.so" \
	    -L --times -r -z \
	    . $(IPAQTMPBBBIKEDEST)
#	ssh -l root ipaq ln -s tkbabybike /tmp/bbbike/tkbb

# restrict only to tkbabybike-related files
rsync-tkbabybike:	do-rsync-tkbabybike ipaq-generate-cache

do-rsync-tkbabybike:
	$(RSYNC) -L --times -r -z --hard-links \
	    --exclude data_usedom_uckermark \
	    --exclude "images/usedom_uckermark*" \
	    --exclude data_dessau \
	    --exclude "images/dessau*" \
	    --exclude .xvpics --exclude "*.png" --exclude _Inline \
	    --exclude "images/berlin.xpm.gz" \
	    --exclude "images/brb.xpm.gz" \
	    --exclude data_uckermark \
	    --exclude "images/uckermark*" \
	    --exclude data_koethen \
	    --exclude "images/koethen*" \
	    --exclude data_muenchen \
	    --exclude "images/muenchen_tiles*" \
	    --exclude-from .tkbabybike.SKIP \
	    --cvs-exclude --exclude oldlib/ --include "*.so" \
	    . $(IPAQTMPBBBIKEDEST)

ipaq-generate-cache:
	ssh -l $(IPAQUSER) $(IPAQHOST) $(IPAQTMPBBBIKE)/generate_cache.pl
#	ssh -l $(IPAQUSER) $(IPAQHOST) $(IPAQTMPBBBIKE)/generate_cache.pl -algorithm "C-A*-2" -scopes city

rsync-brb-images:
	cd images/brb_tiles && $(RSYNC) -L --times -r -z \
	    . $(IPAQTMPBBBIKEDEST)/images/brb_tiles

# additions (development code only)
rsync-add:
	-ssh -l root ipaq mkdir /tmp/bbbike/Karte
	cd .. && $(RSYNC) -L Karte.pm miscsrc/tkpolarinput.pl $(IPAQTMPBBBIKEDEST)
	cd .. && $(RSYNC) -L Karte/Polar.pm Karte/Standard.pm $(IPAQTMPBBBIKEDEST)/Karte

# only the main script:
fast-rsync-tkbabybike:
	$(RSYNC) -L -z tkbabybike $(IPAQTMPBBBIKEDEST)

full-rsync:	make-directories rsync

make-directories:
	ssh -l root ipaq mkdir -p /tmp/bbbike

rsync-stable:	stable-dist
	@echo Do not use this rule anymore...
	false
	cd /tmp && $(RSYNC) -L --exclude .xvpics --cvs-exclude -r -z \
	    --exclude "*/data/landstrassen*" --exclude "*/images/brb.*" \
	    --exclude "*.gif" --exclude ".rcsignore" --exclude oldlib/ \
	    BBBike $(IPAQSTABLEDEST)

rsync-tkbabybike-stable:	stable-dist
	@echo Better use stable-tkbabybike-dist, rsync the files
	@echo manually to the iPAQ, check it there, and finally copy
	@echo the files with cp -R /usr/local/BBBike
	@echo Now hit CTRL-C or wait and do it anyway...
	@sleep 10
	@echo OK, doing it anyway.
	@sleep 1
	cd /tmp && $(RSYNC) -T /tmp -L --exclude .xvpics --cvs-exclude -r -z \
	    --exclude "*/data/landstrassen*" --exclude "*/images/brb.*" \
	    --exclude "*.gif" --exclude ".rcsignore" \
	    --exclude "babybike*" --exclude "*.png" --exclude oldlib/ \
	    BBBike $(IPAQSTABLEDEST)

stable-dist:
	@echo Do not use this rule, use stable-tkbabybike-dist!
	rm -rf $(DISTDEST)
	mkdir $(DISTDEST)
	cp -pRL * $(DISTDEST)

stable-tkbabybike-dist: copy-stable-tkbabybike-dist \
			remove-brb-from-stable-dist \
			mangle-dist

copy-stable-tkbabybike-dist:
	rm -rf $(DISTDEST)
	mkdir $(DISTDEST)
	rsync  -L --exclude .xvpics --exclude-from .tkbabybike.SKIP \
	    --cvs-exclude --exclude oldlib/ --include "*.so" -r . $(DISTDEST)
	gzip -9 $(DISTDEST)/data/Berlin.coords.data
	rm -f $(DISTDEST)/lib/Strassen/CNetFile.pm
	rm -f $(DISTDEST)/lib/Strassen/Inline.pm
	rm -f $(DISTDEST)/lib/Strassen/Inline2.pm

# call after stable-tkbabybike-dist
remove-brb-from-stable-dist:
	rm -f $(DISTDEST)/data/landstrassen.gz
	rm -f $(DISTDEST)/images/brb.xpm.gz

# call after stable-tkbabybike-dist
# Create a mangled, comment-less, pod-less minimal version of the script
# and modules. See comment for mange in bbbike/Makefile.PL
mangle-dist:
	cd $(DISTDEST) && \
	    find . $(FIND_PERL_SCRIPTS) -print \
		-exec mv {} {}~ \; \
		-exec perltidy -mangle -dac -dp {}~ -o {} \; \
		-exec rm -f {}~ \;
	# why is perltidy removing the she-bang?
	mv $(DISTDEST)/tkbabybike $(DISTDEST)/tkbabybike~
	(echo '#!/usr/bin/perl'; cat $(DISTDEST)/tkbabybike~) > $(DISTDEST)/tkbabybike
	rm $(DISTDEST)/tkbabybike~
	chmod 755 $(DISTDEST)/tkbabybike

rsync-cgi:	rsync
	$(RSYNC) -z ../cgi/bbbike.cgi ../cgi/runbbbikecgi ../cgi/tinyhttpd \
	    $(IPAQTMPBBBIKEDEST)/cgi
	$(RSYNC) -z ../cgi/bbbike-ipaq.cgi.config \
	    $(IPAQTMPBBBIKEDEST)/cgi/bbbike.cgi.config
	$(RSYNC) -z ../BBBikeVar.pm $(IPAQTMPBBBIKEDEST)
	$(RSYNC) -z -L ../lib/WWWBrowser.pm ../lib/BrowserInfo.pm \
	    /usr/libdata/perl/5.00503/CGI.pm \
	    $(IPAQTMPBBBIKEDEST)/lib
	$(RSYNC) -z /usr/libdata/perl/5.00503/CGI/Cookie.pm \
	    $(IPAQTMPBBBIKEDEST)/lib/CGI

rsync-gtk-tmp:
	cd /home/e/eserte/private/ipaq/rsync/usr/local/lib && \
	    $(RSYNC) -zr site_perl $(IPAQTMPDEST)

rsync-kino-berlin:
	$(RSYNC) -z ../miscsrc/kino-berlin.pl ../miscsrc/CommonMLDBM.pm \
	    $(IPAQTMPBBBIKEDEST)

ipkg-babybike:
	../port/ipk/mkipk.pl -dist babybike -destdir ${.CURDIR}/../distfiles

ipkg-tkbabybike:
	../port/ipk/mkipk.pl -dist tkbabybike -destdir ${.CURDIR}/../distfiles

get_update_points:	/tmp/update_points

/tmp/update_points:	tkbabybike
	ssh -l $(IPAQUSER) $(IPAQHOST) env TK_SPLASH_COMPUTE=1 DISPLAY=:0 /tmp/bbbike/tkbabybike | grep Update | perl -nale 'print $$F[2]' > /tmp/update_points

distcheck:
	perl "-MExtUtils::Manifest=fullcheck" -e fullcheck

######################################################################
# special rules for temporary maps

# Köthen, Dessau etc.
# im Norden bis Burg u. Magdeburg
BBOX_KOETHEN=-118300,-112100,-31400,-1000

data_koethen:
	-mkdir data_koethen
	echo -n | gzip > data_koethen/strassen.gz
	echo -n | gzip > data_koethen/landstrassen2.gz
	echo -n | gzip > data_koethen/wasserstrassen.gz
	echo -n | gzip > data_koethen/wasserumland2.gz
	echo -n | gzip > data_koethen/gesperrt.gz
	echo -n | gzip > data_koethen/orte2.gz
	echo -n | gzip > data_koethen/qualitaet_s.gz
	env BBBIKE_DATADIR=${DATADIR} ${MISCSRCDIR}/restrict_bbd_data.pl -bbox $(BBOX_KOETHEN) -scope wideregion -strdata landstrassen,landstrassen2 -o - | gzip -9f > data_koethen/landstrassen.gz
	env BBBIKE_DATADIR=${DATADIR} ${MISCSRCDIR}/restrict_bbd_data.pl -bbox $(BBOX_KOETHEN) -scope wideregion -strdata wasserumland,wasserumland2 -o - | gzip -9f > data_koethen/wasserumland.gz
	env BBBIKE_DATADIR=${DATADIR} ${MISCSRCDIR}/restrict_bbd_data.pl -bbox $(BBOX_KOETHEN) -scope wideregion -strdata rbahn -o - | gzip -9f > data_koethen/rbahn.gz
	env BBBIKE_DATADIR=${DATADIR} ${MISCSRCDIR}/restrict_bbd_data.pl -bbox $(BBOX_KOETHEN) -scope wideregion -strdata rbahnhof -o - | gzip -9f > data_koethen/rbahnhof.gz
	env BBBIKE_DATADIR=${DATADIR} ${MISCSRCDIR}/restrict_bbd_data.pl -bbox $(BBOX_KOETHEN) -scope wideregion -strdata orte,orte2 -o - | gzip -9f > data_koethen/orte.gz
	env BBBIKE_DATADIR=${DATADIR} ${MISCSRCDIR}/restrict_bbd_data.pl -bbox $(BBOX_KOETHEN) -scope wideregion -strdata qualitaet_l -o - | gzip -9f > data_koethen/qualitaet_l.gz

data_koethen_gpstracks:
	${MISCSRCDIR}/restrict_bbd_data.pl -bbox $(BBOX_KOETHEN)  -strdata ${BBBIKEDIR}/tmp/streets.bbd,${BBBIKEDIR}/tmp/streets-bahn.bbd,${BBBIKEDIR}/misc/mps_examples/streets.bbd -o - | gzip -9f > data_koethen/gpstracks.gz

image_koethen:
	env BBBIKE_DATADIR=data_koethen ../miscsrc/bbbikedraw.pl -geometry 750x* -ipaq -nooutline\
	    -outtype png -bbox $(BBOX_KOETHEN) \
	    -scope wideregion -drawtypes str,wasser,rbahn,ort \
	    -minplacecat 0 \
	    -o images/koethen.png -dimfile images/koethen.dim
	pngtopnm images/koethen.png | ppmtoxpm | gzip -9 > images/koethen.xpm.gz

image_koethen_tiles:
	-mkdir images/koethen_tiles
	env BBBIKE_DATADIR=data_koethen ../miscsrc/bbbikedraw.pl \
	    -outtype png -bbox $(BBOX_KOETHEN) \
	    -geometry 2250x* -ipaq -nooutline -fillimage \
	    -scope wideregion -drawtypes str,wasser,rbahn,ort \
	    -minplacecat 0 \
	    -o /tmp/koethen.png -dimfile images/koethen_tiles/koethen.dim
	pngtopnm /tmp/koethen.png > /tmp/koethen.ppm
	perl -I$HOME/lib/perl ../miscsrc/tilemap -image /tmp/koethen.ppm -destdir images/koethen_tiles -geometry 100x100 -conf /tmp/koethen.conf

######################################################################
# von Berlin bis zur Uckermark

#BBOX_UCKERMARK=85200,125500,3000,30000
# Das hier schließt Neubrandenburg mit ein:
#BBOX_UCKERMARK=85200,141100,-19300,30000
# Das hier geht nur von der Uckermark bis nach Usedom, ohne Berlin:
BBOX_UCKERMARK=11807,92994,67114,186179

data_uckermark:
	-mkdir data_uckermark
	echo -n | gzip > data_uckermark/strassen.gz
	echo -n | gzip > data_uckermark/landstrassen2.gz
	echo -n | gzip > data_uckermark/wasserstrassen.gz
	echo -n | gzip > data_uckermark/wasserumland2.gz
	echo -n | gzip > data_uckermark/gesperrt.gz
	echo -n | gzip > data_uckermark/orte2.gz
	echo -n | gzip > data_uckermark/qualitaet_s.gz
	${MISCSRCDIR}/restrict_bbd_data.pl -bbox $(BBOX_UCKERMARK) -scope wideregion -strdata ${DATADIR}/landstrassen,${DATADIR}/landstrassen2 -o - | gzip -9f > data_uckermark/landstrassen.gz
	${MISCSRCDIR}/restrict_bbd_data.pl -bbox $(BBOX_UCKERMARK) -scope wideregion -strdata ${DATADIR}/wasserumland,${DATADIR}/wasserumland2 -o - | gzip -9f > data_uckermark/wasserumland.gz
	${MISCSRCDIR}/restrict_bbd_data.pl -bbox $(BBOX_UCKERMARK) -scope wideregion -strdata ${DATADIR}/rbahn -o - | gzip -9f > data_uckermark/rbahn.gz
	${MISCSRCDIR}/restrict_bbd_data.pl -bbox $(BBOX_UCKERMARK) -scope wideregion -strdata ${DATADIR}/rbahnhof -o - | gzip -9f > data_uckermark/rbahnhof.gz
	${MISCSRCDIR}/restrict_bbd_data.pl -bbox $(BBOX_UCKERMARK) -scope wideregion -strdata ${DATADIR}/orte,${DATADIR}/orte2 -o - | gzip -9f > data_uckermark/orte.gz
	${MISCSRCDIR}/restrict_bbd_data.pl -bbox $(BBOX_UCKERMARK) -scope wideregion -strdata ${DATADIR}/qualitaet_l -o - | gzip -9f > data_uckermark/qualitaet_l.gz

data_uckermark_gpstracks:
	${MISCSRCDIR}/restrict_bbd_data.pl -bbox $(BBOX_UCKERMARK)  -strdata ${BBBIKEDIR}/tmp/streets.bbd,${BBBIKEDIR}/tmp/streets-bahn.bbd,${BBBIKEDIR}/misc/mps_examples/streets.bbd -o - | gzip -9f > data_uckermark/gpstracks.gz


image_uckermark:
	env BBBIKE_DATADIR=data_uckermark ../miscsrc/bbbikedraw.pl -geometry 900x* -ipaq -nooutline\
	    -outtype png -bbox $(BBOX_UCKERMARK) \
	    -scope wideregion -drawtypes str,wasser,rbahn,ort \
	    -mapserver \
	    -minplacecat 0 \
	    -o images/uckermark.png -dimfile images/uckermark.dim
	pngtopnm images/uckermark.png | ppmtoxpm | gzip -9 > images/uckermark.xpm.gz

# XXX evtl. cleanup uckermark_tiles
image_uckermark_tiles:
	-mkdir images/uckermark_tiles
	env BBBIKE_DATADIR=data_uckermark ../miscsrc/bbbikedraw.pl \
	    -outtype png -bbox $(BBOX_UCKERMARK) \
	    -mapserver \
	    -geometry 2250x* -ipaq -nooutline -fillimage \
	    -scope wideregion -drawtypes str,wasser,rbahn,ort \
	    -minplacecat 0 \
	    -o /tmp/uckermark.png -dimfile images/uckermark_tiles/uckermark.dim
	pngtopnm /tmp/uckermark.png > /tmp/uckermark.ppm
	perl -I$HOME/lib/perl ../miscsrc/tilemap -image /tmp/uckermark.ppm -destdir images/uckermark_tiles -geometry 100x100 -conf /tmp/uckermark.conf

rsync-uckermark: do-rsync-uckermark ipaq-generate-cache-uckermark

do-rsync-uckermark:
	$(RSYNC) -L --times -r -z --hard-links \
	    --cvs-exclude \
	    data_uckermark/ \
	    $(IPAQTMPBBBIKEDEST)/data_uckermark/
	$(RSYNC) -L --times -r -z --hard-links \
	    --cvs-exclude \
	     images/uckermark_tiles/ \
	    $(IPAQTMPBBBIKEDEST)/images/uckermark_tiles/

ipaq-generate-cache-uckermark:
	ssh -l $(IPAQUSER) $(IPAQHOST) $(IPAQTMPBBBIKE)/generate_cache.pl -scopes uckermark

######################################################################

## XXX Does not work. Problem: $(BBOX_$(REGION))
## It's probably easier to use Makefile.PL instead.

# REGIONS=uckermarkXXX
# BBOX_uckermarkXXX=85200,125500,3000,30000

# .for region in $(REGIONS)
# all_${region}:	data_${region} \
# 		data_${region}_gpstracks \
# 		image_${region}_tiles

# data_${region}:
# 	-mkdir data_${region}
# 	echo -n | gzip > data_${region}/strassen.gz
# 	echo -n | gzip > data_${region}/landstrassen2.gz
# 	echo -n | gzip > data_${region}/wasserstrassen.gz
# 	echo -n | gzip > data_${region}/wasserumland2.gz
# 	echo -n | gzip > data_${region}/gesperrt.gz
# 	echo -n | gzip > data_${region}/orte2.gz
# 	echo -n | gzip > data_${region}/qualitaet_s.gz
# 	${MISCSRCDIR}/restrict_bbd_data.pl -bbox $(BBOX_${REGION}) -scope wideregion -strdata ${DATADIR}/landstrassen,${DATADIR}/landstrassen2 -o - | gzip -9f > data_${region}/landstrassen.gz
# 	${MISCSRCDIR}/restrict_bbd_data.pl -bbox $(BBOX_${REGION}) -scope wideregion -strdata ${DATADIR}/wasserumland,${DATADIR}/wasserumland2 -o - | gzip -9f > data_${region}/wasserumland.gz
# 	${MISCSRCDIR}/restrict_bbd_data.pl -bbox $(BBOX_${REGION}) -scope wideregion -strdata ${DATADIR}/rbahn -o - | gzip -9f > data_${region}/rbahn.gz
# 	${MISCSRCDIR}/restrict_bbd_data.pl -bbox $(BBOX_${REGION}) -scope wideregion -strdata ${DATADIR}/rbahnhof -o - | gzip -9f > data_${region}/rbahnhof.gz
# 	${MISCSRCDIR}/restrict_bbd_data.pl -bbox $(BBOX_${REGION}) -scope wideregion -strdata ${DATADIR}/orte,${DATADIR}/orte2 -o - | gzip -9f > data_${region}/orte.gz
# 	${MISCSRCDIR}/restrict_bbd_data.pl -bbox $(BBOX_${REGION}) -scope wideregion -strdata ${DATADIR}/qualitaet_l -o - | gzip -9f > data_${region}/qualitaet_l.gz

# data_${region}_gpstracks:
# 	${MISCSRCDIR}/restrict_bbd_data.pl -bbox $(BBOX_${REGION})  -strdata ${BBBIKEDIR}/tmp/streets.bbd,${BBBIKEDIR}/tmp/streets-bahn.bbd,${BBBIKEDIR}/misc/mps_examples/streets.bbd -o - | gzip -9f > data_${region}/gpstracks.gz


# image_${region}:
# 	env BBBIKE_DATADIR=data_${region} ../miscsrc/bbbikedraw.pl -geometry 900x* -ipaq -nooutline\
# 	    -outtype png -bbox $(BBOX_${REGION}) \
# 	    -scope wideregion -drawtypes str,wasser,rbahn,ort \
# 	    -mapserver \
# 	    -minplacecat 0 \
# 	    -o images/${region}.png -dimfile images/${region}.dim
# 	pngtopnm images/${region}.png | ppmtoxpm | gzip -9 > images/${region}.xpm.gz

# # XXX evtl. cleanup ${region}_tiles
# image_${region}_tiles:
# 	-mkdir images/${region}_tiles
# 	env BBBIKE_DATADIR=data_${region} ../miscsrc/bbbikedraw.pl \
# 	    -outtype png -bbox $(BBOX_${REGION}) \
# 	    -mapserver \
# 	    -geometry 2250x* -ipaq -nooutline -fillimage \
# 	    -scope wideregion -drawtypes str,wasser,rbahn,ort \
# 	    -minplacecat 0 \
# 	    -o /tmp/${region}.png -dimfile images/${region}_tiles/${region}.dim
# 	pngtopnm /tmp/${region}.png > /tmp/${region}.ppm
# 	perl -I$HOME/lib/perl ../miscsrc/tilemap -image /tmp/${region}.ppm -destdir images/${region}_tiles -geometry 100x100 -conf /tmp/${region}.conf

# rsync-${region}: do-rsync-${region} ipaq-generate-cache-${region}

# do-rsync-${region}:
# 	$(RSYNC) -L --times -r -z --hard-links \
# 	    --cvs-exclude \
# 	    data_${region}/ \
# 	    $(IPAQTMPBBBIKEDEST)/data_${region}/
# 	$(RSYNC) -L --times -r -z --hard-links \
# 	    --cvs-exclude \
# 	     images/${region}_tiles/ \
# 	    $(IPAQTMPBBBIKEDEST)/images/${region}_tiles/

# ipaq-generate-cache-${region}:
# 	ssh -l $(IPAQUSER) $(IPAQHOST) $(IPAQTMPBBBIKE)/generate_cache.pl -scopes ${region}

# .PHONY: data_${region}

# .endfor

######################################################################

.PHONY: data_koethen data_uckermark

