#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassen-gpx.t,v 1.9 2007/07/20 20:14:06 eserte Exp $
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
my $tests_per_variant = 23;
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

plan tests => 6 + scalar(@variants) * $tests_per_variant;

use_ok("Strassen::GPX");
my $s = Strassen::GPX->new;
isa_ok($s, "Strassen::GPX");
isa_ok($s, "Strassen");

my %parsed_rte;
my $do_not_compare_variants = 0;

for my $use_xml_module (@variants) {
 SKIP: {
	$do_not_compare_variants = 1,
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
	    is_deeply($s3->data, $s->data, "File loading OK");

	    # Parsing from string, overriding name and cat
	    my $s4 = Strassen::GPX->new;
	    $s4->gpxdata2bbd($gpx_sample, name => "My Name", cat => "MYCAT");
	    $s4->init;
	    my $r4 = $s4->next;
	    is($r4->[Strassen::NAME()], "My Name", "Check overridden name");
	    is($r4->[Strassen::CAT()], "MYCAT", "Check overriden category");

	    # Parsing from file, overriding name and cat
	    my $s5 = Strassen::GPX->new;
	    $s5->gpx2bbd($ofilename, name => "My Name", cat => "MYCAT");
	    is_deeply($s5->data, $s4->data, "Check overriden data in files");
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

	    # Parsing from string, overriding name and cat
	    my $s4 = Strassen::GPX->new;
	    $s4->gpxdata2bbd($gpx_sample, name => "My Name", cat => "MYCAT");
	    $s4->init;
	    my $r4 = $s4->next;
	    is($r4->[Strassen::NAME()], "My Name", "Check overridden name");
	    is($r4->[Strassen::CAT()], "MYCAT", "Check overriden category");

	    # Parsing from file, overriding name and cat
	    my $s5 = Strassen::GPX->new;
	    $s5->gpx2bbd($ofilename, name => "My Name", cat => "MYCAT");
	    is_deeply($s5->data, $s4->data, "Check overriden data in files");
	}

	# Rte file
	{
	    my $gpx_sample = gpx_sample_rte();
	    my $s = Strassen::GPX->new;
	    $s->gpxdata2bbd($gpx_sample);
	    cmp_ok($s->count, ">=", 10, "A lot of data found in route file");

	    $parsed_rte{$use_xml_module} = $s->as_string;
	}

	{
	    my $data_file = "$FindBin::RealBin/../data/$bbdfile";
	    my $s0 = Strassen->new($data_file);
	    my $s = Strassen::GPX->new($s0);
	    isa_ok($s, "Strassen::GPX");
	    my $xml_res = $s->Strassen::GPX::bbd2gpx;
	    like($xml_res, qr{^<(\?xml|gpx)}, "Looks like XML");
	}

	# Problematic file
	{
	    # Parsing from string
	    my $gpx_sample = problematic_gpx();
	    my $s = Strassen::GPX->new;
	    $s->gpxdata2bbd($gpx_sample);
	    is($s->count, 2, "Ignored first (empty) entry");
	    $s->init; $s->next;
	    my $rec = $s->next;
	    unlike($rec->[Strassen::NAME()], qr{\n}, "No newline in name");
	    is(scalar(@{ $rec->[Strassen::COORDS()] }), 1, "Found a coord in second record");
	}

    }
}

SKIP: {
    skip("one or more variants not testable, cannot compare variants", 1)
	if $do_not_compare_variants;
    is($parsed_rte{"XML::LibXML"}, $parsed_rte{"XML::Twig"}, "Both variants same result");
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

sub gpx_sample_rte {
    <<'EOF';
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<gpx xmlns="http://www.topografix.com/GPX/1/1" creator="GPS TrackMaker" version="1.1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1
http://www.topografix.com/GPX/1/1/gpx.xsd"><metadata><link href="http://www.gpstm.com"><text>Geo Studio Tecnology Ltd</text></link><time>2006-09-04T22:56:11Z</time><bounds minlat="52.386254" minlon="13.090528" maxlat="52.392324" maxlon="13.122877"/></metadata><wpt lat="52.392098000" lon="13.103797000"><ele>0.000000</ele><name>Ampel</name><cmt>Ampel</cmt><desc>Ampel</desc><sym>Danger Area</sym></wpt><rte><name>Althoffstr. (A)</name><rtept lat="52.389263000" lon="13.099393000"><ele>0.000000</ele><name>R1-1</name><cmt>R1-1</cmt><desc>R1-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.389430000" lon="13.100719000"><ele>0.000000</ele><name>R1-2</name><cmt>R1-2</cmt><desc>R1-2</desc><sym>Waypoint</sym></rtept><rtept lat="52.389430000" lon="13.100719000"><ele>0.000000</ele><name>R1-3</name><cmt>R1-3</cmt><desc>R1-3</desc><sym>Waypoint</sym></rtept></rte><rte><name>Heide (leicht Kopf)</name><rtept lat="52.389603000" lon="13.101458000"><ele>0.000000</ele><name>R2-1</name><cmt>R2-1</cmt><desc>R2-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.388971000" lon="13.101809000"><ele>0.000000</ele><name>R2-2</name><cmt>R2-2</cmt><desc>R2-2</desc><sym>Waypoint</sym></rtept><rtept lat="52.388470000" lon="13.102458000"><ele>0.000000</ele><name>R2-3</name><cmt>R2-3</cmt><desc>R2-3</desc><sym>Waypoint</sym></rtept><rtept lat="52.388195000" lon="13.103039000"><ele>0.000000</ele><name>R2-4</name><cmt>R2-4</cmt><desc>R2-4</desc><sym>Waypoint</sym></rtept><rtept lat="52.388007000" lon="13.103915000"><ele>0.000000</ele><name>R2-5</name><cmt>R2-5</cmt><desc>R2-5</desc><sym>Waypoint</sym></rtept><rtept lat="52.388007000" lon="13.103915000"><ele>0.000000</ele><name>R2-6</name><cmt>R2-6</cmt><desc>R2-6</desc><sym>Waypoint</sym></rtept></rte><rte><name>Blumenweg (A)</name><rtept lat="52.387384000" lon="13.108086000"><ele>0.000000</ele><name>R3-1</name><cmt>R3-1</cmt><desc>R3-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.390022000" lon="13.109474000"><ele>0.000000</ele><name>R3-2</name><cmt>R3-2</cmt><desc>R3-2</desc><sym>Waypoint</sym></rtept><rtept lat="52.389977000" lon="13.109473000"><ele>0.000000</ele><name>R3-3</name><cmt>R3-3</cmt><desc>R3-3</desc><sym>Waypoint</sym></rtept><rtept lat="52.389977000" lon="13.109546000"><ele>0.000000</ele><name>R3-4</name><cmt>R3-4</cmt><desc>R3-4</desc><sym>Waypoint</sym></rtept></rte><rte><name>Paul-N. (A)</name><rtept lat="52.387479000" lon="13.107501000"><ele>0.000000</ele><name>R4-1</name><cmt>R4-1</cmt><desc>R4-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.386254000" lon="13.113566000"><ele>0.000000</ele><name>R4-2</name><cmt>R4-2</cmt><desc>R4-2</desc><sym>Waypoint</sym></rtept><rtept lat="52.386254000" lon="13.113566000"><ele>0.000000</ele><name>R4-3</name><cmt>R4-3</cmt><desc>R4-3</desc><sym>Waypoint</sym></rtept></rte><rte><name>Paul-N.(leicht Kopf)</name><rtept lat="52.389880000" lon="13.105431000"><ele>0.000000</ele><name>R5-1</name><cmt>R5-1</cmt><desc>R5-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.387479000" lon="13.107501000"><ele>0.000000</ele><name>R5-2</name><cmt>R5-2</cmt><desc>R5-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Althoffstr (A)</name><rtept lat="52.389429000" lon="13.100793000"><ele>0.000000</ele><name>R6-1</name><cmt>R6-1</cmt><desc>R6-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.389654000" lon="13.100798000"><ele>0.000000</ele><name>R6-2</name><cmt>R6-2</cmt><desc>R6-2</desc><sym>Waypoint</sym></rtept><rtept lat="52.390158000" lon="13.104630000"><ele>0.000000</ele><name>R6-3</name><cmt>R6-3</cmt><desc>R6-3</desc><sym>Waypoint</sym></rtept></rte><rte><name>Heide (A)</name><rtept lat="52.387960000" lon="13.104135000"><ele>0.000000</ele><name>R7-1</name><cmt>R7-1</cmt><desc>R7-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.387349000" lon="13.107057000"><ele>0.000000</ele><name>R7-2</name><cmt>R7-2</cmt><desc>R7-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Stephen (A)</name><rtept lat="52.390600000" lon="13.100601000"><ele>0.000000</ele><name>R8-1</name><cmt>R8-1</cmt><desc>R8-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.391149096" lon="13.104208058"><ele>0.000000</ele><name>R8-2</name><cmt>R8-2</cmt><desc>R8-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Paul-N. (A)</name><rtept lat="52.391781000" lon="13.104010000"><ele>0.000000</ele><name>R9-1</name><cmt>R9-1</cmt><desc>R9-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.389972000" lon="13.105286000"><ele>0.000000</ele><name>R9-2</name><cmt>R9-2</cmt><desc>R9-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Stephen (leicht Kopf</name><rtept lat="52.390131000" lon="13.097799000"><ele>0.000000</ele><name>R10-1</name><cmt>R10-1</cmt><desc>R10-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.390555000" lon="13.100527000"><ele>0.000000</ele><name>R10-2</name><cmt>R10-2</cmt><desc>R10-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Anhalter (leicht Kop</name><rtept lat="52.391366000" lon="13.100327000"><ele>0.000000</ele><name>R11-1</name><cmt>R11-1</cmt><desc>R11-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.390600000" lon="13.100528000"><ele>0.000000</ele><name>R11-2</name><cmt>R11-2</cmt><desc>R11-2</desc><sym>Waypoint</sym></rtept><rtept lat="52.390600000" lon="13.100528000"><ele>0.000000</ele><name>R11-3</name><cmt>R11-3</cmt><desc>R11-3</desc><sym>Waypoint</sym></rtept></rte><rte><name>Anhalter (A)</name><rtept lat="52.390465000" lon="13.100525000"><ele>0.000000</ele><name>R12-1</name><cmt>R12-1</cmt><desc>R12-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.389699000" lon="13.100799000"><ele>0.000000</ele><name>R12-2</name><cmt>R12-2</cmt><desc>R12-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Paul-N. (leicht Kopf</name><rtept lat="52.391826000" lon="13.104011000"><ele>0.000000</ele><name>R13-1</name><cmt>R13-1</cmt><desc>R13-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.392324000" lon="13.103656000"><ele>0.000000</ele><name>R13-2</name><cmt>R13-2</cmt><desc>R13-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Kopern. (leicht Kopf</name><rtept lat="52.390824000" lon="13.095833000"><ele>0.000000</ele><name>R14-1</name><cmt>R14-1</cmt><desc>R14-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.390593000" lon="13.096488000"><ele>0.000000</ele><name>R14-2</name><cmt>R14-2</cmt><desc>R14-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Kopern (leicht Kopf)</name><rtept lat="52.389355000" lon="13.099102000"><ele>0.000000</ele><name>R15-1</name><cmt>R15-1</cmt><desc>R15-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.389080000" lon="13.099682000"><ele>0.000000</ele><name>R15-2</name><cmt>R15-2</cmt><desc>R15-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Route 16</name><rtept lat="52.389344000" lon="13.095502000"><ele>0.000000</ele><name>R16-1</name><cmt>R16-1</cmt><desc>R16-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.389612000" lon="13.095656000"><ele>0.000000</ele><name>R16-2</name><cmt>R16-2</cmt><desc>R16-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Kopern (Kopf)</name><rtept lat="52.388623000" lon="13.100552000"><ele>0.000000</ele><name>R17-1</name><cmt>R17-1</cmt><desc>R17-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.387248000" lon="13.103382000"><ele>0.000000</ele><name>R17-2</name><cmt>R17-2</cmt><desc>R17-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Watt (Kopf)</name><rtept lat="52.390969000" lon="13.094661000"><ele>0.000000</ele><name>R18-1</name><cmt>R18-1</cmt><desc>R18-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.389182000" lon="13.093589000"><ele>0.000000</ele><name>R18-2</name><cmt>R18-2</cmt><desc>R18-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Benzstr (A)</name><rtept lat="52.391103000" lon="13.094738000"><ele>0.000000</ele><name>R19-1</name><cmt>R19-1</cmt><desc>R19-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.391457000" lon="13.100256000"><ele>0.000000</ele><name>R19-2</name><cmt>R19-2</cmt><desc>R19-2</desc><sym>Waypoint</sym></rtept><rtept lat="52.391874000" lon="13.103718000"><ele>0.000000</ele><name>R19-3</name><cmt>R19-3</cmt><desc>R19-3</desc><sym>Waypoint</sym></rtept><rtept lat="52.391300000" lon="13.112150000"><ele>0.000000</ele><name>R19-4</name><cmt>R19-4</cmt><desc>R19-4</desc><sym>Waypoint</sym></rtept><rtept lat="52.391424000" lon="13.122877000"><ele>0.000000</ele><name>R19-5</name><cmt>R19-5</cmt><desc>R19-5</desc><sym>Waypoint</sym></rtept></rte><rte><name>Schul (A)</name><rtept lat="52.391061000" lon="13.094443000"><ele>0.000000</ele><name>R20-1</name><cmt>R20-1</cmt><desc>R20-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.390154000" lon="13.090528000"><ele>0.000000</ele><name>R20-2</name><cmt>R20-2</cmt><desc>R20-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Route 21</name><rtept lat="52.390641000" lon="13.096122000"><ele>0.000000</ele><name>R21-1</name><cmt>R21-1</cmt><desc>R21-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.389702000" lon="13.095658000"><ele>0.000000</ele><name>R21-2</name><cmt>R21-2</cmt><desc>R21-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Route 22</name><rtept lat="52.389255000" lon="13.095427000"><ele>0.000000</ele><name>R22-1</name><cmt>R22-1</cmt><desc>R22-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.388807000" lon="13.095269000"><ele>0.000000</ele><name>R22-2</name><cmt>R22-2</cmt><desc>R22-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Siemens (Kopf)</name><rtept lat="52.388818000" lon="13.098941000"><ele>0.000000</ele><name>R23-1</name><cmt>R23-1</cmt><desc>R23-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.389432000" lon="13.095725000"><ele>0.000000</ele><name>R23-2</name><cmt>R23-2</cmt><desc>R23-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Siemens (Kopf)</name><rtept lat="52.389481000" lon="13.095285000"><ele>0.000000</ele><name>R24-1</name><cmt>R24-1</cmt><desc>R24-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.389716000" lon="13.094116000"><ele>0.000000</ele><name>R24-2</name><cmt>R24-2</cmt><desc>R24-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Siemens (Kopf)</name><rtept lat="52.389898000" lon="13.093900000"><ele>0.000000</ele><name>R25-1</name><cmt>R25-1</cmt><desc>R25-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.390667000" lon="13.093332000"><ele>0.000000</ele><name>R25-2</name><cmt>R25-2</cmt><desc>R25-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>H.-v.-K (leicht Kopf</name><rtept lat="52.389174000" lon="13.099317000"><ele>0.000000</ele><name>R26-1</name><cmt>R26-1</cmt><desc>R26-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.388101000" lon="13.098703000"><ele>0.000000</ele><name>R26-2</name><cmt>R26-2</cmt><desc>R26-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Kopernikus (A)</name><rtept lat="52.388623000" lon="13.100552000"><ele>0.000000</ele><name>R27-1</name><cmt>R27-1</cmt><desc>R27-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.389035000" lon="13.099755000"><ele>0.000000</ele><name>R27-2</name><cmt>R27-2</cmt><desc>R27-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Kopernikus (A)</name><rtept lat="52.389356000" lon="13.099028000"><ele>0.000000</ele><name>R28-1</name><cmt>R28-1</cmt><desc>R28-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.390041000" lon="13.097797000"><ele>0.000000</ele><name>R28-2</name><cmt>R28-2</cmt><desc>R28-2</desc><sym>Waypoint</sym></rtept><rtept lat="52.390547000" lon="13.096561000"><ele>0.000000</ele><name>R28-3</name><cmt>R28-3</cmt><desc>R28-3</desc><sym>Waypoint</sym></rtept></rte><rte><name>Kopernikus (A)</name><rtept lat="52.390779000" lon="13.095832000"><ele>0.000000</ele><name>R29-1</name><cmt>R29-1</cmt><desc>R29-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.391058000" lon="13.094810000"><ele>0.000000</ele><name>R29-2</name><cmt>R29-2</cmt><desc>R29-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Pestalozzi (A)</name><rtept lat="52.390064000" lon="13.105068000"><ele>0.000000</ele><name>R30-1</name><cmt>R30-1</cmt><desc>R30-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.387201000" lon="13.103675000"><ele>0.000000</ele><name>R30-2</name><cmt>R30-2</cmt><desc>R30-2</desc><sym>Waypoint</sym></rtept></rte><rte><name>Anhalter (leicht Kop</name><rtept lat="52.391952000" lon="13.100121000"><ele>0.000000</ele><name>R31-1</name><cmt>R31-1</cmt><desc>R31-1</desc><sym>Waypoint</sym></rtept><rtept lat="52.391412000" lon="13.100254000"><ele>0.000000</ele><name>R31-2</name><cmt>R31-2</cmt><desc>R31-2</desc><sym>Waypoint</sym></rtept></rte></gpx>
EOF
}

sub problematic_gpx {
    # Newline in first name
    # First track has no coordinates
    <<EOF;
<?xml version="1.0"?>
<gpx
 version="1.0"
creator="GPSBabel - http://www.gpsbabel.org"
xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xmlns="http://www.topografix.com/GPX/1/0"
xsi:schemaLocation="http://www.topografix.com/GPX/1/0 http://www.topografix.com/GPX/1/0/gpx.xsd">
<time>2006-09-12T17:28:57Z</time>
<trk>
  <name>Spreeradweg_sachsen
</name>
<trkseg>
</trkseg>
</trk>
<trk>
  <name>track</name>
<trkseg>
<trkpt lat="51.524421700" lon="14.400062600">
  <ele>112.000000</ele>
<time>2002-06-12T23:00:20Z</time>
</trkpt>
<trkpt lat="51.522651700" lon="14.402491600">
  <ele>112.000000</ele>
<time>2002-06-12T23:00:04Z</time>
</trkpt>
</trkseg>
</trk>
<trk>
  <name>Spreeradweg_sachsen2
</name>
<trkseg>
<trkpt lat="51.524421700" lon="14.400062600">
  <ele>112.000000</ele>
<time>2002-06-12T23:00:20Z</time>
</trkpt>
</trkseg>
</trk>
</gpx>
EOF
}

__END__
