#
# $Id: Makefile,v 1.8 2005/02/27 21:06:37 eserte Exp $
#

# XXX don't duplicate, see ../Makefile.PL
STRPP=	strpp
# XXX replace with tpage from Template 2.14?
#TPAGE=	mytpage
TPAGE=	tpage
# XXX get from elsewhere
CGIDIR?=../cgi

all: newstreetform.html fragezeichenform.html bbbike_small

bbbike_small:	bbbike_small.html bbbike_small.en.html \
		bbbike_sidebar.html bbbike_sidebar.en.html

bbbike_small.html bbbike_small.en.html: bbbike_small.html.spp
	${STRPP} --dir=. bbbike_small.html.spp
	chmod 644 bbbike_small.html bbbike_small.en.html

bbbike_sidebar.html bbbike_sidebar.en.html: bbbike_sidebar.html.spp
	${STRPP} --dir=. bbbike_sidebar.html.spp
	chmod 644 bbbike_sidebar.html bbbike_sidebar.en.html

newstreetform.html: newstreetform.tpl.html
	${TPAGE} --define cgidir=${CGIDIR} $> > $@
	chmod ugo+r $@

fragezeichenform.html: newstreetform.tpl.html
	${TPAGE} --define cgidir=${CGIDIR} --define is_fragezeichen_form=1 $> > $@
	chmod ugo+r $@
