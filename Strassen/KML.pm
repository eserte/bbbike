# -*- perl -*-

#
# $Id: KML.pm,v 1.10 2008/05/12 16:04:23 eserte Exp $
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
$VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

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
    my $xy2longlat = \&xy2longlat;
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
    my $docMember;
    for my $m ($zip->members) {
	if ($m->fileName =~ m{\.kml$}) {
	    if ($docMember) {
		warn "Multiple .kml files in .kmz found, using only the first one!";
	    } else {
		$docMember = $m;
	    }
	}
    }
    if (!$docMember) {
	die "Can't find any file <*.kml> in <$file>";
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
    for my $route (@routes) {
	my($name, $coords, $color, $dist) = @{$route}{qw(name coords color dist)};
	my $dist_km = m2km($dist);
	my $style = $styles{$color};
	$kml_tmpl .= <<EOF;
    <Placemark>
      <name>@{[ xml($name) ]}</name>
      <description>@{[ xml($dist_km) ]}</description>
      <styleUrl>#@{[ xml($styles{$color}) ]}</styleUrl> 
      <LineString>
        <extrude>1</extrude>
        <tessellate>1</tessellate>
        <altitudeMode>absolute</altitudeMode>
        <coordinates> 
@{[ xml($coords) ]}
        </coordinates>
      </LineString>
    </Placemark>
EOF
    }
    $kml_tmpl .= <<EOF;
  </Document>
</kml>
EOF
    
}

1;

__END__
