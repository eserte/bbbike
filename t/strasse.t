#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strasse.t,v 1.1 2003/08/07 23:16:14 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../data", "$FindBin::RealBin/../lib");
use Strassen::Strasse;

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "1..0 # skip: no Test module\n";
	exit;
    }
}

BEGIN { plan tests => 3 }

for my $s (["Heerstr. (Spandau, Charlottenburg)" =>
	    ["Heerstr.", "Spandau", "Charlottenburg"]],
	   ["Heerstr. (Spandau)" =>
	    ["Heerstr.", "Spandau"]],
	   ["Heerstr." => ["Heerstr."]],
	  ) {
    my($str, @expected) = ($s->[0], @{ $s->[1] });
    my(@res) = Strasse::split_street_citypart($str);
    ok(join("#", @res), join("#", @expected));
}

__END__
