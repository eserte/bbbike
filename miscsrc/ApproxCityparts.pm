#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: ApproxCityparts.pm,v 1.2 2001/11/05 21:55:03 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven.rezic@berlin.de
# WWW:  http://www.rezic.de/eserte/
#

# try to match (Berlin) cityparts

package ApproxCityparts;
use String::Approx;
use strict;

sub new {
    my($class, %args) = @_;
    my $self = {Geo => $args{-geo}};

    if ($args{-geo} eq 'Geography::Berlin_DE') {
	require Geography::Berlin_DE;
	my %s1 = map {($_=>1)} Geography::Berlin_DE::subcityparts();
	my %s2 = map {($_=>1)} Geography::Berlin_DE::cityparts();
	my %s = (%s1,%s2);
	my @s = sort keys %s;
	$self->{Cityparts} = \@s;
	$self->{CitypartsHash} = \%s;
    } else {
	die "-geo argument missing or not recognized";
    }

    bless $self, $class;
}

sub search {
    my($self, $test) = @_;

    my @ret;

    if (exists $self->{CitypartsHash}{$test}) {
	@ret = ($test, 'exact');
    } else {
	my($test_rx) = $test;
	$test_rx =~ s/[\.\']//g;
	my $rx = join(".*", split //, $test_rx);
	my @matches;
	foreach my $test2 (@{$self->{Cityparts}}) {
	    if ($test2 =~ /$rx/i) {
		push @matches, $test2;
	    }
	}
	if (!@matches) {
	    # no matches ... try String::Approx
	TRY: {
		foreach my $errors (1..5) {
		    @matches = String::Approx::amatch($test, [$errors,'i'],
						      @{$self->{Cityparts}});
		    if (@matches == 1) {
			@ret = ($matches[0], 'single approx match @ '.$errors.' err');
			last TRY;
		    } elsif (@matches > 1) {
			my($shortest) = (sort { length($a) <=> length($b) } @matches)[0];
			@ret = ($shortest, 'multi approx match @ '.$errors.' err');
			last TRY;
		    }
		}
		@ret = (undef, 'no match');
	    }
	} elsif (@matches == 1) {
	    @ret = ($matches[0], 'single match');
	} else {
	    my($shortest) = (sort { length($a) <=> length($b) } @matches)[0];
	    @ret = ($shortest, 'multi match');
	}
    }

    if (wantarray) {
	@ret;
    } else {
	$ret[0];
    }
}

return 1 if caller;

package main;

require Getopt::Long;

my $do_test;
if (!Getopt::Long::GetOptions("test" => \$do_test)) {
    die "usage";
}

if ($do_test) {
    push @INC, ".."; # for Geography::Berlin_DE

    my @testdata = split /\n/, <<'EOF';
Adlershof
Altglienicke
Baumschulenweg
Biesdorf
Blankenburg
Blankenfelde
Britz
Buch
Buckow
Charl.
Charl.-Nord
Charl.burg
Charlott.
Charlott.-Nord
Charlottenb.
Charlottenb.-Nord
Charlottenburg
Charlottenburg-Nord
Dahlem
Franz.Buchholz
Fri'hain
Friedenau
Friedrichsfelde
Friedrichshagen
Friedrichshain
Frohnau
Frz.Buchholz
Gatow
Gesundbr.
Gesundbrunnen
Grünau
Grunewald
Hansaviertel
Haselhorst
Heiligensee
Heinersdorf
Hellersdorf
Hermsdorf
Hohenschönhausen
Hohenschönhsn
Johannisthal
Karlshorst
Karow
Kaulsdorf
Kladow
Köpenick
Kreuzberg
Lankwitz
Lichtenberg
Lichtenrade
Lichterfelde
Lübars
Mahlsdorf
Malchow
Mariendorf
Marienfelde
Märk.Viertel
Märkisches Viertel
Marzahn
Mitte
Moabit
Müggelheim
Neukölln
Niederschönhausen
Niederschönhsn
Nikolassee
Pankow
Prenzl.Berg
Prenzl.Bg
Prenzlauer Berg
Prenzlauer Bg
Rahnsdorf
Rein.
Reinickendorf
Rosenthal
Rudow
Schmargendorf
Schmöckwitz
Schöneberg
Schöneberg-Nord
Schönebg-Nord
Siemensstadt
Spandau
Staaken
Steglitz
Tegel
Tempelhof
Tierg
Tierg.
Tiergarten
Tiergarten-Süd
Treptow
Waidmannslust
Wannsee
Wartenberg
Wedding
Weißensee
Wilmersd
Wilmersdf
Wilmersdorf
Wílmersdorf
Wittenau
Zehlendorf
EOF
#'

    my $ap = ApproxCityparts->new(-geo => 'Geography::Berlin_DE');

    my $longest_testdata = length((sort { length($b) <=> length($a) } @testdata)[0]);
    my $longest_result   = length((sort { length($b) <=> length($a) } @{$ap->{Cityparts}})[0]);

    foreach my $s (@testdata) {
	my($res, $exact) = $ap->search($s);
	warn sprintf("%-".$longest_testdata."s => %-".$longest_result."s ($exact)\n", $s, $res);
    }
}


__END__
