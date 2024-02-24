#!/usr/local/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 1998,2000,2003,2004,2006,2010,2011,2012,2013,2017,2018,2022,2023 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.de
#

use strict;

use Test::More;
use LWP::UserAgent;
use URI::WithBase;
use URI::Escape qw(uri_escape);
use Getopt::Long;
# Prefer diag(Dumper($res)) over diag $res->as_string, because
# the responses may be binary
use Data::Dumper;
$Data::Dumper::Useqq = 1;
$Data::Dumper::Indent = 1;
use Safe;
use CGI qw();
use Time::HiRes qw(time);

use FindBin;
use lib ($FindBin::RealBin,
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);
use BBBikeTest qw(
		     check_cgi_testing xmllint_string gpxlint_string kmllint_string
		     validate_bbbikecgires_xml_string validate_bbbikecgires_json_string
		     validate_bbbikecgires_yaml_string validate_bbbikecgires_data
		     eq_or_diff
		);

eval { require Compress::Zlib };

sub std_get ($;@);
sub std_get_route ($;@);
sub like_html ($$$);
sub unlike_html ($$$);

check_cgi_testing;

my @urls;

if (defined $ENV{BBBIKE_TEST_CGIURL}) {
    push @urls, $ENV{BBBIKE_TEST_CGIURL};
} elsif (defined $ENV{BBBIKE_TEST_CGIDIR}) {
    push @urls, $ENV{BBBIKE_TEST_CGIDIR} . "/bbbike.cgi";
}

my $cpt = Safe->new;

my $test_file_cache = 1; # if specified, then some URLs will be fetched twice
my $do_display = 0;
my $do_xxx;
my $do_accept_gzip = 1;
my $v = 0;
my %skip;

if ($ENV{BBBIKE_TEST_SKIP_MAPSERVER}) {
    $skip{mapserver} = 1;
}
if (!$ENV{BBBIKE_LONG_TESTS} || $ENV{BBBIKE_TEST_SKIP_PALMDOC}) {
    $skip{palmdoc} = 1;
}

my $ua = LWP::UserAgent->new(keep_alive => 1);
$ua->agent("BBBike-Test/1.0");
$ua->env_proxy;

if (!GetOptions("cgiurl=s" => sub {
		    @urls = $_[1];
		},
		"display!" => \$do_display,
		"xxx" => \$do_xxx,
		"v!" => \$v,
		"skip-mapserver!" => \$skip{mapserver},
		"accept-gzip!" => \$do_accept_gzip,
		"file-cache!" => \$test_file_cache,
	       )) {
    die "usage: $0 [-cgiurl url] [-fast] [-display] [-v] [-skip-mapserver] [-noaccept-gzip] [-nofile-cache] [-xxx]";
}

if (!@urls) {
    unshift @urls, "http://localhost/bbbike/cgi/bbbike.cgi";
    ## If this URL exists, then it is using cgi-bin in contrast to mod-perl
    #my $url2 = "http://localhost/~eserte/bbbike/cgi/bbbike.cgi";
    #my $resp = $ua->head($url2);
    #if ($resp->is_success) {
    #	push @urls, $url2;
    #} else {
    #	diag "Skipping tests on $url2";
    #}
    my $bbbike_config_file = "$FindBin::RealBin/../cgi/bbbike.cgi.config";
    if (!-e $bbbike_config_file) {
	diag "Cannot find BBBike config file $bbbike_config_file, some tests may fail!";
    }
}

my @output_as_defs =
    map {
	+{
	  format         => $_->[0],
	  can_file_cache => $_->[1],
	 }
    } (
       # format
       #              can_file_cache
       ["",           0],
       ["xml",        0],
       ["gpx-track",  1],
       ["gpx-route",  1],
       ["kml-track",  1],
       ["print",      0],
       ["perldump",   0],
       ["yaml",       0],
       ["yaml-short", 0],
       ["json",       1],
       ["json-short", 1],
       ["geojson",    0],
       ["geojson-short", 0],
       ["palmdoc",    0],
       ["mapserver",  0],
      );

my @imagetype_defs =
    map {
	+{
	  format         => $_->[0],
	  can_file_cache => $_->[1],
	 }
    } (
       # format
       #                 can_file_cache
       ["gif",           0],
       ["png",           0],
       ["jpeg",          0],
       ["svg",           0],
       ["mapserver",     0],
       ["pdf",           1],
       ["pdf-auto",      1],
       ["pdf-landscape", 1],
       ["googlemaps",    0],
       # cannot add "leaflet" here --- bbbike.cgi does special javascript handling here; see onsubmit+show_map
      );

my $file_cache_tests_per_format = 4;
my $file_cache_tests_formats = scalar grep { $_->{can_file_cache} } (@output_as_defs, @imagetype_defs);

plan tests => (271 + ($test_file_cache ? $file_cache_tests_formats*$file_cache_tests_per_format : 0)) * scalar @urls;

my $default_hdrs;
if (defined &Compress::Zlib::memGunzip && $do_accept_gzip) {
    $default_hdrs = HTTP::Headers->new(Accept_Encoding => "gzip");
    warn "Accept gzip encoding\n" if $v;
} else {
    $default_hdrs = HTTP::Headers->new();
}

for my $cgiurl (@urls) {
    my $action;
    {
	my($content, $resp) = std_get $cgiurl;
	like $resp->header('Content_Type'),
	    qr{^text/html(?:; charset=(?:ISO-8859-1|utf-8))?$}, "Expect text/html (regardless which charset)";
	like_html $content, qr/Dieses Programm sucht .*Fahrrad-.*Routen in Berlin/,
	    "Expected introduction text in body";
	if ($content =~ /form action=\"([^\"]+)\"/i) {
	    pass "Form found";
	    $action = $1;
	} else {
	    pass "No form found";
	    $action = $cgiurl;
	}
    }

    if ($do_xxx) {
	goto XXX; # skip some tests
    }

    {
	my($content, $resp) = std_get "$action?start=dudenstr&via=&ziel=grimmstr",
	                              testname => "Dudenstr. -> Grimmstr.";
	like_html $content, qr/Start.*Dudenstr\./, "Expected start (Dudenstr)";
	like_html $content, qr/Grimmstr\..*Kreuzberg.*10967/, "Expected goal (Grimmstr)";
    }

    {
	my($content, $resp) = std_get "$action?startname=Dudenstr.&startplz=10965&via=&ziel2=Grimmstr.%21Kreuzberg%2110967",
				      testname => "Dudenstr. -> Grimmstr. (resolved)";
	my($mehringdamm_line) = $content =~ /(.*Mehringdamm.*)/;
	ok defined $mehringdamm_line, "Found Mehringdamm in route";
	like_html $mehringdamm_line, qr/Platz.*d.*Luftbr/, "Found PladeLu in route";
	like_html $mehringdamm_line, qr/Tempelhofer/, "Found Tempelhofer in route";
	like_html $content, qr/(Urban.*Fichte|Fichte.*Urban)/, "Found Urban/Fichtestr. in route";
    }

    {
	# Potsdam
	my($content, $resp) = std_get "$action?start=helmholtzstr&ziel=otto-nagel",
				      testname => "Potsdam streets (Helmholtz-, Otto-Nagel-Str.)";
	like_html $content, qr/Helmholtz.*Potsdam/, "Found Helmholtzstr in Potsdam";
	like_html $content, qr/Helmholtz.*Charlottenburg/, "Found Helmholtzstr in Berlin";
	like_html $content, qr/Otto-Nagel-Str.*Potsdam/, "Found Otto-Nagel-Str. in Potsdam";
	like_html $content, qr/Otto-Nagel-Str.*Biesdorf/, "Found Otto-Nagel-Str. in Berlin";
    }

    {
	# Potsdam, Ortsteile
	my($content, $resp) = std_get "$action?startname=Wildkirschenweg+%28Potsdam-Eiche%29&startplz=14469&vianame=Altes+Rad+%28Potsdam-Eiche%29&viaplz=14469&ziel2=Kaiser-Friedrich-Str.%21Potsdam-Eiche%2114469%21-18046%2C-955&scope=region", testname => "Potsdam-Eiche streets"; # both ...name and ...2 params
	like_html $content, qr{Start.*Wildkirschenweg.*Potsdam-Eiche}, "Found Wildkirscheweg in Potsdam-Eiche";
	like_html $content, qr{Via.*Altes Rad.*Potsdam-Eiche}, "Found Altes Rad in Potsdam-Eiche";
	like_html $content, qr{Ziel.*Kaiser-Friedrich-Str.*Potsdam-Eiche}, "Found Kaiser-Friedrich-Str. in Potsdam-Eiche";
    }

    # search_coord
    for my $output_as_def (@output_as_defs) {
	my($output_as, $can_file_cache) = @{$output_as_def}{qw(format can_file_cache)};
	my $this_test_file_cache = $can_file_cache && $test_file_cache;
	my $this_file_cache_tests = $this_test_file_cache ? $file_cache_tests_per_format : 0;
    SKIP: {
	    skip "No mapserver tests", 2 + $this_file_cache_tests
		if $output_as eq 'mapserver' && $skip{mapserver};
	    skip "No palmdoc tests", 4 + $this_file_cache_tests
		if $output_as eq 'palmdoc' && $skip{palmdoc};

	    my $url = "$action?startname=Dudenstr.&startplz=10965&startc=9222%2C8787&zielname=Grimmstr.+%28Kreuzberg%29&zielplz=10967&zielc=11036%2C9592&pref_seen=1&output_as=$output_as";
	    my($content, $resp) = std_get $url, testname => "Route result output_as=$output_as";
	    if ($output_as eq '' || $output_as eq 'print') {
		is $resp->content_type, 'text/html', "Expected content type";
		my $len = extract_length($content);
		ok $len && $len > 0, "Length text found";
		# minor changes in the data may change the initial direction,
		# both "Osten" and "Norden" already happened
		like_html $content, qr/nach\s+(Norden|Osten)/, "Direction is correct";
		like_html $content, qr/angekommen/, "End of route list found";
	    } elsif ($output_as eq 'palmdoc') {
		is $resp->header("content-type"), 'application/x-palm-database', "Correct mime type for palmdoc";
		BBBikeTest::like_long_data($content, qr/Dudenstr/, "Expected palmdoc content", '.pdb');
		like $resp->header('Content-Disposition'), qr{attachment; filename=.*\.pdb$}, 'PDB filename';
	    } elsif ($output_as eq 'perldump') {
		is $resp->content_type, 'text/plain', "Correct mime type for perl dump";
	        like $resp->header('Content-Disposition'), qr{attachment; filename=.*\.txt$}, 'Perl dump has .txt extension';
		my $route = $cpt->reval($content);
		is ref $route, 'HASH', "perldump is a hash";
		is ref $route->{Route}, 'ARRAY', "Route member found";
		like $route->{Route}[0]{DirectionString}, qr/nach\s+(Norden|Osten)/,
		    "Direction is correct";
		like $route->{Route}[0]{Direction}, qr{^[NE]$}, # see above about initial direction
		    "Raw direction is correct";
	    } elsif ($output_as eq 'mapserver') {
		is $resp->content_type, "text/html",
		   "Expected content-type for $output_as";
	    } elsif ($output_as eq 'xml') {
		like $resp->header('Content-Disposition'), qr{attachment; filename=.*\.xml$}, 'xml filename';
		xmllint_string($content, "xmllint check for $output_as");
		validate_bbbikecgires_xml_string($content, "schema check for output_as=$output_as");
	    } elsif ($output_as =~ m{^( gpx-track
				     |  gpx-route
				     )$}x) {
		like $resp->header('Content-Disposition'), qr{attachment; filename=.*\.gpx$}, 'gpx filename';
		is $resp->header("content-type"), 'application/gpx+xml', "The GPX mime type";
		gpxlint_string($content, "xmllint check with gpx schema for $output_as");
	    } elsif ($output_as eq 'kml-track') {
		is $resp->header("content-type"), 'application/vnd.google-earth.kml+xml', "The KML mime type";
		like $resp->header('Content-Disposition'), qr{attachment; filename=.*\.kml$}, 'kml filename';
		kmllint_string($content, "xmllint check for $output_as");
	    } elsif ($output_as =~ m{^(json|json-short|geojson|geojson-short)$}) {
		if ($output_as eq 'json') {
		    validate_bbbikecgires_json_string($content, 'json content');
		} else {
		    # json-short, geojson, and geojson-short are not valid against the bbbikecgires schema
		    require JSON::XS;
		    my $data = eval { JSON::XS::decode_json($content) };
		    my $err = $@;
		    ok $data, "Decoded JSON content"
			or diag $err;
		}
	    } elsif ($output_as =~ m{^yaml}) {
		if ($output_as eq 'yaml') {
		    validate_bbbikecgires_yaml_string($content, 'yaml content');
		} else {
		    # the yaml-short variant has no schema
		    require BBBikeYAML;
		    my $data = eval { BBBikeYAML::Load($content) };
		    my $err = $@;
		    ok $data, "Decoded YAML content"
			or diag $err;
		}
	    }
	    if ($this_test_file_cache) {
		my ($content2, $resp2) = std_get $url, testname => "2nd fetch";
		eq_or_diff $content2, $content, "2nd fetch content equals ($output_as)";
		is $resp2->content_type, $resp->content_type, "2nd fetch has same content-type ($output_as)";
		is $resp2->header('x-bbbike-file-cache'), 'HIT', 'X-BBBike-File-Cache seen';
	    }
	}
    }

    {
	# Combine places with same coordinates
	my $content = std_get "$action?start=zoo", testname => 'Zoo';
	if ($content =~ m{Zoologischer Garten \[Elefantentor\]}) {
	    # Since 2011-08 there is no one point matching this query,
	    # but two for each entrance to the zoo. The "combine
	    # places with same coordinates" feature is probably still
	    # tested, because "Zoo" and "Zoologischer Garten [Eingang
	    # Hardenbergplatz]" with the same coordinate is still
	    # there.
	    like_html $content, qr/start2.*Zoologischer Garten.*Elefantentor/, "First alternative is Zoologischer Garten Elefantentor";
	    # In perls < 5.18 the response was always "Zoo". Since
	    # perl 5.18 and hash randomization it maybe be either one
	    # of the two names for the coordinate 5698,11333
	    like_html $content, qr/start2.*(\bZoo\b|Zoologischer Garten.*Eingang Hardenbergplatz)/, "Second alternative is either 'Zoo' or explicitely the entrance Hardenbergplatz";
	} else {
	    like_html $content, qr/Start.*Zoologischer Garten/, "Start is Zoologischer Garten";
	    unlike_html $content, qr/\bZoo\b/, "Zoo not found (same point optimization)";
	}
	unlike_html $content, qr/\(\)/, "No empty parenthesis";
    }

    {
	# Start and goal are in plaetze
	my $content = std_get "$action?start=rio-reiser-platz&starthnr=&startcharimg.x=&startcharimg.y=&startmapimg.x=&startmapimg.y=&via=&viahnr=&viacharimg.x=&viacharimg.y=&viamapimg.x=&viamapimg.y=&ziel=gesundbrunnen&zielhnr=&zielcharimg.x=&zielcharimg.y=&zielmapimg.x=&zielmapimg.y=&scope=", testname => "Rio-Reiser-Platz - Gesundbrunnen";
	like_html $content, qr/Start.*startc.*startname.*Rio-Reiser-Platz/, "Start is Rio-Reiser-Platz"
	    or diag "Test may fail if start is not in file plaetze";
	like_html $content, qr/Ziel.*zielc.*zielname.*Gesundbrunnen/, "Goal is Gesundbrunnen"
	    or diag "Test may fail if goal is not in file plaetze";
    }

    {
	# search_coord in and to Potsdam
	my $content = std_get "$action?startname=Alemannenstr.+%28Nikolassee%29&startplz=14129&startc=-3360%2C2917&zielc=-11833%2C-63&zielname=Helmholtzstr.+%28Potsdam%29&zielplz=&pref_seen=1&pref_speed=21&pref_cat=&pref_quality=&pref_ampel=yes&scope=", testname => "Berlin => Potsdam";
	like_html $content, qr/angekommen/, "Angekommen!";
    }

    {
	my $content = std_get "$action?zielname=Alemannenstr.+%28Nikolassee%29&zielplz=14129&zielc=-3360%2C2917&startc=-11833%2C-63&startname=Helmholtzstr.+%28Potsdam%29&startplz=&pref_seen=1&pref_speed=21&pref_cat=&pref_quality=&pref_ampel=yes&scope=", testname => "Potsdam => Berlin";
	like_html $content, qr/angekommen/, "Angekommen!";
    }

    {
	my $content = std_get "$action?zielname=Nuthewinkel+%28Potsdam%29&zielplz=&zielc=-11225%2C-2878&startc=-11833%2C-63&startname=Helmholtzstr.+%28Potsdam%29&startplz=&pref_seen=1&pref_speed=21&pref_cat=&pref_quality=&pref_ampel=yes&scope=", testname => "Potsdam => Potsdam";
	like_html $content, qr/angekommen/, "Angekommen!";
    }

 XXX: 
    {
	my $content = std_get "$action?startc_wgs84=13.028141,52.390967", testname => "Crossing in Potsdam, direct wgs84 coordinate";
	like_html $content, qr{\QKastanienallee/Kantstr. (Potsdam)}, "Found crossing name";
    }

    {
	my $content = std_get "$action?startc_wgs84=13.971133,53.924910", testname => "Crossing in wide region, direct wgs84 coordinate";
	like_html $content, qr{\QMorgenitz - Krienke/Suckow - Morgenitz/Morgenitz - Mellenthin}, "Found crossing name";
    }

    {
	my $content = std_get "$action?startc_wgs84=10.039791,54.623759", testname => "Crossing outside BBBike scope, direct wgs84 coordinate";
	like_html $content, qr{N 54\.6237\d+ / O 10\.03979\d+}, "Found coordinate without crossing name";
    }

 SKIP: {
	# this is critical --- both streets in the neighborhood of Berlin
	my $route = std_get_route "$action?startc=-12064%2C-284&zielc=-11831%2C-70&startname=Otto-Nagel-Str.+%28Potsdam%29&zielname=Helmholtzstr.+%28Potsdam%29&pref_seen=1&pref_speed=21&pref_cat=&pref_quality=&output_as=perldump", testname => "Otto-Nagel => Manger (Potsdam)";
	skip "No hash, no further checks", 1 if !$route;
	ok $route->{Len} > 0 && $route->{Len} < 500, "check route length"
	    or diag "Route length: $route->{Len} too large, Route is " . Dumper($route->{Route});
    }

 SKIP: {
	# this had once an empty route as the result:
	my $route = std_get_route "$action?startname=Mangerstr.+%28Potsdam%29&startplz=&startc=-12236%2C-447&zielname=Berliner+Allee&zielplz=13088&zielc=13332%2C15765&pref_seen=1&pref_speed=21&pref_cat=&pref_quality=&scope=region&output_as=perldump", testname => "Manger => Berliner Allee";
	skip "No hash, no further checks", 1 if !$route;
	ok $route->{Len} > 30000 && $route->{Len} < 35000, "check route length"
	    or diag "Route length: $route->{Len}";
    }

 SKIP: {
	# scope=region gets lost in "R�ckweg". bbbike.cgi should handle
	# this case:
	my $route = std_get_route "$action?startc=13332%2C15765&zielc=-12236%2C-447&startname=Berliner+Allee&zielname=Mangerstr.+%28Potsdam%29&pref_seen=1&pref_speed=21&pref_cat=&pref_quality=&output_as=perldump", testname => 'way back';
	skip "No hash, no further checks", 1 if !$route;
	ok $route->{Len} > 30000 && $route->{Len} < 35000, "check route length"
	    or diag "Route length: $route->{Len}";
    }

    {
	# Test comments_points (category 0, CARRY) (as part of Bemerkungen)
	my $content = std_get "$action?startname=Sonntagstr.&startplz=10245&startc=14798%2C10985&zielname=Markgrafendamm&zielplz=10245&zielc=14794%2C10844&pref_seen=1&pref_speed=20&pref_cat=&pref_quality=&scope=", testname => 'Tragen test';
	like_html $content, qr/(Sekunden|Minuten).*Zeitverlust/, "Zeitverlust in text";
    }

    {
	# Test comments_points (category BNP, NARROWPASSAGE) (as part of Bemerkungen)
	my $content = std_get "$action?startc=9662%2C10345&startplz=10969&startname=Mehringplatz&zielname=Brachvogelstr.&zielplz=10961&zielc=10059%2C10147&scope=&pref_seen=1&pref_speed=12&pref_cat=N1&pref_quality=Q2&pref_ampel=yes&pref_green=&pref_fragezeichen=yes", testname => "Dr�ngelgitter test";
	like_html $content, qr/Dr.*ngelgitter.*(Sekunden|Minuten).*Zeitverlust/, "Zeitverlust in text";
    }

 SKIP: {
	# This is only correct with use_exact_streetchooser=true
	my $route = std_get_route "$action?startc=13332%2C15765&zielc=-10825,-62&startname=Berliner+Allee&zielname=Babelsberg+%28Potsdam%29&pref_seen=1&pref_speed=21&pref_cat=&pref_quality=&output_as=perldump&scope=", testname => "use exact streetchooser";
	skip "No hash, no further checks", 2 if !$route;
	ok $route->{Len} > 30000 && $route->{Len} < 35000, "check route length"
	    or diag "Route length: $route->{Len}";
	ok((grep { $_->{Strname} =~ /Park Babelsberg/ } @{ $route->{Route} }),
	   "Route through Park Babelsberg")
	    or diag "Route not through Park Babelsberg: " . Dumper($route->{Route});
    }

 SKIP: {
	# This created degenerated routes because of missing handling of "B"
	# (Bundesstra�en) category
	my $route = std_get_route "$action?startname=Otto-Nagel-Str.+%28Potsdam%29&startplz=&startc=-11978%2C-348&zielname=Sonntagstr.&zielplz=10245&zielc=14598%2C11245&scope=region&pref_seen=1&pref_speed=20&pref_cat=N2&pref_quality=&output_as=perldump", testname => "Bundesstra�en handled OK";
	skip "No hash, no further checks", 1 if !$route;
	ok($route->{Len} > 30000 && $route->{Len} < 40000,
	   "check route length")
	    or diag "Route length: $route->{Len}, Route is " . Dumper($route->{Route});
    }

    {
	# optimal route crosses Berlin border
	my $content = std_get "$action?startname=Kirchhainer+Damm&startplz=12309&startc=11172%2C-2224&zielname=Zwickauer+Damm&zielplz=12353%2C+12355&zielc=15540%2C1235&pref_seen=1&pref_speed=26&pref_cat=&pref_quality=&pref_green=&pref_fragezeichen=yes&scope=", testname =>  "Kirchhainer Damm - Zwickauer Damm";
	like_html $content, qr/(Lichtenrader Chaussee|\(Lichtenrade -\) Gro�ziethen)/, "Shorter route through Gro�ziethen";
	like_html $content, qr/\(Gro�ziethen -\) Rudow/, "Shorter route through Gro�ziethen";
    }

    {
	# optimal route crosses Berlin border (using upgrade_scope_hint)
	# Falkenseer Platz -> Ruppiner Chaussee
	my $content = std_get "$action?startc=-3220%2C14716&pref_seen=1&zielc=-1287%2C23752",
	                      testname => "Falkenseer Platz - Ruppiner Chaussee";
	like_html $content, qr/(An der Havel|\(Spandau -\) Hennigsdorf)/, "Shorter route on the western side of the Havel";
	unlike_html $content, qr/Maienwerderweg/, "Not using the eastern side of the Havel";
	my $len = extract_length($content);
	cmp_ok $len, "<=", 14.5, "Shorter route"; # longer (eastern) route: 14.6km
    }

    {
	# optimal route crosses Berlin border (using upgrade_scope_hint)
	# Wannsee -> Kladow
	my $content = std_get "$action?startc=-4869%2C1389&pref_seen=1&zielc=-7108%2C5072", testname => "Wannsee - Kladow";
	like_html $content, qr/(Nedlitzer Str|Gutsstr)/, "Shorter route via Potsdam and Sacrow";
	unlike_html $content, qr/Heerstr/, "Not using the eastern side of the Havel";
	my $len = extract_length($content);
	cmp_ok $len, "<=", 22.0, "Shorter route"; # longer (eastern) route: 22.2km
    }

    {
	# Test "inaccessible" feature
	my $inacc_xy = "21306,381"; # B96a
	std_get_route "$action?startname=Somewhere&startc=" . uri_escape($inacc_xy) . "&zielname=Sonntagstr.&zielplz=10245&zielc=14598%2C11245&scope=region&pref_seen=1&pref_speed=20&pref_cat=N2&pref_quality=&output_as=perldump", testname => 'test "inaccessible" feature';
	# Just checked if $route is valid
    }

    {
	my $content = std_get "$action?start=duden&via=&ziel=guben", testname => "Guben vs. Gubener Str.";
	like_html $content, qr/Gubener Str./, "Gubener Str. found";
    }

    {
	# Test "ImportantAngleCrossingName"
	my $content = std_get "$action?startc=23085%2C898;pref_quality=;startplz=12527;pref_speed=20;startname=Regattastr.;pref_specialvehicle=;zielname=Sportpromenade;pref_seen=1;zielplz=12527;zielc=25958%2C-731;pref_cat=;pref_green=;scope=", testname => 'test "ImportantAngleCrossingName" feature';
	like_html $content, qr/\QRegattastr. (Ecke Rabindranath-Tagore-Str.)/, 'found "ImportantAngleCrossingName" feature';
    }

    {
	# Another test for "ImportantAngleCrossingName"
	# B�lowstr. am Dennewitzplatz
	my $content = std_get "$action?startc=7938%2C9694&pref_seen=1&zielc=7813%2C10112",
	                      testname => 'test "ImportantAngleCrossingName" feature (Dennewitzplatz)';
	like_html $content, qr/weiter auf der.*B.*lowstr\. \(Ecke Alvenslebenstr\.\)/,
	          'stripped citypart from ImportantAngleCrossingName';
	like_html $content, qr/weiter auf der.*B.*lowstr\. \(Ecke Dennewitzstr\.\)/,
	          'second ImportantAngleCrossingName';
    }

    {
	# Test possible "Aktuelle Position verwenden" flows
	my($x,$y) = (10923,13156);

	{
	    my $content = std_get "$action?start=Alexanderstr.%2FKarl-Liebknecht-Str.&startort=&startcharimg.x=&startcharimg.y=&startc=$x%2C$y&scvf=Alexanderstr.%2FKarl-Liebknecht-Str.&startmapimg.x=&startmapimg.y=&via=&viaort=&viacharimg.x=&viacharimg.y=&viamapimg.x=&viamapimg.y=&ziel=&zielort=&zielcharimg.x=&zielcharimg.y=&zielmapimg.x=&zielmapimg.y=&scope=";
	    like_html $content, qr{Alexanderstr./Karl-Liebknecht-Str.}, 'Preserved geolocated position';
	    like_html $content, qr{startc value="$x,$y"}, 'Found startc position';
	}

	{
	    my $content = std_get "$action?start=Dudenstr.&startort=&startcharimg.x=&startcharimg.y=&startc=$x%2C$y&scvf=Alexanderstr.%2FKarl-Liebknecht-Str.&startmapimg.x=&startmapimg.y=&via=&viaort=&viacharimg.x=&viacharimg.y=&viamapimg.x=&viamapimg.y=&ziel=&zielort=&zielcharimg.x=&zielcharimg.y=&zielmapimg.x=&zielmapimg.y=&scope=";
	    like_html $content, qr{Dudenstr.}, 'Geolocated position not preserved, user changed his mind';
	    unlike_html $content, qr{startc value="}, 'startc element does NOT exist';
	}

	{
	    my $content = std_get "$action?start=Alexanderstr.%2FKarl-Liebknecht-Str.&startort=&startcharimg.x=&startcharimg.y=&startc=&scvf=&startmapimg.x=&startmapimg.y=&via=&viaort=&viacharimg.x=&viacharimg.y=&viamapimg.x=&viamapimg.y=&ziel=&zielort=&zielcharimg.x=&zielcharimg.y=&zielmapimg.x=&zielmapimg.y=&scope=";
	    like_html $content, qr{Alexanderstr./Karl-Liebknecht-Str.}, 'Recalculated geolocated position';
	    like_html $content, qr{startc value="$x,$y"}, 'Found startc position (new geocoding)';
	}

	{
	    my $content = std_get "$action?start=Alexanderstr.&startort=&startcharimg.x=&startcharimg.y=&startc=&scvf=&startmapimg.x=&startmapimg.y=&via=&viaort=&viacharimg.x=&viacharimg.y=&viamapimg.x=&viamapimg.y=&ziel=Dudenstr.&zielort=&zielcharimg.x=&zielcharimg.y=&zielmapimg.x=&zielmapimg.y=&scope=";
	    like_html $content, qr{Alexanderstr.}, 'Normal street search';
	    unlike_html $content, qr{startc value="}, 'startc element does NOT exist';
	}
    }

    {
	# Klick on "D" in Start A..Z
	my $content = std_get "$action?start=&startcharimg.x=107&startcharimg.y=15&startmapimg.x=&startmapimg.y=&via=&viacharimg.x=&viacharimg.y=&viamapimg.x=&viamapimg.y=&ziel=&zielcharimg.x=&zielcharimg.y=&zielmapimg.x=&zielmapimg.y=", testname => "Click on D in A..Z";
	like_html $content, qr/Anfangsbuchstabe.*D/, "Initial letter is D";
	like_html $content, qr/Dudenstr/, "Dudenstr. is in D section";
	like_html $content, qr/\QDortustr. (Potsdam)/, "There are also Potsdam streets";
	unlike_html $content, qr/\QDorfstr. (Heinersdorf)/, "But no other streets in Brandenburg";
    }

    {
	# Klick on "B" in Start A..Z
	my $content = std_get "$action?start=&startcharimg.x=44&startcharimg.y=15&startmapimg.x=&startmapimg.y=&via=&viacharimg.x=&viacharimg.y=&viamapimg.x=&viamapimg.y=&ziel=&zielcharimg.x=&zielcharimg.y=&zielmapimg.x=&zielmapimg.y=", testname => "Click on B in A..Z";
	like_html $content, qr/\QBerliner Str. (Potsdam)/, "Stripped `B1' from street name";
	like_html $content, qr/\QBaumhaselring (Potsdam-Eiche)/, "Found street in Potsdam-Eiche";
    }

 SKIP: {
	# Klick on Start berlin map (Kreuzberg)
	my $content = std_get "$action?start=&startcharimg.x=107&startcharimg.y=15&startmapimg.x=90&startmapimg.y=107&via=&viacharimg.x=&viacharimg.y=&viamapimg.x=&viamapimg.y=&ziel=&zielcharimg.x=&zielcharimg.y=&zielmapimg.x=&zielmapimg.y=", testname => "Click on overview map";
	my $map_qr = qr{(http://.*/bbbike.*(?:tmp|\?tmp=)/berlin_map_04-05(?:_240|_280x240)?.png)}i;
	like_html $content, $map_qr, "Found map image source";
	my($image_url) = $content =~ $map_qr;
	my $resp;
	($content, $resp) = std_get $image_url;
	is $resp->header("content-type"), 'image/png', "$image_url is a PNG";
	cmp_ok length($content), ">", 0, "Image is non-empty";
    }

    {
	# Klick on Info link
	std_get "$action?info=1", testname => "Click on info link";
    }

    {
	# Info page through pathinfo
	my $content = std_get "$action/info=1", testname => "Info page through pathinfo";
	like_html $content, qr/Link auf BBBike setzen/, "Is it really the info page?";
    }

 SKIP: {
	# Klick on Mapserver link
	my $tests = 6;
	skip "No mapserver tests", $tests
	    if $skip{mapserver};
	skip "Does not work with CGI::MiniSvr", $tests
	    if $cgiurl =~ /bbbike-fast.cgi/;

	my($content, $resp) = std_get "$action?mapserver=1", testname => "Click on mapserver link";
	like_html $content, qr/Darzustellende Ebenen/, "Layers headline";

	skip "Cannot get map image reference in $action?mapserver=1", 4
	    if $content !~ qr|SRC="(.*/mapserver/brb/tmp/brb.*.png)"|;
	    
	pass "Found image reference on mapserver page";
	my $u1 = URI::WithBase->new($1, $resp->base);
	my $image_url = $u1->abs;

	($content, $resp) = std_get $image_url;
	is $resp->header("content-type"), 'image/png', "$image_url is a PNG";
	cmp_ok length($content), ">", 0, "Image is non-empty";
    }

    {
	# Klick on "alle Stra�en" link
	my $content = std_get "$action?all=1", testname => "Click on all streets link";
	like_html $content, qr/B(?:�|&ouml;|&#246;)lschestr.*Brachvogelstr.*(?:�|&Ouml;|&#214;)schelbronner(?:.|&#160;)Weg.*Pallasstr/s, "Correct sort order";
    }
    
    for my $imagetype_def (@imagetype_defs) {
	my($imagetype, $can_file_cache) = @{$imagetype_def}{qw(format can_file_cache)};
	my $this_test_file_cache = $can_file_cache && $test_file_cache;
	my $this_file_cache_tests = $this_test_file_cache ? $file_cache_tests_per_format : 0;

    SKIP: {
	    skip "No mapserver tests", 3 + $this_file_cache_tests
		if $imagetype eq 'mapserver' && $skip{mapserver};

	    my $imagetype_param = ($imagetype ne "" ? "imagetype=$imagetype&" : "");
	    # This coords are sensitive to changes if
	    # search_algorithm=C-A*-2 is used. Expect failures in this
	    # case and try to fix the coords list.
	    my $url = "$action?${imagetype_param}coords=9222%2C8787%219227%2C8890%219796%2C8905%219799%2C8962%219958%2C8966%219962%2C9237%219987%2C9238%2110109%2C9240%2110189%2C9403%2110298%2C9649%2110345%2C9764%2110408%2C9800%2110480%2C9949%2110503%2C10046%2110490%2C10080%2110511%2C10128%2110605%2C10312%2110859%2C10333%2110962%2C10340%2111114%2C10338%2111336%2C10390%2111370%2C10398%2111454%2C10400%2111660%2C10402%2111949%2C10414%2112230%2C10437%2112274%2C10436%2112328%2C10442%2112755%2C10552%2112899%2C10595%2112980%2C10575%2113035%2C10635%2113082%2C10634%2113178%2C10623%2113216%2C10664%2113297%2C10781%2113332%2C10832%2113409%2C11004%2113546%2C11352%2113594%2C11489%2113720%2C11459%2113890%2C11411%2114139%2C11269%2114211%2C11229%2114286%2C11186%2114442%2C11101%2114509%2C11060%2114677%2C11027%2114752%2C11041%2114798%2C10985&startname=Dudenstr.&zielname=Sonntagstr.&windrichtung=E&windstaerke=2&geometry=400x300&draw=str&draw=wasser&draw=flaechen&draw=ampel&draw=strname&draw=title&draw=all";
	    my($content, $resp) = std_get $url, testname => "imagetype=$imagetype";
	    if ($imagetype eq 'gif') {
		is $resp->header("content-type"), 'image/gif', "It's a GIF image";
		BBBikeTest::like_long_data($content, qr/^GIF8/, "Really a GIF image")
			or diag "Not a gif: $url";
		display($resp);
	    } elsif ($imagetype =~ /(png|jpeg)/) {
		is $resp->header("content-type"), 'image/' . $imagetype, "It's a $imagetype image";
		ok length $content, "The image is non-empty";
		display($resp);
	    } elsif ($imagetype =~ /pdf/) {
		is $resp->header("content-type"), 'application/pdf', "It's a PDF";
		ok length $content, "The PDF is non-empty";
		display($resp);
		like $resp->header('Content-Disposition'), qr{inline; filename=.*\.pdf$}, 'PDF filename'; # unfortunately in this case (missing session?) there's no nice filename from route start/endpoint
	    } elsif ($imagetype =~ /svg/) {
		is $resp->header("content-type"), "image/svg+xml", "It's a SVG image";
		ok length $content, "The SVG is non-empty";
		display($resp);
	    } else {
		like $resp->content_type, qr{^text/html}, "It's a $imagetype";
		ok length $content, "The $imagetype is non-empty";
	    }

	    if ($this_test_file_cache) {
		my($content2, $resp2) = std_get $url, testname => "imagetype=$imagetype (2nd possibly cached fetch)";
		ok $content2 eq $content, "2nd fetch content equals ($imagetype)";
		is $resp2->content_type, $resp->content_type, "2nd fetch has same content-type ($imagetype)";
		is $resp2->header('x-bbbike-file-cache'), 'HIT', 'X-BBBike-File-Cache seen';
	    }
	}
    }

    {
	# Semantik ein bisschen testen:
	my $route = std_get_route"$action?startname=Dudenstr.&startplz=10965&startc=8982%2C8781&zielname=Sonntagstr.&zielplz=10245&zielc=14598%2C11245&pref_seen=1&pref_speed=20&pref_cat=&pref_quality=&output_as=perldump", testname => "Route request";
	for my $h_member (qw(Speed Power)) {
	    is ref $route->{$h_member}, "HASH", "$h_member existant";
	}
	for my $a_member (qw(Route LongLatPath Path)) {
	    is ref $route->{$a_member}, "ARRAY", "$a_member existant";
	    cmp_ok @{$route->{$a_member}}, ">", 0;
	}
	is scalar(@{$route->{LongLatPath}}), scalar(@{$route->{Path}}),
	    "Both Path arrays have same length";

    TRY: {
	    for my $xy (@{$route->{Route}}) {
		if (ref $xy ne 'HASH') {
		    fail "Route elem should be hash";
		    last TRY;
		}
		if (exists $xy->{Direction} &&
		    $xy->{Direction} !~ /^([NS]?[EW]|[NS]|h?[lr]|)$/) {
		    fail "Unexpected direction: $xy->{Direction}";
		    last TRY;
		}
		if ($xy->{Coord} !~ /^[+-]?\d+,[+-]?\d+$/) {
		    fail "Wrong Coord format: $xy->{Coord}";
		    last TRY;
		}
	    }
	    pass "Directions and Coords OK";
	}

	TRY: {
	    for my $xy (@{$route->{LongLatPath}}) {
		if ($xy !~ /^13\..*,52\..*$/) {
		    fail "Wrong coord format: $xy";
		    last TRY;
		}
	    }
	    pass "LongLatPath check OK, everything seems to be coordinates in Berlin";
	}

	for my $s (qw(Methfesselstr Skalitzer Sonntagstr)) {
	    ok((grep { $_->{Strname} =~ /$s/ } @{$route->{Route}}),
	       "Street $s expected in route");
	}
	ok $route->{Len} > 7000 && $route->{Len} < 8000, "check route length"
	    or diag "Route length: $route->{Len}";
    }

    {
	my $content = std_get "$action?" .
	    CGI->new({startc=>"42685,19584",
		      zielc=>"-8063,17487",
		      scope=>"region", # why needed?
		     })->query_string,
	    testname => "Request with crossings in region";
	like_html $content, qr{\QWallstr./Karl-Liebknecht-Str./August-Bebel-Str./Gro�e Str. (Strausberg)\E}, "Simplified crossing";
	like_html $content, qr{\QHumboldtallee/Haydnallee/Fr�belstr. (Falkensee)}, "Simplified crossing (goal)";
    }

    {
	my $content = std_get "$action?" .
	    CGI->new({startc=>"9222,8787",
		      zielc=>"-502,-803",
		      scope=>"region", # why needed?
		     })->query_string,
	    testname => "Another request with crossings";
	like_html $content, qr{\QDudenstr./Mehringdamm/Platz der Luftbr�cke/Tempelhofer Damm\E}, "No simplification for Berlin crossings needed";
	like_html $content, qr{\QThomas-M�ntzer-Damm (Kleinmachnow)/Warthestr. (Teltow)\E}, "No simplification possible between different places";
    }

    {
	my %common_args = ( startc=>'16428,7144',
			    zielc=>'17202,8391',
			    startname=>'Schnellerstr.',
			    zielname=>'Hegemeisterweg (Karlshorst)',
			    pref_speed=>20,
			    pref_seen=>1,
			  );
	{
	    my $content = std_get "$action?" .
		CGI->new({%common_args,
			  pref_ferry=>'use',
			 })->query_string,
		testname => 'Request with ferry=use';
	    like_html $content, qr{F11.*Baumschulenstr.*Wilhelmstrand}, 'Found use of ferry F11';
	    like_html $content, qr{(BVG-Tarif|BVG-Kurzstreckentarif|�berfahrt.*kostet)}, 'Found tariff information for ferry';
	}

	{
	    my $content = std_get "$action?" .
		CGI->new({%common_args,
			  pref_ferry=>'',
			 })->query_string,
		testname => 'Request without ferry=use';
	    unlike_html $content, qr{F11.*Baumschulenstr.*Wilhelmstrand}, 'No use of ferry F11';
	    unlike_html $content, qr{(BVG-Tarif|BVG-Kurzstreckentarif|�berfahrt.*kostet)}, 'No tariff information for ferry';
	}
    }

    {   # The "M�ller Breslau"-Bug (from the Berlin PM wiki page)
	#
	# The problem may happen with a bbbike.cgi link with just
	# "zielname" set to an inexact street name. If the user now
	# enters the start street, then under some circumstances the
	# crossing chooser is not presented for the start street
	#
	# More specifically, this happens because bbbike.cgi
	# determines that there's zielname without zielc (which
	# usually should not happen) and decides to restart to
	# choose_form(). Here finding a start street with multiple
	# zips (e.g. for "Invalidenstr") failed, because the
	# comma-separated zips were not properly split up into an
	# array ref for PLZ.pm

	my $content = std_get "$action?" .
	    CGI->new({ start => "invalidenstr",
		       zielname => "m�ller-breslau-str",
		     })->query_string,
	    testname => "The Mueller-Breslau request";
	like_html $content, qr{Invalidenstr\..*Ecke.*M�ller-Breslau-Str\..*Ecke}s, "'Ecke' for both crossings";
    }

    {   # All street types (as defined in PLZ.pm) except "streets"
        # should provide automatically the nearest crossing to the
        # Berlin.coords.data coordinate. Note that this should also
        # happen for railway stations --- this is already tested in
        # cgi-mechanize.t

	my $content = std_get "$action?" .
	    CGI->new({ start2 => 'Westend (Kolonie)!Westend!14050!935,12882!0', # note: multiple results with "Westend"
		       via    => 'Weinbergsh�he',
		       ziel2  => 'Eiswerder (Insel)!Hakenfelde!13585!-2318,15601!0', # note: multiple results with "Eiswerder"
		       scope  => 0,
		     })->query_string,
	    testname => 'Westend/Weinbergshoehe/Eiswerder';
	like_html $content, qr{   Die[ ]n�chste[ ]Kreuzung[ ]ist.*
				  Die[ ]n�chste[ ]Kreuzung[ ]ist.*
				  Die[ ]n�chste[ ]Kreuzung[ ]ist
			  }xs, 'Find automatically next crossing for non-streets';
    }

#     {
# 	# fragezeichen streets not in crossing
# 	$req = HTTP::Request->new
# 	    ('GET', "$action?" . CGI->new({startc=>'-1179,-298',
# 					   zielname=>'Dudenstr.',
# 					   zielplz=>10965,
# 					   zielc=>'9222,8787',
# 					   pref_seen=>1,
# 					   pref_speed=>26,
# 					   pref_cat=>'',
# 					   pref_quality=>'Q2',
# 					   pref_green=>'',
# 					   pref_fragezeichen=>'yes',
# 					   scope=>'region',
# 					  })->query_string);
# 	$res = $ua->request($req);
# 	ok($res->is_success, "Another request with pref_fragezeichen=yes")
# 	    or diag(Dumper($res));
# 	$content = uncompr($res);
# 	unlike($content, qr{Route von.*Qualit.*?t zwischen}, "No fragezeichen text found");
# 	like($content, qr{fragezeichenform.*Qualit.*?t.*zwischen}, "But fragezeichenform link is there");
#     }

    {
	# opensearch search params
	my $resp;

	$resp = $ua->get($cgiurl . "?" . CGI->new({ossp => 'dudenstr'})->query_string);
	ok($resp->is_success, "ossp with start");
	like_html $resp->content, qr{startname.*Dudenstr}, 'single start, street';
	like_html $resp->content, qr{startplz.*10965},     'single start, zip';

	$resp = $ua->get($cgiurl . "?" . CGI->new({ossp => '"unter den linden"'})->query_string);
	ok($resp->is_success, "ossp with start with spaces");
	like_html $resp->content, qr{startname.*Unter den Linden}, 'quoted start, street';
	like_html $resp->content, qr{startplz.*10117},             'quoted start, zip';

	$resp = $ua->get($cgiurl . "?" . CGI->new({ossp => 'dudenstr seumestr'})->query_string);
	ok($resp->is_success, "ossp with start and goal");
	like_html $resp->content, qr{startname.*Dudenstr},     'start and goal, start';
	like_html $resp->content, qr{zielname.*Seumestr},      'start and goal, goal';
	like_html $resp->content, qr{Genaue Kreuzung angeben}, 'crossing text';

	$resp = $ua->get($cgiurl . "?" . CGI->new({ossp => '  "unter den lind"    "habelschwerdter alle"'})->query_string);
	ok($resp->is_success, "ossp with start and goal and spaces");
	like_html $resp->content, qr{startname.*Unter den Linden},     'partial start';
	like_html $resp->content, qr{zielname.*Habelschwerdter Allee}, 'partial goal';
	like_html $resp->content, qr{Genaue Kreuzung angeben},         'crossing text';

	$resp = $ua->get($cgiurl . "?" . CGI->new({ossp => 'dudenstr "unter den linden" seumestr'})->query_string);
	ok($resp->is_success, "ossp with start, via and goal");
	like_html $resp->content, qr{startname.*Dudenstr},       '*start* via goal';
	like_html $resp->content, qr{vianame.*Unter den Linden}, 'start *via* goal';
	like_html $resp->content, qr{zielname.*Seumestr},        'start via *goal*';
	like_html $resp->content, qr{Genaue Kreuzung angeben},   'crossing text';
    }

    {
	if ($CGI::VERSION == 3.33) {
	    # but see below for other bad CGI versions...
	    diag <<EOF;
Check if Umlaute are correctly preserved. This breaks with
the CGI.pm in perl 5.10.0 (3.33) and must be seen as a CGI.pm
problem. It seems to be solved with CGI 3.34, so please
upgrade!
EOF
	}

	# Do not use CGI.pm here, because it is known to have issues!
	my %params = (startc=>"9322,11487",
		      zielc=>"9126,12413",
		      startname=>"Mauerstr. (Mitte)/Krausenstr.",
		      zielname=>"Neust�dtische Kirchstr./Mittelstr. (Mitte)",
		      pref_seen=>1,
		     );
	my $url = $cgiurl . "?" . join("&", map { "$_=" . my_uri_escape($params{$_}) } keys %params);
	my $content = std_get $url, testname => "Request with latin1 incoming CGI params";
	diag "URL: $url" if $v;
	my $fail_count;
	$fail_count++ if !like_html $content, qr{Neust%e4dtische}i, "Found iso-8859-1 encoding in CGI params in links";
	$fail_count++ if !unlike_html $content, qr{Neust%C3%A4dtische}i, "No single encoded utf-8 in CGI params in links";
	$fail_count++ if !unlike_html $content, qr{Neust%C3%83%C2%A4dtische}i, "No double encoded utf-8 in CGI params in links";
	if ($fail_count) {
	    if ($] >= 5.010 && $CGI::VERSION < 3.48) {
		# ... but see above for other bad CGI versions
		diag <<EOF;
Locally CGI.pm $CGI::VERSION is installed, remote maybe too?
Consider to upgrade to at least CGI.pm 3.47.
EOF
	    }
	}
    }

    {
	# gple (GooglePolylineEncoding) - pdf
	my(undef, $resp) = std_get $cgiurl . '?gple=gap_I%7BsspAI_DIcCM%7BFSqF&imagetype=pdf-auto&draw=str&draw=sbahn&draw=ubahn&draw=wasser&draw=flaechen&draw=ampel';
	is $resp->content_type, 'application/pdf', "gple input - pdf output";
	display($resp);
    }

    {
	# gple (GooglePolylineEncoding) - gif
	my $url = $cgiurl . '?gple=gap_I%7BsspAI_DIcCM%7BFSqF&imagetype=gif&draw=str&draw=sbahn&draw=ubahn&draw=wasser&draw=flaechen&draw=ampel';
	my($content, $resp) = std_get $url;
	is $resp->content_type, 'image/gif', "gple input - gif output";
	BBBikeTest::like_long_data($content, qr/^GIF8/, "Really a GIF image")
		or diag "Not a gif: $url";
	display($resp);
    }

    {
	# gpleu (GooglePolylineEncoding with URL safe character set) - pdf
	my(undef, $resp) = std_get $cgiurl . '?gpleu=gap_I7sspAI_DIcCM7FSqF&imagetype=pdf-auto&draw=str&draw=sbahn&draw=ubahn&draw=wasser&draw=flaechen&draw=ampel';
	is $resp->content_type, 'application/pdf', "gpleu input - pdf output";
	display($resp);
    }

    {
	my $content = std_get $cgiurl . "?scope=wideregion&detailmapx=2&detailmapy=6&type=start&detailmap.x=200&detailmap.y=226";
	like_html $content, qr{diese Koordinaten konnte keine Kreuzung gefunden werden}, "No crossing for coords in the D�beritzer Heide";
    }

    {
	my $content = std_get $cgiurl . "?scope=wideregion&detailmapx=3&detailmapy=8&type=start&detailmap.x=304&detailmap.y=331";
	like_html $content, qr{Rudolf-Breitscheid-Str}, "Crossing in Potsdam near Berlin, should get a street in Potsdam";
    }
}

sub display {
    my $res = shift;
    return if !$do_display;
    require File::Temp;
    my($fh, $filename) = File::Temp::tempfile(UNLINK => 1);
    my $content = uncompr($res);
    print $fh $content;
    if ($res->header('Content_Type') =~ m{^image/svg\+xml}i) {
	#XXX find a better viewer...
	system("svgviewer $filename &");
    } elsif ($res->header('Content_Type') =~ m{^image/}i) {
	system("xv $filename &");
    } elsif ($res->header('Content_Type') =~ m{^application/pdf}i) {
	system("xpdf $filename &");
    } else {
	warn "Can't display content type " . $res->header('Content_Type');
    }
}

# One test
sub std_get ($;@) {
    my($url, %opts) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $testname = delete $opts{testname} || "Requesting $url";
    die "Unhandled arguments: " . join(" ", %opts) if %opts;

    my $req = HTTP::Request->new('GET', $url, $default_hdrs);
    my $t0 = time;
    my $resp = $ua->request($req);
    my $dt = sprintf "%.3fs", time-$t0;
    ok $resp->is_success, "$testname (reqtime $dt)"
	or diag(Dumper($resp));
    my $content = uncompr($resp);
    wantarray ? ($content, $resp) : $content;
}

# Two tests
sub std_get_route ($;@) {
    my($url, %opts) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my($content, $resp) = std_get($url, %opts);
    my $route = $cpt->reval($content);
    validate_bbbikecgires_data($route, 'Validation');
    if (is ref $route, 'HASH', 'Route result is a HASH') {
	wantarray ? ($route, $resp) : $route;
    } else {
	wantarray ? (undef, $resp) : undef;
    }
}

sub uncompr {
    my $res = shift;
    if ($res->can("decoded_content")) {
	my %opts;
	if (!$res->can('content_is_xml') || $res->content_is_xml) {
	    # http://rt.cpan.org/Public/Bug/Display.html?id=52572
	    $opts{charset} = 'none';
	}
	$res->decoded_content(%opts);
    } else {
	# When was decoded_content part of LWP?
	# XXX without decoded_content charset-related errors are possible,
	# especially if utf-8 is used
	if (defined $res->header('Content_Encoding') &&
	    $res->header('Content_Encoding') eq 'gzip') {
	    Compress::Zlib::memGunzip($res->content);
	} else {
	    $res->content;
	}
    }
}

sub my_uri_escape {
    my $toencode = shift;
    return undef unless defined($toencode);
    $toencode=~s/([^a-zA-Z0-9_.~-])/uc sprintf("%%%02x",ord($1))/eg;
    return $toencode;
}

sub extract_length {
    my($content) = @_;
    my($len) = $content =~ /L.*nge:.*?(\d[\d.,]+).*km/;
    $len;
}

sub like_html ($$$) {
    my($content, $rx, $testname) = @_;
    local $Test::Builder::Level = $Test::Builder::Level+1;
    BBBikeTest::like_long_data($content, $rx, $testname, '.html');
}

sub unlike_html ($$$) {
    my($content, $rx, $testname) = @_;
    local $Test::Builder::Level = $Test::Builder::Level+1;
    BBBikeTest::unlike_long_data($content, $rx, $testname, '.html');
}
