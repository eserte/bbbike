#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../miscsrc",
	);
use Test::More 'no_plan';

use ReverseGeocoding;

my $rg = ReverseGeocoding->new('bbbike');
isa_ok $rg, 'ReverseGeocoding';

{
    my $res = $rg->find_closest("13.5,52.5", "road");
    is $res, 'Sewanstr.', 'find road';
}

{
    my $res = $rg->find_closest("-13.5,-52.5", "road");
    is $res, undef, 'do not find road';
}

{
    my $res = $rg->find_closest("13.236871,52.754177", "area");
    is $res, 'Oranienburg', 'find area';
}

{
    my $res = $rg->find_closest("-13.236871,-52.754177", "area");
    is $res, undef, 'do not find area';
}

__END__
