# -*- perl -*-

#
# $Id: GPX.pm,v 1.1 2005/07/17 20:39:22 eserte Exp eserte $
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

sub xy2longlat {
    my($c) = @_;
    my($lon, $lat) = $Karte::Polar::obj->trim_accuracy($Karte::Polar::obj->standard2map(split /,/, $c));
    ($lon, $lat);
}

sub bbd2gpx {
    my($self) = @_;
    require XML::LibXML;
    $self->init;
    my @wpt;
    my @trkseg;
    while(1) {
	my $r = $self->next;
	last if !@{ $r->[Strassen::COORDS] };
	if (@{ $r->[Strassen::COORDS] } == 1) {
	    push @wpt, { name => $r->[Strassen::NAME],
			 coords => [ xy2longlat($r->[Strassen::COORDS][0]) ],
		       };
	} else {
	    push @trkseg,
		{
		 name => $r->[Strassen::NAME],
		 coords => [ map { [ xy2longlat($_) ] } @{ $r->[Strassen::COORDS] } ],
		};
	}
    }
    my $dom = XML::LibXML::Document->new('1.0', 'UTF8');
    my $gpx = $dom->createElement("gpx");
    $dom->setDocumentElement($gpx);
    $gpx->setAttribute("version", "1.1");
    $gpx->setAttribute("create", "http://www.bbbike.de");
    for my $wpt (@wpt) {
	my $wptxml = $gpx->addNewChild(undef, "wpt");
	$wptxml->setAttribute("lat", $wpt->{coords}[1]);
	$wptxml->setAttribute("lon", $wpt->{coords}[0]);
	my $namexml = $wptxml->addNewChild(undef, "name");
	$namexml->appendText($wpt->{name});
    }
    if (@trkseg) {
	my $trkxml = $gpx->addNewChild(undef, "trk");
	my $name_from = $trkseg[0]->{name};
	my $name_to   = $trkseg[-1]->{name};
	my $name = $name_from;
	if ($name_from ne $name_to) {
	    $name .= " - $name_to";
	}
	my $namexml = $trkxml->addNewChild(undef, "name");
	$namexml->appendText($name);
	for my $trkseg (@trkseg) {
	    my $trksegxml = $trkxml->addNewChild(undef, "trkseg");
	    for my $wpt (@{ $trkseg->{coords} }) {
                my $trkptxml = $trksegxml->addNewChild(undef, "trkpt");
                $trkptxml->setAttribute("lat", $wpt->[1]);
                $trkptxml->setAttribute("lon", $wpt->[0]);
            }
	}
    }
    $dom->toString;
}

1;

__END__
