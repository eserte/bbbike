# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2024 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# WWW:  https://github.com/eserte/bbbike
#

package
    BBBikeTestSamplesKML;

use strict;
use warnings;
our $VERSION = '0.01';

use Exporter 'import';

our @EXPORT = qw(get_sample_kml_1 get_sample_kml_coordinates_1 get_sample_kml_polygons get_sample_kml_multigeometry_linestring get_sample_kml_points get_sample_kml_unknown_placemarks);

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

# These are the bbbike coordinates for get_sample_kml_1()
sub get_sample_kml_coordinates_1 {
    ('5181,12673', '5082,12453', '5173,12408', '13485,23009',
     '13531,23052', '13532,23052', '13563,23059', '13653,23030',
     '13801,22931',
    );
}

sub get_sample_kml_polygons {
    <<'EOF';
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
 xsi:schemaLocation="http://www.opengis.net/kml/2.2 http://schemas.opengis.net/kml/2.2.0/ogckml22.xsd http://www.google.com/kml/ext/2.2 http://code.google.com/apis/kml/schema/kml22gx.xsd">
<Document id="Ortsteile_WGS84">
  <name>Ortsteile_WGS84</name>
    <Placemark id="ID_00000">
      <name>Mitte</name>
      <description><![CDATA[<html><body>description</body></html>]]></description>
      <styleUrl>#PolyStyle00</styleUrl>
      <MultiGeometry>
        <Polygon>
          <extrude>0</extrude><altitudeMode>clampToGround</altitudeMode><tessellate>1</tessellate>
          <outerBoundaryIs><LinearRing><coordinates> 13.373601,52.527913,0.000000 13.373656,52.527918,0.000000 13.373822,52.527718,0.000000 13.373750,52.527632,0.000000</coordinates></LinearRing></outerBoundaryIs>
        </Polygon>
      </MultiGeometry>
    </Placemark>
  <Style id="PolyStyle00">
    <LabelStyle>
      <color>00000000</color>
      <scale>0.000000</scale>
    </LabelStyle>
    <LineStyle>
      <color>ff0000a8</color>
      <width>1.000000</width>
    </LineStyle>
    <PolyStyle>
      <color>00c8d0d4</color>
      <outline>1</outline>
    </PolyStyle>
  </Style>
</Document>
</kml>
EOF
}

sub get_sample_kml_multigeometry_linestring {
    <<'EOF';
<?xml version="1.0" encoding="UTF-8"?> <kml xmlns="http://earth.google.com/kml/2.2"><Document><name>B.iCycle Track from 2009-09-28_16.06.55.kml</name><Style id="roadStyle"><LineStyle><color>F03399FF</color><width>10</width></LineStyle></Style><Placemark><name>Route</name><styleUrl>#roadStyle</styleUrl><MultiGeometry><LineString><coordinates>13.085528,52.412301,0 13.085827,52.412391,0 13.085915,52.412417,0  </coordinates></LineString></MultiGeometry></Placemark></Document></kml>
EOF
}

sub get_sample_kml_points {
    <<'EOF';
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://earth.google.com/kml/2.1">
  <Document>
    <name>BBBike-Route</name>
    <description></description>
    <Style id="style1">
      <LineStyle>
        <color>ff0000ff</color>
        <width>4</width>
      </LineStyle>
      <PolyStyle>
        <color>ff0000ff</color>
      </PolyStyle>
    </Style>
    <Placemark>
      <name>amenity:post_box; collection_times:Mo-Fr 15:00; Sa 12:15; operator:Deutsche Post</name>
      <!-- Center to start -->
      <LookAt>
        <longitude>13.282268</longitude>
        <latitude>52.436952</latitude>
        <range>2000</range>
      </LookAt>
      <Point>
        <coordinates>
13.282268,52.436952
        </coordinates>
      </Point>
    </Placemark>
  </Document>
</kml>
EOF
}

sub get_sample_kml_unknown_placemarks {
    <<'EOF';
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://earth.google.com/kml/2.1">
  <Document>
    <name>BBBike-Route</name>
    <description></description>
    <Placemark><unknown /></Placemark>
    <Placemark><unknown /></Placemark>
    <Placemark><unknown /></Placemark>
    <Placemark><unknown /></Placemark>
  </Document>
</kml>
EOF
}

1;

__END__
