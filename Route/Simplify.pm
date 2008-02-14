# -*- perl -*-

#
# $Id: Simplify.pm,v 1.1 2008/02/03 12:10:54 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2008 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Route::Simplify;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

use GPS::Util qw(eliminate_umlauts);

# XXX
# ideas:
#  wichtigkeitspunkte für jeden (möglichen) punkt vergeben:
#  - viele punkte für große winkel
#  - punkte für straßennamenswechsel
#  - evtl. minuspunkte für kleine entfernungen vom vorherigen+nächsten punkt
sub Route::simplify_for_gps {
    my($route, %args) = @_;

    no locale; # for scalar localtime

    require Karte::Polar;
    require Strassen;

    my $obj = $Karte::Polar::obj;
    $Karte::Polar::obj = $Karte::Polar::obj if 0; # cease -w

    my $routename = $args{-routename};
    my $routenumber = $args{-routenumber} || 1;
    my $str       = $args{-streetobj};
    my $net       = $args{-netobj};
    my $wptsuffix = $args{-wptsuffix} || "";
    my $wptsuffixexisting = $args{-wptsuffixexisting} || 0;
    my $convmeth  = $args{-convmeth} || sub {
	$obj->standard2map(@_);
    };
    my $waypointlength = $args{-waypointlength} || 10;
    my $waypointcharset = $args{-waypointcharset} || 'simpleascii';
    my $waypointscache = $args{-waypointscache} || {};
    my $routenamelength = $args{-routenamelength} || 13;

    my %crossings;
    if ($str) {
	%crossings = %{ $str->all_crossings(RetType => 'hash',
					    UseCache => 1) };
    }

    my $now = scalar localtime;
    my $ident_counter = 0;
    my %idents;
    use constant MAX_COMMENT => 45;

    my $simplified_route = { routenumber => $routenumber,
			   };

    my @path;
    my $obj_type;
    my $routetoname = $args{-routetoname};
    if ($routetoname) {
	@path = map {
	    $route->path->[$_->[&StrassenNetz::ROUTE_ARRAYINX][0]]
	} @$routetoname;
	push @path, $route->path->[-1]; # add goal node
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
	my($lon, $lat) = $convmeth->(@$xy); # XXX del: $obj->standard2map(@$xy);

	#warn "lon=$lon lat=$lat\n";

	# create comment and point number
	my $comment = "";
	my $ident;
	my @cross_streets;
	if ($str && exists $crossings{$xy_string}) {

	    @cross_streets = @{ $crossings{$xy_string} };
	}

	my $short_dir   = '';
	if ($obj_type eq 'routetoname') {
	    my $this_street_info = $routetoname->[$n];
	    my $prev_street_info = $routetoname->[$n-1];
	    my $main_street = $this_street_info->[&StrassenNetz::ROUTE_NAME];
	    my $prev_street = $prev_street_info->[&StrassenNetz::ROUTE_NAME] if $n > 0;
	    # The < or > prefix for showing the direction
	    # XXX should use a better "situation_at_point" function
	    if ($waypointcharset eq 'latin1' && ($prev_street_info->[&StrassenNetz::ROUTE_ANGLE]||0) >= 30) {
		if      ($prev_street_info->[&StrassenNetz::ROUTE_DIR] eq 'l') {
		    #$short_dir = '<';
		    $short_dir = "(-";
		} elsif ($prev_street_info->[&StrassenNetz::ROUTE_DIR] eq 'r') {
		    #$short_dir = '>';
		    $short_dir = "-)";
		}
	    }

	    # test for simplify_route_to_name output:
	    if (ref $main_street eq 'ARRAY') {
		$main_street = $main_street->[0];
	    }
	    if (ref $prev_street eq 'ARRAY') {
		$prev_street = $prev_street->[-1];
	    }

	    # This condition is hacky: because landstrassen may or may not be
	    # transformed from "A - B" to "(A -) B" or "(B -) A" the
	    # $prev_street vs. $main_street comparison below does not
	    # work. The workaround is to remove the (A -) part. This
	    # would be removed anyway in the short_landstrasse function.
	    if (defined $main_street && $main_street =~ m/\s*\([^\)]+-\)\s*/) { # XXX (... -) ...
		@cross_streets = $main_street;
	    }

	    # no crossing => use at least the current street
	    if (!@cross_streets) {
		@cross_streets = $main_street;
	    }
	    # if the main street is still the same, then use the
	    # "+crossingstreet" syntax
	    # XXX theoretisch kann "+crossingstreet+mainstreet" passieren,
	    # was nicht so schön wäre ... aber dazu müsste crossingstreet
	    # superkurz oder $waypointlength superlang sein
	    # XXX die Abfrage im map scheint teilweise überflüssig zu sein
	    # (main_street eq prev_street!)
	    elsif (defined $prev_street && $prev_street eq $main_street &&
		   @cross_streets > 1) {
		@cross_streets =
		    ("",
		     map  { $_->[0] }
		     sort { $b->[1] <=> $a->[1] }
		     map  { [$_, $_ eq $main_street ? -99 : (defined $prev_street && $_ eq $prev_street ? -100 : 0) ] }
		     @cross_streets);
	    }
	    # Sort the crossing streets so, that the current street
	    # is first and the previous street (if any) is last.
	    else {
		if (defined $prev_street && $prev_street eq $main_street) {
		    undef $prev_street;
		}
		@cross_streets =
		    (map  { $_->[0] }
		     sort { $b->[1] <=> $a->[1] }
		     map  { [$_, $_ eq $main_street ? 100 : (defined $prev_street && $_ eq $prev_street ? -100 : 0) ] }
		     @cross_streets);
	    }
	}

	if (@cross_streets) {
	    # try to shorten street names
            if ($n < $#path) {
	        $cross_streets[0] = Route::Simplify::short_landstrasse($cross_streets[0], $net, $xy_string, join(",",@{ $path[$n+1] }));
	    }
	    my $short_crossing;
	    my $level = 0;
	    while($level <= 3) {
		# XXX the "+" character is not supported by all Garmin devices
		$short_crossing = $short_dir . join("+", map { s/\s+\(.*\)\s*$//; Strasse::short($_, $level, "nodot") } grep { defined } @cross_streets);
		if ($waypointcharset ne 'latin1') {
		    $short_crossing = Route::Simplify::_eliminate_umlauts_and_shorten($short_crossing);
		}
		last
#		    if (length($short_crossing) + length($comment) <= MAX_COMMENT);
		    if (length($short_crossing) + length($comment) <= $waypointlength);
		$level++;
	    }

	    $comment .= $short_crossing;

	    my $short_name;
	    my $suffix_in_use = 0;
	    my $create_short_name = sub {
		my($suffix,$name) = @_;
		$name = substr($name.(" "x $waypointlength), 0, $waypointlength);
		if ($suffix ne "") {
		    substr($name, $waypointlength-length($suffix), length($suffix), $suffix);
		    $suffix_in_use = $suffix;
		} else {
		    $suffix_in_use = "";
		}
		if ($waypointlength eq 'simpleascii') {
		    uc($name); # Garmin etrex venture supports only uppercase chars
		} else {
		    # keep lowercase characters
		    $name;
		}
	    };
	TRY: {
		if ($wptsuffix ne "" && $wptsuffixexisting) {
		    $short_name = $create_short_name->("",$short_crossing);
		    last TRY if (!exists $waypointscache->{$short_name});
		}
		$short_name = $create_short_name->($wptsuffix,$short_crossing);
	    }

	    $ident = $short_name;
	    my $local_ident_counter = ord("0")-1;
	    while (exists $idents{$ident}) { # ||
#		   ($wptsuffixexisting && $wptsuffix ne "" && exists $waypointscache->{$ident})) {
		$local_ident_counter++;
		if ($local_ident_counter > ord("Z")) {
		    last; # give up
		} elsif ($local_ident_counter > ord("9") &&
			 $local_ident_counter < ord("A")) {
		    $local_ident_counter = ord("A");
		}
		substr($ident,$waypointlength-1-length($suffix_in_use),1) = chr($local_ident_counter);
	    }

	    if (length($comment) > MAX_COMMENT) {
		$comment = substr($comment, 0, MAX_COMMENT);
	    }
	}

	if (!defined $ident || $ident =~ /^\s*$/) {
	    if ($n == 0) {
		$ident = "START $routenumber"; # no $wptsuffix needed
	    } elsif ($n == $#path) {
		$ident = "GOAL $routenumber";
	    } else {
		$ident = $wptsuffix."T". ($ident_counter++); # don't bother with wptsuffixexisting here, and with suffix used as a prefix here
	    }
	}

	print STDERR $ident, "\n";
	$idents{$ident}++;
	$waypointscache->{$ident}++;

	my $wpt = {lat => $lat, lon => $lon, ident => $ident,
		   origlon => $xy->[0], origlat => $xy->[1]};
	push @{ $simplified_route->{wpt} }, $wpt;
    } continue {
	$n++;
    }
    
    if (!$routename) {
	if ($routetoname) {
	    $routename = join("-",
			      map {
				  my $street = $routetoname->[$_][&StrassenNetz::ROUTE_NAME];
				  $street = $street->[0] if ref $street eq 'ARRAY';
				  substr(Route::Simplify::_eliminate_umlauts_and_shorten($street), 0, int($routenamelength/2))
			      } (0, -1)
			     );
	} else {
	    my @l = localtime;
	    $l[5]+=1900; $l[4]++;
	    $routename = "Route" . sprintf("%04d%02d%02d",@l[5,4,3]);
	}
    }
    $simplified_route->{routename} = $routename;

    $simplified_route;
}

# ... and more
sub _eliminate_umlauts_and_shorten {
    my $s = shift;
    $s = GPS::Util::eliminate_umlauts($s);
    # And more shortenings:
    $s =~ s/[\(\)]//g;
    $s =~ s/str\./str/g;
    $s =~ s/\./ /g;
    $s;
}

sub short_landstrasse {
    my($s, $net, $xy1, $xy2) = @_;
    $s = Strasse::beautify_landstrasse($s, $net->street_is_backwards($xy1, $xy2));
    $s =~ s/:\s+/ /g;
    $s =~ s/\s*\([^\)]+-\)\s*/-/g;
    $s;
}

1;

__END__
