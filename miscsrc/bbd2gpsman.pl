#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbd2gpsman.pl,v 1.6 2008/06/21 16:54:53 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003,2009 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Convert from bbd to gpsman data

# Sample cmdline:
# ./bbd2gpsman.pl -filter nearby=200 -prefix XXX -symbol danger < ~/src/bbbike/data/fragezeichen > /tmp/test.wpt
# or look at the Makefile in ..../src/bbbike/misc

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);
use GPS::GpsmanData;
use Strassen::Core;
use Strassen::Util;
use Getopt::Long;
use Karte;
use Object::Iterate qw(iterate);

Karte::preload(qw(Polar Standard));

my $type_string = "waypoint";
my $prefix = "";
my $prefixmap;
my $match_index = Strassen::CAT;
my $symbol;
my $filter;
my $filter_nearby;
my $wptlen = 14; # XXX configurable!

if (!GetOptions("type=s" => \$type_string,
		"prefix=s" => \$prefix,
		"prefixmap=s" => sub {
		    for my $e (split /,/, $_[1]) {
			my($k,$v) = split /=/, $e, 2;
			$prefixmap->{$k} = $v;
		    }
		},
		"match=s" => sub {
		    if ($_[1] eq 'cat') {
			$match_index = Strassen::CAT;
		    } elsif ($_[1] eq 'name') {
			$match_index = Strassen::NAME;
		    } else {
			die "Invalid parameter for match: must be cat or name";
		    }
		},
		"symbol=s" => \$symbol,
		"filter=s" => \$filter,
	       )) {
    die "usage: $0 [-type type] [-match match]
	[-prefix prefix | -prefixmap expr1=prefix1,expr2=prefix2,...]
	[-symbol symbol] [-filter filter] [file | -]"
}

my $outtype = ($type_string =~ /^(waypoint|wpt)$/
	       ? GPS::GpsmanData::TYPE_WAYPOINT
	       : $type_string =~ /^(track|trk)$/
	       ? GPS::GpsmanData::TYPE_TRACK
	       : die "Unknown type $type_string, should be waypoint or track");

my $file = shift || "-";
if ($file eq '-' && -t STDIN) { warn "Reading from STDIN ...\n" }

my $s = Strassen->new($file);
my $gpsmandata = GPS::GpsmanData->new;
$gpsmandata->Type($outtype);

if ($filter) {
    for (split /,/, $filter) {
	if ($filter =~ /^nearby=(\d+)$/) {
	    $filter_nearby = $1;
	} else {
	    die "Unknown filter $filter";
	}
    }
}

my $inc = 0;
my @wpts;
my %seen;
my($lastx,$lasty);
iterate {
    for my $c (@{ $_->[Strassen::COORDS] }) {
	next if $seen{$c};
	$seen{$c}++;
	my($x,$y) = split /,/, $c;
	if ($filter_nearby && defined $lastx) {
	    next if Strassen::Util::strecke([$x,$y],[$lastx,$lasty]) < $filter_nearby;
	}
	my($long,$lat) = $Karte::Polar::obj->standard2map($x,$y);
	my $wpt = GPS::Gpsman::Waypoint->new;

    TRY_PREFIX: {
	if ($prefixmap) {
	    keys %$prefixmap; # reset iterator
	    while(my($k,$v) = each %$prefixmap) {
		if ($_->[$match_index] =~ /(?i:$k)/) {
		    $wpt->Ident("$prefix$v$inc");
		    last TRY_PREFIX;
		}
	    }
	    $wpt->Ident("$prefix$inc");
	} elsif ($outtype eq GPS::GpsmanData::TYPE_WAYPOINT) {
	    $wpt->Ident(get_ident($_->[Strassen::NAME]));
	}
    }

	$wpt->Comment($_->[Strassen::NAME]);
	$wpt->Latitude($lat);
	$wpt->Longitude($long);
	if (defined $symbol) {
	    $wpt->Symbol($symbol);
	}
	push @wpts, $wpt;
	$inc++;
	($lastx,$lasty) = ($x,$y);
    }
} $s;

if ($outtype eq GPS::GpsmanData::TYPE_TRACK) {
    $gpsmandata->Track(\@wpts);
} else {
    $gpsmandata->Waypoints(\@wpts);
}
$gpsmandata->write("-");

sub get_ident {
    my $name = shift;
    # XXX Hack to protect from non-ascii characters,
    # check what gpsman likes and wants
    if (eval { require Text::Unidecode; 1 }) {
	$name = Text::Unidecode::unidecode($name);
    }
    find_ident($name);
}

{
    my %used_ident;
    sub find_ident {
	my $name = shift;
	$name = substr($name, 0, $wptlen) if length($name) > $wptlen;
	for (1..100) { # recursion breaker
	    if (!$used_ident{$name}) {
		$used_ident{$name} = 1;
		return $name;
	    }
	    $name++;
	}
	undef;
    }
}

__END__
