TPAGE=	tpage
# XXX get from elsewhere
CGIDIR?=../cgi

all:	newstreetform.html newstreetform.utf8.html \
	fragezeichenform.html fragezeichenform.utf8.html \
	shortfragezeichenform.html shortfragezeichenform.utf8.html \
	bbbike_small \
	bbbike-opensearch \
	bbbike-opensearch-images \
	bbbikeleaflet.en.html

bbbike_small:	bbbike_small.html bbbike_small.en.html \
		bbbike_sidebar.html bbbike_sidebar.en.html

bbbike_small.html: bbbike_small.tpl.html ../BBBikeVar.pm
	tpage --define lang=DE --eval_perl bbbike_small.tpl.html > bbbike_small.html~
	chmod 644 bbbike_small.html~
	mv bbbike_small.html~ bbbike_small.html

bbbike_small.en.html: bbbike_small.tpl.html ../BBBikeVar.pm
	tpage --define lang=EN --eval_perl bbbike_small.tpl.html > bbbike_small.en.html~
	chmod 644 bbbike_small.en.html~
	mv bbbike_small.en.html~ bbbike_small.en.html

bbbike_sidebar.html: bbbike_sidebar.tpl.html ../BBBikeVar.pm
	tpage --define lang=DE --eval_perl bbbike_sidebar.tpl.html > bbbike_sidebar.html~
	chmod 644 bbbike_sidebar.html~
	mv bbbike_sidebar.html~ bbbike_sidebar.html

bbbike_sidebar.en.html: bbbike_sidebar.tpl.html ../BBBikeVar.pm
	tpage --define lang=EN --eval_perl bbbike_sidebar.tpl.html > bbbike_sidebar.en.html~
	chmod 644 bbbike_sidebar.en.html~
	mv bbbike_sidebar.en.html~ bbbike_sidebar.en.html

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

shortfragezeichenform.html: newstreetform.tpl.html
	${TPAGE} --define cgidir=${CGIDIR} --define is_fragezeichen_form=1 --define is_short_fragezeichen_form=1 newstreetform.tpl.html > $@
	chmod ugo+r $@

shortfragezeichenform.utf8.html: newstreetform.tpl.html
	${TPAGE} --define cgidir=${CGIDIR} --define is_fragezeichen_form=1 --define is_short_fragezeichen_form=1 --define nometacharset=1 --define encoding=utf-8 newstreetform.tpl.html | piconv -f latin1 -t utf8 > $@
	chmod ugo+r $@

bbbike-opensearch:	opensearch/bbbike-opensearch-de-simple.xml \
			opensearch/bbbike-opensearch-de.xml \
			opensearch/bbbike-opensearch-en-simple.xml \
			opensearch/bbbike-opensearch-en.xml \
			opensearch/bbbike-opensearch-de-simple.src \
			opensearch/bbbike-opensearch-de.src \
			opensearch/bbbike-opensearch-en-simple.src \
			opensearch/bbbike-opensearch-en.src

opensearch/bbbike-opensearch-de-simple.xml: opensearch/bbbike-opensearch.tpl.xml
	${TPAGE} --define lang=de --define lang_msg=deutsch --define type_msg=einfach --define paramspec='start={searchTerms}' $> > $@
	chmod ugo+r $@

opensearch/bbbike-opensearch-de.xml: opensearch/bbbike-opensearch.tpl.xml
	${TPAGE} --define lang=de --define lang_msg=deutsch --define type_msg=erweitert --define paramspec='ossp={searchTerms}' $> > $@
	chmod ugo+r $@

opensearch/bbbike-opensearch-en-simple.xml: opensearch/bbbike-opensearch.tpl.xml
	${TPAGE} --define lang=en --define lang_msg=english --define type_msg=einfach --define paramspec='start={searchTerms}' $> > $@
	chmod ugo+r $@

opensearch/bbbike-opensearch-en.xml: opensearch/bbbike-opensearch.tpl.xml
	${TPAGE} --define lang=en --define lang_msg=english --define type_msg=erweitert --define paramspec='ossp={searchTerms}' $> > $@
	chmod ugo+r $@

opensearch/bbbike-opensearch-de-simple.src: opensearch/bbbike-opensearch.tpl.src
	${TPAGE} --define lang=de --define lang_msg=deutsch --define type_msg=einfach --define type=simple --define paramspec='start={searchTerms}' $> > $@
	chmod ugo+r $@

opensearch/bbbike-opensearch-de.src: opensearch/bbbike-opensearch.tpl.src
	${TPAGE} --define lang=de --define lang_msg=deutsch --define type_msg=erweitert --define paramspec='ossp={searchTerms}' $> > $@
	chmod ugo+r $@

opensearch/bbbike-opensearch-en-simple.src: opensearch/bbbike-opensearch.tpl.src
	${TPAGE} --define lang=en --define lang_msg=english --define type_msg=einfach --define type=simple --define paramspec='start={searchTerms}' $> > $@
	chmod ugo+r $@

opensearch/bbbike-opensearch-en.src: opensearch/bbbike-opensearch.tpl.src
	${TPAGE} --define lang=en --define lang_msg=english --define type_msg=erweitert --define paramspec='ossp={searchTerms}' $> > $@
	chmod ugo+r $@

bbbike-opensearch-images:	\
			opensearch/bbbike-opensearch-de-simple.gif \
			opensearch/bbbike-opensearch-de.gif \
			opensearch/bbbike-opensearch-en-simple.gif \
			opensearch/bbbike-opensearch-en.gif

opensearch/bbbike-opensearch-de-simple.gif:
	cd opensearch && ln -s ../../images/srtbike16.gif bbbike-opensearch-de-simple.gif

opensearch/bbbike-opensearch-de.gif:
	cd opensearch && ln -s ../../images/srtbike16.gif bbbike-opensearch-de.gif

opensearch/bbbike-opensearch-en-simple.gif:
	cd opensearch && ln -s ../../images/srtbike16.gif bbbike-opensearch-en-simple.gif

opensearch/bbbike-opensearch-en.gif:
	cd opensearch && ln -s ../../images/srtbike16.gif bbbike-opensearch-en.gif

bbbikeleaflet.en.html:
	ln -s bbbikeleaflet.html bbbikeleaflet.en.html

# found json2.js at https://raw.github.com/douglascrockford/JSON-js/master/json2.js
json2.min.js: json2.js
	jsmin < $> > $@
