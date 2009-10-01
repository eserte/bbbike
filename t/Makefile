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
# Test BBBikeSOAP
# There are four stages
# * bbbikesoap-devel is for development
# * bbbikesoap-test is for the test directory. This will create the test
#   cases used for the other stages.
# * bbbikesoap-extern is for the external IP address
# * bbbikesoap-intern is for the internal IP address

bbbikesoap-devel: _bbbikesoap-httpd
	./bbbikesoap.t -proxy http://localhost:8082/soapbbbike -create

_bbbikesoap-httpd:
	-kill -TERM `cat /tmp/eserte-httpd.pid`
	-httpd -D PERL -f /home/e/eserte/src/bbbike/miscsrc/httpd.conf

bbbikesoap-test:
	./bbbikesoap.t -proxy http://localhost:8080/soapbbbike-test -create

bbbikesoap-extern:
	./bbbikesoap.t -proxy http://194.140.111.226:8080/soapbbbike

bbbikesoap-intern:
	./bbbikesoap.t -proxy http://outerwww.intra.onlineoffice.de/soapbbbike

# XXX noch nicht aktiv...
bbbikesoap-intern-new:
	./bbbikesoap.t -proxy http://localhost:8080/soapbbbike

######################################################################

# only for kira-pc:
kira-test:
	env BBBIKE_TEST_DRAW_ONLY_MODULES=GD/png,GD/jpeg,Imager/png,Imager/jpeg,SVG,PDF,BBBikeGoogleMaps \
	    $(MAKE) test-no-cgi PERL=/cygdrive/c/Perl/bin/perl

