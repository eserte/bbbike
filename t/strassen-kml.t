#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassen-kml.t,v 1.11 2008/03/19 23:03:01 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/..",
	 $FindBin::RealBin,
	);

use File::Temp qw(tempfile);

use Strassen;
use Strassen::Util qw();

BEGIN {
    if (!eval q{
	use Test::More;
	use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
	1;
    }) {
	print "1..0 # skip no Test::More and/or Archive::Zip modules\n";
	exit;
    }
}

use BBBikeTest;

plan tests => 24;

use_ok("Strassen::KML")
    or exit 1; # avoid recursive calls to Strassen::new
my $s = Strassen::KML->new;
isa_ok($s, "Strassen::KML");
isa_ok($s, "Strassen");

{
    my($fh,$file) = tempfile(SUFFIX => '.kml',
			     UNLINK => 1);
    print $fh get_sample_kml_1();
    close $fh or die $!;

    my @sample_coords = get_sample_coordinates_1();

    my $s = Strassen::KML->new($file);
    isa_ok($s, "Strassen", "File <$file> loaded OK");
    my @data = @{ $s->data };
    is($data[0], "Route\tX @sample_coords\n", "Expected translated coordinates");

    my $kml = $s->bbd2kml;
    kmllint_string($kml, "bbd2kml produced KML");
    my($fh2,$file2) = tempfile(SUFFIX => '.kml',
			       UNLINK => 1);
    print $fh2 $kml;
    close $fh2 or die $!;

    my $s2 = Strassen::KML->new($file2);
    isa_ok($s2, "Strassen", "Roundtrip: KML loaded OK");

    $s->init;
    my @coords  = @{ $s->next->[Strassen::COORDS] };
    $s2->init;
    my @coords2 = @{ $s2->next->[Strassen::COORDS] };

    is(scalar(@coords2), scalar(@coords), "After roundtrip: Same coordinates length");
    my @errors;
    for my $i (0 .. $#coords) {
	my $delta = Strassen::Util::strecke_s($coords[$i], $coords2[$i]);
	if ($delta > 2) {
	    push @errors, "Unexpected delta <$delta> for <$coords[$i]> <$coords2[$i]>";
	}
    }
    ok(!@errors, "Coordinates within tolerance after roundtrip");

    my $s0 = Strassen->new($file);
    isa_ok($s, "Strassen", ".kml detection in Strassen::Core seems OK");
    is_deeply($s0->data, $s->data, "No difference between Strassen and Strassen::KML loading");
}

{
    my($fh,$file) = tempfile(SUFFIX => '.kml',
			     UNLINK => 1);
    print $fh get_sample_kml_1();
    close $fh or die $!;

    my @sample_coords = get_sample_coordinates_1();

    local $Strassen::KML::TEST_SET_NAMESPACE_DECL_URI_HACK = 1;
    $Strassen::KML::TEST_SET_NAMESPACE_DECL_URI_HACK = $Strassen::KML::TEST_SET_NAMESPACE_DECL_URI_HACK if 0; # cease -w
    my $s = Strassen::KML->new($file);
    isa_ok($s, "Strassen", "File <$file> loaded OK");
    my @data = @{ $s->data };
    is($data[0], "Route\tX @sample_coords\n", "Expected translated coordinates with namespace decl hack");
}

{
    my($tmpfh,$tmpfile) = tempfile(SUFFIX => '.kmz',
				   UNLINK => 1);

    my $kml_string = get_sample_kml_1();
    my @sample_coords = get_sample_coordinates_1();

    my $zip = Archive::Zip->new;
    $zip->addString($kml_string, 'doc.kml');
    unless ($zip->writeToFileNamed($tmpfile) == AZ_OK) {
	die "Can't write to $tmpfile";
    }

    my $s = Strassen::KML->new($tmpfile);
    isa_ok($s, "Strassen", "File <$tmpfile> loaded OK");
    my @data = @{ $s->data };
    is($data[0], "Route\tX @sample_coords\n", "Expected translated coordinates in .kmz file");

    my $s0 = Strassen->new($tmpfile);
    isa_ok($s, "Strassen", ".kmz detection in Strassen::Core seems OK");
    is_deeply($s0->data, $s->data, "No difference between Strassen and Strassen::KML loading");
}

{
    my @sample_coords1 = get_sample_coordinates_1();
    my @sample_coords2 = get_sample_coordinates_2();
    my $s = Strassen->new_from_data("Route1\t#00ff00 @sample_coords1", "Route2\t#0000ff @sample_coords2");
    my $s_kml = Strassen::KML->new($s);
    my $kml_string = $s_kml->bbd2kml;
    kmllint_string($kml_string, "KML OK");
    like($kml_string, qr{<Placemark.*<Placemark}s, "Two routes in KML");
    like($kml_string, qr{<color>00ff00ff}, "Found green color");
    like($kml_string, qr{<color>0000ffff}, "Found blue color");
    like($kml_string, qr{<description>14\.[123]\s+km}, "Found distance of first route");
}

{
    my @sample_coords1 = get_sample_coordinates_1();
    my @sample_coords2 = get_sample_coordinates_2();
    my $s = Strassen->new_from_data(">evil<\t#00ff00 @sample_coords1", "\"characters & ümläüt stuff\t#0000ff @sample_coords2");
    my $s_kml = Strassen::KML->new($s);
    my $kml_string = $s_kml->bbd2kml;
    kmllint_string($kml_string, "KML OK with evil characters");
    like($kml_string, qr{&#\d+;}s, "escaped entities found");
}

sub get_sample_kml_1 {
    <<'EOF';
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://earth.google.com/kml/2.1">
  <Document>
    <name>Paths</name>
    <description>Something</description>
    <Style id="yellowLineGreenPoly">
      <LineStyle>
        <color>ff0000ff</color>
        <width>4</width>
      </LineStyle>
      <PolyStyle>
        <color>ff0000ff</color>
      </PolyStyle>
    </Style>
    <Placemark>
      <name>Tour</name>
      <description>enable/disable</description>
      <styleUrl>#yellowLineGreenPoly</styleUrl> 
      <LineString>
        <extrude>1</extrude>
        <tessellate>1</tessellate>
        <altitudeMode>absolute</altitudeMode>
        <coordinates> 

13.327553,52.520582 13.326041,52.518623 13.32736,52.518206

13.452791,52.612149 13.453488,52.612534 13.453499,52.612534
13.45395,52.612592 13.455269,52.612319 13.457415,52.6114



</coordinates>
      </LineString>
    </Placemark>
  </Document>
</kml>
EOF
}

sub get_sample_coordinates_1 {
    ('5181,12673', '5082,12453', '5173,12408', '13485,23009',
     '13531,23052', '13532,23052', '13563,23059', '13653,23030',
     '13801,22931',
    );
}

sub get_sample_coordinates_2 { # Brandenburger Tor - Alexanderplatz
    ('8515,12242', '8610,12254', '8804,12280', '9028,12307',
     '9141,12320', '9349,12344', '9394,12351', '9476,12359',
     '9603,12372', '9681,12382', '9754,12389', '9782,12393',
     '9853,12402', '9918,12411', '9987,12421', '10025,12428',
     '10083,12442', '10173,12492', '10244,12544', '10300,12587',
     '10352,12627', '10440,12696', '10519,12768', '10699,12929',
     '10740,12960', '10781,13002');
}

__END__
