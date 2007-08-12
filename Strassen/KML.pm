# -*- perl -*-

#
# $Id: KML.pm,v 1.6 2007/08/12 18:50:58 eserte Exp $
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
use vars qw($VERSION $TEST_SET_NAMESPACE_DECL_URI_HACK);
$VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

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
    my $coords = $root->findvalue('/kml//Placemark/LineString/coordinates'); # might be Document or Folder in between
    my @c = map {
	my($lon,$lat) = split /,/, $_;
	join(",", longlat2xy($lon,$lat));
    } grep { !/^\s+$/ } split ' ', $coords;

    my $name = $args{name} || "Route"; # XXX get from /kml//name?
    my $cat  = $args{cat}  || "X";
    $self->push([$name, [@c], $cat]) if @c;
}

sub kmz2bbd {
    my($self, $file, %args) = @_;

    require Archive::Zip;

    my $zip = Archive::Zip->new;
    unless ($zip->read($file) == Archive::Zip::AZ_OK()) {
	die "Can't read kmz file <$file>";
    }
    my $docMember = $zip->memberNamed('doc.kml');
    if (!$docMember) {
	die "Can't find expected file <doc.kml> in <$file>";
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
