# -*- perl -*-

#
# $Id: WaypointPlus.pm,v 1.3 2005/04/18 07:10:58 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2005 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package Strassen::WaypointPlus;

=head1 NAME

Strassen::WaypointPlus - support for the Waypoint+ format

=head1 DESCRIPTION

See L<http://www.tapr.org/~kh2z/Waypoint/> for programm
information.

=cut

use strict;
use vars qw(@ISA);

require Strassen::Core;

require GPS::WaypointPlus;

@ISA = 'Strassen';

sub new {
    my($class, $filename, %args) = @_;
    my $self = {};
    bless $self, $class;

    if ($filename) {
	$self->read_waypoint_plus($filename, %args);
    }

    $self;
}

sub read_waypoint_plus {
    my($self, $file, %args) = @_;

    my $wp = GPS::WaypointPlus->new;
    my $res = $wp->parse($file, %args);
    return if !$res;

    $self->{Data} = [];

    if ($res->{type} eq 'W') {
	for my $p (@{ $res->{points} }) {
	    $self->push([$p->[2], [$p->[0].",".$p->[1]], "X"]);
	}
    } else {
	$self->push(["", [ map { $_->[0].",".$_->[1] } @{ $res->{points} } ], "X"]);
    }
}

1;
