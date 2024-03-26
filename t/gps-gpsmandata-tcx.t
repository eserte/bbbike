#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;

BEGIN {
    if (!eval q{
	use Test::More;
	use XML::LibXML;
	1;
    }) {
	print "1..0 # skip no Test::More and/or XML::LibXML modules\n";
	exit;
    }
}

use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 $FindBin::RealBin,
	);

use BBBikeTest qw(eq_or_diff);

plan tests => 9;

use Encode qw(encode_utf8);
use File::Temp qw(tempfile);
use IO::File qw();

use GPS::GpsmanData::Any;
use GPS::GpsmanData::TCX;

{
    my $bom_octets = Encode::encode_utf8("\x{FEFF}");
    my $tcx_sample_file = <<"EOF";
$bom_octets<?xml version="1.0" encoding="UTF-8"?>
<TrainingCenterDatabase schemaLocation="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2 http://www.garmin.com/xmlschemas/TrainingCenterDatabasev2.xsd" xmlns:ns5="http://www.garmin.com/xmlschemas/ActivityGoals/v1" xmlns:ns3="http://www.garmin.com/xmlschemas/ActivityExtension/v2" xmlns:ns2="http://www.garmin.com/xmlschemas/UserProfile/v2" xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <Activities>
    <Activity Sport="Biking">
      <Name>London Ride activity</Name>
      <Id>id007</Id>
      <Lap StartTime="2020-01-01T12:34:56.000Z">
        <TotalTimeSeconds>1234</TotalTimeSeconds>
        <DistanceMeters>1234.56</DistanceMeters>
        <Intensity>Active</Intensity>
        <Track>
          <Trackpoint>
            <Time>2020-01-01T12:34:56.000Z</Time>
            <AltitudeMeters>4.4</AltitudeMeters>
            <DistanceMeters>0</DistanceMeters>
            <Position>
              <LatitudeDegrees>51.5074</LatitudeDegrees>
              <LongitudeDegrees>-0.1278</LongitudeDegrees>
            </Position>
          </Trackpoint>
          <Trackpoint>
            <Time>2020-01-01T12:35:56.000Z</Time>
            <AltitudeMeters>4.6</AltitudeMeters>
            <DistanceMeters>9.670000076293945</DistanceMeters>
            <Position>
              <LatitudeDegrees>51.5075</LatitudeDegrees>
              <LongitudeDegrees>-0.1279</LongitudeDegrees>
            </Position>
          </Trackpoint>
        </Track>
      </Lap>
    </Activity>
  </Activities>
</TrainingCenterDatabase>
EOF

    my $tmpfile = _create_temporary_tcx($tcx_sample_file);

    {
	my $gps = GPS::GpsmanData::Any->load($tmpfile);
	isa_ok $gps, 'GPS::GpsmanMultiData';

	is scalar @{ $gps->Chunks }, 1, 'one chunk detected';
	is($gps->Chunks->[0]->TrackAttrs->{'srt:vehicle'}, 'bike', 'vehicle as expected');

	is scalar($gps->flat_track), 2, 'Found two waypoints in first track';
	my $wpt = ($gps->flat_track)[0];
	is($wpt->Latitude, '51.5074', 'First latitude as expected');
	is($wpt->Longitude, '-0.1278', 'First longitude as expected');
	is($wpt->DateTime, '01-Jan-2020 12:34:56', 'Time in Comment field as expected');

	my $gps_loadtcx = GPS::GpsmanData::TCX->load_tcx($tmpfile);
	eq_or_diff $gps_loadtcx, $gps, 'load_tcx works and returns the same like load';

	my $fh = IO::File->new("$tmpfile", 'r');
	my $gps_fh = GPS::GpsmanData::TCX->load_tcx($fh);
	eq_or_diff $gps_fh, $gps, 'loading from a filehandle';
    }
}

sub _create_temporary_tcx {
    my $tcx_string = shift;

    my($tmpfh,$tmpfile) = tempfile(SUFFIX => '_gpsmandatatcx.tcx', UNLINK => 1)
	or die $!;
    print $tmpfh $tcx_string;
    close $tmpfh
	or die $!;

    $tmpfile;
}

__END__
