# -*- perl -*-

#
# $Id: KML.pm,v 1.4 2007/07/20 23:10:32 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2007 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Strassen::KML;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

use base qw(Strassen);

use XML::LibXML;
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
	    $self->kml2bbd($filename_or_object, %args);
	}

	$self;
    }
}

sub kml2bbd {
    my($self, $file, %args) = @_;

    my $p = XML::LibXML->new;
    my $doc = $p->parse_file($file);
    my $root = $doc->documentElement;
    $root->setNamespaceDeclURI(undef, undef);
    my $coords = $root->findvalue('/kml//Placemark/LineString/coordinates'); # might be Document or Folder in between
    my @c = map {
	my($lon,$lat) = split /,/, $_;
	join(",", longlat2xy($lon,$lat));
    } grep { !/^\s+$/ } split ' ', $coords;

    my $name = $args{name} || "Route"; # XXX get from /kml//name?
    my $cat  = $args{cat}  || "X";
    $self->push([$name, [@c], $cat]) if @c;
}

sub longlat2xy {
    my($lon,$lat) = @_;
    my($x, $y) = $Karte::Standard::obj->trim_accuracy($Karte::Polar::obj->map2standard($lon, $lat));
    ($x, $y);
}

sub xy2longlat {
    my($c) = @_;
    my($lon, $lat) = $Karte::Polar::obj->trim_accuracy($Karte::Polar::obj->standard2map(split /,/, $c));
    ($lon, $lat);
}

sub xml { shift } # XXX impl missing!

sub bbd2kml {
    my($self, %args) = @_;
    my @coords;
    my $title;
    $self->init;
    while(1) {
	my $r = $self->next;
	last if !@{ $r->[Strassen::COORDS] };
	$title = $r->[Strassen::NAME] if !defined $title; # XXX better heuristic? use %args?
	push @coords, map {
	    join(",", xy2longlat($_))
	} @{ $r->[Strassen::COORDS] };
    }
    my $coords = join("\n", @coords);
    my $kml_tmpl = <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://earth.google.com/kml/2.1">
  <Document>
    <name>Paths</name>
    <description>@{[ xml($title) ]}</description>
    <Style id="yellowLineGreenPoly">
      <LineStyle>
        <color>ff0000ff</color>
        <width>4</width>
      </LineStyle>
      <PolyStyle>
        <color>ff0000ff</color>
      </PolyStyle>
    </Style>
    <Placemark>
      <name>Tour</name>
      <description>enable/disable</description>
      <styleUrl>#yellowLineGreenPoly</styleUrl> 
      <LineString>
        <extrude>1</extrude>
        <tessellate>1</tessellate>
        <altitudeMode>absolute</altitudeMode>
        <coordinates> 
@{[ xml($coords) ]}
        </coordinates>
      </LineString>
    </Placemark>
  </Document>
</kml>
EOF
    
}

1;

__END__
