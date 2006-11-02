#
# $Id: Makefile,v 1.12 2006/11/02 19:24:38 eserte Exp $
#

# XXX don't duplicate, see ../Makefile.PL
STRPP=	strpp
# XXX replace with tpage from Template 2.14?
#TPAGE=	mytpage
TPAGE=	tpage
# XXX get from elsewhere
CGIDIR?=../cgi

all:	newstreetform.html newstreetform.utf8.html \
	fragezeichenform.html fragezeichenform.utf8.html \
	bbbike_small

bbbike_small:	bbbike_small.html bbbike_small.en.html \
		bbbike_sidebar.html bbbike_sidebar.en.html

bbbike_small.html bbbike_small.en.html: bbbike_small.html.spp
	${STRPP} --dir=. bbbike_small.html.spp
	chmod 644 bbbike_small.html bbbike_small.en.html

bbbike_sidebar.html bbbike_sidebar.en.html: bbbike_sidebar.html.spp
	${STRPP} --dir=. bbbike_sidebar.html.spp
	chmod 644 bbbike_sidebar.html bbbike_sidebar.en.html

newstreetform.html: newstreetform.tpl.html
	${TPAGE} --define cgidir=${CGIDIR} newstreetform.tpl.html > $@
	chmod ugo+r $@

newstreetform.utf8.html: newstreetform.tpl.html
	${TPAGE} --define cgidir=${CGIDIR} --define nometacharset=1 --define encoding=utf-8 newstreetform.tpl.html | piconv -f latin1 -t utf8 > $@
	chmod ugo+r $@

fragezeichenform.html: newstreetform.tpl.html
	${TPAGE} --define cgidir=${CGIDIR} --define is_fragezeichen_form=1 newstreetform.tpl.html > $@
	chmod ugo+r $@

fragezeichenform.utf8.html: newstreetform.tpl.html
	${TPAGE} --define cgidir=${CGIDIR} --define is_fragezeichen_form=1 --define nometacharset=1 --define encoding=utf-8 newstreetform.tpl.html | piconv -f latin1 -t utf8 > $@
	chmod ugo+r $@
