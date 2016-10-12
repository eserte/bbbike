# BBBIKE_TEST_SLOW_NETWORK=1
# BBBIKE_TEST_NO_NETWORK=1
# BBBIKE_TEST_NO_CGI_TESTS=1
# BBBIKE_TEST_GUI=1

PERL?=		perl
PSGI_PORT?=	5000
# TEST_FILES must be a single argument
TEST_FILES=	*.t
# List created with:
#    echo `git grep -l '^check_cgi_testing' t/*.t`
CGI_TEST_FILES=	t/bbbikecgiapi.t t/bbbikegooglemap.t t/cgi-cookie.t t/cgi-mechanize-upload.t t/cgi-mechanize.t t/cgi-test.t t/cgi-validator.t t/cgi.t t/cgihead.t t/cgihead2.t t/m-bbbike-de.t t/mapserver-util.t t/mapserver.t t/mapserver_comment.t t/old_comments.t t/radrouten.t t/server-check.t t/wapcgi.t t/wwwdata.t

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

# Live layout (.../cgi-bin/bbbike.cgi, .../BBBike/html) and
# http://localhost (no vhost)
test-live-layout-localhost:
	(cd .. && LANG=C BBBIKE_TEST_SKIP_MAPSERVER=1 BBBIKE_TEST_SKIP_PALMDOC=1 BBBIKE_TEST_CGIDIR=http://localhost/cgi-bin BBBIKE_TEST_HTMLDIR=http://localhost/BBBike BBBIKE_TEST_FOR_LIVE=1 \
	    $(PERL) -S prove -w -I -Ilib t/$(TEST_FILES))

test-live-layout-localhost-staging:
	(cd .. && LANG=C BBBIKE_TEST_SKIP_MAPSERVER=1 BBBIKE_TEST_SKIP_PALMDOC=1 BBBIKE_TEST_CGIDIR=http://bbbike-staging/cgi-bin BBBIKE_TEST_HTMLDIR=http://localhost/BBBike BBBIKE_TEST_FOR_LIVE=1 \
	    $(PERL) -S prove -w -I -Ilib t/$(TEST_FILES))

# Assumes a running plackup server on standard port 5000
# (or change port by setting the PSGI_PORT variable)
#
#    plackup cgi/bbbike.psgi
#
PSGI_ENV=BBBIKE_TEST_CGIDIR=http://localhost:$(PSGI_PORT)/bbbike/cgi BBBIKE_TEST_CGIURL=http://localhost:$(PSGI_PORT)/bbbike/cgi/bbbike.cgi BBBIKE_TEST_WAPURL=http://localhost:$(PSGI_PORT)/bbbike/cgi/wapbbbike.cgi BBBIKE_TEST_HTMLDIR=http://localhost:$(PSGI_PORT)/bbbike

test-psgi:
	(cd .. && LANG=C $(PSGI_ENV) $(PERL) -w -I.. -I../lib -MTest::Harness -e \
	    'runtests(@ARGV)' $(CGI_TEST_FILES))

test-all-psgi:
	LANG=C $(PSGI_ENV) $(PERL) -w -I.. -I../lib -MTest::Harness -e \
	    'runtests(@ARGV)' $(TEST_FILES)

prove-psgi:
	(cd .. && LANG=C $(PSGI_ENV) $(PERL) -S prove -w -I -Ilib $(CGI_TEST_FILES))

prove-all-psgi:
	LANG=C $(PSGI_ENV) $(PERL) -S prove -w -I -Ilib $(TEST_FILES)

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

