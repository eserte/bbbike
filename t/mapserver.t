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

plan tests => 75;

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
    die "Not yet polished";
    # guess position of bbbike.cgi.config
    require File::Basename;
    require File::Spec;
    my $bbbike_dir = File::Spec->rel2abs(File::Basename::dirname(File::Basename::dirname($INC{"BBBikeDraw/MapServer.pm"})));
    my $bbbike_cgi_conf_path = File::Spec->catfile($bbbike_dir, "cgi", "bbbike.cgi.config");
    if (!-r $bbbike_cgi_conf_path) {
	die "$bbbike_cgi_conf_path is not existent or readable";
    }
    require BBBikeMapserver;
    my $ms = BBBikeMapserver->new;
    $ms->read_config($bbbike_cgi_conf_path);
}

{
    die "NYI";

    my $agent = get_agent();
    my $url = $cgidir . "/mapserver_address.cgi";
    $agent->get($url);
    ok($agent->success, "$url is ok");

    is_on_mapserver_page($agent, "...");
}

__END__
