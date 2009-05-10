#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: mapserver.t,v 1.6 2006/10/07 13:36:13 eserte Exp $
# Author: Slaven Rezic
#

use strict;

BEGIN {
    if (!eval q{
	use WWW::Mechanize 1.54;
	use WWW::Mechanize::FormFiller;
	use Test::More;
	use Sys::Hostname qw(hostname);
	1;
    }) {
	print "1..0 # skip: no WWW::Mechanize (1.54), WWW::Mechanize::FormFiller and/or Test::More modules\n";
	exit;
    }
}

if (hostname !~ m{^(biokovo|biokovo-amd64|vran)\.herceg\.de} && hostname !~ /radzeit/i) {
    print "1..0 # skip: works only on vran/biokovo\n";
    exit;
}

use FindBin;
use lib ("$FindBin::RealBin",
	 "$FindBin::RealBin/..",
	);
use BBBikeTest;

use CGI;
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

# Get SCOPES from mapserver/brb/Makefile:
my @scopes = qw(brb b inner-b wide p);

my $core_tests = 210;
plan tests => 1 + $core_tests;

sub get_agent {
    my $agent = WWW::Mechanize->new;
    $agent->agent("BBBikeTest/1.0");
    $agent->env_proxy;
    $agent;
}

sub is_on_mapserver_page {
    my($agent, $for) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    like($agent->response->request->uri, qr{/mapserv}, "Show mapserver output for $for");

    my(@images) = $agent->find_all_images;
    is(scalar(@images), 4, "Expected 4 images: map, ref, legend, scalebar")
	or diag($agent->content);
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
##XXX How to get site-independent?
#     my $q = CGI->new({map => $ms->{MAPSERVER_DIR}."/brb-b.map",
# 		      program => $ms->{MAPSERVER_PROG_RELURL},
# 		     });
#     $url = $ms->{MAPSERVER_PROG_URL} . "?" . $q->query_string;
    my $host = hostname =~ /radzeit/ ? "www.radzeit.de" : "radzeit";
    $url = "http://$host/cgi-bin/bbbike.cgi?mapserver=1";
    $agent->get($url);
    ok($agent->success, "$url is ok");

    my $skip_not_useable = ($host eq "radzeit" && index($agent->content, 'Unable to access file.') > -1 && index($agent->content, '/var/www/domains/radzeit.de/www/') > -1);

    SKIP:
    {
	if ($skip_not_useable) {
	    diag "To fix this, do: cd $FindBin::RealBin/../projects/www.radzeit.de && make deploy-local";
	    skip("not setup for local operation", $core_tests)
	}

	is_on_mapserver_page($agent, "...");

	for my $layer (@layers) {
	    $agent->form_number(1) if $agent->forms and scalar @{$agent->forms};
	    { local $^W; for ($layer) { $agent->tick('layer', $_); };}
	    $agent->submit;
	    is_on_mapserver_page($agent, "Layer $layer ticked");
	    $agent->back;
	}

	for my $scope (@scopes) {
	    my $uri = $agent->response->request->uri;
	    ($uri, my($qs)) = $uri =~ m{^(.*)\?(.*)};
	    my $q = CGI->new($qs);
	    my $map = $q->param("map");
	    $map =~ s{(/brb-)[^/]+(\.map)$}{$1$scope$2};
	    $q->param("map", $map);
	    $agent->get($uri."?".$q->query_string);
	    is_on_mapserver_page($agent, "Scope $scope for reference map");
	}
    }

}

__END__
