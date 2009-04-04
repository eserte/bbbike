# -*- perl -*-

#
# $Id: Kreuzungen.pm,v 1.18 2009/04/04 12:47:52 eserte Exp $
#
# Copyright (c) 1995-2001 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Author: Slaven Rezic (eserte@cs.tu-berlin.de)
#

package Strassen::Kreuzungen;

$VERSION = sprintf("%d.%02d", q$Revision: 1.18 $ =~ /(\d+)\.(\d+)/);

package Kreuzungen;
use strict;
use vars qw($VERBOSE);
#use AutoLoader 'AUTOLOAD';

use BBBikeUtil qw();

# Argumente: entweder "Hash" oder "Strassen"
# "Hash" ist der Rückgabewert von Strassen::all_crossings (bei
# Verwendung von "hash" oder "hashpos" als RetType). Array wird noch nicht
# verwendet.
# Bei "Strassen" werden die Kreuzungen automatisch per all_crossings erstellt.
sub new {
    my($class, %args) = @_;
    my $self = {};
    my $rettype = 'hash';
    my $usecache = defined $args{UseCache} ? $args{UseCache} : 1;
    my $all_points = $args{AllPoints} || $args{Kurvenpunkte} || 0;
    my @config = ($all_points ? "kurvenp" : ());
    if (!exists $args{Hash}) {
	die "Missing arg for new Kreuzungen: either Hash or Strassen"
	    if !exists $args{Strassen};
	if ($args{WantPos}) {
	    $rettype .= "pos";
	}
	my($kreuzungen_ref) = $args{Strassen}->all_crossings
	    (RetType => $rettype, AllPoints => $all_points,
	     UseCache => $usecache);
	$args{Hash} = $kreuzungen_ref;
	if ($args{Strassen}->{Inaccessible}) {
	    push @config, "inacc";
	}
    }
    $self->{Hash}  = $args{Hash};
    $self->{Array} = $args{Array};
    $self->{IsPos} = $args{WantPos};
    $self->{Strassen} = $args{Strassen};
    $self->{Config} = \@config;

    bless $self, $class;
}

# Nimmt an. dass alle Punkte aus der Strassen-Datei Kreuzungen (z.B. Orte)
# darstellen.
# Das Argument "Kurvenpunkte" wird hier ignoriert.
### AutoLoad Sub
sub new_from_strassen {
    my($class, %args) = @_;
    my $want_pos = $args{WantPos};
    my $self = {};
    $self->{Hash} = {};
    $self->{Config} = [ ];
    my $str = $args{Strassen};
    if (!$str) {
	die "Missing arg for new_from_strassen: Strassen";
    }
    $str->init;
    my $pos = 0;
    while(1) {
	my $ret = $str->next;
	last if !@{ $ret->[Strassen::COORDS()] };
	foreach my $p (@{ $ret->[Strassen::COORDS()] }) {
	    $self->{Hash}{$p} = [($want_pos ? $pos : $ret->[Strassen::NAME()])];
	}
	$pos++;
    }
    if ($want_pos) {
	$self->{IsPos} = 1;
	$self->{Strassen} = $str;
    }
    bless $self, $class;
}

### Autoload Sub
sub id {
    my $self = shift;
    if ($self->{Strassen}) {
	$self->{Strassen}->id;
    } else {
	undef;
    }
}

### Autoload Sub
sub file {
    my $self = shift;
    if ($self->{Strassen}) {
	$self->{Strassen}->file;
    } else {
	undef;
    }
}

### Autoload Sub
sub dependent_files {
    my $self = shift;
    if ($self->{Strassen}) {
	$self->{Strassen}->dependent_files;
    } else {
	return; # undef or ()
    }
}

### Autoload Sub
sub add {
    my($self, %args) = @_;
    if (!exists $args{Hash}) {
	die "Missing argument Hash";
    }
    my $h = $self->{Hash};
    while(my($k,$v) = each %{ $args{Hash} }) {
	$h->{$k} = $v;
    }
}

# Return true if the given $coord is a crossing
### AutoLoad Sub
sub crossing_exists {
    my($self, $coord) = @_;
    exists $self->{Hash}{$coord};
}

# Return an array reference of street names of this coord
### AutoLoad Sub
sub get {
    my($self, $coord) = @_;
    if (exists $self->{Hash}{$coord}) {
	if ($self->{IsPos}) {
	    [ map { $self->{Strassen}->get($_)->[Strassen::NAME()] } @{ $self->{Hash}{$coord} } ];
	} else {
	    $self->{Hash}{$coord}
	}
    } else {
	die "Coordinate $coord does not exist in Hash. The Hash has @{[ scalar keys %{ $self->{Hash} } ]} entries.";
    }
}

# Return an array reference of street records of this coord
# Fails if this object was not constructed with WantPos=>1
### AutoLoad Sub
sub get_records {
    my($self, $coord) = @_;
    die "get_records does not work with WantPos=>0" if !$self->{IsPos};
    return [] if !exists $self->{Hash}{$coord}; # necessary to avoid errors with read-only hashes (e.g. CDB_File)
    [ map { $self->{Strassen}->get($_) } @{ $self->{Hash}{$coord} } ];
}

### AutoLoad Sub
sub get_first { shift->get(@_)->[0] }

# Args: Width => $grid_width (optional, default 1000m)
#       Height => $grid_height (optional, default $args{Width}
#       UseCache => $bool (optional, default 0)
### AutoLoad Sub
sub make_grid {
    my($self, %args) = @_;
    $self->{GridWidth}  = (defined $args{Width} ? $args{Width} : 1000);
    $self->{GridHeight} = (defined $args{Height} ? $args{Height} : $self->{GridWidth});

    my $cachefile;
 TRY_CACHE: {
	if ($args{UseCache}) {
	    my $id = $self->id;
	    if (!defined $id) {
		warn "Can't create cache: missing id" if $VERBOSE;
		last TRY_CACHE;
	    }
	    $cachefile = "kreuzungen_grid_" . $id . "_" . $self->{GridWidth} . "x" . $self->{GridHeight};
	    if ($self->{Config} && @{ $self->{Config} }) {
		$cachefile .= "_" . join("_", @{ $self->{Config} });
	    }
	    require Strassen::Util;
	    my $hashref = Strassen::Util::get_from_cache($cachefile, [$self->dependent_files]);
	    if (defined $hashref) {
		warn "Using cache for $cachefile\n" if $VERBOSE;
		$self->{Grid} = $hashref;
		return $hashref;
	    }
	}
    }

    $self->{Grid} = {};
    keys %{$self->{Hash}}; # reset iterator
    while(defined(my $k = each %{$self->{Hash}})) {
	my $grid = join(",", $self->grid(split(/,/, $k)));
	push @{$self->{Grid}{$grid}}, $k;
    }

    if ($args{UseCache} && defined $cachefile) {
	require Strassen::Util;
	if (Strassen::Util::write_cache($self->{Grid}, $cachefile)) {
	    warn "Wrote cache ($cachefile)\n" if $VERBOSE;
	}
    }
}

### AutoLoad Sub
sub grid {
    my($self, $x, $y) = @_;
    my($gx,$gy) = (int($x/$self->{GridWidth}), int($y/$self->{GridHeight}));
    $gx-- if $x < 0;
    $gy-- if $y < 0;
    ($gx,$gy);
}

# Argumente:
#    $x, $y
#    IncludeDistance: Rückgabewert ist ein Feld mit den Elementen ["x,y", dist]
#    Grids (default 1): Anzahl der Grids, die vom Mittelpunkt abweichen dürfen
#    BestOnly: return only the best match, otherwise return all in grid
# Ansonsten wird ein Feld mit den Elementen "x,y" zurückgegeben. In beiden
# Fällen ist das Feld nach der Entfernung von $x und $y sortiert (kürzeste
# zuerst).
### AutoLoad Sub
sub nearest {
    my($self, $x, $y, %args) = @_;
    my $use_cache = delete $args{UseCache};
    my $best_only = delete $args{BestOnly};
    $self->make_grid(UseCache => $use_cache) if (!$self->{Grid});
    my $xy = "$x,$y";
    my $grids = $args{Grids} || 1;
#   my $distance = $args{Distance};
# XXX distance wird noch ignoriert
#    if (!defined $distance) { $distance = 1000 }
    my($gridx, $gridy) = $self->grid($x, $y);
    my @res;
    my %seen_combination;
    for my $grids_i (0 .. $grids) {
	my @grid_sequence = (0);
	push @grid_sequence, map { ($_, -$_) } (1 .. $grids_i);
	for my $xx (@grid_sequence) {
	    for my $yy (@grid_sequence) {
		next if (exists $seen_combination{"$xx,$yy"});
		$seen_combination{"$xx,$yy"} = 1;
		my $s = ($gridx+$xx) . "," . ($gridy+$yy);
		if (defined $self->{Grid}{$s}) {
		    push @res, @{$self->{Grid}{$s}};
		}
	    }
	}
	last if $best_only && @res && $grids_i > 0;
    }

    if ($args{IncludeDistance}) {
	foreach (@res) {
	    my $dist = Strassen::Util::strecke_s($_, $xy);
	    $_ = [$_, $dist];
	}
	@res = sort { $a->[1] <=> $b->[1] } @res;
    } else {
	@res =
	map  { $_->[0] }
	sort { $a->[1] <=> $b->[1] }
	map  { [$_, Strassen::Util::strecke_s($_, $xy)] }
	@res;
    }
    if ($best_only) {
	$res[0];
    } else {
	@res;
    }
}

# Incrementally try nearest with Grids => 1 to Grids => 5
# 5 can be replaced by MaxGrids parameter
sub nearest_loop {
    my($self, $x, $y, %args) = @_;
    my $max_grids = delete $args{MaxGrids} || 5;
    return $self->nearest($x, $y, %args, Grids => $max_grids);
}

# wie nearest, nur wird hier "x,y" als ein Argument übergeben
### AutoLoad Sub
sub nearest_coord {
    my($self, $xy, %args) = @_;
    my($x, $y) = split(/,/, $xy);
    $self->nearest($x, $y, %args);
}

# wie nearest_loop, nur wird hier "x,y" als ein Argument übergeben
### AutoLoad Sub
sub nearest_loop_coord {
    my($self, $xy, %args) = @_;
    my($x, $y) = split(/,/, $xy);
    $self->nearest_loop($x, $y, %args);
}

# Zeichnet die Kreuzungen, z.B. zum Debuggen.
### AutoLoad Sub
sub draw {
    my($self, $canvas, $transpose_sub) = @_;
    $canvas->delete("crossings");
    while(my $crossing = each %{ $self->{Hash} }) {
	my($x,$y) = $transpose_sub->(split /,/, $crossing);
	$canvas->createLine($x, $y, $x, $y,
			    -tags => 'crossings',
			    -fill => 'DeepPink',
			    -capstyle => "round", # XXX see exceed bug in main
			    -width => 4,
			   );
    }
}

sub situation_at_point {
    my($self, $coord, $before_coord, $after_coord) = @_;

    my($before_coord_x, $before_coord_y) = split /,/, $before_coord;
    my($coord_x,        $coord_y)        = split /,/, $coord;
    my($angle, $dir) = BBBikeUtil::schnittwinkel($before_coord_x, $before_coord_y,
						 $coord_x,        $coord_y,
						 (split /,/, $after_coord)
						);

    my @records = @{ $self->get_records($coord) };
    my $before_street;
    my $after_street;
    my @neighbors;
    for my $record (@records) {
	my $coords = $record->[Strassen::COORDS()];

	for my $def ([\$before_street, $before_coord],
		     [\$after_street,  $after_coord],
		    ) {
	    my($other_street_ref, $other_coord) = @$def;
	    if (!defined $$other_street_ref) {
		for my $c_i (0 .. $#$coords) {
		    if ($coords->[$c_i] eq $other_coord &&
			(($c_i < $#$coords && $coords->[$c_i+1] eq $coord) ||
			 ($c_i > 0         && $coords->[$c_i-1] eq $coord))
		       ) {
			$$other_street_ref = $record;
			last;
		    }
		}
	    }
	}

 	for my $c_i (0 .. $#$coords) {
 	    if ($coords->[$c_i] eq $coord) {
 		if ($c_i > 0) {
 		    my($angle,$dir) = BBBikeUtil::schnittwinkel($before_coord_x, $before_coord_y,
								$coord_x,        $coord_y,
								(split /,/, $coords->[$c_i-1]),
							       );
		    push @neighbors, [$record, $angle, $dir];
		}
		if ($c_i < $#$coords) {
 		    my($angle,$dir) = BBBikeUtil::schnittwinkel($before_coord_x, $before_coord_y,
								$coord_x,        $coord_y,
								(split /,/, $coords->[$c_i+1]),
							       );
		    push @neighbors, [$record, $angle, $dir];
		}
 	    }
	}
    }

    use constant SAP_MIN_ANGLE   => BBBikeUtil::deg2rad(5);
    use constant SAP_HALF_ANGLE  => BBBikeUtil::deg2rad(45);
    use constant SAP_SHARP_ANGLE => BBBikeUtil::deg2rad(130);

    my $l_or_r = sub { $dir eq 'l' ? 'left' : 'right' };
    my $action;
    if (@neighbors == 2) {
	$action = ''; # no crossings
    } elsif ($after_coord eq $before_coord) {
	$action = 'back';
    } elsif ($angle >= SAP_SHARP_ANGLE) {
	$action = 'sharp-' . $l_or_r->();
    } elsif ($angle >= SAP_HALF_ANGLE) {
	$action = $l_or_r->();
    } elsif ($angle <= SAP_MIN_ANGLE) {
	$action = ''; # too small angle to distinguish from straight
    } else {
	my $is_min_angle = BBBikeUtil::min(map { $_->[1] } @neighbors) == $angle;
	if ($is_min_angle) {
	    $action = ''; # straight
	} else {
	    $action = 'half-' . $l_or_r->();
	}
    }
	
    (before_street => $before_street, # The street before the crossing
     after_street  => $after_street,  # The street after the crossing
     angle         => $angle,         # The angle in radians at point
     dir           => $dir,           # Direction: l or r
     neighbors     => \@neighbors,    # a list of [neighbors (Strassen records), angle and dir]
     action        => $action,
    );
}

{
    package Kreuzungen::MoreContext;
    use vars qw(@ISA);
    @ISA = qw(Kreuzungen);

    sub new {
	my($class, %args) = @_;
	my $ampeln    = delete $args{Ampeln}; # Hashref: x,y -> cat
	my $vf        = delete $args{Vf}; # Strassen-Objekt vorfahrt
	my $handicap  = delete $args{HandicapNet};
	my $qualitaet = delete $args{QualitaetNet};
	my $self = $class->SUPER::new(%args);
	$self->{Ampeln} = $ampeln;
	if ($vf) {
	    my %vf_hash;
	    $vf->init;
	    while(1) {
		my $r = $vf->next;
		my $c = $r->[Strassen::COORDS()];
		last if !@$c;
		$vf_hash{join(" ", @$c)}++;
		$vf_hash{join(" ", reverse @$c)}++;
	    }
	    $self->{Vf} = \%vf_hash;
	}
	$self->{HandicapNet} = $handicap;
	$self->{QualitaetNet} = $qualitaet;
	$self;
    }

    sub situation_at_point {
	my($self, $coord, $before_coord, $after_coord) = @_;
	my %ret = $self->SUPER::situation_at_point($coord, $before_coord, $after_coord);

	my $traffic_rule;
	if ($self->{Ampeln} && (my $ampel_cat = $self->{Ampeln}{$coord})) {
	    if ($ampel_cat eq 'X') {
		$traffic_rule = 'traffic_light';
	    } elsif ($ampel_cat eq 'F') {
		$traffic_rule = 'traffic_light_pedestrian';
	    } elsif ($ampel_cat eq 'B') {
		$traffic_rule = 'railway_crossing';
	    } # ignore others
	}
	if (!defined $traffic_rule) {
	    my $is_vorfahrt = $self->{Vf} && exists $self->{Vf}{join(" ", $before_coord, $coord, $after_coord)};
	    if (!$is_vorfahrt) {
		# XXX NYI: calculate implicite right of way/give right of way
		# based on Strassen::CAT
	    }
	    if ($is_vorfahrt) {
		if ($ret{action} eq '') {
		    $traffic_rule = 'right_of_way';
		} else {
		    $traffic_rule = 'bent_right_of_way';
		}
	    }
	}
	if (!defined $traffic_rule) {
	    $traffic_rule = '';
	}

	my $new_quality_cat;
	if ($self->{QualitaetNet}) {
	    my $Q_before = ($self->{QualitaetNet}{Net}{$before_coord} && $self->{QualitaetNet}{Net}{$before_coord}{$coord}) || 'Q0';
	    my $Q_after  = ($self->{QualitaetNet}{Net}{$coord}        && $self->{QualitaetNet}{Net}{$coord}{$after_coord}) || 'Q0';
	    if ($Q_before ne $Q_after) {
		$new_quality_cat = $Q_after;
	    }
	}

	my $new_handicap_cat;
	if ($self->{HandicapNet}) {
	    my $q_before = ($self->{HandicapNet}{Net}{$before_coord} && $self->{HandicapNet}{Net}{$before_coord}{$coord}) || 'q0';
	    my $q_after  = ($self->{HandicapNet}{Net}{$coord}        && $self->{HandicapNet}{Net}{$coord}{$after_coord}) || 'q0';
	    if ($q_before ne $q_after) {
		$new_handicap_cat = $q_after;
	    }
	}

	(%ret,
	 traffic_rule => $traffic_rule,
	 quality_cat  => $new_quality_cat,
	 handicap_cat => $new_handicap_cat,
	);
    }
}

1;
