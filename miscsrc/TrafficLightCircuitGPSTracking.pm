# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2010 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package TrafficLightCircuitGPSTracking;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use Tie::File;

sub gpsman2ampelschaltung_string {
    my($gps, $info) = @_;
    my $res;
    $res .= "#WPTFILE: " . $gps->File . "\n";

    $res .= <<EOF;
# Punkt       Kreuzung                           Dir    Zyk grün      rot
#
----------------------------------------------------------------------------
EOF

    my $date = $gps->Waypoints->[0]->Comment_to_unixtime($gps);
    my(undef,undef,undef,$day,$month,$year,$wkday) = localtime $date;
    $month++;
    $year+=1900;
    my $wkday_german = wkday_to_german($wkday);
    my $formatted_date = sprintf "%s, %02d.%02d.%04d", $wkday_german, $day, $month, $year;
    $info->{formatted_date} = $formatted_date if $info;
    $res .= $formatted_date . "\n";

    for my $wpt (@{ $gps->Waypoints }) {
	$res .= "#WPT: " . join("\t", $wpt->Ident, $wpt->Comment, $wpt->Latitude, $wpt->Longitude, $wpt->Symbol) . "\n";
    }
    $res;
}

# Returns filehandle with file offset set to line after date, or undef
# Dies if ampelschaltung-orig.txt cannot be found.
sub find_date_in_ampelschaltung {
    my $date = shift;
    my $file = ampelschaltung_filename();
    open my $fh, $file
	or die "Can't open $file: $!";
    while(<$fh>) {
	chomp;
	if ($_ eq $date) {
	    return $fh;
	}
    }
    undef;
}

sub inject {
    my($res) = @_;
    my $file = ampelschaltung_filename();
    tie my @lines, 'Tie::File', $file
	or die "Can't tie $file: $!";
    for(my $line_i = $#lines; $line_i >= 0; $line_i--) {
	if ($lines[$line_i] =~ m{^# Anmerkungen:$}) {
	    splice @lines, $line_i, 0, $res, "\n";
	    return 1;
	}
    }
    die "Can't find 'Anmerkungen' marker in " . $file;
}

sub ampelschaltung_filename {
    require BBBikeUtil;
    BBBikeUtil::bbbike_root() . "/misc/ampelschaltung-orig.txt";
}

sub wkday_to_german {
    my($wkday_num) = @_;
    [qw(So Mo Di Mi Do Fr Sa)]->[$wkday_num];
}

return 1 if caller;

######################################################################
# Script usage
require FindBin;
require Getopt::Long;
push @INC, "$FindBin::RealBin/..";
require GPS::GpsmanData;

sub usage (;$) {
    my $msg = shift;
    warn $msg, "\n" if $msg;
    die <<EOF;
usage: $^X $0 [-force] dump|inject gpsfile
EOF
}

my $force;
Getopt::Long::GetOptions("force" => \$force)
    or usage;
my $action = shift or usage "Please specify action: dump or inject";
my $file   = shift or usage "Please specify gpsmap waypoint file";
my $gps = GPS::GpsmanData->new;
$gps->load($file);
my $info = {};
my $res = gpsman2ampelschaltung_string($gps, $info);
if ($action eq 'dump') {
    print $res;
} elsif ($action eq 'inject') {
    $info->{formatted_date} or die "Strange: did not get formatted date?!";
    if (!$force && find_date_in_ampelschaltung($info->{formatted_date})) {
	die "Data for date '$info->{formatted_date}' seems to exist already. Force operation with --force.\n";
    }
    inject($res);
} else {
    usage "Invalid action '$action', please specify either dump or inject";
}

1;

__END__
