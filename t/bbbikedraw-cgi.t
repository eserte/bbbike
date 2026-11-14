#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use warnings;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 $FindBin::RealBin,
	);

use Test::More;

use BBBikeTest;

plan skip_all => "CGI.pm needed for tests" if !eval { require CGI; 1 };
plan 'no_plan';

use_ok 'BBBikeDraw';

for my $imagetype (qw(gif jpeg png svg)) {
 SKIP: {
	skip "$imagetype not available", 1
	    if $imagetype eq 'svg' && !eval { require SVG; 1 };
	my $q = CGI->new({
	    imagetype => $imagetype,
	    markerpoint => '100,-20',
	});
	my $o = BBBikeDraw->new_from_cgi($q);
	isa_ok $o, 'BBBikeDraw';
	is $o->{ImageType}, $imagetype, "imagetype $imagetype is accepted";
	is $o->{MarkerPoint}, '100,-20';
	is $o->{CGI}, $q;
    }
}

{
    my $q = CGI->new({
	imagetype => "invalid/type",
	markerpoint => "100,20\n300,20",
    });
    my $o = BBBikeDraw->new_from_cgi($q);
    isa_ok $o, 'BBBikeDraw';
    is $o->{ImageType}, 'gif', 'unhandled type falls back to gif';
    is $o->{MarkerPoint}, undef, 'markerpoint rejected';
    is $o->{CGI}, $q;
}

for my $geometry (qw(6001x6001 100x6001 6001x100)) {
    my $q = CGI->new({
	geometry => $geometry,
    });
    my $o = eval { BBBikeDraw->new_from_cgi($q) };
    like $@, qr{width.*height.*too large}i, "geometry $geometry is rejected";
}

__END__
