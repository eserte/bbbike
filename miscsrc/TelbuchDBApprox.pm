# -*- perl -*-

#
# $Id: TelbuchDBApprox.pm,v 1.28 2007/03/20 22:01:46 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001,2003,2006 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

=head1 NAME

TelbuchDBApprox - Geokodierung

=head1 SYNOPSIS

    use TelbuchDBApprox;
    my $tb = TelbuchDBApprox->new(%args);
    my($res) = $tb->search("$street $hnr", $zip, $citypart);

  or

    perl TelbuchDBApprox.pm strasse hausnummer bezirk

=head1 DESCRIPTION

Prerequisite: a Mysql database filled with
L<telefonbuch_strassen2001.pl>.

=over

=cut

BEGIN {
    if (!caller(2)) {
	eval <<'EOF';
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);
EOF
    die $@ if $@;
    }
}

package TelbuchDBApprox;

use strict;
use Geography::Berlin_DE;
use TelbuchApprox; # for split_street and match_plz
use PLZ;
use DBI;
use Karte;
use Encode qw(encode decode);

use vars qw($VERBOSE %exceptions);
use vars qw($msgstr);

sub _enc {
    encode("iso-8859-1", $_[0]);
}

=item new(%args)

Arguments are:

   -multimatchprefer: output multiple matches instead of returning best one

   -approxhnr: approximate house numbers (find closest)

=cut

sub new {
    my $pkg = shift;
    my(%args) = @_;
    my $geo = Geography::Berlin_DE->new;
    my $plz = PLZ->new;

    Karte::preload(':all');

    if ($VERBOSE) {
	$PLZ::VERBOSE = 1;
	$TelbuchApprox::VERBOSE = 1;
    }

    my $self = {Geo => $geo,
		Plz => $plz,
	       };
    bless $self, $pkg;

    if (exists $args{-multimatchprefer}) {
	$self->{MultiMatchPrefer} = delete $args{-multimatchprefer};
    }
    if (exists $args{-approxhnr}) {
	$self->{ApproxHnr} = delete $args{-approxhnr};
    }
    if (%args) {
	die "Unknown parameters: " . join(",", keys %args);
    }

    my $dbh = DBI->connect($self->dsn)
	or die "Cannot connect to " . join(" ", $self->dsn) . ": " . $DBI::error;
    $self->{Dbh} = $dbh;

    my $sel = " select street.name, citypart.name, street_hnr.hnr, street_hnr.longitude, street_hnr.latitude from street";
    my $joins = " left join street_hnr on street.nr = street_hnr.street" .
	        " left join citypart on citypart.nr = street_hnr.citypart";
    my $where_cp_hnr   = " where street.name like ? and street_hnr.hnr like ? and citypart.name like ?";
    my $where_cp_nohnr = " where street.name like ? and citypart.name like ?";
    my $where_hnr      = " where street.name like ? and street_hnr.hnr like ?";
    my $where_nohnr    = " where street.name like ?";

    my $sth_exact = $self->{Dbh}->prepare($sel . $joins . $where_hnr);
    my $sth_nohnr = $self->{Dbh}->prepare($sel . $joins . $where_nohnr);
    my $sth_cp_exact = $self->{Dbh}->prepare($sel . $joins . $where_cp_hnr);
    my $sth_cp_nohnr = $self->{Dbh}->prepare($sel . $joins . $where_cp_nohnr);

    my $sth_all_streets = $self->{Dbh}->prepare("select street.name from street");

    $self->{Sth_exact} = $sth_exact;
    $self->{Sth_nohnr} = $sth_nohnr;
    $self->{Sth_cp_exact} = $sth_cp_exact;
    $self->{Sth_cp_nohnr} = $sth_cp_nohnr;
    $self->{Sth_all_streets} = $sth_all_streets;

    $self->{Fuzzy} = [];

    $self;
}

sub DESTROY {
    my $self = shift;
    $self->{Dbh}->disconnect if $self->{Dbh};
}

sub add_exceptions {
    my($self, $hash) = @_;
    %exceptions = (%exceptions, %$hash);
}

use constant RES_STREET => 0;
use constant RES_CITYPART => 1;
use constant RES_NR => 2;
use constant RES_COORD_X => 3;
use constant RES_COORD_Y => 4;

sub _res2out {
    my($self, $res) = @_;
    my($x,$y) = map { int } $Karte::map{'t2001'}->map2standard($res->[RES_COORD_X],$res->[RES_COORD_Y]);
    return +{
	     Street   => $res->[RES_STREET],
	     Citypart => $res->[RES_CITYPART],
	     Nr       => $res->[RES_NR],
	     Coord    => "$x,$y",
	     OrigCoord => join(",", $res->[RES_COORD_X],$res->[RES_COORD_Y]),
	     (@{$self->{Fuzzy}} ? (Fuzzy => [@{$self->{Fuzzy}}]) : ()),
	    };
}

use enum qw(:TRY_
	    NORMAL APPROX_HNR ECKE DEL_SLASH NO_CITYPART BAHNHOF BHF
	    APPROX APPROX_NO_CITYPART PLZ);
use constant TRY_LAST => TRY_PLZ;

=item search($str, $zip, $city_citypart, %args)

Arguments are:

   $str: street with house number (unless -hnr is specified, see below)

   $zip: PLZ, may be undefined

   $city_citypart: citypart (Bezirk), may be undefined

   -hnr => $housenumber (otherwise house number is in $str)

   -maxtry => $try_nr

=cut

sub search {
    my($self, $str, $zip, $city_citypart, %args) = @_;

    if (defined $zip && $Telefonbuch::Telefonbuch->database ne '98') { # XXX better: can_plz
	if (!$self->{ZipToCityparts}) {
	    $self->{ZipToCityparts} = $self->{Plz}->zip_to_cityparts_hash(UseCache => 1);
	}
    }

    $city_citypart =~ s/B-// if defined $city_citypart;

    my @out;

    my $approx_str; # remembers approx matched string

    my $max_try = $args{-maxtry};
    my $try_nr = -1;
 TRY: {
	while ($try_nr < TRY_LAST) {
	    $try_nr++;

	    last if (defined $max_try && $try_nr > $max_try);

	    my $str = $str;
	    my $city_citypart = $city_citypart;
	    my $hnr;
	    $self->{Fuzzy} = [];

	    if ($try_nr == TRY_ECKE) {
		# Ecke (".../...") feststellen
		if ($str =~ m¦(.*)/(?:\s*(?:Ecke|Nähe)\s+)?(\D.*)¦) {
		    my($str1,$str2) = ($1,$2);
		    my($hnr1,$hnr2);
		    ($str1,$hnr1) = norm_indata($str1);
		    ($str2,$hnr2) = norm_indata($str2);
		    {
			local $^W = 0;
			warn "Search crossing: <$str1><$hnr1> - <$str2><$hnr2>"
			    if $VERBOSE;
		    }
		    my @out1 = $self->search_single($str1,$hnr1,$zip,$city_citypart);
		    if (@out1) {
			my @out2 = $self->search_single($str2,$hnr2,$zip,$city_citypart);
			if (@out2) {
			    my @set1 = map { $_->{Coord} } @out1;
			    my @set2 = map { $_->{Coord} } @out2;

			    {
				local $^W = 0;
				$msgstr = "$str1 $hnr1/$str2 $hnr2";
			    }

			    my($nearest_pair) = find_pair(\@set1, \@set2);
			    if ($nearest_pair) {
				my($x1,$y1,$x2,$y2) =
				    (split(/,/, $nearest_pair->[0]),
				     split(/,/, $nearest_pair->[1]),
				    );
				my($cx,$cy) = map {int} ($x1+($x2-$x1)/2,
							 $y1+($y2-$y1)/2);

				# find corresponding points:
				my($res1, $res2);
				foreach (@out1) {
				    if ($_->{Coord} eq $nearest_pair->[0]) {
					$res1 = $_;
					last;
				    }
				}
				foreach (@out2) {
				    if ($_->{Coord} eq $nearest_pair->[1]) {
					$res2 = $_;
					last;
			    }
				}
				if (!defined $res1 || !defined $res2) {
				    die "Strange: couldn't find points for @$nearest_pair";
				}
				return +{
					 Street => "$res1->{Street}/$res2->{Street}",
					 Citypart => $res1->{Citypart},
					 Coord => "$cx,$cy",
					};
			    }
			}
		    }
		} else {
		    next;
		}
	    } elsif ($try_nr == TRY_DEL_SLASH) {
		# "/..." entfernen
		if ($str =~ m|^(.*)\s*/|) {
		    $str = $1;
		} else {
		    next;
		}
	    } elsif ($try_nr == TRY_NO_CITYPART) {
		undef $city_citypart;
		push @{$self->{Fuzzy}}, "No citypart match";
	    }

	    if ($try_nr == TRY_PLZ) {
	    	my(@res) = $self->TelbuchApprox::match_plz($str, $zip, $city_citypart);
		for (@res) {
		    push @{ $_->{Fuzzy} }, "No housenumber match";
		}
		return @res if @res
	    }

	    if ($try_nr == TRY_BAHNHOF ||
		$try_nr == TRY_BHF) {
		$str =~ s/\bBahnhof$/Bhf./;
		if ($str =~ /\b(U\+S|S\+U)\b/) {
		    # S-Bhf and U-Bhf. are separated in the database,
		    # so choose just one:
		    $str =~ s/\b(U\+S|S\+U)\b/S-Bhf./;
		} elsif ($str =~ s/\b([US])\b/$1-Bhf./) {
		    # done
		} else {
		    next;
		}
	    }

	    if (defined $args{-hnr}) {
		$str = norm_street($str);
		$hnr = norm_hnr($args{-hnr});
	    } else {
		($str,$hnr) = norm_indata($str);
	    }
	    my $hnr_defined = $hnr || "";
	    my $city_citypart_defined = $city_citypart || "";

	    next if (!defined $str || $str eq '');

	    if ($try_nr == TRY_APPROX || $try_nr == TRY_APPROX_NO_CITYPART) {
		if ($try_nr == TRY_APPROX_NO_CITYPART) {
		    undef $city_citypart;
		}
		if (!defined $approx_str) {
		    $approx_str = ($self->match_against_all_streets($str))[0];
		}
		$str = $approx_str;
	    }

	    next if (!defined $str || $str eq '');

	    warn "Street=<$str> Nr=<$hnr_defined> Citypart=<$city_citypart_defined>\n" if $VERBOSE;

	    if (exists $exceptions{$str}) {
		my @fuzzy = @{$self->{Fuzzy}};
		push @fuzzy, "Through exception list";
		if (ref $exceptions{$str}->{$city_citypart_defined} eq 'HASH'){
		    if (exists $exceptions{$str}->{$city_citypart_defined}->{$hnr_defined}) {
			my $coord = $exceptions{$str}->{$city_citypart_defined}->{$hnr_defined};
			@out = {
				Street => $str,
				(defined $hnr ? (Nr => $hnr) : ()),
				(defined $city_citypart ? (Citypart => $city_citypart) : ()),
				Coord => $coord,
				OrigCoord => get_orig_coord($coord),
				Fuzzy => \@fuzzy,
			       };
			last TRY;
		    }
		}
		if (exists $exceptions{$str}->{$hnr_defined}) {
		    my $coord = $exceptions{$str}->{$hnr_defined};
		    @out = {
			    Street => $str,
			    (defined $hnr ? (Nr => $hnr) : ()),
			    Coord  => $coord,
			    OrigCoord => get_orig_coord($coord),
			    Fuzzy => \@fuzzy,
			   };
		    last TRY;
		}
	    }

	    my $tried_super_cp = 0;

	CITYPART_AGAIN:

	    if (defined $hnr &&
		$self->{ApproxHnr} &&
		$try_nr == TRY_APPROX_HNR) {
		local $^W = 0; # no warnings on house numbers like "12a"
		@out = sort { abs($a->{Nr}-$hnr) <=> abs($b->{Nr}-$hnr) }
		    $self->search_single($str, undef, $zip, $city_citypart);
		if (@out) {
		    my $dist = abs($out[0]->{Nr}-$hnr);
		    if ($dist <= 2) {
			if ($dist > 0) {
			    push @{$out[0]->{Fuzzy}}, "ApproxHnr", "Distance: " . $dist;
			}
			@out = $out[0];
			last TRY;
		    } else {
			warn "Too large in approx housenumber: $out[0]->{Nr} vs. $hnr";
		    }
		}
	    }

	    @out = $self->search_single($str, $hnr, $zip, $city_citypart);
	    if (@out) {
		last TRY;
	    }

	    if (!$tried_super_cp) {
		if (defined $city_citypart) {
		    if ($self->{Geo}->subcitypart_to_citypart->{$city_citypart}) {
			$city_citypart = $self->{Geo}->subcitypart_to_citypart->{$city_citypart};
			$tried_super_cp++;
			goto CITYPART_AGAIN;
		    }

		    my @cityparts = $self->{Geo}->get_cityparts_for_supercitypart($city_citypart);
		    if (@cityparts > 1) { # not the citypart itself
			foreach my $citypart (@cityparts) {
			    @out = $self->search_single($str, $hnr, $zip,
							$citypart);
			    if (@out) {
				last TRY;
			    }
			}
		    }
		}
	    }
	}

	warn "*** Nothing found for <$str> <" . ($zip||"") . "> <" . ($city_citypart||"") . ">\n";
    }

    if (@out) {
	# some output warnings
	if ($try_nr == TRY_NO_CITYPART) {
	    warn "*** Citypart <$city_citypart> not matched for <$str>\n";
	}
    }

    @out;
}

sub norm_indata {
    my($str) = @_;
    my $hnr;
    ($str,$hnr) = TelbuchApprox::split_street($str);
    $str = norm_street($str);
    $hnr = norm_hnr($hnr);
    ($str,$hnr);
}

sub norm_street {
    my($str) = @_;
    # XXX move this to split_street???
    if ($str =~ s/(s)tr\./$1traße/ig) {
	$str =~ s/(s)traße(\S)/$1traße $2/ig; # Space nach "Straße" erzwingen
    }
    if ($str =~ s/(p)l\./$1latz/ig) {
	$str =~ s/(p)latz(\S)/$1latz $2/ig; # Space nach "Platz" erzwingen
    }
    $str =~ s/\s+$//; # trim again
    $str;
}

sub norm_hnr {
    my($hnr) = @_;
    if ($hnr =~ /^\s*$/) { undef $hnr }
    $hnr;
}

sub search_single {
    my($self, $str, $hnr, $zip, $city_citypart, %args) = @_;

    my @out;

    my $used_sth;

    if (defined $zip && !defined $city_citypart &&
	$self->{ZipToCityparts} && $self->{ZipToCityparts}->{$zip}) {
	my @city_cityparts = @{ $self->{ZipToCityparts}->{$zip} };
	if (@city_cityparts) {
	    # Sigh ... inconsistency in the data. "Tegel" wird als eigener
	    # Bezirk aufgeführt, aber nicht "Dahlem" :-(
	    for my $try ('SUBCP', 'CP') {
		foreach my $city_citypart (@city_cityparts) {
		    my $real_citypart = $city_citypart;
		    if ($try eq 'SUBCP') {
			my $real_citypart = Geography::Berlin_DE::subcitypart_to_citypart()->{$city_citypart};
			if (!defined $real_citypart) {
			    warn "Ups? No citypart for subcitypart $city_citypart? Reverting to old...";
			    $real_citypart = $city_citypart;
			}
		    }
		    push @out, $self->search_single($str, $hnr, undef, $real_citypart, %args);
		}
		return @out if @out;
	    }
	}
    }

    if (!defined $city_citypart) {
	$used_sth = (!defined $hnr ? $self->{Sth_nohnr} : $self->{Sth_exact});
    } else {
	$used_sth = (!defined $hnr ? $self->{Sth_cp_nohnr} : $self->{Sth_cp_exact});
    }

    $used_sth->execute(_enc($str),
		       defined $hnr ? _enc($hnr) : (),
		       defined $city_citypart ? _enc($city_citypart) : ())
	or die $!;
    if ($used_sth->rows) {
	my @log;
	while(my(@res) = $used_sth->fetchrow_array) {
	    push @log, "@res\n";
	    push @out, $self->_res2out(\@res);
	}
	log_multi(\@log);
	return @out;
    } else {
	$used_sth->finish;
	$used_sth->execute(_enc("$str%"),
			   defined $hnr ? _enc($hnr) : (),
			   defined $city_citypart ? _enc($city_citypart) : ())
	    or die $!;
	if ($used_sth->rows) {
	    my @log;
	    while(my(@res) = $used_sth->fetchrow_array) {
		push @log, "@res\n";
		push @out, $self->_res2out(\@res);
	    }
	    log_multi(\@log);
	    return @out;
	} else {
	    $used_sth->finish;
	}
    }

    ();
}

sub log_multi {
    my($res) = @_;
    return unless $VERBOSE;
    if ($VERBOSE > 1 || scalar @$res < 5) {
	warn "· " . join("· ", @$res);
    } else {
	warn "· " . join("· ", @{$res}[0..4])."...\n";
    }
}

sub get_all_streets {
    my($self) = shift;
    return $self->{AllStreets} if $self->{AllStreets};
    $self->{AllStreets} = [];
    $self->{Sth_all_streets}->execute or die $!;
    while(my($street) = $self->{Sth_all_streets}->fetchrow_array) {
	push @{$self->{AllStreets}}, $street;
    }
    $self->{AllStreets};
}

sub match_against_all_streets {
    my($self, $str) = @_;
    require String::Approx;
    my $all_streets = $self->get_all_streets;
    for my $errors ('nospace', 0..4) {
	warn "Try errors=$errors\n" if $VERBOSE;
	my @m;
	if ($errors eq 'nospace') {
	    (my $nospace_str = $str) =~ s/\s+//g;
	    @m = grep {
		(my $s = $_) =~ s/\s+//g;
		lc($nospace_str) eq lc($s)
	    } @$all_streets;
	} else {
	    @m = String::Approx::amatch($str, [$errors,'i'], @$all_streets);
	}
	if (@m) {
	    if (exists $self->{MultiMatchPrefer}) {
		if ($self->{MultiMatchPrefer} eq 'streets') {
		    @m = map  { $_->[0] }
			 sort { $b->[1] <=> $a->[1] }
			 map  {
			     my $street = $_;
			     my $score = 0;
			     if ($street =~ /^[su]-bhf/i) {
				 $score -= 100;
			     }
			     if ($street =~ /str(\.|a(ss|ß)e)$/i) {
				 $score += 20;
			     }
			     [$street, $score];
			 } @m;
		} else {
		    die "Unhandled value for MultiMatchPrefer: $self->{MultiMatchPrefer}";
		}
	    } else {
		# sort by length
		@m = sort { length($a) <=> length($b) } @m;
		warn "Found matches for <$str>: @m with error $errors\n";
		push @{ $self->{Fuzzy} },
		     "Errors: $errors", "Matches: " . join(", ", @m);
	    }
	    return @m;
	}
    }
    ();
}

# grant all on telbuch.* to 'bbbike'@'localhost' identified by 'bbbike';
sub dsn {
    ("dbi:mysql:telbuch", "bbbike", "bbbike");
}

sub find_pair {
    my(@sets) = @_;

    # brute force approach: double-iterate over all points

    my $nearest_dist;
    my $nearest_pair;

    foreach my $xy1 (@{$sets[0]}) {
	my($x1,$y1) = split /,/, $xy1;
	foreach my $xy2 (@{$sets[1]}) {
	    my($x2,$y2) = split /,/, $xy2;
	    my $dist = sqrt(sqr($x2-$x1) + sqr($y2-$y1));
	    if (!defined $nearest_dist ||
		$dist < $nearest_dist) {
		$nearest_dist = $dist;
		$nearest_pair = ["$x1,$y1", "$x2,$y2"];
	    }
	}
    }

    warn "Distance is ${nearest_dist}m, pair is @$nearest_pair\n" if $VERBOSE;
    if ($nearest_dist > 100) {
	warn "*** Distance between $msgstr is ".int($nearest_dist)."m, maybe too large\n";
    }
    $nearest_pair;
}

# REPO BEGIN
# REPO NAME sqr /home/e/eserte/src/repository 
# REPO MD5 846375a266b4452c6e0513991773b211
sub sqr { $_[0] * $_[0] }
# REPO END

######################################################################
# Interface for bbbike

# Dialog zum Auswahl eines Straße aus der MySQL-Datenbank
### AutoLoad Sub
sub tk_choose {
    my($top, %args) = @_;

    my $batch = (defined $args{'-str'} || defined $args{'-coord'});
    if (!$batch) {
	if ($main::toplevel{"choosedb"} && Tk::Exists($main::toplevel{"choosedb"})) {
	    $main::toplevel{"choosedb"}->deiconify;
	    $main::toplevel{"choosedb"}->raise;
	    return;
	}
    }

    my $tdb = new TelbuchDBApprox
	or die "Can't create TelbuchDBApprox object";

    my $show_sub = sub {
	my($street_obj, $dont_mark, $dont_center) = @_;

	main::IncBusy($top);
	eval {
	    if (!defined $main::str_obj{'s'}) {
		$main::str_obj{'s'} = new Strassen $main::str_file{'s'};
	    }
	    my $s = $main::str_obj{'s'};
	    die "Str ($s)-Objekt?" if !$s;
	    my($street, $bezirk, $points) = @$street_obj;

	    my @t_points;
	    my @labels;
	    foreach my $p_def (@$points) {
		push @t_points,
		    [[ main::transpose($Karte::map{'t2001'}->map2standard($p_def->[1], $p_def->[2])) ]];
	        push @labels, "$street $p_def->[0]";
	    }
	    main::mark_street(-coords => \@t_points, -labels => \@labels,
			      -pointwidth => 9,
			      -clever_center => 1,
			      -dont_center => $dont_center||0
			     );
	};
	if ($@) {
	    main::status_message($@, 'err');
	}
	main::DecBusy($top);
    };


    my($str, $hnr);
    if (0 && defined $args{'-str'}) { # auf Straße zentrieren # Not yet XXX
	$str = $args{'-str'};
	my($matchref);# = $plz->look_loop($str, Agrep => 3, Max => 20);
	my(@match) = @$matchref;
	return if !@match;
	$show_sub->($match[0], 1) if !$args{-noshow};
	return $match[0]->[PLZ::LOOK_COORD()]; # return coords
    } elsif (0 && defined $args{'-coord'}) { # auf Koordinaten zentrieren # Not yet XXX
	mark_point(-coords => [[[ main::transpose(split(/,/, $args{'-coord'})) ]]],
		   -dont_mark => 1);
    } else { # interaktiv
	my $t = $top->Toplevel(-title => main::M("Auswahl aus DB-Liste"),
			       -class => "Bbbike Extended Chooser");
	$t->transient($top) if $main::transient;
	$main::toplevel{"choosedb"} = $t;
	$t->{Tdb} = $tdb;

	my $bf   = $t->Frame->pack(-fill => 'x', -side => "bottom");
	my $strf = $t->Frame->pack(-fill => 'x', -side => "top");

	$strf->Label(-text => main::M('Straße').':'
		    )->pack(-side => "left");
	my $Entry = 'Entry';
	my @extra_args;
	my $this_history_file;
	eval {
	    require Tk::HistEntry;
	    Tk::HistEntry->VERSION(0.37);
	    @extra_args = (-match => 1, -dup => 0, #-case => 0
			  );
	    $Entry = 'HistEntry';
	    $this_history_file = "$main::bbbike_configdir/bbbike_street_hist";
	};
	my $e = $strf->$Entry(-textvariable => \$str,
			      @extra_args,
			      -width => 30)->pack(-side => "left");
	$e->historyMergeFromFile($this_history_file)
	    if $e->can('historyMergeFromFile');

	my $hnr_e = $strf->Entry(-textvariable => \$hnr,
				 -width => 3)->pack(-side => "left");
	$e->focus;
	my $srchb =
	  $strf->Button(Name => 'search',
			-padx => 0,
			-pady => 0,
		       )->pack(-side => "left");
	my $showb;
	my $lb = $t->Scrolled('Listbox',
			      -scrollbars => 'osoe',
			     )->pack(-fill => "x");
	my @match;
	my $show_sub_lb = sub {
	    $show_sub->($match[$lb->index('active')], 0);
	};

	for (qw(Double-1 2)) {
	    $lb->bind("<$_>" => sub {
			  $show_sub->($match
				      [$lb->nearest
				       ($lb->Subwidget('scrolled'
						      )->XEvent->y)], 0);
		      });
	}
	$lb->bind("<3>" =>
		  [sub {
		       my($w, $y) = @_;
		       my $inx = $w->nearest($y);
		       $w->selectionClear(0, "end");
		       $w->selectionSet($inx);
		       $w->activate($inx);
		       $show_sub->($match[$inx], 0, 1);
		   }, Tk::Ev('y')]);

	$t->OnDestroy(sub { delete $main::toplevel{"choosedb"} });
	my $close_window = sub { $t->destroy; };
	my $search_window = sub {
	    $str =~ s/^\s+//;
	    $str =~ s/\s+$//;
	    if ($e->can('historyAdd') &&
		$e->can('historySave')) {
		$e->historyAdd;
		$e->historySave($this_history_file);
	    }

	    main::IncBusy($t);
	    eval {

		@match = ();
		my %res;

	    TRY: {
		    for my $try ("separated", "combined") {
			my $str = $str;
			my $hnr = $hnr;
			if ($try eq 'combined') {
			    if (!defined $hnr || $hnr eq "") {
				($str,$hnr) = TelbuchApprox::split_street($str);
			    } else {
				last TRY;
			    }
			}
			$str =~ s/(str)\.$/$1/i;
			$str .= "%";
			undef $hnr if defined $hnr && $hnr =~ /^\s*$/;
			my $sth = (defined $hnr
				   ? $tdb->{Sth_exact}
				   : $tdb->{Sth_nohnr}
				  );
			$sth->execute(_enc($str), (defined $hnr ? _enc($hnr) : ()))
			    or die $DBI::error;
			while(my @row = $sth->fetchrow_array) {
			    # street.name => citypart.name => list of [hnr, long, lat]
			    push @{ $res{$row[0]}{$row[1]} }, [@row[2 .. 5]];
			}
			$sth->finish;

			if (keys %res) {
			    last TRY;
			}
		    }
		}

		if (!keys %res) {
		    $showb->configure(-state => 'disabled');
		    die main::M("Keine Straßen gefunden.\n");
		} else {
		    while(my($street,$v) = each %res) {
			while(my($citypart,$points) = each %$v) {
			    my @plz = $tdb->get_plz($street, $citypart);
			    push @match, [$street, $citypart, $points, \@plz];
			}
		    }
		    @match = sort { "$a->[0] $a->[1]" cmp "$b->[0] $b->[1]" } @match;
		    $lb->delete(0, 'end');
		    $lb->insert("end", map {
			"$_->[0]" . ($_->[1] ne "" ? " ($_->[1])" : "") .
			    (@{$_->[3]} ? " (".join(",",@{$_->[3]}).")" : "")
		    } @match);
		    $lb->selection('set', 0);
		    $showb->configure(-state => 'normal');
		    $lb->focus;
		}
	    };
	    if ($@) {
		main::status_message($@, 'err');
	    }
	    main::DecBusy($t);
	};
	$e->bind('<Return>' => $search_window);
	$hnr_e->bind('<Return>' => $search_window);
	$srchb->configure(-command => $search_window);
	#$e->bind('<Escape>' => $close_window);
	$e->bind('<<CloseWin>>' => $close_window);
	$showb = $bf->Button
	  (Name => 'show',
	   -state => 'disabled',
	   -command => $show_sub_lb)->grid(-row => 0, -column => 1,
					   -sticky => 'ew');
	$lb->bind('<Return>' => $show_sub_lb);
	$bf->Button(Name => 'close',
		    -command => $close_window)->grid(-row => 0, -column => 2,
						     -sticky => 'ew');
	#$t->Popup(@main::popup_style);
	my($x,$y) = ($main::c->rootx+10, $main::c->rooty+10);
	$t->geometry("+$x+$y");

    }
}

sub get_plz {
    my($self, $str, $citypart) = @_;
    my $plz = $self->{Plz};
    my $geo = $self->{Geo};
    $str = PLZ::norm_street($str);
    my(@res) = $plz->look($str, Citypart => [$geo->get_all_subparts($citypart)]);
    map { $_->[PLZ::FILE_ZIP] } @res;
}

sub get_orig_coord {
    my $std_coord = shift;
    require Karte;
    require Karte::Standard;
    require Karte::T2001;
    join(",", map { int } $Karte::T2001::obj->standard2map(split /,/, $std_coord));
}

return 1 if caller;

package main;

require Getopt::Long;
my %args;
if (!Getopt::Long::GetOptions
    ("v" => sub { $TelbuchDBApprox::VERBOSE = 1 },
     "multimatchprefer=s" => sub { $args{"-multimatchprefer"} = $_[1] },
     "approxhnr" => sub { $args{"-approxhnr"} = 1 },
    )) {
    die "usage: $0 street [number [citypart | zip]]";
}

my($str,$hnr,$citypart_or_zip) = (shift,shift,shift);

my($citypart, $zip);
if ($citypart_or_zip =~ /^\d+$/) {
    $zip = $citypart_or_zip;
} else {
    $citypart = $citypart_or_zip;
}

my $tb = TelbuchDBApprox->new(%args);

if (!defined $str) {
    # get from pipe...
    while(<STDIN>) {
	chomp;
	next if /^\s*$/;
	require Data::Dumper; print Data::Dumper->Dumpxs([ $tb->search($_) ],['res']);
    }
} else {
    require Data::Dumper; print Data::Dumper->Dumpxs([ $tb->search("$str $hnr", $zip, $citypart) ],['res']);
}

=back

=cut

__END__
