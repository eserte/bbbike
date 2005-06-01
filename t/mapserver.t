#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: mapserver-util.t,v 1.2 2005/05/12 22:22:16 eserte Exp $
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
	print "1..0 # skip: no WWW::Mechanize and/or Test::More modules\n";
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

# Get from elsewhere?
my @layers = qw(
		qualitaet
		handicap
		radwege
		blocked
		bahn
		gewaesser
		faehren
		flaechen
		grenzen
		ampeln
		sehenswuerdigkeit
		obst
		orte
		fragezeichen
		route
	       );

plan tests => 41;

sub get_agent {
    my $agent = WWW::Mechanize->new;
    $agent->agent("BBBikeTest/1.0");
    $agent->env_proxy;
    $agent;
}

sub is_on_mapserver_page {
    my($agent, $for) = @_;
    like($agent->response->request->uri, qr{/mapserv.cgi}, "Show mapserver output for $for");

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

sub get_config {
    #die "Not yet polished";
    # guess position of bbbike.cgi.config
    require File::Basename;
    require File::Spec;
    my $bbbike_dir = File::Spec->rel2abs(File::Basename::dirname($FindBin::RealBin));
    my $bbbike_cgi_conf_path = File::Spec->catfile($bbbike_dir, "cgi", "bbbike.cgi.config");
    if (!-r $bbbike_cgi_conf_path) {
	die "$bbbike_cgi_conf_path is not existent or readable";
    }
    require BBBikeMapserver;
    my $ms = BBBikeMapserver->new;
    $ms->read_config($bbbike_cgi_conf_path);
    $ms;

}

my $ms = get_config();
{
    my $agent = get_agent();
    my $url;
    $url = $ms->{MAPSERVER_PROG_URL} . '?map=%2Fhome%2Fslavenr%2Fwork2%2Fbbbike%2Fmapserver%2Fbrb%2Fbrb-b.map&mode=&zoomdir=&mode_or_zoomdir=0&zoomsize=2&orig_mode=%5Borig_mode%5D&orig_zoomdir=%5Borig_zoomdir%5D&imgxy=275+275&imgext=5593.000000+9243.000000+11593.000000+15243.000000&savequery=true&imgsize=550+550&program=%2Fmapserver%2Fcgi%2Fmapserv.cgi&bbbikeurl=http%3A%2F%2Flocalhost%3A8080%2Fbbbike%2Fcgi%2Fbbbike.cgi&bbbikemail=slaven%40rezic.de&startc=%5Bstartc%5D&coordset=';
    $agent->get($url);
    ok($agent->success, "$url is ok");

    is_on_mapserver_page($agent, "...");

    for my $layer (@layers) {
	$agent->form(1) if $agent->forms and scalar @{$agent->forms};
	{ local $^W; for ($layer) { $agent->tick('layer', $_); };}
	$agent->submit;
	is_on_mapserver_page($agent, "Layer $layer ticked");
	$agent->back;
    }

}

__END__
