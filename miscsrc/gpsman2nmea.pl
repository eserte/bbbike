#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: gpsman2nmea.pl,v 1.2 2009/03/07 08:20:36 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2009 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib "$FindBin::RealBin/..";

use GPS::GpsmanData::Any;

my $gps = GPS::GpsmanData::Any->load(shift);
for my $chunk (@{ $gps->Chunks }) {
    for my $wpt (@{ $chunk->Points }) {
	my $lon = $wpt->Longitude;
	my $lon_sgn = $lon < 0 ? 'W' : 'E';
	$lon = abs $lon;
	my($lon_d, $lon_m) = $lon =~ m{^(\d+)\.(\d+)};
	$lon_m = "0.".$lon_m;
	$lon_m*=60;
	my $lon_dmm = sprintf "%03d%07.4f", $lon_d, $lon_m;

	my $lat = $wpt->Latitude;
	my $lat_sgn = $lat < 0 ? 'S' : 'N';
	$lat = abs $lat;
	my($lat_d, $lat_m) = $lat =~ m{^(\d+)\.(\d+)};
	$lat_m = "0.".$lat_m;
	$lat_m*=60;
	my $lat_dmm = sprintf "%02d%07.4f", $lat_d, $lat_m;

	my $nmea_line = '$GPRMC,000000,A,' . "$lat_dmm,$lat_sgn,$lon_dmm,$lon_sgn,0.0,0.0,010109,1.8,E,A";
	$nmea_line .= '*'.checksum($nmea_line);
	print $nmea_line, "\n";
    }
}

# from GPS::NMEA
sub checksum {
    my ($line) = @_;
    my $csum = 0;
    $csum ^= unpack("C",(substr($line,$_,1))) for(1..length($line)-1);
    return (sprintf("%2.2X",$csum));
}

__END__

=pod

     ./miscsrc/gpsman2nmea.pl gpsmantrack | gpsfake -c 1 /dev/stdin

=cut
