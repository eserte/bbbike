#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2012,2013,2015,2016,2018,2023,2024 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib (grep { -d }
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/BBBike", # weitere Alternative
	 "$FindBin::RealBin/BBBike/lib",
	);

use CGI ();

use BBBikeLeaflet::Template ();
use BBBikeCGI::Config ();
use BBBikeCGI::Util ();

my $cgi_config = BBBikeCGI::Config->load_config("$FindBin::RealBin/bbbike.cgi.config", 'perl');

my $q = CGI->new;
print $q->header('text/html; charset=utf-8');

my $leaflet_ver        = $q->param('leafletver');
my $enable_upload      = $q->param('upl') || 0;
my $enable_accel       = $q->param('accel') || 0;
my $use_osm_de_map     = $q->param('osmdemap') || 0;
my $devel              = $q->param('devel') || 0;
my $route_title        = $q->param('routetitle');
my $replay_trk         = $q->param('replaytrk');
my $loc                = $q->param('loc');
my $geojsonp_url       = $q->param('geojsonp_url');
my $show_feature_list  = $q->param('fl') || 0; # feature list can currently only be enabled together with a geojsonp_url
my $show_expired_session_msg;
my($coords, $wgs84_coords);
if ($q->param('coordssession')) {
    require BBBikeApacheSessionCounted;
    if (my $sess = BBBikeApacheSessionCounted::tie_session(scalar $q->param('coordssession'))) {
	$coords = $sess->{routestringrep};
    } else {
	$show_expired_session_msg = 1;
    }
} elsif ($q->param('coords') || $q->param('coords_forw') || $q->param('coords_rev')) {
    # Currently coords_forw and coords_rev are rendered the same, but
    # it would be nice if the different directions could be
    # visualized.
    $coords = [
	       BBBikeCGI::Util::my_multi_param($q, 'coords'),
	       BBBikeCGI::Util::my_multi_param($q, 'coords_forw'),
	       BBBikeCGI::Util::my_multi_param($q, 'coords_rev'),
	      ];
} elsif ($q->param('gple') || $q->param('gpleu')) {
    my $gple = scalar $q->param('gpleu') ? do {
	require Route::GPLEU;
	Route::GPLEU::gpleu_to_gple(scalar $q->param('gpleu'));
    } : scalar $q->param('gple');
    require Algorithm::GooglePolylineEncoding;
    my @polyline = Algorithm::GooglePolylineEncoding::decode_polyline($gple);
    $wgs84_coords = [ join "!", map { join ',', $_->{lon}, $_->{lat} } @polyline ];
}

my $show_speedometer;
if ($devel) {
    $enable_upload = $show_feature_list = $show_speedometer = 1;
    # $enable_accel = 1; # XXX not yet
    $leaflet_ver = '0.7.3' if !defined $leaflet_ver;
}

my $tpl = BBBikeLeaflet::Template->new
    (
     leaflet_ver              => $leaflet_ver,
     enable_upload            => $enable_upload,
     enable_accel             => $enable_accel,
     use_osm_de_map           => $use_osm_de_map,
     cgi_config               => $cgi_config,
     show_expired_session_msg => $show_expired_session_msg,
     show_feature_list        => $show_feature_list,
     show_speedometer         => $show_speedometer,
     coords                   => $coords,
     wgs84_coords             => $wgs84_coords,
     route_title              => $route_title,
     replay_trk               => $replay_trk,
     loc                      => $loc,
     geojsonp_url             => $geojsonp_url,
    );
$tpl->process(\*STDOUT);

__END__
