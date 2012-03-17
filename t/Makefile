PERL?=		perl
TEST_FILES=	*.t

test:
	LANG=C $(PERL) -w -I.. -I../lib -MTest::Harness -e \
	    'runtests(@ARGV)' $(TEST_FILES)

test-shuffle:
	LANG=C $(PERL) -w -I.. -I../lib -MTest::Harness -e \
	    'BEGIN { if (!eval q{ use List::Util qw(shuffle); 1 }) { *shuffle = sub { @_ }; } } runtests(shuffle @ARGV)' $(TEST_FILES)

test-no-cgi:
	LANG=C BBBIKE_TEST_NO_CGI_TESTS=1 $(PERL) -w -I.. -I../lib -MTest::Harness -e \
	    'runtests(@ARGV)' $(TEST_FILES)

# This is basically test-no-cgi, but works with dmake
# (dmake+windows cannot ?=, env shell syntax, single quotes, * expansion)
test-on-windows:
	perl -w -I.. -I../lib -MTest::Harness -e "$$ENV{BBBIKE_TEST_NO_CGI_TESTS} = 1; runtests(<*.t>)" 

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

