# -*- perl -*-

#
# $Id: MasterPunkte.pm,v 1.2 1999/04/13 13:38:34 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

# neues Punkt-Format
# Kommentare/Namen/etc.:
# * Straßen
#   tragen
#   Vorfahrt
#   Ampelkategorie (ohne Richtung (?))
#   Sperrung
#   Penalty
#   Höhe (ohne Richtung)
# * locker mit Straßen verbunden
#   Label-Name, Label-Orientierung, Label-Anchor
#   Platz
#   Obst-Art
# * Sonstiges
#   Ort-Name, Ort-Kategorie
#   S-Bahnhof, VBB-Zone
#   U-Bahnhof, VBB-Zone
#   R-Bahnhof, VBB-Zone

# Datenformat:
#
# x,y TAB Attribute TAB x1,y1 x2,y2 TAB Attribute<->;Attribute->;Attribute<- TAB ...
#
# Format der Attribute:
#
# Attributzeichen [ = Kommentar ], Attributzeichen...
#

use strict;

{
    package MasterPunkt;

    use constant Hoehe               => 'h';
    use constant Vorfahrt            => 'v';

    use constant Sperrung            => 'x';
    use constant Tragen              => 't';
    use constant Penalty             => 'p';

    use constant Ampel               => 'X';
    use constant Fussgaengerampel    => 'F';
    use constant Bahnuebergang       => 'B';

    use constant Fragezeichen        => '?';

    sub new {
	my($class, $coord) = @_;
	my $self = {};
	$self->{Coord} = $coord;
	bless $self, $class;
    }

    sub parse {
	my($class, $str) = @_;
	my($p, $glob, $rest) = split(/\t/, $str, 3);
	my $o = $class->new($p);
	my(%r) = _parse_attributes($glob);
	if (keys %r) {
	    $o->{Global} = \%r;
	}

	while(1) {
	    if (defined $rest and $rest =~ /^(\S+)\s(\S+)\t([^\t]*)(.*)$/) {
		my($c1, $c2, $attr) = ($1, $2, $3);
		$rest = $4; $rest =~ s/^\t//;
		my($both, $forth, $back) = split(/;/, $attr);
		if ($both ne '') {
		    my(%r) = _parse_attributes($both);
		    $o->{Line}{$c1}{$c2} = \%r;
		}
		if ($forth ne '') {
		    my(%r) = _parse_attributes($forth);
		    $o->{Vector}{$c1}{$c2} = \%r;
		}
		if ($back ne '') {
		    my(%r) = _parse_attributes($back);
		    $o->{Vector}{$c2}{$c1} = \%r;
		}
	    } else {
		last;
	    }
	}

	$o;
    }
    
    sub _parse_attribute {
	my $str = shift;
	my($k,$v) = split(/=/, $str, 2);
	if (!defined $v) { $v = "1" }
	($k,$v);
    }

    sub _parse_attributes {
	my $str = shift;
	my(@a) = split(/,/, $str);
	my %r;
	foreach (@a) {
	    my($k,$v) = _parse_attribute($_);
	    $r{$k} = $v;
	}
	%r;
    }

    

    sub set_global {
	my($self, %args) = @_;
	while(my($k, $v) = each %args) {
	    $self->{Global}{$k} = $v;
	}
    }

    sub set_line {
	my($self, $coord1, $coord2, %args) = @_;
	if (exists $self->{Line}{$coord2}{$coord1}) {
	    ($coord1, $coord2) = ($coord2, $coord1);
	}
	while(my($k, $v) = each %args) {
	    $self->{Line}{$coord1}{$coord2}{$k} = $v;
	}
    }

    sub set_vector {
	my($self, $coord1, $coord2, %args) = @_;
	while(my($k, $v) = each %args) {
	    $self->{Vector}{$coord1}{$coord2}{$k} = $v;
	}
    }

    # Alle benachbarten Punkte feststellen
    sub get_neighbours {
	my $self = shift;
	my @add_coords;
	my %add_coords;
	foreach my $type (qw(Line Vector)) {
	    foreach my $c1 (keys %{ $self->{$type} }) {
		foreach my $c2 (keys %{ $self->{$type}{$c1} }) {
		    if (!exists $add_coords{"$c1,$c2"} &&
			!exists $add_coords{"$c2,$c1"}) {
			push @add_coords, [$c1, $c2];
			$add_coords{"$c1,$c2"}++;
		    }
		}
	    }
	}
	@add_coords;
    }

    # Gibt die String-Repräsentation für das Abspeichern in der
    # Datenbank zurück. Wenn keine Attribute gesetzt sind,
    # wird ein leerer String zurückgegeben.
    sub as_string {
	my $self = shift;
	my $ret = $self->{Coord} . "\t";
	my @attr;
	my $has_global = 0;
	while(my($k, $v) = each %{ $self->{Global} }) {
	    push @attr, _attribute($k, $v);
	    $has_global++;
	}
	$ret .= join(",", @attr);

	my(@add_coords) = $self->get_neighbours;
	my(@add_coords_attr);
	foreach my $def (@add_coords) {
	    my($c1, $c2) = @$def;
	    my(@both, @forth, @back);

	    # hin und zurück
	    my %h = (exists $self->{Line}{$c1}{$c2}
		     ? %{ $self->{Line}{$c1}{$c2} }
		     : (exists $self->{Line}{$c1}{$c2}
			? %{ $self->{Line}{$c2}{$c1} }
			: ()));
	    while(my($k, $v) = each %h) {
		push @both, _attribute($k, $v);
	    }

	    # hin
	    if (exists $self->{Vector}{$c1}{$c2}) {
		while(my($k, $v) = each %{ $self->{Vector}{$c1}{$c2} }) {
		    push @forth, _attribute($k, $v);
		}
	    }

	    # zurück
	    if (exists $self->{Vector}{$c2}{$c1}) {
		while(my($k, $v) = each %{ $self->{Vector}{$c2}{$c1} }) {
		    push @back, _attribute($k, $v);
		}
	    }

	    if (@both || @forth || @back) {
		push @add_coords_attr, "$c1 $c2\t" . join(";",
							  join(",", @both),
							  join(",", @forth),
							  join(",", @back));
	    }
	}
	if (@add_coords_attr) {
	    $ret .= "\t" . join("\t", @add_coords_attr);
	}
	if (!@add_coords_attr && !$has_global) {
	    "";
	} else {
	    $ret;
	}
    }

    sub _remove_special {
	my $str = shift;
	$str =~ s/=;,\t//g;
	$str;
    }

    sub _attribute {
	my($k, $v) = @_;
	if ($v eq "1") {
	    $k;
	} else {
	    $k . "=" . _remove_special($v);
	}
    }

=head2 selfcheck

Überprüft den Konstantenteil auf Konflikte. Aufruf:

   perl5.00502 -MMasterPunkte -e 'MasterPunkt::selfcheck()'

=cut

    sub selfcheck {
	open(M, "MasterPunkte.pm") or die;
	my $found_pkg;
	my %used;
	while(<M>) {
	    if ($found_pkg && /use\s+constant\s+(\S+).*'(.)'/) {
		if (exists $used{$2}) {
		    warn "$2 wird bereits von $1 verwendet!";
		} else {
		    $used{$2} = $1;
		}
	    } elsif ($found_pkg && /package\s+/) {
		last;
	    } elsif (/package\s+MasterPunkt/) {
		$found_pkg = 1;
	    }
	}
	close M;
	warn "Done.\n";
    }
}

package MasterPunkte;

use DB_File;
use vars qw(@datadirs $VERBOSE); # XXX $OLD_AGREP 

@datadirs = ("$FindBin::RealBin/data", './data');
foreach (@INC) {
    push @datadirs, "$_/data";
}

sub new {
    my($class, $filename, %arg) = @_;
    my @filenames;
    if (defined $filename) {
	push @filenames, $filename, map { "$_/$filename" } @datadirs;
    }
    my $self = {};
    bless $self, $class;

    if (@filenames) {
      TRY: {
	    foreach my $file (@filenames) {
		if (-f $file and -r _) {
		    my @a;
		    my $db =
		      tie @a, 'DB_File', $file, O_RDWR, 0644, $DB_RECNO;
		    if ($db) {
			$self->{DB} = $db;
			last TRY;
		    }
		}
	    }
	    die "Can't open ", join(", ", @filenames);
	}
    }

    $self->{Pos} = 0;

    $self;
}

# initialisiert für next() und gibt *keinen* Wert zurück
sub init {
    my $self = shift;
    $self->{Pos} = 0;
}

sub getpoint {
    my($self, $pos) = @_;
    while ($pos < $self->{DB}->length) {
	my $line;
	$self->{DB}->get($pos, $line);
	if ($line !~ /^\s*($|\#)/) {
	    my $o = parse MasterPunkt $line;
	    return ($o, ++$pos);
	} else {
	    $pos++;
	}
    }
    undef;
}

sub nextpoint {
    my $self = shift;
    my($o, $pos) = $self->getpoint($self->{Pos});
    if (defined $pos) {
	$self->{Pos} = $pos;
    }
    $o;
}

sub read {
    my $self = shift;
    undef $self->{Data};
    $self->init;
    my $pos = 0;
    while(1) {
	my $o = $self->nextpoint;
	last if !$o;
	$self->{Data}{$o->{Coord}} = $o;
	$o->{Pos} = $pos;
	$pos++;
    }
}

# read() muß vorher aufgerufen worden sein.
sub get_point {
    my($self, $coord) = @_;
    $self->{Data}{$coord};
}

# read() muß vorher aufgerufen worden sein.
# $o: das abzuspeichernde MasterPunkt-Objekt
# $pos: Die Position in der Datenbank. Wenn nicht angegeben, wird die
#       alte Position $o->{Pos} verwendet. Wenn diese auch nicht existiert,
#       wird das Objekt ans Ende geschrieben.
# $nosync: Verhindert ein flush, damit große Datenmengen schnell geschrieben
#          werden können. Siehe flush-Methode.
sub set_point {
    my($self, $o, $pos, $nosync) = @_;
    $pos = $o->{Pos} unless defined $pos;
    $pos = $self->{DB}->length unless defined $pos;
    $self->{DB}->put($pos, $o->as_string);
    $o->{Pos} = $pos;
    $self->{Data}{$o->{Coord}} = $o;
    $self->{DB}->sync unless $nosync;
}

sub flush {
    shift->{DB}->sync;
}

return 1 if caller();

{
    package main;
    no strict;
    $p = new MasterPunkte "/tmp/test";
    $p->read;
use Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->Dumpxs([$p],[]); # XXX

}
