#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassen-gpx.t,v 1.5 2006/08/29 22:38:31 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/..",
	);
use Data::Dumper;
use File::Temp qw(tempfile);
use Getopt::Long;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip: no Test::More module\n";
	exit;
    }
}

use Route;

my $v;
my @variants = ("XML::LibXML", "XML::Twig");
my $tests_per_variant = 13;
my $bbdfile = "obst";

GetOptions("v" => \$v,
	   "libxml!" => sub {
	       if (!$_[1]) {
		   @variants = grep {!/XML::LibXML/} @variants;
	       }
	   },
	   "twig!" => sub {
	       if (!$_[1]) {
		   @variants = grep {!/XML::Twig/} @variants;
	       }
	   },
	   "long!" => sub {
	       $bbdfile = "strassen";
	   },
	  )
    or die "usage!";

plan tests => 5 + scalar(@variants) * $tests_per_variant;

use_ok("Strassen::GPX");
my $s = Strassen::GPX->new;
isa_ok($s, "Strassen::GPX");
isa_ok($s, "Strassen");

for my $use_xml_module (@variants) {
 SKIP: {
	skip("$use_xml_module variant missing", $tests_per_variant)
	    if !eval qq{ require $use_xml_module; 1 };

	$Strassen::GPX::use_xml_module = $Strassen::GPX::use_xml_module if 0; # peacify -w
	$Strassen::GPX::use_xml_module = $use_xml_module;

	# Track file
	{
	    # Parsing from string
	    my $gpx_sample = gpx_sample_trk();
	    my $s = Strassen::GPX->new;
	    $s->gpxdata2bbd($gpx_sample);
	    $s->init;
	    my $r = $s->next;
	    is($r->[Strassen::NAME()], "0723", "Check name from track - $use_xml_module");
	    is(scalar(@{ $r->[Strassen::COORDS()] }), 2);

	    my $xml_res = $s->bbd2gpx;
	    like($xml_res, qr{^<(\?xml|gpx)}, "Looks like XML");

	    my $s2 = Strassen::GPX->new;
	    $s2->gpxdata2bbd($xml_res);
	    deep_strassen_check($s, $s2, $xml_res);

	    # Parsing from file
	    my($ofh, $ofilename) = tempfile(UNLINK => 1, SUFFIX => ".gpx");
	    print $ofh $gpx_sample;
	    close $ofh;

	    my $s3 = Strassen::GPX->new;
	    $s3->gpx2bbd($ofilename);
	    is_deeply($s->data, $s3->data, "File loading OK");
	}

	# Waypoint file
	{
	    # Parsing from string
	    my $gpx_sample = gpx_sample_wpt();
	    my $s = Strassen::GPX->new;
	    $s->gpxdata2bbd($gpx_sample);
	    $s->init;
	    my $r = $s->next;
	    is($r->[Strassen::NAME()], "011", "Check name from waypoint");
	    is($r->[Strassen::COORDS()][0], "10387,6488");
	    is($s->count, 2);

	    my $xml_res = $s->bbd2gpx;
	    like($xml_res, qr{^<(\?xml|gpx)}, "Looks like XML");

	    my $s2 = Strassen::GPX->new;
	    $s2->gpxdata2bbd($xml_res);
	    deep_strassen_check($s, $s2, $xml_res);

	    # Parsing from file
	    my($ofh, $ofilename) = tempfile(UNLINK => 1, SUFFIX => ".gpx");
	    print $ofh $gpx_sample;
	    close $ofh;

	    my $s3 = Strassen::GPX->new;
	    $s3->gpx2bbd($ofilename);
	    is_deeply($s->data, $s3->data, "File loading OK");
	}

	{
	    my $data_file = "$FindBin::RealBin/../data/$bbdfile";
	    my $s0 = Strassen->new($data_file);
	    my $s = Strassen::GPX->new($s0);
	    isa_ok($s, "Strassen::GPX");
	    my $xml_res = $s->Strassen::GPX::bbd2gpx;
	    like($xml_res, qr{^<(\?xml|gpx)}, "Looks like XML");
	}
    }
}

{
    my($fh,$file) = tempfile(SUFFIX => ".gpx", UNLINK => 1);
    print {$fh} gpx_sample_trk();
    close $fh;

    if ($v) {
	$main::verbose = $main::verbose = 2;
    }
    my $route = Route::load($file, {}, -fuzzy => 1);
    is($route->{Type}, "GPX", "Route recognized as GPX");
    is(scalar(@{$route->{RealCoords}}), 2, "Two coordinates found");
}

sub deep_strassen_check {
    my($s1, $s2, $xml_res) = @_;
    # Do not check coords, because off-by-one meter is expected!
    is_deeply([map({ [$_->[Strassen::NAME()], $_->[Strassen::CAT()]] } $s1->get_all)],
	      [map({ [$_->[Strassen::NAME()], $_->[Strassen::CAT()]] } $s2->get_all)],
	     )
	or diag "XML was $xml_res\nStrassen dumps: " . Dumper([$s->get_all, $s2->get_all]);
}

sub gpx_sample_trk {
    <<'EOF';
<?xml version="1.0" encoding="ISO-8859-1" standalone="yes"?>
<gpx
 version="1.0"
 creator="GPSMan" 
 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
 xmlns="http://www.topografix.com/GPX/1/0"
 xmlns:topografix="http://www.topografix.com/GPX/Private/TopoGrafix/0/2"
 xsi:schemaLocation="http://www.topografix.com/GPX/1/0 http://www.topografix.com/GPX/1/0/gpx.xsd http://www.topografix.com/GPX/Private/TopoGrafix/0/2 http://www.topografix.com/GPX/Private/TopoGrafix/0/2/topografix.xsd">
 <author>an author</author>
 <email>an_email@somewhere</email>
 <url>an_url</url>
 <urlname>a_url_name</urlname>
<time>2006-07-24T19:03:31Z</time>
<trk>
<name>0723</name>
<trkseg>
<trkpt lat="52.5328254327" lon="13.3285581786">
  <ele>24.6510009766</ele>
  <time>2006-07-23T07:14:24Z</time>
</trkpt>
<trkpt lat="52.5330141094" lon="13.3285904489">
  <ele>24.1702880859</ele>
  <time>2006-07-23T07:14:32Z</time>
</trkpt>
</trkseg></trk>
</gpx>
EOF
}

sub gpx_sample_wpt {
    <<'EOF';
<?xml version="1.0" encoding="UTF-8" standalone="no" ?>
<gpx xmlns="http://www.topografix.com/GPX/1/1" creator="MapSource 6.11.1" version="1.1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">

  <metadata>
    <link href="http://www.garmin.com">
      <text>Garmin International</text>
    </link>
    <time>2006-07-25T15:56:32Z</time>
    <bounds maxlat="52.753318" maxlon="13.624997" minlat="52.341700" minlon="13.232372"/>
  </metadata>

  <wpt lat="52.464161" lon="13.402240">
    <ele>38.818604</ele>
    <name>011</name>
    <cmt>17-JUL-06 14:58:30</cmt>
    <desc>17-JUL-06 14:58:30</desc>
    <sym>Residence</sym>
    <extensions>
      <gpxx:WaypointExtension xmlns:gpxx="http://www.garmin.com/xmlschemas/GpxExtensions/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.garmin.com/xmlschemas/GpxExtensions/v3 http://www.garmin.com/xmlschemas/GpxExtensions/v3/GpxExtensionsv3.xsd">
        <gpxx:DisplayMode>SymbolAndName</gpxx:DisplayMode>
      </gpxx:WaypointExtension>
    </extensions>
  </wpt>

  <wpt lat="52.516176" lon="13.281016">
    <ele>38.097656</ele>
    <name>AgentArb</name>
    <cmt>20-JUN-06 13:50:01</cmt>
    <desc>20-JUN-06 13:50:01</desc>
    <sym>Building</sym>
    <extensions>
      <gpxx:WaypointExtension xmlns:gpxx="http://www.garmin.com/xmlschemas/GpxExtensions/v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.garmin.com/xmlschemas/GpxExtensions/v3 http://www.garmin.com/xmlschemas/GpxExtensions/v3/GpxExtensionsv3.xsd">
        <gpxx:DisplayMode>SymbolAndName</gpxx:DisplayMode>
      </gpxx:WaypointExtension>
    </extensions>
  </wpt>
</gpx>
EOF
}

__END__
