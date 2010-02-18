# -*- perl -*-

#
# $Id: Ampelschaltung.pm,v 1.10 2005/12/10 23:23:23 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

use strict;

package AmpelschaltungCommon;

sub time2s {
    my($t1,%args) = @_;
    return if $t1 eq '';

    my($h1,$m1,$s1);
    if ($t1 =~ /^\+(\d+):(\d+)\??$/) {
	my($rel_m,$rel_s) = ($1, $2);
	if (!$args{-relstart}) {
	    die "Relative time found, but no -relstart given!";
	}
	($h1,$m1,$s1) = @{ $args{-relstart} };
	$s1+=$rel_s;
	if ($rel_s >= 60) {
	    $rel_s -= 60;
	    $m1++;
	}
	$m1+=$rel_m;
	if ($rel_m >= 60) {
	    $rel_m -= 60;
	    $h1++;
	}
	if ($h1 >= 24) {
	    $h1 -= 24;
	}
    } else {
	($h1,$m1,$s1) = split(/:/, $t1);
    }
    $s1 =~ s/\D//g; # Fragezeichen etc. am Ende streichen
    $h1*60*60+$m1*60+$s1;
}

sub s2time {
    my($s) = @_;
    my $h = int($s / (60*60));
    $s -= $h*(60*60);
    my $m = int($s / 60);
    $s -= $m*60;
    ($h, $m, $s);
}

package Ampelschaltung::Point;

sub new {
    my($class, $root, %args) = @_;
    my $self = \%args;
    $self->{Root} = $root;
    bless $self, $class;
}

# Constructor. Erzeugt aus einer Zeile aus der Datenbanl ein Point-Objekt mit
# den darunterliegenden Entries. Root ist *nicht* gesetzt, wenn
# $args{Root} leer ist.
sub create {
    my($class, $string, %args) = @_;
    my($p1, $kreuzung, @schaltung) = split(/\t/);
    my $root = $args{Root};
    if (!defined $kreuzung || $kreuzung eq '') {
	if ($root and
	    scalar keys %{ $root->{Crossing} } and
	    exists $root->{Crossing}{$p1}) {
	    $kreuzung = join("/", @{ $root->{Crossing}{$p1} });
	} else {
	    $kreuzung = '???';
	}
    }
    my $ap = Ampelschaltung::Point->new($root,
					Point    => $p1,
					Crossing => $kreuzung);
    foreach (@schaltung) {
	my(@l) = split /,/;
	$ap->add_entry
	  (Ampelschaltung::Entry->new
	   ($ap,
	    Day     => $l[0], # Wochentag
	    Time    => $l[1], # Uhrzeit
	    DirFrom => $l[2],
	    DirTo   => $l[3],
	    Green   => $l[4],
	    Red     => $l[5],
	    Cycle   => $l[6],
	    Comment => $l[7],
	    Date    => $l[8],
	   ));
    }
    $ap;
}

sub as_string {
    my $self = shift;
    join("\t", @{$self}{qw(Point Crossing)},
	 map { $_->as_string } $self->entries);
}

sub add_entry {
    my($self, $entry) = @_;
    push @{ $self->{Entries} }, $entry;
}

sub del_entry {
    my($self, $entry_index) = @_;
    splice @{ $self->{Entries} }, $entry_index, 1;
    undef $self->root->{SavedUntil};
}

sub root { $_[0]->{Root} }

sub entries { ref $_[0]->{Entries} eq 'ARRAY' ?  @{ $_[0]->{Entries} } : () }

sub entries_by_dir {
    my($self, $from, $to) = @_;
    # Ampelschaltung verwendet deutsche Himmelsrichtungen
    $from =~ s/e/o/g;
    $to   =~ s/e/o/g;
    my @res;
    foreach my $e ($self->entries) {
	if ($e->{DirFrom} eq $from &&
	    $e->{DirTo}   eq $to) {
	    push @res, $e;
	}
    }
    @res;
}

package Ampelschaltung::Entry;

sub new {
    my($class, $root, %args) = @_;
    my $self = \%args;
    $self->{Root} = $root;
    bless $self, $class;
}

sub as_string {
    my $self = shift;
    local $^W = undef;
    join(",", @{$self}{qw(Day Time DirFrom DirTo Green Red Cycle Comment Date)});
}

sub get_cycle {
    my $self = shift;
    if (defined $self->{Cycle} and $self->{Cycle} ne '') {
	$self->{Cycle};
    } elsif (defined $self->{Green} and $self->{Green} =~ /^\d/ and
	     defined $self->{Red}   and $self->{Red} =~ /^\d/) {
	(my $g = $self->{Green}) =~ s/\D//g;
	(my $r = $self->{Red})   =~ s/\D//g;
	$g + $r;
    }
}

sub update_cycle {
    my $self = shift;
    my $cycle = $self->get_cycle;
    $self->{Cycle} = $cycle;
}

sub lost {
    my($self, %args) = @_;
    Ampelschaltung::lost(-gruen => $self->{Green},
			 -rot   => $self->{Red},
			 %args);
}

sub root { $_[0]->{Root} }

package Ampelschaltung;
use Strassen;
use BBBikeUtil qw(sqr);
use vars qw($warn);
$warn = 1;

use vars qw(@ISA);
@ISA = qw(AmpelschaltungCommon);

sub new {
    my($class, %args) = @_;
    my $self = \%args;
    bless $self, $class;
}
    
sub open {
    my $self = shift;
    my $basefile = shift || "ampelschaltung-orig";
    my(%args) = @_;
    require MyFile;
    my $file = MyFile::openlist(*RW, map { "$_/$basefile" }
				@Strassen::datadirs, @INC);
    my $r = 0;
    if ($file) {
	$self->{File}             = $file;
	@{ $self->{Data} }        = (); # Ampelschaltung::Point-Objekte
	%{ $self->{Point2Index} } = (); # "x,y"-Koordinaten => Index auf Data
	while(<RW>) {
	    chomp;
	    $self->add_point($_);
	}
	close RW;
	if (!-w $file and $self->{Top}) {
	    require Tk::Dialog;
	    $self->{Top}->Dialog
	      (-title => 'Warnung',
	       -text => "Achtung: auf die Datei $file kann nicht geschrieben werden.",
	       -buttons => ['OK'])->Show;
	}
	$r = 1;
    }
    
    if ($args{UpdateCycle}) {
	# update cycle times...
	foreach (@{ $self->{Data} }) {
	    foreach my $e ($_->entries) {
		$e->update_cycle;
	    }
	}
    }
    
    $r;
}

sub save {
    my $self = shift;
    if ($self->{File}) {
	CORE::open(RW, ">$self->{File}") or die "Can't save $self->{File}: $!";
	print RW join("\n", map { $_->as_string } @{ $self->{Data} }), "\n";
	close RW;
    }
}

sub dump {
    my $self = shift;
    require Data::Dumper;
    Data::Dumper::Dumper($self->{Data});
}

# XXX
# sub save_new {
#     my $self = shift;
#     if (!defined $self->{SavedUntil}) {
# 	$self->save;
#     } elsif ($self->{File}) {
# 	open(RW, ">>$self->{File}") or die "Can't append to $self->{File}: $!";
# 	print RW join("\n", map { $_->as_string } @{ $self->{Data} }), "\n";
# 	close RW;
#     }
#     $self->{SavedUntil} = $#{ $self->{Data} };
# }

sub add_point {
    my($self, $line) = @_;
    my $ap = create Ampelschaltung::Point $line, Root => $self;
    my $p1 = $ap->{Point};
    push @{ $self->{Data} }, $ap;
    if (exists $self->{Point2Index}{$p1}) {
	warn "Die Ampelschaltung für $p1 existiert bereits!";
    }
    $self->{Point2Index}{$p1} = $#{ $self->{Data} };
    return $#{ $self->{Data} };
}

sub find_point {
    my($self, $point) = @_;
    if (exists $self->{Point2Index}{$point}) {
	$self->{Data}[$self->{Point2Index}{$point}];
    } else {
	undef;
    }
}

# verlorene Zeit und Strecke
sub lost {
    my(%args) = @_;

    my $gruen = $args{-gruen}; # in Sekunden
    my $rot   = $args{-rot};
    return if !defined $gruen or !defined $rot;

    $gruen =~ s/^(\d+).*/$1/;
    $rot   =~ s/^(\d+).*/$1/;
    return if $gruen eq '' or $rot eq '';

    my $kmh   = (exists $args{-geschwindigkeit}
		 ? $args{-geschwindigkeit} : 20); # in km/h
    # Beschleunigung in m/s²
    my $a     = exists $args{-beschleunigung} ? $args{-beschleunigung} : 1;

    my($rot_ver, $ms);

    if (defined $kmh and $a) {
	$ms = $kmh/3.6;
	# Zeit, die für die Beschleunigung auf $ms benötigt wird:
	my $t = $ms/$a;
	# bei einer linearen Bewegung könnte man so weit kommen:
	my $s_lin = $t*$ms;
	# beschleunigt schafft man aber nur so viel:
	my $s_bes = $ms*$ms/(2*$a);
	# verlorene Zeit:
	my $t_ver = ($s_lin-$s_bes)/$ms;
	# auf die Rotphasenzeit aufschlagen:
	$rot_ver = $rot + $t_ver;
    } else {
	$rot_ver = $rot; # ignorieren
    }

    my %res;
    if ($gruen+$rot > 0) {
	$res{-zeit} = (($rot_ver*($rot_ver+1))/2)/($gruen+$rot);
	if (defined $kmh) {
	    $res{-strecke} = $ms*$res{-zeit};
	}
    }
    %res;

}

use vars qw($lost);
$lost->{10}{0.5} = [17.10, 47.51];
$lost->{15}{0.5} = [18.10, 75.43];
$lost->{20}{0.5} = [19.13, 106.28];
$lost->{25}{0.5} = [20.19, 140.21];
$lost->{30}{0.5} = [21.28, 177.32];
$lost->{10}{1} = [16.14, 44.82];
$lost->{15}{1} = [16.62, 69.23];
$lost->{20}{1} = [17.10, 95.02];
$lost->{25}{1} = [17.60, 122.22];
$lost->{30}{1} = [18.10, 150.85];
$lost->{10}{1.5} = [15.82, 43.94];
$lost->{15}{1.5} = [16.14, 67.23];
$lost->{20}{1.5} = [16.45, 91.42];
$lost->{25}{1.5} = [16.78, 116.51];
$lost->{30}{1.5} = [17.10, 142.53];
$lost->{10}{2} = [15.66, 43.51];
$lost->{15}{2} = [15.90, 66.24];
$lost->{20}{2} = [16.14, 89.64];
$lost->{25}{2} = [16.37, 113.71];
$lost->{30}{2} = [16.62, 138.47];

sub get_lost {
    my($speed, $a) = @_;
    my %res;

    # force numeric
    $speed = $speed + 0;
    $a = $a + 0;

    # XXX bessere Näherung
    if ($a < 0.7)    { $a = 0.5 }
    elsif ($a < 1.2) { $a = 1 }
    elsif ($a < 1.7) { $a = 1.5 }
    else             { $a = 2 }
    if ($speed < 10) { $speed = 10 }
    elsif ($speed > 30) { $speed = 30 }

    if (int($speed) != $speed or $speed % 5 != 0) {
	my $lower = int($speed/5)*5;
	my $upper = $lower+5;
	my $arr1 = $lost->{$lower}{$a};
	my $arr2 = $lost->{$upper}{$a};
	die "Problem with $speed and $a " if (ref $arr1 ne 'ARRAY' or
					      ref $arr2 ne 'ARRAY');
	$res{-zeit} = ($arr2->[0]-$arr1->[0])*($speed-$lower)/5 + $arr1->[0];
	$res{-strecke} = ($arr2->[1]-$arr1->[1])*($speed-$lower)/5 + $arr1->[1];
	
    } else {
	my $arr = $lost->{$speed}{$a};
	die "Problem with speed=$speed and a=$a " if (ref $arr ne 'ARRAY');
	$res{-zeit} = $arr->[0];
	$res{-strecke} = $arr->[1];
    }
    %res;
}

# verlorene Zeiten, Strecken bei beschleunigten Vorgängen
# %args:
#   abbremsung:     Abbremsung in m/s^2 (benötigt)
#   beschleunigung: Beschleunigung in m/s^2 /benötigt)
#   beschleunigung_P: Beschleunigungs-Leistung in W, kann anstelle von
#                     beschleunigung angegeben werden
#   speed_reise:    Reisegeschwindigkeit in km/h
#   speed_reduced:  Geschwindigkeit nach Abbremsung in km/h
#   wartezeit:      zusätzliche Wartezeit in s (nur bei speed_reduced=0
#                   sinnvoll)
#   length_reduced: Länge der Strecke, die mit der reduzierten Geschwindigkeit
#                   befahren wird (in m)
#   gesamtmasse:    Gesamtmasse von Rad und Fahrer, nur für Energie- und
#                   Leistungsberechnung notwendig (in kg)
# Rückgabe:
#   linear:         zurückgelegte Strecke ohne Verluste und Wartezeit
#   beschl:         zurückgelegte Strecke mit Verlusten und Wartezeit
#   s:              verlorene Strecke in m
#   t:              verlorene Zeit in s
#   t_beschl:       Zeit für die Beschleunigung in s
#   W:              aufgewendete Energie für Beschleunigung in J
#   P:              aufgewendete Leistung für Beschleunigung in W
sub acc_lost {
    my(%args) = @_;
    return if ($args{'abbremsung'} == 0 || 
	       ($args{'beschleunigung'} == 0 and
		$args{'beschleunigung_P'} == 0));

    my $speed_reise_ms   = $args{'speed_reise'} / 3.6;
    my $speed_reduced_ms = $args{'speed_reduced'} / 3.6;
    my $wartezeit        = $args{'wartezeit'} || 0;
    my $gesamtmasse      = $args{'gesamtmasse'} || 0;

    # kinetische Energie für speed_reduced und speed_reise
    my $W_reduced = 0.5*$gesamtmasse*sqr($speed_reduced_ms);
    my $W_reise   = 0.5*$gesamtmasse*sqr($speed_reise_ms);
    my $W         = $W_reise - $W_reduced;

    # Zeit, die für das Abbremsen auf reduced benötigt wird
    my $t_abbrems = ($speed_reduced_ms-$speed_reise_ms)
                    /-$args{'abbremsung'};

    # Zeit, die für die Beschleunigung auf reise benötigt wird
    my $t_beschl;
    if ($args{'beschleunigung_P'}) {
	$t_beschl  = $W/$args{'beschleunigung_P'};
    } else {
	$t_beschl  = ($speed_reise_ms-$speed_reduced_ms)
                     /$args{'beschleunigung'};
    }

    # bei einer linearen Bewegung könnte man so weit kommen
    my $s_lin = ($t_abbrems+$t_beschl+$wartezeit)*$speed_reise_ms;

    # beschleunigt schafft man aber nur so viel
    my $s_bes_a = sqr($speed_reise_ms-$speed_reduced_ms)
                  /(2*$args{'abbremsung'});
    my $s_bes_b = sqr($speed_reise_ms-$speed_reduced_ms)
                  /(2*$args{'beschleunigung'});
    my $s_bes   = $s_bes_a + $s_bes_b;

    # verlorene Zeit
    #my $t_ver_a = ($s_lin-$s_bes_a)/$speed_reise_ms;
    #my $t_ver_b = ($s_lin-$s_bes_b)/$speed_reise_ms;
    my $t_ver   = ($s_lin-$s_bes)/$speed_reise_ms;

    # Die Langsamfahrstrecke fordert auch ihren Tribut:
    if ($speed_reise_ms != $speed_reduced_ms and
	$speed_reise_ms and $speed_reduced_ms) {
	my $t_ver_red = $args{'length_reduced'}/$speed_reduced_ms
	              - $args{'length_reduced'}/$speed_reise_ms;
	$t_ver += $t_ver_red;
	# XXX t_ver_a/b ungültig?
    }

    # Soviel muß dafür geleistet werden:
    my $P = ($t_beschl ? $W/$t_beschl : 0);

    my %res = 
      (
       'linear'	   => $s_lin,
       'beschl'	   => $s_bes,
       's'	   => $s_lin - $s_bes,
       't'	   => $t_ver,
       't_beschl'  => $t_beschl,
       #'t_brems'   => $t_ver_a,
       'W'	   => $W,
       'P'	   => $P,
      );
    %res;
}

# Verkehrszeiten
# Argumente:
#   wochentag: "mo", "di" ...
#   zeit: "hh:mm"
# Ausgabe: "berufsverkehr", "tagesverkehr", "nachtverkehr", undef
#
# Ich definiere die Verkehrszeiten wie folgt:
# Berufsverkehr: Mo-Fr, 7-9 Uhr und 16-19 Uhr
# Nachtverkehr: von 22-7h
# Tagesverkehr: sonstige Zeiten
#
# Nach dem Skript "Verkehrsplanungstheorie" S.23 von Prof. Kutter 
# existieren Verkehrsleistungsspitzen (über 100000 Kfz/h) in Berlin
# in den Morgenstunden um 8 Uhr und nachmittags von 16 bis einschließlich
# 19 Uhr.
# 
sub verkehrszeit {
    my($wochentag, $zeit) = @_;
    return if !defined $wochentag or !defined $zeit;
    my($h,$m) = split(/:/, $zeit);
    return if !defined $h;
    if ($h < 7 || $h >= 22) {
	return "nachtverkehr";
    }
    if ($wochentag eq 'sa' || $wochentag eq 'so') {
	return "tagesverkehr";
    } else {
	if ($h < 9 || ($h >= 16 && $h < 19)) {
	    return "berufsverkehr";
	} else {
	    return "tagesverkehr";
	}
    }
}

# Restrict Entries by Direction, Time (Verkehrszeit) etc.
sub restrict_entries {
    my($e_ref, %args) = @_;
    my(@res);
    if ($args{DirFrom}) {
	$args{DirFrom} =~ s/e/o/g;
    }
    if ($args{DirTo}) {
	$args{DirTo} =~ s/e/o/g;
    }
    foreach my $e (@$e_ref) {
      TRY: {
	    while(my($k, $v) = each %args) {
		if ($k eq 'Verkehrszeit') {
		    my $vz = Ampelschaltung::verkehrszeit($e->{Day},
							  $e->{Time});
		    last TRY if $vz ne $v;
		} else {
		    last TRY if ($e->{$k} ne $v);
		}
	    }
	    push @res, $e;
	}
    }
    @res;
}

# XXX create_points also for Ampelschaltung!

package Ampelschaltung2::Point;
use vars qw(@ISA);
@ISA = qw(Ampelschaltung::Point);

sub new {
    my($class, $root, $point) = @_;
    my $self = {Point => $point,
		Crossing => "",
	       };
    $self->{Root} = $root;
    bless $self, $class;
    my(@e) = $self->entries;
    if (@e) {
	$self->{Crossing} = $e[0]->{Crossing};
    }
    $self;
}

sub entries {
    my $self = shift;
    $self->{Root}->find_by_point($self->{'Point'});
}

package Ampelschaltung2::Entry;
use vars qw(@ISA);
@ISA = qw(Ampelschaltung::Entry);

sub new {
    my($class, $root, %args) = @_;
    my $self = \%args;
    $self->{Root} = $root;
    bless $self, $class;
}

# Pseudo-Methode, um Kompatibiliät zu Ampelschaltung::Point::entries
# zu erreichen.
# XXX hier richtig????
sub entries { $_[0] }

sub lost { Ampelschaltung::Entry::lost(@_) }

# XXX duplicate code
sub as_string {
    my $self = shift;
    local $^W = undef;
    join(",", @{$self}{qw(Day Time DirFrom DirTo Green Red Cycle Comment Date)});
}

package Ampelschaltung2;

# Alternatives Ampelschaltungs-Format (misc/ampelschaltung.txt) Diese
# ist genauer, weil die exakte Zeit (H:M:S) der Signalumschaltung
# erfasst wird.

use vars qw(@ISA);
@ISA = qw(AmpelschaltungCommon);

sub new {
    my($class, %args) = @_;
    my $self = \%args;
    bless $self, $class;
}

# hacky, but works
sub from_string {
    my($self, $str) = @_;
    local(@Strassen::datadirs) = "/tmp";
    my $tmpfile = "/tmp/ampsch.$$.txt";
    CORE::open(W, ">$tmpfile") or die "$tmpfile: $!";
    print W $str;
    close W;
    require File::Basename;
    my $r = $self->open(File::Basename::basename($tmpfile));
    unlink $tmpfile;
    $r;
}

sub open {
    my $self = shift;
    my $basefile = shift || "ampelschaltung-orig.txt";
    require MyFile;
    use FindBin; # XXX
    my $file;
    if (-e $basefile) {
	$file = $basefile;
	CORE::open(RW, $file) or return 0;
    } else {
	$file = MyFile::openlist(*RW, map { "$_/$basefile" }
				 @Strassen::datadirs, "$FindBin::RealBin/misc",
				 @INC);
    }
    if ($file) {
	$self->{File}             = $file;
	@{ $self->{Data} }        = (); # Ampelschaltung2::Entry-Objekte
	%{ $self->{Point2Index} } = (); # "x,y" => Index auf Data
	my $curr_date;
	my $curr_day;
	# Eine Gruppe besteht aus Beobachtungen eines Tages. Nur dort
	# kann ich mir sicher sein, daß die Uhrzeiten *relativ*
	# stimmen.
	my $group_index = -1; # Index der Gruppe
	my $index_in_group;   # Index innerhalb der Gruppe
	my @rel_start;
	while(<RW>) {
	    next if (/^\s*\#/ || /^\s*$/); # Kommentare und Leerzeilen
	    chomp;
	    if (/^(\w{2}),\s+(\d+)\.(\d+)\.(\d+)(?:\s+\(00:00:00\s*=\s*(\d+):(\d+):(\d+)\))?/) {
		$curr_day  = lc($1);
		$curr_date = sprintf("%s, %02d.%02d.%04d", $1, $2, $3, $4);
		$group_index++;
		$index_in_group = 0;
		@rel_start = ();
		if (defined $5) {
		    @rel_start = ($5, $6, $7);
		}
	    } elsif (/^([-+]?\d+,[-+]?\d+)/) {
		my $point = $1;
		$self->add_point(-date       => $curr_date,
				 -day        => $curr_day,
				 -point      => $point,
				 -group      => $group_index,
				 -groupindex => $index_in_group,
				 -line       => $_,
				 -relstart   => \@rel_start,
				);
		push @{$self->{Point2Index}{$point}}, $#{ $self->{Data} };
		$index_in_group++;
	    } elsif (/^\s+/) { # XXX spezielle Zeilen
	    } else {
		warn "Can't parse line: $_";
	    }
	}
	close RW;
	1;
    } else {
	0;
    }
}

sub dump {
    my $self = shift;
    require Data::Dumper;
    Data::Dumper::Dumper($self->{Data});
}

sub add_point {
    my($self, %args) = @_;
    my $date        = $args{-date}; # komplettes Datum: "wk, dd.mm.yyyy"
    my $day         = $args{-day}; # Wochentag
    my $point       = $args{-point};
    my $line        = $args{-line};
    my $group       = $args{-group};
    my $group_index = $args{-groupindex};
    my $rel_start   = $args{-relstart};
    if (!defined $date) {
	warn "Datum für <$line> nicht definiert";
	return;
    }
    require Text::Tabs;
    $line = Text::Tabs::expand($line);

    my $last_e = ($#{$self->{Data}} >= 0 
		  ? $self->{Data}[$#{$self->{Data}}]
		  : undef);

    my $kreuzung = _strip_blank_substr($line, 14, 49-14);
    my $dir = _strip_blank_substr($line, 49, 6);
    my($dir_from, $dir_to);
    if ($dir !~ m{^\s*$}) {
	if ($dir !~ /([A-Z]+)->([A-Z]+)/) {
	    warn "Die Richtung <$dir> in <$line> kann nicht geparst werden.";
	    return;
	}
	($dir_from, $dir_to) = (lc($1), lc($2));
    }

    my $zyklus     = _strip_blank_substr($line, 56, 3);
    (my $zyklus_n = $zyklus) =~ s/^(\d+).*/$1/;
    my $green_time = _strip_blank_substr($line, 60, 69-60);
    my $red_time   = _strip_blank_substr($line, 70, 10);

    my($green, $red);
    my $green_is_length;
    my $red_is_length;

    if ($green_time =~ /^\d+$/ || $red_time =~ /^\d+$/) {
	if ($green_time =~ /^\d+$/) {
	    $green = $green_time;
	    $green_is_length = 1;
	}
	if ($red_time =~ /^\d+$/) {
	    $red = $red_time;
	    $red_is_length = 1;
	}
    }

    if ($green_time ne '' and $red_time ne '' && !$green_is_length && !$red_is_length) {
	my $gs = AmpelschaltungCommon::time2s($green_time, -relstart => $rel_start);
	my $rs = AmpelschaltungCommon::time2s($red_time,   -relstart => $rel_start);
	if ($gs < $rs) {
	    $green = _adjust_green_red($rs-$gs, $zyklus_n);
	} elsif ($zyklus_n ne '' and $zyklus_n > 0) {
	    $green = _adjust_green_red($zyklus_n - ($gs-$rs), $zyklus_n);
	}
	if ($gs > $rs) {
	    $red = _adjust_green_red($gs-$rs, $zyklus_n);
	} elsif ($zyklus_n ne '' and $zyklus_n > 0) {
	    $red = _adjust_green_red($zyklus_n - ($rs-$gs), $zyklus_n);
	}
    }
    # length of red time in form +5s
    if ($red_time =~ /^\+(\d+)/ and $green_time eq '' and $last_e and !@$rel_start) {
	my $add = $1;
	$green = $last_e->{Green}-$add
	  if defined $last_e->{Green} && $last_e->{Green} ne '';
	$red   = $last_e->{Red}+$add 
	  if defined $last_e->{Red} && $last_e->{Red} ne '';
    }

    my $time;
    {
	my @time;
	if (@$rel_start) {
	    foreach my $t_def ([$red_time, $red_is_length],
			       [$green_time, $green_is_length]) {
		my($t, $is_length) = @$t_def;
		if (defined $t && $t ne "" && !$is_length) {
		    my $s = AmpelschaltungCommon::time2s($t, -relstart => $rel_start);
		    push @time, sprintf "%02d:%02d:%02d", AmpelschaltungCommon::s2time($s);
		}
	    }
	} else {
	    foreach my $t_def ([$red_time, $red_is_length],
			       [$green_time, $green_is_length]) {
		my($t, $is_length) = @$t_def;
		push @time, $t if defined $t && $t ne "" && !$is_length && $t !~ /^\+/;
	    }
	}
	if (@time) {
	    $time = join(":", (split(/:/, (@time == 1 
					   ? $time[0]
					   : _min_time(@time))))[0 .. 2]);
	}
    }

    if (defined $green and ($green < 5 or $green > 50)) {
	warn "Suspicious green time for $kreuzung at $date: $green\n"
	  if $Ampelschaltung::warn;
    }
    if (defined $red   and ($red < 18 or $red > 80)) {
	warn "Suspicious red time for $kreuzung at $date: $red\n"
	  if $Ampelschaltung::warn;
    }
    if ($zyklus_n ne '' and $zyklus_n ne 'AUS'
	and ($zyklus_n < 40 or $zyklus_n > 90)) {
	warn "Suspicious cycle time for $kreuzung at $date: $zyklus_n\n"
	  if $Ampelschaltung::warn;
    }

    my $comment;
    if ($kreuzung =~ /\((auto.*|rad.*)\)/i) {
	$comment = $1;
    }
    my $e = Ampelschaltung2::Entry->new
      ($self,
       Date       => $date,
       Day        => $day, # Wochentag
       Point      => $point,
       Crossing   => $kreuzung,
       DirFrom    => $dir_from,
       DirTo      => $dir_to,
       GreenTime  => $green_time,
       Green      => $green,
       RedTime    => $red_time,
       Red        => $red,
       Time       => $time, # Uhrzeit
       Cycle      => $zyklus,
       Comment    => $comment,
       Group      => $group,
       GroupIndex => $group_index,
      );
    push @{ $self->{Data} }, $e;
}

# Create a hash of Points, each one contains a list of Entries.
sub create_points {
    my($self) = @_;
    my %point;
    foreach my $e (@{ $self->{Data} }) {
	push @{ $point{$e->{Point}} }, $e;
    }
    %point;
}

# Return pseudo-object Ampelschaltung2::Point
sub find_point {
    my($self, $point) = @_;
    if (exists $self->{Point2Index}{$point}) {
	Ampelschaltung2::Point->new($self, $point);
    } else {
	undef;
    }
}

# Return list of Ampelschaltung2::Entries for the specified point.
sub find_by_point {
    my($self, $point) = @_;
    my @res;
    if (exists $self->{Point2Index}{$point}) {
	foreach (@{ $self->{Point2Index}{$point} }) {
	    push @res, $self->{Data}[$_];
	}
    }
    @res;
}

# Gibt die beste Gruppe für die angegebenen Entries zurück.
# Die beste Gruppe ist diejenige mit den meisten Einträgen.
sub find_best_group {
    my($e_ref) = @_;
    my %group_points;
    foreach my $e (@$e_ref) {
	if ($e->{RedTime} ne "") {
	    $group_points{$e->{Group}}++;
	}
	if ($e->{GreenTime} ne "") {
	    $group_points{$e->{Group}}++;
	}
    }
    (sort { $group_points{$b} <=> $group_points{$a} } keys %group_points)[0];
}

# Argument ist eine Referenz auf die Entries einer Gruppe (ggfs.
# mit Ampelschaltung::restrict erstellen).
# Ausgabe ist ein Array mit den Abständen zwischen den Rot- und
# Grün-Zeiten in Sekungen:
# ([r1, g1], # Rot- und Grün-Abstand zwischen dem Gruppenmitglied 1 und 2
#  [r2, g2],
#  ...)
# XXX siehe Hinweis 3 Zeilen tiefer
sub build_delta_table {
    my($e_ref, %args) = @_;
    my $zyklus = $args{Zyklus} || die; # XXX sollte nicht notwendig sein!
    my @res;
    for(my $i=0; $i<$#$e_ref; $i++) {
	my @def;
	if ($e_ref->[$i]{RedTime} ne '' and
	    $e_ref->[$i+1]{RedTime} ne '') {
	    my($rs1, $rs2) = 
	      (AmpelschaltungCommon::time2s($e_ref->[$i]{RedTime}),
	       AmpelschaltungCommon::time2s($e_ref->[$i+1]{RedTime}));
	    $def[0] = ($rs2-$rs1)%$zyklus;
	}
	if ($e_ref->[$i]{GreenTime} ne '' and
	    $e_ref->[$i+1]{GreenTime} ne '') {
	    my($rs1, $rs2) = 
	      (AmpelschaltungCommon::time2s($e_ref->[$i]{GreenTime}),
	       AmpelschaltungCommon::time2s($e_ref->[$i+1]{GreenTime}));
	    $def[1] = ($rs2-$rs1)%$zyklus;
	}
	push @res, [@def];
    }
    @res;
}

sub _strip_blank_substr {
    my($s, @substr_args) = @_;
    local $^W = 0; # "substr outside of string" verhindern
    $s = substr($s, $substr_args[0], $substr_args[1]);
    $s =~ s/\s+$//;
    $s || '';
}

sub _min_time {
    my($t1, $t2) = @_;
    return if $t1 eq '' and $t2 eq '';
    return $t1 if $t2 eq '';
    return $t2 if $t1 eq '';
    my $ss1 = AmpelschaltungCommon::time2s($t1);
    my $ss2 = AmpelschaltungCommon::time2s($t2);
    if ($ss1 > $ss2) { # XXX über Mitternacht hinaus XXX
	$t2;
    } else {
	$t1;
    }
}

sub _adjust_green_red {
    my($green_red, $zyklus) = @_;
    $green_red =~ s/^(\d+).*/$1/;
    $zyklus =~ s/^(\d+).*/$1/;
    if ($zyklus ne '' and $zyklus > 0) {
	while ($green_red > $zyklus) {
	    $green_red -= $zyklus;
	}
	while ($green_red < 0) {
	    $green_red += $zyklus;
	}
    }
    $green_red;
}

1;

