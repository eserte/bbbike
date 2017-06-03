# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2017 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Route::GPLE;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use Algorithm::GooglePolylineEncoding ();

sub as_gple {
    my $r = shift;

    my $converter;
    if ($r->coord_system ne 'polar') {
	require Karte;
	if ($r->coord_system eq 'standard') {
	    Karte::preload(qw(Standard Polar));
	} else {
	    Karte::preload(qw(:all));
	}
	my $from_map = $Karte::map{$r->coord_system};
	if (!$from_map) {
	    die "No support for coord system '" . $r->coord_system . "'";
	}
	my $to_map   = $Karte::map{polar};
	$converter = sub {
	    my($x, $y) = @_;
	    $from_map->map2map($to_map, $x, $y);
	};
    } else {
	$converter = sub { @_ };
    }

    my @polyline;
    for my $c ($r->path_list) {
	my($xp,$yp) = $converter->(@$c);
	push @polyline, {lat => $yp, lon => $xp};
    }

    Algorithm::GooglePolylineEncoding::encode_polyline(@polyline);
}

1;

__END__
