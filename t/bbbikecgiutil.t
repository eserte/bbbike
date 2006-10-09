#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbbikecgiutil.t,v 1.1 2006/10/09 15:35:38 eserte Exp $
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
	print "1..0 # skip: no Test::More module\n";
	exit;
    }
}

use CGI;

plan tests => 3;

use_ok("BBBikeCGIUtil");

{
    my $q = CGI->new({movemap => "Süd"});
    BBBikeCGIUtil::encode_possible_utf8_params($q, "not_used", "not_used");
    is($q->param("movemap"), "Süd");
}

SKIP: {
    skip("Encode not available", 1)
	if !eval { require Encode; 1 };
    my $sued_utf8 = Encode::encode("utf-8", "Süd");
    my $q = CGI->new({movemap => $sued_utf8});
    BBBikeCGIUtil::encode_possible_utf8_params($q, "not_used", "not_used");
    my $success = is($q->param("movemap"), "Süd");
    if (!$success && $Encode::VERSION lt "2.08") {
	diag "Failure expected with this Encode version ($Encode::VERSION)";
    }
}

__END__
