#
# $Id: Makefile,v 1.7 2004/08/26 23:53:17 eserte Exp $
#

# XXX don't duplicate, see ../Makefile.PL
STRPP=	strpp
TPAGE=	mytpage
# XXX get from elsewhere
CGIDIR?=../cgi

all: newstreetform.html bbbike_small

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

