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
	1;
    }) {
	print "1..0 # skip: no HTML::Form, LWP::UserAgent and/or Test::More modules\n";
	exit;
    }
}

use FindBin;
use lib ($FindBin::RealBin, "$FindBin::RealBin/..");

use CGI qw();
use Getopt::Long;

use BBBikeTest qw(get_std_opts like_html unlike_html $cgidir xmllint_string);

sub bbbike_cgi_search ($$);
sub bbbike_cgi_geocode ($$);

#plan 'no_plan';
plan tests => 52;

if (!GetOptions(get_std_opts("cgidir"),
	       )) {
    die "usage!";
}

{
    my $make = $^O =~ m{bsd}i ? "make" : "pmake";
    # -f BSDmakefile needed for old pmake (which may be found in Debian)
    system("cd $FindBin::RealBin/data && $make -f BSDmakefile");
    diag "Error running make, expect test failures..." if $? != 0;
}

my $testcgi = "$cgidir/bbbike-test.cgi";
my $ua = LWP::UserAgent->new;
$ua->agent("BBBike-Test/1.0");

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
    my $resp = bbbike_cgi_geocode +{start => 'Really unknown street (make it long, so approx cannot handle it, too)',
				    ziel => 'Yorckstr.',
				   }, 'Find normal street';
    not_on_crossing_pref_page($resp);
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
	xmllint_string($resp->decoded_content, 'Well-formedness of XML output');
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
	my $doc = $p->parse_string($resp->decoded_content(charset => "none"));
	my $startname = $doc->findvalue('/BBBikeRoute/Route/Point[position()=1]/Strname');
	is($startname, 'Wilhelmshöhe', 'Expected startname in right encoding');
    }

    {
	my $resp = bbbike_cgi_search +{%route_params, output_as => 'gpx-route'}, 'GPX route';
	my $doc = $p->parse_string($resp->decoded_content(charset => "none"));
	$doc->documentElement->setNamespaceDeclURI(undef, undef);
	my $startname = $doc->findvalue('/gpx/rte/rtept[1]/name');
	is($startname, 'Wilhelmshöhe', 'Expected startname in right encoding');
    }

    {
	my $resp = bbbike_cgi_search +{%route_params, output_as => 'kml-track'}, 'KML output';
	my $doc = $p->parse_string($resp->decoded_content(charset => "none"));
	$doc->documentElement->setNamespaceDeclURI(undef, undef);
	my $name = $doc->findvalue('/kml/Document/Placemark/name');
	like($name, qr{^Wilhelmshöhe}, 'Expected name in right encoding');
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
}


sub bbbike_cgi_search ($$) {
    my($params, $testname) = @_;
    $params->{pref_seen} = 1;
    $params->{pref_speed} = 20 if !exists $params->{pref_speed};
    my $url = $testcgi . '?' . CGI->new($params)->query_string;
    my $resp = $ua->get($url);
    ok($resp->is_success, $testname);
    $resp;
}

sub bbbike_cgi_geocode ($$) {
    my($params, $testname) = @_;
    $params->{pref_seen} = 0;
    my $url = $testcgi . '?' . CGI->new($params)->query_string;
    my $resp = $ua->get($url);
    ok($resp->is_success, $testname);
    $resp;
}

sub on_crossing_pref_page {
    my($resp) = @_;
    like_html($resp->decoded_content, 'Genaue Kreuzung angeben:', 'On crossing/pref page');
}

sub not_on_crossing_pref_page {
    my($resp) = @_;
    unlike_html($resp->decoded_content, 'Genaue Kreuzung angeben:', 'Not on crossing/pref page');
}

sub on_routelist_page {
    my($resp) = @_;
    like_html($resp->decoded_content, qr{Route von .* bis}, 'On routelist page (title)');
    like_html($resp->decoded_content, qr{Fahrzeit}, 'On routelist page (Fahrzeit)');
}

__END__
