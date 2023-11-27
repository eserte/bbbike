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
	 $FindBin::RealBin,
	);

use File::Temp qw(tempdir tempfile);
use Getopt::Long;
use Test::More 'no_plan';

use BBBikeYAML;
use Geography::FromMeta;
use Strassen::Core;

use BBBikeTest qw(is_number);

sub my_system (@) {
    my(@args) = @_;
    if ($^O eq 'MSWin32') {
	require Win32Util;
	Win32Util::win32_system(@args);
    } else {
	system @args;
    }
}

my $osm2bbd             = "$FindBin::RealBin/../miscsrc/osm2bbd";
my $osm2bbd_postprocess = "$FindBin::RealBin/../miscsrc/osm2bbd-postprocess";

my $keep;
GetOptions("keep" => \$keep)
    or die "usage: $0 [--keep]\n";

{
    my $destdir = tempdir("osm2bbd.t-1-XXXXXXXX", TMPDIR => 1, CLEANUP => $keep ? 0 : 1);
    if ($keep) {
	diag "1st destination directory is: $destdir";
    }
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

  <!-- nodes for Wismarplatz -->
  <node id="27459716" lat="52.5114094" lon="13.4630646" version="6" timestamp="2012-09-03T18:56:16Z" changeset="12971697" uid="209498" user="nurinfo"/>
  <node id="29785833" lat="52.5108136" lon="13.4627415" version="5" timestamp="2010-03-07T15:29:56Z" changeset="4061779" uid="115651" user="Konrad Aust"/>

  <!-- nodes for Wallensteinstraße -->
  <node id="662034255" visible="true" version="4" changeset="15862082" timestamp="2013-04-25T15:29:49Z" user="BenSim" uid="261789" lat="52.4902799" lon="13.5086756"/>
  <node id="1492489247" visible="true" version="2" changeset="35928745" timestamp="2015-12-13T16:20:37Z" user="atpl_pilot" uid="881429" lat="52.4898947" lon="13.5095316"/>

  <!-- nodes for Evangelicky Kristuv kostel -->
  <node id="603020423" visible="true" version="1" changeset="3517189" timestamp="2010-01-02T11:04:47Z" user="Datin" uid="115815" lat="49.8392106" lon="18.2869317"/>
  <node id="603020424" visible="true" version="1" changeset="3517189" timestamp="2010-01-02T11:04:47Z" user="Datin" uid="115815" lat="49.8392232" lon="18.2869912"/>

  <!-- nodes for Columbiadamm -->
  <node id="3612453908" lat="52.4845034" lon="13.3887745" version="1" timestamp="2015-06-23T09:55:04Z" changeset="32157314" uid="120249" user="robson06"/>
  <node id="298080689" lat="52.4843476" lon="13.3887500" version="4" timestamp="2012-11-24T10:15:15Z" changeset="14010259" uid="881429" user="atpl_pilot"/>

  <!-- reduced set of attributes for Berlin -->
  <node id="240109189" visible="true" version="119" changeset="48601888" timestamp="2017-05-11T19:04:44Z" user="kartonage" uid="1497225" lat="52.5170365" lon="13.3888599">
    <tag k="is_in:country_code" v="DE"/>
    <tag k="place" v="city"/>
    <tag k="name" v="Berlin"/>
    <tag k="population" v="3531201"/>
  </node>

  <!-- nodes for Stallschreiberstraße (reduced) -->
  <node id="2453005325" visible="true" version="1" changeset="17769039" timestamp="2013-09-10T15:15:14Z" user="Pholker" uid="13673" lat="52.5069069" lon="13.4069476"/>
  <node id="767501074" visible="true" version="1" changeset="4940461" timestamp="2010-06-08T20:41:02Z" user="wicking" uid="102755" lat="52.5077626" lon="13.4058616"/>

  <!-- nodes for Klappbruecke Tegeler Hafen -->
  <node id="1195371984" visible="true" version="1" changeset="7514472" timestamp="2011-03-10T14:10:24Z" user="Spartanischer Esel" uid="58727" lat="52.5925657" lon="13.2786880" />
  <node id="1195371985" visible="true" version="1" changeset="7514472" timestamp="2011-03-10T14:10:24Z" user="Spartanischer Esel" uid="58727" lat="52.5924815" lon="13.2789366" />
  <node id="2029670964" lat="52.4844998" lon="13.3889022" version="1" timestamp="2012-11-24T10:14:49Z" changeset="14010259" uid="881429" user="atpl_pilot"/>

  <!-- nodes for trunks around Koblenz -->
  <node id="3175668837" visible="true" version="2" changeset="35782978" timestamp="2015-12-06T10:36:27Z" user="kjon" uid="44217" lat="50.3538584" lon="7.6022197"/>
  <node id="2340431463" visible="true" version="2" changeset="26650794" timestamp="2014-11-08T20:34:01Z" user="rab" uid="36894" lat="50.3537927" lon="7.6024921"/>
  <node id="148281369" visible="true" version="6" changeset="26650794" timestamp="2014-11-08T20:34:00Z" user="rab" uid="36894" lat="50.3519688" lon="7.6088753"/>
  <node id="2907318197" visible="true" version="3" changeset="58378636" timestamp="2018-04-24T15:56:47Z" user="primtert" uid="5232758" lat="50.3520816" lon="7.6083146"/>
  <node id="148355093" visible="true" version="7" changeset="66884533" timestamp="2019-02-03T19:27:54Z" user="kreuzschnabel" uid="2773866" lat="50.3463404" lon="7.6354296"/>
  <node id="3294929282" visible="true" version="2" changeset="66884533" timestamp="2019-02-03T19:27:57Z" user="kreuzschnabel" uid="2773866" lat="50.3462314" lon="7.6350669"/>

  <!-- nodes for tourism/hotel -->
  <node id="4037118061" visible="true" version="6" changeset="46140469" timestamp="2017-02-16T15:46:00Z" user="ma-rt-in" uid="1431737" lat="49.9509760" lon="7.1136555"><tag k="addr:city" v="Traben-Trarbach"/><tag k="addr:country" v="DE"/><tag k="addr:housenumber" v="11"/><tag k="addr:postcode" v="56841"/><tag k="addr:street" v="An der Mosel"/><tag k="addr:suburb" v="Traben"/><tag k="beds" v="150"/><tag k="contact:email" v="info@bellevue-hotel.de"/><tag k="contact:fax" v="+49 6541 703400"/><tag k="contact:phone" v="+49 6541 7030"/><tag k="contact:website" v="http://www.bellevue-hotel.de/"/><tag k="internet_access" v="wlan"/><tag k="name" v="Romantik Jugendstilhotel Bellevue"/><tag k="outdoor_seating" v="veranda"/><tag k="rooms" v="68"/><tag k="source" v="http://www.bellevue-hotel.de/"/><tag k="source:date" v="2016-09-01"/><tag k="tourism" v="hotel"/></node>

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
    <tag k="name" v="Rudi-Dutschke-Straße"/>
    <tag k="postal_code" v="10969"/>
  </way>

 <!-- way with oneway:bicycle -->
 <way id="4685868" version="11" timestamp="2014-03-24T12:15:47Z" changeset="21283624" uid="884156" user="DieBuche">
   <nd ref="27459716"/>
   <nd ref="29785833"/>
   <tag k="highway" v="residential"/>
   <tag k="maxspeed" v="30"/>
   <tag k="name" v="Wismarplatz"/>
   <tag k="oneway" v="yes"/>
   <tag k="oneway:bicycle" v="no"/>
   <tag k="postal_code" v="10245"/>
   <tag k="surface" v="cobblestone"/>
 </way>

 <!-- embedded newlines -->
 <way id="47356195" visible="true" version="5" changeset="25521525" timestamp="2014-09-18T14:24:09Z" user="Vladimir Domes" uid="1595880">
  <nd ref="603020423"/>
  <nd ref="603020424"/>
  <tag k="amenity" v="place_of_worship"/>
  <tag k="building" v="church"/>
  <tag k="building:height" v="60"/>
  <tag k="denomination" v="evangelical"/>
  <tag k="name" v="Evangelicky Kristuv kostel"/>
  <tag k="religion" v="christian"/>
  <tag k="start_date" v="1907"/>
  <tag k="wikipedia" v="cs: Evangelicky Kristuv kostel&#10;(Ostrava)"/>
 </way>

 <!-- surface:left/right -->
 <way id="51872061" visible="true" version="25" changeset="51736723" timestamp="2017-09-05T05:25:00Z" user="BER319" uid="3020814">
  <nd ref="662034255"/>
  <nd ref="1492489247"/>
  <tag k="highway" v="residential"/>
  <tag k="name" v="Wallensteinstraße"/>
  <tag k="smoothness:left" v="bad"/><tag k="surface:left" v="cobblestone"/><tag k="surface:right" v="asphalt"/>
 </way>

 <!-- surface=sett -->
 <way id="61502109" visible="true" version="7" changeset="49145142" timestamp="2017-05-31T19:35:43Z" user="RoterEmil" uid="4179530">
  <nd ref="2453005325"/>
  <nd ref="767501074"/>
  <tag k="highway" v="residential"/>
  <tag k="name" v="Stallschreiberstraße"/>
  <tag k="oneway" v="yes"/>
  <tag k="surface" v="sett"/>
 </way>

 <!-- bridge=movable -->
 <way id="103531998" visible="true" version="3" changeset="54813480" timestamp="2017-12-21T12:28:55Z" user="Kivi" uid="120279">
  <nd ref="1195371984"/>
  <nd ref="1195371985"/>
  <tag k="access" v="no"/>
  <tag k="bridge" v="movable"/>
  <tag k="bridge:movable" v="bascule"/>
  <tag k="highway" v="footway"/>
  <tag k="layer" v="1"/>
  <tag k="man_made" v="bridge"/>
  <tag k="name" v="Klappbruecke an der Humboldtmuehle"/>
 </way>

 <!-- check_date & opening_date -->
 <way id="355673416" version="1" timestamp="2015-06-23T09:55:04Z" changeset="32157314" uid="120249" user="robson06">
  <nd ref="3612453908"/>
  <nd ref="298080689"/>
  <tag k="highway" v="secondary"/>
  <tag k="name" v="Columbiadamm"/>
  <tag k="check_date" v="2018-01-01" />
  <tag k="opening_date" v="2999-01-01" />
 </way>
 <way id="318668065" version="2" timestamp="2015-06-23T09:55:12Z" changeset="32157314" uid="120249" user="robson06">
  <nd ref="298080689"/>
  <nd ref="2029670964"/>
  <tag k="highway" v="secondary"/>
  <tag k="name" v="Columbiadamm"/>
  <tag k="opening_date" v="1970-01-01" />
 </way>

 <!-- trunks allowed and disallowed for cyclists -->
 <!-- no motorroad -->
 <way id="311830742" visible="true" version="7" changeset="49435778" timestamp="2017-06-11T07:27:36Z" user="primtert" uid="5232758"><nd ref="3175668837"/><nd ref="2340431463"/><tag k="bicycle" v="official"/><tag k="bridge" v="yes"/><tag k="change:lanes:backward" v="not_left|yes"/><tag k="change:lanes:forward" v="not_left|yes"/><tag k="cycleway" v="track"/><tag k="foot" v="official"/><tag k="highway" v="trunk"/><tag k="lanes" v="4"/><tag k="layer" v="1"/><tag k="maxspeed" v="50"/><tag k="motorroad" v="no"/><tag k="note" v="autobahn\303\244hnlich aber keine KFS daher highway=trunk aber motoroad=no!"/><tag k="ref" v="B 49"/><tag k="surface" v="asphalt"/></way>
 <!-- motorroad and explicit bicycle=no tag -->
 <way id="4759135" visible="true" version="21" changeset="61792903" timestamp="2018-08-19T13:03:25Z" user="krilog" uid="2290088"><nd ref="148281369"/><nd ref="2907318197"/><tag k="bicycle" v="no"/><tag k="bridge" v="yes"/><tag k="change:lanes:backward" v="not_left|yes"/><tag k="change:lanes:forward" v="no|yes"/><tag k="cycleway:both" v="share_sidewalk"/><tag k="footway" v="both|sidewalk"/><tag k="highway" v="trunk"/><tag k="lanes" v="4"/><tag k="lanes:forward" v="2"/><tag k="layer" v="1"/><tag k="maxspeed" v="50"/><tag k="motorroad" v="yes"/><tag k="ref" v="B 49"/><tag k="surface" v="asphalt"/><tag k="turn:lanes:backward" v="through|right"/></way>
 <!-- motorroad without explicit bicycle=no tag -->
 <way id="68744683" visible="true" version="6" changeset="66884533" timestamp="2019-02-03T19:28:01Z" user="kreuzschnabel" uid="2773866"><nd ref="148355093"/><nd ref="3294929282"/><tag k="highway" v="trunk"/><tag k="lanes" v="2"/><tag k="maxspeed" v="100"/><tag k="motorroad" v="yes"/><tag k="oneway" v="yes"/><tag k="ref" v="B 49"/><tag k="surface" v="asphalt"/><tag k="toll:N3" v="yes"/></way>

</osm>
EOF
    close $osmfh;

    my @cmd = ($^X, $osm2bbd, "--debug=0", "-f", "-o", $destdir, $osmfile);
    system @cmd;
    is $?, 0, "<@cmd> works";

    my $meta;
    {
	$meta = BBBikeYAML::LoadFile("$destdir/meta.yml");
	is $meta->{source}, 'osm';
	like $meta->{created}, qr{^2\d{7}\d{6}}, 'looks like an ISO date';
	is $meta->{coordsys}, 'wgs84';
	like "@{ $meta->{commandline} }", qr{osm2bbd};
	is $meta->{country}, 'DE', 'country heuristics';
    }

    {
	my $meta_dd = Geography::FromMeta->load_meta("$destdir/meta.dd");
	is_deeply $meta_dd, $meta, 'meta.dd and meta.yml have the same contents';
    }

    {
	my $strassen = Strassen->new("$destdir/strassen", UseLocalDirectives => 1);
	ok $strassen, 'strassen could be loaded';
	is $strassen->data->[0], "Karl-Marx-Allee\tHH 13.4329187,52.5178395 13.4364709,52.5174916\n";
	is_deeply $strassen->get_directives(0), { alias => ['B 1;B 5'] };
	is $strassen->data->[1], "Rudi-Dutschke-Stra�e\tH 13.3905066,52.5067076 13.3905715,52.5067128\n";
	is $strassen->data->[2], "Wismarplatz\tN 13.4630646,52.5114094 13.4627415,52.5108136\n";
	is $strassen->data->[3], "Wallensteinstra�e\tN 13.5086756,52.4902799 13.5095316,52.4898947\n";
	is $strassen->data->[4], "Stallschreiberstra\x{df}e\tN 13.4069476,52.5069069 13.4058616,52.5077626\n";
	is $strassen->data->[5], "Klappbruecke an der Humboldtmuehle\tNN::Br 13.2786880,52.5925657 13.2789366,52.5924815\n";
	is $strassen->data->[6], "Columbiadamm\tH 13.3887745,52.4845034 13.3887500,52.4843476\n";
	is_deeply $strassen->get_directives(6), { last_checked => ['2018-01-01'], next_check => ['2999-01-01'] };
	is $strassen->data->[7], "Columbiadamm\tH 13.3887500,52.4843476 13.3889022,52.4844998\n";
	is_deeply $strassen->get_directives(7), {}, 'opening_date is the past is ignored';
	is $strassen->data->[8], "B 49\tHH::Br 7.6022197,50.3538584 7.6024921,50.3537927\n";
    }

    {
	my $radwege = Strassen->new("$destdir/radwege");
	ok $radwege, 'radwege could be loaded';
	is $radwege->data->[0], "Karl-Marx-Allee\tRW1; 13.4329187,52.5178395 13.4364709,52.5174916\n";
	is_deeply $radwege->get_directives(0), { };
	is $radwege->data->[1], "Rudi-Dutschke-Stra�e\t;RW5 13.3905066,52.5067076 13.3905715,52.5067128\n";
    }

    {
	my $ampeln = Strassen->new("$destdir/ampeln");
	ok $ampeln, 'ampeln could be loaded';
	is $ampeln->data->[0], "\tX 13.4329187,52.5178395\n";
    }

    {
	my $gesperrt = Strassen->new("$destdir/gesperrt");
	ok $gesperrt, 'gesperrt could be loaded';
	is $gesperrt->data->[0], "Karl-Marx-Allee\t1 13.4364709,52.5174916 13.4329187,52.5178395\n";
	is_deeply $gesperrt->get_directives(0), { };
    }

    {
	my $gesperrt_car = Strassen->new("$destdir/gesperrt_car");
	ok $gesperrt_car, 'oneway:bicycle=no goes to gesperrt_car';
	is $gesperrt_car->data->[0], "Wismarplatz\t1 13.4627415,52.5108136 13.4630646,52.5114094\n";
    }

    {
	my $qualitaet_s = Strassen->new("$destdir/qualitaet_s");
	ok $qualitaet_s, 'cobblestone to quality file';
	my $rec_i = 0;
	is $qualitaet_s->data->[$rec_i++], "Wismarplatz: Kopfsteinpflaster\tQ2 13.4630646,52.5114094 13.4627415,52.5108136\n";
	TODO: {
	    todo_skip 'smoothness & surface:left/right NYI', 2; # XXX todo_skip to not increase $rec_i
	    is $qualitaet_s->data->[$rec_i++], "Wallensteinstra�e: Kopfsteinpflaster\tQ3; 13.5095316,52.4898947 13.5086756,52.4902799\n";
	    is $qualitaet_s->data->[$rec_i++], "Wallensteinstra�e: Asphalt\tQ2; 13.5086756,52.4902799 13.5095316,52.4898947\n";
	}
	is $qualitaet_s->data->[$rec_i++], "Stallschreiberstra�e: gepflastert\tQ2+ 13.4069476,52.5069069 13.4058616,52.5077626\n";
    }

    {
	my $sights = Strassen->new_stream("$destdir/sehenswuerdigkeit", UseLocalDirectives => 1);
	ok $sights, 'constructed sights file';
	my $record_number = 0;
	my @got_url_directive;
	my @got_cat_directive;
	$sights->read_stream
	    (sub {
		 my($r, $dir) = @_;
		 $got_cat_directive[$record_number] = $r->[Strassen::CAT];
		 $got_url_directive[$record_number] = $dir->{url}->[0];
		 $record_number++;
	     });
	is $got_url_directive[0], 'http://www.bellevue-hotel.de/', 'contact:website turned into a url directive';
	is $got_cat_directive[0], 'SW|IMG:hotel';
	is $got_url_directive[1], 'http://en.wikipedia.org/wiki/cs: Evangelicky Kristuv kostel (Ostrava)', 'url in sights file';
	is $got_cat_directive[1], 'SW|IMG:church';
    }

    {
	my $gesperrt = Strassen->new("$destdir/orte");
	ok $gesperrt, 'orte could be loaded';
	is $gesperrt->data->[0], "Berlin\t6 13.3888599,52.5170365\n";
    }

    {
	my @cmd = ($^X, $osm2bbd_postprocess, "--debug=0", "--only-title-for-dataset", $destdir);
	system @cmd;
	is $?, 0, "<@cmd> works";

	my $meta_new = BBBikeYAML::LoadFile("$destdir/meta.yml");
	my $dataset_title = delete $meta_new->{dataset_title}; # and manipulate $meta_new
	is $dataset_title, 'Berlin', 'added dataset_title by osm2bbd-postprocess';
	is_deeply $meta_new, $meta, 'meta.yml is otherwise unchanged by osm2bbd-postprocess';
    }

    {
	my $strassen_bab = Strassen->new("$destdir/strassen_bab");
	is $strassen_bab->data->[0], "B 49\tBAB::Br 7.6088753,50.3519688 7.6083146,50.3520816\n";
	is $strassen_bab->data->[1], "B 49\tBAB 7.6354296,50.3463404 7.6350669,50.3462314\n";
	is scalar(@{$strassen_bab->data}), 2;
    }

 SKIP: {
	skip "Need IPC::Run for stderr capturing", 1
	    if !eval { require IPC::Run; 1 };

	my $succ = IPC::Run::run([$^X, $osm2bbd_postprocess, "--only-title-for-dataset", $destdir], '>', \my $stdout, '2>', \my $stderr);
	ok $succ, 'Running osm2bbd-postprocess twice is OK';
	is $stdout, '', 'STDOUT is empty';
	is $stderr, "Running target title_for_dataset ... dataset_title already set in meta.yml, do not overwrite, skipping\n", 'Skipping target on 2nd run';

	my $meta_new = BBBikeYAML::LoadFile("$destdir/meta.yml");
	my $dataset_title = delete $meta_new->{dataset_title}; # and manipulate $meta_new
	is $dataset_title, 'Berlin', 'dataset_title is still unchanged';
	is_deeply $meta_new, $meta, 'meta.yml is otherwise still unchanged by osm2bbd-postprocess';
    }

    {
	my $local_language = 'de';
	my $city_names = 'B�rlin';
	my $neighbours = '["some data structure"]';
	my $other_names = "Potsdam,Bernau";
	my $region = "\x{20ac}urope";
	my @add_args = map { Encode::encode_utf8($_) }
	    (
	     '--local-language', $local_language,
	     '--city-names', $city_names,
	     '--neighbours', $neighbours,
	     '--other-names', $other_names,
	     '--region', $region,
	    );
	my @cmd = (
		   $^X, $osm2bbd_postprocess, "--debug=0", "--only-write-meta",
		   @add_args,
		   $destdir
		  );
	my_system @cmd;
	is $?, 0, "<@cmd> works";

	my $meta_new = BBBikeYAML::LoadFile("$destdir/meta.yml");
	is $meta_new->{local_language}, $local_language;
	is $meta_new->{city_names}, $city_names, 'option with unicode in latin1 range';
	is_deeply $meta_new->{neighbours}, ["some data structure"], q{eval'ed option};
	is $meta_new->{other_names}, $other_names;
	is $meta_new->{region}, $region, 'option with unicode > 0xff';

	my $meta_dd = Geography::FromMeta->load_meta("$destdir/meta.dd");
	is_deeply $meta_dd, $meta_new, 'meta.dd and meta.yml have the same contents';
    }

 SKIP: {
	skip 'Requires IPC::Run for -fingerprint-only test', 1
	    if !eval { require IPC::Run; 1 };

	my @stdout;
	for my $run (0..1) {
	    my $succ = IPC::Run::run([$^X, $osm2bbd, '-fingerprint-only', '-o', '/tmp/not-used', '-f', $osmfile], '>', \$stdout[$run], '2>', \my $stderr);
	    ok $succ, '-fingerprint-only call is successful';
	    is $stderr, '', 'nothing on stderr';
	    like $stdout[$run], qr{^[0-9a-f]{32}$}, 'looks like a md5 hex fingerprint';
	}
	is $stdout[1], $stdout[0], 'both fingerprints the same';

	ok(IPC::Run::run([$^X, $osm2bbd, '-fingerprint-only', '-o', '/tmp/not-used', '-f', $osmfile, '-experiment', 'handle_relations'], '>', \$stdout[2]));
	isnt $stdout[2], $stdout[0], 'fingerprint different on different cmdline';
    }

    {
	my @cmd = ($^X, $osm2bbd_postprocess, "--debug=0", "--only-largest-city-is-center", $destdir);
	if (eval { require IPC::Run; 1 }) {
	    ok IPC::Run::run(\@cmd, '>', \my $stdout, '2>', \my $stderr), "<@cmd> works";
	    is $stdout, '', 'STDOUT is empty';
	    is $stderr, 'setting Berlin (13.3888599,52.5170365) as center ', 'expected diagnostics for center-setting';
	} else {
	    system @cmd;
	    is $?, 0, "<@cmd> works";
	}

	my $meta_new = BBBikeYAML::LoadFile("$destdir/meta.yml");
	is_deeply $meta_new->{center}, [13.3888599,52.5170365], 'center set';
	is_number $meta_new->{center}->[0], 'lon from center is a number';
	is_number $meta_new->{center}->[1], 'lat from center is a number';
	is_deeply $meta_new->{center_wgs84}, [13.3888599,52.5170365], 'center_wgs84 set';
	is_number $meta_new->{center_wgs84}->[0], 'lon from center is a number';
	is_number $meta_new->{center_wgs84}->[1], 'lat from center is a number';
	is $meta_new->{center_name}, 'Berlin', 'center_name set';

	my $meta_new_dd = Geography::FromMeta->load_meta("$destdir/meta.dd");
	is_deeply $meta_new_dd->center, "13.3888599,52.5170365", 'center from Geography::FromMeta';
	is_deeply $meta_new_dd->center_wgs84, "13.3888599,52.5170365", 'center_wgs84 from Geography::FromMeta';
    }
}

# Following is actually checking two things:
# - handling gzipped osm files
# - the polar_coord_hack experiment, together with checking the generated Karte/Polar.pm file
SKIP: {
    skip "Need IO::Zlib for testing .osm.gz files", 1
	if !eval { require IO::Zlib; 1 };

    my $destdir = tempdir("osm2bbd.t-2-XXXXXXXX", TMPDIR => 1, CLEANUP => $keep ? 0 : 1);
    if ($keep) {
	diag "2nd destination directory is: $destdir";
    }

    my(undef,$osm_gzip_file) = tempfile(UNLINK => 1, SUFFIX => ".osm2bbd.t.osm.gz");
    my $fh = IO::Zlib->new($osm_gzip_file, "wb9")
	or die "Can't create gzipped file: $!";
    print $fh <<'EOF';
<?xml version='1.0' encoding='UTF-8'?>
<osm version="0.6" generator="osmconvert 0.8.4" timestamp="2017-08-07T01:59:59Z">
        <bounds minlat="53.246" minlon="11.085" maxlat="53.83" maxlon="11.964"/>
        <node id="5072583" lat="53.8246271" lon="11.3533807" version="1"/>
        <node id="5072743" lat="53.8206992" lon="11.325464" version="1"/>
        <way id="4040433" version="1">
                <nd ref="5072583"/>
                <nd ref="5072743"/>
		<tag k="highway" v="residential"/>
		<tag k="name" v="Teststreet"/>
	</way>
</osm>
EOF
    close $fh
	or die $!;

    my @cmd = ($^X, $osm2bbd, "--debug=0", "--experiment=polar_coord_hack", "-f", "-o", $destdir, $osm_gzip_file);
    system @cmd;
    is $?, 0, "<@cmd> works";

    {
	my $strassen = Strassen->new("$destdir/strassen");
	ok $strassen, 'strassen could be loaded';
	is $strassen->data->[0], "Teststreet\tN 11.3533807,53.8246271 11.325464,53.8206992\n";
    }

    ok -f "$destdir/Karte/Polar.pm", 'Karte::Polar was created';

 SKIP: {
	skip 'Requires IPC::Run for Karte::Polar test', 1
	    if !eval { require IPC::Run; 1 };
	my @polar_cmd = ($^X, "-I$destdir", "-I.", "-MKarte::Polar", "-MKarte::Standard", "-MKarte", "-e", 'Karte::preload(":all"); print join(",", $Karte::map{"polar"}->trim_accuracy($Karte::map{"polar"}->standard2map(0,0))), "\n"');
	my $succ = IPC::Run::run(\@polar_cmd, '>', \my $got, '2>', \my $stderr);
	ok $succ, "Running <@polar_cmd> was successful";
	is $got, "13.651456,52.403097\n", "expected translation for 0,0 (trimmed)";
	is $stderr, "Using corrected Karte::Polar for latitude 53.538...\n", "expected diagnostics"; # may be removed some day?
    }

    my $meta = BBBikeYAML::LoadFile("$destdir/meta.yml");
    is $meta->{coordsys}, 'wgs84';

    {
	my $dataset_title = qq{a "strange" d\x{e4}taset title \x{20ac}};
	require Encode;
	my $dataset_title_octets = Encode::encode_utf8($dataset_title);
	my @cmd = ($^X, $osm2bbd_postprocess, "--debug=0", "--only-title-for-dataset", "--dataset-title", $dataset_title_octets, $destdir);
	my_system @cmd;
	is $?, 0, "<@cmd> works";

	my $meta_new = BBBikeYAML::LoadFile("$destdir/meta.yml");
	is $meta_new->{dataset_title}, $dataset_title, 'Custom --dataset-title, correctly encoded';

	my $meta_new_dd = Geography::FromMeta->load_meta("$destdir/meta.dd");
	is_deeply $meta_new_dd, $meta_new, 'meta.dd and meta.yml have the same contents';
    }

}

SKIP: {
    skip 'Requires IPC::Run for -parsefor test', 1
	if !eval { require IPC::Run; 1 };
    my($osmfh,$osmfile) = tempfile(UNLINK => 1, SUFFIX => '_osm2bbd.osm');
    print $osmfh <<'EOF';
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="Overpass API 0.7.61.5 4133829e">
<note>The data included in this document is from www.openstreetmap.org. The data is made available under ODbL.</note>
<meta osm_base="2023-11-27T07:27:20Z"/>
  <node id="338178874" lat="52.4585984" lon="13.3103323">
    <tag k="name" v="positive name"/>
    <tag k="key" v="positive_val"/>
  </node>
  <node id="727611593" lat="52.5222444" lon="13.3765784">
    <tag k="name" v="negative name"/>
    <tag k="key" v="negative_val"/>
  </node>
</osm>
EOF
    close $osmfh;

    my @cmd = ($^X, $osm2bbd, "--debug=0", "-parsefor", "key=positive_val", $osmfile);
    ok IPC::Run::run(\@cmd, '>', \my $bbd), 'osm2bbd with -parsefor';
    my $s = Strassen->new_from_data_string($bbd);
    isa_ok $s, 'Strassen';
    is $s->count, 1, 'only one element found with -parsefor';
    is $s->data->[0], "positive name\tpositive_val 13.3103323,52.4585984\n", 'expected data';
}

SKIP: {
    skip 'Requires IPC::Run for -version test', 1
	if !eval { require IPC::Run; 1 };
    my $succ = IPC::Run::run([$^X, $osm2bbd, '-version'], '>', \my $stdout, '2>', \my $stderr);
    ok $succ, '-version call is successful';
    is $stderr, '', 'nothing on stderr';
    like $stdout, qr{\Aosm2bbd \d+\.\d+\n\z}, 'looks like a version';
}

__END__
