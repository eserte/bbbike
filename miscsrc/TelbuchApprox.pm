# -*- perl -*-

#
# $Id: TelbuchApprox.pm,v 1.12 2003/06/02 23:01:32 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven.rezic@berlin.de
# WWW:  http://www.rezic.de/eserte/
#

# XXX no support for ZipToCitypart like in TelbuchDbApprox.pm

package TelbuchApprox;
use Telefonbuch;
use locale;
use strict;
use Geography::Berlin_DE;
use PLZ;

use vars qw($VERBOSE %exceptions);

sub new {
    my $pkg = shift;
    my $geo = Geography::Berlin_DE->new;
    my $plz = PLZ->new;

    if ($VERBOSE) {
	$PLZ::VERBOSE = 1;
    }

    bless {Geo => $geo,
	   Plz => $plz,
	  }, $pkg;
}

sub split_street {
    my $s = shift;
    my($str, $hnr);
    $s =~ s/^\s+//;
    $s =~ s/\s+$//;
    # split Straße/Hausnummer
    if ($s =~ /((?:Straße|Str\.)\s+\d+)\s+(?:Nr\.|Nummer)\s*(\d+)/) {
	# Straße 635 Nr. 1
	($str, $hnr) = ($1,$2);
    } elsif ($s =~ /(.*?)\b\s*([\d-]+\s?(?:[a-zA-Z]|bis))-(?:[a-zA-Z]|bis)$/) { # same as below, with a-c
	($str, $hnr) = ($1,$2);
    } elsif ($s =~ /(.*?)\b\s*([\d-]+\s?(?:[a-zA-Z]|bis)?)$/) {
	($str, $hnr) = ($1,$2);
    } elsif ($s =~ /(.*\.)([0-9-]+)$/) {
	($str, $hnr) = ($1,$2);
    } else {
	($str, $hnr) = ($s, "");
    }
    if ($hnr =~ m|^(\d+)\s?[-/]\s?\d|) { # "12-14"- oder "12/14"-Hausnummern normieren
	$hnr = $1;
    }
    $str =~ s/\s+$//; # trim again...
    $hnr = uc $hnr; # Hausnummerzahlen sind immer groß (?)
    ($str, $hnr);
}

sub match_plz {
    my($self, $str, $zip, $city_citypart) = @_;
    if ($self->{Plz}) {

	$city_citypart = "" if !defined $city_citypart;
	(my $bezirk = $city_citypart) =~ s/^B-//;

	my @plz_args;
	if (defined $zip && $zip ne '') {
	    push @plz_args, Citypart => $zip, MultiCitypart => 1;
	} elsif ($bezirk ne '') {
	    push @plz_args, Citypart => $bezirk;
	}

	for my $try (0 .. 1) {
	    if ($try == 1) { @plz_args = () }

	    if ($VERBOSE) {
		warn "Try PLZ match <$str> <@plz_args>\n";
	    }

	    my($str,$hnr) = split_street($str);
	    my $plz = $self->{Plz};
	    my @res = $plz->look($str, @plz_args, NoStringApprox => 1);
	    if (@res) {
		return +{Street => $res[0]->[PLZ::LOOK_NAME],
			 Coord  => $res[0]->[PLZ::LOOK_COORD],
			 Nr     => "",
			 City   => 'Berlin',
			 Citypart => $res[0]->[PLZ::LOOK_CITYPART],
			};
	    } else {
		my @res = $plz->look_loop_best($str, @plz_args,
					       Agrep => 'default',
					       LookCompat => 1);
		if (@res) {
		    warn "Approximate match for $str => $res[0]->[PLZ::LOOK_NAME]...\n";
		    return +{Street => $res[0]->[PLZ::LOOK_NAME],
			     Coord  => $res[0]->[PLZ::LOOK_COORD],
			     Nr     => "",
			     City   => 'Berlin',
			     Citypart => $res[0]->[PLZ::LOOK_CITYPART],
			     Fuzzy  => ["Approximate match ($res[0]->[PLZ::LOOK_NAME])"],
			    };
		}
	    }
	}
    }
    ();
}

sub add_exceptions {
    my($self, $hash) = @_;
    %exceptions = (%exceptions, %$hash);
}

sub search {
    my($self, $str, $zip, $city_citypart, %args) = @_;

    my $try_nr = 0;
 TRY: {
	while($try_nr <= 6) {
	    $try_nr++;
	    my $s = $str;
	    my $zip = $zip;
	    my $city_citypart = $city_citypart;
	    next if !defined $s || $s =~ /^\s*$/;
	    if ($try_nr == 2) {
		# Pl. => Platz
		if ($s =~ s|Pl\.\b|Platz | ||
		    $s =~ s|Chauss\.\b|Chaussee |) {
		    # check it...
		} else {
		    next;
		}
	    } elsif ($try_nr == 3) {
		# "/Ecke ..." entfernen.
		# In Zukunft diese Information verwenden!
		if ($s =~ m|^(.*)\s*/\s*Ecke\s+|) {
		    $s = $1;
		} else {
		    next;
		}
	    } elsif ($try_nr == 4) {
		# "/..." entfernen
		if ($s =~ m|^(.*)\s*/|) {
		    $s = $1;
		} else {
		    next;
		}
	    } elsif ($try_nr == 5) {
		# "n[aä]he ..." entfernen
		if ($s =~ m|^(.*),?\s+n[aä]he|i) {
		    $s = $1;
		} else {
		    next;
		}
	    } elsif ($try_nr == 6) {
		# nur erstes Wort verwenden
		if ($s =~ m|^(\w+)|) {
		    $s = $1;
		    if ($s =~ /^(Platz|Str|Str\.|Straße|Allee)$/) {
			# Primitivkonstrukt nicht verwenden
			next;
		    }
		} else {
		    next;
		}
	    } elsif ($try_nr == 7) {
#XXX no, too dangerous to get streets in other cities
#		undef $zip;
#		undef $city_citypart;
	    } elsif ($try_nr > 1) {
		die "Invalid \$try_nr: $try_nr";
	    }
	    warn "Try $try_nr <$s> <$str> <$zip> <$city_citypart>\n"
		if $VERBOSE;
	    my($str,$hnr) = split_street($s);
	    # Verwendung von Telefonbuch98/99
	    Telefonbuch::exists();
	    # XXX check this! (syntactically)
	    my $coord;
	    if (exists $exceptions{$str} and
		exists $exceptions{$str}->{$hnr}) {
		$coord = $exceptions{$str}->{$hnr};
	    } else {
		next if length $str < 3;
		my $zip_data;
		if ($Telefonbuch::Telefonbuch->database eq '98') {
		    $zip_data = $zip;
		} elsif (defined $city_citypart) { # 99
		    my($city, $bezirk);
		    if ($city_citypart =~ /^([A-Z]{1,3})-(.*)/) {
			($city, $bezirk) = ($1, $2);
			next if $city ne 'B'; # andere sind (noch) nicht unterstützt
		    } else {
			$city = 'B';
			$bezirk = $city_citypart;
		    }
		    if ($self->{Geo}->subcitypart_to_citypart->{$bezirk}) {
			$bezirk = $self->{Geo}->subcitypart_to_citypart->{$bezirk};
		    }
		    #warn "$city --- $bezirk ($str $zip $city_citypart)\n";
		    $zip_data = "$city-$bezirk";
		} elsif ($zip && $self->{Geo} && $self->{Plz}) {
		    my @res = $self->{Plz}->look_loop_best
			($str, Citypart => $zip, MultiCitypart => 1,
			 Agrep => 'default',
			 LookCompat => 1);
		    if (@res) {
			my $bezirk = $res[0]->[PLZ::LOOK_CITYPART];
			if ($self->{Geo}->subcitypart_to_citypart->{$bezirk}) {
			    $bezirk = $self->{Geo}->subcitypart_to_citypart->{$bezirk};
			}
			$zip_data = "B-$bezirk";
		    }
		    if (!defined $zip_data) {
			warn "Can't find citypart information for $str/$zip\n";
		    }
		}
		my $res;
		my $get_coord = sub {
		    my $arg = shift || $res->[0];
		    my(@res) = @{ $arg };
		    if (defined $res[4] and
			defined $res[5]) {
			$coord = int($res[4]).",".int($res[5]);
		    }
		};
		$res = $Telefonbuch::Telefonbuch->search_street_hnr
		       ($str, $hnr, $zip_data);
		if ($res and ref $res and $res->[0]) {
		    $get_coord->();
		} else {
		    $res = $Telefonbuch::Telefonbuch->search_street_hnr
			   ($str, undef, $zip_data);
		    if ($res and ref $res and $res->[0]) {
			# find the nearest Hausnummer
			my $best = $res->[0];
			local $^W = 0; # because of numbers with letters
			my $best_min = abs($res->[0][1]-$hnr);
			foreach my $arg (@$res) {
			    my $this_min = abs($arg->[1]-$hnr);
			    if ($best_min > $this_min) {
				$best_min = $this_min;
				$best = $arg;
			    }
			}
			$get_coord->($best);
		    } else {
#XXX no --- this one is too dangerous
#  			$res = $Telefonbuch::Telefonbuch->search_street_hnr
#  			    ($str, undef, undef);
#  			if ($res and ref $res and $res->[0]) {
#  			    $get_coord->();
#  			}
		    }
		}
	    }
	    if (defined $coord) {
		return +{
			 Street => $str,
			 Coord  => $coord,
			 Nr     => $hnr,
			};
	    }
	}

	my(@res) = $self->match_plz($str, $zip, $city_citypart);
	return @res if @res;

	{
	    my $zip = $zip || "";
	    my $city_citypart = $city_citypart || "";
	    warn "Nicht erkannt: <$str> <$zip> <$city_citypart>\n";
	}
    }
    undef;
}

1;

__END__
