#!/usr/local/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 1998,2000,2003,2004,2006,2010,2011,2012 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net/
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

use FindBin;
use lib ($FindBin::RealBin,
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);
use BBBikeTest qw(check_cgi_testing xmllint_string gpxlint_string kmllint_string validate_bbbikecgires_xml_string);

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

my $fast = 0;
my $ortsuche = 0; # XXX funktioniert nicht mehr
my $do_display = 0;
my $do_xxx;
my $do_accept_gzip = 1;
my $v = 0;
my %skip;

my $ua = new LWP::UserAgent;
$ua->agent("BBBike-Test/1.0");
$ua->env_proxy;

if (!GetOptions("cgiurl=s" => sub {
		    @urls = $_[1];
		},
		"fast!" => \$fast,
		"ortsuche!" => \$ortsuche,
		"display!" => \$do_display,
		"xxx" => \$do_xxx,
		"v!" => \$v,
		"skip-mapserver!" => \$skip{mapserver},
		"accept-gzip!" => \$do_accept_gzip,
	       )) {
    die "usage: $0 [-cgiurl url] [-fast] [-ortsuche] [-display] [-v] [-skip-mapserver] [-noaccept-gzip] [-xxx]";
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

my $ortsuche_tests = 11;
plan tests => (254 + $ortsuche_tests) * scalar @urls;

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

    # search_coord
    for my $output_as ("", qw(xml gpx-track gpx-route kml-track print perldump
			      yaml yaml-short json json-short geojson palmdoc mapserver)) {
    SKIP: {
	    skip "No mapserver tests", 2
		if $output_as eq 'mapserver' && $skip{mapserver};

	    my($content, $resp) = std_get "$action?startname=Dudenstr.&startplz=10965&startc=9222%2C8787&zielname=Grimmstr.+%28Kreuzberg%29&zielplz=10967&zielc=11036%2C9592&pref_seen=1&output_as=$output_as",
					 testname => "Route result output_as=$output_as";
	    if ($output_as eq '' || $output_as eq 'print') {
		is $resp->content_type, 'text/html', "Expected content type";
		my $len = extract_length($content);
		ok $len && $len > 0, "Length text found";
		# minor changes in the data may change the initial direction,
		# both "Osten" and "Norden" already happened
		like_html $content, qr/nach\s+(Norden|Osten)/, "Direction is correct";
		like_html $content, qr/angekommen/, "End of route list found";
	    } elsif ($output_as eq 'palmdoc') {
		is $resp->content_type, 'application/x-palm-database', "Correct mime type for palmdoc";
		BBBikeTest::like_long_data($content, qr/Dudenstr/, "Expected palmdoc content", '.pdb');
		like $resp->header('Content-Disposition'), qr{attachment; filename=.*\.pdb$}, 'PDB filename';
	    } elsif ($output_as eq 'perldump') {
		is $resp->content_type, 'text/plain', "Correct mime type for perl dump";
	        like $resp->header('Content-Disposition'), qr{attachment; filename=.*\.txt$}, 'Perl dump has .txt extension';
		my $route = $cpt->reval($content);
		is ref $route, 'HASH', "perldump is a hash";
		is ref $route->{Route}, 'ARRAY', "Route member found";
		like $route->{Route}[0]{DirectionString}, qr/nach\s+Osten/,
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
		gpxlint_string($content, "xmllint check with gpx schema for $output_as");
	    } elsif ($output_as eq 'kml-track') {
		is $resp->content_type, 'application/vnd.google-earth.kml+xml', "The KML mime type";
		like $resp->header('Content-Disposition'), qr{attachment; filename=.*\.kml$}, 'kml filename';
		kmllint_string($content, "xmllint check for $output_as");
	    } elsif ($output_as =~ m{^(json|geojson$)}) {
		require JSON::XS;
		my $data = eval { JSON::XS::decode_json($content) };
		my $err = $@;
		ok $data, "Decoded JSON content"
		    or diag $err;
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
	    like_html $content, qr/start2.*\bZoo\b/, "Second alternative is just Zoo (Hardenbergplatz)";
	} else {
	    like_html $content, qr/Start.*Zoologischer Garten/, "Start is Zoologischer Garten";
	    unlike_html $content, qr/\bZoo\b/, "Zoo not found (same point optimization)";
	}
	unlike_html $content, qr/\(\)/, "No empty parenthesis";
    }

    {
	# Start and goal are in plaetze
	my $content = std_get "$action?start=heinrichplatz&starthnr=&startcharimg.x=&startcharimg.y=&startmapimg.x=&startmapimg.y=&via=&viahnr=&viacharimg.x=&viacharimg.y=&viamapimg.x=&viamapimg.y=&ziel=gesundbrunnen&zielhnr=&zielcharimg.x=&zielcharimg.y=&zielmapimg.x=&zielmapimg.y=&scope=", testname => "Heinrichplatz - Gesundbrunnen";
	like_html $content, qr/Start.*startc.*startname.*Heinrichplatz/, "Start is Heinrichplatz"
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
	# scope=region gets lost in "Rückweg". bbbike.cgi should handle
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
	my $content = std_get "$action?startc=9662%2C10345&startplz=10969&startname=Mehringplatz&zielname=Brachvogelstr.&zielplz=10961&zielc=10059%2C10147&scope=&pref_seen=1&pref_speed=12&pref_cat=N1&pref_quality=Q2&pref_ampel=yes&pref_green=&pref_fragezeichen=yes", testname => "Drängelgitter test";
	like_html $content, qr/Dr.*ngelgitter.*(Sekunden|Minuten).*Zeitverlust/, "Zeitverlust in text";
    }

 SKIP: {
	# This is only correct with use_exact_streetchooser=true
	my $route = std_get_route "$action?startc=13332%2C15765&zielc=-10825,-62&startname=Berliner+Allee&zielname=Babelsberg+%28Potsdam%29&pref_seen=1&pref_speed=21&pref_cat=&pref_quality=&output_as=perldump&scope=", testname => "use exact streetchooser";
	skip "No hash, no further checks", 2 if !$route;
	ok $route->{Len} > 30000 && $route->{Len} < 35000, "check route length"
	    or diag "Route length: $route->{Len}";
	ok((grep { $_->{Strname} =~ /Park Babelbsberg/ } @{ $route->{Route} }),
	   "Route through Park Babelsberg")
	    or diag "Route not through Park Babelsberg: " . Dumper($route->{Route});
    }

 SKIP: {
	# This created degenerated routes because of missing handling of "B"
	# (Bundesstraßen) category
	my $route = std_get_route "$action?startname=Otto-Nagel-Str.+%28Potsdam%29&startplz=&startc=-11978%2C-348&zielname=Sonntagstr.&zielplz=10245&zielc=14598%2C11245&scope=region&pref_seen=1&pref_speed=20&pref_cat=N2&pref_quality=&output_as=perldump", testname => "Bundesstraßen handled OK";
	skip "No hash, no further checks", 1 if !$route;
	ok($route->{Len} > 30000 && $route->{Len} < 40000,
	   "check route length")
	    or diag "Route length: $route->{Len}, Route is " . Dumper($route->{Route});
    }

    {
	# optimal route crosses Berlin border
	my $content = std_get "$action?startname=Kirchhainer+Damm&startplz=12309&startc=11172%2C-2224&zielname=Zwickauer+Damm&zielplz=12353%2C+12355&zielc=15540%2C1235&pref_seen=1&pref_speed=26&pref_cat=&pref_quality=&pref_green=&pref_fragezeichen=yes&scope=", testname =>  "Kirchhainer Damm - Zwickauer Damm";
	like_html $content, qr/(Lichtenrader Chaussee|\(Lichtenrade -\) Großziethen)/, "Shorter route through Großziethen";
	like_html $content, qr/\(Großziethen -\) Rudow/, "Shorter route through Großziethen";
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
	if (!$ortsuche) {
	    like_html $content, qr/Gubener Str./, "Gubener Str. found";
	    pass "Pseudo test to keep no of tests";
	} else {
	    like_html $content, qr/Gubener Str.!Friedrichshain/, "Gubener Str. in Friedrichshain found"
		or diag "Can't find Gubener Str.";
	    like_html $content, qr/Guben!\#ort!/, "Guben as place/city found"
		or diag "Can't find Guben";
	}
    }

    {
	# Test "ImportantAngleCrossingName"
	my $content = std_get "$action?startc=23085%2C898;pref_quality=;startplz=12527;pref_speed=20;startname=Regattastr.;pref_specialvehicle=;zielname=Sportpromenade;pref_seen=1;zielplz=12527;zielc=25958%2C-731;pref_cat=;pref_green=;scope=", testname => 'test "ImportantAngleCrossingName" feature';
	like_html $content, qr/\QRegattastr. (Ecke Rabindranath-Tagore-Str.)/, 'found "ImportantAngleCrossingName" feature';
    }

    {
	# Another test for "ImportantAngleCrossingName"
	# Bülowstr. am Dennewitzplatz
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
    }

 SKIP: {
	# Klick on Start berlin map (Kreuzberg)
	my $content = std_get "$action?start=&startcharimg.x=107&startcharimg.y=15&startmapimg.x=90&startmapimg.y=107&via=&viacharimg.x=&viacharimg.y=&viamapimg.x=&viamapimg.y=&ziel=&zielcharimg.x=&zielcharimg.y=&zielmapimg.x=&zielmapimg.y=", testname => "Click on overview map";
	my $map_qr = qr{(http://.*/bbbike.*(?:tmp|\?tmp=)/berlin_map_04-05(?:_240|_280x240)?.png)}i;
	like_html $content, $map_qr, "Found map image source";
	my($image_url) = $content =~ $map_qr;
	my $resp;
	($content, $resp) = std_get $image_url;
	is $resp->content_type, 'image/png', "$image_url is a PNG";
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
	is $resp->content_type, 'image/png', "$image_url is a PNG";
	cmp_ok length($content), ">", 0, "Image is non-empty";
    }

    {
	# Klick on "alle Straßen" link
	my $content = std_get "$action?all=1", testname => "Click on all streets link";
	like_html $content, qr/B(?:ö|&ouml;|&#246;)lschestr.*Brachvogelstr.*(?:Ö|&Ouml;|&#214;)schelbronner(?:.|&#160;)Weg.*Pallasstr/s, "Correct sort order";
    }
    
 SKIP: {
	skip("No ortsuche", $ortsuche_tests)
	    if !$ortsuche;

	{
	    my $content = std_get "$action?startname=Dudenstr.&startplz=10965&via=&ziel2=Guben%21%23ort%21100909%2C-46980", testname => "Ortsuche";
	    like_html $content, qr/Mehringdamm.*Platz.*Tempelhofer/, "Found crossing in Berlin";
	    like_html $content, qr/Guben.*zielisort/, "Found city/place in Brandenburg";
	}

	{
	    my $content = std_get "$action?startname=Dudenstr.&startplz=10965&startc=9222%2C8787&zielc=100909%2C-46980&zielname=Guben&zielisort=1", testname => "Dudenstr. -> Guben";
	    if ($content =~ /L.*nge:.*(\d[\d.,]+).*km/) {
		my $len = $1;
		pass "It's possible to parse length";
		cmp_ok $len, ">", 0, "Positive length";
	    } else {
		fail "Cannot parse length" for (1..2);
		diag $content;
	    }
	    like_html $content, qr/angekommen/, "Angekommen!";
	    like_html $content, qr/B97.*Guben/, "Route via B97";
	}
	{
	    # See comment about coords= below.
	    my $url = "$action?imagetype=gif&coords=9222%2C8787%219303%2C8781%219373%2C8728%219801%2C8683%2110193%2C8672%2110598%2C8563%2110858%2C8475%2111308%2C8317%2111416%2C8283%2111632%2C8302%2111892%2C8372%2112195%2C8436%2112349%2C8464%2112500%2C8504%2112598%2C8390%2112771%2C8439%2112925%2C8494%2113107%2C8350%2113279%2C8216%2113452%2C8076%2113916%2C7714%2113996%2C7654%2114164%2C7510%2114596%2C7261%2115043%2C6799%2115478%2C6343%2115719%2C6218%2115758%2C6204%2115869%2C6181%2116107%2C6076%2116510%2C5917%2116861%2C5935%2117662%2C5314%2117741%2C5424%2117884%2C5577%2117962%2C5498%2118016%2C5615%2118133%2C5553%2118236%2C5529%2118987%2C5301%2119210%2C5301%2119425%2C5254%2121332%2C4655%2121796%2C4517%2122093%2C4499%2122396%2C4464%2122686%2C4310%2122967%2C4144%2123368%2C3894%2124912%2C2978%2125011%2C2907%2125502%2C2454%2125609%2C2397%2125928%2C2305%2126720%2C2079%2127093%2C1959%2127603%2C1531%2127746%2C1413%2128106%2C1106%2128190%2C984%2128329%2C906%2128673%2C548%2128812%2C490%2129372%2C561%2129598%2C636%2130217%2C398%2130624%2C266%2130850%2C49%2131032%2C-52%2131111%2C-75%2131227%2C-38%2131354%2C-111%2131662%2C-502%2132214%2C-420%2132258%2C-867%2132898%2C-930%2133005%2C-1015%2133775%2C-1397%2134330%2C-1588%2134694%2C-1673%2135313%2C-1714%2135420%2C-1949%2135634%2C-2183%2136233%2C-2715%2136874%2C-2926%2137004%2C-3331%2136984%2C-3865%2137091%2C-4227%2137348%2C-4333%2137497%2C-4461%2137562%2C-4738%2137755%2C-4865%2139251%2C-5673%2139700%2C-5672%2139892%2C-5565%2140362%2C-6011%2141195%2C-6095%2141919%2C-5304%2142517%2C-5431%2142797%2C-6092%2142840%2C-6390%2143182%2C-6389%2143502%2C-6325%2143694%2C-6367%2144379%2C-7133%2144681%2C-8348%2144874%2C-8519%2144749%2C-9692%2144878%2C-10139%2144945%2C-11291%2145290%2C-12634%2145013%2C-12954%2145912%2C-13848%2147302%2C-14869%2147410%2C-15124%2147411%2C-15636%2147156%2C-15978%2147007%2C-16298%2147286%2C-16895%2148292%2C-17852%2149489%2C-18617%2149554%2C-18788%2150603%2C-19809%2151245%2C-20469%2152400%2C-21149%2152956%2C-21510%2153233%2C-21531%2153233%2C-21361%2153851%2C-21061%2154640%2C-20547%2156049%2C-20630%2157671%2C-20413%2158184%2C-20369%2158889%2C-20666%2159317%2C-21049%2159573%2C-21027%2159810%2C-21731%2160279%2C-21644%2161690%2C-22153%2163016%2C-23196%2165175%2C-24364%2165283%2C-24577%2165667%2C-24491%2166629%2C-24937%2168252%2C-25083%2168593%2C-24911%2168848%2C-24420%2169682%2C-24909%2169554%2C-25101%2169879%2C-26935%2169755%2C-28598%2169630%2C-29963%2169933%2C-31626%2170340%2C-32094%2169938%2C-33311%2170088%2C-33801%2170775%2C-35271%2171311%2C-36230%2171741%2C-37316%2172385%2C-38723%2173415%2C-40554%2173608%2C-41002%2173891%2C-42985%2173594%2C-44009%2173638%2C-44499%2173958%2C-44456%2175538%2C-44410%2176008%2C-44388%2176690%2C-44173%2176883%2C-44194%2177075%2C-44193%2177993%2C-44426%2178442%2C-44404%2179595%2C-44593%2179958%2C-44529%2180791%2C-44783%2187860%2C-45301%2189461%2C-45255%2189760%2C-45297%2190251%2C-45446%2190636%2C-45466%2191961%2C-46039%2192900%2C-46080%2192944%2C-46570%2193053%2C-47146%2193589%2C-48019%2193717%2C-48253%2196427%2C-47736%2198967%2C-47326%21100269%2C-47046%21100909%2C-46980&startname=Dudenstr.&zielname=Guben&windrichtung=S&windstaerke=5&geometry=400x300&draw=str&draw=title&draw=umland";
	    my($content, $resp) = std_get $url, testname => "Map plot request";
	    is $resp->content_type, 'image/gif', "It's a GIF image";
	    BBBikeTest::like_long_data($content, qr/^GIF8/, "It's really a GIF")
		    or diag $url;
	}
    }

    for my $imagetype (
		       "gif", "png", "jpeg",
		       "svg", "mapserver",
		       "pdf", "pdf-auto", "pdf-landscape",
		       "googlemaps",
		      ) {
    SKIP: {
	    my $tests = 3;
	    skip "No mapserver tests", $tests
		if $imagetype eq 'mapserver' && $skip{mapserver};

	    my $imagetype_param = ($imagetype ne "" ? "imagetype=$imagetype&" : "");
	    # This coords are sensitive to changes if
	    # search_algorithm=C-A*-2 is used. Expect failures in this
	    # case and try to fix the coords list.
	    my $url = "$action?${imagetype_param}coords=9222%2C8787%219227%2C8890%219796%2C8905%219799%2C8962%219958%2C8966%219962%2C9237%219987%2C9238%2110109%2C9240%2110189%2C9403%2110298%2C9649%2110345%2C9764%2110408%2C9800%2110480%2C9949%2110503%2C10046%2110490%2C10080%2110511%2C10128%2110605%2C10312%2110859%2C10333%2110962%2C10340%2111114%2C10338%2111336%2C10390%2111370%2C10398%2111454%2C10400%2111660%2C10402%2111949%2C10414%2112230%2C10437%2112274%2C10436%2112328%2C10442%2112755%2C10552%2112899%2C10595%2112980%2C10575%2113035%2C10635%2113082%2C10634%2113178%2C10623%2113216%2C10664%2113297%2C10781%2113332%2C10832%2113409%2C11004%2113546%2C11352%2113594%2C11489%2113720%2C11459%2113890%2C11411%2114139%2C11269%2114211%2C11229%2114286%2C11186%2114442%2C11101%2114509%2C11060%2114677%2C11027%2114752%2C11041%2114798%2C10985&startname=Dudenstr.&zielname=Sonntagstr.&windrichtung=E&windstaerke=2&geometry=400x300&draw=str&draw=wasser&draw=flaechen&draw=ampel&draw=strname&draw=title&draw=all";
	    my($content, $resp) = std_get $url, testname => "imagetype=$imagetype";
	    if ($imagetype eq 'gif') {
		is $resp->content_type, 'image/gif', "It's a GIF image";
		BBBikeTest::like_long_data($content, qr/^GIF8/, "Really a GIF image")
			or diag "Not a gif: $url";
		display($resp);
	    } elsif ($imagetype =~ /(png|jpeg)/) {
		is $resp->content_type, 'image/' . $imagetype, "It's a $imagetype image";
		ok length $content, "The image is non-empty";
		display($resp);
	    } elsif ($imagetype =~ /pdf/) {
		is $resp->content_type, 'application/pdf', "It's a PDF";
		ok length $content, "The PDF is non-empty";
		display($resp);
		like $resp->header('Content-Disposition'), qr{inline; filename=.*\.pdf$}, 'PDF filename'; # unfortunately in this case (missing session?) there's no nice filename from route start/endpoint
	    } elsif ($imagetype =~ /svg/) {
		is $resp->content_type, "image/svg+xml", "It's a SVG image";
		ok length $content, "The SVG is non-empty";
		display($resp);
	    } else {
		like $resp->content_type, qr{^text/html}, "It's a $imagetype";
		ok length $content, "The $imagetype is non-empty";
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
	like_html $content, qr{\QWallstr./Karl-Liebknecht-Str./August-Bebel-Str./Große Str. (Strausberg)\E}, "Simplified crossing";
	like_html $content, qr{\QHumboldtallee/Haydnallee/Fröbelstr. (Falkensee)}, "Simplified crossing (goal)";
    }

    {
	my $content = std_get "$action?" .
	    CGI->new({startc=>"9222,8787",
		      zielc=>"-502,-803",
		      scope=>"region", # why needed?
		     })->query_string,
	    testname => "Another request with crossings";
	like_html $content, qr{\QDudenstr./Mehringdamm/Platz der Luftbrücke/Tempelhofer Damm\E}, "No simplification for Berlin crossings needed";
	like_html $content, qr{\QThomas-Müntzer-Damm (Kleinmachnow)/Warthestr. (Teltow)\E}, "No simplification possible between different places";
    }

    {
	my %common_args = ( startc=>'16720,6845',
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
	    like_html $content, qr{Überfahrt.*kostet}, 'Found tariff information for ferry';
	}

	{
	    my $content = std_get "$action?" .
		CGI->new({%common_args,
			  pref_ferry=>'',
			 })->query_string,
		testname => 'Request without ferry=use';
	    unlike_html $content, qr{F11.*Baumschulenstr.*Wilhelmstrand}, 'No use of ferry F11';
	    unlike_html $content, qr{Überfahrt.*kostet}, 'No tariff information for ferry';
	}
    }

    {   # The "Müller Breslau"-Bug (from the Berlin PM wiki page)
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
		       zielname => "müller-breslau-str",
		     })->query_string,
	    testname => "The Mueller-Breslau request";
	like_html $content, qr{Invalidenstr\..*Ecke.*Müller-Breslau-Str\..*Ecke}s, "'Ecke' for both crossings";
    }

    {   # All street types (as defined in PLZ.pm) except "streets"
        # should provide automatically the nearest crossing to the
        # Berlin.coords.data coordinate. Note that this should also
        # happen for railway stations --- this is already tested in
        # cgi-mechanize.t

	my $content = std_get "$action?" .
	    CGI->new({ start2 => 'Westend (Kolonie)!Westend!14050!935,12882!0', # note: multiple results with "Westend"
		       via    => 'Weinbergshöhe',
		       ziel2  => 'Eiswerder (Insel)!Hakenfelde!13585!-2318,15601!0', # note: multiple results with "Eiswerder"
		       scope  => 0,
		     })->query_string,
	    testname => 'Westend/Weinbergshoehe/Eiswerder';
	like_html $content, qr{   Die[ ]nächste[ ]Kreuzung[ ]ist.*
				  Die[ ]nächste[ ]Kreuzung[ ]ist.*
				  Die[ ]nächste[ ]Kreuzung[ ]ist
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
		      zielname=>"Neustädtische Kirchstr./Mittelstr. (Mitte)",
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
	my $content = std_get $cgiurl . "?scope=wideregion&detailmapx=2&detailmapy=6&type=start&detailmap.x=200&detailmap.y=226";
	like_html $content, qr{diese Koordinaten konnte keine Kreuzung gefunden werden}, "No crossing for coords in the Döberitzer Heide";
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
    my $resp = $ua->request($req);
    ok $resp->is_success, $testname
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
    ok validate_output_as($route), 'Validation';
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

{
    my $schema;
    sub validate_output_as {
	my($data) = @_;
	my $res = 1;
    SKIP: {
	    if (!defined $schema) {
		if (!eval { require Kwalify; require YAML::Syck; 1 }) {
		    diag "Kwalify and YAML::Syck needed for schema validation, but not available.";
		    $schema = 0;
		} else {
		    my $schema_file = "$FindBin::RealBin/../misc/bbbikecgires.kwalify";
		    if (!-r $schema_file) {
			diag "Schema file $schema_file is missing.";
			$schema = 0;
		    } else {
			$schema = YAML::Syck::LoadFile($schema_file);
		    }
		}
	    }

	    if ($schema) {
		if (!eval { Kwalify::validate($schema, $data) }) {
		    diag $@;
		    $res = 0;
		}
	    }
	}
	$res;
    }
}
