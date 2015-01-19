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
    my $use_osm_de_map           = delete $args{use_osm_de_map};
    my $coords                   = delete $args{coords};
    my $show_expired_session_msg = delete $args{show_expired_session_msg};

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
	   use_osm_de_map           => $use_osm_de_map,
	   coords                   => $coords,
	   show_expired_session_msg => $show_expired_session_msg,
	  }, $class;
}

sub process {
    my($self, $ofh) = @_;

    my $htmlfile                 = $self->{htmldir} . '/bbbikeleaflet.html';
    my $enable_upload            = $self->{enable_upload};
    my $enable_accel             = $self->{enable_accel};
    my $leaflet_ver              = $self->{leaflet_ver};
    my $use_osm_de_map           = $self->{use_osm_de_map};
    my $coords                   = $self->{coords};
    my $show_expired_session_msg = $self->{show_expired_session_msg};

    my $use_old_url_layout = $self->{use_old_url_layout};
    my($bbbike_htmlurl, $bbbike_imagesurl);
    if ($use_old_url_layout) {
	$bbbike_htmlurl   = "/bbbike/html";
	$bbbike_imagesurl = "/bbbike/images";
    } else {
	$bbbike_htmlurl   = "/BBBike/html";
	$bbbike_imagesurl = "/BBBike/images";
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
	    }
	}

	if (m{\Q//--- INSERT DEVEL CODE HERE ---}) {
	    print $ofh "enable_upload  = " . ($enable_upload  ? 'true' : 'false') . ";\n";
	    print $ofh "enable_accel   = " . ($enable_accel   ? 'true' : 'false') . ";\n";
	    print $ofh "use_osm_de_map = " . ($use_osm_de_map ? 'true' : 'false') . ";\n";
	}
    }
}

1;

__END__
