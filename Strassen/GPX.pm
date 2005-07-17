# -*- perl -*-

#
# $Id: GPX.pm,v 1.1 2005/07/17 20:39:22 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2005 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Strassen::GPX;

use strict;
use vars qw($VERSION @ISA);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

require Strassen::Core;

use XML::LibXML;

use Karte::Polar;
use Karte::Standard;

@ISA = 'Strassen';

sub new {
    my($class, $filename, %args) = @_;
    my $self = {};
    bless $self, $class;

    if ($filename) {
	$self->gpx2bbd($filename);
    }

    $self;
}

sub gpx2bbd {
    my($self, $file) = @_;
    
    my $p = XML::LibXML->new;
    my $doc = $p->parse_file($file);
    my $root = $doc->documentElement;

    for my $wpt ($root->childNodes) {
	next if $wpt->nodeName ne "wpt";
	my($x, $y) = latlong2xy($wpt);
	my $name = "";
	for my $name_node ($wpt->childNodes) {
	    next if $name_node->nodeName ne "name";
	    $name = $name_node->textContent;
	    last;
	}
	$self->push([$name, ["$x,$y"], "X"]);
    }

    for my $trk ($root->childNodes) {
	next if $trk->nodeName ne "trk";
	my $name;
	for my $trk_child ($trk->childNodes) {
	    if ($trk_child->nodeName eq 'name') {
		$name = $trk_child->textContent;
	    } elsif ($trk_child->nodeName eq 'trkseg') {
		my @c;
		for my $trkpt ($trk_child->childNodes) {
		    next if $trkpt->nodeName ne 'trkpt';
		    my($x, $y) = latlong2xy($trkpt);
		    #my $ele = $wpt->findvalue(q{./ele});
		    #my $time = $wpt->findvalue(q{./time});
		    push @c, "$x,$y";
		}
		$self->push([$name, [@c], "X"]);
	    }
	}
    }
}

sub latlong2xy {
    my($node) = @_;
    my $lat = $node->findvalue(q{./@lat});
    my $lon = $node->findvalue(q{./@lon});
    my($x, $y) = $Karte::Standard::obj->trim_accuracy($Karte::Polar::obj->map2standard($lon, $lat));
    ($x, $y);
}

1;

__END__
