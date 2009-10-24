# -*- perl -*-

#
# $Id: Simplify.pm,v 1.7 2009/02/12 00:50:17 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2008,2009 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Route::Simplify;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

use GPS::Util qw(eliminate_umlauts);

{
    package Route::Simplify::CompressedWaypoint;
    # left:   room for "<" sign
    # right:  room for ">" sign, typically to the right
    # name:   the waypoint name
    # index:  an index to disambiguate the waypoint name within a session
    # suffix: an addition to disambiguate waypoint names across sessions
    my @name_members = qw(left name index suffix right);
    my @members = (@name_members, qw(waypointcharset waypointlength));
    sub new {
	my $self = bless {}, shift;
	for (@name_members) { $self->{$_} = '' }
	$self;
    }
    sub copy {
	my $self = shift;
	my $copy = bless { %$self }, ref $self;
	$copy;
    }
    for my $member (@members) {
	no strict 'refs';
	*{"set_".$member} = sub { my($self,$val)=@_; $self->{$member} = $val };
    }
    sub fixedlength {
	my $self = shift;
	length($self->{left})
	    + length($self->{suffix})
		+ length($self->{right})
		    + length($self->{index});
    }
    sub freelength {
	my $self = shift;
	$self->{waypointlength} - $self->fixedlength;
    }
    sub shorten {
	my($self, %args) = @_;
	die "Unhandled args: " . join(" ", %args) if %args;
	my $length = $self->{waypointlength};
	my $fixed_length = $self->fixedlength;
	my $name;
	if ($fixed_length + length($self->{name}) < $length) {
	    if ($self->{name} !~ m{^($|\s*)}) { # do not fill empty names, looks ugly...
		$name = $self->{name} . " "x($length - $fixed_length - length($self->{name}));
	    } else {
		$name = $self->{name};
	    }
	} else {
	    $name = substr($self->{name}, 0, $length - $fixed_length);
	}
	    
	$name = $self->{left} . $name . $self->{index} . $self->{suffix} . $self->{right};
	if ($self->{waypointcharset} && $self->{waypointcharset} eq 'simpleascii') {
	    $name = uc($name); # Garmin etrex venture supports only uppercase chars
	}
	$name =~ s{^\s}{.}; # Garmin does not like waypoint names starting with a space
	$name =~ s{\s$}{.}; # ... and ending with a space
	$name;
    }
}


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
    #my $wptsuffixexisting = $args{-wptsuffixexisting} || 0;#XXX no support for this anymore, delete it!
    my $convmeth  = $args{-convmeth} || sub {
	$obj->standard2map(@_);
    };
    my $waypointlength = $args{-waypointlength} || 10;
    my $waypointcharset = $args{-waypointcharset} || 'simpleascii';
    my $waypointscache = $args{-waypointscache} || {};
    my $routenamelength = $args{-routenamelength} || 13;
    my $showcrossings = exists $args{-showcrossings} ? $args{-showcrossings} : 1;

    my %crossings;
    if ($str) {
	%crossings = %{ $str->all_crossings(RetType => 'hash',
					    UseCache => 1) };
    }

    my $now = scalar localtime;
    my $ident_counter = 0;
    my %idents;

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

    my $prev_used_street_name;
    my $n = 0;
    foreach my $xy (@path) {
	my $xy_string = join ",", @$xy;
	my($lon, $lat) = $convmeth->(@$xy); # XXX del: $obj->standard2map(@$xy);

	my $importance = 0;

	#warn "lon=$lon lat=$lat\n";

	# create comment and point number
	my @cross_streets;
	if ($str && exists $crossings{$xy_string}) {

	    @cross_streets = @{ $crossings{$xy_string} };
	}

	my $short_dir_left  = '';
	my $short_dir_right = '';
	my $large_angle = 0;
	if ($obj_type eq 'routetoname') {
	    my $this_street_info = $routetoname->[$n];
	    my $prev_street_info = $routetoname->[$n-1];
	    my $main_street = $this_street_info->[&StrassenNetz::ROUTE_NAME];
	    my $prev_street; $prev_street = $prev_street_info->[&StrassenNetz::ROUTE_NAME] if $n > 0;
	    # The < or > prefix for showing the direction
	    # XXX should use a better "situation_at_point" function
	    if (($prev_street_info->[&StrassenNetz::ROUTE_ANGLE]||0) >= 30) {
		$large_angle = 1;
	    }
	    if ($waypointcharset eq 'latin1' && $large_angle) {
		if      ($prev_street_info->[&StrassenNetz::ROUTE_DIR] eq 'l') {
		    #$short_dir_left = '<'; # unfortunately not supported by Garmin devices :-(
		    $short_dir_left = "(- "; # XXX experiment: add space for legibility
		} elsif ($prev_street_info->[&StrassenNetz::ROUTE_DIR] eq 'r') {
		    #$short_dir_right = '>'; # see above
		    $short_dir_right = " -)"; # XXX experiment: add space for legibility
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

	if (!$showcrossings) {
	TRY: {
		if ($n == $#path) {
		    # Special goal handling: make sure that it has a
		    # always a name, by using a crossing street
		    # instead of the "main" street. Otherwise just
		    # choose "Goal"
		    for my $try (@cross_streets) {
			if ($try && $prev_used_street_name && $prev_used_street_name ne $try) {
			    @cross_streets = ($try);
			    last TRY;
			}
		    }
		    @cross_streets = ('Goal');
		    last TRY;
		} 
		@cross_streets = $cross_streets[0];
	    }
	}

	my $cmptwpt = Route::Simplify::CompressedWaypoint->new;
	$cmptwpt->set_waypointcharset($waypointcharset);
	$cmptwpt->set_waypointlength($waypointlength);
	$cmptwpt->set_left($short_dir_left);
	$cmptwpt->set_right($short_dir_right);

	if (!@cross_streets || (!$showcrossings && ($cross_streets[0] eq '' || ($prev_used_street_name && $prev_used_street_name eq $cross_streets[0])))) {
	    $cmptwpt->set_name('');
	    $importance = -1;
	} else {
	    $prev_used_street_name = $cross_streets[0];
	    $importance = +1 if $large_angle;
	    # try to shorten street names
	    if ($n < $#path) {
		$cross_streets[0] = Route::Simplify::short_landstrasse($cross_streets[0], $net, $xy_string, join(",",@{ $path[$n+1] }));
	    }
	    my $short_crossing;
	    my $level = 0;
	    while($level <= 3) {
		# XXX the "+" character is not supported by all Garmin devices
		$short_crossing = join("+", map { s/\s+\(.*\)\s*$//; Strasse::short($_, $level, "nodot") } grep { defined } @cross_streets);
		if ($waypointcharset ne 'latin1') {
		    $short_crossing = Route::Simplify::_eliminate_umlauts_and_shorten($short_crossing);
		}
		$cmptwpt->set_name($short_crossing);
		last
		    if (length($short_dir_left) + length($short_crossing) + length($short_dir_right) <= $waypointlength);
		$level++;
	    }
	}

	if ($wptsuffix ne '') {
	    $cmptwpt->set_suffix($wptsuffix);
	}

	my $ident = $cmptwpt->shorten;
	if ($ident =~ m{^\s*$} # it seems that Garmin does not like waypoint names with just spaces
	    || exists $idents{$ident} || exists $waypointscache->{$ident}) {
	TRY: {
		if ($waypointcharset ne 'simpleascii') {
		    my $local_ident_counter = 1;
		    my @sets = ([split //, ' .'],
				[split //, ' .,:;'], # just in case
			       );
		    for my $set (@sets) {
			while(1) {
			    my $index = _basify_number(++$local_ident_counter, $set);
			    last if length($index) > $cmptwpt->freelength; # XXX -> move into a constant? make dependent on waypointlength-fixedlength?
			    $cmptwpt->set_index($index);
			    $ident = $cmptwpt->shorten;
			    last TRY if (!exists $idents{$ident} && !exists $waypointscache->{$ident});
			}
		    }
		}

		my $local_ident_counter = ord("0")-1;
		while (1) {
		    $local_ident_counter++;
		    if ($local_ident_counter > ord("Z")) {
			last; # give up
		    } elsif ($local_ident_counter > ord("9") &&
			     $local_ident_counter < ord("A")) {
			$local_ident_counter = ord("A");
		    }
		    $cmptwpt->set_index($local_ident_counter);
		    $ident = $cmptwpt->shorten;
		    last TRY if (!exists $idents{$ident} && !exists $waypointscache->{$ident});
		}

		warn "Should never happen: cannot disambiguate $ident!";
		$ident = "XXX"; # should never happen
	    }
	}

	print STDERR "|$ident|\n"; #XXX if debug?
	$idents{$ident}++;

	my $wpt = {lat => $lat, lon => $lon,
		   origlon => $xy->[0], origlat => $xy->[1],
		   ident => $ident,
		   importance => $importance,
		  };
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
    $simplified_route->{idents} = \%idents;

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

sub _basify_number {
    my($number, $set_ref) = @_;
    my $s = "";
    while($number) {
	my $rest = $number % (scalar @$set_ref);
	$s = $set_ref->[$rest] . $s;
	$number = int($number/(scalar @$set_ref));
    }
    $s;
}

1;

__END__
