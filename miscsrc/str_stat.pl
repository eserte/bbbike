#!/usr/local/bin/perl -w
# -*- perl -*-

#
# $Id: str_stat.pl,v 1.8 2002/09/01 08:49:05 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../lib");
use Strassen::Core;
use Strassen::MultiStrassen;
use Strassen::Stat;
use strict;

my %seen;
my %str;

{
    my $s = new MultiStrassen
	Strassen->new("wasserumland"),
	Strassen->new("wasserumland2"),
	Strassen->new("wasserstrassen");

    my $last_seen;
    $s->init;
    while(1) {
	my $r = $s->next;
	last if !@{$r->[Strassen::COORDS]};
	my $is_insel = $r->[Strassen::CAT] =~ /^F:I/;
	next if $r->[Strassen::CAT] !~ /^F:/ || (!$is_insel && $r->[Strassen::NAME] eq '');
	if ($is_insel) { # Insel abziehen
	    $seen{$last_seen} -= Strassen::area($r)/1_000_000;
	} else {
	    $seen{$r->[Strassen::NAME]} += Strassen::area($r)/1_000_000;
	    $last_seen = $r->[Strassen::NAME];
	}
    }
}

my $str_total_total_len = 0;
{
    my $s = new Strassen "strassen";
    $s->init;
    while(1) {
	my $r = $s->next;
	last if !@{$r->[1]};
	my $total_len = Strassen::total_len($r);
	$str{$r->[Strassen::NAME]} += $total_len/1_000;
	$str_total_total_len += $total_len/1_000;
    }
}


# * Die Auflösung der GIS-Karten ist für eine genaue Flächenberechnung
#   zu gering. Die stadtinfo-Karten reichen aus.
print "Seen:\n";
print join("\n",
	   map { sprintf "%-30s %6.2f km² = %5.f ha",
		   $_, $seen{$_}, $seen{$_}*100
	       } sort { $seen{$b} <=> $seen{$a} } keys %seen), "\n";

print "-" x 70, "\n";
print "Straßen:\n";
print join("\n",
	   map { sprintf "%-40s %6.2f km",
		   $_, $str{$_}
	       } sort { $str{$b} <=> $str{$a} } keys %str), "\n";

printf "Gesamtes Straßennetz: %6.2f km\n", $str_total_total_len;
