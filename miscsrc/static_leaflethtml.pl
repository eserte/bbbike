#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2015 Slaven Rezic. All rights reserved.
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

use Getopt::Long;

use BBBikeLeaflet::Template;

my $root_url = 'http://bbbike.de';
my $shortcut_icon;
my $geojson_file;
my $geojsonp_url;
my $show_feature_list = 1;
my $leaflet_ver;
my $title;
my $disable_routing;
GetOptions(
	   'rooturl=s'              => \$root_url,
	   'geojson|geojson-file=s' => \$geojson_file,
	   'geojsonp-url=s'         => \$geojsonp_url,
	   'show-feature-list!'     => \$show_feature_list,
	   'leafletver=s'           => \$leaflet_ver,
	   'title=s'                => \$title,
	   'disable-routing'        => \$disable_routing,
	   'shortcuticon=s'         => \$shortcut_icon,
	  )
    or die "usage: $0 [-rooturl ...] [-geojson ... | -geojsonp-url ...] [-title ...] [-disable-routing] [-shortcut-icon url]\n";

($geojson_file && $geojsonp_url)
    and die "Can't use -geojson and -geojsonp-url together.\n";

my $title_html;
if (defined $title) {
    require HTML::Entities;
    $title_html = HTML::Entities::encode_entities_numeric($title);
}

my $tpl = BBBikeLeaflet::Template->new(
				       root_url     => $root_url,
				       geojson_file => $geojson_file,
				       geojsonp_url  => $geojsonp_url,
				       show_feature_list => $show_feature_list,
				       leaflet_ver => $leaflet_ver,
				       title_html => $title_html,
				       disable_routing => $disable_routing,
				       shortcut_icon => $shortcut_icon,
				      );
$tpl->process(\*STDOUT);

__END__
