# -*- perl -*-

#
# $Id: WaypointPlus.pm,v 1.1 2003/07/21 22:39:58 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package GPS::WaypointPlus;

use strict;
use vars qw($VERSION @ISA);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

require GPS;
push @ISA, 'GPS';

sub magics { ('^Datum,') }

sub convert_to_route {
    my($self, $file, %args) = @_;

    require Karte::Polar;
    my $obj = $Karte::Polar::obj;

    my @res;
    open(FH, $file) or die "Can't open $file: $!";
    while(<FH>) {
	if (/^TP,D,/) {
	    chomp;
	    my(@l) = split /,/;
	    my($x,$y) = $obj->map2standard($l[3], $l[2]);
	    if (!@res || ($x != $res[-1]->[0] ||
			  $y != $res[-1]->[1])) {
		push @res, [$x, $y];
	    }
	}
    }
    close FH;

    @res;
}

sub convert_from_route {
    my($self, $route, %args) = @_;

    my $net       = $args{-netobj};

    require Karte::Polar;
    require Strassen::Core;

    my $obj = $Karte::Polar::obj;

    my $s = <<EOF;
Datum,WGS84,WGS84,0,0,0,0,0

EOF
    my @path;
    if ($args{-simplify}) {
	my $max_waypoints = $args{-maxwaypoints} || 50;
	@path = $route->path_list_max($net, $max_waypoints);
    } else {
	@path = $route->path_list;
    }

    my $is_first = 1;
    foreach my $xy (@path) {
	my($polar_x, $polar_y) = $obj->standard2map(@$xy);
	$s .= sprintf "TP,D,%.5f,%.5f,00/00/00,00:00:00,%d\n", $polar_y, $polar_x, $is_first;
	$is_first = 0 if $is_first;
    }

    $s;
}

1;

__END__
