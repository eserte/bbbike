# -*- perl -*-

#
# $Id: BBBikeLocalizator.pm,v 1.2 2001/12/09 21:04:16 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
#

warn "Wird nicht verwendet --- besser TelbuchDBApprox oder TelbuchApprox verwenden?";

package BBBikeLocalizator;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

# Achtung: das aufrufende Skript muss use lib $FindBin richtig gesetzt haben

# Argument: PLZ-Objekt
sub new {
    my($class, %args) = @_;
    my $self = {};

    if ($args{-plz}) {
	$self->{PLZ} = $args{-plz};
    } else {
	require PLZ;
	my $plz = PLZ->new;
	$self->{PLZ} = $plz;
    }

    if ($args{-streets}) {
	$self->{Streets} = $args{-streets};
    } else {
	require Strassen;
	my $streets = Strassen->new("strassen");
	$self->{Streets} = $streets;
    }

    if ($args{-crossings}) {
	$self->{Crossings} = $args{-crossings};
    } else {
	require Strassen;
	my $kr = Kreuzungen->new(Strassen => $self->{Streets});
	$kr->make_grid;
	$self->{Crossings} = $kr;
    }

    bless $self, $class;
}

# Eingabe:
#   $city:     Ort
#   $citypart: Bezirk oder Postleitzahl
#   $street:   Straße, evtl. mit Hausnummer
# Ausgabe:
#   Liste von matches als Standard-Koordinaten "$x,$y"
#
sub find_best_matches {
    my $self = shift;
    my $coord = $self->_find_best_matches(@_);
    $coord = ($self->{Crossings}->nearest_coord($coord))[0];
    $coord;
}

sub _find_best_matches {
    my($self, $city, $citypart, $street) = @_;

    return () unless ($city eq 'Berlin'); # z.Zt. wird noch nichts anderes unterstützt

    # grobe Ausnahmen
    if ($street =~ /Im Volkspark Friedrichshain/) {
	return ("12185,13717"); # Kreuzung Am Friedrichshain/Bötzowstr.
    } elsif ($street =~ /Innenhof d. Bethanien/) {
	return ("11961,11055"); # Marienenplatz
    } elsif ($street =~ /Quartier 205/) {
	return ("9410,11803"); # Friedrich/Mohrenstr.
    } elsif ($street =~ /vor der Alten Nationalgalerie/) {
	return ("10045,12685"); # Bodestr.
    } elsif ($street =~ /Im Volkspark Hasenheide/) {
	return ("11108,9194"); # Hasenheide/Graefestr
    }

    my $number;
    ($street, $number) = split_street($street);
    my $coords;
    my $args = join(", ", $street, $citypart, $city);

    my %args;
    $args{Citypart} = $citypart if defined $citypart;
    $args{Agrep}    = 0;
    $args{MultiCitypart} = 1;
    my $pass = 0;
    my @res;

 TRY: {
	require Telefonbuch;
	require Geography::Berlin_DE;

	if (Telefonbuch::exists() &&
	    $Telefonbuch::Telefonbuch->database ne '98') {
	    my $r = $Telefonbuch::Telefonbuch->search_street_hnr($street, $number, "B-$citypart");
	    if ((!$r || !ref $r || !$r->[0]) &&
		$Telefonbuch::Telefonbuch->can('search_street_nearest_hnr')) {
		$r = $Telefonbuch::Telefonbuch->search_street_nearest_hnr($street, $number, "B-$citypart");
	    }
	    if ($r and ref $r and $r->[0]) {
		my @r = @{ $r->[0] };
		if (defined $r[4] and
		    defined $r[5]) {
		    $coords = int($r[4]).",".int($r[5]);
		    last TRY;
		}
	    }

	    warn "NOTE: No tel coords for $args, try from PLZ data...\n";
	}

    PLZTRY: {
	    last PLZTRY if !$self->{PLZ};
	    @res = $self->{PLZ}->look($street, %args);
	    last PLZTRY if @res;

	    my @subcityparts;
	    if (exists Geography::Berlin_DE::citypart_to_subcitypart()->{$citypart}){
		@subcityparts = @{ Geography::Berlin_DE::citypart_to_subcitypart()->{$citypart} };
	    }

	    foreach my $subcitypart (@subcityparts) {
		$args{Citypart} = $subcitypart;
		@res = $self->{PLZ}->look($street, %args);
		last PLZTRY if @res;
	    }

	PLZ2TRY: {
		# the same as above without Citypart constraint
		my(%args) = %args;
		delete $args{Citypart};
		@res = $self->{PLZ}->look($street, %args);
		last PLZ2TRY if @res;
	    }
	}

	if (!@res) {
	    warn "WARN: No coords for $args\n";
	} else {
	    if (@res > 1) {
		warn "Too many coords for $args\n";
	    }
	    $coords = $res[0]->[PLZ::LOOK_COORD()];
	}
    }

    ($coords);
}

# Teilt Straßenname in Straße und Hausnummer auf
# XXX sollte in Strassen.pm definiert sein
sub split_street {
    my $s = shift;
    $s =~ s/\s*\(.*\)$//; # alles in Klammern löschen
    $s =~ s/\s*[\/;].*$//; # alles nach ; und / löschen
    $s =~ s/Kindl-Boul., //; # XXX Sonderfall
    if ($s !~ /^Neue Straße/) { # XXX Neue Straße ist ein Sonderfall
	$s =~ s/Straße/Str./;
    }
    my($name, $nr);
    if ($s =~ /^(.*?)\s+(\S+)$/) {
	$name = $1;
	$nr   = $2;
	if ($nr !~ /^\d/) {
	    $name = $s;
	    $nr   = "";
	} elsif ($nr =~ /^(\d+)\D/) {
	    $nr = $1;
	}
    } else {
	$name = $s;
	$nr   = "";
    }
    ($name, $nr);
}

return 1 if caller();

######################################################################
#
# standalone program
#
package main;
require FindBin;
push @INC, "$FindBin::RealBin/..", "$FindBin::RealBin/../lib";
require Getopt::Long;

my $citypart;
my $city = "Berlin";

if (!Getopt::Long::GetOptions
    ("citypart=s" => \$citypart,
     "city=s"     => \$city,
    )
   ) {
    die "Usage: $0 [-citypart citypart] [-city city] street
Default -city is $city.
";
}

my $street = shift || die "Street?";

my $loc = BBBikeLocalizator->new;
warn $loc->find_best_matches($city, $citypart, $street);

__END__

=head1 NAME

Localizator -

=head1 SYNOPSIS


=head1 DESCRIPTION

=head1 AUTHOR


=head1 SEE ALSO

=cut

