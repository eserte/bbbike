#
# $Id: Makefile,v 1.24 2008/02/02 22:11:33 eserte Exp $
#

# l‰uft nicht mit 5.004 oder ‰lter

PERL?=		perl
TEST_FILES=	*.t

test:
	LANG=C $(PERL) -w -I.. -I../lib -MTest::Harness -e \
	    'runtests(@ARGV)' $(TEST_FILES)

test-shuffle:
	LANG=C $(PERL) -w -I.. -I../lib -MTest::Harness -e \
	    'BEGIN { if (!eval q{ use List::Util qw(shuffle); 1 }) { *shuffle = sub { @_ }; } } runtests(shuffle @ARGV)' $(TEST_FILES)

test-no-cgi:
	LANG=C $(PERL) -w -I.. -I../lib -MTest::Harness -e \
	    'runtests(grep { !/^cgi/ && !/^wapcgi/ && !/^radzeit/ && !/^wwwdata/ } @ARGV)' $(TEST_FILES)

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

