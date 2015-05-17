# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2012 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeGeoJSON;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

sub bbbikecgires_to_geojson_object {
    my($res, %args) = @_;
    my $do_short_result = delete $args{short};
    die "Unhandled arguments: " . join(" ", %args) if %args;

    my $result = $do_short_result ? undef : { map { ($_ => $res->{$_}) } qw(Route Trafficlights AffectingBlockings Speed Len Power) };

#XXX FeatureCollection does not seem to work with Leaflet?
#    +{ type => 'FeatureCollection',
#       'features' =>
       {type => 'Feature',
	geometry =>
	{type => 'LineString',
	 coordinates => [map { [ map { 0+$_ } split /,/, $_ ] } @{ $res->{LongLatPath} } ],
	},
	properties =>
	{
	 type => 'Route',
	 ($do_short_result ? () : (result => $result)),
	},
#       },
     };
}

sub bbbikecgires_to_geojson_json {
    my($res, %args) = @_;
    require JSON::XS;
    JSON::XS->new->utf8->canonical(1)->encode(bbbikecgires_to_geojson_object($res, %args));
}

sub route_to_geojson_object {
    my($route) = @_;
    require Karte::Polar;
    require Karte::Standard;
    bbbikecgires_to_geojson_object({LongLatPath => [map {
	my($x,$y) = $Karte::Polar::obj->standard2map(@$_);
	"$x,$y";
    } @{ $route->path }]}, short => 1); # no additional information available, so always short
}

sub route_to_geojson_json {
    my($route) = @_;
    require JSON::XS;
    JSON::XS->new->utf8->canonical(1)->encode(route_to_geojson_object($route));
}

# Cease warnings
if (0) {
    $Karte::Polar::obj = $Karte::Polar::obj;
}

1;

__END__
