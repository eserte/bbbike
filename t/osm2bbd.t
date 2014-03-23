#!/usr/bin/perl -w
# -*- mode:cperl; coding:iso-8859-1 -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use File::Temp qw(tempdir tempfile);
use Test::More 'no_plan';

use BBBikeYAML;
use Strassen::Core;

my $osm2bbd = "$FindBin::RealBin/../miscsrc/osm2bbd";

{
    my $destdir = tempdir(CLEANUP => 1);
    my($osmfh,$osmfile) = tempfile(UNLINK => 1, SUFFIX => '_osm2bbd.osm');
    print $osmfh <<'EOF';
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="Overpass API">
<note>The data included in this document is from www.openstreetmap.org. The data is made available under ODbL.</note>
<meta osm_base="2014-03-23T11:14:02Z"/>

  <!-- nodes for Karl-Marx-Allee -->
  <node id="29271394" lat="52.5178395" lon="13.4329187" version="12" timestamp="2012-05-16T22:57:29Z" changeset="11618882" uid="76006" user="Inhiber">
    <tag k="highway" v="traffic_signals"/>
  </node>
  <node id="29271393" lat="52.5174916" lon="13.4364709" version="5" timestamp="2013-05-15T16:31:54Z" changeset="16141106" uid="1439784" user="der-martin"/>

  <!-- nodes for Rudi-Dutschke-Str. -->
  <node id="25663454" lat="52.5067076" lon="13.3905066" version="7" timestamp="2012-07-18T12:30:56Z" changeset="12281912" uid="722137" user="OSMF Redaction Account"/>
  <node id="1814134273" lat="52.5067128" lon="13.3905715" version="2" timestamp="2012-07-05T20:06:34Z" changeset="12124058" uid="125718" user="Fabi2"/>

  <!-- way with cycleway and oneway -->
  <way id="76865761" version="4" timestamp="2013-09-26T03:46:24Z" changeset="18038475" uid="1439784" user="der-martin">
    <nd ref="29271394"/>
    <nd ref="29271393"/>
    <tag k="cycleway" v="track"/>
    <tag k="highway" v="primary"/>
    <tag k="name" v="Karl-Marx-Allee"/>
    <tag k="oneway" v="yes"/>
    <tag k="postal_code" v="10243"/>
    <tag k="ref" v="B 1;B 5"/>
  </way>

 <!-- way with cycleway:left -->
 <way id="4396302" version="15" timestamp="2012-12-02T20:26:29Z" changeset="14130596" uid="111462" user="Posemuckel">
    <nd ref="25663454"/>
    <nd ref="1814134273"/>
    <tag k="cycleway:left" v="share_busway"/>
    <tag k="highway" v="secondary"/>
    <tag k="name" v="Rudi-Dutschke-StraÃŸe"/>
    <tag k="postal_code" v="10969"/>
  </way>

</osm>
EOF
    close $osmfh;

    my @cmd = ($^X, $osm2bbd, "--debug=0", "-f", "-o", $destdir, $osmfile);
    system @cmd;
    is $?, 0, "<@cmd> works";

    my $meta = BBBikeYAML::LoadFile("$destdir/meta.yml");
    is $meta->{source}, 'osm';
    like $meta->{created}, qr{^2\d{7}\d{6}}, 'looks like an ISO date';
    is $meta->{coordsys}, 'wgs84';
    like "@{ $meta->{commandline} }", qr{osm2bbd};

    {
	my $radwege = Strassen->new("$destdir/strassen");
	ok $radwege, 'radwege could be loaded';
	is $radwege->data->[0], "Karl-Marx-Allee (B 1;B 5)\tHH 13.4329187,52.5178395 13.4364709,52.5174916\n";
	is $radwege->data->[1], "Rudi-Dutschke-Straße\tH 13.3905066,52.5067076 13.3905715,52.5067128\n";
    }

    {
	my $radwege = Strassen->new("$destdir/radwege");
	ok $radwege, 'radwege could be loaded';
	is $radwege->data->[0], "Karl-Marx-Allee (B 1;B 5)\tRW1; 13.4329187,52.5178395 13.4364709,52.5174916\n";
	is $radwege->data->[1], "Rudi-Dutschke-Straße\t;RW5 13.3905066,52.5067076 13.3905715,52.5067128\n";
    }

    {
	my $ampeln = Strassen->new("$destdir/ampeln");
	ok $ampeln, 'ampeln could be loaded';
	is $ampeln->data->[0], "\tX 13.4329187,52.5178395\n";
    }

    {
	my $gesperrt = Strassen->new("$destdir/gesperrt");
	ok $gesperrt, 'gesperrt could be loaded';
	is $gesperrt->data->[0], "Karl-Marx-Allee (B 1;B 5)\t1 13.4364709,52.5174916 13.4329187,52.5178395\n";
    }
}

__END__
