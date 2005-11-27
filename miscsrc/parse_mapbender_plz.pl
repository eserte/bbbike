#!/usr/bin/perl
# -*- perl -*-

#
# $Id: parse_mapbender_plz.pl,v 1.3 2005/11/27 09:34:54 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2005 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use warnings;
no warnings 'qw';
use FindBin;
use lib "$FindBin::RealBin/..";
use Karte;
use Karte::Polar;
use Karte::Standard;

my @colors = qw(#ffeecd #ffadcc #adffcc #ccadff #ffaa9d);
my $colors_i = 0;

while(<>) {
    chomp;
    if (/^INSERT INTO/) {
	if (/^INSERT INTO post_code_areas VALUES \(\d+, '(\d+)', \d+, '(.*?)', 'SRID=4326;MULTIPOLYGON\(+(.*?)\)+'\);/) {
	    my($plz, $city, $multipolygon) = ($1, $2, $3);
	    my $color = $colors[$colors_i];
	    $colors_i++; $colors_i %= scalar(@colors);
	    while ($multipolygon =~ m{(.*?)(?:\)+,\(+|$)}g) {
		my $coords = $1;
		last if $coords eq "";
		my(@coords) = split /,/, $coords;
		my @standard_coords;
		for my $c (@coords) {
		    my($sx,$sy) = $Karte::Standard::obj->trim_accuracy($Karte::Polar::obj->map2standard(split / /, $c));
		    $sy -= 278;
		    $sx -= 210;
		    push @standard_coords, join ",", $sx,$sy;
		}
		my $cat = "F:$color|stiplite.xbm";
		print "$plz ($city)\t$cat @standard_coords\n";
	    }
	} else {
	    warn "Cannot parse INSERT line <$_>";
	}
    }
}

__END__

plz.sql: aus http://prdownloads.sourceforge.net/mapbender/plz.zip?download

./parse_mapbender_plz.pl < /tmp/plz.sql > /tmp/plz.bbd

Oder nur Berlin:

grep -i berlin /tmp/plz.sql | ./parse_mapbender_plz.pl > /tmp/plz-b.bbd
