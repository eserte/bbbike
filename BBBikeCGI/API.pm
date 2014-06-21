# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2009,2013,2014 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Hmmm... XXXX

package BBBikeCGI::API;

use strict;
use vars qw($VERSION);
$VERSION = '0.02';

use JSON::XS qw();

require Karte::Polar;
require Karte::Standard;

sub action {
    my($action, $q) = @_;
    if ($action !~ m{^(revgeocode|config)$}) {
	die "Invalid action $action";
    }
    my $func = "action_$action";
    no strict 'refs';
    &{$func}($q);
}

sub action_revgeocode {
    my $q = shift;
    my($lon) = $q->param('lon');
    $lon eq '' and die "lon is missing";
    my($lat) = $q->param('lat');
    $lat eq '' and die "lat is missing";

    no warnings 'once';
    my($x,$y) = $main::data_is_wgs84 ? ($lon,$lat) : $Karte::Polar::obj->map2standard($lon,$lat);
    # XXX Die Verwendung von main::... bricht, wenn bbbike.cgi als
    # Apache::Registry-Skript ausgeführt wird, da das Package dann ein
    # anderes ist! -> beste Lösung: alle Funktionen von bbbike.cgi
    # müssen in ein Package überführt werden
    my $xy = main::get_nearest_crossing_coords($x,$y);
    my $cr;
    if (defined $xy) {
	my @cr = split m{/}, main::crossing_text($xy);
	@cr = @cr[0,1] if @cr > 2; # bbbike.cgi can deal only with A/B
	$cr = join("/", @cr);
    }
    print $q->header(-type => 'text/plain', -access_control_allow_origin => '*');
    print JSON::XS->new->ascii->encode({ crossing => $cr,
					 bbbikepos => $xy,
					 origlon => $lon,
					 origlat => $lat,
				       });
}

sub action_config {
    my $q = shift;
    print $q->header(-type => 'text/plain');
    no warnings 'once';
    my $json_bool = sub { $_[0] ? JSON::XS::true : JSON::XS::false };
    print JSON::XS->new->ascii->encode
	(
	 {
	  use_apache_session         => $json_bool->($main::use_apache_session),
	  apache_session_module      => $main::apache_session_module,
	  detailmap_module           => $main::detailmap_module,
	  graphic_format             => $main::graphic_format,
	  can_gif                    => $json_bool->($main::can_gif),
	  can_jpeg                   => $json_bool->(!$main::cannot_jpeg),
	  can_pdf                    => $json_bool->(!$main::cannot_pdf),
	  bbbikedraw_pdf_module      => $main::bbbikedraw_pdf_module,
	  can_svg                    => $json_bool->(!$main::cannot_svg),
	  can_wbmp                   => $json_bool->($main::can_wbmp),
	  can_palmdoc                => $json_bool->($main::can_palmdoc),
	  can_gpx                    => $json_bool->($main::can_gpx),
	  can_kml                    => $json_bool->($main::can_kml),
	  can_mapserver              => $json_bool->($main::can_mapserver),
	  can_gpsies_link            => $json_bool->($main::can_gpsies_link),
	  show_start_ziel_url        => $json_bool->($main::show_start_ziel_url),
	  show_weather               => $json_bool->($main::show_weather),
	  use_select                 => $json_bool->($main::use_select),
	  use_berlinmap              => $json_bool->(!$main::no_berlinmap),
	  use_background_image       => $json_bool->($main::use_background_image),
	  with_comments              => $json_bool->($main::with_comments),
	  with_cat_display           => $json_bool->($main::with_cat_display),
	  use_coord_link             => $json_bool->($main::use_coord_link),
	  city                       => $main::city,
	  use_fragezeichen           => $json_bool->($main::use_fragezeichen),
	  use_fragezeichen_routelist => $json_bool->($main::use_fragezeichen_routelist),
	  search_algorithm           => $main::search_algorithm,
	  use_exact_streetchooser    => $json_bool->($main::use_exact_streetchooser),
	  use_utf8                   => $json_bool->($main::use_utf8),
	  data_is_wgs84              => $json_bool->($main::data_is_wgs84),
	  osm_data                   => $json_bool->($main::osm_data),
	 }
	);
}

1;

__END__
