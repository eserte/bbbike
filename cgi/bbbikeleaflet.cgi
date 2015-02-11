#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2012,2013,2015 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use CGI ();

use BBBikeLeaflet::Template ();
use BBBikeCGI::Config ();

my $htmldir = "$FindBin::RealBin/../html";
my $htmlfile = "$htmldir/bbbikeleaflet.html";

my $cgi_config = BBBikeCGI::Config->load_config("$FindBin::RealBin/bbbike.cgi.config", 'perl');

my $q = CGI->new;
print $q->header('text/html; charset=utf-8');

my $leaflet_ver        = $q->param('leafletver');
my $enable_upload      = $q->param('upl') || 0;
my $enable_accel       = $q->param('accel') || 0;
my $use_osm_de_map     = $q->param('osmdemap') || 0;
my $devel              = $q->param('devel') || 0;
my $show_expired_session_msg;
my $coords;
if ($q->param('coordssession')) {
    require BBBikeApacheSessionCounted;
    if (my $sess = BBBikeApacheSessionCounted::tie_session($q->param('coordssession'))) {
	$coords = $sess->{routestringrep};
    } else {
	$show_expired_session_msg = 1;
    }
}
my $show_feature_list;
if ($devel) {
    $enable_upload = $show_feature_list = 1;
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
     coords                   => $coords,
    );
$tpl->process(\*STDOUT);

__END__
