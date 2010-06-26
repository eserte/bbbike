#!/usr/local/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 1998,2000,2003,2004,2006,2010 Slaven Rezic. All rights reserved.
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
use BBBikeTest qw(xmllint_string gpxlint_string kmllint_string);

eval { require Compress::Zlib };

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
}

my $ortsuche_tests = 11;
plan tests => (200 + $ortsuche_tests) * scalar @urls;

my $hdrs;
if (defined &Compress::Zlib::memGunzip && $do_accept_gzip) {
    $hdrs = HTTP::Headers->new(Accept_Encoding => "gzip");
    warn "Accept gzip encoding\n" if $v;
} else {
    $hdrs = HTTP::Headers->new();
}

for my $cgiurl (@urls) {
    my $content;
    my $req = new HTTP::Request('GET', $cgiurl, $hdrs);
    my $res = $ua->request($req);
    ok($res->is_success, "Simple $cgiurl request")
	or diag(Dumper($res));
    like($res->header('Content_Type'),
	 qr{^text/html(?:; charset=(?:ISO-8859-1|utf-8))?$}, "Expect text/html (regardless which charset)");
    $content = uncompr($res);
    like($content, qr/Dieses Programm sucht .*Fahrrad-.*Routen in Berlin/,
	 "Expected introduction text in body");

    my $action;
    if ($content =~ /form action=\"([^\"]+)\"/i) {
	pass("Form found");
	$action = $1;
    } else {
	pass("No form found");
	$action = $cgiurl;
    }

    if ($do_xxx) {
	goto XXX; # skip some tests
    }

    $req = new HTTP::Request
      ('GET', "$action?start=dudenstr&via=&ziel=grimmstr", $hdrs);
    $res = $ua->request($req);
    ok($res->is_success, "Dudenstr. -> Grimmstr.") or diag(Dumper($res));
    $content = uncompr($res);
    like($content, qr/Start.*Dudenstr\./,
	 "Expected start (Dudenstr)");
    like($content, qr/Grimmstr\..*Kreuzberg.*10967/,
	 "Expected goal (Grimmstr)");

    $req = new HTTP::Request
      ('GET', "$action?startname=Dudenstr.&startplz=10965&via=&ziel2=Grimmstr.%21Kreuzberg%2110967", $hdrs);
    $res = $ua->request($req);
    ok($res->is_success, "Dudenstr. -> Grimmstr. (resolved)")
	or diag(Dumper($res));
    $content = uncompr($res);
    my($mehringdamm_line) = $content =~ /(.*Mehringdamm.*)/;
    ok(defined $mehringdamm_line, "Found Mehringdamm in route");
    like($mehringdamm_line, qr/Platz.*d.*Luftbr/, "Found PladeLu in route");
    like($mehringdamm_line, qr/Tempelhofer/, "Found Tempelhofer in route");
    like($content, qr/(Urban.*Fichte|Fichte.*Urban)/,
	 "Found Urban/Fichtestr. in route");

    {
	# Potsdam
	$req = new HTTP::Request
	    ('GET', "$action?start=helmholtzstr&ziel=otto-nagel");
	$res = $ua->request($req);
	ok($res->is_success, "Potsdam streets (Helmholtz-, Otto-Nagel-Str.)")
	    or diag(Dumper($res));
	$content = uncompr($res);
	like($content, qr/Helmholtz.*Potsdam/,
	     "Found Helmholtzstr in Potsdam");
	like($content, qr/Helmholtz.*Charlottenburg/,
	     "Found Helmholtzstr in Berlin");
	like($content, qr/Otto-Nagel-Str.*Potsdam/,
	     "Found Otto-Nagel-Str. in Potsdam");
	like($content, qr/Otto-Nagel-Str.*Biesdorf/,
	     "Found Otto-Nagel-Str. in Berlin");
    }

    # search_coord
    for my $output_as ("", qw(xml gpx-track gpx-route kml-track print perldump
			      yaml yaml-short palmdoc mapserver)) {
	$req = new HTTP::Request
	    ('GET', "$action?startname=Dudenstr.&startplz=10965&startc=9222%2C8787&zielname=Grimmstr.+%28Kreuzberg%29&zielplz=10967&zielc=11036%2C9592&pref_seen=1&output_as=$output_as", $hdrs);
	$res = $ua->request($req);
    SKIP: {
	    skip "No mapserver tests", 1 if $skip{mapserver};
	    ok($res->is_success, "Route result output_as=$output_as")
		or diag(Dumper($res));
	}
	my $content = uncompr($res);
	if ($output_as eq '' || $output_as eq 'print') {
	    is($res->content_type, 'text/html', "Expected content type");
	    ok($content =~ /L.*nge:.*(\d[\d.,]+).*km/ && $1 > 0,
	       "Length text found");
	    # minor changes in the data may change the initial direction,
	    # both "Osten" and "Norden" already happened
	    like($content, qr/nach\s+(Norden|Osten)/, "Direction is correct");
	    like($content, qr/angekommen/, "End of route list found");
	} elsif ($output_as eq 'palmdoc') {
	    is($res->content_type, 'application/x-palm-database',
	       "Correct mime type for palmdoc");
	    like($content, qr/Dudenstr/, "Expected palmdoc content");
	} elsif ($output_as eq 'perldump') {
	    is($res->content_type, 'text/plain',
	       "Correct mime type for perl dump");
	    my $route = $cpt->reval($content);
	    is(ref $route, 'HASH', "perldump is a hash");
	    is(ref $route->{Route}, 'ARRAY', "Route member found");
	    like($route->{Route}[0]{DirectionString}, qr/nach\s+Osten/,
		 "Direction is correct");
	    like($route->{Route}[0]{Direction}, qr{^[NE]$}, # see above about initial direction
	       "Raw direction is correct");
	} elsif ($output_as eq 'mapserver') {
	SKIP: {
		skip "No mapserver tests", 1 if $skip{mapserver};
		is($res->content_type, "text/html",
		   "Expected content-type for $output_as");
	    }
	} elsif ($output_as eq 'xml') {
	    xmllint_string($content, "xmllint check for $output_as");
	} elsif ($output_as =~ m{^( gpx-track
				 |  gpx-route
				 )$}x) {
	    gpxlint_string($content, "xmllint check with gpx schema for $output_as");
	} elsif ($output_as eq 'kml-track') {
	    is($res->content_type, 'application/vnd.google-earth.kml+xml', "The KML mime type");
	    kmllint_string($content, "xmllint check for $output_as");
	}
    }

    {
	my $content;
	my $route;

	# Combine places with same coordinates
	$req = new HTTP::Request
	    (GET => "$action?start=zoo");
	$res = $ua->request($req);
	ok($res->is_success, "Zoo")
	    or diag(Dumper($res));
	$content = uncompr($res);
	BBBikeTest::like_long_data($content, qr/Start.*Zoologischer Garten/,
				   "Start is Zoologischer Garten", ".html");
	BBBikeTest::unlike_long_data($content, qr/\bZoo\b/,
				     "Zoo not found (same point optimization)", ".html");
	BBBikeTest::unlike_long_data($content, qr/\(\)/,
				     "No empty parenthesis", ".html");

	# Start and goal are in plaetze
	$req = new HTTP::Request
	    (GET => "$action?start=heinrichplatz&starthnr=&startcharimg.x=&startcharimg.y=&startmapimg.x=&startmapimg.y=&via=&viahnr=&viacharimg.x=&viacharimg.y=&viamapimg.x=&viamapimg.y=&ziel=gesundbrunnen&zielhnr=&zielcharimg.x=&zielcharimg.y=&zielmapimg.x=&zielmapimg.y=&scope=");
	$res = $ua->request($req);
	ok($res->is_success, "Heinrichplatz - Gesundbrunnen")
	    or diag(Dumper($res));
	$content = uncompr($res);
	BBBikeTest::like_long_data($content, qr/Start.*startc.*startname.*Heinrichplatz/,
				   "Start is Heinrichplatz", ".html")
		or diag "Test may fail if start is not in file plaetze";
	BBBikeTest::like_long_data($content, qr/Ziel.*zielc.*zielname.*Gesundbrunnen/,
				   "Goal is Gesundbrunnen", ".html")
		or diag "Test may fail if goal is not in file plaetze";

	# search_coord in and to Potsdam
	$req = new HTTP::Request
	    ('GET', "$action?startname=Alemannenstr.+%28Nikolassee%29&startplz=14129&startc=-3360%2C2917&zielc=-11833%2C-63&zielname=Helmholtzstr.+%28Potsdam%29&zielplz=&pref_seen=1&pref_speed=21&pref_cat=&pref_quality=&pref_ampel=yes&scope=");
	$res = $ua->request($req);
	ok($res->is_success, "Berlin => Potsdam") or diag(Dumper($res));
	$content = uncompr($res);
	ok($content =~ qr/angekommen/, "Angekommen!");

	$req = new HTTP::Request
	    ('GET', "$action?zielname=Alemannenstr.+%28Nikolassee%29&zielplz=14129&zielc=-3360%2C2917&startc=-11833%2C-63&startname=Helmholtzstr.+%28Potsdam%29&startplz=&pref_seen=1&pref_speed=21&pref_cat=&pref_quality=&pref_ampel=yes&scope=");
	$res = $ua->request($req);
	ok($res->is_success, "Potsdam => Berlin") or diag(Dumper($res));
	$content = uncompr($res);
	ok($content =~ qr/angekommen/, "Angekommen!");

	$req = new HTTP::Request
	    ('GET', "$action?zielname=Nuthewinkel+%28Potsdam%29&zielplz=&zielc=-11225%2C-2878&startc=-11833%2C-63&startname=Helmholtzstr.+%28Potsdam%29&startplz=&pref_seen=1&pref_speed=21&pref_cat=&pref_quality=&pref_ampel=yes&scope=");
	$res = $ua->request($req);
	ok($res->is_success, "Potsdam => Potsdam") or diag(Dumper($res));
	$content = uncompr($res);
	ok($content =~ qr/angekommen/, "Angekommen!");

	# this is critical --- both streets in the neighborhood of Berlin
	$req = new HTTP::Request
	    ('GET', "$action?startc=-12064%2C-284&zielc=-11831%2C-70&startname=Otto-Nagel-Str.+%28Potsdam%29&zielname=Helmholtzstr.+%28Potsdam%29&pref_seen=1&pref_speed=21&pref_cat=&pref_quality=&output_as=perldump");
	$res = $ua->request($req);
	ok($res->is_success, "Otto-Nagel => Manger (Potsdam)")
	    or diag(Dumper($res));
	$content = uncompr($res);
	$route = $cpt->reval($content);
	is(ref $route, "HASH", "Route result is a HASH");
	ok($route->{Len} > 0 && $route->{Len} < 500, "check route length")
	    or diag "Route length: $route->{Len} too large, Route is " . Dumper($route->{Route});

	# this had once an empty route as the result:
	$req = new HTTP::Request
	    ('GET', "$action?startname=Mangerstr.+%28Potsdam%29&startplz=&startc=-12236%2C-447&zielname=Berliner+Allee&zielplz=13088&zielc=13332%2C15765&pref_seen=1&pref_speed=21&pref_cat=&pref_quality=&scope=region&output_as=perldump");
	$res = $ua->request($req);
	ok($res->is_success, "Manger => Berliner Allee")
	    or diag(Dumper($res));
	$content = uncompr($res);
	$route = $cpt->reval($content);
	is(ref $route, "HASH", "Route result is a HASH");
	ok($route->{Len} > 30000 && $route->{Len} < 35000,
	   "check route length")
	    or diag "Route length: $route->{Len}";

	# scope=region gets lost in "Rückweg". bbbike.cgi should handle
	# this case:
	$req = new HTTP::Request
	    ('GET', "$action?startc=13332%2C15765&zielc=-12236%2C-447&startname=Berliner+Allee&zielname=Mangerstr.+%28Potsdam%29&pref_seen=1&pref_speed=21&pref_cat=&pref_quality=&output_as=perldump");
	$res = $ua->request($req);
	ok($res->is_success, "way back") or diag(Dumper($res));
	$content = uncompr($res);
	$route = $cpt->reval($content);
	if (is(ref $route, "HASH", "Route result is a HASH")) {
	    ok($route->{Len} > 30000 && $route->{Len} < 35000,
	       "check route length")
		or diag "Route length: $route->{Len}";
	} else {
	    fail("No hash, no route length");
	}

	# Test comments_points (category 0, CARRY) (as part of Bemerkungen)
	$req = new HTTP::Request
	    ('GET', "$action?startname=Sonntagstr.&startplz=10245&startc=14798%2C10985&zielname=Markgrafendamm&zielplz=10245&zielc=14794%2C10844&pref_seen=1&pref_speed=20&pref_cat=&pref_quality=&scope=");
	$res = $ua->request($req);
	ok($res->is_success, "Tragen test") or diag(Dumper($res));

	$content = uncompr($res);
	BBBikeTest::like_long_data($content, qr/(Sekunden|Minuten).*Zeitverlust/, "Zeitverlust in text", ".html");

	# Test comments_points (category BNP, NARROWPASSAGE) (as part of Bemerkungen)
	$req = new HTTP::Request
	    ('GET', "$action?startc=9662%2C10345&startplz=10969&startname=Mehringplatz&zielname=Brachvogelstr.&zielplz=10961&zielc=10059%2C10147&scope=&pref_seen=1&pref_speed=12&pref_cat=N1&pref_quality=Q2&pref_ampel=yes&pref_green=&pref_fragezeichen=yes");
	$res = $ua->request($req);
	ok($res->is_success, "Drängelgitter test") or diag(Dumper($res));

	$content = uncompr($res);
	BBBikeTest::like_long_data($content, qr/Dr.*ngelgitter.*(Sekunden|Minuten).*Zeitverlust/, "Zeitverlust in text", ".html");

	# This is only correct with use_exact_streetchooser=true
	$req = new HTTP::Request
	    ('GET', "$action?startc=13332%2C15765&zielc=-10825,-62&startname=Berliner+Allee&zielname=Babelsberg+%28Potsdam%29&pref_seen=1&pref_speed=21&pref_cat=&pref_quality=&output_as=perldump&scope=");
	$res = $ua->request($req);
	ok($res->is_success, "use exact streetchooser")
	    or diag(Dumper($res));
	$content = uncompr($res);
	$route = $cpt->reval($content);
	if (is(ref $route, "HASH", "Route result is a HASH")) {
	    ok($route->{Len} > 30000 && $route->{Len} < 35000,
	       "check route length")
		or diag "Route length: $route->{Len}";
	    ok((grep { $_->{Strname} =~ /Park Babelbsberg/ } @{ $route->{Route} }),
	       "Route through Park Babelsberg")
		or diag "Route not through Park Babelsberg: " . Dumper($route->{Route});
	} else {
	    diag($@);
	    fail("No hash, no route length or route info") for (1..2);
	}

	# This created degenerated routes because of missing handling of "B"
	# (Bundesstraßen) category
	$req = new HTTP::Request
	    ('GET', "$action?startname=Otto-Nagel-Str.+%28Potsdam%29&startplz=&startc=-11978%2C-348&zielname=Sonntagstr.&zielplz=10245&zielc=14598%2C11245&scope=region&pref_seen=1&pref_speed=20&pref_cat=N2&pref_quality=&output_as=perldump");
	$res = $ua->request($req);
	ok($res->is_success, "Bundesstraßen handled OK")
	    or diag(Dumper($res));
	$content = uncompr($res);
	$route = $cpt->reval($content);
	if (is(ref $route, "HASH", "Route result is a HASH")) {
	    ok($route->{Len} > 30000 && $route->{Len} < 40000,
	       "check route length")
		or diag "Route length: $route->{Len}, Route is " . Dumper($route->{Route});
	} else {
	    diag($@);
	    fail("No hash, no route length");
	}
    }

    {
	my $content;

	# optimal route crosses Berlin border
	$res = $ua->get("$action?startname=Kirchhainer+Damm&startplz=12309&startc=11172%2C-2224&zielname=Zwickauer+Damm&zielplz=12353%2C+12355&zielc=15540%2C1235&pref_seen=1&pref_speed=26&pref_cat=&pref_quality=&pref_green=&pref_fragezeichen=yes&scope=");
	ok($res->is_success, "Kirchhainer Damm - Zwickauer Damm")
	    or diag(Dumper($res));
	$content = uncompr($res);
	BBBikeTest::like_long_data($content, qr/(Lichtenrader Chaussee|\(Lichtenrade -\) Großziethen)/,
				   "Shorter route through Großziethen", ".html");
	BBBikeTest::like_long_data($content, qr/\(Großziethen -\) Rudow/,
				   "Shorter route through Großziethen", ".html");
    }

    {
	# Test "inaccessible" feature
	my $inacc_xy = "21306,381"; # B96a
	$req = new HTTP::Request
	    ('GET', "$action?startname=Somewhere&startc=" . uri_escape($inacc_xy) . "&zielname=Sonntagstr.&zielplz=10245&zielc=14598%2C11245&scope=region&pref_seen=1&pref_speed=20&pref_cat=N2&pref_quality=&output_as=perldump");
	$res = $ua->request($req);
	ok($res->is_success, 'test "inaccessible" feature')
	    or diag(Dumper($res));
	$content = uncompr($res);
	my $route = $cpt->reval($content);
	is(ref $route, "HASH", 'route with "inaccessible" feature is valid');
    }

    $req = new HTTP::Request
      ('GET', "$action?start=duden&via=&ziel=guben", $hdrs);
    $res = $ua->request($req);
    ok($res->is_success, "Guben vs. Gubener Str.")
	or diag(Dumper($res));
    $content = uncompr($res);
    if (!$ortsuche) {
	like($content, qr/Gubener Str./, "Gubener Str. found");
	pass("Pseudo test to keep no of tests");
    } else {
	like($content, qr/Gubener Str.!Friedrichshain/,
	     "Gubener Str. in Friedrichshain found")
	    or diag "Can't find Gubener Str. in " . $content;
	like($content, qr/Guben!\#ort!/, "Guben as place/city found")
	    or diag("Can't find Guben in " . $content);
    }

    # Klick on "D" in Start A..Z
    $req = new HTTP::Request
	(GET => "$action?start=&startcharimg.x=107&startcharimg.y=15&startmapimg.x=&startmapimg.y=&via=&viacharimg.x=&viacharimg.y=&viamapimg.x=&viamapimg.y=&ziel=&zielcharimg.x=&zielcharimg.y=&zielmapimg.x=&zielmapimg.y=", $hdrs);
    $res = $ua->request($req);
    ok($res->is_success, "Click on D in A..Z")
	or diag(Dumper($res));
    $content = uncompr($res);
    like($content, qr/Anfangsbuchstabe.*D/, "Initial letter is D");
    like($content, qr/Dudenstr/, "Dudenstr. is in D section");
    like($content, qr/\QDortustr. (Potsdam)/, "There are also Potsdam streets");
    unlike($content, qr/\QDorfstr. (Heinersdorf)/, "But no other streets in Brandenburg");

    # Klick on "B" in Start A..Z
    $req = new HTTP::Request
	(GET => "$action?start=&startcharimg.x=44&startcharimg.y=15&startmapimg.x=&startmapimg.y=&via=&viacharimg.x=&viacharimg.y=&viamapimg.x=&viamapimg.y=&ziel=&zielcharimg.x=&zielcharimg.y=&zielmapimg.x=&zielmapimg.y=", $hdrs);
    $res = $ua->request($req);
    ok($res->is_success, "Click on B in A..Z")
	or diag(Dumper($res));
    $content = uncompr($res);
    like($content, qr/\QBerliner Str. (Potsdam)/, "Stripped `B1' from street name");

    # Klick on Start berlin map (Kreuzberg)
    $req = new HTTP::Request
	(GET => "$action?start=&startcharimg.x=107&startcharimg.y=15&startmapimg.x=90&startmapimg.y=107&via=&viacharimg.x=&viacharimg.y=&viamapimg.x=&viamapimg.y=&ziel=&zielcharimg.x=&zielcharimg.y=&zielmapimg.x=&zielmapimg.y=", $hdrs);
    $res = $ua->request($req);
    ok($res->is_success, "Click on overview map")
	or diag(Dumper($res));
    $content = uncompr($res);
    my $map_qr = qr{(http://.*/bbbike.*(?:tmp|\?tmp=)/berlin_map_04-05(?:_240|_280x240)?.png)}i;
    if ($content !~ $map_qr) {
	diag("Cannot get tile image reference, expected something like $map_qr");
	BBBikeTest::failed_long_data($content, $map_qr, "Tile image check", ".html");
	ok(0) for 1..3; # really skip
    } else {
	my $image_url = $1;
	pass("Found map image source");
	$req = new HTTP::Request
	    (GET => $image_url, $hdrs);
	$res = $ua->request($req);
	ok($res->is_success, "Getting $image_url") or diag(Dumper($res));
	is($res->content_type, 'image/png', "$image_url is a PNG");
	ok(length($content) > 0, "Image is non-empty");
    }

    # Klick on Info link
    {
	my $req = new HTTP::Request
	    (GET => "$action?info=1", $hdrs);
	my $res = $ua->request($req);
	ok($res->is_success, "Click on info link")
	    or diag(Dumper($res));
    }

    # Info page through pathinfo
    {
	my $req = new HTTP::Request
	    (GET => "$action/info=1", $hdrs);
	my $res = $ua->request($req);
	ok($res->is_success, "Info page through pathinfo")
	    or diag(Dumper($res));
	my $content = uncompr($res);
	like($content, qr/Link auf BBBike setzen/,
	     "Is it really the info page?");
    }

    # Klick on Mapserver link
    SKIP: {
	my $tests = 6;
	skip "Does not work with CGI::MiniSvr", $tests
	    if ($cgiurl =~ /bbbike-fast.cgi/);
	skip "No mapserver tests", $tests
	    if $skip{mapserver};

	$req = new HTTP::Request
	    (GET => "$action?mapserver=1", $hdrs);
	$res = $ua->request($req);
	ok($res->is_success, "Click on mapserver link")
	    or diag(Dumper($res));
	my $content = uncompr($res);
	like($content, qr/Darzustellende Ebenen/, "Layers headline");
	if ($content !~ qr|SRC="(.*/mapserver/brb/tmp/brb.*.png)"|) {
	    ok(0) for 1..4; # really skip
	    diag "Cannot get map image reference in $action?mapserver=1";
	} else {
	    pass("Found image reference on mapserver page");
	    my $u1 = URI::WithBase->new($1, $res->base);
	    my $image_url = $u1->abs;
	    $req = new HTTP::Request
		(GET => $image_url, $hdrs);
	    $res = $ua->request($req);
	    ok($res->is_success, "$image_url was OK") or diag(Dumper($res));
	    is($res->content_type, 'image/png', "$image_url is a PNG");
	    ok(length($content) > 0, "Image is non-empty");
	}
    }

    {
	# Klick on "alle Straßen" link
	$req = new HTTP::Request
	    (GET => "$action?all=1", $hdrs);
	$res = $ua->request($req);
	ok($res->is_success, "Click on all streets link")
	    or diag(Dumper($res));
	my $content = uncompr($res);
	BBBikeTest::like_long_data($content, qr/B(?:ö|&ouml;|&#246;)lschestr.*Brachvogelstr.*(?:Ö|&Ouml;|&#214;)schelbronner(?:.|&#160;)Weg.*Pallasstr/s, "Correct sort order", ".html");
    }

 SKIP: {
	skip("No ortsuche", $ortsuche_tests)
	    if !$ortsuche;

	my $content;
	$req = new HTTP::Request
	    ('GET', "$action?startname=Dudenstr.&startplz=10965&via=&ziel2=Guben%21%23ort%21100909%2C-46980", $hdrs);
	$res = $ua->request($req);
	ok($res->is_success, "Ortsuche")
	    or diag(Dumper($res));
	$content = uncompr($res);
	ok($content =~ /Mehringdamm.*Platz.*Tempelhofer/,
	   "Found crossing in Berlin");
	ok($content =~ /Guben.*zielisort/,
	   "Found city/place in Brandenburg");

	$req = new HTTP::Request
	    ('GET', "$action?startname=Dudenstr.&startplz=10965&startc=9222%2C8787&zielc=100909%2C-46980&zielname=Guben&zielisort=1", $hdrs);
	$res = $ua->request($req);
	ok($res->is_success, "Dudenstr. -> Guben") or diag(Dumper($res));
	$content = uncompr($res);
	if ($content =~ /L.*nge:.*(\d[\d.,]+).*km/) {
	    my $len = $1;
	    pass("Possible to parse length");
	    ok($len > 0, "Positive length");
	} else {
	    fail("Cannot parse length") for (1..2);
	    diag $content;
	}
	ok($content =~ /angekommen/, "Angekommen!");
	ok($content =~ /B97.*Guben/, "Route via B97");

	# See comment about coords= below.
	my $url = "$action?imagetype=gif&coords=9222%2C8787%219303%2C8781%219373%2C8728%219801%2C8683%2110193%2C8672%2110598%2C8563%2110858%2C8475%2111308%2C8317%2111416%2C8283%2111632%2C8302%2111892%2C8372%2112195%2C8436%2112349%2C8464%2112500%2C8504%2112598%2C8390%2112771%2C8439%2112925%2C8494%2113107%2C8350%2113279%2C8216%2113452%2C8076%2113916%2C7714%2113996%2C7654%2114164%2C7510%2114596%2C7261%2115043%2C6799%2115478%2C6343%2115719%2C6218%2115758%2C6204%2115869%2C6181%2116107%2C6076%2116510%2C5917%2116861%2C5935%2117662%2C5314%2117741%2C5424%2117884%2C5577%2117962%2C5498%2118016%2C5615%2118133%2C5553%2118236%2C5529%2118987%2C5301%2119210%2C5301%2119425%2C5254%2121332%2C4655%2121796%2C4517%2122093%2C4499%2122396%2C4464%2122686%2C4310%2122967%2C4144%2123368%2C3894%2124912%2C2978%2125011%2C2907%2125502%2C2454%2125609%2C2397%2125928%2C2305%2126720%2C2079%2127093%2C1959%2127603%2C1531%2127746%2C1413%2128106%2C1106%2128190%2C984%2128329%2C906%2128673%2C548%2128812%2C490%2129372%2C561%2129598%2C636%2130217%2C398%2130624%2C266%2130850%2C49%2131032%2C-52%2131111%2C-75%2131227%2C-38%2131354%2C-111%2131662%2C-502%2132214%2C-420%2132258%2C-867%2132898%2C-930%2133005%2C-1015%2133775%2C-1397%2134330%2C-1588%2134694%2C-1673%2135313%2C-1714%2135420%2C-1949%2135634%2C-2183%2136233%2C-2715%2136874%2C-2926%2137004%2C-3331%2136984%2C-3865%2137091%2C-4227%2137348%2C-4333%2137497%2C-4461%2137562%2C-4738%2137755%2C-4865%2139251%2C-5673%2139700%2C-5672%2139892%2C-5565%2140362%2C-6011%2141195%2C-6095%2141919%2C-5304%2142517%2C-5431%2142797%2C-6092%2142840%2C-6390%2143182%2C-6389%2143502%2C-6325%2143694%2C-6367%2144379%2C-7133%2144681%2C-8348%2144874%2C-8519%2144749%2C-9692%2144878%2C-10139%2144945%2C-11291%2145290%2C-12634%2145013%2C-12954%2145912%2C-13848%2147302%2C-14869%2147410%2C-15124%2147411%2C-15636%2147156%2C-15978%2147007%2C-16298%2147286%2C-16895%2148292%2C-17852%2149489%2C-18617%2149554%2C-18788%2150603%2C-19809%2151245%2C-20469%2152400%2C-21149%2152956%2C-21510%2153233%2C-21531%2153233%2C-21361%2153851%2C-21061%2154640%2C-20547%2156049%2C-20630%2157671%2C-20413%2158184%2C-20369%2158889%2C-20666%2159317%2C-21049%2159573%2C-21027%2159810%2C-21731%2160279%2C-21644%2161690%2C-22153%2163016%2C-23196%2165175%2C-24364%2165283%2C-24577%2165667%2C-24491%2166629%2C-24937%2168252%2C-25083%2168593%2C-24911%2168848%2C-24420%2169682%2C-24909%2169554%2C-25101%2169879%2C-26935%2169755%2C-28598%2169630%2C-29963%2169933%2C-31626%2170340%2C-32094%2169938%2C-33311%2170088%2C-33801%2170775%2C-35271%2171311%2C-36230%2171741%2C-37316%2172385%2C-38723%2173415%2C-40554%2173608%2C-41002%2173891%2C-42985%2173594%2C-44009%2173638%2C-44499%2173958%2C-44456%2175538%2C-44410%2176008%2C-44388%2176690%2C-44173%2176883%2C-44194%2177075%2C-44193%2177993%2C-44426%2178442%2C-44404%2179595%2C-44593%2179958%2C-44529%2180791%2C-44783%2187860%2C-45301%2189461%2C-45255%2189760%2C-45297%2190251%2C-45446%2190636%2C-45466%2191961%2C-46039%2192900%2C-46080%2192944%2C-46570%2193053%2C-47146%2193589%2C-48019%2193717%2C-48253%2196427%2C-47736%2198967%2C-47326%21100269%2C-47046%21100909%2C-46980&startname=Dudenstr.&zielname=Guben&windrichtung=S&windstaerke=5&geometry=400x300&draw=str&draw=title&draw=umland";
	$req = new HTTP::Request('GET', $url, $hdrs);
	$res = $ua->request($req);
	ok($res->is_success, "Map plot request") or diag(Dumper($res));
	is($res->header('Content_Type'), 'image/gif', "It's a GIF image");
	$content = uncompr($res);
	ok($content =~ /^GIF8/, "It's really a GIF") # no like, binary!
	    or diag $url;
    }

    for my $imagetype (
		       "gif", "png", "jpeg",
		       "svg", "mapserver",
		       "pdf", "pdf-auto", "pdf-landscape",
		       "googlemaps",
		      ) {
    SKIP: {
	    my $tests = 3;
	    skip "No mapserver tests", $tests if $skip{mapserver};

	    my $imagetype_param = ($imagetype ne "" ? "imagetype=$imagetype&" : "");
	    # This coords are sensitive to changes if
	    # search_algorithm=C-A*-2 is used. Expect failures in this
	    # case and try to fix the coords list.
	    my $url = "$action?${imagetype_param}coords=9222%2C8787%219227%2C8890%219796%2C8905%219799%2C8962%219958%2C8966%219962%2C9237%219987%2C9238%2110109%2C9240%2110189%2C9403%2110298%2C9649%2110345%2C9764%2110408%2C9800%2110480%2C9949%2110503%2C10046%2110490%2C10080%2110511%2C10128%2110605%2C10312%2110859%2C10333%2110962%2C10340%2111114%2C10338%2111336%2C10390%2111370%2C10398%2111454%2C10400%2111660%2C10402%2111949%2C10414%2112230%2C10437%2112274%2C10436%2112328%2C10442%2112755%2C10552%2112899%2C10595%2112980%2C10575%2113035%2C10635%2113082%2C10634%2113178%2C10623%2113216%2C10664%2113297%2C10781%2113332%2C10832%2113409%2C11004%2113546%2C11352%2113594%2C11489%2113720%2C11459%2113890%2C11411%2114139%2C11269%2114211%2C11229%2114286%2C11186%2114442%2C11101%2114509%2C11060%2114677%2C11027%2114752%2C11041%2114798%2C10985&startname=Dudenstr.&zielname=Sonntagstr.&windrichtung=E&windstaerke=2&geometry=400x300&draw=str&draw=wasser&draw=flaechen&draw=ampel&draw=strname&draw=title&draw=all";
	    $req = new HTTP::Request('GET', $url, $hdrs);

	    $res = $ua->request($req);
	    ok($res->is_success, "imagetype=$imagetype") or diag(Dumper($res));
	    if ($imagetype eq 'gif') {
		is($res->header('Content_Type'), 'image/gif',
		   "It's a GIF image");
		my $content = uncompr($res);
		ok($content =~ /^GIF8/, "Really a GIF image") # no qr//,binary!
		    or diag "Not a gif: $url";
		display($res);
	    } elsif ($imagetype =~ /(png|jpeg)/) {
		is($res->header('Content_Type'), 'image/' . $imagetype,
		  "It's a $imagetype image");
		ok(defined uncompr($res), "The image is non-empty");
		display($res);
	    } elsif ($imagetype =~ /pdf/) {
		is($res->header('Content_Type'), 'application/pdf',
		  "It's a PDF");
		ok(defined uncompr($res), "The PDF is non-empty");
		display($res);
	    } elsif ($imagetype =~ /svg/) {
		is($res->header('Content_Type'), "image/svg+xml",
		  "It's a SVG image");
		ok(defined uncompr($res), "The SVG is non-empty");
		display($res);
	    } else {
		like($res->header('Content_Type'), qr{^text/html},
		     "It's a $imagetype");
		ok(defined uncompr($res), "The $imagetype is non-empty");
	    }
	}
    }

    # Semantik ein bisschen testen:
    {
	$req = new HTTP::Request
	    ('GET', "$action?startname=Dudenstr.&startplz=10965&startc=8982%2C8781&zielname=Sonntagstr.&zielplz=10245&zielc=14598%2C11245&pref_seen=1&pref_speed=20&pref_cat=&pref_quality=&output_as=perldump");
	$res = $ua->request($req);
	ok($res->is_success, "Route request") or diag(Dumper($res));
	$content = uncompr($res);
	my $route = $cpt->reval($content);
	is(ref $route, "HASH", "Route is a HASH");
	for my $h_member (qw(Speed Power)) {
	    is(ref $route->{$h_member}, "HASH", "$h_member existant");
	}
	for my $a_member (qw(Route LongLatPath Path)) {
	    is(ref $route->{$a_member}, "ARRAY", "$a_member existant");
	    ok(@{$route->{$a_member}} > 0);
	}
	is(scalar @{$route->{LongLatPath}},
	   scalar @{$route->{Path}}, "Both Path arrays have same length");

	TRY: {
	    for my $xy (@{$route->{Route}}) {
		if (ref $xy ne 'HASH') {
		    fail("Route elem should be hash");
		    last TRY;
		}
		if (exists $xy->{Direction} &&
		    $xy->{Direction} !~ /^([NS]?[EW]|[NS]|h?[lr]|)$/) {
		    fail("Unexpected direction: $xy->{Direction}");
		    last TRY;
		}
		if ($xy->{Coord} !~ /^[+-]?\d+,[+-]?\d+$/) {
		    fail("Wrong Coord format: $xy->{Coord}");
		    last TRY;
		}
	    }
	    pass("Directions and Coords OK");
	}

	TRY: {
	    for my $xy (@{$route->{LongLatPath}}) {
		if ($xy !~ /^13\..*,52\..*$/) {
		    fail("Wrong coord format: $xy");
		    last TRY;
		}
	    }
	    pass("LongLatPath check OK, everything seems to be coordinates in Berlin");
	}

	for my $s (qw(Methfesselstr Skalitzer Sonntagstr)) {
	    ok((grep { $_->{Strname} =~ /$s/ } @{$route->{Route}}),
	       "Street $s expected in route");
	}
	ok($route->{Len} > 7000 && $route->{Len} < 8000, "check route length")
	    or diag "Route length: $route->{Len}";
    }

    {
	$req = HTTP::Request->new
	    ('GET', "$action?" . CGI->new({startc=>"42685,19584",
					   zielc=>"-8063,17487",
					   scope=>"region", # why needed?
					  })->query_string);
	$res = $ua->request($req);
	ok($res->is_success, "Request with crossings in region")
	    or diag(Dumper($res));
	$content = uncompr($res);
	like($content, qr{\QWallstr./Karl-Liebknecht-Str./August-Bebel-Str./Große Str. (Strausberg)\E}, "Simplified crossing");
	like($content, qr{\QHumboldtallee/Haydnallee/Fröbelstr. (Falkensee)},
	     "Simplified crossing (goal)");
    }

    {
	$req = HTTP::Request->new
	    ('GET', "$action?" . CGI->new({startc=>"9222,8787",
					   zielc=>"-502,-803",
					   scope=>"region", # why needed?
					  })->query_string);
	$res = $ua->request($req);
	ok($res->is_success, "Another request with crossings")
	    or diag(Dumper($res));
	$content = uncompr($res);
	like($content, qr{\QDudenstr./Mehringdamm/Platz der Luftbrücke/Tempelhofer Damm\E}, "No simplification for Berlin crossings needed");
	like($content, qr{\QThomas-Müntzer-Damm (Kleinmachnow)/Warthestr. (Teltow)\E}, "No simplification possible between different places");
    }

    {
	my %common_args = ( startc=>'16720,6845',
			    zielc=>'17202,8391',
			    startname=>'Schnellerstr.',
			    zielname=>'Hegemeisterweg (Karlshorst)',
			    pref_speed=>20,
			    pref_seen=>1,
			  );
	$req = HTTP::Request->new
	    ('GET', "$action?" . CGI->new({%common_args,
					   pref_ferry=>'use',
					  })->query_string);
	$res = $ua->request($req);
	ok($res->is_success, 'Request with ferry=use')
	    or diag(Dumper($res));
	$content = uncompr($res);
	like($content, qr{F11.*Baumschulenstr.*Wilhelmstrand}, 'Found use of ferry F11');
	like($content, qr{Überfahrt.*kostet}, 'Found tariff information for ferry');

	$req = HTTP::Request->new
	    ('GET', "$action?" . CGI->new({%common_args,
					   pref_ferry=>'',
					  })->query_string);
	$res = $ua->request($req);
	ok($res->is_success, 'Request without ferry=use')
	    or diag(Dumper($res));
	$content = uncompr($res);
	unlike($content, qr{F11.*Baumschulenstr.*Wilhelmstrand}, 'No use of ferry F11');
	unlike($content, qr{Überfahrt.*kostet}, 'No tariff information for ferry');			    
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

	$req = HTTP::Request->new
	    ('GET', "$action?" . CGI->new({ start => "invalidenstr",
					    zielname => "müller-breslau-str",
					  })->query_string);
	$res = $ua->request($req);
	ok($res->is_success, "The Mueller-Breslau request")
	    or diag(Dumper($res));
	$content = uncompr($res);
	like($content, qr{Invalidenstr\..*Ecke.*Müller-Breslau-Str\..*Ecke}s, "'Ecke' for both crossings");
    }

 XXX: 
    {   # All street types (as defined in PLZ.pm) except "streets"
        # should provide automatically the nearest crossing to the
        # Berlin.coords.data coordinate. Note that this should also
        # happen for railway stations --- this is already tested in
        # cgi-mechanize.t

	$req = HTTP::Request->new
	    ('GET', "$action?" . CGI->new({ start2 => 'Westend (Kolonie)!Westend!14050!935,12882!0', # note: multiple results with "Westend"
					    via    => 'Weinbergshöhe',
					    ziel2  => 'Eiswerder (Insel)!Hakenfelde!13585!-2318,15601!0', # note: multiple results with "Eiswerder"
					    scope  => 0,
					  })->query_string);
	$res = $ua->request($req);
	ok($res->is_success, 'Westend/Weinbergshoehe/Eiswerder')
	    or diag(Dumper($res));
	$content = uncompr($res);
	BBBikeTest::like_long_data($content, qr{   Die[ ]nächste[ ]Kreuzung[ ]ist.*
						   Die[ ]nächste[ ]Kreuzung[ ]ist.*
						   Die[ ]nächste[ ]Kreuzung[ ]ist
					   }xs, 'Find automatically next crossing for non-streets');
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
	BBBikeTest::like_long_data($resp->content, qr{startname.*Dudenstr});
	BBBikeTest::like_long_data($resp->content, qr{startplz.*10965});

	$resp = $ua->get($cgiurl . "?" . CGI->new({ossp => '"unter den linden"'})->query_string);
	ok($resp->is_success, "ossp with start with spaces");
	BBBikeTest::like_long_data($resp->content, qr{startname.*Unter den Linden});
	BBBikeTest::like_long_data($resp->content, qr{startplz.*10117});

	$resp = $ua->get($cgiurl . "?" . CGI->new({ossp => 'dudenstr seumestr'})->query_string);
	ok($resp->is_success, "ossp with start and goal");
	BBBikeTest::like_long_data($resp->content, qr{startname.*Dudenstr});
	BBBikeTest::like_long_data($resp->content, qr{zielname.*Seumestr});
	BBBikeTest::like_long_data($resp->content, qr{Genaue Kreuzung angeben});

	$resp = $ua->get($cgiurl . "?" . CGI->new({ossp => '  "unter den lind"    "habelschwerdter alle"'})->query_string);
	ok($resp->is_success, "ossp with start and goal and spaces");
	BBBikeTest::like_long_data($resp->content, qr{startname.*Unter den Linden});
	BBBikeTest::like_long_data($resp->content, qr{zielname.*Habelschwerdter Allee});
	BBBikeTest::like_long_data($resp->content, qr{Genaue Kreuzung angeben});

	$resp = $ua->get($cgiurl . "?" . CGI->new({ossp => 'dudenstr "unter den linden" seumestr'})->query_string);
	ok($resp->is_success, "ossp with start, via and goal");
	BBBikeTest::like_long_data($resp->content, qr{startname.*Dudenstr});
	BBBikeTest::like_long_data($resp->content, qr{vianame.*Unter den Linden});
	BBBikeTest::like_long_data($resp->content, qr{zielname.*Seumestr});
	BBBikeTest::like_long_data($resp->content, qr{Genaue Kreuzung angeben});
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

	my $resp;

	# Do not use CGI.pm here, because it is known to have issues!
	my %params = (startc=>"9322,11487",
		      zielc=>"9126,12413",
		      startname=>"Mauerstr. (Mitte)/Krausenstr.",
		      zielname=>"Neustädtische Kirchstr./Mittelstr. (Mitte)",
		      pref_seen=>1,
		     );
	my $url = $cgiurl . "?" . join("&", map { "$_=" . my_uri_escape($params{$_}) } keys %params);
	$resp = $ua->get($url);
	diag "URL: $url" if $v;
	ok($resp->is_success, "Request with latin1 incoming CGI params")
	    or diag $resp->as_string;
	my $content = uncompr($resp);
	my $fail_count = 0;
	$fail_count++ if !BBBikeTest::like_long_data($content, qr{Neust%e4dtische}i, "Found iso-8859-1 encoding in CGI params in links");
	$fail_count++ if !BBBikeTest::unlike_long_data($content, qr{Neust%C3%A4dtische}i, "No single encoded utf-8 in CGI params in links");
	$fail_count++ if !BBBikeTest::unlike_long_data($content, qr{Neust%C3%83%C2%A4dtische}i, "No double encoded utf-8 in CGI params in links");
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
	my $resp = $ua->get($cgiurl . "?scope=wideregion&detailmapx=2&detailmapy=6&type=start&detailmap.x=200&detailmap.y=226");
	ok($resp->is_success);
	my $content = uncompr($resp);
	BBBikeTest::like_long_data($content, qr{diese Koordinaten konnte keine Kreuzung gefunden werden},
				   "No crossing for coords in the Döberitzer Heide");
    }

    {
	my $resp = $ua->get($cgiurl . "?scope=wideregion&detailmapx=3&detailmapy=8&type=start&detailmap.x=304&detailmap.y=331");
	ok($resp->is_success);
	my $content = uncompr($resp);
	BBBikeTest::like_long_data($content, qr{Rudolf-Breitscheid-Str},
				   "Crossing in Potsdam near Berlin, should get a street in Potsdam");
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

sub uncompr {
    my $res = shift;
    if ($res->can("decoded_content")) {
	my %opts;
	if ($res->content_is_xml) {
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

# REPO BEGIN
# REPO NAME file_name_is_absolute /home/e/eserte/src/repository 
# REPO MD5 89d0fdf16d11771f0f6e82c7d0ebf3a8
BEGIN {
    if (eval { require File::Spec; defined &File::Spec::file_name_is_absolute }) {
	*file_name_is_absolute = \&File::Spec::file_name_is_absolute;
    } else {
	*file_name_is_absolute = sub {
	    my $file = shift;
	    my $r;
	    if ($^O eq 'MSWin32') {
		$r = ($file =~ m;^([a-z]:(/|\\)|\\\\|//);i);
	    } else {
		$r = ($file =~ m|^/|);
	    }
	    $r;
	};
    }
}
# REPO END
# REPO BEGIN
# REPO NAME is_in_path /home/e/eserte/src/repository 
# REPO MD5 81c0124cc2f424c6acc9713c27b9a484
sub is_in_path {
    my($prog) = @_;
    return $prog if (file_name_is_absolute($prog) and -f $prog and -x $prog);
    require Config;
    my $sep = $Config::Config{'path_sep'} || ':';
    foreach (split(/$sep/o, $ENV{PATH})) {
	if ($^O eq 'MSWin32') {
	    # maybe use $ENV{PATHEXT} like maybe_command in ExtUtils/MM_Win32.pm?
	    return "$_\\$prog"
		if (-x "$_\\$prog.bat" ||
		    -x "$_\\$prog.com" ||
		    -x "$_\\$prog.exe" ||
		    -x "$_\\$prog.cmd");
	} else {
	    return "$_/$prog" if (-x "$_/$prog" && !-d "$_/$prog");
	}
    }
    undef;
}
# REPO END

sub my_uri_escape {
    my $toencode = shift;
    return undef unless defined($toencode);
    $toencode=~s/([^a-zA-Z0-9_.~-])/uc sprintf("%%%02x",ord($1))/eg;
    return $toencode;
}
