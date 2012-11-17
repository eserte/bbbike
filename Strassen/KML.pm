# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2007,2011 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Strassen::KML;

use strict;
use vars qw($VERSION $TEST_SET_NAMESPACE_DECL_URI_HACK);
$VERSION = 1.13;

use base qw(Strassen);

use XML::LibXML;
use Karte::Polar;
use Karte::Standard;
use Strassen::Util;
use BBBikeUtil qw(m2km);

sub new {
    my($class, $filename_or_object, %args) = @_;
    if (UNIVERSAL::isa($filename_or_object, "Strassen")) {
	bless $filename_or_object, $class;
    } else {
	my $self = {};
	bless $self, $class;

	if ($filename_or_object) {
	    if ($filename_or_object =~ m{\.kmz$}i) {
		$self->kmz2bbd($filename_or_object, %args);
	    } else {
		$self->kml2bbd($filename_or_object, %args);
	    }
	}

	$self;
    }
}

sub kml2bbd {
    my($self, $file, %args) = @_;
    my $p = XML::LibXML->new;
    my $doc = $p->parse_file($file);
    $self->_kmldoc2bbd($doc, %args);
}

sub _kmldoc2bbd {
    my($self, $doc, %args) = @_;
    my $converter;
    if ($args{'map'} && $args{'map'} eq 'bbbike') {
	$converter = \&longlat2xy;
    } else {
	$self->set_global_directive(map => 'polar');
    }
    my $root = $doc->documentElement;
    if ($root->can("setNamespaceDeclURI") && !$TEST_SET_NAMESPACE_DECL_URI_HACK) {
	$root->setNamespaceDeclURI(undef, undef);
    } else {
	# ugly hack, try it again, remove namespace first:
	my $xml = $doc->serialize;
	$xml =~ s{xmlns="[^"]+"}{}g;
	my $p = XML::LibXML->new;
	$doc = $p->parse_string($xml);
	$root = $doc->documentElement;
    }
    for my $placemark_node ($root->findnodes('/kml//Placemark')) {
	my $name = $placemark_node->findvalue('./name') || $args{name} || 'Route';
	my $cat  = $args{cat}  || 'X';
	my $coords = $placemark_node->findvalue('./LineString/coordinates');
	if (!$coords) {
	    $coords = $placemark_node->findvalue('./MultiGeometry/Polygon/outerBoundaryIs/LinearRing/coordinates');
	    if (!$coords) {
		$coords = $placemark_node->findvalue('./MultiGeometry/LineString/coordinates');
		if (!$coords) {
		    warn "kml2bbd: Cannot find coordinates in Placemark";
		    next;
		}
	    }
	    ## XXX yes? no?
	    #$cat = "F:$cat";
	}
	my @c = map {
	    if ($converter) {
		my($lon,$lat) = split /,/, $_;
		join(",", $converter->($lon,$lat));
	    } else {
		my($x,$y) = split /,/, $_; # throwing the elevation away, if any
		join(",", $x,$y);
	    }
	} grep { !/^\s+$/ } split ' ', $coords;
	if (@c) {
	    $self->push([$name, [@c], $cat]);
	}
    }
}

sub kmz2bbd {
    my($self, $file, %args) = @_;

    require Archive::Zip;

    my $zip = Archive::Zip->new;
    unless ($zip->read($file) == Archive::Zip::AZ_OK()) {
	die "Can't read kmz file <$file>";
    }
    my $docMember;
    for my $m ($zip->members) {
	if ($m->fileName =~ m{\.kml$}i) {
	    if ($docMember) {
		warn "Multiple .kml files in .kmz found, using only the first one!";
	    } else {
		$docMember = $m;
	    }
	}
    }
    if (!$docMember) {
	die "Can't find any file <*.kml> in <$file>, zip only contains " . join(", ", $zip->memberNames);
    }
    my($contents, $status) = $docMember->contents;
    if ($status != Archive::Zip::AZ_OK()) {
	die "Error while getting doc.kml contents";
    }
    my $p = XML::LibXML->new;
    my $doc = $p->parse_string($contents);
    $self->_kmldoc2bbd($doc, %args);
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

sub xml {
    my $s = shift;
    $s =~ s{([<>&"])}{"&#".ord($1).";"}ge;
    $s =~ s{([\x80-\x{ffff}])}{"&#".ord($1).";"}ge;
    $s;
}

sub bbd2kml {
    my($self, %args) = @_;
    my $document_name = delete $args{documentname} || 'BBBike-Route';
    my $document_description = delete $args{documentdescription} || "";
    my $with_start_goal_icons = delete $args{startgoalicons};

    my $xy2longlat = \&xy2longlat;
    my $map = $self->get_global_directive("map");
    if ($map && $map eq 'polar') {
	$xy2longlat = \&longlat2longlat;
    }

    my @routes;
    my %colors;
    $self->init;
    while(1) {
	my $r = $self->next;
	my @c = @{ $r->[Strassen::COORDS] };
	last if !@c;

	my $color;
	if ($r->[Strassen::CAT] =~ m{^\#(......)$}) {
	    $color = lc($1) . "ff";
	} else {
	    $color = 'ff0000ff';
	}
	$colors{$color}++;

	my $dist = 0;
	for(my $i = 1; $i<=$#c; $i++) {
	    $dist += Strassen::Util::strecke_s($c[$i-1], $c[$i]);
	}

	push @routes, { name => $r->[Strassen::NAME],
			coords => join("\n", map {
			    join(",", $xy2longlat->($_))
			} @c),
			color => $color,
			dist => $dist,
		      };
    }
    my $kml_tmpl = <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://earth.google.com/kml/2.1">
  <Document>
    <name>@{[ xml($document_name) ]}</name>
    <description>@{[ xml($document_description) ]}</description>
EOF
    my %styles;
    my $style_id = 1;
    for my $color (keys %colors) {
	$styles{$color} = "style" . $style_id++;
	$kml_tmpl .= <<EOF;
    <Style id="@{[ xml($styles{$color}) ]}">
      <LineStyle>
        <color>@{[ $color ]}</color>
        <width>4</width>
      </LineStyle>
      <PolyStyle>
        <color>@{[ $color ]}</color>
      </PolyStyle>
    </Style>
EOF
    }
    if ($with_start_goal_icons) {
	$kml_tmpl .= <<EOF;
    <Style id="start">
      <IconStyle>
        <scale>2</scale>
        <Icon>
          <href>http://www.bbbike.de/BBBike/images/flag2_bl_centered.png</href>
        </Icon> 
      </IconStyle>
    </Style>
    <Style id="goal">
      <IconStyle>
        <scale>2</scale>
        <Icon>
          <href>http://www.bbbike.de/BBBike/images/flag_ziel_centered.png</href>
        </Icon> 
      </IconStyle>
    </Style>
EOF
    }
    my $is_first_route = 1;
    for my $route (@routes) {
	my($name, $coords, $color, $dist) = @{$route}{qw(name coords color dist)};
	my $dist_km = m2km($dist);
	my $style = $styles{$color};
	$kml_tmpl .= <<EOF;
    <Placemark>
      <name>@{[ xml($name) ]}</name>
      <description>@{[ xml($dist_km) ]}</description>
EOF
	if ($is_first_route) {
	    $is_first_route = 0;
	    if (!$with_start_goal_icons) {
		# Without the start/goal icons the route is centered
		# and not completely shown. In this case it's better
		# to specify a LookAt point. With the altitude=2000m a
		# good portion of the route is shown.
		my($lon,$lat) = $coords =~ m{^([^,]+),(\S+)};
		$kml_tmpl .= <<EOF;
      <!-- Center to start -->
      <LookAt>
        <longitude>$lon</longitude>
        <latitude>$lat</latitude>
        <range>2000</range>
      </LookAt>
EOF
	    }
	}
	$kml_tmpl .= <<EOF;
      <styleUrl>#@{[ xml($styles{$color}) ]}</styleUrl> 
      <LineString>
        <extrude>1</extrude>
        <tessellate>1</tessellate>
        <altitudeMode>clampToGround</altitudeMode>
        <coordinates> 
@{[ xml($coords) ]}
        </coordinates>
      </LineString>
    </Placemark>
EOF
    }
    if ($with_start_goal_icons && @routes) {
	my($startcoord) = $routes[0]->{coords}  =~ m{^(\S+)};
	my($goalcoord)  = $routes[-1]->{coords} =~ m{(\S+)$};
	$kml_tmpl .= <<EOF;
    <Placemark>
      <styleUrl>#start</styleUrl>
      <Point>
        <coordinates>$startcoord</coordinates>
      </Point>
    </Placemark>
    <Placemark>
      <styleUrl>#goal</styleUrl>
      <Point>
        <coordinates>$goalcoord</coordinates>
      </Point>
    </Placemark>
EOF
    }
    $kml_tmpl .= <<EOF;
  </Document>
</kml>
EOF
    $kml_tmpl;
}

1;

__END__

=head1 NAME

Strassen::KML - convert between bbd and kml files

=head1 SYNOPSIS

    use Strassen::KML;
    $kml_s = Strassen::KML->new($s);
    $kml = $kml_s->bbd2kml;

=head1 DESCRIPTION

Convert between BBBike's bbd format and Google's kml format.

=head2 Converting from bbd to kml

Call the constructor C<new> with a L<Strassen> object.

Then use the method C<bbd2kml> to create a KML string.

The C<bbd2kml> method takes the following optional named parameters:

=over

=item documentname => $name

The KML document name. Defaults to "BBBike-Route".

=item documentdescription => $description

The KML document description. No default.

=item startgoalicons => $bool

If true, then create references to start/goal icons for the
beginning/end of the route. The icon images are fetched from
L<http://www.bbbike.de>.

=back

=head2 Covnerting from kml/kmz to bbd

Call the constructor C<new> with a C<kml> or C<kmz> filename. After
this, the constructed object behaves like a L<Strassen> object.

The constructor takes the following optional named parameters:

=over

=item name => $name

Default route name if no name was found in the kml file. Defaults to
"Route".

=item cat => $cat

The route category. Defaults to "X".

=back

=head1 AUTHOR

Slaven Rezic

=cut
