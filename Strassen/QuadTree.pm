# -*- perl -*-

#
# $Id: QuadTree.pm,v 1.2 2005/03/28 22:49:27 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Strassen::QuadTree;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

use Algorithm::QuadTree;
use Strassen::Core;

package Strassen;

sub create_quadtree {
    my($s, %args) = @_;
    my $depth = $args{Depth} || 8;

    my $cachefile = "qt_${depth}_" . $s->id;
    if ($args{UseCache}) {
	require Strassen::Util;
	my $hashref = Strassen::Util::get_from_cache($cachefile, [$s->dependent_files]);
	if (defined $hashref) {
	    warn "Using quadtree cache for $cachefile\n" if $Strassen::VERBOSE;
	    $s->{QuadTree} = $hashref;
	    return $s->{QuadTree};
	}
    }

    my(@bbox) = $s->bbox;
    my $qt = Algorithm::QuadTree->new(-xmin => $bbox[0],
				      -ymin => $bbox[1],
				      -xmax => $bbox[2],
				      -ymax => $bbox[3],
				      -depth => $depth,
				     );

    my $bboxes = $s->bboxes;
    for my $id (0 .. $#$bboxes) {
	$qt->add($id, @{ $bboxes->[$id] });
    }
    $s->{QuadTree} = $qt;

    if ($args{UseCache}) {
	require Strassen::Util;
	if (Strassen::Util::write_cache($s->{QuadTree}, $cachefile)) {
	    warn "Wrote cache ($cachefile)\n" if $Strassen::VERBOSE;
	}
    }

    return $s->{QuadTree};
}

sub get_quadtree {
    my($s, %args) = @_;
    $s->{QuadTree} || $s->create_quadtree(%args);
}

sub get_objects_in_region {
    my($s, $x0,$y0,$x1,$y1, %args) = @_;
    $s->get_quadtree(%args)->getEnclosedObjects($x0,$y0,$x1,$y1);
}

1;

__END__

Example usage:

perl -Ilib -MStrassen -MStrassen::QuadTree -MData::Dumper -e '$s=MultiStrassen->new(qw(strassen landstrassen landstrassen2)); warn Dumper [ map { $s->get($_)->[Strassen::NAME] } sort {$a <=> $b} @{ $s->get_objects_in_region(9222,8787,9395,10233, UseCache => 1) }]'

