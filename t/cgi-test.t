#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;

BEGIN {
    if (!eval q{
	use HTML::Form;
	use LWP::UserAgent;
	use Test::More;
	use URI::Escape qw(uri_escape);
	1;
    }) {
	print "1..0 # skip no HTML::Form, LWP::UserAgent, URI::Escape, and/or Test::More modules\n";
	exit;
    }
}

use FindBin;
use lib ($FindBin::RealBin, "$FindBin::RealBin/..");

use CGI qw();
use Data::Dumper ();
use Getopt::Long;
use Safe ();
use Time::HiRes qw(time);

use BBBikeUtil qw(is_in_path);
use BBBikeTest qw(get_std_opts like_html unlike_html $cgidir
		  xmllint_string gpxlint_string kmllint_string
		  using_bbbike_test_cgi check_cgi_testing
		  validate_bbbikecgires_xml_string
		  validate_bbbikecgires_data
		  libxml_parse_html_or_skip
		);

sub bbbike_cgi_search ($$);
sub bbbike_en_cgi_search ($$);
sub bbbike_cgi_geocode ($$);
sub bbbike_en_cgi_geocode ($$);
sub _bbbike_lang_cgi ($);

check_cgi_testing;

my $json_xs_0_tests = 2;
my $json_xs_tests = 4;
my $json_xs_2_tests = 5;
my $yaml_syck_tests = 5;
#plan 'no_plan';
plan tests => 139 + $json_xs_0_tests + $json_xs_tests + $json_xs_2_tests + $yaml_syck_tests;

if (!GetOptions(get_std_opts("cgidir", "simulate-skips"),
	       )) {
    die "usage!";
}

using_bbbike_test_cgi;

my $testcgi = "$cgidir/bbbike-test.cgi";
my $ua = LWP::UserAgent->new(keep_alive => 1);
$ua->agent("BBBike-Test/1.0");
$ua->env_proxy;

{
    # This used also to dump an error
    # "bbbike-test.cgi: Search again with nearest node <-11472,-2406> instead of wanted goal <-10859,-3249>"
    # to error.log, but not anymore (not tested here)
    my $safe = Safe->new;
    my $resp = bbbike_cgi_search +{ startc => '-11472,-2406', zielc => '-10859,-3249',
				    pref_fragezeichen => 'yes',
				    output_as => 'perldump',
				  }, 'tricky search with fragezeichen in region scope';
    my $res = $safe->reval($resp->decoded_content);
    cmp_ok $res->{Len}, ">", 1300, 'expected length';
    is $res->{Route}->[0]->{Strname}, 'Fragezeichen1', 'expected route, 1st hop';
    is $res->{Route}->[1]->{Strname}, "Landstra\337e 1", 'expected route, 2nd hop';
    is $res->{Route}->[2]->{Strname}, "Landstra\337e 1/Fragezeichen2", 'expected route, final hop';
}

SKIP: {
    skip "need JSON::XS", $json_xs_0_tests
	if !eval { require JSON::XS; 1 };

    my $resp = bbbike_cgi_search +{ startc_wgs84 => '13.410891,52.544453', zielc_wgs84 => '0.000000,0.000000',
				    output_as => 'json',
				  }, 'json output';
    my $data = JSON::XS::decode_json($resp->decoded_content(charset => 'none'));
    like $data->{error}, qr{highly probably wrong coordinate}i, 'detected wrong coordinate';
}

{
    my $resp = bbbike_cgi_search +{ startc_wgs84 => '13.410891,52.544453', zielc_wgs84 => '0.000000,0.000000',
				  }, 'non-json output';
    like $resp->decoded_content, qr{highly probably wrong coordinate}i, 'detected wrong coordinate in text/plain';
}

{
    my $resp = bbbike_cgi_geocode +{start => 'Total unbekannter Weg'}, 'Completely unknown street';
    like_html($resp->decoded_content, qr{Total unbekannter Weg.*?ist nicht bekannt.*?Checkliste}s);
}

{
    my $resp = bbbike_en_cgi_geocode +{start => 'Total unbekannter Weg'}, 'Completely unknown street';
    like_html($resp->decoded_content, qr{Total unbekannter Weg.*?is unknown.*?Checklist}s);
}

{
    my $resp = bbbike_cgi_geocode +{start => 'Unbekannter Weg'}, 'Unknown street';
    my $content = $resp->decoded_content;
    like_html($content, qr{Unbekannter Weg.*?ist nicht bekannt.*?Stra.*?eintragen}s);
    like_html($content, qr{Die n.*?chste bekannte Kreuzung ist:.*?Dudenstr./Mehringdamm.*?und wird f.*?r die Suche verwendet}s);
}

{
    my $resp = bbbike_en_cgi_geocode +{start => 'Unbekannter Weg'}, 'Unknown street';
    my $content = $resp->decoded_content;
    like_html($content, qr{Unbekannter Weg.*?is unknown.*?register this street}s);
    like_html($content, qr{The next known crossing is:.*?Dudenstr./Mehringdamm.*?and will be used for route search}s);
}

{
    my $resp = bbbike_cgi_geocode +{start => 'Kottbusser Damm/Maybachstr.',
				    ziel => 'Maybachstr./Schinkelstr.',
				   }, 'Find streets with crossing notation';
    on_crossing_pref_page($resp);
}

{
    my $resp = bbbike_cgi_geocode +{start => 'Mehringdamm',
				    ziel => 'Yorckstr.',
				   }, 'Find normal street';
    on_crossing_pref_page($resp);

 TODO: {
	todo_skip "Alias handling not yet implemented", 4;

	my $resp2 = bbbike_cgi_geocode +{start => 'Aliaswidestr.',
					 ziel => 'Aliasstr.',
					}, 'Find aliases';
	on_crossing_pref_page($resp2);

	my $resp3 = bbbike_cgi_geocode +{start => 'B96',
					 ziel => 'Aliasstr.',
					}, 'Find aliases, 2nd check';
	{
	    local $TODO = "Approx is too good here";
	    on_crossing_pref_page($resp2);
	}
    }
}

{
    my $resp = bbbike_cgi_geocode +{start => 'Kleine Parkstr.',
				    via => 'Wilhelmshöhe',
				    ziel => 'Blücherplatz',
				   }, 'A street with culdesac';
    on_crossing_pref_page($resp);
    my $content = $resp->decoded_content;
 SKIP: {
	my $doc = libxml_parse_html_or_skip 3, $content;
	{
	    my $found_culdesac = !!$doc->findnodes('//select//option[normalize-space(.)="Sackgassenende, Gartenbauamt"]');
	    ok $found_culdesac, 'Seen culdesac';
	}
	{
	    my $found_culdesac = !!$doc->findnodes('//select//option[normalize-space(.)="Sackgassenende"]');
	    ok $found_culdesac, 'Seen culdesac (default entry)';
	}
	{
	    my $found_culdesac = !!$doc->findnodes('//select//option[normalize-space(.)="Sackgassenende, AGB"]');
	    ok $found_culdesac, 'Seen culdesac, not crossing name';
	}
    }
    unlike_html $content, qr{Johanniterstr.}, 'Not seen, instead culdesac (prioritized) was seen';
}

{
    my $resp = bbbike_en_cgi_geocode +{start => 'Wilhelmshöhe',
				       ziel => 'Dudenstr.',
				      }, 'culdesac (English)';
    on_crossing_pref_page($resp);
    my $content = $resp->decoded_content;
 SKIP: {
	my $doc = libxml_parse_html_or_skip 1, $content;
	{
	    my $found_culdesac = !!$doc->findnodes('//select//option[normalize-space(.)="cul-de-sac"]');
	    ok $found_culdesac, 'Seen culdesac (default entry; English)';
	}
    }
}

{
    my $resp = bbbike_cgi_geocode +{start => 'Really unknown street (make it long, so approx cannot handle it, too)',
				    ziel => 'Yorckstr.',
				   }, 'Find normal street';
    not_on_crossing_pref_page($resp);
}

{
    # "inofficial" streets not found in Berlin.coords.data
    my $resp = bbbike_cgi_geocode +{start => 'Alt-Treptow',
				    ziel => 'Rosengarten',
				   }, 'Inofficial street';
    on_crossing_pref_page($resp);
    my $content = $resp->decoded_content;
    like $content, qr{\Q(Rosengarten}, 'Found Rosengarten with parenthesis';
}

{
    # oldname, not unique
    my $resp = bbbike_cgi_geocode +{start => 'Kochstr.',
				    ziel => 'Dudenstr.',
				   }, 'oldname';
    not_on_crossing_pref_page($resp);
    my $content = $resp->decoded_content;
    like $content, qr{Rudi-Dutschke-Str.*alter Name.*Kochstr}, 'Found old name note';
}

{
    # oldname, not unique, English
    my $resp = bbbike_en_cgi_geocode +{start => 'Kochstr.',
				       ziel => 'Dudenstr.',
				   }, 'oldname (English)';
    not_on_crossing_pref_page($resp);
    my $content = $resp->decoded_content;
    like $content, qr{Rudi-Dutschke-Str.*old name.*Kochstr}, 'Found old name note (English)';
}

{
    # oldname, unique -> directly to crossing page
    my $resp = bbbike_cgi_geocode +{start => 'Belle-Alliance-Straße',
				    ziel => 'Dudenstr.',
				   }, 'oldname (unique)';
    on_crossing_pref_page($resp);
    my $content = $resp->decoded_content;
    like $content, qr{Mehringdamm.*alter Name.*Belle-Alliance-Str.}, 'Found old name note';
}

{
    # multiple cityparts
    my $resp = bbbike_cgi_geocode +{start => uri_escape('gürtelstr')}, 'multi cityparts';
    my $content = $resp->decoded_content;
    like $content, qr{value="Gürtelstr.!Friedrichshain, Lichtenberg!}, 'first alternative';
    like $content, qr{value="Gürtelstr.!Prenzlauer Berg, Weißensee!}, 'second alternative';
 SKIP: {
	my $doc = libxml_parse_html_or_skip 3, $content;
	my @radio_nodes = $doc->findnodes('//input[@type="radio" and @name="start2"]');
	is @radio_nodes, 2, 'Two <input> nodes found';
	for my $radio_node (@radio_nodes) {
	    like $radio_node->getAttribute('value'), qr{^Gürtelstr\.}, 'Found Gürtelstr. in <input> node';
	}
    }
}

SKIP: {
    skip "need JSON::XS", $json_xs_tests
	if !eval { require JSON::XS; 1 };

    my %route_endpoints = (startc => '9229,8785',
			   zielc  => '9227,8890',
			  );
    my $resp = bbbike_cgi_search +{ %route_endpoints, output_as => 'json'}, 'json output';
    my $data = JSON::XS::decode_json($resp->decoded_content(charset => 'none'));
    validate_bbbikecgires_data $data, 'Mehringdamm Richtung Norden';
    is $data->{Trafficlights}, 1, 'one traffic light seen';
    is $data->{Route}->[0]->{DirectionString}, 'nach Norden', 'direction string seen';
}

SKIP: {
    skip "need working BBBikeYAML", $yaml_syck_tests
	if !eval { require BBBikeYAML; 1 };

    my %route_endpoints = (startc => '14311,11884', # Gärtnerstr.
			   zielc  => '14674,11370', # Wühlischstr.
			  );
    my $resp = bbbike_cgi_search +{ %route_endpoints, output_as => 'yaml'}, 'yaml output';
    my $data = BBBikeYAML::Load($resp->decoded_content(charset => 'none'));
    validate_bbbikecgires_data $data, 'YAML output';
    is $data->{Route}->[0]->{Strname}, 'Gärtnerstr.', 'found 1st non-ascii name';
    is $data->{Route}->[0]->{DirectionString}, 'nach Süden';
    is $data->{Route}->[1]->{Strname}, 'Wühlischstr.', 'found 2nd non-ascii name';
}

{
    my %route_endpoints = (startc => '14798,10985',
			   zielc  => '14794,10844',
			  );
    {
	my $resp = bbbike_cgi_search +{ %route_endpoints }, 'No special vehicle';
	my $content = $resp->decoded_content;
	like_html($content, qr{Fußgängerbrücke}, 'Found Fussgaengerbruecke');
	like_html($content, qr{30 Sekunden Zeitverlust}, 'Found lost time');
	like_html($content, qr{0:01h.*?bei 20 km/h}, 'Fahrzeit');
    }

    {
	my $resp = bbbike_cgi_search +{ %route_endpoints, pref_specialvehicle => 'childseat' }, 'Special "vehicle" childseat';
	my $content = $resp->decoded_content;
	like_html($content, qr{Fußgängerbrücke}, 'Still found Fussgaengerbruecke');
	like_html($content, qr{110 Sekunden Zeitverlust}, 'Found lost time, in seconds');
	like_html($content, qr{0:04h.*?bei 20 km/h}, 'Fahrzeit');
    }

    {
	my $resp = bbbike_cgi_search +{ %route_endpoints, pref_specialvehicle => 'trailer' }, 'Special "vehicle" childseat';
	my $content = $resp->decoded_content;
	like_html($content, qr{Brücken Rummelsburg}, 'Found Umfahrung');
	unlike_html($content, qr{Zeitverlust}, 'No lost time here');
    }
}

{
    my $resp = bbbike_cgi_search +{ startc => '14787,10972',
				    viac   => '14764,10877',
				    zielc  => '14787,10972',
				    pref_specialvehicle => 'childseat' }, 'Special "vehicle" childseat';
    my $content = $resp->decoded_content;
    like_html($content, qr{Fußgängerbrücke}, 'Still found Fussgaengerbruecke');
    like_html($content, qr{\(2x\).*4 Minuten Zeitverlust}, 'Found lost time, in minutes, and "2x"');
    like_html($content, qr{0:04h.*?bei 20 km/h}, 'Fahrzeit');
}

{
    my %route_params = (startname=>'Dudenstr.',
			startc=>'9229,8785',
			zielname=>'Methfesselstr.',
			zielc=>'8982,8781',
		       );
    {
	my $resp = bbbike_cgi_search +{%route_params}, 'Search route with bbbike coords';
	my $content = $resp->decoded_content;
	like_html($content, qr{Route von.*Dudenstr.*Methfesselstr});
	like_html($content, qr{L.*nge.*0\.25\s+km});
    }

    {
	my $resp = bbbike_cgi_search +{%route_params, output_as => 'xml'}, 'XML output';
	my $content = $resp->decoded_content(charset => "none");
	xmllint_string($content, 'Well-formedness of XML output');
	validate_bbbikecgires_xml_string($content, 'Validation of XML output');
    }
}

SKIP: {
    skip "Need XML::LibXML for more XML checks", 6
	if !eval { require XML::LibXML; 1 };

    my $p = XML::LibXML->new;

    my %route_params = (startname => 'Wilhelmshöhe',
			startc => '9225,9111',
			zielname => 'Wilhelmshöhe',
			zielc => '9149,8961',
		       );

    {
	my $resp = bbbike_cgi_search +{%route_params, output_as => 'xml'}, 'XML output';
	my $content = $resp->decoded_content(charset => "none");
	validate_bbbikecgires_xml_string($content, 'Validation of XML output');
	my $doc = $p->parse_string($content);
	my $startname = $doc->findvalue('/BBBikeRoute/Route/Point[position()=1]/Strname');
	is($startname, 'Wilhelmshöhe', 'Expected startname in right encoding');
    }

    {
	my $resp = bbbike_cgi_search +{%route_params, output_as => 'gpx-route'}, 'GPX route';
	my $content = $resp->decoded_content(charset => "none");
	my $doc = $p->parse_string($content);
	$doc->documentElement->setNamespaceDeclURI(undef, undef);
	my $startname = $doc->findvalue('/gpx/rte/rtept[1]/name');
	is($startname, 'Wilhelmshöhe', 'Expected startname in right encoding');
	gpxlint_string($content);
    }

    {
	my $resp = bbbike_cgi_search +{%route_params, output_as => 'kml-track'}, 'KML output';
	my $content = $resp->decoded_content(charset => "none");
	my $doc = $p->parse_string($content);
	$doc->documentElement->setNamespaceDeclURI(undef, undef);
	my $name = $doc->findvalue('/kml/Document/Placemark/name');
	like($name, qr{^Wilhelmshöhe}, 'Expected name in right encoding');
	kmllint_string($content);
    }

    # No route found with these values
    my %noroute_params = ('startname'=>'Pazifik1',
			  'startc_wgs84'=>'-144.316406,-4.915833',
			  'zielname'=>'Pazifik2',
			  'zielc_wgs84'=>'-139.570312,-4.565474',
			 );

    {
	my $resp = bbbike_cgi_search +{%noroute_params, output_as => 'xml'}, 'No route, XML output';
	my $content = $resp->decoded_content(charset => 'none');
	validate_bbbikecgires_xml_string($content);
	my $doc = $p->parse_string($content);
	like($doc->findvalue('/BBBikeRoute/Error'), qr{.+}, 'Found expected error message')
	    or diag $content;
    }

    {
	my $resp = bbbike_cgi_search +{%noroute_params, output_as => 'gpx-route'}, 'No route, GPX route output';
	gpxlint_string($resp->decoded_content(charset => 'none'));
    }

    {
	my $resp = bbbike_cgi_search +{%noroute_params, output_as => 'gpx-track'}, 'No route, GPX track output';
	gpxlint_string($resp->decoded_content(charset => 'none'));
    }

    {
	my $resp = bbbike_cgi_search +{%noroute_params, output_as => 'kml-track'}, 'No route, KML track output';
	kmllint_string($resp->decoded_content(charset => 'none'));
    }
}

{
    my $resp = bbbike_cgi_search +{startname=>'Dudenstr.',
				   startc_wgs84=>'13.385915,52.484976',
				   zielname=>'Methfesselstr.',
				   zielc_wgs84=>'13.382252,52.484989',
				  },'Search route with WGS84 coords';
    my $content = $resp->decoded_content;
    like_html($content, qr{Route von.*Dudenstr.*Methfesselstr});
    like_html($content, qr{L.*nge.*0\.25\s+km});
}

{
    my $resp = bbbike_cgi_search +{startc=>'10094,6428',
				   zielc=>'10176,6050',
				  },'BNP (Poller) in midst of route';
    my $content = $resp->decoded_content;
    like_html($content, qr{\(kein Zeitverlust\)});
}

{ # Ausweichroute
    my %route_endpoints = (startc => '11543,10015',
			   zielc  => '11880,9874',
			  );
    my $resp = bbbike_cgi_search +{ %route_endpoints }, 'Ausweichroute should follow';
    on_routelist_page($resp);
    my $content = $resp->decoded_content;
    like_html($content, qr{Maybachufer: Di und Fr 11.00-18.30 Wochenmarkt, Behinderungen möglich}, 'Found Ausweichroute reason');
    like_html($content, qr{Ausweichroute suchen}, 'Found Ausweichroute button');
    my($ausweichroute_form) = grep { $_->attr('name') eq 'Ausweichroute' } HTML::Form->parse($resp);
    ok($ausweichroute_form, 'Found form with name "Ausweichroute"');

    {
	my $req = $ausweichroute_form->click;
	my $resp = $ua->request($req);
	ok($resp->is_success, 'Ausweichroute request was successful');
	$content = $resp->decoded_content;
	like_html($content, qr{Mögliche Ausweichroute}, 'Expected Ausweichroute text');
	like_html($content, qr{links.*in die.*Schinkelstr}, 'Expected route');
    }

    {
	$ausweichroute_form->param('pref_speed', 5);
	my $req = $ausweichroute_form->click;
	my $resp = $ua->request($req);
	ok($resp->is_success, 'Ausweichroute request with 5 km/h was successful');
	$content = $resp->decoded_content;
	like_html($content, qr{Eine bessere Ausweichroute wurde nicht gefunden}, 'Expected Ausweichroute text (no better route at 5 km/h)')
	    or do {
		if (!eval { require Apache::Session; 1 } &&
		    !eval { require Apache::Session::Counted; 1 }
		   ) {
		    diag 'Please install either Apache::Session or Apache::Session::Counted';
		}
	    };
    }

 SKIP: {
	# Ausweichroute with json
	skip "need JSON::XS", $json_xs_2_tests
	    if !eval { require JSON::XS; 1 };

	my $resp = bbbike_cgi_search +{ %route_endpoints, output_as => 'json'}, 'json output';
	my $data = JSON::XS::decode_json($resp->decoded_content);
	validate_bbbikecgires_data $data, 'JSON data, Maybachufer';
	my $first_blocking = $data->{AffectingBlockings}->[0];
	is $first_blocking->{Index}, 0, 'Index of affecting blockings';
	like $first_blocking->{Text}, qr{Maybachufer.*Wochenmarkt}, 'Text of affecting blockings';
	like $first_blocking->{LongLatHop}->{XY}->[0], qr{^13\.\d+,52\.\d+$}, 'looks like a coordinate in Berlin';
    }
}

{ # double "Ausweichroute"
    my %route_endpoints = (startc => '11092,12375',
			   zielc  => '11329,12497',
			  );
    my $resp = bbbike_cgi_search +{ %route_endpoints }, 'Ausweichroute (Voltairestr., Weihnachtsmarkt) should follow';
    on_routelist_page($resp);
    my $content = $resp->decoded_content;
    like_html($content, qr{Voltairestr.: Weihnachtsmarkt}, 'Found Ausweichroute reason');
    like_html($content, qr{Ausweichroute suchen}, 'Found Ausweichroute button');
    my($ausweichroute_form) = grep { $_->attr('name') eq 'Ausweichroute' } HTML::Form->parse($resp);
    ok($ausweichroute_form, 'Found form with name "Ausweichroute"');

    {
	my $req = $ausweichroute_form->click;
	my $resp = $ua->request($req);
	ok($resp->is_success, 'Ausweichroute request was successful');
	$content = $resp->decoded_content;
	like_html($content, qr{Mögliche Ausweichroute}, 'Expected Ausweichroute text');
	like_html($content, qr{Stralauer Str.}, 'Expected route');
	like_html($content, qr{Stralauer Str.: Bauarbeiten}, 'Found another Ausweichroute reason');
	($ausweichroute_form) = grep { $_->attr('name') eq 'Ausweichroute' } HTML::Form->parse($resp);
	ok($ausweichroute_form, 'Found again form with name "Ausweichroute"');
    }

    {
	my $req = $ausweichroute_form->click;
	my $resp = $ua->request($req);
	ok($resp->is_success, 'Ausweichroute request was successful');
	$content = $resp->decoded_content;
	like_html($content, qr{Mögliche Ausweichroute}, 'Expected Ausweichroute text');
	like_html($content, qr{Grunerstr.}, 'Expected route');
    }
}

{
    # N_RW, N_RW1 ... (avoid main roads without cycle paths...)
    my %route_endpoints = (startc => '10020,11262',
			   zielc  => '9199,11166',
			  );
    my $safe = Safe->new;
    {
	my $resp = bbbike_cgi_search +{ %route_endpoints, output_as => 'perldump' }, 'No road prefs';
	my $res = $safe->reval($resp->decoded_content);
	ok((grep { $_ eq '9615,11225' } @{$res->{Path}}), 'via Kochstr.')
	    or diag_route($res);
    }

    {
	my $resp = bbbike_cgi_search +{ %route_endpoints, pref_cat => 'N_RW', output_as => 'perldump' }, 'N_RW';
	my $res = $safe->reval($resp->decoded_content);
	ok((grep { $_ eq '9615,11225' } @{$res->{Path}}), 'still via Kochstr. (bus lane)')
	    or diag_route($res);
    }

    {
	my $resp = bbbike_cgi_search +{ %route_endpoints, pref_cat => 'N_RW1', output_as => 'perldump' }, 'N_RW1';
	my $res = $safe->reval($resp->decoded_content);
	ok(!(grep { $_ eq '9615,11225' } @{$res->{Path}}), 'not anymore via Kochstr.')
	    or diag_route($res);
    }

    {
	my $resp = bbbike_cgi_search +{ %route_endpoints, pref_cat => 'N2', output_as => 'perldump' }, 'N';
	my $res = $safe->reval($resp->decoded_content);
	ok(!(grep { $_ eq '9615,11225' } @{$res->{Path}}), 'also not via Kochstr. (residential only)')
	    or diag_route($res);
    }

}

{
    no warnings 'qw';
    # Rund um den Kreuzberg
    my @test_points = qw(13.382267,52.484989 13.376560,52.485016 13.376766,52.489392 13.386351,52.490061 13.385901,52.484986 13.382267,52.484989);
    my $start = shift @test_points;
    my $goal  = pop @test_points;
    # Rest of @test_points are Via points

    my $safe = Safe->new;
    my $resp = bbbike_cgi_search +{startc_wgs84 => $start,
				   viac_wgs84   => [@test_points],
				   zielc_wgs84  => $goal,
				   output_as    => 'perldump',
				  },'Search route with multiple via points';
    my $res = $safe->reval($resp->decoded_content);
    like join("; ", map { $_->{Strname} } @{ $res->{Route} }), qr{Dudenstr.*Katzbachstr.*Kreuzbergstr.*Mehringdamm.*Dudenstr},
	'Rund um Kreuzberg'
	    or diag(Data::Dumper->new([$res],[qw()])->Indent(1)->Useqq(1)->Dump);
}

{
    my %route_endpoints = (startc => '6209,9772',
			   zielc  => '6209,9773',
			  );
    {
	my $resp = bbbike_cgi_search +{ %route_endpoints }, 'Hohenstaufenstr., turn around, German';
	my $content = $resp->decoded_content;
	like_html($content, qr{nach 0.03 km.*umdrehen.*Hohenstaufenstr..*0.0 km}, 'Found "umdrehen"');
	unlike_html($content, qr{Hohenstaufenstr.*Ecke.*Hohenstaufenstr.}, 'No "Ecke" with same street');
    }

    {
	my $resp = bbbike_en_cgi_search +{ %route_endpoints }, 'Hohenstaufenstr., turn around, English';
	my $content = $resp->decoded_content;
	like_html($content, qr{after 0.03 km.*turn around.*Hohenstaufenstr..*0.0 km}, 'Found "turn around" (English)');
	like_html($content, qr{after 0.03 km.*arrived!.*Hohenstaufenstr.}, 'Found "arrived" (English)');
    }
}

sub bbbike_cgi_search ($$) {
    _bbbike_cgi_search({lang=>undef},@_);
}

sub bbbike_en_cgi_search ($$) {
    _bbbike_cgi_search({lang=>'en'},@_);
}

sub _bbbike_cgi_search {
    my($cgiopts, $params, $testname) = @_;
    my $testcgi = _bbbike_lang_cgi $cgiopts;
    $params->{pref_seen} = 1;
    $params->{pref_speed} = 20 if !exists $params->{pref_speed};
    my $url = $testcgi . '?' . CGI->new($params)->query_string;
    my $t0 = time;
    my $resp = $ua->get($url);
    my $t1 = time;
    ok($resp->is_success, "$testname (time=" . sprintf("%.4fs",$t1-$t0) . ")");
    $resp;
}

sub bbbike_cgi_geocode ($$) {
    _bbbike_cgi_geocode({lang=>undef},@_);
}

sub bbbike_en_cgi_geocode ($$) {
    _bbbike_cgi_geocode({lang=>'en'},@_);
}

sub _bbbike_cgi_geocode ($$) {
    my($cgiopts, $params, $testname) = @_;
    my $testcgi = _bbbike_lang_cgi $cgiopts;
    $params->{pref_seen} = 0;
    my $url = $testcgi . '?' . CGI->new($params)->query_string;
    my $resp = $ua->get($url);
    ok($resp->is_success, $testname);
    $resp;
}

sub _bbbike_lang_cgi ($) {
    my $cgiopts = shift;
    my $testcgi = $testcgi;
    if ($cgiopts->{lang}) {
	$testcgi =~ s{\.cgi}{\.$cgiopts->{lang}\.cgi};
    }
    $testcgi;
}

sub on_crossing_pref_page {
    my($resp) = @_;
    like_html($resp->decoded_content, qr{(?:Genaue Kreuzung angeben|Choose crossing):}, 'On crossing/pref page');
}

sub not_on_crossing_pref_page {
    my($resp) = @_;
    unlike_html($resp->decoded_content, qr{(?:Genaue Kreuzung angeben|Choose crossing):}, 'Not on crossing/pref page');
}

sub on_routelist_page {
    my($resp) = @_;
    like_html($resp->decoded_content, qr{Route von .* bis}, 'On routelist page (title)');
    like_html($resp->decoded_content, qr{Fahrzeit}, 'On routelist page (Fahrzeit)');
}

sub diag_route {
    my($res) = @_;
    diag join(" - ", map { $_->{Strname} } @{$res->{Route}});
}

__END__
