# -*- perl -*-

#
# $Id: KML.pm,v 1.1 2007/06/19 20:37:26 eserte Exp $
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
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

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
	    $self->kml2bbd($filename_or_object);
	}

	$self;
    }
}

sub kml2bbd {
    my($self, $file) = @_;

    my $p = XML::LibXML->new;
    my $doc = $p->parse_file($file);
    my $root = $doc->documentElement;
    $root->setNamespaceDeclURI(undef, undef);
    my $coords = $root->findvalue('/kml/Document/Placemark/LineString/coordinates');
    my @c = map {
	my($lon,$lat) = split /,/, $_;
	join(",", longlat2xy($lon,$lat));
    } grep { !/^\s+$/ } split ' ', $coords;
    $self->push(["Route", [@c], "X"]);
}

sub longlat2xy {
    my($lon,$lat) = @_;
    my($x, $y) = $Karte::Standard::obj->trim_accuracy($Karte::Polar::obj->map2standard($lon, $lat));
    ($x, $y);
}

1;

__END__
