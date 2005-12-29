# -*- perl -*-

#
# $Id: Gpsman.pm,v 1.8 2005/12/28 19:24:11 eserte Exp $
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

sub new_from_string {
    my($class, $string, %args) = @_;
    my $self = {};
    bless $self, $class;
    $self->read_gpsman_from_string($string, %args);
    $self;
}

sub _read_gpsman {
    my($self, $gpsman, %args) = @_;

    # Options for this? XXX
    my $in_map = $Karte::Polar::obj = $Karte::Polar::obj;
    my $out_map = $Karte::Standard::obj = $Karte::Standard::obj;
    my $convert_coordinates = sub {
	my $o = shift;
	join ",", $out_map->trim_accuracy($in_map->map2standard($o->Longitude, $o->Latitude));
    };

    $self->{Data} = [];
    $self->{DependentFiles} = [ $gpsman->File ];

    my $cat = $args{cat} || "X";

    for my $chunk (@{ $gpsman->Chunks }) {
	if ($chunk->Type eq GPS::GpsmanData::TYPE_WAYPOINT()) {
	    for my $wpt (@{ $chunk->Waypoints }) {
		my $name = $wpt->Ident;
		if (defined $wpt->Comment && $wpt->Comment ne "") {
		    $name .= " (" . $wpt->Comment . ")";
		}
		my @coords = $convert_coordinates->($wpt);
		if (@coords) {
		    $self->push([$name, \@coords, $cat]);
		}
	    }
	} else {
	    my @coords;
	    for my $wpt (@{ $chunk->Track }) {
		push @coords, $convert_coordinates->($wpt);
	    }
	    if (@coords) {
		my $name = $args{name} || $chunk->Name;
		if (defined $name && $name =~ /^ACTIVE LOG$/i && $args{fallbackname}) {
		    $name = $args{fallbackname};
		}
		if (!defined $name) {
		    $name = "";
		}
		$self->push([$name, \@coords, $cat]);
	    }
	}
    }
}

sub read_gpsman {
    my($self, $filename, %args) = @_;

    my $gpsman = GPS::GpsmanMultiData->new();

    {
	local $^W = 0;
	$gpsman->load($filename); # setting File
	## XXX del:
	#$gpsman->convert_all("DDD");
    }

    $self->_read_gpsman($gpsman, %args);
}

sub read_gpsman_from_string {
    my($self, $string, %args) = @_;
    my $gpsman = GPS::GpsmanMultiData->new();
    $gpsman->parse($string);
    $gpsman->File($args{File}) if defined $args{File};
    $self->_read_gpsman($gpsman, %args);
}

sub reload {
    # NYI
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
