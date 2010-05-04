# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 1998, 2000, 2001, 2002, 2003, 2004, 2010 Slaven Rezic. All rights reserved.
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
use Strassen::Strasse;

$VERSION = 1.76;

use constant FMT_NORMAL            => 0; # /usr/www/soc/plz/Berlin.data
use constant FMT_REDUCED           => 1; # ./data/Berlin.small.data (does not exist anymore)
use constant FMT_COORDS            => 2; # ./data/Berlin.coords.data
use constant FMT_COORDS_WITH_INDEX => 3; # PLZ::Multi with -addindex option

# agrep says that 32 is the max length, but experiments show something else:
use constant AGREP_LONGEST_RX => 29;

$PLZ_BASE_FILE = "Berlin.coords.data" if !defined $PLZ_BASE_FILE;

# XXX use BBBikeUtil::bbbike_root().'/data'!!!
@plzfile =
  ((map { "$_/$PLZ_BASE_FILE" } @Strassen::datadirs),
   BBBikeUtil::bbbike_root().'/data/'.$PLZ_BASE_FILE,
   (map { ("$_/$PLZ_BASE_FILE", "$_/data/$PLZ_BASE_FILE") } @INC),
   (map { ("$_/berlinco.dat",
	   "$_/Berlin.data",        "$_/data/Berlin.data") } @INC),
  ) if !@plzfile;
$OLD_AGREP = 0 unless defined $OLD_AGREP;
# on FreeBSD is
#    ports/textproc/agrep => agrep 2.04 with buggy handling of umlauts
#    ports/textproc/glimpse => agrep 3.0

# indexes of file fields
use constant FILE_NAME     => 0;
use constant FILE_CITYPART => 1;
use constant FILE_ZIP      => 2; # this is not valid for FMT_NORMAL
use constant FILE_COORD    => 3;
use constant FILE_INDEX    => 4;
use constant FILE_STRTYPE  => 5; # This is a placeholder, and not implemented now!

use constant FILE_ZIP_FMT_NORMAL => 4; # this is only valid for FMT_NORMAL

$sep = '|';

use constant SA_ANCHOR_LENGTH => 3; # use 0 to turn off String::Approx anchor hack
use constant SA_ANCHOR_HACK   => "ÿ" x SA_ANCHOR_LENGTH; # use a rare character

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
	    last if defined $file;
	}
    } elsif (defined $file) {
	open(DATA, $file) or return undef;
    } else {
	return undef;
    }

    binmode DATA;
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
    } elsif (@l == 5) {
	$self->{DataFmt}  = FMT_COORDS_WITH_INDEX;
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
	binmode PLZ;

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
	} elsif ($self->{DataFmt} == FMT_COORDS_WITH_INDEX) {
	    $push_code = q{push @data,
			   [@l[FILE_NAME, FILE_CITYPART, FILE_ZIP, FILE_COORD, FILE_INDEX]]};
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
	$self->{DataFmt} == FMT_COORDS ||
	$self->{DataFmt} == FMT_COORDS_WITH_INDEX) {
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
use constant LOOK_INDEX    => 4;
use constant LOOK_STRTYPE  => 5; # This is a placeholder, and not implemented now!

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

    # Windows usually does not have grep and agrep externally
    if ($^O eq 'MSWin32' && !exists $args{Noextern}) {
	$args{Noextern} = 1;
    }

    print STDERR "->look($str, " . join(" ", %args) .") in '$file'\n" if $VERBOSE;

    #XXX use fgrep instead of grep? slightly faster, no quoting needed!
    my $grep_type = ($args{Agrep} ? 'agrep' : ($args{GrepType} || 'grep'));
    my @push_inx;
    if      ($self->{DataFmt} == FMT_NORMAL) {
	@push_inx = (FILE_NAME, FILE_CITYPART, $self->{FieldPLZ});
    } elsif ($self->{DataFmt} == FMT_REDUCED) {
	@push_inx = (FILE_NAME, FILE_CITYPART, FILE_ZIP);
    } elsif ($self->{DataFmt} == FMT_COORDS_WITH_INDEX) {
	@push_inx = (FILE_NAME, FILE_CITYPART, FILE_ZIP, FILE_COORD, FILE_INDEX);
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
	if (($args{MultiCitypart}||
	     $to_push[FILE_CITYPART] eq "" ||
	     !exists $res{$to_push[FILE_NAME]}->{$to_push[FILE_CITYPART]}) &&
	    ($args{MultiZIP}     ||
	     $to_push[FILE_ZIP] eq "" ||
	     !exists $res{$to_push[FILE_NAME]}->{$to_push[FILE_ZIP]})
	   ) {
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
	    } else { # agrep
		$str =~ s/([\$\^\*\[\]\^\|\(\)\!\`\,\;])/\\$1/g;
	    }
	    $str = "^$str";
	}

	# limitation of agrep:
	if ($grep_type eq 'agrep' && length($str) > AGREP_LONGEST_RX) {
	    $str = substr($str, 0, AGREP_LONGEST_RX);
	    $str =~ s/\\$//; # remove a (lonely?) backslash at the end
	    # XXX but this will be wrong if it's really a \\
	}

	if (eval { require Encode; Encode::is_utf8($str) }) {
	    $str = Encode::encode("iso-8859-1", $str);
	}
	my(@grep_args) = ('-i', $str, $file);
	if ($grep_type eq 'agrep' && $args{Agrep}) {
	    unshift @grep_args, "-$args{Agrep}";
	}
	my @cmd = ($grep_type, @grep_args);
	warn "About to call <@cmd>" if $VERBOSE;
	CORE::open(PLZ, "-|") or do {
	    $ENV{LANG} = $ENV{LC_ALL} = $ENV{LC_CTYPE} = 'C';
	    # agrep emits some warnings "using working-directory '...'
	    # to locate dictionaries" if it does not have a $ENV{HOME}
	    # (which is probably a bug, because dictionaries are not
	    # used at all)
	    $ENV{HOME} = "/something";
	    exec @cmd;
	    warn "While doing @cmd: $!";
	    require POSIX;
	    POSIX::_exit(1); # avoid running any END blocks
	};
	my %res;
	binmode PLZ;
	while(<PLZ>) {
	    chomp;
	    $push_sub->($_);
	}
	close PLZ;
    } else {
	CORE::open(PLZ, $file)
	  or die "Die Datei $file kann nicht geöffnet werden: $!";
	binmode PLZ;
	if ($grep_type eq 'agrep') {
	    chomp(my @data = <PLZ>);
	    close PLZ;
	    my %res;
	    if (@data) {
		foreach (map { substr $_, SA_ANCHOR_LENGTH }
			 String::Approx::amatch(SA_ANCHOR_HACK . $str,
						['i', $args{Agrep}],
						map { SA_ANCHOR_HACK . $_ } @data)) {
		    $push_sub->($_);
		}
	    }
	} elsif ($grep_type =~ m{^grep-(umlaut|inword|substr)$}) {
	    my $sub_type = $1;
	    if ($sub_type eq 'umlaut') {
		$str = '(?i:^' . quotemeta(BBBikeUtil::umlauts_to_german($str)) . ')';
	    } elsif ($sub_type eq 'inword') {
		$str = '(?i:\b' . quotemeta(BBBikeUtil::umlauts_to_german($str)) . '\b)';
	    } elsif ($sub_type eq 'substr') {
		$str = '(?i:' . quotemeta(BBBikeUtil::umlauts_to_german($str)) . ')';
	    }
	    $str = qr{$str};
	    while(<PLZ>) {
		chomp;
		if (BBBikeUtil::umlauts_to_german($_) =~ $str) {
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
	    $rx = "^(?i:" . join("|", map {quotemeta($_)} @{ $args{Citypart} }) . ")";
	} else {
	    $rx = "^(?i:" . quotemeta($args{Citypart}) . ")";
	}
	my $need_utf8_upgrade = defined &utf8::is_utf8 && utf8::is_utf8($rx);
	$rx = qr{$rx};
	my @new_res;
	foreach (@res) {
	    my $citypart = $_->[LOOK_CITYPART];
	    # This is needed for something which smells like a perl
	    # bug, apparent from 5.8.8 over 5.10.1 to 5.11.4. If $rx
	    # is utf8-flagged and contains a "ß", then the regexp does
	    # not match. See the Gustav-Adolf-Str. (Weißensee) test in
	    # plz.t
	    utf8::upgrade($citypart) if $need_utf8_upgrade;
	    if ($citypart =~ /$rx/ ||
		$_->[$self->{FieldPLZ}] =~ /$rx/) {
		push @new_res, $_;
	    }
	}
	@res = @new_res;
    }

    @res;
}

# Argument: an array of references (the output of look())
# Combine streets which are probably the same (same coord, same citypart
# and/or same
# zip code)
# Returned value has the same format as the input
sub combine {
    my($self, @in) = @_;
    my %out;
    my @copy_indexes = (LOOK_NAME, LOOK_COORD);
    if ($self->{DataFmt} eq FMT_COORDS_WITH_INDEX) {
	push @copy_indexes, LOOK_INDEX;
    }
 CHECK_IT:
    foreach my $s (@in) {
	if (exists $out{$s->[LOOK_NAME]}) {
	    foreach my $r (@{ $out{$s->[LOOK_NAME]} }) {
		my $eq_coord = $s->[LOOK_COORD] && $s->[LOOK_COORD] eq $r->[LOOK_COORD];
		my $eq_cp = grep { $s->[LOOK_CITYPART] eq $_ } grep { $_ ne "" } @{ $r->[LOOK_CITYPART] };
		my $eq_zp = grep { $s->[LOOK_ZIP]      eq $_ } grep { $_ ne "" } @{ $r->[LOOK_ZIP] };
		if ($eq_cp || $eq_zp || $eq_coord) {
		    push @{ $r->[LOOK_CITYPART] }, $s->[LOOK_CITYPART]
			unless $eq_cp;
		    push @{ $r->[LOOK_ZIP] }, $s->[LOOK_ZIP]
			unless $eq_zp;
		    next CHECK_IT;
		}
	    }
	}
	# does not exist or is a new citypart/zip combination
	my $r = [];
	$r->[$_] = $s->[$_] for (@copy_indexes);
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
    my @copy_indexes = (LOOK_NAME, LOOK_COORD);
    if ($self->{DataFmt} eq FMT_COORDS_WITH_INDEX) {
	push @copy_indexes, LOOK_INDEX;
    }
    my $r = [];
    $r->[$_] = $elem->[$_] for (@copy_indexes);
    $r->[LOOK_CITYPART] = join(", ", @{$elem->[LOOK_CITYPART]});
    $r->[LOOK_ZIP]      = join(", ", @{$elem->[LOOK_ZIP]});
    $r;
}

# Split a street specification like "Heerstr. (Charlottenburg, Spandau)"
# to the street component and the citypart components
sub split_street {
    my $street = shift;
    my @cityparts;
    ($street, @cityparts) = Strasse::split_street_citypart($street);
    if (@cityparts) {
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

    my $agrep = 0;
    my @matchref;
    # 1. Try unaltered
    @matchref = $self->look($str, %args);
    if (!@matchref) {
	# 2. Try to strip house number
	if (my $str0 = _strip_hnr($str)) {
	    @matchref = $self->look($str0, %args);
	}
	# 3. Try to strip "straße" => "str."
	# 3b. Strip house number
	if (!@matchref) {
	    if (my $str0 = _strip_strasse($str)) {
		@matchref = $self->look($str0, %args);
		if (!@matchref) {
		    if ($str0 = _strip_hnr($str0)) {
			@matchref = $self->look($str0, %args);
		    }
		}
	    }
	}
	# 4. Try to expand "Str." on beginning of the string
	# 4b. Strip house number
	if (!@matchref) {
	    if (my $str0 = _expand_strasse($str)) {
		@matchref = $self->look($str0, %args);
		if (!@matchref) {
		    if ($str0 = _strip_hnr($str0)) {
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
		if (!@matchref && (my $str0 = _strip_strasse($str))) {
		    @matchref = $self->look($str0, %args, Agrep => $agrep);
		}
		if (!@matchref && (my $str0 = _strip_hnr($str))) {
		    @matchref = $self->look($str0, %args, Agrep => $agrep);
		}
		{
		    my $str0;
		    if (!@matchref
			&& ($str0 = _strip_strasse($str))) {
			@matchref = $self->look($str0, %args, Agrep => $agrep);
			if (!@matchref
			    && ($str0 = _strip_hnr($str0))) {
			    @matchref = $self->look($str0, %args, Agrep => $agrep);
			}
		    }
		}
		{
		    my $str0;
		    if (!@matchref
			&& ($str0 = _expand_strasse($str))) {
			@matchref = $self->look($str0, %args, Agrep => $agrep);
			if (!@matchref
			    && ($str0 = _strip_hnr($str0))) {
			    @matchref = $self->look($str0, %args, Agrep => $agrep);
			}
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

sub _strip_strasse {
    my $str = shift;
    if ($str =~ /stra(?:ss|ß)e/i) {
	$str =~ s/(s)tra(?:ss|ß)e/$1tr./i;
	$str;
    } else {
	undef;
    }
}

sub _strip_hnr {
    my $str = shift;
    # This strips input like "Straße 1a" or "Straße 1-2". Maybe
    # also strip "Straße 1 a"? XXX
    if ($str =~ m{\s+(?:\d+[a-z]?|\d+\s*[-/]\s*\d+)\s*$}) {
	$str =~ s{\s+(?:\d+[a-z]?|\d+\s*[-/]\s*\d+)\s*$}{};
	$str;
    } else {
	undef;
    }
}

sub _expand_strasse {
    my $str = shift;
    my $replaced = 0;
    if      ($str =~ s/^(U\+S|S\+U)[- ](?:Bahnhof|Bhf\.?)\s+/S-Bhf /i) { # Choose one
	$replaced++;
    } elsif ($str =~ s/^(U\+S|S\+U)\s+/S-Bhf /i) { # Choose one
	$replaced++;
    } elsif ($str =~ s/^([US])[- ](?:Bahnhof|Bhf\.)\s+/uc($1)."-Bhf "/ie) {
	$replaced++;
    } elsif ($str =~ s/^([US])\s+/uc($1)."-Bhf "/ie) {
	$replaced++;
    }
    if      ($str =~ s/^(k)l\.?\s+(.*str)/$1leine $2/i) {
	$replaced++;
    } elsif ($str =~ s/^(g)r\.?\s+(.*str)/$1roße $2/i) {
	$replaced++;
    }
    if ($str =~ /^\s*str\.(\S)?/i) {
	if (defined $1) {	# add space
	    $str =~ s/^\s*(s)tr\./$1traße /i;
	} else {
	    $str =~ s/^\s*(s)tr\./$1traße/i;
	}
	$replaced++;
	$str;
    } elsif ($str =~ s/^\s*(s)trasse/$1traße/i) {
	$replaced++;
	$str;
    } elsif ($replaced) {
	$str;
    } else {
	undef;
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

sub as_streets {
    my $self = shift;
    my(%args) = @_;
    my $cat = $args{Cat} || 'X';

    my @data;

    if ($self->{DataFmt} ne FMT_COORDS) {
	die "Only PLZ format FMT_COORDS (".FMT_COORDS.") is supported, not " . $self->{DataFmt};
    }
    CORE::open(F, $self->{File}) or die "Can't open $self->{File}: $!";
    binmode F;
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
    binmode PLZ;
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
    binmode D;
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
    binmode D;
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

sub get_street_type {
    my($self, $look_result) = @_;
    if (defined $look_result->[LOOK_STRTYPE]) { # This is not yet defined, but maybe some day?
	$look_result->[LOOK_STRTYPE];
    } else {
	my $name = $look_result->[LOOK_NAME];
	if      ($name =~ m{(^Kolonie\s
			    |^KGA\s
			    |\s\(Kolonie\)$
			    )}x) {
	    return 'orchard';
	} elsif ($name =~ m{^[SU]-Bhf\s}) {
	    return 'railway station';
	} elsif ($name =~ m{\s\(Gaststätte\)$}) {
	    return 'restaurant';
	} elsif ($name =~ m{\s\(Siedlung\)$}) {
	    return 'settlement'; # XXX English wording?
	} elsif ($name =~ m{(?:^Insel\s|\s\(Insel\)$)}) {
	    return 'island';
	} elsif ($name =~ m{\s\(geplant\)$}) {
	    return 'projected street';
	} else {
	    return 'street';
	}
    }
}

# This method may be removed or renamed one day!
sub _populate_street_type {
    my($self, $look_result) = @_;
    my $type = $self->get_street_type($look_result);
    $look_result->[LOOK_STRTYPE] = $type;
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
my $grep_type;

if (!Getopt::Long::GetOptions
    ("agrep=i" => \$agrep,
     "extern!" => \$extern,
     "citypart=s" => \$citypart,
     "multicitypart!" => \$multi_citypart,
     "multizip!" => \$multi_zip,
     "greptype=s" => \$grep_type,
     "v!" => \$PLZ::VERBOSE,
     )
   ) {
    die "Usage: $0 [-v] [-agrep errors] [-greptype grep-inword|grep-umlaut|...]
	      [-extern] [-citypart citypart]
              [-multicitypart] [-multizip] street
";
}

my $street = shift || die "Street?";

my $plz = PLZ->new;

my @args;
push @args, "Agrep", $agrep;
if ($grep_type) {
    push @args, "GrepType", $grep_type;
}
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
    printf "%-40s %-20s %-10s (%s)\n", @$res;
}
print "*** Errors: $errors\n";

######################################################################
# Ein Kuriosum in Berlin: sowohl die Waldstr. in Grünau als auch die
# Waldstr. in Schmöckwitz haben die gleiche PLZ 12527. Erschwerend kommt
# hinzu, dass Grünau (früher Köpenick) und Schmöckwitz (früher Treptow)
# heute im gleichen Bezirk liegen. Lösung zurzeit: ignorieren.

# Weiterer Fall: es gibt zweimal den Mittelweg, PLZ 12524, aber in
# unterschiedlichen Stadtteilen im gleichen Bezirk: Altglienicke und
# Bohnsdorf

# Quick check:
# perl -Ilib -MData::Dumper -MPLZ -e '$p=PLZ->new;warn Dumper $p->look_loop($ARGV[0], Max => 1, MultiZIP => 1, MultiCitypart => 1, Agrep => "default")' ...
#
# Convert to bbd:
# perl -F'\|' -nale 'print "@F[0,1,2]\tX $F[3]" if $F[3]' Berlin.coords.data > /tmp/plz.bbd

