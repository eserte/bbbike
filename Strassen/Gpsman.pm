# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (c) 2004,2012,2014 Slaven Rezic. All rights reserved.
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

    my $preserve_time = delete $args{PreserveTime};

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
	} elsif ($chunk->Type eq GPS::GpsmanData::TYPE_GROUP()) {
	    # ignore this chunk
	} else {
	    my @wpts = @{ $chunk->Track };
	    if (@wpts) {
		my $name = $args{name} || $chunk->Name;
		if (   defined $name
		       && $name =~ /^ACTIVE LOG(?:\s+\d+)?$/i # see Pod for "ACTIVE LOG" handling
		       && $args{fallbackname}
		   ) {
		    $name = $args{fallbackname};
		}
		if (!defined $name) {
		    $name = "";
		}

		my @coords = map { $convert_coordinates->($_) } @wpts;
		if ($preserve_time) {
		    for my $i (0 .. $#coords-1) {
			my $wpt = $wpts[$i];
			my $epoch = $wpt->Comment_to_unixtime($chunk);
			$self->push_ext([$name, [$coords[$i], $coords[$i+1]], $cat], { time => [ $epoch ] });
		    }
		} else {
		    $self->push([$name, \@coords, $cat]);
		}
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

__END__

=head1 DESCRIPTION

Load a L<gpsman(1)> file (containing tracks, routes, or waypoints)
into a L<Strassen>-compatible object.

The gpsman chunk name is used for the street name field of the
generated bbd record. A special handling is used for the names "ACTIVE
LOG" and "ACTIVE LOG <number>": the former is typically used as an
"anonymous" name by gpsman. The latter is a private extension to be
able to split a track into multiple tracks (e.g. to apply different
track attributes, e.g. different srt:vehicle values). If the option
C<< -fallbackname => ... >> is supplied to the constructur, then
"ACTIVE LOG" and "ACTIVE LOG <number>" are replaced by this value.

=head1 OPTIONS

=over

=item C<< PreserveTime => 1 >>

Time in the GPS track is preserved by creating C<< time >> directives
(which is in seconds since Unix epoch). The track is split into pairs
of coordinates.

An example to convert a GPSman track into a bbd file with C<< time >>
directives:

    cd .../bbbike
    perl -Ilib -MStrassen::Core -e '$f=shift; $s = Strassen->new($f,PreserveTime=>1); print $s->as_string' /path/to/gpsman.trk > /path/to/result.bbd

=back

=head1 AUTHOR

Slaven Rezic <eserte@users.sourceforge.net>

=head1 COPYRIGHT

Copyright (c) 2004,2012,2014 Slaven Rezic. All rights reserved.
This is free software; you can redistribute it and/or modify it under the
terms of the GNU General Public License, see the file COPYING.

=head1 SEE ALSO

L<Strassen::Core>, L<gpsman(1)>.

=cut
