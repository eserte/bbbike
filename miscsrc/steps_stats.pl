#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2009 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib "$FindBin::RealBin/..";

use Strassen::Core;

my $times_expr = qr{(\d+)\s*x\s*(\d+)};
my $plus_expr = qr{\d+\s*(?:\+\s*\d+)+};

my $file = shift || "$FindBin::RealBin/../data/gesperrt";

my @res;
my @steps_without_count;
Strassen->new_stream($file)->read_stream
    (sub {
	 my $r = shift;
	 return if $r->[Strassen::CAT] !~ m{^0};
	 if (my($steps) = $r->[Strassen::NAME] =~ m{(\d+|$times_expr|$plus_expr)\s+Stufe}) {
	     if ($steps =~ $times_expr) {
		 $steps = $1 * $2;
	     } elsif ($steps =~ $plus_expr) {
		 my($total_steps) = $steps =~ s{^(\d+)}{};
		 while($steps =~ m{\s*\+\s*(\d+)}g) {
		     $total_steps += $1;
		 }
		 $steps = $total_steps;
	     } # else $steps
	     if (my($time) = $r->[Strassen::CAT] =~ m{0:(\d+)}) {
		 push @res, [$time/$steps, $steps, $time, $r];
	     }
	 } elsif ($r->[Strassen::NAME] =~ m{treppe}i) {
	     my($time) = $r->[Strassen::CAT] =~ m{0:(\d+)};
	     push @steps_without_count, [$time, $r];
	 }
     });

@steps_without_count = sort { $b->[0] <=> $a->[0] } @steps_without_count;
print "Steps without count:\n" . join("\n", map { join("\t", $_->[0], $_->[1]->[Strassen::NAME]) } @steps_without_count), "\n";
print "-"x70,"\n";

@res = sort { $b->[0] <=> $a->[0] } @res;
print join("\n", map { join("\t", @{$_}[0,1,2], $_->[3]->[Strassen::NAME]) } @res), "\n";

__END__

=pod

   Daten:

   * Spreetunnel oben auf der Treppe zwischen 12:09:44 und 12:09:59
     unten ca. 12:10:17 oder so
     wieder oben auf der anderen Seite 12:12:03
     50+50 Stufen, unten im Tunnel 5 km/h (bei ca. 100m entspricht 72
     Sekunden)
     insgesamt also ca. 2:30 min verloren, davon 78 Sekunden beim
     Treppensteigen
     entspricht also 0.78 Sekunden/Stufe ~ 1s/Stufe

   * Laut DIN-Norm 18065 beträgt die Steigung ~20cm. Laut
     http://de.wikipedia.org/wiki/Spreetunnel_Friedrichshagen müssten
     die Treppen 8.4m+1.5m=9.9m überwinden --- kommt ziemlich gut hin!
     Mein GPS-Empfänger hat übrigens als tiefsten Punkt 27m angezeigt,
     oben waren es ca. 35m, also hier nur ein Unterschied von 8m.

   * Treppe am Rolandufer, 26 Stufen am
     2005-06-25, wahrscheinlich mit Kind im Kindersitz: für die
     Treppe brauchte ich geschätzte 40 Sekunden, Kind blieb
     wahrscheinlich drinnen. -> 1.5s/Stufe

   * Elsenbrücke: ca. 2 x 15 Stufen, insgesamt 60 Meter, im Mittel
     verlorene Zeit 35 Sekunden. Bei 20 km/h hätte man es in ca. 10
     Sekunden geschafft -> 0.83 Sekunden/Stufe

   * Sasarsteig: mehrere Treppen, insgesamt 25 Stufen, im Mittel
     verlorene Zeit 50 Sekunden. Bei 20 km/h hätte man es in ca. 21
     Sekunden geschafft -> 0.6 Sekunden/Stufe. Kein Unterschied beim
     Hoch/Runterfahren.

   * Mühsamstr. 40 Meter, 34 Sekunden, unbekannte Anzahl von Stufen.
     Bei 20 km/h hätte man 7 Sekunden dafür gebraucht.

=cut
