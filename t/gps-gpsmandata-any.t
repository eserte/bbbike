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
use IO::File qw();

use BBBikeTest qw(eq_or_diff xmllint_string);

plan tests => 101;

use GPS::GpsmanData::Any;

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

	my $gps2 = GPS::GpsmanData::Any->load($tmpfile, debug => 0);
	eq_or_diff $gps2, $gps, 'using debug option should not change anything';

	is scalar($gps->flat_track), 2, 'Found two waypoints in first track';
	my $wpt = ($gps->flat_track)[0];
	is($wpt->Latitude, '52.5086944444', 'First latitude as expected');
	is($wpt->DateTime, '13-Mar-2011 09:19:00', 'Time in Comment field as expected');

	## Roundtrip does not work here: 1.0 vs 1.1, and metadata is
	## handled differently in gpx 1.1
	#ok GPS::GpsmanData::TestRoundtrip::gpx2gpsman2gpx($tmpfile), 'Roundtrip check for gpx 1.0 file';

	my $gps_loadgpx = GPS::GpsmanData::Any->load_gpx($tmpfile);
	eq_or_diff $gps_loadgpx, $gps, 'load_gpx works and returns the same like load';

	my $fh = IO::File->new("$tmpfile", 'r');
	my $gps_fh = GPS::GpsmanData::Any->load_gpx($fh);
	eq_or_diff $gps_fh, $gps, 'loading from a filehandle';

	my $tmpgzfile = _create_temporary_gpx_gz($gpsman_gpx10_sample_file);
	my $gps_gz = GPS::GpsmanData::Any->load("$tmpgzfile");
	eq_or_diff $gps_gz, $gps, 'loading gzipped gpx file';

	my $gps_gz_loadgpx = GPS::GpsmanData::Any->load_gpx("$tmpgzfile");
	eq_or_diff $gps_gz_loadgpx, $gps, 'loading gzipped gpx file using load_gpx';
    }

    {
	my $gps = GPS::GpsmanData::Any->load($tmpfile, timeoffset => -2);
	isa_ok $gps, 'GPS::GpsmanMultiData';

	my $wpt = ($gps->flat_track)[0];
	is($wpt->DateTime, '13-Mar-2011 07:19:00', 'Time in Comment field with timeoffset');
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
	is $wpt->DateTime, '22-May-2014 07:25:58';

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
	is $wpt1->DateTime, '22-May-2014 09:25:58', 'timeoffset test with trk file';

	my $wpt2 = $gps->Chunks->[1]->Track->[0];
	is $wpt2->DateTime, '22-May-2014 17:48:11', 'timeoffset test in 2nd chunk';

	ok GPS::GpsmanData::TestRoundtrip::gpx2gpsman2gpx($tmpfile, timeoffset => 2), 'Roundtrip check for trk file with timeoffset';
    }

    {
	my $gps = GPS::GpsmanData::Any->load($tmpfile, timeoffset => 'automatic');
	isa_ok $gps, 'GPS::GpsmanMultiData';

	my $wpt = $gps->Chunks->[0]->Track->[0];
	is $wpt->DateTime, '22-May-2014 09:25:58', 'automatic timeoffset test with trk file';

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
	is $wpt->DateTime, "04-Jun-2014 07:46:31";
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
	is $wpt->DateTime, "04-Jun-2014 09:46:31", 'timeoffset works';

	ok GPS::GpsmanData::TestRoundtrip::gpx2gpsman2gpx($tmpfile, timeoffset => 2), 'Roundtrip check for wpt file with timeoffset';
    }

    {
	my $gps = GPS::GpsmanData::Any->load($tmpfile, timeoffset => 'automatic');
	isa_ok $gps, 'GPS::GpsmanMultiData';
	my $wpt = $gps->Chunks->[0]->Waypoints->[0];
	isa_ok $wpt, 'GPS::Gpsman::Waypoint';
	is $wpt->Ident, '218'; # just check if we're looking at the expected waypoint
	is $wpt->DateTime, "04-Jun-2014 09:46:31", 'timeoffset works with automatic selection';

	ok GPS::GpsmanData::TestRoundtrip::gpx2gpsman2gpx($tmpfile, timeoffset => 'automatic'), 'Roundtrip check for wpt file with automatic timeoffset selection';
    }
}

{
    my $sample_wpt_gpx = <<'EOF';
<?xml version="1.0" encoding="UTF-8" standalone="no" ?><gpx xmlns="http://www.topografix.com/GPX/1/1" xmlns:gpxx="http://www.garmin.com/xmlschemas/GpxExtensions/v3" xmlns:wptx1="http://www.garmin.com/xmlschemas/WaypointExtension/v1" xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v1" creator="eTrex 30" version="1.1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd http://www.garmin.com/xmlschemas/GpxExtensions/v3 http://www8.garmin.com/xmlschemas/GpxExtensionsv3.xsd http://www.garmin.com/xmlschemas/WaypointExtension/v1 http://www8.garmin.com/xmlschemas/WaypointExtensionv1.xsd http://www.garmin.com/xmlschemas/TrackPointExtension/v1 http://www.garmin.com/xmlschemas/TrackPointExtensionv1.xsd"><metadata><link href="http://www.garmin.com"><text>Garmin International</text></link><time>2014-06-04T07:46:31Z</time></metadata><wpt lat="52.532055" lon="13.384399"><ele>47.636337</ele><time>2014-06-04T07:46:31Z</time><name>218</name><cmt>This is a comment</cmt><sym>Navaid, White/Green</sym></wpt></gpx>
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
	is $wpt->DateTime, "04-Jun-2014 07:46:31";
	is $wpt->Comment, 'This is a comment';
	is $wpt->Symbol, 'buoy_white_green';
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
}

{
    # Two test cases here:
    # * a different gps device (Montana)
    # * newline in <cmt> element (should be removed when converting to gpsman)
    my $sample_wpt_gpx = <<'EOF';
<?xml version="1.0" encoding="UTF-8" standalone="no" ?><gpx xmlns="http://www.topografix.com/GPX/1/1" xmlns:gpxx="http://www.garmin.com/xmlschemas/GpxExtensions/v3" xmlns:wptx1="http://www.garmin.com/xmlschemas/WaypointExtension/v1" xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v1" creator="Montana 650" version="1.1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd http://www.garmin.com/xmlschemas/GpxExtensions/v3 http://www8.garmin.com/xmlschemas/GpxExtensionsv3.xsd http://www.garmin.com/xmlschemas/TrackStatsExtension/v1 http://www8.garmin.com/xmlschemas/TrackStatsExtension.xsd http://www.garmin.com/xmlschemas/WaypointExtension/v1 http://www8.garmin.com/xmlschemas/WaypointExtensionv1.xsd http://www.garmin.com/xmlschemas/TrackPointExtension/v1 http://www.garmin.com/xmlschemas/TrackPointExtens"><metadata><link href="http://www.garmin.com"><text>Garmin International</text></link><time>2015-01-01T00:00:00Z</time></metadata><wpt lat="0.040801" lon="0.073325"><ele>0.175386</ele><time>2015-01-01T00:00:00Z</time><name>230</name><cmt>Vbspfl
gem g u radw</cmt><sym>Golf Course</sym></wpt></gpx>
EOF

    my $tmpfile = _create_temporary_gpx($sample_wpt_gpx);
    {
	my $gps = GPS::GpsmanData::Any->load($tmpfile);
	isa_ok $gps, 'GPS::GpsmanMultiData';

	my $first_chunk = $gps->Chunks->[0];
	is $first_chunk->TrackAttrs->{'srt:device'}, 'Montana 650', 'preserve creator into srt:device';

	my $first_wpt = $first_chunk->Waypoints->[0];
	is $first_wpt->Comment, q{Vbspfl gem g u radw}, 'newline converted to space';

	ok GPS::GpsmanData::TestRoundtrip::gpx2gpsman2gpx($tmpfile), 'Roundtrip check for gpx file';
    }
}

{
    # Test case here:
    # * <trk><number> (should be removed when coverting to gpsman)
    my $sample_trk_gpx = <<'EOF';
<?xml version="1.0" encoding="UTF-8"?>
<gpx xmlns="http://www.topografix.com/GPX/1/1" xmlns:gpxx="http://www.garmin.com/xmlschemas/GpxExtensions/v3" xmlns:gpxtrkx="http://www.garmin.com/xmlschemas/TrackStatsExtension/v1" xmlns:wptx1="http://www.garmin.com/xmlschemas/WaypointExtension/v1" xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v1" creator="Montana 650" version="1.1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd http://www.garmin.com/xmlschemas/GpxExtensions/v3 http://www8.garmin.com/xmlschemas/GpxExtensionsv3.xsd http://www.garmin.com/xmlschemas/TrackStatsExtension/v1 http://www8.garmin.com/xmlschemas/TrackStatsExtension.xsd http://www.garmin.com/xmlschemas/WaypointExtension/v1 http://www8.garmin.com/xmlschemas/WaypointExtensionv1.xsd http://www.garmin.com/xmlschemas/TrackPointExtension/v1 http://www.garmin.com/xmlschemas/TrackPointExtens">
        <metadata>
                <name>2016-01-01</name>
                <desc>Export from GpsPrune</desc>
        </metadata>
        <trk>
                <name>2016-01-01</name>
                <number>1</number>
                <trkseg>
<trkpt lat="0.0494003553" lon="0.0092164190"><ele>0.74</ele><time>2016-01-01T09:54:03Z</time></trkpt>
                </trkseg>
        </trk>
</gpx>
EOF

    my $tmpfile = _create_temporary_gpx($sample_trk_gpx);
    {
	my $gps = GPS::GpsmanData::Any->load($tmpfile);
	isa_ok $gps, 'GPS::GpsmanMultiData';

	my $first_chunk = $gps->Chunks->[0];
	is $first_chunk->TrackAttrs->{'srt:device'}, 'Montana 650', 'preserve creator into srt:device';
	is $first_chunk->Name, '2016-01-01', 'name of trk';

	ok GPS::GpsmanData::TestRoundtrip::gpx2gpsman2gpx($tmpfile), 'Roundtrip check for gpx file';
    }
}

{
    # Test case here: negative lon/lat
    my $sample_wpt_gpx = <<'EOF';
<?xml version="1.0" encoding="UTF-8" standalone="no" ?><gpx xmlns="http://www.topografix.com/GPX/1/1" xmlns:gpxx="http://www.garmin.com/xmlschemas/GpxExtensions/v3" xmlns:wptx1="http://www.garmin.com/xmlschemas/WaypointExtension/v1" xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v1" creator="eTrex 30" version="1.1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd http://www.garmin.com/xmlschemas/GpxExtensions/v3 http://www8.garmin.com/xmlschemas/GpxExtensionsv3.xsd http://www.garmin.com/xmlschemas/WaypointExtension/v1 http://www8.garmin.com/xmlschemas/WaypointExtensionv1.xsd http://www.garmin.com/xmlschemas/TrackPointExtension/v1 http://www.garmin.com/xmlschemas/TrackPointExtensionv1.xsd"><metadata><link href="http://www.garmin.com"><text>Garmin International</text></link><time>2000-01-01T12:34:56Z</time></metadata><wpt lat="-52.450380" lon="-1.726790"><ele>114.034470</ele><time>2000-01-01T13:17:10Z</time><name>225</name><sym>BBBike23</sym></wpt></gpx>
EOF
    my $tmpfile = _create_temporary_gpx($sample_wpt_gpx);
    {
	my $gps = GPS::GpsmanData::Any->load($tmpfile);
	isa_ok $gps, 'GPS::GpsmanMultiData';

	my($wpt) = @{ $gps->Chunks->[0]->Waypoints };
	is $wpt->Longitude, '-1.726790';
	is $wpt->Latitude, '-52.450380';

	ok GPS::GpsmanData::TestRoundtrip::gpx2gpsman2gpx($tmpfile), 'Roundtrip check for gpx file';
    }
}

{
    # Test case here: waypoint with empty cmt tag
    my $sample_wpt_gpx = <<'EOF';
<?xml version="1.0" encoding="UTF-8" standalone="no" ?><gpx xmlns="http://www.topografix.com/GPX/1/1" xmlns:gpxx="http://www.garmin.com/xmlschemas/GpxExtensions/v3" xmlns:wptx1="http://www.garmin.com/xmlschemas/WaypointExtension/v1" xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v1" creator="Montana 650" version="1.1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd http://www.garmin.com/xmlschemas/GpxExtensions/v3 http://www8.garmin.com/xmlschemas/GpxExtensionsv3.xsd http://www.garmin.com/xmlschemas/TrackStatsExtension/v1 http://www8.garmin.com/xmlschemas/TrackStatsExtension.xsd http://www.garmin.com/xmlschemas/WaypointExtension/v1 http://www8.garmin.com/xmlschemas/WaypointExtensionv1.xsd http://www.garmin.com/xmlschemas/TrackPointExtension/v1 http://www.garmin.com/xmlschemas/TrackPointExtens"><metadata><link href="http://www.garmin.com"><text>Garmin International</text></link><time>2015-01-01T00:00:00Z</time></metadata><wpt lat="0.040801" lon="0.073325"><ele>0.175386</ele><time>2015-01-01T00:00:00Z</time><name>230</name><cmt/><sym>Golf Course</sym></wpt></gpx>
EOF
    my $tmpfile = _create_temporary_gpx($sample_wpt_gpx);
    {
	my $gps = GPS::GpsmanData::Any->load($tmpfile);
	isa_ok $gps, 'GPS::GpsmanMultiData';
	ok GPS::GpsmanData::TestRoundtrip::gpx2gpsman2gpx($tmpfile), 'Roundtrip check for gpx file';
    }
}

{
    # Test case here: with <trk><type> and <desc> containing device
    my $sample_trk_gpx = <<'EOF';
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="fit2gpx by Matjaz Rihtar" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd http://www.garmin.com/xmlschemas/GpxExtensions/v3 http://www.garmin.com/xmlschemas/GpxExtensionsv3.xsd http://www.garmin.com/xmlschemas/TrackPointExtension/v1 http://www.garmin.com/xmlschemas/TrackPointExtensionv1.xsd http://www.garmin.com/xmlschemas/WaypointExtension/v1 http://www.garmin.com/xmlschemas/WaypointExtensionv1.xsd http://www.cluetrust.com/XML/GPXDATA/1/0 http://www.cluetrust.com/Schemas/gpxdata10.xsd" xmlns="http://www.topografix.com/GPX/1/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:gpxx="http://www.garmin.com/xmlschemas/GpxExtensions/v3" xmlns:gpxtrx="http://www.garmin.com/xmlschemas/GpxExtensions/v3" xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v1" xmlns:gpxwpx="http://www.garmin.com/xmlschemas/WaypointExtension/v1" xmlns:gpxdata="http://www.cluetrust.com/XML/GPXDATA/1/0">
    <metadata>
        <name>Track 02-Jan-21 12:08</name>
        <desc>Walking (generic) recorded on Garmin Fenix5_plus</desc>
        <author>
                <name>John Smith</name>
        </author>
        <link href="http://acme.com/fit2gpx.pl">
                <text>fit2gpx by Matjaz Rihtar</text>
        </link>
        <time>2021-01-02T11:08:29Z</time>
    </metadata>
    <trk>
        <name>Track 02-Jan-21 12:08</name>
        <desc>Walking (generic) recorded on Garmin Fenix5_plus</desc>
        <type>__TYPE__</type>
        <trkseg>
            <trkpt lat="12.34567" lon="12.34567">
                <ele>-29.4</ele>
                <time>2021-01-02T11:09:05Z</time>
                <extensions>
                    <gpxtpx:TrackPointExtension>
                        <gpxtpx:hr>111</gpxtpx:hr>
                        <gpxtpx:cad>56</gpxtpx:cad>
                        <gpxtpx:atemp>28</gpxtpx:atemp>
                    </gpxtpx:TrackPointExtension>
                </extensions>
            </trkpt>
        </trkseg>
    </trk>
</gpx>
EOF

    my $expected_gpsman = <<'EOF';
!Format: DDD 0 WGS 84
!Creation: no

!T:	Track 02-Jan-21 12:08
	02-Jan-2021 11:09:05	N12.34567	E12.34567	-29.4
EOF

    for my $type (qw(Cycling Walking SomethingElse)) {
	my $vehicle = $type eq 'Cycling' ? 'bike' : 'pedes';
	(my $sample_trk_gpx = $sample_trk_gpx) =~ s{__TYPE__}{$type}g;
	my $tmpfile = _create_temporary_gpx($sample_trk_gpx);
	for my $type_to_vehicle (0, 1) {
	    my $gps = GPS::GpsmanData::Any->load($tmpfile, typetovehicle => $type_to_vehicle);
	    isa_ok $gps, 'GPS::GpsmanMultiData';
	    my $gpsman = $gps->as_string;
	    $gpsman =~ s{^% Written by.*\n\n}{};
	    my $expected_gpsman = $expected_gpsman;
	    if ($type_to_vehicle && $type ne 'SomethingElse') {
		$expected_gpsman =~ s{^(!T:.*)}{$1\tsrt:vehicle=$vehicle}m;
	    }
	    eq_or_diff $gpsman, $expected_gpsman, "expected srt:vehicle line for $type=$type, type_to_vehicle=$type_to_vehicle";
	}
    }

    for my $guess_device (0, 1) {
	my $tmpfile = _create_temporary_gpx($sample_trk_gpx);
	my $gps = GPS::GpsmanData::Any->load($tmpfile, guessdevice => $guess_device);
	isa_ok $gps, 'GPS::GpsmanMultiData';
	my $gpsman = $gps->as_string;
	$gpsman =~ s{^% Written by.*\n\n}{};
	my $expected_gpsman = $expected_gpsman;
	if ($guess_device) {
	    $expected_gpsman =~ s{^(!T:.*)}{$1\tsrt:device=Garmin Fenix5_plus}m;
	}
	eq_or_diff $gpsman, $expected_gpsman, "expected " . ($guess_device ? "with" : "without") . " srt:device line";
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

sub _create_temporary_gpx_gz {
    my $gpx_string = shift;

    require Compress::Zlib;

    my($tmpfh,$tmpfile) = tempfile(SUFFIX => '_gpsmandataany.gpx.gz', UNLINK => 1)
	or die $!;
    print $tmpfh Compress::Zlib::memGzip($gpx_string);
    close $tmpfh
	or die $!;

    $tmpfile;
}

__END__
