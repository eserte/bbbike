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
    my($res) = @_;
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
	},
#       },
     };
}

sub bbbikecgires_to_geojson_json {
    my($res) = @_;
    require JSON::XS;
    JSON::XS->new->utf8->encode(bbbikecgires_to_geojson_object($res));
}

sub route_to_geojson_object {
    my($route) = @_;
    require Karte::Polar;
    require Karte::Standard;
    bbbikecgires_to_geojson_object({LongLatPath => [map {
	my($x,$y) = $Karte::Polar::obj->standard2map(@$_);
	"$x,$y";
    } @{ $route->path }]});
}

sub route_to_geojson_json {
    my($route) = @_;
    require JSON::XS;
    JSON::XS->new->utf8->encode(route_to_geojson_object($route));
}

1;

__END__
