#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: mapserver-util.t,v 1.5 2006/10/10 22:40:39 eserte Exp $
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
	print "1..0 # skip: no WWW::Mechanize, WWW::Mechanize::FormFiller and/or Test::More modules\n";
	exit;
    }
}

use FindBin;
use lib ("$FindBin::RealBin",
	 "$FindBin::RealBin/..",
	);
use BBBikeTest;

use Getopt::Long;

if (!GetOptions(get_std_opts("cgidir", "xxx"),
	       )) {
    die "usage: $0 [-cgidir url] [-xxx]";
}

plan tests => 97;

sub get_agent {
    my $agent = WWW::Mechanize->new;
    $agent->agent("BBBikeTest/1.0");
    $agent->env_proxy;
    $agent;
}

sub is_on_mapserver_page {
    my($agent, $for) = @_;
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

{
    my $agent = get_agent();
    my $url = $cgidir . "/mapserver_address.cgi";
    $agent->get($url);
    ok($agent->success, "$url is ok");

    # Street
    $agent->form(1) if $agent->forms and scalar @{$agent->forms};
    { local $^W; $agent->current_form->value('street', 'Dudenstr'); };
    $agent->submit();
    is_on_mapserver_page($agent, "street Dudenstr");

    # City
    $agent->back();
    $agent->form(2);
    { local $^W; $agent->current_form->value('city', 'rollberg'); };
    $agent->submit();
    is_on_mapserver_page($agent, "city");

    # Lat/long
    $agent->back();
    $agent->form(4);
    { local $^W; $agent->current_form->value('lat', '52.5'); };
    { local $^W; $agent->current_form->value('long', '13.5'); };
    $agent->submit();
    is_on_mapserver_page($agent, "lat/long DDD");

    $agent->back();
    { local $^W; $agent->current_form->value('latD', '52'); };
    { local $^W; $agent->current_form->value('latM', '30'); };
    { local $^W; $agent->current_form->value('longD', '13'); };
    { local $^W; $agent->current_form->value('longM', '30'); };
    $agent->submit();
    is_on_mapserver_page($agent, "lat/long DMS");

    $agent->back();
    $agent->form(3);
    { local $^W; $agent->current_form->value('searchterm', 'funkturm'); };
    $agent->submit();
    like($agent->uri, qr{/mapserver_address.cgi}, "Multiple matches, same address");
    like($agent->content, qr{Mehrere Treffer}, 'Expected "multiple ..." content');

    $agent->form(1);
    { local $^W; $agent->current_form->value('coords', 'Funkturm (Plätze)'); };
    $agent->submit();
    is_on_mapserver_page($agent, "fulltext term");

    $agent->back();
    $agent->form(2);
    { local $^W; $agent->current_form->value('street', 'heerstr'); };
    $agent->submit();
    like($agent->uri, qr{/mapserver_address.cgi}, "Multiple street matches, same address");
    like($agent->content, qr{Mehrere.*Stra.*en}, 'Expected "multiple ..." content');

    $agent->form(1);
    { local $^W; $agent->current_form->value('coords', 'Heerstr. (Spandau, 13591)'); };
    $agent->submit();
    is_on_mapserver_page($agent, "after multiple streets");

    $agent->back();
    $agent->form(2);
    { local $^W; $agent->current_form->value('street', 'heerstr'); };
    { local $^W; $agent->current_form->value('citypart', 'spandau'); };
    $agent->submit();
    is_on_mapserver_page($agent, "street with citypart output");
}

__END__
