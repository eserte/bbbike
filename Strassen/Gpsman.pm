# -*- perl -*-

#
# $Id: Gpsman.pm,v 1.4 2005/05/19 00:05:42 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (c) 2004 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://bbbike.sourceforge.net
#

package Strassen::Gpsman;

use strict;
use vars qw(@ISA);

require Strassen::Core;
require Strassen::MultiStrassen;

require GPS::GpsmanData;

require Karte;
require Karte::Polar;
require Karte::Standard;

@ISA = 'Strassen';

=head1 NAME

Strassen::Gpsman - read gpsman files into a Strassen object

=head1 SYNOPSIS

    use Strassen::Gpsman;
    $s = Strassen::Gpsman->new("file.wpt");

=cut

sub new {
    my($class, $filename, %args) = @_;
    my $self = {};
    bless $self, $class;

    if ($filename) {
	$self->read_gpsman($filename, %args);
    }

    $self;
}

sub read_gpsman {
    my($self, $filename, %args) = @_;

    my $gpsman = GPS::GpsmanData->new();

    {
	local $^W = 0;
	$gpsman->load($filename);
	## XXX del:
	#$gpsman->convert_all("DDD");
    }

    # Options for this? XXX
    my $in_map = $Karte::Polar::obj = $Karte::Polar::obj;
    my $out_map = $Karte::Standard::obj = $Karte::Standard::obj;
    my $convert_coordinates = sub {
	my $o = shift;
	join ",", $out_map->trim_accuracy($in_map->map2standard($o->Longitude, $o->Latitude));
    };

    $self->{Data} = [];

    if ($gpsman->Type eq GPS::GpsmanData::TYPE_WAYPOINT()) {
	for my $wpt (@{ $gpsman->Waypoints }) {
	    my $name = $wpt->Ident;
	    if (defined $wpt->Comment && $wpt->Comment ne "") {
		$name .= " (" . $wpt->Comment . ")";
	    }
	    my $cat = "X"; # XXX
	    my @coords = $convert_coordinates->($wpt);
	    $self->push([$name, \@coords, $cat]);
	}
    } else {
	my @coords;
	for my $wpt (@{ $gpsman->Track }) {
	    push @coords, $convert_coordinates->($wpt);
	}
	my $name = $gpsman->Name;
	my $cat = "X"; # XXX
	$self->push([$name, \@coords, $cat]);
    }
}

1;

=head1 AUTHOR

Slaven Rezic <eserte@users.sourceforge.net>

=head1 COPYRIGHT

Copyright (c) 2004 Slaven Rezic. All rights reserved.
This is free software; you can redistribute it and/or modify it under the
terms of the GNU General Public License, see the file COPYING.

=head1 SEE ALSO

L<Strassen::Core>.
