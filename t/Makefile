# BBBIKE_TEST_SLOW_NETWORK=1
# BBBIKE_TEST_NO_NETWORK=1
# BBBIKE_TEST_NO_CGI_TESTS=1

PERL?=		perl
# TEST_FILES must be a single argument
TEST_FILES=	*.t
# Guessing on cgi test scripts
CGI_TEST_FILES=	t/mapserver.t t/bbbikegooglemap.t t/*cgi*.t

test:
	LANG=C $(PERL) -w -I.. -I../lib -MTest::Harness -e \
	    'runtests(@ARGV)' $(TEST_FILES)

test-shuffle:
	LANG=C $(PERL) -w -I.. -I../lib -MTest::Harness -MList::Util=shuffle -e \
	    'runtests(shuffle @ARGV)' $(TEST_FILES)

test-no-cgi:
	LANG=C BBBIKE_TEST_NO_CGI_TESTS=1 $(PERL) -w -I.. -I../lib -MTest::Harness -e \
	    'runtests(@ARGV)' $(TEST_FILES)

prove-no-cgi:
	(cd .. && LANG=C BBBIKE_TEST_NO_CGI_TESTS=1 $(PERL) -S prove -w -I -Ilib t/$(TEST_FILES))

test-cgi-lite:
	LANG=C BBBIKE_TEST_SKIP_MAPSERVER=1 BBBIKE_TEST_SKIP_PALMDOC=1 $(PERL) -w -I.. -I../lib -MTest::Harness -e \
	    'runtests(@ARGV)' $(TEST_FILES)

prove-cgi-lite:
	(cd .. && LANG=C BBBIKE_TEST_SKIP_MAPSERVER=1 BBBIKE_TEST_SKIP_PALMDOC=1 $(PERL) -S prove -w -I -Ilib t/$(TEST_FILES))

# Assumes a running plackup server on standard port 5000
#
#    plackup cgi/bbbike.psgi
#
test-psgi:
	(cd .. && LANG=C BBBIKE_TEST_CGIDIR=http://localhost:5000/bbbike/cgi BBBIKE_TEST_CGIURL=http://localhost:5000/bbbike/cgi/bbbike.cgi BBBIKE_TEST_WAPURL=http://localhost:5000/bbbike/cgi/wapbbbike.cgi BBBIKE_TEST_HTMLDIR=http://localhost:5000/bbbike -w -I.. -I../lib -MTest::Harness -e \
	    'runtests(@ARGV)' $(CGI_TEST_FILES))

prove-psgi:
	(cd .. && LANG=C BBBIKE_TEST_CGIDIR=http://localhost:5000/bbbike/cgi BBBIKE_TEST_CGIURL=http://localhost:5000/bbbike/cgi/bbbike.cgi BBBIKE_TEST_WAPURL=http://localhost:5000/bbbike/cgi/wapbbbike.cgi BBBIKE_TEST_HTMLDIR=http://localhost:5000/bbbike $(PERL) -S prove -w -I -Ilib $(CGI_TEST_FILES))

# This is basically test-no-cgi, but works with dmake
# (dmake+windows cannot ?=, env shell syntax, single quotes, * expansion)
test-on-windows:
	perl -w -I.. -I../lib -MTest::Harness -e "$$ENV{{BBBIKE_TEST_NO_CGI_TESTS}} = 1; runtests(<*.t>)" 

interactive:
	./cgi2.pl -v -netscape -today

# SGML-Parser-Test mit nsgmls
sgml:
	./cgi2.pl -v -sgml -today

# l‰ﬂt nsgmls nur auf die Startseite laufen
sgmlindex:
	(echo '<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">'; (lynx -source http://localhost/bbbike/cgi/bbbike.cgi | tail +2)) > /tmp/bla.html
	nsgmls -m /usr/www/informatik/hypermedia/html/html4.0/sgml/CATALOG /tmp/bla.html 2>/tmp/errors >/dev/null

######################################################################

# only for kira-pc:
kira-test:
	env BBBIKE_TEST_DRAW_ONLY_MODULES=GD/png,GD/jpeg,Imager/png,Imager/jpeg,SVG,PDF,BBBikeGoogleMaps \
	    $(MAKE) test-no-cgi PERL=/cygdrive/c/Perl/bin/perl

