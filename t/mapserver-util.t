#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;

BEGIN {
    if (!eval q{
	use WWW::Mechanize;
	use WWW::Mechanize::FormFiller;
	use Test::More;
	1;
    }) {
	print "1..0 # skip no WWW::Mechanize, WWW::Mechanize::FormFiller and/or Test::More modules\n";
	exit;
    }
}

if ($ENV{BBBIKE_TEST_SKIP_MAPSERVER}) {
    plan skip_all => 'Skipping mapserver-related tests';
    exit;
}

use FindBin;
use lib ("$FindBin::RealBin",
	 "$FindBin::RealBin/..",
	);
use BBBikeTest qw(check_cgi_testing get_std_opts $do_xxx $cgidir);

use Getopt::Long;

check_cgi_testing;

if (!GetOptions(get_std_opts("cgidir", "xxx"),
	       )) {
    die "usage: $0 [-cgidir url] [-xxx]";
}

if ($do_xxx) {
    Test::More->import(qw(no_plan));
} else {
    plan tests => 106;
}

sub get_agent {
    my $agent = WWW::Mechanize->new;
    $agent->agent("BBBike-Test/1.0");
    $agent->env_proxy;
    $agent;
}

sub is_on_mapserver_page {
    my($agent, $for) = @_;
    local $Test::Builder::Level = $Test::Builder::Level+1;
    like($agent->response->request->uri, qr{(/mapserv.cgi|cgi-bin/mapserv)}, "Show mapserver output for $for");

    my(@images) = $agent->find_all_images;
    is(scalar(@images), 4, "Expected 4 images: map, ref, legend, scalebar");
    for my $image (@images) {
	my $image_url = $image->url;
	$agent->get($image_url);
	ok($agent->success, "Image $image_url is OK");
	like($agent->ct, qr{^image/}, "... and it's really an image");
	$agent->back;
    }
}

goto XXX if $do_xxx;

{
    my $agent = get_agent();
    my $url = $cgidir . "/mapserver_address.cgi/coords=19987,12658/mapext=19354,13525,20856,12589/layer=qualitaet/layer=handicap/layer=radwege/layer=fragezeichen/layer=sehenswuerdigkeit/layer=ampeln/layer=blocked";
    $agent->get($url);
    ok($agent->success, "$url with pathinfo is ok");
    is_on_mapserver_page($agent, "pathinfo really works");
}

{
    my $agent = get_agent();
    my $url = $cgidir . "/mapserver_address.cgi?coords=19987,12658;mapext=19354+13525+20856+12589;layer=qualitaet;layer=handicap;layer=radwege;layer=fragezeichen;layer=sehenswuerdigkeit;layer=ampeln;layer=blocked";
    $agent->get($url);
    ok($agent->success, "$url with param style is ok");
    is_on_mapserver_page($agent, "param style really works");
}

XXX: {
    my $agent = get_agent();
    my $url = $cgidir . "/mapserver_address.cgi";
    $agent->get($url);
    ok($agent->success, "$url is ok");

    # Street
    $agent->submit_form(form_number => 1,
			fields => {
				   'street' => 'Dudenstr',
				  },
		       );
    is_on_mapserver_page($agent, "street Dudenstr");

    # City
    $agent->back();
    $agent->submit_form(form_number => 2,
			fields => {'city', 'rollberg'},
		       );
    is_on_mapserver_page($agent, "city");
    $agent->back();

    # Lat/long DDD
    $agent->submit_form(form_number => 4,
			fields => {'lat', '52.5',
				   'long', '13.5',
				  },
		       );
    is_on_mapserver_page($agent, "lat/long DDD");
    $agent->back();

    # wrong Lat/long (non-number)
    $agent->submit_form(form_number => 4,
			fields => {'lat', 'a',
				   'long', 'b',
				  },
		       );
    like($agent->uri, qr{/mapserver_address.cgi}, "Error, same URL");
    like($agent->content, qr{Falsche Werte.*DDD}, "Error message (DDD)");

    # Lat/long DMS
    $agent->submit_form(form_number => 4,
			fields => {'latD', '52',
				   'latM', '30',
				   'longD', '13',
				   'longM', '30',
				  },
		       );
    is_on_mapserver_page($agent, "lat/long DMS");
    $agent->back();

    # wrong Lat/long (non-number)
    $agent->submit_form(form_number => 4,
			fields => {'latD', 'a',
				   'latM', 'b',
				   'longD', 'c',
				   'longM', 'd',
				  },
		       );
    like($agent->uri, qr{/mapserver_address.cgi}, "Error, same URL");
    like($agent->content, qr{Falsche Werte.*DMS}, "Error message (DMS)");

    ######################################################################
    # non-existent

    $agent->submit_form(form_number => 3,
			fields => {'searchterm', 'thisreallydoesnotexistBlafoobarXYZ'},
		       );
    like($agent->uri, qr{/mapserver_address.cgi}, "Nothing found, same address");
    like($agent->content, qr{Nichts gefunden}, 'Expected "nothing found" content for nonsense search term');

    ######################################################################
    # Volltext (Funkturm)

    $agent->submit_form(form_number => 3,
			fields => {'searchterm', 'funkturm'},
		       );
    like($agent->uri, qr{/mapserver_address.cgi}, "Multiple matches, same address");
    like($agent->content, qr{Mehrere Treffer}, 'Expected "multiple ..." content for Funkturm');

    {
	my $form = $agent->form_number(1);
	my $input = $form->find_input('coords','radio');
	$agent->submit_form(form_number => 1,
			    fields => {'coords', ($input->possible_values)[0]}, # This is probably 'Funkturm (Plätze)'
			   );
    }
    is_on_mapserver_page($agent, "fulltext term");

    $agent->back();

    ######################################################################
    # Straße (Heerstr.)

    $agent->submit_form(form_number => 2,
			fields => {'street', 'heerstr'},
		       );
    like($agent->uri, qr{/mapserver_address.cgi}, "Multiple street matches, same address");
    like($agent->content, qr{Mehrere.*Stra.*en}, 'Expected "multiple ..." content for Heerstr');

    $agent->submit_form(form_number => 1,
			fields => {'coords', 'Heerstr. (Staaken, Westend, Wilhelmstadt; 13591, 13593, 14052)'},
		       );
    is_on_mapserver_page($agent, "after multiple streets");

    $agent->back();
    $agent->submit_form(form_number => 2,
			fields => {'street', 'heerstr',
				   'citypart', 'westend',
				  },
		       );
    is_on_mapserver_page($agent, "street with citypart output");

    $agent->back();

    ######################################################################
    # Straße (Bahnhofstr.)

    $agent->submit_form(form_number => 2,
			fields => {'street', 'bahnhofstr'},
		       );
    like($agent->uri, qr{/mapserver_address.cgi}, "Multiple street matches, same address");
    like($agent->content, qr{Mehrere.*Stra.*en}, 'Expected "multiple ..." content for Bahnhofstr');

    {
	my $form = $agent->form_number(1);
	my $input = $form->find_input('coords','radio');
	cmp_ok(scalar $input->possible_values, ">=", 8, "Found a lot of Bahnhofstr.");
    }
}

__END__
