#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassen-grepstreets.t,v 1.1 2004/08/27 00:04:58 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data");

use Strassen::Core;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

BEGIN { plan tests => 1 }

{
    my $s = Strassen->new;
    for (1..10) {
	$s->push(["Name$_", ["1,2","3,4"], "Cat".($_%2) ]);
    }
    my $new_s = $s->grepstreets(sub { $_->[Strassen::CAT] eq "Cat0" });
    is(scalar @{$new_s->{Data}}, 5);
}

__END__
