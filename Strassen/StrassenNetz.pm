# -*- perl -*-

#
# $Id: StrassenNetz.pm,v 1.60 2008/12/31 12:26:33 eserte Exp $
#
# Copyright (c) 1995-2003 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package Strassen::StrassenNetz;

=head1 NAME

Strassen::StrassenNetz - net creation and route searching routines

=head1 SYNOPSIS

    $net = StrassenNetz->new($strassen);
    $net->make_net;
    $net->search(...)

=head1 DESCRIPTION

=head2 METHODS

=cut

$VERSION = sprintf("%d.%02d", q$Revision: 1.60 $ =~ /(\d+)\.(\d+)/);

package StrassenNetz;
use strict;
# XXX StrassenNetzLite?
#use AutoLoader 'AUTOLOAD';
use BBBikeUtil qw(schnittwinkel m2km min max);
use BBBikeCalc;
BEGIN {@StrassenNetz::EXPORT_OK = qw($VERBOSE $data_format
				     $FMT_HASH $FMT_ARRAY $FMT_CDB $FMT_MMAP)}
use vars @StrassenNetz::EXPORT_OK;

$FMT_HASH  = 1;
$FMT_ARRAY = 2;
$FMT_CDB   = 3;
$FMT_MMAP  = 4;

$VERBOSE     = 0         if !defined $VERBOSE;
$data_format = $FMT_HASH if !defined $data_format;

require Strassen::Cat;
require Strassen::Generated;

use vars qw($AUTOLOAD);
sub AUTOLOAD {
    warn "Loading Strassen::StrassenNetzHeavy for $AUTOLOAD ...\n"
	if $VERBOSE;
    require Strassen::StrassenNetzHeavy;
    if (defined &$AUTOLOAD) {
	goto &$AUTOLOAD;
    } else {
	die "Cannot find $AUTOLOAD in ". __PACKAGE__;
    }
}

=head2 new($strassen)

Construct a new C<Strassen::StrassenNetz> object. The supplied
argument should be a C<Strassen> object.

=cut

sub new {
    my($class, $strassen) = @_;
    die "argument 1 is not of type Strassen"
	if !$strassen->isa('Strassen') && !$strassen->isa('Strassen::Storable');
    my $self = {};
    $self->{Strassen} = $strassen;
    bless $self, $class;
}

# verwendet entweder new_from_server (wenn nicht NoNewFromServer spezifiziert
# wurde) oder new
# XXX einheitliches Mapping strassen/multistrassen => shareable object
# XXX $class vs. __PACKAGE__?
### AutoLoad Sub
sub new_from_best {
    my($class, %args) = @_;
    my $net;
    $net = __PACKAGE__->new_from_server
	unless $args{NoNewFromServer};
    if (!$net) {
	die "Missing Strassen parameter" if !$args{Strassen};
	$net = __PACKAGE__->new($args{Strassen});
	if ($args{OnCreate}) {
	    my $meth = $args{OnCreate};
	    $meth->($net);
	}
    }
    $net;
}

sub get_cachefile {
    my $self = shift;
#XXX del:
#     require File::Basename;
#     my(@src) = $self->dependent_files;
#     my $cachefile = join("_", map { File::Basename::basename($_) } @src);
#     $cachefile;
    $self->id;
}

# Markiert die angegebenen Objekte als Quell-Objekte für dieses StrassenNetz
# Im Gegensatz dazu müssen dependent_files nicht unbedingt die direkten
# Quellen sein.
# Returns nothing meaningful
### AutoLoad Sub
sub source {
    my($self, @source) = @_;
    push(@{$self->{Source}}, @source);
}

# Markiert die angegebenen Straßen-Abkürzungen als Quell-Objekte für
# dieses StrassenNetz
# Returns nothing meaningful
### AutoLoad Sub
sub source_abk {
    my($self, @source_abk) = @_;
    push(@{$self->{SourceAbk}}, @source_abk);
}

### AutoLoad Sub
sub is_source {
    my($self, $source) = @_;
    foreach (@{$self->{Source}}) {
	return 1 if $_ eq $source;
    }
    0;
}

# gibt die zugehörigen Quellobjekte aus
### AutoLoad Sub
sub sourceobjects {
    my $self = shift;
    if (exists $self->{Source} && @{$self->{Source}}) {
	@{$self->{Source}};
    } else {
	$self->{Strassen};
    }
}

# gibt die zugehörigen Quelldateien aus
### AutoLoad Sub
sub sourcefiles {
    my $self = shift;
    my %src;
    for my $obj ($self->sourceobjects) {
	for my $file ($obj->file) {
	    $src{$file}++;
	}
    }
    sort keys %src;
}

sub dependent_files {
    my $self = shift;
    $self->{Strassen}->dependent_files;
}

sub id {
    my $self = shift;
    $self->{Strassen}->id;
}

if (!defined &make_net) {
    *make_net = \&make_net_slow_1;
    *net_read_cache = \&net_read_cache_1;
    *net_write_cache = \&net_write_cache_1;
}
*make_net_classic = \&make_net_slow_1;

use enum qw(:WIDE_ NEIGHBOR1 DISTANCE1 NEIGHBOR2 DISTANCE2);

use constant BLOCKED_ONEWAY   => 1;
use constant BLOCKED_ONEWAY_STRICT => "1s";
use constant BLOCKED_COMPLETE => 2;
use constant BLOCKED_CARRY    => 0;
use constant BLOCKED_ROUTE    => 3;
use constant BLOCKED_NARROWPASSAGE => "BNP";

# $sperre_file may also be a Strassen object
### AutoLoad Sub
sub make_sperre_1 {
    my($self, $sperre_file, %args) = @_;

    my $del_token = $args{DelToken};
    my $special_vehicle = $args{SpecialVehicle} || '';

    my %sperre_type;
    if (exists $args{Type}) {
	$args{Type} = [$args{Type}] unless ref $args{Type} eq 'ARRAY';
	foreach (@{$args{Type}}) {
	    if ($_ eq 'einbahn') {
		$sperre_type{&BLOCKED_ONEWAY} = 1;
	    } elsif ($_ eq 'einbahn-strict') {
		$sperre_type{&BLOCKED_ONEWAY_STRICT} = 1;
	    } elsif ($_ eq 'sperre') {
		$sperre_type{&BLOCKED_COMPLETE} = 1;
	    } elsif ($_ eq 'tragen') {
		$sperre_type{&BLOCKED_CARRY} = 1;
	    } elsif ($_ eq 'wegfuehrung') {
		$sperre_type{&BLOCKED_ROUTE} = 1;
	    } elsif ($_ eq 'narrowpassage') {
		$sperre_type{&BLOCKED_NARROWPASSAGE} = 1;
	    } elsif ($_ eq 'all') {
		for (BLOCKED_ONEWAY, BLOCKED_ONEWAY_STRICT,
		     BLOCKED_COMPLETE, BLOCKED_CARRY, BLOCKED_ROUTE,
		     BLOCKED_NARROWPASSAGE) {
		    $sperre_type{$_} = 1;
		}
	    } else {
		$sperre_type{$_} = 1;
	    }
	}
    } else {
	%sperre_type = (&BLOCKED_COMPLETE => 1,
			&BLOCKED_ONEWAY   => 1); # Standard: einbahn und sperre
    }

    my $sperre_obj;
    if (UNIVERSAL::isa($sperre_file, "Strassen")) {
	$sperre_obj = $sperre_file;
    } else {
	require Strassen::Core;
	$sperre_obj = new Strassen $sperre_file;
    }
    $sperre_obj->init;
    while(1) {
	my $ret = $sperre_obj->next;
	last if !@{$ret->[Strassen::COORDS()]};
	my($category,$penalty,@addinfo) = split /:/, $ret->[Strassen::CAT()];

	# Fix penalty or propagate to other category for special
	# vehicles, currently only for BNP and CARRY:
	if ($special_vehicle ne '') {
	    if ($category eq BLOCKED_NARROWPASSAGE) {
		Strassen::Cat::change_bnp_penalty_for_special_vehicle(\@addinfo, $special_vehicle, \$category, \$penalty);
	    } elsif ($category eq BLOCKED_CARRY) {
		$penalty = Strassen::Cat::carry_penalty_for_special_vehicle($penalty, $special_vehicle);
	    }
	}

	if (exists $sperre_type{$category}) {
	    if ($category eq BLOCKED_ROUTE) {
		# Aufzeichnen der nicht erlaubten Wegführung
		push @{ $self->{Wegfuehrung}{$ret->[Strassen::COORDS()][-1]} },
		     $ret->[Strassen::COORDS()];
		if (defined $del_token) {
		    push @{ $self->{"Wegfuehrung_$del_token"}{$ret->[Strassen::COORDS()][-1]} },
			 $ret->[Strassen::COORDS()];
		}
	    } else { # ONEWAY...
		my @kreuzungen = @{$ret->[Strassen::COORDS()]};
		if (@kreuzungen == 1) {
		    $self->del_net($kreuzungen[0], undef, undef, $del_token);
		} else {
		    my $i;
		    for($i = 0; $i < $#kreuzungen; $i++) {
			$self->del_net($kreuzungen[$i], $kreuzungen[$i+1],
				       substr($category, 0, 1), $del_token);
		    }
		}
	    }
	} else {
	    if (defined $penalty) {
		# XXX z.Zt. nur für Typ BLOCKED_CARRY u. BLOCKED_NARROWPASSAGE
		$self->{Penalty}{$ret->[Strassen::COORDS()][0]} = $penalty;
	    }
	}
    }
}

*make_sperre = \&make_sperre_1;

sub make_sperre_tragen {
    my($sperre_file, $special_vehicle, $sperre_tragen_ref, $sperre_narrowpassage_ref, %args) = @_;
    %$sperre_tragen_ref        = ();
    %$sperre_narrowpassage_ref = ();
    my $extended = $args{'-extended'} || 0;
    my $s = Strassen->new($sperre_file);
    $s->init;
    while(1) {
	my $r = $s->next;
	last if !@{ $r->[Strassen::COORDS()] };
	my($cat,@addinfo) = split /:/, $r->[Strassen::CAT()];
	if ($cat eq StrassenNetz::BLOCKED_CARRY &&
	    defined $addinfo[0] && $addinfo[0] ne '') {
	    my $penalty = Strassen::Cat::carry_penalty_for_special_vehicle($addinfo[0], $special_vehicle);
	    $sperre_tragen_ref->{$r->[Strassen::COORDS()][0]} = $extended ? [$r->[Strassen::NAME()], $penalty] : $penalty;
	} elsif ($cat eq StrassenNetz::BLOCKED_NARROWPASSAGE &&
		 defined $addinfo[0] && $addinfo[0] ne '') {
	    my $penalty = $addinfo[0];
	    my $dummy;
	    Strassen::Cat::change_bnp_penalty_for_special_vehicle(\@addinfo, $special_vehicle, \$dummy, \$penalty);
	    $sperre_narrowpassage_ref->{$r->[Strassen::COORDS()][0]} = $extended ? [$r->[Strassen::NAME()], $penalty] : $penalty;
	}
    }
}

# erstellt ein Netz mit der Steigung als Value
# Argumente:
#   sourcenet: bereits existierendes StrassenNetz-Objekt, das
#              als Vorlage dient
#   hoehe: Hash-Referenz mit den Hoehenangaben
#   -min => minimale_Steigung in %
#   -maxsearchdist => maximale Suche nach Höhenpunkten
#   -v (verbose, but not activated)
# XXX Problems if the net contains a null-distance edge!
#
# XXX Problem mit der rekursiven Suche: unterschiedliche
# Wege/Ausgangspunkte können unterschiedliche Ergebnisse verursachen.
# Denkfehler! Ich benutze nicht zwangsweise den *kuerzesten* Weg!
# find_neighbors sollte eine Breitensuche mit korrekter Sortierung nach
# Wegstrecke verwenden.
# Problemfaelle: Bersarinplatz, Heilbronner Str.; Imchenweg, bevor ich den
# korrigierenden Höhenpunkt eingefügt habe.
#
### AutoLoad Sub
sub make_net_steigung {
    my($self, $sourcenet, $hoehe, %args) = @_;
    die "sourcenet must be StrassenNetz object"
	if !$sourcenet->isa('StrassenNetz');
    my $calc_strecke = $args{'-strecke'} || \&Strassen::Util::strecke_s;
    my $min_mount = 0.001; # 0.1% als minimale Steigung
    my $max_search_dist = 1000; # bricht die Suche nach Höhenpunkten nach 1000m ab
    my $v = $args{-v} || 0;

    if (exists $args{'-min'}) {
	$min_mount = $args{'-min'}/100;
    }
    if (exists $args{'-maxsearchdist'}) {
	$max_search_dist = $args{'-maxsearchdist'};
    }
    $self->{Net} = {};
    my $net = $self->{Net};

    # Search recursively until $max_search_dist is exceeded
    my $find_neighborsXXX;
    $find_neighborsXXX = sub {
	my($from, $seen, $dist_so_far, $initial_elevation) = @_;

	my $nodes = keys %{ $sourcenet->{Net} };

	my %CLOSED;
	my %OPEN;
	my %PRED;

	my $act_coord = $from;
	my $act_dist = $dist_so_far || 0;
	$OPEN{$act_coord} = $act_dist;
	$PRED{$act_coord} = undef;

	while (1) {
	    $CLOSED{$act_coord} = $act_dist;
	    delete $OPEN{$act_coord};

	    while (my($neighbor, $dist) = each %{ $sourcenet->{Net}{$act_coord} }) {
#require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([\%OPEN, \%CLOSED],[])->Indent(1)->Useqq(1)->Dump; # XXX

#warn "($neighbor, $dist)";
		next if exists $CLOSED{$neighbor} && $CLOSED{$neighbor} <= $act_dist + $dist;
		next if exists $OPEN{$neighbor} && $OPEN{$neighbor} <= $act_dist + $dist;
		$OPEN{$neighbor} = $act_dist + $dist;
		delete $CLOSED{$neighbor};
		$PRED{$neighbor} = $act_coord;
	    }

	    # XXX Better use a heap!
	    my $new_act_coord;
	    my $new_act_dist = Strassen::Util::infinity();
	    while (my($c, $dist) = each %OPEN) {
		if ($dist < $new_act_dist) {
		    $new_act_coord = $c;
		    $new_act_dist = $dist;
		}
	    }
	    if (!defined $new_act_coord) {
		last;
	    }
	    if ($new_act_dist > $max_search_dist) {
		last;
	    }

	    if (exists $hoehe->{$new_act_coord}) {
		my $hoehendiff = $hoehe->{$new_act_coord} - $initial_elevation;
		if (!exists $net->{$from}{$new_act_coord} && $new_act_dist > 0) {
		    my $mount = int(($hoehendiff/$new_act_dist)*1000)/1000;
		    if ($mount >= $min_mount) {
			for my $i (0 .. $#$seen - 1) {
			    # XXX müßte ich hier nicht max(abs(...)) aussuchen?
			    $net->{$seen->[$i]}{$seen->[$i+1]} = $mount
				unless exists $net->{$seen->[$i]}{$seen->[$i+1]};
			}
			$net->{$seen->[-1]}{$from} = $mount
			    unless exists $net->{$seen->[-1]}{$from};
			$net->{$from}{$new_act_coord} = $mount
			    unless exists $net->{$from}{$new_act_coord};
		    }
		}
	    }

	    $act_coord = $new_act_coord;
	    $act_dist = $new_act_dist;
	    # warn $act_dist;
	}
    };

    my $find_neighbors;
    $find_neighbors = sub {
	my($from, $seen, $dist_so_far, $initial_elevation) = @_;
	$seen ||= [];
	$dist_so_far ||= 0;
	my %seen = map { ($_=>1) } @$seen;

	while(defined(my $neighbor = each %{$sourcenet->{Net}{$from}})) {
	    next if exists $seen{$neighbor};
	    my $strecke1 = $dist_so_far;
	    my $strecke2 = $calc_strecke->($from, $neighbor);
	    my $strecke = $strecke1 + $strecke2;
	    if (exists $hoehe->{$neighbor}) {
		my $hoehendiff = $hoehe->{$neighbor} - $initial_elevation;
		if (!exists $net->{$from}{$neighbor} && $strecke > 0) {
		    my $mount = int(($hoehendiff/$strecke)*1000)/1000;
		    if ($mount >= $min_mount) {
			for my $i (0 .. $#$seen - 1) {
			    $net->{$seen->[$i]}{$seen->[$i+1]} = $mount
				unless exists $net->{$seen->[$i]}{$seen->[$i+1]};
			}
#XXX$mount = "$mount @$seen";
			$net->{$seen->[-1]}{$from} = $mount
			    unless exists $net->{$seen->[-1]}{$from};
			$net->{$from}{$neighbor} = $mount
			    unless exists $net->{$from}{$neighbor};
		    }
		}
	    } else {
		return if $strecke > $max_search_dist;
		$find_neighbors->($neighbor, [@$seen, $from], $strecke, $initial_elevation);
	    }
	}
    };

    my $keys = scalar keys %{$sourcenet->{Net}};
    my $i = 0;
    my @keys = keys %{$sourcenet->{Net}};
    foreach my $p1 (@keys) {
	my $val = $sourcenet->{Net}{$p1};
	if ($v) {
	    if ($i%100 == 0) {
		printf STDERR "$i/$keys (%d%%) ($p1)...\r", $i/$keys*100;
	    }
	    $i++;
	}
	my @keys = keys %$val; # no iterator reset!
	foreach my $p2 (@keys) {
	    if (exists $hoehe->{$p1}) {
		if (exists $hoehe->{$p2}) {
		    my $strecke = $calc_strecke->($p1, $p2);
		    my $hoehendiff = $hoehe->{$p2}-$hoehe->{$p1};
		    if ($strecke > 0) {
			my $mount = int(($hoehendiff/$strecke)*1000)/1000;
			$net->{$p1}{$p2} = $mount
			    if $mount >= $min_mount;
		    }
		} else {
		    $find_neighbors->($p2, [$p1], $calc_strecke->($p1, $p2), $hoehe->{$p1});
		}
	    }
	}
    }
    printf STDERR "\n" if $v;
}

### AutoLoad Sub
sub reset {
    my $self = shift;
    $self->del_add_net;
}

use vars qw($MLDBM_SERIALIZER);
$MLDBM_SERIALIZER = 'Storable' unless defined $MLDBM_SERIALIZER;

# Gibt die Straßen-Positionsnummer für das angegebene Koordinaten-Paar aus.
# Der zweite Rückgabewert (rueckwaerts) gibt an, ob die Reihenfolge from-to
# in der Datenbank umgedreht ist.
# Wenn $to nicht definiert ist, werden alle Straßen-Positionsnummern, die
# von $from aus gehen, ausgegeben. In diesem Fall gibt es keinen
# "rueckwaerts"-Rückgabewert.
### AutoLoad Sub
sub net2name {
    my($net, $from, $to) = @_;
    if (!defined $to) {
	my(@to) = keys %{$net->{Net}{$from}};
	my @ret;
	foreach my $to (@to) {
	    push @ret, $net->net2name($from, $to);
	}
	@ret;
    } else {
	if (exists $net->{Net2Name}{$from} &&
	    exists $net->{Net2Name}{$from}{$to}) {
	    ($net->{Net2Name}{$from}{$to}, 0);
	} elsif (exists $net->{Net2Name}{$to} &&
		 exists $net->{Net2Name}{$to}{$from}) {
	    ($net->{Net2Name}{$to}{$from}, 1);
	} else {
	    warn "Can't find street from $from to $to"
	      if $VERBOSE;
	    undef;
	}
    }
}

sub get_street_record {
    my($net, $from, $to, %args) = @_;
    my $obeydir = delete $args{-obeydir};
    my($pos, $reversed) = $net->net2name($from, $to);
    if (defined $pos) {
	return undef if ($obeydir && $reversed);
	if (ref $pos eq 'ARRAY') {
	    map { $net->{Strassen}->get($_) } @$pos;
	} else {
	    $net->{Strassen}->get($pos);
	}
    } else {
	undef;
    }
}

use Class::Struct;
#BEGIN { Class::Struct::printem() }
BEGIN {
    struct('StrassenNetz::SearchContext' =>
       {Algorithm => "\$",
	HasPenalty => "\$",
	HasAmpeln => "\$",
	AmpelPenalty => "\$",
	HasQualitaet => "\$",
	HasHandicap => "\$",
	HasStrcat => "\$",
	HasRadwege => "\$",
	HasRadwegeStrcat => "\$",
	HasGreen => "\$",
	HasUnlitStreets => "\$",
	HasSteigung => "\$",
	HasTragen => "\$",
	Velocity => "\$",
	HasAbbiegen => "\$",
	Statistics => "\$",
	UserDefPenaltySub => "\$",
	HasBlocked => "\$",
       }
   );
}

sub build_penalty_code {
    my $sc = shift || die "No build context given";

    my $penalty_code = "";

    if ($sc->Algorithm ne 'srt' &&
	$sc->Algorithm !~ /^C-/) {
	$penalty_code .= '
                    my $next_node = $successor;
                    my $last_node = $min_node;
';
    }
    if ($sc->HasBlocked) {
	$penalty_code .= '
                    if (defined $last_node) {
                        if (exists $blocked_net->{$last_node}{$next_node}) {
			    my $cat = $blocked_net->{$last_node}{$next_node};
			    if ($cat =~ /^(?:' . BLOCKED_COMPLETE . '|' . BLOCKED_ONEWAY . ')$/) {
			        return Strassen::Util::infinity();
			    } # XXX strict oneway?
			} elsif (exists $blocked_net->{$next_node}{$last_node} &&
				 $blocked_net->{$next_node}{$last_node} =~ /^' . BLOCKED_COMPLETE . '/) {
			    return Strassen::Util::infinity();
			}
		    }
';
    }
    if ($sc->HasAmpeln && $sc->Algorithm ne 'srt') {
	# XXX not yet for srt_algo
	# XXX Penalty anpassen, falls nach links/rechts abgebogen wird.
	# Keine Penalty bei Besonderheiten (nur eine Richtung ist relevant,
	# Fußgängerampel...) XXX
	# XXX next_node oder last_node verwenden?
	$penalty_code .= '
		    if (exists $ampel_net->{$next_node}) {
			$pen += ' . $sc->AmpelPenalty . ';
		    }
';
    }
    if ($sc->HasQualitaet) {
	# A not existing penalty may happen if searching with fragezeichen streets
	# is turned on.
	$penalty_code .= '
		    if (defined $last_node and
                        exists $qualitaet_net->{$last_node}{$next_node}) {
			my $cat = $qualitaet_net->{$last_node}{$next_node};
			if (exists $qualitaet_penalty->{$cat}) {
  	                    $pen *= $qualitaet_penalty->{$cat}; # Qualitätszuschlag
			}
		    }
';
    }
    if ($sc->HasHandicap) {
	# See above
	$penalty_code .= '
		    if (defined $last_node and
                        exists $handicap_net->{$last_node}{$next_node}) {
			my $cat = $handicap_net->{$last_node}{$next_node};
			if (exists $handicap_penalty->{$cat}) {
                            $pen *= $handicap_penalty->{$cat}; # Handicapzuschlag
			}
		    }
';
    }
    if ($sc->HasStrcat) {
	# See above
	$penalty_code .= '
		    if (defined $last_node and
                        exists $strcat_net->{$last_node}{$next_node}) {
			my $cat = $strcat_net->{$last_node}{$next_node};
			if (exists $strcat_penalty->{$cat}) {
                            $pen *= $strcat_penalty->{$cat}; # Kategorieaufschlag
			}
		    }
';
    }
    if ($sc->HasRadwege) {
	# A penalty for the empty category should be defined.
	$penalty_code .= '
		    if (defined $last_node and
                        exists $radwege_net->{$last_node}{$next_node}) {
                        # Radwegeaufschlag
                        $pen *= $radwege_penalty->{$radwege_net->{$last_node}{$next_node}};
		    } else {
                        $pen *= $radwege_penalty->{""};
                    }
';
    }
    if ($sc->HasRadwegeStrcat) {
	# Assumes that every possible category has a penalty.
	$penalty_code .= '
		    if (defined $last_node and
                        exists $radwege_strcat_net->{$last_node}{$next_node}) {
                        $pen *= $radwege_strcat_penalty->{$radwege_strcat_net->{$last_node}{$next_node}}; # combined cycle path/street category penalty
		    }
';
    }
    if ($sc->HasGreen) {
	# Assumes that the penalty for green0 (not a green street) is
	# defined.
	$penalty_code .= '
		    if (defined $last_node) {
                        if (exists $green_net->{$last_node}{$next_node}) {
                            $pen *= $green_penalty->{$green_net->{$last_node}{$next_node}};
                        } else {
                            $pen *= $green_penalty->{"green0"};
                        }

		    }
';
    }
    if ($sc->HasUnlitStreets) {
	# Lit streets have no penalty.
	$penalty_code .= '
		    if (defined $last_node and
                        exists $unlit_streets_net->{$last_node}{$next_node}) {
			my $cat = $unlit_streets_net->{$last_node}{$next_node};
			if (exists $unlit_streets_penalty->{$cat}) {
                            $pen *= $unlit_streets_penalty->{$cat};
                        }
		    }
';
    }
    if ($sc->HasSteigung) {
	$penalty_code .= '
		    if (defined $last_node and
                        exists $steigung_net->{$last_node}{$next_node}) {
                        my $norm_steigung = int(1000*$steigung_net->{$last_node}{$next_node});
                        if (!exists $steigung_penalty->{$norm_steigung}) {
                            $steigung_penalty->{$norm_steigung} = $steigung_penalty_sub->($norm_steigung);
                        }
                        $pen *= $steigung_penalty->{$norm_steigung}; # Steigungsaufschlag
		    }
';
    }
    if ($sc->UserDefPenaltySub) {
	$penalty_code .= '
                    $pen = $user_def_penalty_sub->($pen, $next_node, $last_node);
';
    }
    # should be last, because of addition
    if ($sc->HasTragen) { # XXX häh?
	if ($sc->HasGreen) {
	    # Adjust penalty according to penalty for "normal" (non-green)
	    # streets:
	    $penalty_code .= '
		    if ($penalty and exists $penalty->{$next_node}) {
                        $pen += ' . $sc->Velocity . '*$penalty->{$next_node}*$green_penalty->{"green0"};
		    }
';
	} else {
	    $penalty_code .= '
		    if ($penalty and exists $penalty->{$next_node}) {
                        $pen += ' . $sc->Velocity . '*$penalty->{$next_node};
		    }
';
	}
    }

    if ($penalty_code ne "" &&
	$] >= 5.006 # has warnings.pm
       ) {
	$penalty_code = "    no warnings; # ignore because of \"inwork\" and such

$penalty_code";
    }

    $penalty_code;
}

# Return value
use enum qw(:RES_ PATH LEN XXX PENALTY TRAFFICLIGHTS NEAREST_NODE);

# local constants for A*
use enum qw(PREDECESSOR DIST HEURISTIC_DIST);

# XXX mögliche Rückgabewerte:
# - die beste Pfadbeschreibung (+ Länge etc.)
# - die besten Pfadbeschreibungen (+ Länge etc.)
# - die beste Pfadbeschreibung (ohne Länge etc.)
# - die besten Pfadbeschreibungen (ohne Länge etc.)
# - die beste Route (als Objekt)
# - die besten Routen (als Objekt)
### AutoLoad Sub
sub build_search_code {
    my($self, %args) = @_;

    my $sc = $args{SearchContext} || die "No SearchContext given";

    # Optionen zum Ändern des Suchalgorithmus'
    #XXX => $sc->AlgorithmOpt
    my $cut_path_nr   = 10;
    my $pure_depth    = 0;
    my $backtracking  = 0;
    if (exists $args{Tune}) {
	if (exists $args{Tune}->{CutPath}) {
	    $cut_path_nr = $args{Tune}->{CutPath};
	}
	if ($args{Tune}->{PureDepth}) {
	    $pure_depth = $args{Tune}->{PureDepth};
	}
	if ($args{Tune}->{Backtracking}) {
	    $backtracking = $args{Tune}->{Backtracking};
	}
    }

    # soll eine "visuelle" Suche vorgenommen werden
    my $do_visual     = exists $args{VisualSearch} ? 1 : 0;
    my $do_singlestep = exists $args{SingleStep} ? 1 : 0;

    # Optimierung mit einem seen-Hash, damit bereits besuchte Knoten im
    # gleichen Pfad nicht nochmals überprüft werden.
    my $seen_optimierung = 1;

    my $use_2 = 0;
    if (defined $args{Use2}) {
	$use_2 = $args{Use2};
    } elsif ($data_format == $FMT_ARRAY) {
	$use_2 = 1;
    }

    # XXX use_3 nicht implementiert?
    my $use_3 = $data_format == $FMT_CDB;

    # XXX use_2 ist für A* noch nicht implementiert XXXXXXXXXXXXXXXXXX
    if ($use_2) {
	$sc->Algorithm("srt");
    }

    my $len_pen    = ($sc->HasPenalty ? 'pen' : 'len');

    # Aufschlag, damit Alternativ-Routen gefunden werden können
    my $aufschlag_code = '';
    if ($args{Aufschlag}) {
	$aufschlag_code = '*' . $args{Aufschlag};
    }
    # XXX Die $skip_path_code*-Variablen sind nur fuer SRT-Algo.
    #
    # Code für die Abfrage, ob der aktuelle Path das Ziel nicht mehr in einer
    # kürzeren Länge erreichen kann.
    my $skip_path_code = '
		    if (defined $visited{$next_node} and
			$next_node_'.$len_pen.' > $visited{$next_node}'
			  . $aufschlag_code . ') {
			next;
		    }
';
    my $skip_path_code2 = '
		    if (defined $visited{$to} and 
                        $virt_'.$len_pen.' > $visited{$to}'
			  . $aufschlag_code . ') {
			next;
		    }
';
    # Code für die Abfrage, ob die Wegführung des aktuellen Pfades nicht
    # erlaubt ist
    # XXX ich habe die Datenstruktur von $wegfuehrung umgestellt, hier
    # aber noch nicht...
    my $skip_path_code3 = '
		    if ($wegfuehrung and
                        exists $wegfuehrung->{$next_node}) {
                      CHECK_WEGFUEHRUNG: {
                          my($wegfuehrung) = $wegfuehrung->{$next_node};
                          for(my $i=0; $i<$#$wegfuehrung; $i++) {
                             last CHECK_WEGFUEHRUNG if ($path[$#path-$i] ne $wegfuehrung->[$#$wegfuehrung-1-$i];
                          }
			  next;
                        }
		    }
';

    # Commoninit
    my $code = 'sub {
    my($self, $from, $to) = @_;
    my $str = $self->{Strassen};
    my $net = $self->{Net};
    my $wegfuehrung = $self->{Wegfuehrung};
    my $penalty = $self->{Penalty};
    local *strecke_s = $self->{strecke_s_sub} || \&Strassen::Util::strecke_s;
';

    # Use_2_Init
    if ($use_2) {
	$code .= '
    $from = unpack("l", $self->{Coord2Index}{pack("l2", split(/,/, $from))});
    $to   = unpack("l", $self->{Coord2Index}{pack("l2", split(/,/, $to))});
';
    }

    # Visualinit
    if ($do_visual) {
	$code .= '
    my $red_val = 100;
';
    }

    # Statinit/VisualInit
    if ($sc->Statistics || $do_visual) {
	$code .= '
    my $last_time = (defined &Tk::timeofday ? Tk::timeofday() : time);
';
    }

    # Debugging (single step)
    if ($do_singlestep) {
	$code .= '
    my $do_singlestep = 1;
';
    }

    # Penaltycode ...
    my($penalty_code) = "";
    if ($sc->HasPenalty) {
	$penalty_code = build_penalty_code($sc);
    }

    if ($sc->Algorithm eq 'srt') {
	require Strassen::Obsolete;
	return $self->build_search_code_srt($code, $sc, $seen_optimierung, $use_2, $do_visual, $penalty_code, $len_pen, $skip_path_code, $skip_path_code2, $pure_depth, $backtracking, $cut_path_nr, \%args, $aufschlag_code);
    }

    ######################################################################
    # A*

    # NODES: Hash von Nodes auf
    #     [$node: Vorgänger-Node ("x,y") (PREDECESSOR),
    #      $g:    Streckenlänge (oder Penalty) bis Node (DIST),
    #      $f:    abgeschätzte Länge bis Ziel über Node (HEURISTIC_DIST),
    #      weitere Array-Elemente sind optional ...]
    use vars qw($use_heap);
    $use_heap = 0 if !defined $use_heap; # XXX the heap version seems to be faster, but first do some tests and enable it after 3.13 RELEASE.
    if ($use_heap && !eval q{ require Array::Heap2; import Array::Heap2; 1 }) {
	$use_heap = 0;
    }
    $code .= '

'; if ($use_heap) { $code .= '
    my @OPEN = ([0, $from]); make_heap @OPEN;
'; } else { $code .= '
    my %OPEN = ($from => 1);
'; } $code .= '
    my %NODES = ($from => [undef, 0, strecke_s($from, $to), undef]);
    my %CLOSED;
    my $nearest_node;
    my $nearest_node_dist = Strassen::Util::infinity();
    while (1) {
#require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([\@OPEN],[])->Indent(1)->Useqq(1)->Dump; # XXX

'; if ($do_visual) { $code .= '
        if (Tk::timeofday() > $last_time + $visual_delay) {
            $canvas->idletasks;
            $last_time = Tk::timeofday();
        }
        $red_val+=5 if $red_val < 255;
        my $red_col = sprintf("#%02x0000", $red_val);
'; } if ($use_heap) { $code .= '
        if (!@OPEN) {
'; } else { $code .= '
        if (keys %OPEN == 0) {
'; } $code .= '
            my @res;
            $res[RES_NEAREST_NODE] = $nearest_node;
            return @res;
        }

        my $min_node;
        my $min_node_f = Strassen::Util::infinity();
'; if ($use_heap) { $code .= '
	my($min_node_f, $min_node) = @{ pop_heap @OPEN };
'; } else { $code .= '
        foreach (keys %OPEN) {
            if ($NODES{$_}->[HEURISTIC_DIST] < $min_node_f) {
                $min_node = $_;
                $min_node_f = $NODES{$_}->[HEURISTIC_DIST];
            }
        }
        # min_node wird aus OPEN nach CLOSED bewegt
        delete $OPEN{$min_node};
'; } $code .= '
        $CLOSED{$min_node} = 1;
        if ($min_node eq $to) {
	    #$self->dump_search_nodes(\%NODES); # DEBUG_DUMP_NODES
            my @path;
            my $len = 0;
            while (1) {
                push @path, $min_node;
                my $prev_node = $NODES{$min_node}->[PREDECESSOR];
                if (defined $prev_node) {
                    $len += strecke_s($min_node, $prev_node);
                    $min_node = $prev_node;
                } else {
                    last;
                }
            }
            @path = map { [ split(/,/, $_) ] } reverse @path;
'; if ($sc->Statistics) {
    if ($use_heap) { $code .= '
            $visited_nodes = scalar(@OPEN) + scalar(keys %CLOSED);
';  } else { $code .= '
            $visited_nodes = scalar(keys %OPEN) + scalar(keys %CLOSED);
'; }} $code .= '
            my @ret;
            $ret[RES_PATH]          = \@path;
            $ret[RES_LEN]           = $len;
            $ret[2]                 = 0; # ???
            $ret[RES_PENALTY]       = $min_node_f;
            $ret[RES_TRAFFICLIGHTS] = undef;
            return @ret;
        }

        #printf STDERR "- dump minnode ----------------------------\nx,y=%s dist=%d hdist=%d\n", $min_node, $NODES{$min_node}->[DIST], $NODES{$min_node}->[HEURISTIC_DIST]; # DEBUG_MINNODE
	#printf STDERR "----------\n"; # DEBUG_SUCC
        my @successors = keys %{ $net->{$min_node} };
     CHECK_SUCCESSOR:
        foreach my $successor (@successors) {
#         while(my($successor, $dist) = each %{ $net->{$min_node} }) {

            my $NODES_min_node = $NODES{$min_node};
            # do not check against the predecessor of this node
            next if (defined $NODES_min_node->[PREDECESSOR] &&
                     $NODES_min_node->[PREDECESSOR] eq $successor);

            # erlaubte Wegführungen beachten
            # die Performance-Einbuße liegt anscheinend unter 1% (Messung
            # mit der alten, nicht-Array-Implementation)
            if ($wegfuehrung and
                exists $wegfuehrung->{$successor}) {
                my($wegfuehrungen) = $wegfuehrung->{$successor};
                for my $wegfuehrung (@$wegfuehrungen) {
                    my $this_node = $min_node;
                    my $same = 1;
                    for(my $i=$#$wegfuehrung-1; $i>=0; $i--) {
                        if ($wegfuehrung->[$i] ne $this_node) {
                            $same = 0;
                            last;
                        }
			if ($i > 0) {
                            $this_node = $NODES{$this_node}->[PREDECESSOR];
                            if (!defined $this_node) {
                                $same = 0;
                                last;
			    }
                        }
                    }
                    next CHECK_SUCCESSOR if $same;
                }
            }
'; if ($do_visual) { $code .= '
            if ($canvas) {
                # Ausgabe für Visual Search
                my($lx, $ly) = $transpose_sub->(split(/,/, $min_node));
                my($nx, $ny) = $transpose_sub->(split(/,/, $successor));
                $canvas->createLine($lx,$ly,$nx,$ny,
                                    -tag=>"visual",
                                    -fill=>"red",-width=>3);
            }
'; } if ($sc->Statistics) { $code .= '
            $node_touches++; # das gehört in die Stat-Abteilung
'; } $code .= "

            my \$" . $len_pen .' = $net->{$min_node}{$successor};#$dist;
';
	if ($sc->HasPenalty) {
	    $code .= $penalty_code;
	} $code .= '
            my $g = $NODES_min_node->[DIST] + ' . "\$" . $len_pen . ';
            my $remaining_dist = strecke_s($successor, $to);
            my $f = $g + $remaining_dist;
	    #printf STDERR "x,y=%s\nthis=%d f=%d g=%d\n", $successor, $' . $len_pen . ', $f, $g; # DEBUG_SUCC
            # !exists in OPEN and !exists in CLOSED:
            if (!exists $NODES{$successor}) {
                $NODES{$successor} = [$min_node, $g, $f];
'; if ($use_heap) { $code .= '
		push_heap @OPEN, [$f, $successor];
'; } else { $code .= '
                $OPEN{$successor} = 1;
'; } $code .= '
                if ($remaining_dist < $nearest_node_dist) {
                    $nearest_node_dist = $remaining_dist;
                    $nearest_node = $min_node;
                }
            } else {
                if ($f < $NODES{$successor}->[HEURISTIC_DIST]) {
                    $NODES{$successor} = [$min_node, $g, $f];
                    if (exists $CLOSED{$successor}) {
'; if ($use_heap) { $code .= '
			push_heap @OPEN, [$f, $successor];
'; } else { $code .= '
                        $OPEN{$successor} = 1;
'; } $code .= '
                        delete $CLOSED{$successor};
                    }
'; if ($use_heap) { $code .= '
		    else { # exists in OPEN
			for my $i (0 .. $#OPEN) {
			    if ($OPEN[$i][1] eq $successor) {
				$OPEN[$i][0] = $f;
				last;
			    }
			}
			make_heap @OPEN;
		    }
'; } $code .= '
                }
            }
        }
';
	if ($do_singlestep) {
	    $code .= '
	    if ($do_singlestep) {
                my $mw = defined &Tk::MainWindow::Existing && (Tk::MainWindow::Existing())[0];
		$mw->update if $mw && Tk::Exists($mw);
	    INPUT: {
	            print STDERR "min node=$min_node, <RETURN> for next step, <c> for continue: ";
	            my($ans) = scalar(<STDIN>);
	            if ($ans =~ /^c/) {
		        $do_singlestep = 0;
		    } elsif ($ans =~ /^x\s+(.*)/) {
			require Data::Dumper; print STDERR "\n", Data::Dumper->new([eval $1],[])->Deparse(1)->Useqq(1)->Dump, "\n";
		        redo INPUT;
		    }
		}
	    }
';
	} $code .= '
    }
 } # Achtung, Einrückung für make_autoload!
';
    return $code;
}

# Sucht eine Route im Netz von $from bis $to.
#
# Rückgabewert:
# wenn AsObj gesetzt ist, dann eine Liste von Route-Objekten
# ansonsten eine Liste von Array-Referenzen mit folgendem Format:
#    [\@Path, $Len, $_, $Penalty, $Ampeln]
# \@Path ist eine Liste aus Punkten "$x,$y"
# $Len ist die Gesamtlänge in Metern
# $_: ?
# $Penalty ist die Penalty (in Metern ???)
# $Ampeln ist die Anzahl der Ampeln an der Route
#
### AutoLoad Sub
sub search {
    my($self, $from, $to, %args) = @_;

    my $sc = StrassenNetz::SearchContext->new;

    # Initialisierung ...
    # $sc->HasPenalty gibt an, ob die Suche nur über die Entfernung geht oder
    # ob eine Penalty verwendet wird, die sich aus der Entfernung modifiziert
    # mit weiteren Parametern ergibt
    $sc->HasPenalty(exists $args{Ampeln}    ||
		    exists $args{Qualitaet} ||
		    exists $args{Handicap}  ||
		    exists $args{Strcat}    ||
		    exists $args{Radwege}   ||
		    exists $args{RadwegeStrcat} ||
		    exists $args{Green} ||
		    exists $args{UnlitStreets} ||
		    exists $args{Steigung}  ||
		    exists $args{Abbiegen}  ||
		    exists $args{Tragen}    ||
		    exists $self->{BlockingNet}
		   );
    $sc->HasBlocked(exists $self->{BlockingNet});
    $sc->HasAmpeln(exists $args{Ampeln});
    if ($sc->HasAmpeln) {
	$sc->AmpelPenalty((exists $args{Ampeln}->{Penalty}
			   ? $args{Ampeln}->{Penalty}
			   : 100));
    }
    $sc->HasQualitaet     (exists $args{Qualitaet});
    $sc->HasHandicap      (exists $args{Handicap});
    $sc->HasStrcat        (exists $args{Strcat});
    $sc->HasRadwege       (exists $args{Radwege});
    $sc->HasRadwegeStrcat (exists $args{RadwegeStrcat});
    $sc->HasGreen         (exists $args{Green});
    $sc->HasUnlitStreets  (exists $args{UnlitStreets});
    $sc->HasSteigung      (exists $args{Steigung});
    $sc->HasAbbiegen      (exists $args{Abbiegen} and exists $args{Ampeln});
    $sc->HasTragen        (exists $args{Tragen} and exists $args{Velocity});
    $sc->UserDefPenaltySub(exists $args{UserDefPenaltySub});

    # Ausgabe einer Statistik
    $sc->Statistics($args{Stat} || 0);

    $sc->Velocity($args{Velocity});

    $sc->Algorithm($args{'Algorithm'} || "A*");

    my $ampel_net;
    if (exists $args{Ampeln}) {
	$ampel_net = $args{Ampeln}->{Net};
    }

    my($qualitaet_net, $qualitaet_penalty);
    if (exists $args{Qualitaet}) {
	$qualitaet_net = $args{Qualitaet}->{Net}->{Net};
	$qualitaet_penalty = $args{Qualitaet}->{Penalty} || die "No penalty";
    }

    my($handicap_net, $handicap_penalty);
    if (exists $args{Handicap}) {
	$handicap_net = $args{Handicap}->{Net}->{Net};
	$handicap_penalty = $args{Handicap}->{Penalty} || die "No penalty";
    }

    my($strcat_net, $strcat_penalty);
    if (exists $args{Strcat}) {
	$strcat_net = $args{Strcat}->{Net}->{Net};
	$strcat_penalty = $args{Strcat}->{Penalty} || die "No penalty";
    }
    my($radwege_net, $radwege_penalty);
    if (exists $args{Radwege}) {
	$radwege_net = $args{Radwege}->{Net}->{Net};
	$radwege_penalty = $args{Radwege}->{Penalty} || die "No penalty";
    }
    my($radwege_strcat_net, $radwege_strcat_penalty);
    if (exists $args{RadwegeStrcat}) {
	$radwege_strcat_net = $args{RadwegeStrcat}->{Net}->{Net};
	$radwege_strcat_penalty = $args{RadwegeStrcat}->{Penalty} || die "No penalty";
    }
    my($green_net, $green_penalty);
    if (exists $args{Green}) {
	$green_net = $args{Green}->{Net}->{Net};
	$green_penalty = $args{Green}->{Penalty} || die "No penalty";
    }
    my($unlit_streets_net, $unlit_streets_penalty);
    if (exists $args{UnlitStreets}) {
	$unlit_streets_net = $args{UnlitStreets}->{Net}->{Net};
	$unlit_streets_penalty = $args{UnlitStreets}->{Penalty} || die "No penalty";
    }
    my($steigung_net, $steigung_penalty, $steigung_penalty_sub);
    if (exists $args{Steigung}) {
	$steigung_net = $args{Steigung}->{Net}->{Net};
	$steigung_penalty = $args{Steigung}->{Penalty} || die "No penalty";
	$steigung_penalty_sub = $args{Steigung}->{PenaltySub} ||
	  die "No penalty subroutine";
    }
    my($abbiegen_penalty, $category_order);
    if (exists $args{Abbiegen}) {
	$category_order = $args{Abbiegen}->{Order} || die "No order";
	$abbiegen_penalty = $args{Abbiegen}->{Penalty} || die "No penalty";
    }

    my($blocked_net);
    if (exists $self->{BlockingNet}) {
	$blocked_net = $self->{BlockingNet}->{Net};
    }
    my $user_def_penalty_sub = $args{UserDefPenaltySub};

    # für die Statistik:
    my($max_new_paths, $max_suspended_paths, $visited_nodes, $node_touches)
	= (0, 0, 0, 0);
    my(@loop_count);
    # für Visual Search:
    my($canvas, $transpose_sub, $visual_delay);
    if ($args{'VisualSearch'}) {
	$canvas        = $args{'VisualSearch'}->{Canvas};
	$transpose_sub = $args{'VisualSearch'}->{Transpose};
	$visual_delay  = $args{'VisualSearch'}->{Delay};
	$canvas->delete("visual");
    }

    if (!$args{'ExtraResults'} && !$args{AsObj}) {
	# nur Routenpunkte ohne Streckenlänge etc. zurückgegebn
	$args{OnlyPath} = 1;
    }

    if ($sc->Algorithm) {
	if ($sc->Algorithm =~ /^(dip-|DBI-)A\*$/) {
	    push @INC, "$FindBin::RealBin/diplom/code";
	    require BBBikeDiplom;
	    if ($sc->Algorithm eq 'dip-A*') {
		return $self->search_A_star($from, $to, %args);
	    } elsif ($sc->Algorithm eq 'DBI-A*') {
		$args{'DBI'} = 1;
		return $self->search_A_star($from, $to, %args);
	    }
	} elsif ($sc->Algorithm !~ /^(srt$|A\*$|C-A\*)/) {
	    die "Unknown algorithm " . $sc->Algorithm;
	}
    } else {
	$sc->Algorithm("A*");
    }

    my $search_sub;
    if ($sc->Algorithm !~ /^C-/) {
	my $code = $self->build_search_code(SearchContext => $sc, %args);
	if ($VERBOSE) {
	    # dump code with line numbers
	    my $i = 0;
	    foreach (split(/\n/, $code)) {
		$i++;
		printf STDERR "%3d %s\n", $i, $_;
	    }
	}
	$search_sub = eval $code;
	warn $@ if $@;
    } else {
	my $inner_search_sub;
	if ($sc->Algorithm eq 'C-A*-2') {
	    require Strassen::Inline2Dist;
	    $inner_search_sub = \&Strassen::Inline2::search_c;
	} else {
	    require Strassen::InlineDist;
	    $inner_search_sub = \&Strassen::Inline::search_c;
	}
	my $penalty_code = build_penalty_code($sc);
	my $penalty_sub;
	if ($penalty_code ne "") {
	    $penalty_code = <<'EOF' .
sub {
    my($next_node, $last_node, $pen) = @_;
    my $penalty = $self->{Penalty}; # XXX should not be here...
EOF
		$penalty_code . <<'EOF'
    $pen;
}
EOF
	    ;
	    warn $penalty_code if $VERBOSE;
	    $penalty_sub = eval $penalty_code;
	    die "While eval'ing penalty sub: $@" if $@;
	}
	$search_sub = sub {
	    $inner_search_sub->(@_,
				($penalty_sub ? (-penaltysub => $penalty_sub) : ()),
			       );
	};
    }

    my $start_time;
    if ($sc->Statistics) {
	$start_time = (defined &Tk::timeofday ? Tk::timeofday() : time);
    }

    if ($args{WideSearch}) {
	my $inner_search_sub = $search_sub;
	$search_sub = sub { $self->wide_search($inner_search_sub, @_) };
    }

    my @res;
    # XXX Via, All und !OnlyPath funktioniert nicht zusammen...
    if (exists $args{Via} and @{$args{Via}}) {
	my(@route) = ($from, @{$args{Via}}, $to);
	my @path;
	my $ges_len = 0;
	for(my $i = 0; $i < $#route; $i++) {
	    my($search_res, $len)
		= &$search_sub($self, $route[$i], $route[$i+1]);
	    if (ref $search_res eq 'ARRAY') {
		my(@found_path) = @$search_res;
		if ($i > 0) {
		    shift @found_path;
		}
		push @path, @found_path;
		$ges_len += $len;
	    }
	}
	@res = (\@path, $ges_len);
    } else {
	@res = &$search_sub($self, $from, $to);
    }

    if ($args{WideSearch}) {
	$res[0] = $self->expand_wide_path($res[0]);
    }

    if ($sc->Statistics) {

	my $search_time = (defined &Tk::timeofday ? Tk::timeofday() : time) - $start_time;
	warn "\n";
	warn "Algorithm:            " . $sc->Algorithm . "\n";
	warn sprintf "Search time:          %.4f s\n", $search_time;
	if ($sc->Algorithm eq 'srt') {
	    warn "Max. new paths:       $max_new_paths\n";
	    warn "Max. suspended paths: $max_suspended_paths\n";
	}
	my $path_length = 0;
	if ($search_time) {
	    if (ref $res[0] eq 'ARRAY') {
		$path_length = scalar @{$res[0]};
		warn sprintf "Path length (nodes):  %-5d %d/s\n", $path_length, $path_length/$search_time;
	    }
	    warn sprintf "Visited nodes:        %-5d %d/s\n", $visited_nodes, $visited_nodes/$search_time;
	    warn sprintf "Node touches:         %-5d %d/s\n", $node_touches, $node_touches/$search_time;
	}
	if ($visited_nodes) {
	    warn "Penetrance P:         "
		. sprintf("%.4f", scalar(@{$res[0]})/$visited_nodes) . "\n";
	    # XXX effective branching factor
	}
	warn "Length:               " . $res[RES_LEN] . "\n";
	warn "Penalty:              " . $res[RES_PENALTY] . "\n";
	warn "Length/Penalty ratio: " . ($res[RES_LEN] ? $res[RES_PENALTY]/$res[RES_LEN] : "Inf") . "\n";
	if ($sc->Statistics > 1) {
	    for(my $i=1; $i<=3; $i++) {
		if (defined $loop_count[$i-1]) {
		    warn "Loop count level $i:   " . $loop_count[$i-1] . "\n";
		}
	    }
	}

	if ($args{StatDB} && open(STAT, ">>$FindBin::RealBin/tmp/searchstat.txt")) {
	    print STAT join('|', $visited_nodes, $node_touches, $path_length);
	    close STAT;
	}
    }

    # XXX ???? verwenden für GPS-Ausgabe
    if ($args{AsObj}) {
	require Route;
	my $new_res = new Route(Path    => $res[RES_PATH],
				Len     => $res[RES_LEN],
				From    => $from,
				Via	=> $args{Via},
				To      => $to,
				Penalty => $res[RES_PENALTY],
				Ampeln  => $res[RES_TRAFFICLIGHTS],
				NearestNode => $res[RES_NEAREST_NODE],
				);
	$new_res;
    } else {
	@res;
    }
}

# Backward compat:
sub new_search {
    warn "new_search() is deprecated, please use search()";
    shift->search(@_);
}


# Findet für die Strecke c1-c2 die Position in Strassen.
# Von c1 und c2 muß mindestens ein Punkt in Net2Name existieren.
# Als zweiter Rückgabewert wird zurückgegeben, ob die Strecke rückwärts
# zur Strecke in der Datenbasis verläuft.
### AutoLoad Sub
sub nearest_street {
    my($self, $c1, $c2) = @_;
    my $rueckwaerts = 0;
    my(@str);
    return undef if !exists $self->{Net}{$c1};
    @str = keys %{ $self->{Net}{$c1} };
    if (!@str) {
	($c1, $c2) = ($c2, $c1);
	$rueckwaerts = 1;
	@str = keys %{ $self->{Net}{$c1} };
	if (!@str) {
	    warn "Kann weder $c1 noch $c2 in Net2Name finden"
	      if $VERBOSE;
	    return undef;
	}
    }

    my($x1,$y1) = split(/,/, $c1);
    my($x2,$y2) = split(/,/, $c2);

    my @winkel;

    for(my $i = 0; $i <= $#str; $i++) {
	my($xn,$yn) = split(/,/, $str[$i]);
	my($w) = schnittwinkel($x2,$y2, $x1,$y1, $xn,$yn);
	$w = 0 if $w =~ /nan/i; # ???
	push @winkel, [$w, $i];
    }

    @winkel = sort { $a->[0] <=> $b->[0] } @winkel;
    ($self->net2name($c1, $str[$winkel[0]->[1]]), $rueckwaerts);
}

use enum qw(:ROUTE_ NAME DIST ANGLE DIR	ARRAYINX EXTRA);

*route_to_name = \&route_to_name_1;

sub street_is_backwards {
    my($self, $xy1, $xy2) = @_;
    # XXX probably does not work for $type == $FMT_ARRAY
    my($str_i, $backwards) = $self->net2name($xy1, $xy2);
    return $backwards if (defined $str_i);
    ($str_i, $backwards) = $self->nearest_street($xy1, $xy2);
    return $backwards if (defined $str_i);
    warn "Can't get street for coordinates $xy1 - $xy2\n";
    0;
}

# Take the output of route_to_name and simplify the list so that only
# direction changes with an angle > $args{-minangle} (no default, 30° is a
# possible value) are recorded.
# If $args{-samestreet} is set to a true then also changes in street names
# will be recorded.
# The returned value is of the same format like in route_to_name, only change:
# the street names are collected into an array of streets.
# The ROUTE_EXTRA information is not used.
sub simplify_route_to_name {
    my($route_to_name_ref, %args) = @_;
    my @new_route_to_name;
    for(my $i=0; $i<=$#$route_to_name_ref; $i++) {
	my $e0; $e0 = $route_to_name_ref->[$i-1] if $i > 0;
	my $e = $route_to_name_ref->[$i];
	my $combine = 0;
    CHECK_COMBINE: {
	    last if $i == $#$route_to_name_ref;
	    last if (!@new_route_to_name);
	    last if ($args{-samestreet} && $new_route_to_name[-1][0][-1] ne $e->[ROUTE_NAME]);
	    last if (defined $args{-minangle} &&
		     defined $e0->[ROUTE_ANGLE] &&
		     $e0->[ROUTE_ANGLE] >= $args{-minangle});
	    $combine = 1;
	}
	if ($combine) {
	    my $last = $new_route_to_name[-1];
	    push @{$last->[ROUTE_NAME]}, $e->[ROUTE_NAME];
	    $last->[ROUTE_DIST] += $e->[ROUTE_DIST];
	    $last->[ROUTE_ANGLE]       = $e->[ROUTE_ANGLE];
	    $last->[ROUTE_DIR]         = $e->[ROUTE_DIR];
	    $last->[ROUTE_ARRAYINX][1] = $e->[ROUTE_ARRAYINX][1];
	} else {
	    push @new_route_to_name,
		[[$e->[ROUTE_NAME]],
		 $e->[ROUTE_DIST], $e->[ROUTE_ANGLE], $e->[ROUTE_DIR],
		 [@{ $e->[ROUTE_ARRAYINX] }]
		];
	}
    }

    @new_route_to_name;
}

=head2 route_info(%args)

The input arguments:

=over

=item Route

Required. The list of the path, as returned by search().

=item Coords

List of coordinates (? XXX)

=item Km

Return distances in km instead of m.

=item AngleAccuracy

Set the accuracy for angles in degrees. Default is 10E<deg>.

=item PathIndexStart

Set the start index for the reference to the Path/Route array. By
default 0.

=item StartMeters

Set the start distance. Used for continued routes. By default 0.

=back

The output is an array of hash elements with the following keys:

=over

=item Hop

The distance of the current hop as a string (number with unit, usually km).

=item HopMeters

Same as B<Hop> as a number in meters.

=item Whole

The distance from the start to the end point of the current hop. Same
format as Hop.

=item WholeMeters

Same as B<Whole> as a number in meters.

=item Way

The direction to be used at the beginning of the current hop. Possible
values are "R" (right), "L" (left) and may be prefixed with "H"
(half). Undefined or empty means: straight ahead.

=item Angle

The precise angle of the direction change. The angle is in degrees,
always positive and rounded to the AngleAccuracy input argument.

=item Direction

The direction at the beginning of the current hop ("N" for north, "S"
for south etc.).

=item Street

The street name of the current hop.

=item Coords

The coordinates as "X,Y" at the beginning of the current hop.

=back

=cut

sub route_info {
   my($self, %args) = @_;

   my $routeref       = $args{Route} || die "Missing argument: Route";
   my $coords         = $args{Coords};
   my $s_in_km        = $args{Km};
   my $angle_accuracy = $args{AngleAccuracy} || 10;
   my $path_index_start = $args{PathIndexStart} || 0;
   my $whole          = $args{StartMeters} || 0;

   my $s_sub = ($s_in_km ? sub { m2km($_[0]) } : sub { $_[0] });

   my @search_route = $self->route_to_name($routeref);
   my @route_info;
   my @route_strnames;
   my($next_angle, $next_direction)
	= ("", undef, "");
   my $last_str;
   for(my $i = 0; $i <= $#search_route; $i++) {
	my $route_info_item = {};
	my($str, $index_arr);
	my $compassdirection;
	my $hop;
	my($angle, $direction)
	    = ($next_angle, $next_direction);

	my $val = $search_route[$i];
	$str	        = $val->[ROUTE_NAME];
	$hop	        = $val->[ROUTE_DIST];
	$next_angle     = $val->[ROUTE_ANGLE];
	$next_direction = $val->[ROUTE_DIR];
	$index_arr      = $val->[ROUTE_ARRAYINX];

	my $route_strnames_index;
	if ($str ne '...' &&
	    (!defined $last_str || $last_str ne $str)) {
	    $last_str = $str;
	    $str = Strassen::strip_bezirk($str);
	    if (ref $index_arr eq 'ARRAY' &&
		ref $coords eq 'ARRAY' && 
		defined $index_arr->[0] &&
		defined $coords->[$index_arr->[0]] &&
		defined $coords->[$index_arr->[0]+1]) {
		my($x, $y) = ($coords->[$index_arr->[0]]->[0],
			      $coords->[$index_arr->[0]]->[1]);
		push @route_strnames, [$str, $x, $y, $index_arr->[0]];
		$route_strnames_index = $#route_strnames;
	    }
	}

	if ($i < $#search_route and  ref $index_arr eq 'ARRAY') {
	    $compassdirection =
		    uc(BBBikeCalc::line_to_canvas_direction
		       (@{ $routeref->[$index_arr->[0]] },
			@{ $routeref->[$index_arr->[0]+1] }));
	}

	if ($i > 0) {
	    if (!$angle) { $angle = 0 }
	    $angle = int($angle/$angle_accuracy)*$angle_accuracy;
	    if ($angle < 30) {
		$direction = "";
	    } else {
		$direction = ($angle <= 45 ? 'H' : '') . uc($direction);
	    }
	    # XXX is this correct (that is, in the $i>0 condition)?
	    if (defined $route_strnames_index) {
		$route_strnames[$route_strnames_index]->[ROUTE_ARRAYINX]
		    = $s_sub->($whole);
	    }
	}
	$whole += $hop;

	for ($route_info_item) {
	    $_->{Hop}         = $s_sub->($hop);
	    $_->{HopMeters}   = $hop;
	    $_->{Whole}       = $s_sub->($whole);
	    $_->{WholeMeters} = $whole;
	    $_->{Way}         = $direction;
	    $_->{Angle}       = $angle;
	    $_->{Direction}   = $compassdirection;
	    $_->{Street}      = $str;
	    $_->{Coords}      =
		join(",", @{$routeref->[$index_arr->[0]]});
	    $_->{PathIndex}   = $index_arr->[0] + $path_index_start;
	}

	push @route_info, $route_info_item;
   }

   @route_info;
}

# Only valid for "comments" net objects.
# $routeref: array reference to path
# $routeinx: current route index
# $seen: optional hash reference of seen comments XXX Rundfahrten?
# XXX flaky.
# XXX support for ":" in categories missing (except for PI)
# $args{AsObj} = 1: return a full Strasse object instead of the name
# $args{AsIndex} = 1: return the index of the Strasse object
sub get_point_comment {
    my($self, $routeref, $routeinx, $seen, %args) = @_;
    my $as_obj = $args{AsObj};
    my $as_index = $args{AsIndex};
    return if $routeinx == $#$routeref;
    my $xy1 = join ",", @{ $routeref->[$routeinx] };
    my $xy2 = join ",", @{ $routeref->[$routeinx+1] };
    my @pos;
    my $pos;
    my $strassen = $self->{Strassen};
    my $net2name = $self->{Net2Name};
 FIND_POS: {
	my $h1;
	$h1 = $net2name->{$xy1};
	if ($h1) {
	    $pos = $h1->{$xy2};
	    push @pos, $pos if defined $pos;
	    $pos = $h1->{"*"};
	    push @pos, $pos if defined $pos;
	}
	$h1 = $net2name->{$xy2};
	if ($h1) {
	    $pos = $h1->{$xy1};
	    push @pos, $pos if defined $pos;
	    $pos = $h1->{"*"};
	    push @pos, $pos if defined $pos;
	}
        $h1 = $net2name->{"*"};
	if ($h1) {
	    $pos = $h1->{$xy1};
	    push @pos, $pos if defined $pos;
	    $pos = $h1->{$xy2};
	    push @pos, $pos if defined $pos;
	}
	if (!@pos) {
	    return;
	}
    }

    # array-ify and uniq-ify
    my %pos = map {($_,1)} map {
	if (UNIVERSAL::isa($_, "ARRAY")) {
	    @$_;
	} else {
	    $_;
	}
    } @pos;
    @pos = keys %pos;

    my @res;
    my @res_inx;
 POS:
    for my $pos1 (@pos) {
	next if $seen && $seen->{$pos1};
	my $r = $strassen->get($pos1);
	if ($r->[Strassen::CAT()] =~ /^(P1|CP;)$/) {
	    if ($routeinx > 0) {
		my $xy0 = join ",", @{ $routeref->[$routeinx-1] };
		if (($r->[Strassen::COORDS()][0] eq $xy0 || $r->[Strassen::COORDS()][0] eq '*') &&
		    ($r->[Strassen::COORDS()][1] eq $xy1 || $r->[Strassen::COORDS()][1] eq '*') &&
		    ($r->[Strassen::COORDS()][2] eq $xy2 || $r->[Strassen::COORDS()][2] eq '*')) {
		    push @res, $r;
		    push @res_inx, $pos1;
		    next POS;
		}
	    }
	} elsif ($r->[Strassen::CAT()] =~ /^(P2|CP)$/) {
	    if ($routeinx > 0) {
		my $xy0 = join ",", @{ $routeref->[$routeinx-1] };
		if ((($r->[Strassen::COORDS()][0] eq $xy0 || $r->[Strassen::COORDS()][0] eq '*') &&
		     ($r->[Strassen::COORDS()][1] eq $xy1 || $r->[Strassen::COORDS()][1] eq '*') &&
		     ($r->[Strassen::COORDS()][2] eq $xy2 || $r->[Strassen::COORDS()][2] eq '*')) ||
		    (($r->[Strassen::COORDS()][0] eq $xy2 || $r->[Strassen::COORDS()][2] eq '*') &&
		     ($r->[Strassen::COORDS()][1] eq $xy1 || $r->[Strassen::COORDS()][1] eq '*') &&
		     ($r->[Strassen::COORDS()][2] eq $xy0 || $r->[Strassen::COORDS()][0] eq '*'))) {
		    push @res, $r;
		    push @res_inx, $pos1;
		    next POS;
		}
	    }
	} elsif ($r->[Strassen::CAT()] =~ /^CP2;$/) {
	    if ($r->[Strassen::COORDS()][0] eq $xy1 &&
		$r->[Strassen::COORDS()][1] eq $xy2) {
		push @res, $r;
		push @res_inx, $pos1;
		next POS;
	    }
	} elsif ($r->[Strassen::CAT()] =~ /^CP2$/) {
	    if (($r->[Strassen::COORDS()][0] eq $xy1 &&
		 $r->[Strassen::COORDS()][1] eq $xy2) ||
		($r->[Strassen::COORDS()][0] eq $xy2 &&
		 $r->[Strassen::COORDS()][1] eq $xy1)) {
		push @res, $r;
		push @res_inx, $pos1;
		next POS;
	    }
	} elsif ($r->[Strassen::CAT()] =~ /^(S1|CS;)$/) {
	    for my $i (0 .. $#{$r->[Strassen::COORDS()]}-1) {
		if ($r->[Strassen::COORDS()][$i] eq $xy1 &&
		    $r->[Strassen::COORDS()][$i+1] eq $xy2) {
		    $seen->{$pos1}++ if $seen;
		    push @res, $r;
		    push @res_inx, $pos1;
		    next POS;
		}
	    }
	} elsif ($r->[Strassen::CAT()] =~ /^(S2|CS)$/) {
	    for my $i (0 .. $#{$r->[Strassen::COORDS()]}-1) {
		if (($r->[Strassen::COORDS()][$i] eq $xy1 &&
		     $r->[Strassen::COORDS()][$i+1] eq $xy2) ||
		    ($r->[Strassen::COORDS()][$i+1] eq $xy1 &&
		     $r->[Strassen::COORDS()][$i] eq $xy2)) {
		    $seen->{$pos1}++ if $seen;
		    push @res, $r;
		    push @res_inx, $pos1;
		    next POS;
		}
	    }
	} elsif ($r->[Strassen::CAT()] =~ /^PI;?(:|$)/) {
	CHECK_PI: {
		for my $i (0 .. $#{$r->[Strassen::COORDS()]}) {
		    last CHECK_PI if !defined $routeref->[$routeinx+$i];
		    my $xy = join ",", @{ $routeref->[$routeinx+$i] };
		    last CHECK_PI if ($r->[Strassen::COORDS()][$i] ne $xy);
		}
		$seen->{$pos1}++ if $seen;
		push @res, $r;
		push @res_inx, $pos1;
		next POS;
	    }
	} elsif ($r->[Strassen::CAT()] =~ /^P0;?$/) {
	    # not yet
	    next POS;
	} else { # arbitrary categories
	    # XXX what about obey_dir???
	    my $cat_hin = $r->[Strassen::CAT()];
	    my $cat_rueck;
	    if ($cat_hin =~ /(.*);(.*)/) {
		($cat_hin, $cat_rueck) = ($1, $2);
	    } else {
		$cat_rueck = $cat_hin;
	    }
	    for my $i (0 .. $#{$r->[Strassen::COORDS()]}-1) {
		my $yes = 0;
		if ($r->[Strassen::COORDS()][$i] eq $xy1 &&
		    $r->[Strassen::COORDS()][$i+1] eq $xy2 &&
		    $cat_hin ne "") {
		    $yes = 1;
		} elsif ($r->[Strassen::COORDS()][$i+1] eq $xy1 &&
			 $r->[Strassen::COORDS()][$i] eq $xy2 &&
			 $cat_rueck ne "") {
		    $yes = 1;
		}
		if ($yes) {
		    $seen->{$pos1}++ if $seen;
		    push @res, $r;
		    push @res_inx, $pos1;
		    next POS;
		}
	    }
	}
    }

    if ($as_index) {
	@res_inx;
    } elsif ($as_obj) {
	@res;
    } else {
	map { $_->[Strassen::NAME()] } @res;
    } 
}

# Löscht den Punkt aus dem Straßennetz-Graphen
# Wenn nur ein Punkt angegeben ist, dann werden alle Nachbarn entfernt.
# Wenn zwei Punkte angegeben sind, dann wird nur diese Strecke entfernt,
# und zwar nur in dieser Richtung, wenn dir == 1, oder beide Richtungen,
# wenn dir == 2
# If $del_token is defined, then record the deletion in _Deleted$del_token
sub del_net {
    my($self, $point1, $point2, $dir, $del_token) = @_;
    if (!defined $point2) {
	if (exists $self->{Net}{$point1}) {
	    foreach (keys %{$self->{Net}{$point1}}) {
		if (defined $del_token) {
		    if (exists $self->{Net}{$point1}{$_}) {
			$self->{"_Deleted$del_token"}{$point1}{$_} = $self->{Net}{$point1}{$_};
		    }
		    if (exists $self->{Net}{$_}{$point1}) {
			$self->{"_Deleted$del_token"}{$_}{$point1} = $self->{Net}{$_}{$point1};
		    }
		}
		delete $self->{Net}{$point1}{$_};
		delete $self->{Net}{$_}{$point1};
	    }
	}
    } else {
	if (exists $self->{Net}{$point1}) {
	    if (defined $del_token &&
		exists $self->{Net}{$point1}{$point2}) {
		$self->{"_Deleted$del_token"}{$point1}{$point2} = $self->{Net}{$point1}{$point2};
	    }
	    delete $self->{Net}{$point1}{$point2};
	}
	if ($dir ne BLOCKED_ONEWAY) { # "2"
	    if (exists $self->{Net}{$point2}) {
		if (defined $del_token &&
		    exists $self->{Net}{$point2}{$point1}) {
		    $self->{"_Deleted$del_token"}{$point2}{$point1} = $self->{Net}{$point2}{$point1};
		}
		delete $self->{Net}{$point2}{$point1};
	    }
	}
    }
}

# Der erste Punkt in @points ist der einzufügende, die beiden anderen
# existieren bereits. Rückwärts-Eigenschaft wird beachtet.
### AutoLoad Sub
sub add_net {
    my($self, $pos, @points) = @_;
    return unless defined $pos;
    die 'Es müssen genau 3 Punkte in @points sein!' if @points != 3;
    # additional check: for (@points) { die "add_net: all points should be array refs" if !UNIVERSAL::isa($_,"ARRAY") }
    my($startx, $starty) = @{$points[0]};
    require Route;
    my $starts = Route::_coord_as_string([$startx,$starty]);
    my @ex_point;
    my @entf;
    for (1..2) {
	$ex_point[$_] = Route::_coord_as_string($points[$_]);
    }
    my $rueckwaerts = 0;
    if ($self->{Net2Name} &&
	exists $self->{Net2Name}{$ex_point[2]}{$ex_point[1]}) {
        $rueckwaerts = 1;
    }

    my $i;
    for($i=1; $i<=2; $i++) {
        my $s = $ex_point[$i];
	my $entf = $entf[$i] = Strassen::Util::strecke($points[0], $points[$i]);
	if (!exists $self->{Net}{$starts}{$s}) {
	    $self->store_to_hash($self->{Net}, $starts, $s, $entf);
	    #$self->{Net}{$starts}{$s} = $entf;
	    push @{$self->{AdditionalNet}}, [$starts, $s];
	}
	if (!exists $self->{Net}{$s}{$starts}) {
	    $self->store_to_hash($self->{Net}, $s, $starts, $entf);
	    #$self->{Net}{$s}{$starts} = $entf;
	    push @{$self->{AdditionalNet}}, [$s, $starts];
	}
	# XXX $pos ist hier immer definiert...
	if ($self->{Net2Name} &&
	    !exists $self->{Net2Name}{$starts}{$s} &&
	    defined $pos) {
  	    if (($i == 1 && $rueckwaerts) || $i == 2) {
		$self->store_to_hash($self->{Net2Name}, $starts, $s, $pos);
	        #$self->{Net2Name}{$starts}{$s} = $pos;
	    } else {
		$self->store_to_hash($self->{Net2Name}, $s, $starts, $pos);
	        #$self->{Net2Name}{$s}{$starts} = $pos;
            }
	}
    }

    if ($self->{WideNet}) {
	my $wide_neighbors = $self->{WideNet}{WideNeighbors};
	my $intermediates_hash = $self->{WideNet}{Intermediates};

	my($n1, $n2);
	if (!defined $wide_neighbors->{$ex_point[1]} &&
	    !defined $wide_neighbors->{$ex_point[2]}) {
	    # Beide Endpunkte sind bereits Kreuzungspunkte
	    ($n1, $n2) = ($ex_point[1], $ex_point[2]);
	    $wide_neighbors->{$starts} =
		[$n1, $entf[1],
		 $n2, $entf[2],
		];
	} else {
	    my($ex1_n1_dist, $ex1_n2_dist);
	    if (defined $wide_neighbors->{$ex_point[1]}) {
		($n1, $ex1_n1_dist, $n2, $ex1_n2_dist) =
		    @{ $wide_neighbors->{$ex_point[1]} };
	    } else {
		($n1, $ex1_n1_dist, $n2, $ex1_n2_dist) =
		    @{ $wide_neighbors->{$ex_point[2]} };
	    }

	    my $total_len = $ex1_n1_dist + $ex1_n2_dist;
	    $wide_neighbors->{$starts} =
		[$n1,
		 $total_len - $ex1_n2_dist - $entf[2],
		 $n2,
		 $total_len - $ex1_n1_dist - $entf[1],
		];
	}
return; # XXX?????????????????
	for my $def ([$n1, $n2],
		     [$n2, $n1]) {
	    my $intermediates = $intermediates_hash->{$def->[0]}{$def->[1]};
	    if ($intermediates) {
		my @test_interm = @$intermediates;
	    TRY: {
		    for(my $i=0; $i<$#test_interm; $i++) {
			if ($test_interm[$i]   eq $ex_point[1] &&
			    $test_interm[$i+1] eq $ex_point[2]) {
			    $intermediates_hash->{$def->[0]}{$starts}
				= [@{$intermediates}[0 .. $i]];
			    $intermediates_hash->{$starts}{$def->[1]}
				= [@{$intermediates}[$i+1 .. $#$intermediates]];
			    last TRY;
			} elsif ($test_interm[$i]   eq $ex_point[2] &&
				 $test_interm[$i+1] eq $ex_point[1]) {
warn "#XXXny";
#  			    $intermediates_hash->{$def->[1]}{$starts}
#  				= [@{$intermediates}[0 .. $i]];
#  			    $intermediates_hash->{$starts}{$def->[0]}
#  				= [@{$intermediates}[$i+1 .. $#$intermediates]];
			}
		    }
		    warn "$ex_point[1]/$ex_point[2] not found in @test_interm";
		}
	    } else {
		warn "No intermediates for $def->[0] to $def->[1]";
	    }
	}
    }
}

### AutoLoad Sub
sub del_add_net {
    my $self = shift;

    foreach my $b (@{$self->{AdditionalNet}}) {
	delete $self->{Net}{$b->[0]}{$b->[1]};
	if (exists $self->{Net2Name}{$b->[0]}{$b->[1]}) {
	    delete $self->{Net2Name}{$b->[0]}{$b->[1]};
	}
    }
    @{$self->{Additional}} = ();
    @{$self->{AdditionalNet}} = ();
}

*reachable = \&reachable_1;

# Falls die Koordinate nicht exakt im Netz existiert, wird der nächstgelegene
# Punkt gesucht und zurückgegeben, ansonsten der exakte Punkt.
# Die Koordinate ist im "x,y"-Format angegeben.
# XXX Funktioniert die Methode auch mit Data_Format 2?
### AutoLoad Sub
sub fix_coords {
    my($self, $coord) = @_;
    if (!$self->reachable($coord)) {
	$self->make_crossings();
	my(@nearest) = $self->{Crossings}->nearest_coord($coord);
	if (@nearest) {
	    $nearest[0];
	} else {
	    warn "Can't find another point near to $coord.\n";
	    undef;
	}
    } else {
	$coord;
    }
}

### AutoLoad Sub
sub make_crossings {
    my $self = shift;
    if (!defined $self->{Crossings}) {
	require Strassen::Kreuzungen;
	warn "In StrassenNetz::make_crossings...\n" if $VERBOSE;
	$self->{CrossingsHash} = $self->{Strassen}->all_crossings
	    (RetType => 'hash', UseCache => 1);
	$self->{Crossings} = Kreuzungen->new(Hash => $self->{CrossingsHash});
	$self->{Crossings}->make_grid;
	warn "...done\n" if $VERBOSE;
    }
}

sub null { }

# XXX sollte geändert werden, so dass echtes Subclassing verwendet
# wird (etwa wie für CNetFile)
### AutoLoad Sub
sub use_data_format {
    my $self;
    if (@_) {
	if (ref $_[0] && $_[0]->isa("StrassenNetz")) {
	    $self = shift;
	}
    }
    if (@_) {
	$data_format = shift;
    }
    if ($self) {
	if ($data_format == $FMT_MMAP) {
	    require StrassenNetz::CNetFileDist;
	    bless $self, "StrassenNetz::CNetFile";
	} else {
	    bless $self, "StrassenNetz";
	}
    }

    my $a = shift;
    if (defined $a) {
	$data_format = $a;
    }

    local($^W) = 0;

    if ($data_format == $FMT_MMAP) {
	# nothing to do
    } elsif ($data_format == $FMT_CDB) {
	require Strassen::CDB;
	use_data_format_cdb();
    } else {
	*make_net        = ($data_format == $FMT_HASH ? \&make_net_slow_1 : \&make_net_slow_2);
	*net_read_cache  = ($data_format == $FMT_HASH ? \&net_read_cache_1 : \&net_read_cache_2);
	*net_write_cache = ($data_format == $FMT_HASH ? \&net_write_cache_1 : \&net_write_cache_2);
	*make_sperre     = ($data_format == $FMT_HASH ? \&make_sperre_1 : \&null);
	*route_to_name   = ($data_format == $FMT_HASH ? \&route_to_name_1 : \&route_to_name_2);
	*reachable       = ($data_format == $FMT_HASH ? \&reachable_1 : \&reachable_2);
	# XXX restliche ...
    }
}

sub DESTROY { }

*make_net_classic = *make_net_classic if 0; # peacify -w

1;
