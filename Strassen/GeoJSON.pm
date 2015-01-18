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

package Strassen::GeoJSON;

use strict;
use vars qw($VERSION);
$VERSION = '0.02';

use base qw(Strassen);

use JSON::XS ();
use Karte::Polar;
use Karte::Standard;

sub new {
    my($class, $filename_or_object, %args) = @_;
    if (UNIVERSAL::isa($filename_or_object, "Strassen")) {
	bless $filename_or_object, $class;
    } else {
	my $self = {};
	bless $self, $class;

	if ($filename_or_object) {
	    $self->geojson2bbd($filename_or_object, %args);
	}

	$self;
    }
}

sub geojson2bbd {
    my($self, $file, %args) = @_;
    my $geojson_string = do {
	open my $fh, '<', $file
	    or die "Can't open $file: $!";
	local $/;
	<$fh>;
    };
    $self->geojsonstring2bbd($geojson_string, %args);
}

sub geojsonstring2bbd {
    my($self, $string, %args) = @_;

    my $converter;
    if ($args{'map'} && $args{'map'} eq 'bbbike') {
	$converter = \&longlat2xy;
    } else {
	$self->set_global_directive(map => 'polar');
    }
    my $namecb = $args{'namecb'} || sub {
	my $feature = shift;
	my $name = $feature->{properties}->{name};
	$name = '' if !defined $name;
	$name;
    };
    my $catcb = $args{'catcb'} || sub {
	my $feature = shift;
	my $cat = $feature->{properties}->{cat};
	$cat = 'X' if !defined $cat;
	$cat;
    };

    my $data = JSON::XS->new->decode($string);

    my $handle_geometry; $handle_geometry = sub {
	my($geometry, $name, $cat) = @_;
	my $type = $geometry->{type};
	if ($type eq 'GeometryCollection') {
	    for my $inner_geometry (@{ $geometry->{geometries} }) {
		$handle_geometry->($inner_geometry, $name, $cat);
	    }
	} else {
	    my $coordinates = $geometry->{coordinates};
	    if ($type eq 'Point') {
		if ($converter) { @$coordinates = $converter->(@$coordinates) }
		$self->push([$name, [join ',', @$coordinates], $cat]);
	    } elsif ($type eq 'LineString') {
		if ($converter) { for (@$coordinates) { @$_ = $converter->(@$_) } }
		$self->push([$name, [map { join ',',  @$_ } @$coordinates], $cat]);
	    } elsif ($type eq 'Polygon') {
		# XXX bbd has no support for interior rings/holes
		for my $inner_coordinates (@$coordinates) {
		    if ($converter) { for (@$inner_coordinates) { @$_ = $converter->(@$_) } }
		    $self->push([$name, [map { join ',',  @$_ } @$inner_coordinates], 'F:'.$cat]);
		}
	    } elsif ($type eq 'MultiPoint') {
		for my $inner_coordinates (@$coordinates) {
		    if ($converter) { for (@$inner_coordinates) { @$_ = $converter->(@$_) } }
		    $self->push([$name, [join ',', @$inner_coordinates], $cat]);
		}
	    } elsif ($type eq 'MultiLineString') {
		for my $inner_coordinates (@$coordinates) {
		    if ($converter) { for (@$inner_coordinates) { @$_ = $converter->(@$_) } }
		    $self->push([$name, [map { join ',',  @$_ } @$inner_coordinates], $cat]);
		}
	    } elsif ($type eq 'MultiPolygon') {
		for my $inner_coordinates (@$coordinates) {
		    # XXX bbd has no support for interior rings/holes
		    for my $inner_coordinates2 (@$inner_coordinates) {
			if ($converter) { for (@$inner_coordinates2) { @$_ = $converter->(@$_) } }
			$self->push([$name, [map { join ',',  @$_ } @$inner_coordinates2], 'F:'.$cat]);
		    }
		}
	    } else {
		warn "GeoJSON geometry type '$type' not supported, skipping feature...\n";
	    }
	}
    };
    my $handle_feature = sub {
	my $feature = shift;
	my $geometry = $feature->{geometry};
	if (!$geometry) {
	    die "Expected geometry object in feature";
	}
	my $name = $namecb->($feature);
	my $cat = $catcb->($feature);
	$handle_geometry->($geometry, $name, $cat);
    };

    if ($data->{type} eq 'FeatureCollection') {
	for my $feature (@{ $data->{features} || [] }) {
	    if ($feature->{type} eq 'Feature') {
		$handle_feature->($feature);
	    } else {
		die "Expected type=Feature in FeatureCollection";
	    }
	}
    } elsif ($data->{type} eq 'Feature') {
	$handle_feature->($data);
    } else {
	die "Expected type=FeatureCollection or type=Feature in GeoJSON data";
    }
}

sub bbd2geojson {
    my($self, %args) = @_;

    my $pretty = exists $args{pretty} ? $args{pretty} : 1;
    my $utf8   = exists $args{utf8}   ? $args{utf8}   : 1;
    my $bbbgeojsonp = $args{bbbgeojsonp};

    my $xy2longlat = \&xy2longlat;
    my $map = $self->get_global_directive("map");
    if ($map && $map eq 'polar') {
	$xy2longlat = \&longlat2longlat;
    }

    my @features;

    $self->init;
    while(1) {
	my $r = $self->next;
	my @c = @{ $r->[Strassen::COORDS] };
	last if !@c;

	my $name = $r->[Strassen::NAME];
	my $cat = $r->[Strassen::CAT];

	my $geometry = (@c > 1
			? ($cat =~ m{^F:}
			   ? { type => 'Polygon', coordinates => [[map { [$xy2longlat->($_)] } (@c, $c[0] ne $c[-1] ? $c[-1] : ()) ]] }
			   : { type => 'LineString', coordinates => [map { [$xy2longlat->($_)] } @c ] }
			  )
			: { type => 'Point',      coordinates => [$xy2longlat->($c[0])] }
		       );

	my $feature = {
		       type => 'Feature',
		       geometry => $geometry,
		       properties => {
				      name => $name,
				      cat => $cat,
				     }
		      };
	push @features, $feature;
    }

    my $to_serialize;
    if (@features == 1) {
	$to_serialize = $features[0];
    } else {
	$to_serialize = {
			 type => 'FeatureCollection',
			 features => \@features,
			};
    }
    my $json_xs = JSON::XS->new->pretty($pretty)->canonical(1);
    if ($utf8) {
	$json_xs->utf8(1);
    } else {
	$json_xs->ascii(1);
    }
    if ($bbbgeojsonp) {
	'geoJsonResponse(' . $json_xs->encode($to_serialize) . ');';
    } else {
	$json_xs->encode($to_serialize);
    }
}

sub longlat2xy {
    my($lon,$lat) = @_;
    my($x, $y) = $Karte::Standard::obj->trim_accuracy($Karte::Polar::obj->map2standard($lon, $lat));
    ($x, $y);
}

sub longlat2longlat {
    my($c) = @_;
    my($lon, $lat) = split /,/, $c;
    ($lon, $lat);
}

sub xy2longlat {
    my($c) = @_;
    my($lon, $lat) = $Karte::Polar::obj->trim_accuracy($Karte::Polar::obj->standard2map(split /,/, $c));
    ($lon, $lat);
}

1;

__END__

=head2 JSONP support

The GeoJSON result of the C<bbd2geojson()> call can be made into a
JSONP-like result by specifying C<< bbbgeojsonp => 1 >>. This creates
a resulting json string which is wrapped in a C<geoJsonResponse()>
function call. To use this, create a javascript function like

    function geoJsonResponse(geoJson) { initialGeoJSON = geoJson; }

=cut
