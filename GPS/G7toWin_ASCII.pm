# -*- perl -*-

#
# $Id: G7toWin_ASCII.pm,v 1.19 2007/07/21 10:14:13 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package GPS::G7toWin_ASCII;
require GPS;
push @ISA, 'GPS';

use GPS::Util;

use strict;

sub magics { ('^#', '^D\s+WGS-84', '^M\s+DMM') }

sub convert_to_route {
    my($self, $file, %args) = @_;

    my($fh, $lines_ref) = $self->overread_trash($file, %args);
    die "File $file is not a G7T file" unless $fh;

    require Karte::Polar;
    require Karte::Standard;
    my $obj = $Karte::Polar::obj;
    $Karte::Standard::obj = $Karte::Standard::obj if 0; # cease -w

    my @res;
    my $check = sub {
	my $line = shift;
	chomp;
	if (m{^(?:T|W\s+(?:\w+))\s+([NS])(\d+)\s+([\d.]+)\s+([EW])(\d+)\s+([\d.]+)}) {
	    my $breite = $2;
	    my $laenge = $5;

	    my $breite_min = $3/60;
	    my $laenge_min = $6/60;

	    $breite += $breite_min;
	    $laenge += $laenge_min;

	    if ($1 eq 'S') { $breite = -$breite }
	    if ($3 eq 'W') { $laenge = -$laenge }
	    my($x,$y) = $Karte::Standard::obj->trim_accuracy($obj->map2standard($laenge, $breite));
	    if (!@res || ($x != $res[-1]->[0] ||
			  $y != $res[-1]->[1])) {
		push @res, [$x, $y];
	    }
	}
    };

    $check->($_) foreach @$lines_ref;
    while(<$fh>) {
	$check->($_);
    }

    close $fh;

    @res;
}

sub convert_from_route {
    my($self, $route, %args) = @_;

    no locale; # for scalar localtime

    require Karte::Polar;
    require Strassen;

    my $obj = $Karte::Polar::obj;

    my $routename = sprintf("%-8s", $args{-routename} || "TRACBACK");
    my $str       = $args{-streetobj};
    my $net       = $args{-netobj};
    my %crossings;
    if ($str) {
	%crossings = %{ $str->all_crossings(RetType => 'hash',
					    UseCache => 1) };
    }

    my $now = scalar localtime;
    my $point_counter = 0;
    my %point_counter;
    use constant MAX_COMMENT => 45;

    use constant DISPLAY_SYMBOL_BIG => 8196; # zwei kleine Füße
    use constant DISPLAY_SYMBOL_SMALL => 18; # viereckiger Punkt, also allgemeiner Wegepunkt
    use constant SHOW_SYMBOL => 1;
    use constant SHOW_SYMBOL_AND_NAME => 4; # XXX ? ja ?
    use constant SHOW_SYMBOL_AND_COMMENT => 5;

    my $s = <<EOF;
#$now\015
D WGS-84\015
M DMM\015
R  20 $routename\015
EOF
    my @path;
    my $obj_type;
    if ($args{-routetoname}) {
	@path = map
	         { $route->path->[$_->[&StrassenNetz::ROUTE_ARRAYINX][0]] }
		@{$args{-routetoname}};
	$obj_type = 'routetoname';
    } else {
	if ($net && $args{-simplify}) {
	    my $max_waypoints = $args{-maxwaypoints} || 50;
	    @path = $route->path_list_max($net, $max_waypoints);
	} else {
	    @path = $route->path_list;
	}
	$obj_type = 'route';
    }

    my $n = 0;
    foreach my $xy (@path) {
	my $xy_string = join ",", @$xy;
	my($polar_x, $polar_y) = $obj->trim_accuracy($obj->standard2map(@$xy));
	my $NS = $polar_y > 0 ? "N" : do { $polar_y = -$polar_y; "S" };
	my $EW = $polar_x > 0 ? "E" : do { $polar_x = -$polar_x; "W" };
	my $ns_deg = int($polar_y);
	my $ew_deg = int($polar_x);
	my $ns_min = ($polar_y-$ns_deg)*60;
	my $ew_min = ($polar_x-$ew_deg)*60;

	# create comment and point number
	my $comment = "$now ";
	my $point_number;
	if ($str && exists $crossings{$xy_string}) {
	    my $short_crossing;

	    my @cross_streets = @{ $crossings{$xy_string} };

	    if ($obj_type eq 'routetoname') {
		my $main_street = $args{-routetoname}->[$n][&StrassenNetz::ROUTE_NAME];
		# test for simplify_route_to_name output:
		if (ref $main_street eq 'ARRAY') {
		    $main_street = $main_street->[0];
		}
		@cross_streets =
		    map  { $_->[0] }
		    sort { $b->[1] <=> $a->[1] }
		    map  { [$_, $_ eq $main_street ? 100 : 0 ] }
			@cross_streets;
	    }

	    # try to shorten street names
	    my $level = 0;
	    while($level <= 3) {
		$short_crossing = join(" ", map { s/\s+\(.*\)\s*$//; Strasse::short($_, $level) } @cross_streets);
		$short_crossing = eliminate_umlauts($short_crossing);
		last
		    if (length($short_crossing) + length($comment) <= MAX_COMMENT);
		$level++;
	    }

	    $comment .= $short_crossing;
	    my $short_name = substr($short_crossing, 0, 5);
	    $point_number = $short_name;
	    if (exists $point_counter{$short_name}) {
		$point_number .= $point_counter{$short_name};
		if ($point_counter{$short_name} ge "0" &&
		    $point_counter{$short_name} le "8") {
		    $point_counter{$short_name}++;
		} elsif ($point_counter{$short_name} eq "9") {
		    $point_counter{$short_name} = "A";
		} else {
		    $point_counter{$short_name} = chr(ord($point_counter{$short_name})+1);
		}
	    } else {
		$point_counter{$short_name} = 0;
	    }
	}
	if (length($comment) > MAX_COMMENT) {
	    $comment = substr($comment, 0, MAX_COMMENT);
	}
	if (!defined $point_number) {
	    $point_number = "T". ($point_counter++);
	}

	$s .= sprintf
	    "%-3s%-6s          %s%02s %07.4f %s%03d %07.4f %-" . MAX_COMMENT . "s; %d;%d;0\015\012",
	    "W",
	    $point_number,
	    $NS, $ns_deg, $ns_min,
	    $EW, $ew_deg, $ew_min,
	    $comment,
	    DISPLAY_SYMBOL_SMALL,
	    SHOW_SYMBOL_AND_COMMENT,
	    ;
    } continue {
	$n++;
    }
    $s .= "E  20\015\012";
    $s;
}

1;

__END__
