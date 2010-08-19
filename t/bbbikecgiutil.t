#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbbikecgiutil.t,v 1.2 2008/07/15 20:11:13 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib "$FindBin::RealBin/..";

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

use CGI;

plan tests => 6;

use_ok("BBBikeCGIUtil");

{
    my $q = CGI->new({movemap => "Süd"});
    BBBikeCGIUtil::decode_possible_utf8_params($q, "not_used", "not_used");
    is($q->param("movemap"), "Süd");
}

SKIP: {
    skip("Encode not available", 1)
	if !eval { require Encode; 1 };
    my $sued_utf8 = Encode::encode("utf-8", "Süd");
    my $q = CGI->new({movemap => $sued_utf8});
    BBBikeCGIUtil::decode_possible_utf8_params($q, "not_used", "not_used");
    my $success = is($q->param("movemap"), "Süd");
    if (!$success && $Encode::VERSION lt "2.08") {
	diag "Failure expected with this Encode version ($Encode::VERSION)";
    }
}

{
    is(BBBikeCGIUtil::my_escapeHTML("ABC<>&DEF"), "ABC&#60;&#62;&#38;DEF", "Escaping classic ones");
    is(BBBikeCGIUtil::my_escapeHTML("ä"), "&#228;", "Escaping latin1");
    is(BBBikeCGIUtil::my_escapeHTML("ä\x{20ac}"), "&#228;&#8364;", "Escaping unicode > 255");
}

__END__
