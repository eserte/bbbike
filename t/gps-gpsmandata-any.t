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
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 $FindBin::RealBin,
	);

use File::Temp qw(tempfile);

use BBBikeTest qw(eq_or_diff xmllint_string);

plan tests => 51;

use_ok 'GPS::GpsmanData::Any';

require GPS::GpsmanData::TestRoundtrip;

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

    my $tmpfile = _create_temporary_gpx($gpsman_gpx10_sample_file);

    {
	my $gps = GPS::GpsmanData::Any->load($tmpfile);
	isa_ok $gps, 'GPS::GpsmanMultiData';

	is scalar($gps->flat_track), 2, 'Found two waypoints in first track';
	my $wpt = ($gps->flat_track)[0];
	is($wpt->Latitude, '52.5086944444', 'First latitude as expected');
	is($wpt->Comment, '13-Mar-2011 09:19:00', 'Time in Comment field as expected');

	## Roundtrip does not work here: 1.0 vs 1.1, and metadata is
	## handled differently in gpx 1.1
	#ok GPS::GpsmanData::TestRoundtrip::gpx2gpsman2gpx($tmpfile), 'Roundtrip check for gpx 1.0 file';
    }

    {
	my $gps = GPS::GpsmanData::Any->load($tmpfile, timeoffset => -2);
	isa_ok $gps, 'GPS::GpsmanMultiData';

	my $wpt = ($gps->flat_track)[0];
	is($wpt->Comment, '13-Mar-2011 07:19:00', 'Time in Comment field with timeoffset');
    }
}

{
    my $sample_gpx = <<'EOF';
<?xml version="1.0" encoding="UTF-8" standalone="no"?><gpx xmlns="http://www.topografix.com/GPX/1/1" xmlns:gpxx="http://www.garmin.com/xmlschemas/GpxExtensions/v3" xmlns:wptx1="http://www.garmin.com/xmlschemas/WaypointExtension/v1" xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" creator="eTrex 30" version="1.1" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd http://www.garmin.com/xmlschemas/GpxExtensions/v3 http://www8.garmin.com/xmlschemas/GpxExtensionsv3.xsd http://www.garmin.com/xmlschemas/WaypointExtension/v1 http://www8.garmin.com/xmlschemas/WaypointExtensionv1.xsd http://www.garmin.com/xmlschemas/TrackPointExtension/v1 http://www.garmin.com/xmlschemas/TrackPointExtensionv1.xsd"><metadata><link href="http://www.garmin.com"><text>Garmin International</text></link><time>2014-05-23T06:43:11Z</time></metadata><trk><name>2014-05-22 09:25:58 Tag</name><extensions><gpxx:TrackExtension><gpxx:DisplayColor>Black</gpxx:DisplayColor></gpxx:TrackExtension></extensions><trkseg><trkpt lat="52.5096700061" lon="13.4569292888"><ele>81.37</ele><time>2014-05-22T07:25:58Z</time></trkpt><trkpt lat="52.5096870214" lon="13.4569436219"><ele>81.37</ele><time>2014-05-22T07:25:59Z</time></trkpt></trkseg><trkseg><trkpt lat="52.5325743947" lon="13.4091386944"><ele>67.91</ele><time>2014-05-22T15:48:11Z</time></trkpt><trkpt lat="52.5330799911" lon="13.4094979428"><ele>67.91</ele><time>2014-05-22T15:48:12Z</time></trkpt></trkseg></trk></gpx>
EOF

    my $tmpfile = _create_temporary_gpx($sample_gpx);

    {
	my $gps = GPS::GpsmanData::Any->load($tmpfile);
	isa_ok $gps, 'GPS::GpsmanMultiData';

	is scalar(@{ $gps->Chunks }), 2, 'Found two chunks';
	is $gps->Chunks->[0]->IsTrackSegment, 0, 'First chunk is real <trk>';
	is $gps->Chunks->[1]->IsTrackSegment, 1, 'Second chunk is <trkseg>';

	is $gps->Chunks->[0]->TrackAttrs->{'srt:device'}, 'eTrex 30', 'preserve creator into srt:device';

	my $wpt = $gps->Chunks->[0]->Track->[0];
	is $wpt->Comment, '22-May-2014 07:25:58';

	{
	    # Roundtrip check, without gpxx extensions
	    my $gpx2 = $gps->as_gpx(gpxx => 0);
	    xmllint_string($gpx2);

	    # Need to normalize
	    # - header is different (standlone="no", different order of xmlns declarations)
	    # - metadata element missing
	    # - extensions element missing
	    (my $normalized_expected = $sample_gpx) =~ s{^.*?<trk>}{<trk>}s;
	    $normalized_expected =~ s{<extensions>.*?</extensions>}{};
	    (my $normalized_got = $gpx2) =~ s{^.*?<trk>}{<trk>}s;
	    eq_or_diff $normalized_got, $normalized_expected;
	}

	{
	    # Roundtrip check, with gpxx extensions
	    my $gpx2 = $gps->as_gpx; # default is gpxx => 1
	    xmllint_string($gpx2);

	    like $gpx2, qr{creator="eTrex 30"}, 'creator re-created';

	    # Still need to normalize, but without <extensions> now
	    (my $normalized_expected = $sample_gpx) =~ s{^.*?<trk>}{<trk>}s;
	    (my $normalized_got = $gpx2) =~ s{^.*?<trk>}{<trk>}s;
	    eq_or_diff $normalized_got, $normalized_expected;
	}

	ok GPS::GpsmanData::TestRoundtrip::gpx2gpsman2gpx($tmpfile), 'Roundtrip check for gpx 1.1 file';
    }

    {
	my $gps = GPS::GpsmanData::Any->load($tmpfile, timeoffset => 2);
	isa_ok $gps, 'GPS::GpsmanMultiData';

	my $wpt1 = $gps->Chunks->[0]->Track->[0];
	is $wpt1->Comment, '22-May-2014 09:25:58', 'timeoffset test with trk file';

	my $wpt2 = $gps->Chunks->[1]->Track->[0];
	is $wpt2->Comment, '22-May-2014 17:48:11', 'timeoffset test in 2nd chunk';

	ok GPS::GpsmanData::TestRoundtrip::gpx2gpsman2gpx($tmpfile, timeoffset => 2), 'Roundtrip check for trk file with timeoffset';
    }

    {
	my $gps = GPS::GpsmanData::Any->load($tmpfile, timeoffset => 'automatic');
	isa_ok $gps, 'GPS::GpsmanMultiData';

	my $wpt = $gps->Chunks->[0]->Track->[0];
	is $wpt->Comment, '22-May-2014 09:25:58', 'automatic timeoffset test with trk file';

	ok GPS::GpsmanData::TestRoundtrip::gpx2gpsman2gpx($tmpfile, timeoffset => 'automatic'), 'Roundtrip check for trk file with automatic timeoffset selection';
    }
}

{
    my $sample_wpt_gpx = <<'EOF';
<?xml version="1.0" encoding="UTF-8" standalone="no" ?><gpx xmlns="http://www.topografix.com/GPX/1/1" xmlns:gpxx="http://www.garmin.com/xmlschemas/GpxExtensions/v3" xmlns:wptx1="http://www.garmin.com/xmlschemas/WaypointExtension/v1" xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v1" creator="eTrex 30" version="1.1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd http://www.garmin.com/xmlschemas/GpxExtensions/v3 http://www8.garmin.com/xmlschemas/GpxExtensionsv3.xsd http://www.garmin.com/xmlschemas/WaypointExtension/v1 http://www8.garmin.com/xmlschemas/WaypointExtensionv1.xsd http://www.garmin.com/xmlschemas/TrackPointExtension/v1 http://www.garmin.com/xmlschemas/TrackPointExtensionv1.xsd"><metadata><link href="http://www.garmin.com"><text>Garmin International</text></link><time>2014-06-04T07:46:31Z</time></metadata><wpt lat="52.532055" lon="13.384399"><ele>47.636337</ele><time>2014-06-04T07:46:31Z</time><name>218</name><sym>BBBike07</sym></wpt></gpx>
EOF

    my $tmpfile = _create_temporary_gpx($sample_wpt_gpx);

    {
	my $gps = GPS::GpsmanData::Any->load($tmpfile);
	isa_ok $gps, 'GPS::GpsmanMultiData';

	my @chunks = @{ $gps->Chunks };
	is scalar(@chunks), 1, 'got one chunk';
	my @wpts = @{ $chunks[0]->Waypoints };
	is scalar(@wpts), 1, 'got one waypoint';
	my $wpt = $wpts[0];
	isa_ok $wpt, 'GPS::Gpsman::Waypoint';

	is $gps->Chunks->[0]->TrackAttrs->{'srt:device'}, 'eTrex 30', 'preserve creator into srt:device';

	is $wpt->Longitude, 13.384399;
	is $wpt->Latitude, 52.532055;
	is $wpt->Ident, '218';
	is $wpt->Comment, "04-Jun-2014 07:46:31";
	is $wpt->Symbol, 'user:7687';
	is $wpt->Altitude, 47.636337;

	{
	    # Roundtrip check, with gpxx extensions
	    my $gpx2 = $gps->as_gpx; # default is gpxx => 1
	    xmllint_string($gpx2);

	    like $gpx2, qr{creator="eTrex 30"}, 'creator re-created';

	    # Still need to normalize, but without <extensions> now
	    (my $normalized_expected = $sample_wpt_gpx) =~ s{^.*?<wpt}{<wpt}s;
	    (my $normalized_got = $gpx2) =~ s{^.*?<wpt}{<wpt}s;
	    eq_or_diff $normalized_got, $normalized_expected;
	}

	ok GPS::GpsmanData::TestRoundtrip::gpx2gpsman2gpx($tmpfile), 'Roundtrip check for gpx file with waypoint';
    }

    {
	my $gps = GPS::GpsmanData::Any->load($tmpfile, timeoffset => 2);
	isa_ok $gps, 'GPS::GpsmanMultiData';
	my $wpt = $gps->Chunks->[0]->Waypoints->[0];
	isa_ok $wpt, 'GPS::Gpsman::Waypoint';
	is $wpt->Ident, '218'; # just check if we're looking at the expected waypoint
	is $wpt->Comment, "04-Jun-2014 09:46:31", 'timeoffset works';

	ok GPS::GpsmanData::TestRoundtrip::gpx2gpsman2gpx($tmpfile, timeoffset => 2), 'Roundtrip check for wpt file with timeoffset';
    }

    {
	my $gps = GPS::GpsmanData::Any->load($tmpfile, timeoffset => 'automatic');
	isa_ok $gps, 'GPS::GpsmanMultiData';
	my $wpt = $gps->Chunks->[0]->Waypoints->[0];
	isa_ok $wpt, 'GPS::Gpsman::Waypoint';
	is $wpt->Ident, '218'; # just check if we're looking at the expected waypoint
	is $wpt->Comment, "04-Jun-2014 09:46:31", 'timeoffset works with automatic selection';

	ok GPS::GpsmanData::TestRoundtrip::gpx2gpsman2gpx($tmpfile, timeoffset => 'automatic'), 'Roundtrip check for wpt file with automatic timeoffset selection';
    }
}

sub _create_temporary_gpx {
    my $gpx_string = shift;

    my($tmpfh,$tmpfile) = tempfile(SUFFIX => '_gpsmandataany.gpx', UNLINK => 1)
	or die $!;
    print $tmpfh $gpx_string;
    close $tmpfh
	or die $!;

    $tmpfile;
}

__END__
