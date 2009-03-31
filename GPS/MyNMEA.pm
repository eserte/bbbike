# -*- perl -*-

#
# $Id: MyNMEA.pm,v 1.8 2007/07/23 19:37:53 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001,2009 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package GPS::MyNMEA;
require GPS;
push @ISA, 'GPS';

require Karte::Standard;

use strict;

sub magics { ('^\$(GPGSA|GPGSV|GPRMB|GPRMC|PGRMC|PGRME|PGRMI|PGRMO|PGRMT|PGRMV|GPGGA)') }

sub convert_to_route {
    my($self, $file, %args) = @_;

    my($fh, $lines_ref) = $self->overread_trash($file, %args);
    die "File $file does not match" unless $fh;

    require Karte::GPS;
    my $obj = $Karte::GPS::obj;
    $Karte::GPS::obj = $Karte::GPS::obj if 0; # peacify -w
    $Karte::Standard::obj = $Karte::Standard::obj if 0; # peacify -w

# XXX noch nicht zufriedenstellend... ist es überhaupt richtig? außerdem
# zu ungenau....

    my @res;
    my $check = sub {
	my $line = shift;
	if ($line =~ m{^\$GPRMC}) {
	    my $ret = parse_GPRMC($line);
	    if ($ret) {
		my($x,$y) = $Karte::Standard::obj->trim_accuracy($obj->map2standard($ret->{lon}, $ret->{lat}));
		if (!@res || ($x != $res[-1]->[0] ||
			      $y != $res[-1]->[1])) {
		    push @res, [$x, $y];
		}
	    }
	}
    };

    $check->($_) foreach @$lines_ref;
    while(<$fh>) {
	$check->($_);
    }

    close $fh;

    @res;
}

sub parse_GPRMC {
    my $line = shift;
    chomp;
    my(@l) = split(',', $_);
    my $XXX_A_or_V = $l[2];
    return if $XXX_A_or_V eq 'V';
    my $breite_raw = $l[3]; # N is positive
    my $ns         = $l[4];
    my $laenge_raw = $l[5]; # E is positive
    my $ew         = $l[6];
    $breite_raw *= -1 if ($ns eq 'S');
    $laenge_raw *= -1 if ($ew eq 'W');

    my($breite_min, $breite_dec) = split(/\./, $breite_raw);
    my($laenge_min, $laenge_dec) = split(/\./, $laenge_raw);
    my($breite, $laenge);
    $breite_min =~ /^(.*)(..)$/;
    ($breite, $breite_min) = ($1, $2);
    $laenge_min =~ /^(.*)(..)$/;
    ($laenge, $laenge_min) = ($1, $2);

    $breite_min = $breite_min/60;
    $laenge_min = $laenge_min/60;
    $breite_dec = ("0.".$breite_dec)/60;
    $laenge_dec = ("0.".$laenge_dec)/60;
    $breite += $breite_min + $breite_dec;
    $laenge += $laenge_min + $laenge_dec;

    my $isodate = do {
	my($H,$M,$S) = $l[1] =~ m{^(\d\d)(\d\d)(\d\d)$};
	my($d,$m,$y) = $l[9] =~ m{^(\d\d)(\d\d)(\d\d)$};
	$y+=2000; # no support before 2000
	"$y$m$d".'T'."$H$M$S";
    };
    return {lon=>$laenge, lat=>$breite, isodate=>$isodate};
}

sub convert_to_wpt_strassen {
    my($self, $file, %args) = @_;

    my($fh, $lines_ref) = $self->overread_trash($file, %args);
    die "File $file does not match" unless $fh;

    require Karte::GPS;
    my $obj = $Karte::GPS::obj;
    $Karte::GPS::obj = $Karte::GPS::obj if 0; # peacify -w
    $Karte::Standard::obj = $Karte::Standard::obj if 0; # peacify -w

    require Strassen::Core;
    my $s = Strassen->new;

    my $curr_acc;

    my $check = sub {
	my $line = shift;
	if ($line =~ m{^\$PGRME,(.*?),}) {
	    $curr_acc = $1;
	    if ($curr_acc > 1000) {
		$curr_acc = undef;
	    }
	} elsif ($line =~ m{^\$GPRMC}) {
	    my $ret = parse_GPRMC($line);
	    if ($ret) {
		my($x,$y) = $Karte::Standard::obj->trim_accuracy($obj->map2standard($ret->{lon}, $ret->{lat}));
		my $cat = accuracy_to_cat($curr_acc);
		$s->push([$ret->{isodate}, ["$x,$y"], $cat]);
	    }
	}
    };

    $check->($_) foreach @$lines_ref;
    while(<$fh>) {
	$check->($_);
    }

    close $fh;

    $s;
}

sub accuracy_to_cat {
    my($acc) = @_;
    (!defined $acc ? '#f0d0d0' :
     $acc <= 8  ? '#800000' :
     $acc <= 12 ? '#b00000' :
     $acc <= 20 ? '#e00000' :
     $acc <= 40 ? '#f08080' :
                  '#f0c0c0'
    );
}

1;

__END__

=head1 EXAMPLES

Dump the coordinates of a NMEA file:

    perl -w -MData::Dumper -MGPS::MyNMEA -e 'warn Dumper(GPS::MyNMEA->convert_to_route(shift))' nmeafile

Convert a NMEA file into a bbd (one route):

    perl -MRoute -MRoute::Heavy -MGPS::MyNMEA -e 'print Route->new_from_realcoords([GPS::MyNMEA->convert_to_route(shift)])->as_strassen->as_string' /tmp/nmea

Convert a NMEA file into a bbd (single wpts):

    perl -Ilib -MGPS::MyNMEA -e 'print GPS::MyNMEA->convert_to_wpt_strassen(shift)->as_string' /tmp/nmea

=cut
