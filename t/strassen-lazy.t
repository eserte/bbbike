#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassen-lazy.t,v 1.4 2003/07/24 06:25:59 eserte Exp $
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

BEGIN { plan tests => 10, todo => [5..10] }

{
    my $s = Strassen::Lazy->new("strassen");
    ok(UNIVERSAL::isa($s, "Strassen::Lazy"));
    $s->get(0); # trigger realization # XXX why is this triggering a warning
    ok($s->isa("Strassen"));
    my $r = $s->get_by_name("Dudenstr.");
    ok($r);
    ok($r->[Strassen::NAME], "Dudenstr.");
}

if (0) {
    my $s = MultiStrassen::Lazy->new(qw(strassen landstrassen landstrassen2));
    ok(UNIVERSAL::isa($s, "MultiStrassen::Lazy"));
    $s->get(0); # trigger realization
    ok($s->isa("MultiStrassen"));
    my $r = $s->get_by_name("Dudenstr.");
    ok($r);
    ok($r->[Strassen::NAME], "Dudenstr.");
    $r = $s->get_by_name("B96");
    ok($r);
    ok($r->[Strassen::NAME], "B96");
}
__END__
