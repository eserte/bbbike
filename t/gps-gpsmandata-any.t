#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

use FindBin;
use lib ($FindBin::RealBin, "$FindBin::RealBin/lib");

use File::Temp qw(tempfile);

plan tests => 4;

use_ok 'GPS::GpsmanData::Any';

{
    my $gpsman_gpx10_sample_file = <<'EOF';
<?xml version="1.0" encoding="ISO-8859-1" standalone="yes"?>
<gpx
 version="1.0"
 creator="GPSMan" 
 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
 xmlns="http://www.topografix.com/GPX/1/0"
 xmlns:topografix="http://www.topografix.com/GPX/Private/TopoGrafix/0/2"
 xsi:schemaLocation="http://www.topografix.com/GPX/1/0 http://www.topografix.com/GPX/1/0/gpx.xsd http://www.topografix.com/GPX/Private/TopoGrafix/0/2 http://www.topografix.com/GPX/Private/TopoGrafix/0/2/topografix.xsd">
<name>name</name>
<desc>desc</desc>
 <author>an author</author>
 <email>an_email@somewhere</email>
 <url>an_url</url>
 <urlname>a_url_name</urlname>
<time>2011-03-14T20:13:59Z</time>
<keywords>keywords</keywords>
<bounds minlat="0" maxlat="0" minlon="0" maxlon="0" />
<trk>
<name>ACTIVE LOG</name>

 <trkseg>

<trkpt lat="52.5086944444" lon="13.4594166667">
  <ele>89.0593261719</ele>
  <time>2011-03-13T09:19:00Z</time>
</trkpt>
<trkpt lat="52.5088055556" lon="13.4594722222">
  <ele>88.5787353516</ele>
  <time>2011-03-13T09:19:04Z</time>
</trkpt>
</trkseg></trk>
</gpx>
EOF
    my($tmpfh,$tmpfile) = tempfile(SUFFIX => '_gpsmandataany.gpx', UNLINK => 1)
	or die $!;
    print $tmpfh $gpsman_gpx10_sample_file;
    close $tmpfh
	or die $!;

    my $gps = GPS::GpsmanData::Any->load($tmpfile);
    isa_ok $gps, 'GPS::GpsmanMultiData';

    is scalar($gps->flat_track), 2, 'Found two waypoints in first track';
    is(($gps->flat_track)[0]->Latitude, '52.5086944444', 'First latitude as expected');
}


__END__
