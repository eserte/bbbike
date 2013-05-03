#!/usr/bin/perl -w
# -*- perl -*-

#
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

use_ok("BBBikeCGI::Util");

{
    my $q = CGI->new({movemap => "Süd"});
    BBBikeCGI::Util::decode_possible_utf8_params($q, "not_used", "not_used");
    is($q->param("movemap"), "Süd");
}

SKIP: {
    skip("Encode not available", 1)
	if !eval { require Encode; 1 };
    my $sued_utf8 = Encode::encode("utf-8", "Süd");
    my $q = CGI->new({movemap => $sued_utf8});
    BBBikeCGI::Util::decode_possible_utf8_params($q, "not_used", "not_used");
    my $success = is($q->param("movemap"), "Süd");
    if (!$success && $Encode::VERSION lt "2.08") {
	diag "Failure expected with this Encode version ($Encode::VERSION)";
    }
}

{
    is(BBBikeCGI::Util::my_escapeHTML("ABC<>&DEF"), "ABC&#60;&#62;&#38;DEF", "Escaping classic ones");
    is(BBBikeCGI::Util::my_escapeHTML("ä"), "&#228;", "Escaping latin1");
    is(BBBikeCGI::Util::my_escapeHTML("ä\x{20ac}"), "&#228;&#8364;", "Escaping unicode > 255");
}

__END__
