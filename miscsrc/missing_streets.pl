#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: missing_streets.pl,v 1.6 2009/01/18 21:53:15 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2008 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use Getopt::Long;

use PLZ;
use Strassen::Core;

my $incl_fragezeichen = 1;
GetOptions("fz!" => \$incl_fragezeichen)
    or die "usage: $0 [-[no]fz]";

my %seen_street_with_bezirk;
my %seen_street;

my $s = Strassen->new("$FindBin::RealBin/../data/strassen"); # includes plaetze-orig
if ($incl_fragezeichen) {
    my $fz = Strassen->new("$FindBin::RealBin/../data/fragezeichen-orig"); # use -orig, because known unconnected streets are missing in non-orig
    $fz->init;
    while(1) {
	my $r = $fz->next;
	my $c = $r->[Strassen::COORDS];
	last if !@$c;
	$r->[Strassen::NAME] =~ s{:.*}{};
	$s->push($r);
    }
}

$s->init;
while(1) {
    my $r = $s->next;
    my $c = $r->[Strassen::COORDS];
    last if !@$c;
    my($name, $bezirk) = $r->[Strassen::NAME] =~ m{^(.*)\s+\((.*)\)$};
    if (defined $name) {
	my @bezirk = split /\s*,\s*/, $bezirk;
	for my $bezirk (@bezirk) {
	    $seen_street_with_bezirk{$name}->{$bezirk}++;
	}
    } else {
	$seen_street{$r->[Strassen::NAME]}++;
    }
}

my %missing_by_bezirk;

my $plz = PLZ->new;
$plz->load;
foreach my $rec (@{ $plz->{Data} }) {
    my($str, $bezirk) = ($rec->[PLZ::FILE_NAME],
			 $rec->[PLZ::FILE_CITYPART],
			);
    next if $str =~ m{^[SU]-Bhf\s}; # later XXX
    next if $str =~ m{^Güterbahnhof\s}; # later XXX
    next if $str =~ m{\(Gaststätte\)}; # later XXX
    next if $str =~ m{\(Kolonie\)}; # later XXX
    next if $str =~ m{\(Siedlung\)}; # later XXX
    next if $str =~ m{^Kolonie\s}; # later XXX
    next if $str =~ m{^Siedlung\s}; # later XXX
    next if $str =~ m{^Wochenendsiedlung\s}; # later XXX
    next if $str =~ m{^KGA\s}; # later XXX
    next if $str =~ m{^(Modersohnbrücke
		      |Heinrich-von-Kleist-Park # Schöneberg
		      |Englischer[ ]Garten # Tiergarten
		      |Humboldthafen
		      |Schloß[ ]Bellevue
		      |Westhafen
		      |Eichgestell # Oberschöneweide, exists as "(...)"
		      |Waldfriedhof[ ]Oberschöneweide # Oberschöneweide
		      |Wasserwerk[ ]an[ ]der[ ]Wuhlheide
		      |Abstellbahnhof # Grunewald
		      |Hundekehle
		      |Jagdschloß[ ]Grunewald
		      |Lindwerder
		      |Wasserwerk[ ]Teufelssee
		      |Melli-Besse-Str. # Adlershof --- Ring oder Straße; Lage vollkommen unklar
		      |Ernst-Reuter-Siedlung # Wedding --- keine Straße hier zu erkennen
		      |Humboldthain # Wedding
		      |Albrechts[ ]Teerofen # Wannsee
		      |Landgut[ ]Eule # Ist das eine Straße?
		      |Glienicker[ ]Park
		      |Im[ ]Jagen # sieht uninteressant aus
		      |Moorlake
		      |Nikolskoe
		      |Pfaueninsel
		      |Schäferberg
		      |Siedlung[ ]10 # Baumschulenweg
		      |Am[ ]Sportplatz # Buch
		      |Britzer[ ]Hafen # Britz
		      |Am[ ]Bahnhof[ ]Grunewald[ ]Vorplatz[ ]II # Charlottenburg
                      |Avus[ ]Innenraum
		      |Avus[ ]Nordkurve
		      |DRK[ ]Kliniken
		      |Europa-Center
		      |Rudolf-Virchow-Krankenhaus
		      |Schleuse[ ]Charlottenburg
		      |Schleuse[ ]Plötzensee
		      |Schleuseninsel[ ]im[ ]Tiergarten
		      |Sportplatz[ ]Eichkamp
		      |Sportplatz[ ]Kühler[ ]Weg
		      |Sportplatz[ ]Maikäferpfad
		      |Volkspark[ ]Jungfernheide
		      |Waldbühne
		      |Löwe-Siedlung
		      |Jagen[ ]59 # Grünau
		      |Waldfriedhof[ ]Grünau
		      |AEG[ ]Siedlung[ ]I,[ ]II # Lübars
		      |Karpfenteich-Wald
		      |Stadtrandsiedlung # Mariendfelde
		      |Anglerweg # Schmöckwitz (auf der RV-Karte als "Schmöckwitzwerder Süd (Anglerweg)" gekennzeichnet
		      |Schmöckwitzwerder[ ]Süd # siehe Anglerweg
		      |Deutscher[ ]Camping[ ]Club[ ]Krossinsee
		      |Forstweg # keine eindeutige Referenzen
		      |Jagen[ ]17[ ]-[ ]20
		      |Jagen[ ]23
		      |Jagen[ ]25
		      |Jagen[ ]33
		      |Jagen[ ]37
		      |Schmöckwitzwerder[ ]Nord
		      |Gutshof[ ]Glienicke # Kladow
		      |Habichtsgrund
		      |Habichtswald
		      |Havelfreunde # Wochenendsiedlungen
		      |Havelwiese # Kolonie
		      |Hottengrund # Kaserne
		      |Badewiese # Gatow
		      |Breitehorn
		      |Flugplatz[ ]Gatow
		      |Ruprecht
		      |Triftweg
		      |Straße[ ]1[ ]\(Wiesengrund\) # Karlshorst
		      |Behelfsheimsiedlung # Name der Siedlung zwischen Waldowallee und Köpenicker Allee
		      |Am[ ]Elektrizitätswerk # nirgendwo gefunden
		      |Am[ ]Hochwald # nirgendwo gefunden
		      |Erholung # nicht in Karlshorst gefunden
		      |Gartenfreunde[ ]Bahnhof[ ]Wuhlheide # nirgendwo gefunden
		      |Kleckersdorfer[ ]Weg # nirgendwo gefunden
		      |Stallwiesen # nirgendwo gefunden
		      )$}x; # decide later (non-strassen, e.g. brunnels or parks) XXX
    if (exists $seen_street_with_bezirk{$str}->{$bezirk}) {
    } elsif (exists $seen_street{$str}) {
    } else {
	push @{ $missing_by_bezirk{$bezirk} }, $str;
    }
}

#use BBBikeYAML qw(Dump);
binmode STDOUT, ':encoding(iso-8859-1)';
for my $key (sort { scalar(@{$missing_by_bezirk{$a}}) <=> scalar(@{$missing_by_bezirk{$b}}) } keys %missing_by_bezirk) {
    print "$key (" . scalar(@{$missing_by_bezirk{$key}}) . ")\n";
    for my $str (@{ $missing_by_bezirk{$key} }) {
	print "  $str\n";
    }
    print "\n";
#    my %dump_hash = ("$key (" . scalar(@{$missing_by_bezirk{$key}}) . ")" => $missing_by_bezirk{$key});
#    print Dump(\%dump_hash);
}
#print Dump(\%missing_by_bezirk);
#require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([\%missing_by_bezirk],[qw()])->Indent(1)->Useqq(1)->Dump; # XXX

__END__

=pod

Show number of missing streets per bezirk:

     ./missing_streets.pl | grep '^[A-Z]' | sort

=cut
