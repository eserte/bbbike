# -*- perl -*-

#
# $Id: PLZ.pm,v 1.51 2004/07/08 07:29:28 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 1998, 2000, 2001, 2002, 2003, 2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package PLZ;

use 5.005; # qr{}

use strict;
# Setting $OLD_AGREP to a true value really means: use String::Approx
# instead or no agrep at all.
use vars qw($PLZ_BASE_FILE @plzfile $OLD_AGREP $VERSION $VERBOSE $sep);
use locale;
use BBBikeUtil;

$VERSION = sprintf("%d.%02d", q$Revision: 1.51 $ =~ /(\d+)\.(\d+)/);

use constant FMT_NORMAL  => 0; # /usr/www/soc/plz/Berlin.data
use constant FMT_REDUCED => 1; # ./data/Berlin.small.data (does not exist anymore)
use constant FMT_COORDS  => 2; # ./data/Berlin.coords.data

# agrep says that 32 is the max length, but experiments show something else:
use constant AGREP_LONGEST_RX => 29;

$PLZ_BASE_FILE = "Berlin.coords.data" if !defined $PLZ_BASE_FILE;

@plzfile =
  ((map { "$_/$PLZ_BASE_FILE" } @Strassen::datadirs),
   (map { ("$_/$PLZ_BASE_FILE", "$_/data/$PLZ_BASE_FILE") } @INC),
   (map { ("$_/berlinco.dat",
	   "$_/Berlin.data",        "$_/data/Berlin.data") } @INC),
  ) if !@plzfile;
$OLD_AGREP = 0 unless defined $OLD_AGREP;
# on FreeBSD is
#    ports/textproc/agrep => agrep 2.04 with buggy handling of umlauts
#    ports/textproc/glimpse => agrep 3.0

my %uml = ('ä' => 'ae', 'ö' => 'oe', 'ü' => 'ue', 'ß' => 'ss',
	   'Ä' => 'Ae', 'Ö' => 'Öe', 'Ü' => 'Ue', 'é' => 'e', 'è' => 'e');
my $umlkeys = join("",keys %uml);
my $umlkeys_rx = qr{[$umlkeys]};

# indexes of file fields
use constant FILE_NAME     => 0;
use constant FILE_CITYPART => 1;
use constant FILE_ZIP      => 2; # this is not valid for FMT_NORMAL
use constant FILE_COORD    => 3;

use constant FILE_ZIP_FMT_NORMAL => 4; # this is only valid for FMT_NORMAL

$sep = '|';

sub new {
    my($class, $file) = @_;
    my $self = {};
    if (!defined $file) {
	foreach (@plzfile) {
	    if (-r $_ && open(DATA, $_)) {
		$file = $_;
		$self->{IsGzip} = 0;
	    } elsif (-r "$_.gz") {
		if (is_in_path("gzip") && -d "/tmp" && -w "/tmp") {
		    require File::Basename;
		    my $dest = "/tmp/" . File::Basename::basename($_);
		    system("gzip -dc $_ > $dest");
		    if (open(DATA, $dest)) {
			if ($?/256 == 0) {
			    $file = $dest;
			    $self->{WasGzip} = 1;
			}
		    } else {
			warn "Cannot open $dest: $!";
		    }
		}
		if (!defined $file) {
		    warn "Gzip file $_.gz cannot be handled";
		}
	    }
	    next if !defined $file;
	}
    } elsif (defined $file) {
	open(DATA, $file) or return undef;
    } else {
	return undef;
    }

    my($line) = <DATA>;
    $line =~ s/[\015\012]//g;
# Automatic detection of format. Caution: this means that the first line
# in Berlin.coords.data must be complete i.e. having the coords field defined!
    my(@l) = split(/\|/, $line);
    if (@l == 3) {
	$self->{DataFmt}  = FMT_REDUCED;
	$self->{FieldPLZ} = FILE_ZIP;
    } elsif (@l == 4) {
	$self->{DataFmt}  = FMT_COORDS;
	$self->{FieldPLZ} = FILE_ZIP;
    } else {
	$self->{DataFmt} = FMT_NORMAL;
	$self->{FieldPLZ} = FILE_ZIP_FMT_NORMAL;
    }
    close DATA;

    $self->{File} = $file;
    $self->{Sep} = '|'; # XXX not yet used
    bless $self, $class;
}

# Load the data into $self->{Data}. Not necessary for nearly all other
# methods.
sub load {
    my($self, %args) = @_;
    my $file = $args{File} || $self->{File};
    if (do { local $^W = 0; $file ne $self->{Data} }) { # XXX häh???
	my @data;
	open(PLZ, $file)
	  or die "Die Datei $file kann nicht geöffnet werden: $!";

	my $code = <<'EOF';
	while(<PLZ>) {
	    chomp;
	    my(@l) = split(/\|/, $_);
EOF
	my $push_code;
	if ($self->{DataFmt} == FMT_REDUCED) {
	    $push_code = q{push @data,
			   [@l[FILE_NAME, FILE_CITYPART, FILE_ZIP]]};
	} elsif ($self->{DataFmt} == FMT_COORDS) {
	    $push_code = q{push @data,
			   [@l[FILE_NAME, FILE_CITYPART, FILE_ZIP, FILE_COORD]]};
	} else {
	    $push_code = q{push @data,
			   [@l[FILE_NAME, FILE_CITYPART, FILE_ZIP_FMT_NORMAL]]};
	}
	$code .= $push_code . <<'EOF';
	}
EOF
        eval $code;
	close PLZ;
	$self->{Data} = \@data;
	$self->{File} = $file;
	undef $self->{NameHash};
	undef $self->{PlzHash};
    }
}

sub make_plz_re {
    my($self, $plz) = @_;
    if ($self->{DataFmt} == FMT_REDUCED ||
	$self->{DataFmt} == FMT_COORDS) {
	'^[^|]*|[^|]*|' . $plz;
    } else {
	'^[^|]*|[^|]*|[^|]*|[^|]*|' . $plz . '|';
    }
}

# indexes of return values
use constant LOOK_NAME     => 0;
use constant LOOK_CITYPART => 1;
use constant LOOK_ZIP      => 2;
use constant LOOK_COORD    => 3;

# XXX make gzip-aware
# Argumente: (Beschreibung fehlt XXX)
#  Agrep/GrepType
#  Noextern
#  NoStringApprox
#  Citypart (optionale Einschränkung auf einen Bezirk oder Postleitzahl,
#            may also be an array reference to a number of cityparts)
#  MultiCitypart - empfehlenswert, wenn Citypart eine Postleitzahl ist!
#  MultiZIP
# Ausgabe: Array von Referenzen [strasse, bezirk, plz, "x,y-Koordinate"]
#  Je nach Format der Quelldatei ($self->{DataFmt}) fehlt die x,y-Koordinate
sub look {
    my($self, $str, %args) = @_;

    my $file = $args{File} || $self->{File};
    my @res;

    warn "->look($str, " . join(" ", %args) .") in `$file'\n" if $VERBOSE;

    #XXX use fgrep instead of grep? slightly faster, no quoting needed!
    my $grep_type = ($args{Agrep} ? 'agrep' : ($args{GrepType} || 'grep'));
    my @push_inx;
    if      ($self->{DataFmt} == FMT_NORMAL) {
	@push_inx = (FILE_NAME, FILE_CITYPART, $self->{FieldPLZ});
    } elsif ($self->{DataFmt} == FMT_REDUCED) {
	@push_inx = (FILE_NAME, FILE_CITYPART, FILE_ZIP);
    } else {
	@push_inx = (FILE_NAME, FILE_CITYPART, FILE_ZIP, FILE_COORD);
    }
    if ($grep_type eq 'agrep') {
	if ($OLD_AGREP ||
	    (!$args{Noextern} && !is_in_path('agrep')) ||
	    length($str) > AGREP_LONGEST_RX # otherwise there are "pattern too long" errors
	    # XXX AGREP_LONGEST_RX is not perfect --- the string is rx-escaped, see below
	   ) {
	    $args{Noextern} = 1;
	}
	if ($args{Noextern}) {
	    eval q{local $SIG{'__DIE__'};
		   die "Won't use String::Approx" if $args{NoStringApprox};
		   require String::Approx;
		   String::Approx->VERSION(2.7);
	       };
	    if ($@) {
		if ($args{Agrep} == 1) {
		    $grep_type = 'grep-umlaut';
		} else {
		    $grep_type = 'grep';
		}
	    }
	}
    }
    if ($grep_type eq 'grep') {
	if (!$args{Noextern} && !is_in_path('grep')) {
	    $args{Noextern} = 1;
	}
    }

    my %res;
    my $push_sub = sub {
	my(@to_push) = (split(/\|/, $_[FILE_NAME]))[@push_inx];
	if (($args{MultiCitypart}||!exists $res{$to_push[FILE_NAME]}->{$to_push[FILE_CITYPART]}) &&
	    ($args{MultiZIP}     ||!exists $res{$to_push[FILE_NAME]}->{$to_push[FILE_ZIP]})) {
	    push @res, [@to_push];
	    return if defined $args{Max} and $args{Max} < $#res;
	    $res{$to_push[FILE_NAME]}->{$to_push[FILE_CITYPART]}++;
	    $res{$to_push[FILE_NAME]}->{$to_push[FILE_ZIP]}++;
	}
    };

    if (!$args{Noextern} && $grep_type =~ /^a?grep$/) {
	unless ($args{Noquote}) {
	    if ($grep_type eq 'grep') {
		# XXX quotemeta verwenden?
		$str =~ s/([\\.*\[\]])/\\$1/g; # quote metacharacters
	    } else {
		$str =~ s/([\$\^\*\[\]\^\|\(\)\!\`])/\\$1/g;
	    }
	    $str = "^$str";
	}

	# limitation of agrep:
	if ($grep_type eq 'agrep' && length($str) > AGREP_LONGEST_RX) {
	    $str = substr($str, 0, AGREP_LONGEST_RX);
	    $str =~ s/\\$//; # remove a (lonely?) backslash at the end
	    # XXX but this will be wrong if it's really a \\
	}

	my(@grep_args) = ('-i', $str, $file);
	if ($grep_type eq 'agrep' && $args{Agrep}) {
	    unshift @grep_args, "-$args{Agrep}";
	}
	my @cmd = ($grep_type, @grep_args);
	#warn "@cmd";
	CORE::open(PLZ, "-|") or do {
	    exec @cmd;
	    warn "While doing @cmd: $!";
	    require POSIX;
	    POSIX::_exit(1); # avoid running any END blocks
	};
	my %res;
	while(<PLZ>) {
	    chomp;
	    $push_sub->($_);
	}
	close PLZ;
    } else {
	CORE::open(PLZ, $file)
	  or die "Die Datei $file kann nicht geöffnet werden: $!";
	if ($grep_type eq 'agrep') {
	    chomp(my @data = <PLZ>);
	    close PLZ;
	    my %res;
	    foreach (String::Approx::amatch($str,
					    ['i', $args{Agrep}], @data)) {
		$push_sub->($_);
	    }
	} elsif ($grep_type eq 'grep-umlaut') {
	    $str = '(?i:^' . quotemeta(kill_umlauts($str)) . ')';
	    $str = qr{$str};
	    while(<PLZ>) {
		chomp;
		if (kill_umlauts($_) =~ $str) {
		    $push_sub->($_);
		}
	    }
	    close PLZ;
	} elsif ($grep_type eq 'grep-inword') {
	    $str = '(?i:\b' . quotemeta(kill_umlauts($str)) . '\b)';
	    $str = qr{$str};
	    while(<PLZ>) {
		chomp;
		if (kill_umlauts($_) =~ $str) {
		    $push_sub->($_);
		}
	    }
	    close PLZ;
	} else {
	    $str = quotemeta($str) unless $args{Noquote};
	    $str = "^$str" unless $args{Noquote};
#XXX del?	    $str =~ s/\|/\\|/g;
	    $str = '(?i:' . $str . ')';
	    $str = qr{$str};
	    my %res;
	    while(<PLZ>) {
		chomp;
		if ($_ =~ $str) {
		    $push_sub->($_);
		}
	    }
	    close PLZ;
	}
    }

    # filter by citypart (Bezirk) or ZIP
    if (defined $args{Citypart}) {
	my $rx;
	if (ref $args{Citypart} eq 'ARRAY') {
	    $rx = "^" . join("|", map {quotemeta($_)} @{ $args{Citypart} });
	} else {
	    $rx = "^".quotemeta($args{Citypart});
	}
	$rx = qr{$rx};
	my @new_res;
	foreach (@res) {
	    if ($_->[LOOK_CITYPART] =~ /$rx/i ||
		$_->[$self->{FieldPLZ}] =~ /$rx/) {
		push @new_res, $_;
	    }
	}
	@res = @new_res;
    }

    @res;
}

# Argument: an array of references (the output of look())
# Combine streets which are probably the same (same citypart and/or same
# zip code)
# Returned value has the same format as the input
sub combine {
    my($self, @in) = @_;
    my %out;
 CHECK:
    foreach my $s (@in) {
	if (exists $out{$s->[LOOK_NAME]}) {
	    foreach my $r (@{ $out{$s->[LOOK_NAME]} }) {
		my $eq_cp = grep { $s->[LOOK_CITYPART] eq $_ } @{ $r->[LOOK_CITYPART] };
		my $eq_zp = grep { $s->[LOOK_ZIP]      eq $_ } @{ $r->[LOOK_ZIP] };
		if ($eq_cp || $eq_zp) {
		    push @{ $r->[LOOK_CITYPART] }, $s->[LOOK_CITYPART]
			unless $eq_cp;
		    push @{ $r->[LOOK_ZIP] }, $s->[LOOK_ZIP]
			unless $eq_zp;
		    next CHECK;
		}
	    }
	}
	# does not exist or is a new citypart/zip combination
	my $r = [];
	$r->[$_] = $s->[$_] for (LOOK_NAME, LOOK_COORD);
	$r->[LOOK_CITYPART] = [ $s->[LOOK_CITYPART] ];
	$r->[LOOK_ZIP] = [ $s->[LOOK_ZIP ] ];
	push @{ $out{$s->[LOOK_NAME]} }, $r;
    }
    map { @$_ } values %out;
}

# converts an array element from combine from
#    ["Hauptstr.", ["Friedenau","Schoeneberg],[10827,12159], $coord]
# to
#    ["Hauptstr.", "Friedenau, Schoeneberg", "10827,12159", $coord]
sub combined_elem_to_string_form {
    my($self, $elem) = @_;
    my $r = [];
    $r->[$_] = $elem->[$_] for (LOOK_NAME, LOOK_COORD);
    $r->[LOOK_CITYPART] = join(", ", @{$elem->[LOOK_CITYPART]});
    $r->[LOOK_ZIP]      = join(", ", @{$elem->[LOOK_ZIP]});
    $r;
}

# Split a street specification like "Heerstr. (Charlottenburg, Spandau)"
# to the street component and the citypart components
sub split_street {
    my $street = shift;
    if ($street =~ /^(.*)\s+\(([^\(]+)\)$/) {
	$street = $1;
	my @cityparts = split /\s*,\s*/, $2;
	($street, Citypart => \@cityparts);
    } else {
	($street);
    }
}

# Match-Reihenfolge:
# * nicht modifiziert ohne Agrep
# * "strasse" nach "str." umgewandelt ohne Agrep
# * inkrementell bis $args{Agrep} mit Agrep abwechselnd nicht modifiziert und
#   mit s/strasse/str./
# Argumente in %args:
#   Agrep: 0, wenn grep verwendet werden soll
#          >0, wenn mit Fehlern gesucht werden, dann gibt der Wert die
#              maximale Anzahl der erlaubten Fehler an
#          'default', wenn der Standardwert von 3 Fehlern genommen werden soll
#                     Bei längeren Wörtern wird die Maximalanzahl bis 5 erhöht.
# Sonstige Argumente werden nach look() durchgereicht.
# Ausgabe:
#   erstes Element: siehe look() (als Arrayreferenz)
#   zweites Element: Anzahl der Fehler für das Ergebnis
# Wenn $args{LookCompat} gesetzt ist, dann ist die Ausgabe genau wie bei
# look().
sub look_loop {
    my($self, $str, %args) = @_;
    my $max_agrep;
    if (defined $args{Agrep} && $args{Agrep} eq 'default') {
	$max_agrep = 3;
	# Allow more errors for longer strings:
	if    (length($str) > 15) { $max_agrep = 4 }
	elsif (length($str) > 25) { $max_agrep = 5 }
	delete $args{Agrep};
    } else {
	$max_agrep = delete $args{Agrep} || 0;
    }
    my $strip_strasse = sub {
	my $str = shift;
	if ($str =~ /stra(?:ss|ß)e/i) {
	    $str =~ s/(s)tra(?:ss|ß)e/$1tr./i;
	    $str;
	} else {
	    undef;
	}
    };
    my $strip_hnr = sub {
	my $str = shift;
	if ($str =~ m{\s+(?:\d+[a-z]?|\d+[-/]\d+)\s*$}) {
	    $str =~ s{\s+(?:\d+[a-z]?|\d+[-/]\d+)\s*$}{};
	    $str;
	} else {
	    undef;
	}
    };
    my $expand_strasse = sub {
	my $str = shift;
	my $replaced = 0;
	if ($str =~ /^([US])\s+/i) {
	    $str =~ s/^([US])\s+/uc($1)."-Bhf "/ie;
	    $replaced++;
	} elsif ($str =~ /^([US])-Bahnhof\s+/) {
	    $str =~ s/^([US])-Bahnhof\s+/uc($1)."-Bhf "/ie;
	    $replaced++;
	}
	if ($str =~ /^\s*str\./i) {
	    $str =~ s/^\s*(s)tr\./$1traße/i;
	    $str;
	} elsif ($str =~ /^\s*strasse/i) {
	    $str =~ s/^\s*(s)trasse/$1traße/i;
	    $str;
	} elsif ($replaced) {
	    $str;
	} else {
	    undef;
	}
    };
    my $agrep = 0;
    my @matchref;
    # 1. Try unaltered
    @matchref = $self->look($str, %args);
    if (!@matchref) {
	# 2. Try to strip house number
	if (my $str0 = $strip_hnr->($str)) {
	    @matchref = $self->look($str0, %args);
	}
	# 3. Try to strip "straße" => "str."
	# 3b. Strip house number
	if (!@matchref) {
	    if (my $str0 = $strip_strasse->($str)) {
		@matchref = $self->look($str0, %args);
		if (!@matchref) {
		    if ($str0 = $strip_hnr->($str0)) {
			@matchref = $self->look($str0, %args);
		    }
		}
	    }
	}
	# 4. Try to expand "Str." on beginning of the string
	# 4b. Strip house number
	if (!@matchref) {
	    if (my $str0 = $expand_strasse->($str)) {
		@matchref = $self->look($str0, %args);
		if (!@matchref) {
		    if ($str0 = $strip_hnr->($str0)) {
			@matchref = $self->look($str0, %args);
		    }
		}
	    }
	}
	# 5. Try word match in the middle of the string
	if (!@matchref && length $str >= 4) {
	    my %args = %args;
	    delete $args{Agrep};
	    $args{GrepType} = "grep-inword";
	    @matchref = $self->look($str, %args);
	}
	# 6. Use increasing approximate match. Try first unaltered, then
	#    with stripped street, then without house number.
	if (!@matchref) {
	    $agrep = 1;
	    while ($agrep <= $max_agrep) {
		@matchref = $self->look($str, %args, Agrep => $agrep);
		if (!@matchref && (my $str0 = $strip_strasse->($str))) {
		    @matchref = $self->look($str0, %args, Agrep => $agrep);
		}
		if (!@matchref && (my $str0 = $strip_hnr->($str))) {
		    @matchref = $self->look($str0, %args, Agrep => $agrep);
		}
		{
		    my $str0;
		    if (!@matchref
			&& ($str0 = $strip_strasse->($str))
			&& ($str0 = $strip_hnr->($str0))) {
			@matchref = $self->look($str0, %args, Agrep => $agrep);
		    }
		}
		{
		    my $str0;
		    if (!@matchref
			&& ($str0 = $expand_strasse->($str))
			&& ($str0 = $strip_hnr->($str0))) {
			@matchref = $self->look($str0, %args, Agrep => $agrep);
		    }
		}
		last if @matchref;
		$agrep++;
	    }
	}
    }
    if ($args{LookCompat}) {
	@matchref;
    } else {
	(\@matchref, $agrep);
    }
}

# Sortiert die Straßen eines look_loop-Ergebnisses.
# Argumente und Rückgabewerte sind vom gleichen Format wie bei look_loop.
sub look_loop_best {
    my($self, $str, %args) = @_;
    my $look_compat = delete $args{LookCompat};
    my($matchref, $agrep) = $self->look_loop($str, %args);
    if (@$matchref) {
	my @rating;
	my $str_rx = qr{(?i:^$str)};
	for(my $i=0; $i<=$#$matchref; $i++) {
	    my $item = $matchref->[$i];
	    if ($item->[LOOK_NAME] eq $str) {
		push @rating, [ 100, $item ];
	    } elsif ($item->[LOOK_NAME] =~ $str_rx) {
		push @rating, [ 40 + 40-length($item->[LOOK_NAME]), $item ];
	    } else {
		push @rating, [ 40-length($item->[LOOK_NAME]), $item ];
	    }
	}
	$matchref = [map  { $_->[1] } sort { $b->[0] <=> $a->[0] } @rating];
    }
    if ($look_compat) {
	@$matchref;
    } else {
	($matchref, $agrep);
    }
}

# In: an array of indexes FILE_...
# Out: a hashref $hash->{VAL_INDEX_1}{VAL_INDEX_2}{...} = [$pos1, $pos2, ...]
sub make_any_hash {
    my($self, @indexes) = @_;
    die "Please call the load() method first" if !$self->{Data};
    my %hash;
    my $i = 0;
    foreach my $datarec (@{$self->{Data}}) {
	my $h = \%hash;
	for(my $index_i = 0; $index_i <= $#indexes; $index_i++) {
	    my $field_val = $datarec->[$indexes[$index_i]];
	    if ($index_i == $#indexes) {
		push @{$h->{$field_val}}, $i;
	    } else {
		$h = $h->{$field_val} ||= {};
	    }
	}
	$i++;
    }
    \%hash;
}

sub kill_umlauts {
    my $s = shift;
    $s =~ s/($umlkeys_rx)/$uml{$1}/go;
    $s;
}

sub as_streets {
    my $self = shift;
    my(%args) = @_;
    my $cat = $args{Cat} || 'X';

    my @data;

    if ($self->{DataFmt} ne FMT_COORDS) {
	die "Only PLZ format FMT_COORDS (".FMT_COORDS.") is supported, not " . $self->{DataFmt};
    }
    CORE::open(F, $self->{File}) or die "Can't open $self->{File}: $!";
    while(<F>) {
	chomp;
	my(@f) = split /\|/;
	push @data, $f[FILE_NAME]." (".$f[FILE_CITYPART].", ".$f[FILE_ZIP].")\t$cat ".$f[FILE_COORD]."\n"
	    if defined $f[FILE_COORD] && $f[FILE_COORD] ne '';
    }
    close F;

    require Strassen;
    my $s = Strassen->new_from_data_ref(\@data);
    $s->{File} = $self->{File};
    $s;
}

# convert Strassen.pm object to PLZ.pm data file
# my $new_data = PLZ->new_data_from_streets(new Strassen ...);
sub new_data_from_streets {
    my($class, $s) = @_;
    my $ret = "";
    $s->init;
    while(1) {
	my $r = $s->next;
	last if !@{ $r->[Strassen::COORDS()] };
	my($street, %args) = split_street($r->[Strassen::NAME()]);
	$ret .= "$street$sep";
	if ($args{Citypart}) {
	    $ret .= join(", ", @{ $args{Citypart} });
	}
	$ret .= "$sep$sep";
	$ret .= $r->[Strassen::COORDS()][$#{$r->[Strassen::COORDS()]}/2];
	$ret .= "\n";
    }
    $ret;
}

sub zip_to_cityparts_hash {
    my($self, %args) = @_;
    my $cachebase;
    my $h;
    if ($args{UseCache}) {
	require Strassen::Util;
	require File::Basename;
	$cachebase = "zip_to_cityparts_" . File::Basename::basename($self->{File});
	$h = Strassen::Util::get_from_cache($cachebase, [$self->{File}]);
	if ($h) {
	    warn "Using cache for $cachebase\n" if $VERBOSE;
	    return $h;
	}
    }

    my $hh;
    open(PLZ, $self->{File})
	or die "Die Datei $self->{File} kann nicht geöffnet werden: $!";
    while(<PLZ>) {
	chomp;
	my(@l) = split(/\|/, $_);
	if ($l[FILE_ZIP] ne "" && $l[FILE_CITYPART] ne "") {
	    $hh->{$l[FILE_ZIP]}{$l[FILE_CITYPART]}++;
	}
    }
    close PLZ;

    while(my($k,$v) = each %$hh) {
	$h->{$k} = [keys %$v];
    }

    if (defined $cachebase) {
	Strassen::Util::write_cache($h, $cachebase);
	warn "Wrote cache ($cachebase)\n" if $VERBOSE;
    }
    $h;
}

sub norm_street {
    my $str = shift;
    $str =~ s/(s)tra(?:ss|ß)e$/$1tr\./i; # XXX more?
    $str =~ s/^\s+//;
    $str =~ s/\s+$//;
    $str =~ s/ +/ /g;
    $str;
}

sub streets_hash {
    my $self = shift;
    my %hash;
    open(D, $self->{File}) or die "Can't open $self->{File}: $!";
    my $pos = tell(D);
    while(<D>) {
	chomp;
	/^(.+?)\|/;
	my $l = $1;
	if (!exists $hash{$l}) {
	    $hash{$l} = $pos;
	}
	$pos = tell(D);
    }
    close D;
    \%hash;
}

sub street_words_hash {
    my $self = shift;
    my %hash;
    open(D, $self->{File}) or die "Can't open $self->{File}: $!";
    my $pos = tell(D);
    while(<D>) {
	chomp;
	/^(.+?)\|/;
	my @s = split /\s+/, $1;
	my $h = \%hash;
	for my $i (0 .. $#s) {
	    if (!exists $h->{$s[$i]}) {
		if ($i == $#s) {
		    $h->{$s[$i]} = $pos;
		} else {
		    $h->{$s[$i]} = {};
		    $h = $h->{$s[$i]};
		}
	    } else {
		my $old_h = $h->{$s[$i]};
		if (!UNIVERSAL::isa($old_h, 'HASH')) {
		    $h->{$s[$i]} = {"" => $old_h};
		    $old_h = $h->{$s[$i]};
		}
		if ($i == $#s) {
		    if (!exists $old_h->{""}) {
			$old_h->{""} = $pos;
		    }
		} else {
		    $h = $h->{$s[$i]};
		}
	    }
	}
	$pos = tell(D);
    }
    close D;
    \%hash;
}

# Arguments:
#   $text: string to examine
#   $h: result of street_words_hash
# XXX still a simple-minded solution
sub find_streets_in_text {
    my($self, $text, $h) = @_;
    $h = $self->{StreetWordsHash} if !$h;
    my @res;
    my @s = split /(\s+)/, $text;
    my $begin = 0;
    my $length;
    for(my $i = 0; $i <= $#s; $i+=2) {
	$length = length($s[$i]);
	if ($s[$i] =~ /^(s)tra(?:ss|ß)e$/i) {
	    $s[$i] = "$1tr.";
	}
	my $ii = 0;
	if (exists $h->{$s[$i]}) {
	    my $s = $s[$i];
	    my $hh = $h->{$s[$i]};
	    while (1) {
		if (!UNIVERSAL::isa($hh, 'HASH')) {
		    push @res, [$s, $begin, $length];
		    last;
		}
		if (!exists $hh->{$s[$i+$ii+2]}) {
		    if (exists $hh->{""}) {
			push @res, [$s, $begin, $length];
		    }
		    last;
		}
		$ii+=2;
		$s .= " $s[$i+$ii]";
		$length += length($s[$i+$ii-1]) + length($s[$i+$ii]);
		$hh = $hh->{$s[$i+$ii]};
	    }
	}

	$i += $ii;
	$begin += $length;
	if (defined $s[$i+1]) {
	    $begin += length($s[$i+1]);
	}
    }
    \@res;
}

return 1 if caller();

######################################################################
#
# standalone program
#
package main;
require Getopt::Long;

my $agrep = "default";
my $extern = 1;
my $citypart;
my $multi_citypart = 0;
my $multi_zip = 0;

if (!Getopt::Long::GetOptions
    ("agrep=i" => \$agrep,
     "extern!" => \$extern,
     "citypart=s" => \$citypart,
     "multicitypart!" => \$multi_citypart,
     "multizip!" => \$multi_zip,
     )
   ) {
    die "Usage: $0 [-agrep errors] [-extern] [-citypart citypart]
              [-multicitypart] [-multizip] street
";
}

my $street = shift || die "Street?";

my $plz = PLZ->new;

my @args;
push @args, "Agrep", $agrep;
if (!$extern) {
    push @args, "Noextern", 1;
}
if (defined $citypart and $citypart ne "") {
    push @args, "Citypart", $citypart;
}
if ($multi_citypart) {
    push @args, "MultiCitypart", 1;
}
if ($multi_zip) {
    push @args, "MultiZIP", 1;
}

my($res_ref, $errors) = $plz->look_loop(PLZ::split_street($street), @args);
foreach my $res (@$res_ref) {
    printf "%-40s %-20s %-10s\n", @$res;
}
print "*** Errors: $errors\n";

######################################################################
# Ein Kuriosum in Berlin: sowohl die Waldstr. in Grünau als auch die
# Waldstr. in Schmöckwitz haben die gleiche PLZ 12527. Erschwerend kommt
# hinzu, dass Grünau (früher Köpenick) und Schmöckwitz (früher Treptow)
# heute im gleichen Bezirk liegen. Lösung zurzeit: ignorieren.

# Quick check:
# perl -MData::Dumper -MPLZ -e '$p=PLZ->new;warn Dumper $p->look_loop($ARGV[0], Max => 1, MultiZIP => 1, MultiCitypart => 1, Agrep => "default")' ...
#
# Convert to bbd:
# perl -F'\|' -nale 'print "@F[0,1,2]\tX $F[3]" if $F[3]' Berlin.coords.data > /tmp/plz.bbd

