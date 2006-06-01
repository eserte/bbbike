#!/usr/local/bin/perl -w
# -*- perl -*-

#
# $Id: mkdatapdb.pl,v 1.1 1999/09/09 20:28:42 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../data",
	 "$FindBin::RealBin/../lib",
	);
use Strassen;
use PDA::Pilot;
use strict;
eval q{ use BBBikeXS };

use vars qw($output $endian $m68000 $test $palm);
use vars qw($short $u_short $u_long);

use Getopt::Long;

BEGIN {
    $output = 'pdb';
    $endian = 'big';
    $palm   = 1;
    $m68000 = 1;

    if (!GetOptions("output=s", \$output,
		    "little",   sub { $endian = 'little' },
		    "big",      sub { $endian = 'big' },
		    "m68000",   \$m68000,
		    "test",     \$test,
		    "palm",     \$palm,
		   )) {
	die "Usage!";
    }

    if ($output !~ /^(pdb)$/) {
	die "wrong value for output";
    }

    if ($endian eq 'little') {
	($short, $u_short, $u_long) = ("v", "v", "V");
	#($short, $u_short, $u_long) = ("s", "S", "L");
    } else {
	($short, $u_short, $u_long) = ("n", "n", "N");
    }
}

#my $rec_limit = 60000;
my $rec_limit = 40000;

# XXX Pack little/big endian Umschaltung ermöglichen (damit es wirklich
# auf dem Palm läuft)
# XXX Ausgabe-Zeichensatz ändern können (für Win32-Console, evtl. hat der
# Palm einen anderen Zeichensatz)
# XXX weitere Version mit Index-Redirect für Koordinaten schreiben
# vielleicht spare ich damit weitere Bytes für Neighbour und
# struct route. Evtl. auch Redirect für Straßenindex.

use constant KOORDLENSIZE => 2;     # Länge der Koordinatenliste pro Straße
use constant KOORDLENPACK => $u_short;
#use constant KOORDPTRSIZE => 4;     # Pointer auf Koordinate
#use constant KOORDPTRPACK => $u_long;
use constant KOORDSIZE    => 2*2;   # Eine Koordinate (X/Y)
use constant KOORDPACK    => "$short$short";  # reicht für Berlin
use constant OPENCLOSESIZE  => 2;   # OPEN/CLOSE-Flag
use constant OPENCLOSEPACK  => $u_short;
use constant BESTLENSIZE  => 2;     # Entfernung
use constant BESTLENPACK  => $u_short;       # reicht für 64 km
use constant NEIGHBOURLENSIZE => 2; # Länge der Nachbarliste
use constant NEIGHBOURLENPACK => $u_short;
#use constant NEIGHBOURSIZE    => KOORDPTRSIZE; # Pointer auf Koordinate
#use constant NEIGHBOURPACK    => KOORDPTRPACK;
use constant DISTSIZE     => BESTLENSIZE;     # Entfernung zwischen Koordinaten
use constant DISTPACK     => BESTLENPACK;
use constant STRLENSIZE   => 2;     # Länge der Straßenliste pro Koordinate
use constant STRLENPACK   => $u_short;
#use constant STRPTRSIZE   => 4;     # Pointer auf Straße
#use constant STRPTRPACK   => $u_long;
use constant RECINDEXSIZE => 2;     # ein Record-Index
use constant RECINDEXPACK => $u_short;
use constant PTRSIZE      => 2;     # ein Offset innerhalb eines Records
use constant PTRPACK      => $u_short;

my $strname = "strassen";

my $s = new Strassen $strname;
if ($test) {
    splice @{$s->{Data}}, 400;
}
my @str_data; # enthält Elemente der Form ["Strassenname",[Koord1,Koord2...]]
my $last_name;
$s->init;
while(1) {
    my $r = $s->next;
    my @koord = @{$r->[1]};
    last if !@koord;
    my $name = $r->[0];
    if (defined $last_name and $last_name eq $name) {
	my $last_krd_ref = $str_data[$#str_data]->[1];
	if ($last_krd_ref->[$#$last_krd_ref] eq $koord[0]) {
	    push @$last_krd_ref, @koord;
	} else {
	    push @str_data, [$name, [@koord], $s->pos];
	}
    } else {
	push @str_data, [$name, [@koord], $s->pos];
	$last_name = $name;
    }
}

# Sortierung nach Straßennamen
@str_data = sort { $a->[0] cmp $b->[0] } @str_data;

my %koord_build;
my @str_rec; # hält die Recordnummer für die Straße
my @str_ptr; # hält den Offset innerhalb eines Records für die Straße
my $active_rec = 1; # Rec. 0 ist reserviert (evtl. für Datenformatbeschreibung)
my $active_ptr = 0;
my $str_i = 0;
foreach my $str (@str_data) {
    # Genau genommen ist die Grenze ca. bei 64K, aber so exakt ist es
    # nicht notwendig. Wenn es Mini-Records gibt, die größer als 5000
    # Bytes sind, kann es hier zu einem Überlauf kommen!
    if ($active_ptr > $rec_limit) {
	$active_rec++;
	$active_ptr = 0;
    }

    $str_rec[$str_i] = $active_rec;
    $str_ptr[$str_i] = $active_ptr;

    foreach my $koord (@{ $str->[1] }) {
	$koord_build{$koord}->{$str_i}++;
    }
    $active_ptr += length($str->[0]) + 1 + KOORDLENSIZE 
      + (RECINDEXSIZE+PTRSIZE) * scalar @{ $str->[1] };
    if ($m68000 and length($str->[0])%2 == 0) {
	$active_ptr++; # pack(2) for 68000 cpus
    }
    $str_i++;
}

# $str_i=0;
# foreach my $str (@str_data) {
#     print "$str->[0]: $str_ptr[$str_i]\n";
#     $str_i++;
# }

my %koord2str; # Koordinate => [Strassenindex1, Strassenindex2 ...]
my $koord_i = 0;
while(my($koord, $v) = each %koord_build) {
    $koord2str{$koord} = [keys %$v];
}

my $netz = new StrassenNetz $s;
$netz->make_net;
$netz->make_sperre("gesperrt", Type => [qw(einbahn sperre tragen)]);

my @koord_data;
my @koord_rec;
my @koord_ptr;
my %koord_index;
{
    my $active_rec = 1;
    my $active_ptr = 0;
    my $koord_i = 0;
    while(my($koord, $v) = each %koord2str) {
	if ($active_ptr > $rec_limit) {
	    $active_rec++;
	    $active_ptr = 0;
	}

	$koord_rec[$koord_i] = $active_rec;
	$koord_ptr[$koord_i] = $active_ptr;

	$koord_index{$koord} = $koord_i;
	$koord_data[$koord_i] = [$koord];
	$active_ptr += KOORDSIZE + OPENCLOSESIZE + (RECINDEXSIZE+PTRSIZE)*2 +
	  BESTLENSIZE*2 + NEIGHBOURLENSIZE
	    + (RECINDEXSIZE+PTRSIZE + DISTSIZE) 
	      * scalar(keys %{ $netz->{Net}{$koord} })
		+ STRLENSIZE
		  + (RECINDEXSIZE+PTRSIZE) * scalar @$v;
	$koord_i++;
    }
}

# $str_i=0;
# foreach my $str (@koord_data) {
#     print "$str->[0]: $koord_ptr[$str_i]\n";
#     $str_i++;
# }

# FORMAT Straßen:
#  Straßenname (0-terminierter String)
#  Anzahl der Koordinaten
#  KoordinatenPointer1 (auf Straßennetz-Element)
#  ...
# TAMROF
my @str_buf;
for(my $str_i=0; $str_i<=$#str_data; $str_i++) {
    my $act_rec = $str_rec[$str_i];
    warn "Length/pointer mismatch in str"
      if $str_ptr[$str_i] != length($str_buf[$act_rec]);
    my $str = $str_data[$str_i];
    $str_buf[$act_rec] .= $str->[0] . "\0";
    if ($m68000 and length($str->[0])%2 == 0) {
	$str_buf[$act_rec] .= "\0"; # pack(2) for 68000 cpus
    }
    $str_buf[$act_rec] .= pack(KOORDLENPACK, scalar @{ $str->[1] });
    foreach my $koord (@{ $str->[1] }) {
	$str_buf[$act_rec] .=
	  pack(RECINDEXPACK, $koord_rec[$koord_index{$koord}]) .
	    pack(PTRPACK, $koord_ptr[$koord_index{$koord}]);
    }
}

# FORMAT Straßennetz:
#  KoordinateX (von diesem Punkt)
#  KoordinateY
#  OPEN/CLOSE-Flag (für A*)
#  PrevLink (für A*)
#  NextLink (für A*)
#  Länge f (für A*)
#  Länge g (für A*)
#  Anzahl der Nachbarn
#  NachbarPointer1 (auf Straßennetz-Element)
#  NachbarEntfernung1
#  ...
#  Anzahl der Straßen (die diesen Punkt berühren)
#  StraßenPointer1 (auf Straßen-Element)
#  ...
# TAMROF
my @koord_buf;
for(my $koord_i=0; $koord_i<=$#koord_data; $koord_i++) {
    my $act_rec = $koord_rec[$koord_i];
    warn "Length/pointer mismatch in koord.\n"
      . $koord_ptr[$koord_i] . " != " . length($koord_buf[$act_rec])
	if $koord_ptr[$koord_i] != length($koord_buf[$act_rec]);
    my $koord_o = $koord_data[$koord_i];
    my $koord = $koord_o->[0];
    $koord_buf[$act_rec] .=
      pack(KOORDPACK, split(/,/, $koord)) 
	. pack(OPENCLOSEPACK, 0)
	  . pack(RECINDEXPACK, 0) # PrevLink
	    . pack(PTRPACK, 0)
	      . pack(RECINDEXPACK, 0) # NextLink
		. pack(PTRPACK, 0)
		  . pack(BESTLENPACK, 0) # f
		    . pack(BESTLENPACK, 0); # g
    $koord_buf[$act_rec] .=
      pack(NEIGHBOURLENPACK, scalar(keys %{ $netz->{Net}{$koord} }));
    while(my($neighbour, $dist) = each %{ $netz->{Net}{$koord} }) {
	$koord_buf[$act_rec] .=
	  pack(RECINDEXPACK, $koord_rec[$koord_index{$neighbour}])
	    . pack(PTRPACK, $koord_ptr[$koord_index{$neighbour}])
	      . pack(DISTPACK, $dist);
    }
    $koord_buf[$act_rec] .= pack(STRLENPACK, scalar @{$koord2str{$koord}});
    foreach my $str (@{$koord2str{$koord}}) {
	$koord_buf[$act_rec] .=
	  pack(RECINDEXPACK, $str_rec[$str])
	    . pack(PTRPACK, $str_ptr[$str]);
    }
}

my $outdir = "$FindBin::RealBin/data";

my $uid=0;

my $pf_str = PDA::Pilot::File::create($outdir . "/strassen.pdb",
				      {creator => "Bike",
				       type => "BBst", # BBBike street
				       name => "strassen",
				      });
$pf_str->addRecordRaw("", $uid++, 0, 0);
foreach my $i (1 .. $#str_buf) {
    my $str_buf = $str_buf[$i];
    $pf_str->addRecordRaw($str_buf, $uid++, 0, 0);
}
$pf_str->close;

my $pf_net = PDA::Pilot::File::create($outdir . "/netz.pdb",
				      {creator => "Bike",
				       type => "BBnt", # BBBike net
				       name => "netz",
				      });
$pf_net->addRecordRaw("", $uid++, 0, 0);
foreach my $i (1 .. $#koord_buf) {
    my $koord_buf = $koord_buf[$i];
    $pf_net->addRecordRaw($koord_buf, $uid++, 0, 0);
}
$pf_net->close;

__END__
