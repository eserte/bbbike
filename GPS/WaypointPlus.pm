# -*- perl -*-

#
# $Id: WaypointPlus.pm,v 1.2 2005/04/16 12:23:07 eserte Exp $
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
$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

require GPS;
push @ISA, 'GPS';

sub magics { ('^Datum,') }

sub convert_to_route {
    my($self, $file, %args) = @_;
    my $res = $self->parse($file, %args);
    map { [@{$_}[0,1]] } @{ $res->{points } };
}

sub parse {
    my($self, $file, %args) = @_;

    require Karte::Polar;
    my $obj = $Karte::Polar::obj;

    my @res;
    my $type;
    open(FH, $file) or die "Can't open $file: $!";
    while(<FH>) {
	if (/^([WT])P,(D|DMX),/) {
	    $type = $1;
	    my $ddd = $2;
	    my $start_inx = $type eq 'W' ? 3 : 2;

	    chomp;
	    my(@l) = split /,/;

	    my($desc, $long, $lat);
	    if ($ddd eq 'D') {
		$long = $l[$start_inx+1];
		$lat  = $l[$start_inx+0];
		$desc = $l[$start_inx+4];
	    } else { # DMX
		my $long_d  = $l[$start_inx+2];
		my $long_mx = $l[$start_inx+3];
		my $lat_d   = $l[$start_inx+0];
		my $lat_mx  = $l[$start_inx+1];
		$long = Karte::Polar::dmm2ddd($long_d, $long_mx);
		$lat  = Karte::Polar::dmm2ddd($lat_d, $lat_mx);
		$desc = $l[$start_inx+6];
	    }
	    my($x,$y) = $obj->map2standard($long, $lat);
	    if (!@res || ($x != $res[-1]->[0] ||
			  $y != $res[-1]->[1])) {
		push @res, [$x, $y, $desc];
	    }
	}
    }
    close FH;

    return { type => $type,
	     points => \@res,
	   };
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
