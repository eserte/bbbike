#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: ampelschaltung.pl,v 1.9 2007/06/21 19:44:27 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

use strict;
use Getopt::Long;
use Text::Tabs;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data",
	 "$FindBin::RealBin/../misc");
use Ampelschaltung;

$Ampelschaltung::warn = 0;

my $old_ampelschaltung = 0;
my $file;
my $speed = 20;
my $a = 1;
my $array = 0;
my $average = 0;
my $a1 = 1;
my $a2 = 1;
my $table = 0;
my $do_verkehrszeit = 1;
my $bbd;

GetOptions("file=s"           => \$file,
	   "speed=i"          => \$speed,
	   "beschleunigung=f" => \$a,
	   "average!"         => \$average,
	   "array!"           => \$array,
	   "a1!"              => \$a1, # entspricht Ampelschaltung
	   "a2!"              => \$a2, # entspricht Ampelschaltung2
	   "table!"           => \$table,
	   "verkehrszeit!"    => \$do_verkehrszeit,
	   "bbd=s"            => \$bbd,
	  );

if ($old_ampelschaltung && defined $file) { # XXX obsolet, kann gelöscht werden
    my $data = 0;
    my $n = 0;
    my $warte_zeit = 0;
    my $warte_strecke = 0;
    open(F, $file) or die $!;
    while(<F>) {
	chomp;
	if (/^---/)   { $data = 1 }
	elsif (/^\s/) { next }
	elsif (/^$/)  { next }
	elsif ($data) {
	    my $l = expand($_);
	    next if length($l) < 58;
	    my($gruen, $rot) = (substr($l, 47, 3), substr($l, 55, 3));
	    if ($gruen =~ /\d/ && $rot =~ /\d/) {
		my %res = Ampelschaltung::lost(-gruen => $gruen,
					       -rot   => $rot,
					       -geschwindigkeit => $speed,
					       -beschleunigung => $a);
		$warte_zeit += $res{-zeit};
		$warte_strecke += $res{-strecke};
		$n++;
	    }
	}
    }
    close F;

    if ($n) {
	printf "Durchschnittlich verlorene Zeit: %.1f s\n", $warte_zeit/$n;
	printf "Verlorene Strecke bei %d km/h: %d m\n",
	$speed, $warte_strecke/$n;
    }

} elsif ($array) {

    my %res;

    my @a = qw(0.5 1 1.5 2);
    my @speed = qw(10 15 20 25 30);

    foreach my $a (qw(title bar), @a) {
	foreach my $speed (@speed) {
	    if ($table) {
		if ($a eq 'title') {
		    printf "%6d ", $speed;
		} elsif ($a eq 'bar') {
		    print "-------";
		}
	    }
	    if ($a =~ /^\d/) {
		my %res = average_lost(undef, $speed, $a);
		if ($table) {
		    printf "%6.2f ", $res{-strecke};
		} else {
		    # Ausgabe für perl:
		    # $lost->{geschwindigkeit}{beschleunigung} = 
		    #   [verlorene_zeit, verlorene_strecke];
		    print '$lost->{' . $speed . '}{' . $a . '} = [' . 
		      sprintf("%.2f", $res{-zeit}) . ', ' .
			sprintf("%.2f", $res{-strecke}) . '];' . "\n";
		}
	    }
	}
	print "\n" if $table;
    }

} elsif ($average) {

    my %res = average_lost($file, $speed, $a);
    if (defined $res{-zeit}) {
	print "Durchschnittsberechnung (" . $res{"-n"} . " Werte)\n";
	printf "Verlorene Zeit:    %.2f s\n", $res{-zeit};
	printf "Verlorene Strecke: %.2f m\n", $res{-strecke};
	if ($do_verkehrszeit) {
	    foreach my $k (keys %res) {
		next if $k !~ /^-zeit_(.*)/;
		my $verkehrszeit = $1;
		print
		  "Im " . ucfirst($verkehrszeit) . 
		    " (" . $res{"-n_$verkehrszeit"} . " Werte)\n";
		printf("Verlorene Zeit:    %.2f s\n",
		       $res{"-zeit_$verkehrszeit"});
		printf("Verlorene Strecke: %.2f m\n",
		       $res{"-strecke_$verkehrszeit"});
	    }
	}
    }

} elsif ($bbd) {
    process_bbd($bbd);
} else {

    my($gruen, $rot) = (shift, shift);
    if (!defined $gruen or !defined $rot) {
	die "Usage: $0 gruenphase rotphase [geschwindigkeit]
Phasen in Sekunden,
Geschwindigkeit in km/h.
Beschleunigung: $a m/s²
";
    }

    my $kmh = shift;

    my %res = Ampelschaltung::lost(-gruen => $gruen,
				   -rot   => $rot,
				   -geschwindigkeit => $kmh,
				   -beschleunigung => $a);

    printf "Durchschnittlich verlorene Zeit: %.1f s\n", $res{-zeit};
    if (defined $res{-strecke}) {
	printf
	  "Durchschnittlich verlorene Strecke bei $kmh km/h: %d m\n",
	  $res{-strecke};
    }
}

# berechnet die durchschnittlichen Verlustzeiten für die Daten
# aus Ampelschaltung und Ampelschaltung2
sub average_lost {
    my($file, $speed, $a) = @_;

    my @args;
    push @args, File => $file if (defined $file);

    # Statistik
    my %lost_time;
    my %lost_way;
    my %n;
    
    my @mods;
    push @mods, 'Ampelschaltung'  if $a1;
    push @mods, 'Ampelschaltung2' if $a2;

    foreach my $mod (@mods) {
	my $amp = $mod->new(@args);
	die "Can't open file for $amp" if !$amp->open;
	foreach my $p (@{ $amp->{Data} }) {
	    my %point_lost_time;
	    my %point_lost_way;
	    my %point_n;

	    foreach my $e ($p->entries) {
		my $verkehrszeit;
		my($day, $time) = ($e->{Day}, $e->{Time});
		if (defined $day  and $day ne "" and
		    defined $time and $time ne "") {
		    $verkehrszeit = Ampelschaltung::verkehrszeit($day, $time);
		}
		my %res = $e->lost(-geschwindigkeit => $speed,
				   -beschleunigung => $a,
				  );
		if (defined $res{-zeit}) {
		    $point_lost_time{Gesamt} += $res{-zeit};
		    $point_lost_way{Gesamt}  += $res{-strecke};
		    $point_n{Gesamt}++;

		    if (defined $verkehrszeit) {
			$point_lost_time{$verkehrszeit} += $res{-zeit};
			$point_lost_way{$verkehrszeit}  += $res{-strecke};
			$point_n{$verkehrszeit}++;
		    }
		}
	    }
	    foreach my $k (keys %point_n) {
		if ($point_n{$k}) {
		    $lost_time{$k} +=
		      ($point_lost_time{$k}/$point_n{$k});
		    $lost_way{$k} +=
		      ($point_lost_way{$k}/$point_n{$k});
		    $n{$k}++;
		}
	    }
	}
    }

    my %res;
    if ($n{Gesamt}) {
	$res{"-zeit"}    = $lost_time{Gesamt}/$n{Gesamt};
	$res{"-strecke"} = $lost_way{Gesamt}/$n{Gesamt};
	$res{"-n"}       = $n{Gesamt};
    }

    foreach my $k (keys %n) {
	next if $k eq 'Gesamt';
	$res{"-zeit_" . $k}    = $lost_time{$k}/$n{$k};
	$res{"-strecke_" . $k} = $lost_way{$k}/$n{$k};
	$res{"-n_" . $k}       = $n{$k};
    }

    %res;
}

# Example usage:
#  ./miscsrc/ampelschaltung.pl -speed 25 -bbd misc/ampelschaltung_rules.bbd > /tmp/l.bbd
sub process_bbd {
    my $file = shift;
    require Strassen::Core;
    my $s = Strassen->new($file);
    my $new_s = Strassen->new;
    while() {
	my $r = $s->next;
	last if !@{ $r->[Strassen::COORDS()] };
	if ($r->[Strassen::NAME()] =~ m{red=(\d+)s(?:\(.*?\))? green=(\d+)s(?:\(.*?\))?}) {
	    my %lost_res = Ampelschaltung::lost(-rot => $1, -gruen => $2,
						-geschwindigkeit => $speed,
						-beschleunigung => $a,
					       );
	    $new_s->push(["lost=" . sprintf("%ds", $lost_res{-zeit}) . " $r->[Strassen::NAME()]", $r->[Strassen::COORDS()], $r->[Strassen::CAT()]]);
	}
    }
    print <<EOF;
# Speed: $speed km/h
# Accel: $a m/s2
#
EOF
    $new_s->write("-");
}

__END__
