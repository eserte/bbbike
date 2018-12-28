# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2015,2017,2018 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeLeaflet::Template;

use strict;
use vars qw($VERSION);
$VERSION = '0.03';

sub new {
    my($class, %args) = @_;

    my $htmldir = delete $args{htmldir} || do {
	require BBBikeUtil;
	BBBikeUtil::bbbike_root() . '/html';
    };
    my $use_old_url_layout       = delete $args{use_old_url_layout};
    my $cgi_config               = delete $args{cgi_config};
    my $leaflet_ver              = delete $args{leaflet_ver};
    my $enable_upload            = delete $args{enable_upload};
    my $enable_accel             = delete $args{enable_accel};
    my $disable_routing          = delete $args{disable_routing};
    my $use_osm_de_map           = delete $args{use_osm_de_map};
    my $coords                   = delete $args{coords};
    my $wgs84_coords             = delete $args{wgs84_coords};
    my $route_title              = delete $args{route_title};
    my $show_expired_session_msg = delete $args{show_expired_session_msg};
    my $geojson_file             = delete $args{geojson_file};
    my $geojsonp_url             = delete $args{geojsonp_url};
    my $replay_trk               = delete $args{replay_trk};
    my $loc                      = delete $args{loc};
    my $show_feature_list        = delete $args{show_feature_list};
    my $show_speedometer	 = delete $args{show_speedometer};
    my $root_url                 = delete $args{root_url};
    my $shortcut_icon            = delete $args{shortcut_icon};
    my $title_html               = delete $args{title_html};

    die 'Unhandled arguments: ' . join(', ', keys %args) if %args;

    if ($enable_accel && !$enable_upload) { # no sense to enable accelerometer without upload functionality
	$enable_upload = 1;
    }

    bless {
	   htmldir                  => $htmldir,
	   use_old_url_layout       => $use_old_url_layout,
	   cgi_config               => $cgi_config,
	   leaflet_ver              => $leaflet_ver,
	   enable_upload            => $enable_upload,
	   enable_accel             => $enable_accel,
	   disable_routing          => $disable_routing,
	   use_osm_de_map           => $use_osm_de_map,
	   coords                   => $coords,
	   wgs84_coords             => $wgs84_coords,
	   route_title              => $route_title,
	   show_expired_session_msg => $show_expired_session_msg,
	   geojson_file             => $geojson_file,
	   geojsonp_url             => $geojsonp_url,
	   replay_trk               => $replay_trk,
	   loc                      => $loc,
	   show_feature_list        => $show_feature_list,
	   show_speedometer         => $show_speedometer,
	   root_url                 => $root_url,
	   shortcut_icon            => $shortcut_icon,
	   title_html               => $title_html,
	  }, $class;
}

sub process {
    my($self, $ofh) = @_;

    my $htmlfile                 = $self->{htmldir} . '/bbbikeleaflet.html';
    my $enable_upload            = $self->{enable_upload};
    my $enable_accel             = $self->{enable_accel};
    my $disable_routing          = $self->{disable_routing};
    my $leaflet_ver              = $self->{leaflet_ver};
    my $use_osm_de_map           = $self->{use_osm_de_map};
    my $cgi_config               = $self->{cgi_config};
    my $coords                   = $self->{coords};
    my $wgs84_coords             = $self->{wgs84_coords};
    my $route_title              = $self->{route_title};
    my $show_expired_session_msg = $self->{show_expired_session_msg};
    my $geojson_file             = $self->{geojson_file};
    my $geojsonp_url             = $self->{geojsonp_url};
    my $replay_trk               = $self->{replay_trk};
    my $loc                      = $self->{loc};
    my $show_feature_list        = $self->{show_feature_list};
    my $show_speedometer         = $self->{show_speedometer};
    my $root_url                 = $self->{root_url};
    my $shortcut_icon            = $self->{shortcut_icon};
    my $title_html               = $self->{title_html};

    my($bbbike_htmlurl, $bbbike_imagesurl);
    if ($cgi_config) {
	$bbbike_htmlurl   = $cgi_config->{bbbike_html};
	$bbbike_imagesurl = $cgi_config->{bbbike_images};
    } else {
	my $use_old_url_layout = $self->{use_old_url_layout};
	if ($use_old_url_layout) {
	    $bbbike_htmlurl   = "/bbbike/html";
	    $bbbike_imagesurl = "/bbbike/images";
	} else {
	    $bbbike_htmlurl   = "/BBBike/html";
	    $bbbike_imagesurl = "/BBBike/images";
	}
    }
    if (defined $root_url) {
	for ($bbbike_htmlurl, $bbbike_imagesurl) {
	    $_ = "$root_url$_";
	}
    }

    open my $fh, '<:utf8', $htmlfile
	or die "Can't open $htmlfile: $!";
    binmode $ofh, ':utf8';

    my $state_upload;
    while(<$fh>) {
	if (m{\Q<!-- IF UPLOAD ENABLED -->}) {
	    $state_upload = 'enabled';
	    next;
	} elsif (m{\Q<!-- IF UPLOAD DISABLED -->}) {
	    $state_upload = 'disabled';
	    next;
	} elsif (m{\Q<!-- END UPLOAD -->}) {
	    undef $state_upload;
	    next;
	}

	if ($state_upload) {
	    if ($state_upload eq 'enabled' && !$enable_upload) {
		next;
	    } elsif ($state_upload eq 'disabled' && $enable_upload) {
		next;
	    }
	}

	if (m{(.*)\Q<!-- FIX URL LAYOUT -->\E}) {
	    my $line = $1;
	    if ($line !~ s{(src=")}{$1$bbbike_htmlurl/}) {
		$line =~ s{(href=")}{$1$bbbike_htmlurl/};
	    }
	    print $ofh $line, "\n";
	    next;
	}

	# has to be checked before FIX IMAGES URL LAYOUT
	if (defined $shortcut_icon && m{<link rel="shortcut icon" href="([^"]+)"}) {
	    # note: type is hardcoded here, and there's no protection
	    # from strange URLs
	    print $ofh qq{ <link rel="shortcut icon" href="$shortcut_icon" type="image/png" />\n};
	    next;
	}

	if (m{(.*)\Q<!-- FIX IMAGES URL LAYOUT -->\E}) {
	    my $line = $1;
	    if ($line !~ s{(src=")}{$1$bbbike_imagesurl/}) {
		$line =~ s{(href=")}{$1$bbbike_imagesurl/};
	    }
	    print $ofh $line, "\n";
	    next;
	}

	if ($leaflet_ver && m{<(?:link|script ).*(?:/leaflet[-/]\d+\.\d+\.\d+/)}) {
	    s{/leaflet([-/])\d+\.\d+\.\d+/}{/leaflet$1$leaflet_ver/};
	}

	if (defined $title_html && m{<title>.*?</title>}) {
	    s{(<title>).*?(</title>)}{$1$title_html$2};
	}

	if (m{\Q<!-- INSERT JSONP HERE -->}) {
	    if ($geojsonp_url) {
		print qq{<script>function geoJsonResponse(geoJson) { initialGeojson = geoJson }</script>\n};
		print qq{<script type="application/javascript" src="$geojsonp_url"></script>\n};
	    }
	    if ($replay_trk) {
		print qq{<script>function getReplayTrkJsonResponse(json) { replayTrkJson = json }</script>\n};
		print qq{<script type="application/javascript" src="$replay_trk"></script>\n};
	    }
	    next;
	}

	print $ofh $_;

	if (m{\Q//--- INSERT GEOJSON HERE ---}) {
	    if ($wgs84_coords || $coords) {
		if ($wgs84_coords || (ref $coords eq 'ARRAY' && @$coords > 1)) {
		    require Strassen::GeoJSON;
		    require Strassen::Core;
		    my $bbd = Strassen::GeoJSON->new;
		    my $name = defined $route_title ? $route_title : '';
		    if ($wgs84_coords) {
			$bbd->set_global_directive(map => 'polar');
			if (ref $wgs84_coords ne 'ARRAY') { $wgs84_coords = [ $wgs84_coords ] }
			for my $coord (@$wgs84_coords) {
			    $bbd->push([$name, [split /!/, $coord], 'X']);
			}
		    } else {
			for my $coord (@$coords) {
			    $bbd->push([$name, [split /!/, $coord], 'X']);
			}
		    }
		    print $ofh "initialGeojson =\n";
		    my $json_octets = $bbd->bbd2geojson;
		    binmode $ofh, ':raw'; # temporarily turn off utf8 layer --- we have octets, and want to dump them as octets
		    print $ofh $json_octets;
		    binmode $ofh, ':utf8';
		    print $ofh ";\n";
		} else {
		    # This seems to be faster than Strassen::GeoJSON +
		    # Strassen::Core, so use if for simple coordinate
		    # lists.
		    require BBBikeGeoJSON;
		    require Route;
		    ($coords) = @$coords if ref $coords eq 'ARRAY';
		    my $route = Route->new_from_cgi_string($coords);
		    my $json = BBBikeGeoJSON::route_to_geojson_json($route);
		    print $ofh "initialRouteGeojson = $json;\n";
		}
	    } elsif ($show_expired_session_msg) {
		# XXX English message?
		print $ofh qq{alert("Die Session ist abgelaufen, es wird die Karte ohne Route angezeigt.");\n};
	    } elsif ($geojson_file) {
		print $ofh "initialGeojson =\n";
		open my $geojson_fh, '<', $geojson_file
		    or die "Can't open $geojson_file: $!";
		local $/ = \4096;
		local $_;
		while(<$geojson_fh>) {
		    print $ofh $_;
		}
		print $ofh ";\n";
	    }
	}

	if (m{\Q//--- INSERT DEVEL CODE HERE ---}) {
	    print $ofh "enable_upload  = " . ($enable_upload  ? 'true' : 'false') . ";\n";
	    print $ofh "enable_accel   = " . ($enable_accel   ? 'true' : 'false') . ";\n";
	    print $ofh "use_osm_de_map = " . ($use_osm_de_map ? 'true' : 'false') . ";\n";
	    print $ofh "show_feature_list = " . ($show_feature_list ? 'true' : 'false') . ";\n";
	    print $ofh "show_speedometer = " . ($show_speedometer ? 'true' : 'false') . ";\n";
	    print $ofh "disable_routing = " . ($disable_routing ? 'true' : 'false') . ";\n";
	    print $ofh "activate_loc = " . ($loc ? 'true' : 'false') . ";\n";
	}
    }
}

sub as_string {
    my($self) = @_;
    my $out;
    open my $ofh, ">", \$out
	or die "Can't output to scalar fh: $!";
    $self->process($ofh);
    $out;
}

1;

__END__
