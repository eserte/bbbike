#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;

BEGIN {
    for my $moddef (
		    ['HTML::Form'],
		    ['LWP::UserAgent'],
		    ['Test::More'],
		   ) {
	my($mod, @imports) = @$moddef;
	my $use_code = "use $mod" . (@imports ? ' qw(' . join(' ', @imports) . ')' : '') . '; 1';
	if (!eval $use_code) {
	    print "1..0 # skip no $mod module ($@)\n";
	    exit;
	}
    }
}

use FindBin;
use lib ($FindBin::RealBin, "$FindBin::RealBin/..", "$FindBin::RealBin/../lib");

use CGI qw();
use Data::Dumper ();
use Encode qw(from_to);
use Getopt::Long;
use Safe ();
use Time::HiRes qw(time);

use BBBikeUtil qw(is_in_path);
use BBBikeTest qw(get_std_opts like_html unlike_html $cgidir
		  xml_eq xmllint_string gpxlint_string kmllint_string
		  using_bbbike_test_cgi check_cgi_testing
		  validate_bbbikecgires_xml_string
		  validate_bbbikecgires_data
		  libxml_parse_html_or_skip eq_or_diff
		  $debug
		);

sub bbbike_cgi_search ($$;$);
sub bbbike_en_cgi_search ($$;$);
sub bbbike_cgi_geocode ($$);
sub bbbike_en_cgi_geocode ($$);
sub _bbbike_lang_cgi ($);
sub expected_tag ($$);

check_cgi_testing;

my $ipc_run_tests = 3;
my $json_xs_0_tests = 3;
my $json_xs_tests = 5;
my $json_xs_2_tests = 6;
my $json_xs_3_tests = 4;
my $yaml_tests = 7;
my $xml_libxml_tests = 30;
#plan 'no_plan';
plan tests => 266 + $ipc_run_tests + $json_xs_0_tests + $json_xs_tests + $json_xs_2_tests + $json_xs_3_tests + $yaml_tests + $xml_libxml_tests;

if (!GetOptions(get_std_opts("cgidir", "simulate-skips", "debug"),
	       )) {
    die "usage!";
}

using_bbbike_test_cgi;

my $testcgi = "$cgidir/bbbike-test.cgi";
my $ua = LWP::UserAgent->new(keep_alive => 1);
$ua->agent("BBBike-Test/1.0");
$ua->env_proxy;
$ua->default_header('Accept-Encoding' => scalar HTTP::Message::decodable());

{
    # cat=3 in bbbike-temp-blockings, affecting
    my $resp = bbbike_cgi_search +{
				    startc => '18165,7371', # Treskowallee (south)
				    zielc  => '18287,7815', # Hegemeisterweg (north)
				  }, 'route with affecting temp blocking';
    my $content = $resp->decoded_content;
    expected_tag $resp, 'rm.route.html';
    like_html $content, qr{Ereignisse, die die Route betreffen k.*nnen}, 'found temp blocking';
    like_html $content, qr{Hegemeisterweg/Treskowallee}, 'correct temp blocking found';
}

{
    # cat=3 in bbbike-temp-blockings, but not affecting
    my $resp = bbbike_cgi_search +{
				    startc => '18287,7815', # Hegemeisterweg (north)
				    zielc  => '18165,7371', # Treskowallee (south)
				  }, 'route without affecting temp blocking';
    my $content = $resp->decoded_content;
    expected_tag $resp, 'rm.route.html';
    unlike_html $content, qr{Ereignisse, die die Route betreffen k.*nnen}, 'temp blocking not found';
    unlike_html $content, qr{Hegemeisterweg/Treskowallee}, 'temp blocking not found';
}

SKIP: {
    skip "Need IPC::Run for this test", $ipc_run_tests
	if !eval { require IPC::Run; 1 };
    my $cgi_script = "$FindBin::RealBin/../cgi/bbbike-test.cgi";
    skip "Cannot find cgi/bbbike-test.cgi, maybe symlink missing?", $ipc_run_tests
	if !-e $cgi_script;
    # call script directly, check exit code
    my @cmd = ($^X, $cgi_script, 'startc=8000,8000;zielc=10000,10000;pref_seen=1;output_as=json');
    my $http_out;
    my $stderr;
    my $success = IPC::Run::run(\@cmd, '>', \$http_out, '2>', \$stderr);
    ok $success, 'bbbike-test.cgi run successfully';
    like $http_out, qr{content-type: application/json}i, 'detected application/json content type';
    $stderr =~ s{.*Search again with nearest node .* instead of wanted goal .*\n}{};
    is $stderr, '', 'stderr is empty';
}

{
    # mixed N/H, ferry, with_cat_display enabled (currently only in beta bbbike.cgi)
    my $resp = bbbike_cgi_search +{ use_beta => 1,
				    startc => '22162,1067',
				    zielc => '23068,1638',
				    pref_ferry => 'use',
				  }, 'mixed N/H, ferry, beta bbbike.cgi';
    my $content = $resp->decoded_content;
    expected_tag $resp, 'rm.route.html';
    like_html $content, qr{Wassersportallee.*title=.Hauptstra.*e, Radweg.*class=.catH catcellRW}, 'found cat_display with H and RW';
    like_html $content, qr{F12 \(Dahme\).*title=.F.*hre.*class=.catQ.catcell['"].*Mo-Fr von ca. 6 bis 21 Uhr.*BVG-Kurzstreckentarif}, 'found cat_display with ferry, ferry information';
    like_html $content, qr{angekommen.*M.*ggelbergallee/F12 \(Dahme\)}, 'angekommen';
}

{
    # This used also to dump an error
    # "bbbike-test.cgi: Search again with nearest node <-11472,-2406> instead of wanted goal <-10859,-3249>"
    # to error.log, but not anymore (not tested here)
    my $safe = Safe->new;
    my $resp = bbbike_cgi_search +{ startc => '-11472,-2406', zielc => '-10859,-3249',
				    pref_fragezeichen => 'yes',
				    output_as => 'perldump',
				  }, 'tricky search with fragezeichen in region scope';
    is $resp->header('content-disposition'), 'attachment; filename=route_landstrasse1fragezeichen1_landstrasse1fragezeichen2.txt';
    expected_tag $resp, 'rm.route.perldump';
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
    expected_tag $resp, 'error.wrongcoord';
    my $data = JSON::XS::decode_json($resp->decoded_content(charset => 'none'));
    like $data->{error}, qr{highly probably wrong coordinate}i, 'detected wrong coordinate';
}

{
    my $resp = bbbike_cgi_search +{ startc_wgs84 => '13.410891,52.544453', zielc_wgs84 => '0.000000,0.000000',
				  }, 'non-json output', { status => 400 };
    expected_tag $resp, 'error.wrongcoord';
    like $resp->decoded_content, qr{highly probably wrong coordinate}i, 'detected wrong coordinate in text/plain';
}

{
    my $resp = bbbike_cgi_geocode +{start => 'Total unbekannter Weg'}, 'Completely unknown street';
    expected_tag $resp, 'rm.chooseform';
    like_html($resp->decoded_content, qr{Total unbekannter Weg.*?ist nicht bekannt.*?Checkliste}s);
}

{
    my $resp = bbbike_en_cgi_geocode +{start => 'Total unbekannter Weg'}, 'Completely unknown street';
    expected_tag $resp, 'rm.chooseform';
    like_html($resp->decoded_content, qr{Total unbekannter Weg.*?is unknown.*?Checklist}s);
}

{
    my $resp = bbbike_cgi_geocode +{start => 'Unbekannter Weg'}, 'Unknown street';
    my $content = $resp->decoded_content;
    expected_tag $resp, 'rm.chooseform';
    like_html($content, qr{Unbekannter Weg.*?ist nicht bekannt.*?Stra.*?eintragen}s);
    like_html($content, qr{Die n.*?chste bekannte Kreuzung ist:.*?Dudenstr./Mehringdamm.*?und wird f.*?r die Suche verwendet}s);
}

{
    my $resp = bbbike_en_cgi_geocode +{start => 'Unbekannter Weg'}, 'Unknown street';
    my $content = $resp->decoded_content;
    expected_tag $resp, 'rm.chooseform';
    like_html($content, qr{Unbekannter Weg.*?is unknown.*?register this street}s);
    like_html($content, qr{The next known crossing is:.*?Dudenstr./Mehringdamm.*?and will be used for route search}s);
}

{
    my $resp = bbbike_cgi_geocode +{start => 'Kottbusser Damm/Maybachufer',
				    ziel => 'Maybachufer/Schinkestr.',
				   }, 'Find streets with crossing notation';
    expected_tag $resp, 'rm.crossing';
    on_pref_page_without_crossing($resp);
}

{
    my $resp = bbbike_cgi_geocode +{start => 'Mehringdamm',
				    ziel => 'Yorckstr.',
				   }, 'Find normal street';
    expected_tag $resp, 'rm.crossing';
    on_crossing_pref_page($resp);
    my $content = $resp->decoded_content;
 SKIP: {
	my $doc = libxml_parse_html_or_skip 3, $content;
	eq_or_diff
	    [extract_crossings($doc, 'start')],
	    [
	     'Dudenstr.',
	     'Wilhelmshöhe',
	     'Kreuzbergstr.',
	     'Yorckstr.',
	    ],
	    'List of start crossings as expected and in order';
	eq_or_diff [extract_crossings($doc, 'via')], [], 'No via seen';
	eq_or_diff
	    [extract_crossings($doc, 'ziel')],
	    [
	     'Mehringdamm',
	     'Katzbachstr.',
	    ],
	    'List of goal crossings';
    }
}

TODO: {
    todo_skip "Alias handling not yet implemented", 4;

    my $resp2 = bbbike_cgi_geocode +{start => 'Aliaswidestr.',
				     ziel => 'Aliasstr.',
				    }, 'Find aliases';
    expected_tag $resp2, 'rm.crossing';
    on_crossing_pref_page($resp2);

    my $resp3 = bbbike_cgi_geocode +{start => 'B96',
				     ziel => 'Aliasstr.',
				    }, 'Find aliases, 2nd check';
    {
	local $TODO = "Approx is too good here";
	expected_tag $resp2, 'rm.crossing';
	on_crossing_pref_page($resp2);
    }
}

{
    my $resp = bbbike_cgi_geocode +{start => 'Kleine Parkstr.',
				    via => 'Wilhelmshöhe',
				    ziel => 'Blücherplatz',
				   }, 'A street with culdesac';
    expected_tag $resp, 'rm.crossing';
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
    expected_tag $resp, 'rm.crossing';
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
    expected_tag $resp, 'rm.chooseform';
    not_on_crossing_pref_page($resp);
}

{
    # "inofficial" streets not found in Berlin.coords.data
    my $resp = bbbike_cgi_geocode +{start => 'Alt-Treptow',
				    ziel => 'Rosengarten',
				   }, 'Inofficial street';
    expected_tag $resp, 'rm.crossing';
    on_crossing_pref_page($resp);
    my $content = $resp->decoded_content;
    like_html $content, qr{\Q(Rosengarten}, 'Found Rosengarten with parenthesis';
}

{
    # oldname, not unique
    my $resp = bbbike_cgi_geocode +{start => 'Kochstr.',
				    ziel => 'Dudenstr.',
				   }, 'oldname';
    expected_tag $resp, 'rm.chooseform';
    not_on_crossing_pref_page($resp);
    my $content = $resp->decoded_content;
    like_html $content, qr{Rudi-Dutschke-Str.*alter Name.*Kochstr}, 'Found old name note';
}

{
    # oldname, not unique, English
    my $resp = bbbike_en_cgi_geocode +{start => 'Kochstr.',
				       ziel => 'Dudenstr.',
				   }, 'oldname (English)';
    expected_tag $resp, 'rm.chooseform';
    not_on_crossing_pref_page($resp);
    my $content = $resp->decoded_content;
    like_html $content, qr{Rudi-Dutschke-Str.*old name.*Kochstr}, 'Found old name note (English)';
}

{
    # oldname, unique -> directly to crossing page
    my $resp = bbbike_cgi_geocode +{start => 'Belle-Alliance-Straße',
				    ziel => 'Dudenstr.',
				   }, 'oldname (unique)';
    expected_tag $resp, 'rm.crossing';
    on_crossing_pref_page($resp);
    my $content = $resp->decoded_content;
    like_html $content, qr{Mehringdamm.*alter Name.*Belle-Alliance-Str.}, 'Found old name note';
}

{
    # multiple cityparts
    my $resp = bbbike_cgi_geocode +{start => 'gürtelstr'}, 'multi cityparts';
    expected_tag $resp, 'rm.chooseform';
    my $content = $resp->decoded_content;
    like_html $content, qr{value="Gürtelstr.!Friedrichshain, Lichtenberg!}, 'first alternative';
    like_html $content, qr{value="Gürtelstr.!Prenzlauer Berg, Weißensee!}, 'second alternative';
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
    expected_tag $resp, 'rm.route.json';
    my $data = JSON::XS::decode_json($resp->decoded_content(charset => 'none'));
    validate_bbbikecgires_data $data, 'Mehringdamm Richtung Norden';
    is $data->{Trafficlights}, 1, 'one traffic light seen';
    is $data->{Route}->[0]->{DirectionString}, 'nach Norden', 'direction string seen';
}

{
    my %route_endpoints = (startc => '8861,12125', # Wilhelmstr. von N nach S
			   zielc  => '9058,11564',
			  );

    { # 4 tests
	my $resp = bbbike_cgi_search +{
	    %route_endpoints
	}, 'route with lots of traffic lights';
	my $content = $resp->decoded_content;
	expected_tag $resp, 'rm.route.html';
	like_html $content, qr{0:03h\s+\(<b>bei 20 km/h</b>\)}, 'expected time'; # without the traffic lights, it should be 0:02h
	like_html $content, qr{\Q5 Ampeln auf der Strecke (in die Fahrzeit einbezogen)}, 'five traffic lights in description';
    }

 SKIP: {
	skip "need JSON::XS", $json_xs_3_tests
	    if !eval { require JSON::XS; 1 };

	my $resp = bbbike_cgi_search +{ %route_endpoints, output_as => 'json'}, 'json output';
	expected_tag $resp, 'rm.route.json';
	my $data = JSON::XS::decode_json($resp->decoded_content(charset => 'none'));
	validate_bbbikecgires_data $data, 'Wilhelmstr Richtung Süden';
	is $data->{Trafficlights}, 5, 'five traffic lights seen';
    }
}

SKIP: {
    skip "need working BBBikeYAML", $yaml_tests
	if !eval { require BBBikeYAML; 1 };

    my %route_endpoints = (startc => '14311,11884', # Gärtnerstr.
			   zielc  => '14674,11370', # Wühlischstr.
			  );
    my $resp = bbbike_cgi_search +{ %route_endpoints, output_as => 'yaml'}, 'yaml output';
    expected_tag $resp, 'rm.route.yaml';
    is $resp->header('content-disposition'), 'attachment; filename=route_wuehlischstrgaertnerstrfriedrichshain_ostkreuzumfahrungostkreuz.yml';
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
	expected_tag $resp, 'rm.route.html';
	my $content = $resp->decoded_content;
	like_html($content, qr{Fußgängerbrücke}, 'Found Fussgaengerbruecke');
	like_html($content, qr{30 Sekunden Zeitverlust}, 'Found lost time');
	like_html($content, qr{0:01h.*?bei 20 km/h}, 'Fahrzeit');
    }

    {
	my $resp = bbbike_cgi_search +{ %route_endpoints, pref_specialvehicle => 'childseat' }, 'Special "vehicle" childseat';
	expected_tag $resp, 'rm.route.html';
	my $content = $resp->decoded_content;
	like_html($content, qr{Fußgängerbrücke}, 'Still found Fussgaengerbruecke');
	like_html($content, qr{110 Sekunden Zeitverlust}, 'Found lost time, in seconds');
	like_html($content, qr{0:04h.*?bei 20 km/h}, 'Fahrzeit');
    }

    {
	my $resp = bbbike_cgi_search +{ %route_endpoints, pref_specialvehicle => 'trailer' }, 'Special "vehicle" childseat';
	expected_tag $resp, 'rm.route.html';
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
    expected_tag $resp, 'rm.route.html';
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
	expected_tag $resp, 'rm.route.html';
	my $content = $resp->decoded_content;
	like_html($content, qr{Route von.*Dudenstr.*Methfesselstr});
	like_html($content, qr{L.*nge.*0\.25\s+km});
    }

    {
	my $resp = bbbike_cgi_search +{%route_params, output_as => 'xml'}, 'XML output';
	expected_tag $resp, 'rm.route.xml';
	is $resp->header('content-disposition'), 'attachment; filename=route_dudenstr_methfesselstr.xml';
	my $content = $resp->decoded_content(charset => "none");
	xmllint_string($content, 'Well-formedness of XML output');
	validate_bbbikecgires_xml_string($content, 'Validation of XML output');
    }

    {
	my $resp = bbbike_cgi_search +{%route_params, output_as => 'gpx-route'}, 'GPX route';
	expected_tag $resp, 'rm.route.gpxroute';
	is $resp->header('content-disposition'), 'attachment; filename=route_dudenstr_methfesselstr.gpx';
	my $content = $resp->decoded_content(charset => "none");
	xml_eq($content, '<gpx xmlns="http://www.topografix.com/GPX/1/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" creator="Strassen::GPX ... (XML::LibXML ...) - http://www.bbbike.de" version="1.1" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd"><rte><name>Methfesselstr. von Dudenstr.</name><rtept lat="52.484986" lon="13.385901"><name>Dudenstr.</name></rtept><rtept lat="52.484989" lon="13.382267"><name>Methfesselstr.</name></rtept></rte></gpx>',
	       'output_as gpx-route as expected',
	       ignore => ['//*[local-name()="gpx"]/@creator'], # contains implementor module like XML::Twig or XML::LibXML
	      );
	gpxlint_string($content);
    }
}

SKIP: {
    skip "Need XML::LibXML for more XML checks", $xml_libxml_tests
	if !eval { require XML::LibXML; 1 };

    my $p = XML::LibXML->new;

    my %route_params = (startname => 'Wilhelmshöhe',
			startc => '9225,9111',
			zielname => 'Wilhelmshöhe',
			zielc => '9149,8961',
		       );

    {
	my $resp = bbbike_cgi_search +{%route_params, output_as => 'xml'}, 'XML output';
	expected_tag $resp, 'rm.route.xml';
	is $resp->header('content-disposition'), 'attachment; filename=route_wilhelmshoehe_wilhelmshoehe.xml';
	my $content = $resp->decoded_content(charset => "none");
	validate_bbbikecgires_xml_string($content, 'Validation of XML output');
	my $doc = $p->parse_string($content);
	my $startname = $doc->findvalue('/BBBikeRoute/Route/Point[position()=1]/Strname');
	is($startname, 'Wilhelmshöhe', 'Expected startname in right encoding');
    }

    {
	my $resp = bbbike_cgi_search +{%route_params, output_as => 'gpx-route'}, 'GPX route';
	expected_tag $resp, 'rm.route.gpxroute';
	is $resp->header('content-disposition'), 'attachment; filename=route_wilhelmshoehe_wilhelmshoehe.gpx';
	my $content = $resp->decoded_content(charset => "none");
	my $expected = '<gpx xmlns="http://www.topografix.com/GPX/1/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" creator="Strassen::GPX 1.27 (XML::LibXML 2.0128) - http://www.bbbike.de" version="1.1" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd"><rte><name>Wilhelmshöhe von Wilhelmshöhe</name><rtept lat="52.487916" lon="13.38594"><name>Wilhelmshöhe</name></rtept><rtept lat="52.487887" lon="13.385366"><name></name></rtept><rtept lat="52.48658" lon="13.384777"><name></name></rtept></rte></gpx>';
	from_to($expected, 'latin1', 'utf-8');
	xml_eq($content, $expected,
	       'output_as gpx-route with simplification as expected',
	       ignore => ['//*[local-name()="gpx"]/@creator'], # contains implementor module like XML::Twig or XML::LibXML
	      );
	my $doc = $p->parse_string($content);
	$doc->documentElement->setNamespaceDeclURI(undef, undef);
	my $routename = $doc->findvalue('/gpx/rte/name');
	is($routename, 'Wilhelmshöhe von Wilhelmshöhe', 'expected route name');
	my $startname = $doc->findvalue('/gpx/rte/rtept[1]/name');
	is($startname, 'Wilhelmshöhe', 'Expected startname in right encoding');
	gpxlint_string($content);
    }

    {
	my $resp = bbbike_cgi_search +{%route_params, output_as => 'kml-track'}, 'KML output';
	expected_tag $resp, 'rm.route.kmltrack';
	is $resp->header('content-disposition'), 'attachment; filename=track_wilhelmshoehe_wilhelmshoehe.kml';
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
	expected_tag $resp, 'rm.route.xml';
	my $content = $resp->decoded_content(charset => 'none');
	validate_bbbikecgires_xml_string($content);
	my $doc = $p->parse_string($content);
	like($doc->findvalue('/BBBikeRoute/Error'), qr{.+}, 'Found expected error message')
	    or diag $content;
    }

    {
	my $resp = bbbike_cgi_search +{%noroute_params, output_as => 'gpx-route'}, 'No route, GPX route output';
	expected_tag $resp, 'rm.route.gpxroute';
	gpxlint_string($resp->decoded_content(charset => 'none'));
    }

    {
	my $resp = bbbike_cgi_search +{%noroute_params, output_as => 'gpx-track'}, 'No route, GPX track output';
	expected_tag $resp, 'rm.route.gpxtrack';
	gpxlint_string($resp->decoded_content(charset => 'none'));
    }

    {
	my $resp = bbbike_cgi_search +{%noroute_params, output_as => 'kml-track'}, 'No route, KML track output';
	expected_tag $resp, 'rm.route.kmltrack';
	kmllint_string($resp->decoded_content(charset => 'none'));
    }
}

{
    my $resp = bbbike_cgi_search +{startname=>'Dudenstr.',
				   startc_wgs84=>'13.385915,52.484976',
				   zielname=>'Methfesselstr.',
				   zielc_wgs84=>'13.382252,52.484989',
				  },'Search route with WGS84 coords';
    expected_tag $resp, 'rm.route.html';
    my $content = $resp->decoded_content;
    like_html($content, qr{Route von.*Dudenstr.*Methfesselstr});
    like_html($content, qr{L.*nge.*0\.25\s+km});
}

{
    my $resp = bbbike_cgi_search +{startc=>'10094,6428',
				   zielc=>'10176,6050',
				  },'BNP (Poller) in midst of route';
    expected_tag $resp, 'rm.route.html';
    my $content = $resp->decoded_content;
    like_html($content, qr{\(kein Zeitverlust\)});
}

{ # Ausweichroute
    my %route_endpoints = (startc => '11543,10015',
			   zielc  => '11880,9874',
			  );
    my $resp = bbbike_cgi_search +{ %route_endpoints }, 'Ausweichroute should follow';
    expected_tag $resp, 'rm.route.html';
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
	expected_tag $resp, 'rm.route.html';
	$content = $resp->decoded_content;
	like_html($content, qr{Mögliche Ausweichroute}, 'Expected Ausweichroute text');
	like_html($content, qr{links.*in die.*Schinkestr}, 'Expected route');
    }

    {
	$ausweichroute_form->param('pref_speed', 5);
	my $req = $ausweichroute_form->click;
	my $resp = $ua->request($req);
	ok($resp->is_success, 'Ausweichroute request with 5 km/h was successful');
	expected_tag $resp, 'rm.route.html';
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
	expected_tag $resp, 'rm.route.json';
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
    expected_tag $resp, 'rm.route.html';
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
	expected_tag $resp, 'rm.route.html';
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
	expected_tag $resp, 'rm.route.html';
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
	expected_tag $resp, 'rm.route.perldump';
	is $resp->header('content-disposition'), 'attachment; filename=route_rudidutschkestraxelspringerstr_kochstrkreuzbergwilhelmstrmittekreuzberg.txt';
	my $res = $safe->reval($resp->decoded_content);
	ok((grep { $_ eq '9615,11225' } @{$res->{Path}}), 'via Kochstr.')
	    or diag_route($res);
    }

    {
	my $resp = bbbike_cgi_search +{ %route_endpoints, pref_cat => 'N_RW', output_as => 'perldump' }, 'N_RW';
	expected_tag $resp, 'rm.route.perldump';
	my $res = $safe->reval($resp->decoded_content);
	ok((grep { $_ eq '9615,11225' } @{$res->{Path}}), 'still via Kochstr. (bus lane)')
	    or diag_route($res);
    }

    {
	my $resp = bbbike_cgi_search +{ %route_endpoints, pref_cat => 'N_RW1', output_as => 'perldump' }, 'N_RW1';
	expected_tag $resp, 'rm.route.perldump';
	my $res = $safe->reval($resp->decoded_content);
	ok(!(grep { $_ eq '9615,11225' } @{$res->{Path}}), 'not anymore via Kochstr.')
	    or diag_route($res);
    }

    {
	my $resp = bbbike_cgi_search +{ %route_endpoints, pref_cat => 'N2', output_as => 'perldump' }, 'N';
	expected_tag $resp, 'rm.route.perldump';
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
    expected_tag $resp, 'rm.route.perldump';
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
	expected_tag $resp, 'rm.route.html';
	my $content = $resp->decoded_content;
	like_html($content, qr{nach 0.03 km.*umdrehen.*Hohenstaufenstr..*0.0 km}, 'Found "umdrehen"');
	unlike_html($content, qr{Hohenstaufenstr.*Ecke.*Hohenstaufenstr.}, 'No "Ecke" with same street');
    }

    {
	my $resp = bbbike_en_cgi_search +{ %route_endpoints }, 'Hohenstaufenstr., turn around, English';
	expected_tag $resp, 'rm.route.html';
	my $content = $resp->decoded_content;
	like_html($content, qr{after 0.03 km.*turn around.*Hohenstaufenstr..*0.0 km}, 'Found "turn around" (English)');
	like_html($content, qr{after 0.03 km.*arrived!.*Hohenstaufenstr.}, 'Found "arrived" (English)');
    }
}

# quality preferences and calculations
{
    my %route_endpoints = (startc => '8543,22413', # Mönchmühler Str.
			   zielc  => '8904,23365',
			  );
    {
	my $resp = bbbike_cgi_search +{ %route_endpoints }, 'Mönchmühler Str. with cobblestone and without pref_quality';
	expected_tag $resp, 'rm.route.html';
	my $content = $resp->decoded_content;
	like_html $content, qr{Mönchmühler Str..*schlechtes Kopfsteinpflaster}, 'cobblestone in comments field';
	like_html $content, qr{0:03h\s+\(<b>bei 20 km/h</b>\)}, 'expected time at 20km/h (no pref_quality)';
	like_html $content, qr{0:02h\s+\(bei 25 km/h\)},        'expected time at 25km/h (no pref_quality)';
    }

    {
	my $resp = bbbike_cgi_search +{ pref_quality => 'Q2', %route_endpoints }, 'Mönchmühler Str. with cobblestone and pref_quality=Q2';
	expected_tag $resp, 'rm.route.html';
	my $content = $resp->decoded_content;
	like_html $content, qr{Mönchmühler Str..*schlechtes Kopfsteinpflaster}, 'cobblestone in comments field';
	like_html $content, qr{0:04h\s+\(<b>bei 20 km/h</b>\)}, 'expected time at 20km/h (with time loss because of pref_quality=Q2)';
	like_html $content, qr{0:04h\s+\(bei 25 km/h\)},        'expected time at 25km/h (with time loss because of pref_quality=Q2)';
    }

    {
	my $resp = bbbike_cgi_search +{ pref_quality => 'Q0', %route_endpoints }, 'Mönchmühler Str. with cobblestone and pref_quality=Q0';
	expected_tag $resp, 'rm.route.html';
	my $content = $resp->decoded_content;
	like_html $content, qr{Mönchmühler Str..*schlechtes Kopfsteinpflaster}, 'cobblestone in comments field';
	like_html $content, qr{0:06h\s+\(<b>bei 20 km/h</b>\)}, 'expected time at 20km/h (with time loss because of pref_quality=Q0)';
	like_html $content, qr{0:06h\s+\(bei 25 km/h\)},        'expected time at 25km/h (with time loss because of pref_quality=Q0)';
    }
}

{
    my %route_endpoints = (startc => '62099772',
			   zielc  => '62099773',
			  );
    {
	my $resp = bbbike_cgi_search +{ %route_endpoints }, 'false coordinates', { status => 400 };
	expected_tag $resp, 'error.wrongfmt';
	is $resp->code, 400, 'non-OK status code';
	my $content = $resp->decoded_content;
	like($content, qr{Error: Invalid coordinate format in}, 'Found expected error');
    }
}

{ # showroutelist => 1 tests
    no warnings 'qw';
    my @coords = qw(8763,8780 8982,8781 9063,8935 9111,9036 9115,9046 9150,9152 9170,9206 9211,9354 9248,9350 9280,9476); # Duden - Methfessel - Kreuzberg - Mehringdamm

    for my $coordtype (qw(coords gple gpleu)) {
	if ($coordtype =~ /^gple/) {
	    require Algorithm::GooglePolylineEncoding;
	    require Karte::Polar;
	    require Karte::Standard;
	}

	my %params = (showroutelist => 1);
	if ($coordtype =~ /^gple/) {
	    $params{gple} = Algorithm::GooglePolylineEncoding::encode_polyline(map {
		my($x,$y) = split /,/, $_;
		($x,$y) = $Karte::Polar::obj->trim_accuracy($Karte::Polar::obj->standard2map($x,$y));
		{lon => $x, lat => $y};
	    } @coords);
	} else {
	    $params{coords} = join("!", @coords);
	}

	if ($coordtype eq 'gpleu') {
	    require Route::GPLEU;
	    $params{gpleu} = Route::GPLEU::gple_to_gpleu(delete $params{gple});
	}

	{
	    my $resp = bbbike_cgi_search +{ %params }, "showroutelist with text display, param is $coordtype";
	    expected_tag $resp, 'rm.route.html';
	    my $content = $resp->decoded_content;
	    local $TODO;
	    $TODO = "some streets might be unrecognized due to floating point inaccuracies" if $coordtype =~ /^gple/; # converting from std coords to wgs84 and back
	    like_html $content, qr{nach Osten.*Dudenstr};
	    like_html $content, qr{links.*Methfesselstr};
	    like_html $content, qr{rechts.*Kreuzbergstr};
	    like_html $content, qr{links.*Mehringdamm};
	}

	{
	    my %params = (%params, output_as => 'gpx-track');
	    my $resp = bbbike_cgi_search +{ %params }, "showroutelist as gpx-track, param is $coordtype";
	    expected_tag $resp, 'rm.route.gpxtrack';
	    is $resp->header('content-disposition'), 'attachment; filename=track.gpx';
	    gpxlint_string($resp->decoded_content(charset => 'none'));
	}

	{
	    my %params = (%params, output_as => 'gpx-track', startname => 'Dudenstr.', zielname => 'Mehringdamm');
	    my $resp = bbbike_cgi_search +{ %params }, "showroutelist as gpx-track, param is $coordtype";
	    expected_tag $resp, 'rm.route.gpxtrack';
	    is $resp->header('content-disposition'), 'attachment; filename=track_dudenstr_mehringdamm.gpx';
	    gpxlint_string($resp->decoded_content(charset => 'none'));
	}

	{
	    my %params = (%params, output_as => 'gpx-track', startname => 'Dudenstr.', vianame => 'Methfesselstr.', zielname => 'Dudenstr.');
	    my $resp = bbbike_cgi_search +{ %params }, "showroutelist as gpx-track, param is $coordtype";
	    expected_tag $resp, 'rm.route.gpxtrack';
	    is $resp->header('content-disposition'), 'attachment; filename=track_methfesselstr_dudenstr.gpx';
	    gpxlint_string($resp->decoded_content(charset => 'none'));
	}
    }
}

{
    my %params = (simplify_tolerance => 1,
		  startname => 'Seumestr.',
		  vianame   => 'Wühlischstr.',
		  zielname  => 'Simplonstr.',
		  showroutelist => 1,
		  output_as => 'gpx-track',
		  gple => 'gjn_Im_dqAcGcDgApG|EbBlBqE', # already encoded track
		 );
    my $resp = bbbike_cgi_search +{ %params }, "another gpx-track";
    expected_tag $resp, 'rm.route.gpxtrack';
    is $resp->header('content-disposition'), 'attachment; filename=track_wuehlischstr_simplonstr.gpx', 'different start/goal name, but still detected as circular route';
    gpxlint_string($resp->decoded_content(charset => 'none'));
}

{ # expired or invalid coordssession
    my $session_id = '1:12345678_12345678_12345678';
    my %params = (coordssession => $session_id);
    my $resp = bbbike_cgi_search +{ %params }, "expired coordssession", { status => 410 };
    expected_tag $resp, 'error.sessionexpired';
}

sub bbbike_cgi_search ($$;$) {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    _bbbike_cgi_search({lang=>undef},@_);
}

sub bbbike_en_cgi_search ($$;$) {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    _bbbike_cgi_search({lang=>'en'},@_);
}

sub _bbbike_cgi_search {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my($cgiopts, $params, $testname, $testopts) = @_;
    my $expect_status = $testopts && $testopts->{status} ? delete $testopts->{status} : undef;
    my $testcgi = _bbbike_lang_cgi $cgiopts;
    my $use_beta = delete $params->{use_beta};
    if ($use_beta) {
	$testcgi =~ s{bbbike-test}{bbbike2-test};
    }
    $params->{pref_seen} = 1;
    $params->{pref_speed} = 20 if !exists $params->{pref_speed};
    my $url = $testcgi . '?' . CGI->new($params)->query_string;
    my $t0 = time;
    my $resp = $ua->get($url);
    my $t1 = time;
    my $testname_with_timing = "$testname (time=" . sprintf("%.4fs",$t1-$t0) . ")";
    if (!defined $expect_status) {
	ok($resp->is_success, $testname_with_timing);
    } else {
	is $resp->code, $expect_status, $testname_with_timing;
    }
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
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $testcgi = _bbbike_lang_cgi $cgiopts;
    $params->{pref_seen} = 0;
    my $url = $testcgi . '?' . CGI->new($params)->query_string;
    diag "url for _bbbike_cgi_geocode: $url" if $debug;
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
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    like_html($resp->decoded_content, qr{(?:Genaue Kreuzung angeben|Choose crossing):}, 'On crossing/pref page');
}

sub on_pref_page_without_crossing {
    my($resp) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $content = $resp->decoded_content;
    unlike_html($content, qr{(?:Genaue Kreuzung angeben|Choose crossing):}, 'Crossing is already set');
    like_html($content, qr{(?:Einstellungen|Preferences)}, 'On pref page');
}

sub not_on_crossing_pref_page {
    my($resp) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    unlike_html($resp->decoded_content, qr{(?:Genaue Kreuzung angeben|Choose crossing):}, 'Not on crossing/pref page');
}

sub on_routelist_page {
    my($resp) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    like_html($resp->decoded_content, qr{Route von .* bis}, 'On routelist page (title)');
    like_html($resp->decoded_content, qr{Fahrzeit}, 'On routelist page (Fahrzeit)');
}

sub diag_route {
    my($res) = @_;
    diag join(" - ", map { $_->{Strname} } @{$res->{Route}});
}

sub extract_crossings {
    my($doc, $type) = @_;
    die "type must be start, via, or ziel" if $type !~ m{^(start|via|ziel)$};
    my $html_name = $type.'c';
    my @crossings = map {
	chomp(my $text = $_->textContent);
	$text;
    } $doc->findnodes('//select[@name="'.$html_name.'"]/option');
    @crossings;
}

sub expected_tag ($$) {
    my($resp, $expected_tag) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    is $resp->header('X-Tag'), $expected_tag;
}

__END__
