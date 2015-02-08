# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2015 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeLeaflet::Template;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

sub new {
    my($class, %args) = @_;

    my $htmldir = delete $args{htmldir} || do {
	require BBBikeUtil;
	BBBikeUtil::bbbike_root() . '/html';
    };
    my $use_old_url_layout       = delete $args{use_old_url_layout};
    my $leaflet_ver              = delete $args{leaflet_ver};
    my $enable_upload            = delete $args{enable_upload};
    my $enable_accel             = delete $args{enable_accel};
    my $disable_routing          = delete $args{disable_routing};
    my $use_osm_de_map           = delete $args{use_osm_de_map};
    my $coords                   = delete $args{coords};
    my $show_expired_session_msg = delete $args{show_expired_session_msg};
    my $geojson_file             = delete $args{geojson_file};
    my $geojsonp_url             = delete $args{geojsonp_url};
    my $show_feature_list        = delete $args{show_feature_list};
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
	   leaflet_ver              => $leaflet_ver,
	   enable_upload            => $enable_upload,
	   enable_accel             => $enable_accel,
	   disable_routing          => $disable_routing,
	   use_osm_de_map           => $use_osm_de_map,
	   coords                   => $coords,
	   show_expired_session_msg => $show_expired_session_msg,
	   geojson_file             => $geojson_file,
	   geojsonp_url             => $geojsonp_url,
	   show_feature_list        => $show_feature_list,
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
    my $coords                   = $self->{coords};
    my $show_expired_session_msg = $self->{show_expired_session_msg};
    my $geojson_file             = $self->{geojson_file};
    my $geojsonp_url             = $self->{geojsonp_url};
    my $show_feature_list        = $self->{show_feature_list};
    my $root_url                 = $self->{root_url};
    my $shortcut_icon            = $self->{shortcut_icon};
    my $title_html               = $self->{title_html};

    my $use_old_url_layout = $self->{use_old_url_layout};
    my($bbbike_htmlurl, $bbbike_imagesurl);
    if ($use_old_url_layout) {
	$bbbike_htmlurl   = "/bbbike/html";
	$bbbike_imagesurl = "/bbbike/images";
    } else {
	$bbbike_htmlurl   = "/BBBike/html";
	$bbbike_imagesurl = "/BBBike/images";
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

	if ($leaflet_ver && m{<(?:link|script ).*(?:/leaflet-\d+\.\d+\.\d+/)}) {
	    s{/leaflet-\d+\.\d+\.\d+/}{/leaflet-$leaflet_ver/};
	}

	if (defined $title_html && m{<title>.*?</title>}) {
	    s{(<title>).*?(</title>)}{$1$title_html$2};
	}

	if (m{\Q<!-- INSERT JSONP HERE -->}) {
	    if ($geojsonp_url) {
		print qq{<script>function geoJsonResponse(geoJson) { initialGeojson = geoJson }</script>\n};
		print qq{<script type="application/javascript" src="$geojsonp_url"></script>\n};
	    }
	    next;
	}

	print $ofh $_;

	if (m{\Q//--- INSERT GEOJSON HERE ---}) {
	    if ($coords) {
		require BBBikeGeoJSON;
		require Route;
		my $route = Route->new_from_cgi_string(join("!", $coords));
		my $json = BBBikeGeoJSON::route_to_geojson_json($route);
		print $ofh "initialRouteGeojson = $json;\n";
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
	    print $ofh "disable_routing = " . ($disable_routing ? 'true' : 'false') . ";\n";
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
