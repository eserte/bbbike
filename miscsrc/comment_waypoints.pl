#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: comment_waypoints.pl,v 1.2 2002/02/05 22:27:24 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven.rezic@berlin.de
# WWW:  http://www.rezic.de/eserte/
#

# given a gpsman waypoint file, comment the waypoints with approximate
# crossing names

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data");
use GPS::GpsmanData;
use Strassen;
use Karte; Karte::preload(qw(Standard Polar));
use locale;

use constant MAX_COMMENT => 45; # XXX don't duplicate
use constant MAX_DIST => 50; # maximum allowed distance in m

my $f = shift or die ".wpt file?";

my $s = new Strassen "strassen";
die if !$s;

my $kr = new Kreuzungen Strassen => $s;

my $prev_street;
my @prev_streets;
my @curr_streets;

my $gps = new GPS::GpsmanData;
$gps->load($f);
$gps->convert_all("DDD");
foreach my $wpt (@{ $gps->Waypoints }) {
    my($x,$y) = $Karte::Polar::obj->map2standard($wpt->Longitude, $wpt->Latitude);
    $wpt->Comment(make_comment($x,$y));
}

$gps->write("/tmp/out.wpt");

sub get_current_street {
    my %streets;
    return if !@prev_streets && !@curr_streets;
    foreach (@prev_streets, @curr_streets) {
	$streets{$_}++;
    }
#use Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->Dumpxs([@prev_streets, @curr_streets, \%streets],[]); # XXX

    my @streets = sort { $streets{$b} <=> $streets{$a} } keys %streets;
    if ($streets{$streets[0]} < 2) {
	warn "Street $streets[0] has only $streets{$streets[0]} references\n";
    }
    if (@streets > 1 && $streets{$streets[0]} == $streets{$streets[1]}) {
	warn "Streets $streets[0] and $streets[1] has same number of references\n";
    }
    $streets[0];
}

sub make_comment {
    my($x,$y) = @_;
    my($nearest) = $kr->nearest($x, $y);
    my $dist = Strassen::Util::strecke_s($nearest, "$x,$y");
    @curr_streets = @{ $kr->get($nearest) };

    my $curr_street = get_current_street();

    if (defined $prev_street) {
	# Sort the crossing streets so, that the current street
	# is first and the previous street (if any) is last.
	@curr_streets =
	    map  { $_->[0] }
	    sort { $b->[1] <=> $a->[1] }
	    map  { [$_, $_ eq $curr_street ? 100 : (defined $prev_street && $_ eq $prev_street ? -100 : 0) ] }
	    @curr_streets;
    }

    # try to shorten street names
    my $short_crossing;
    my $level = 0;
    my @curr_streets2 = @curr_streets;
    while($level <= 3) {
	# XXX the "+" character is not supported by all Garmin devices
	$short_crossing = join(" ", map { s/\s+\(.*\)\s*$//; s/\s*str\.$//i; Strasse::short($_, $level) } @curr_streets2);
	$short_crossing = eliminate_umlauts($short_crossing);
	last
	    if (length($short_crossing) <= MAX_COMMENT);
	$level++;
    }

    @prev_streets = @curr_streets;
    $prev_street = $curr_street;

    ($dist > MAX_DIST ? "XXX " : "") . GPS::GpsmanData::_eliminate_illegal_characters($short_crossing);
}

sub eliminate_umlauts {
    my $s = shift;
    $s =~ s/ä/ae/g;
    $s =~ s/ö/oe/g;
    $s =~ s/ü/ue/g;
    $s =~ s/ß/ss/g;
    $s =~ s/Ä/Ae/g;
    $s =~ s/Ö/Oe/g;
    $s =~ s/Ü/Ue/g;
    $s =~ s/é/e/g;
    $s;
}

__END__
