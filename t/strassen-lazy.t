#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassen-lazy.t,v 1.1 2003/06/21 14:36:03 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data");

BEGIN {
    if (!eval q{
	use Test;
	use Strassen::Lazy;
	1;
    }) {
	print "1..0 # skip: no Test/Object::Realize::Later modules\n";
	exit;
    }
}

BEGIN { plan tests => 4 }

my $s = Strassen::Lazy->new("strassen");
ok(UNIVERSAL::isa($s, "Strassen::Lazy"));
$s->get(0); # trigger realization
ok($s->isa("Strassen"));
my $r = $s->get_by_name("Dudenstr.");
ok($r);
ok($r->[Strassen::NAME], "Dudenstr.");

__END__
