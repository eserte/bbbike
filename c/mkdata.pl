#!/usr/local/bin/perl -w
# -*- perl -*-

#
# $Id: mkdata.pl,v 1.9 2000/12/12 23:36:28 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999,2000 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

# XXX category

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../data",
	 "$FindBin::RealBin/../lib",
	);
use Strassen;
use strict;
eval q{ use BBBikeXS };

use vars qw($output $endian $m68000 $test $palm);
use vars qw($short $u_short $u_long);
use vars qw(@datadir);

use Getopt::Long;

BEGIN {
    $output = 'data';
    $endian = 'little';

    if (!GetOptions("output=s",  \$output,
		    "little",    sub { $endian = 'little' },
		    "big",       sub { $endian = 'big' },
		    "m68000",    \$m68000,
		    "test",      \$test,
		    "palm",      \$palm,
		    "datadir=s@",\@datadir,
		   )) {
	die "Usage!";
    }

    if ($palm) {
	#$output = 'c';
	$output = 'data';
	$endian = 'big';
	$m68000 = 1;
	$test = 1;
    }

    if ($output !~ /^(data|c)$/) {
	die "wrong value for output";
    }

    if ($endian eq 'little') {
	($short, $u_short, $u_long) = ("v", "v", "V");
	#($short, $u_short, $u_long) = ("s", "S", "L");
    } else {
	($short, $u_short, $u_long) = ("n", "n", "N");
    }
}

# XXX Pack little/big endian Umschaltung ermˆglichen (damit es wirklich
# auf dem Palm l‰uft)
# XXX Ausgabe-Zeichensatz ‰ndern kˆnnen (f¸r Win32-Console, evtl. hat der
# Palm einen anderen Zeichensatz)
# XXX weitere Version mit Index-Redirect f¸r Koordinaten schreiben
# vielleicht spare ich damit weitere Bytes f¸r Neighbour und
# struct route. Evtl. auch Redirect f¸r Straﬂenindex.

use constant KOORDLENSIZE => 2;     # L‰nge der Koordinatenliste pro Straﬂe
use constant KOORDLENPACK => $u_short;
use constant KOORDPTRSIZE => 4;     # Pointer auf Koordinate
use constant KOORDPTRPACK => $u_long;
use constant KOORDSIZE    => 2*2;   # Eine Koordinate (X/Y)
use constant KOORDPACK    => "$short$short";  # reicht f¸r Berlin
use constant BESTLENSIZE  => 2;     # beste derzeitige Entfernung
use constant BESTLENPACK  => $u_short;       # reicht f¸r 64 km
use constant NEIGHBOURLENSIZE => 2; # L‰nge der Nachbarliste
use constant NEIGHBOURLENPACK => $u_short;
use constant NEIGHBOURSIZE    => KOORDPTRSIZE; # Pointer auf Koordinate
use constant NEIGHBOURPACK    => KOORDPTRPACK;
use constant DISTSIZE     => BESTLENSIZE;     # Entfernung zwischen Koordinaten
use constant DISTPACK     => BESTLENPACK;
use constant STRLENSIZE   => 2;     # L‰nge der Straﬂenliste pro Koordinate
use constant STRLENPACK   => $u_short;
use constant STRPTRSIZE   => 4;     # Pointer auf Straﬂe
use constant STRPTRPACK   => $u_long;

if (@datadir) {
    @Strassen::datadirs = @datadir;
}

my $strname = "strassen";
#if (-r "/tmp/test") { $strname = "/tmp/test" }

my $s = new Strassen $strname;
if ($test) {
    splice @{$s->{Data}}, 400;
}
my @str_data; # enth‰lt Elemente der Form ["Strassenname",[Koord1,Koord2...],Pos,"Kat"]
my $last_name;
$s->init;
while(1) {
    my $r = $s->next;
    my @koord = @{$r->[1]};
    last if !@koord;
    my $name = $r->[0];
    my $cat  = $r->[2];
    if (defined $last_name and $last_name eq $name) {
	my $last_krd_ref = $str_data[$#str_data]->[1];
	if ($last_krd_ref->[$#$last_krd_ref] eq $koord[0]) {
	    push @$last_krd_ref, @koord;
	} else {
	    push @str_data, [$name, [@koord], $s->pos, $cat];
	}
    } else {
	push @str_data, [$name, [@koord], $s->pos, $cat];
	$last_name = $name;
    }
}

@str_data = sort { $a->[0] cmp $b->[0] } @str_data;

my %koord_build;
my @str_ptr;
my $active_ptr = 0;
my $str_i = 0;
foreach my $str (@str_data) {
    $str_ptr[$str_i] = $active_ptr;
    foreach my $koord (@{ $str->[1] }) {
	$koord_build{$koord}->{$str_i}++;
    }
    $active_ptr += length($str->[0]) + 1 + KOORDLENSIZE
      + KOORDPTRSIZE * scalar @{ $str->[1] };
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
my @koord_ptr;
my %koord_index;
{
    my $active_ptr = 0;
    my $koord_i = 0;
    while(my($koord, $v) = each %koord2str) {
	$koord_ptr[$koord_i] = $active_ptr;
	$koord_index{$koord} = $koord_i;
	$koord_data[$koord_i] = [$koord];
	$active_ptr += KOORDSIZE + BESTLENSIZE + NEIGHBOURLENSIZE
	  + (NEIGHBOURSIZE + DISTSIZE) * scalar(keys %{ $netz->{Net}{$koord} })
	    + STRLENSIZE
	      + STRPTRSIZE * scalar @$v;
	$koord_i++;
    }
}

# $str_i=0;
# foreach my $str (@koord_data) {
#     print "$str->[0]: $koord_ptr[$str_i]\n";
#     $str_i++;
# }

# FORMAT Straﬂen:
#  Straﬂenname (0-terminierter String)
#  Anzahl der Koordinaten
#  KoordinatenPointer1 (auf Straﬂennetz-Element)
#  ...
# TAMROF
my $str_buf   = "";
for(my $str_i=0; $str_i<=$#str_data; $str_i++) {
    warn "Length/pointer mismatch in str"
      if $str_ptr[$str_i] != length($str_buf);
    my $str = $str_data[$str_i];
    $str_buf .= $str->[0] . "\0";
    if ($m68000 and length($str->[0])%2 == 0) {
	$str_buf .= "\0"; # pack(2) for 68000 cpus
    }
    $str_buf .= pack(KOORDLENPACK, scalar @{ $str->[1] });
    foreach my $koord (@{ $str->[1] }) {
	$str_buf .= pack(KOORDPTRPACK, $koord_ptr[$koord_index{$koord}]);
    }
}

# FORMAT Straﬂennetz:
#  KoordinateX (von diesem Punkt)
#  KoordinateY
#  beste L‰nge (nur f¸r Traversierung)
#  Anzahl der Nachbarn
#  NachbarPointer1 (auf Straﬂennetz-Element)
#  NachbarEntfernung1
#  ...
#  Anzahl der Straﬂen (die diesen Punkt ber¸hren)
#  StraﬂenPointer1 (auf Straﬂen-Element)
#  ...
# TAMROF
my $koord_buf = "";
for(my $koord_i=0; $koord_i<=$#koord_data; $koord_i++) {
    warn "Length/pointer mismatch in koord.\n"
      . $koord_ptr[$koord_i] . " != " . length($koord_buf)
	if $koord_ptr[$koord_i] != length($koord_buf);
    my $koord_o = $koord_data[$koord_i];
    my $koord = $koord_o->[0];
    $koord_buf .= pack(KOORDPACK, split(/,/, $koord)) 
      . pack(BESTLENPACK, 0)
	. pack(NEIGHBOURLENPACK, scalar(keys %{ $netz->{Net}{$koord} }));
    while(my($neighbour, $dist) = each %{ $netz->{Net}{$koord} }) {
	$koord_buf .= pack(NEIGHBOURPACK,
			   $koord_ptr[$koord_index{$neighbour}])
	  . pack(DISTPACK, $dist);
    }
    $koord_buf .= pack(STRLENPACK, scalar @{$koord2str{$koord}});
    foreach my $str (@{$koord2str{$koord}}) {
	$koord_buf .= pack(STRPTRPACK, $str_ptr[$str]);
    }
}

my $outdir = "$FindBin::RealBin/data";
mkdir $outdir, 0755 if !-d $outdir;

if ($output eq 'data') {

    open(STRDATA, ">$outdir/strassen.bin") or die $!;
    print STRDATA $str_buf;
    close STRDATA;

    open(NETZDATA, ">$outdir/netz.bin") or die $!;
    print NETZDATA $koord_buf;
    close NETZDATA;

} elsif ($output eq 'c') {

    open(STR, ">$outdir/strassen.c") or die $!;
    print STR "#include \"bbbike.h\"\n";
    print STR "char str_buf_data[] = {\n";
    my $need_comma = 0;
    for(my $i = 0; $i < length($str_buf); $i++) {
	if ($need_comma) {
	    print STR ",";
	} else {
	    $need_comma++;
	}
	if (($i+1) % 20 == 0) {
	    print STR "\n";
	}
	print STR ord(substr($str_buf, $i, 1));
    }
    print STR "};\n";
    print STR "/* char *str_buf = str_buf_data; */\n";
    print STR "long str_buf_len = " . length($str_buf) . ";\n";
    close STR;

    open(NETZ, ">$outdir/netz.c") or die $!;
    print NETZ "#include \"bbbike.h\"\n";
    print NETZ "char netz_buf_data[] = {\n";
    $need_comma = 0;
    for(my $i = 0; $i < length($koord_buf); $i++) {
	if ($need_comma) {
	    print NETZ ",";
	} else {
	    $need_comma++;
	}
	if (($i+1) % 20 == 0) {
	    print NETZ "\n";
	}
	print NETZ ord(substr($koord_buf, $i, 1));
    }
    print NETZ "};\n";
    print NETZ "/* char *netz_buf = netz_buf_data; */\n";
    print NETZ "long netz_buf_len = " . length($koord_buf) . ";\n";
    close NETZ;

}

sub signed_ord {
    my($ch) = @_;
    my $o = ord($ch);
    if ($o > 127) {
	$o = $o - 255;
    }
    $o;
}

__END__
