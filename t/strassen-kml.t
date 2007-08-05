#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassen-kml.t,v 1.2 2007/08/05 22:21:45 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/..",
	);

use File::Temp qw(tempfile);

use Strassen;
use Strassen::Util qw();

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip: no Test::More module\n";
	exit;
    }
}

plan tests => 8;

use_ok("Strassen::KML");
my $s = Strassen::KML->new;
isa_ok($s, "Strassen::KML");
isa_ok($s, "Strassen");

{
    my($fh,$file) = tempfile(SUFFIX => '.kml',
			     UNLINK => 1);
    print $fh get_sample_kml_1();
    close $fh or die $!;

    my $s = Strassen::KML->new($file);
    isa_ok($s, "Strassen", "File <$file> loaded OK");
    my @data = @{ $s->data };
    is($data[0], "Route\tX 5181,12673 5082,12453 5173,12408 13485,23009 13531,23052 13532,23052 13563,23059 13653,23030 13801,22931\n", "Expected translated coordinates");

    my $kml = $s->bbd2kml;
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

__END__
