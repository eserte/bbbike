# -*- perl -*-

#
# $Id: Cat.pm,v 1.18 2009/02/07 19:52:34 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2006 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# XXX Do not rely on any function/variables here, the API will
# probably change!

package Strassen::Cat;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.18 $ =~ /(\d+)\.(\d+)/);

use File::Basename qw(basename);

use vars qw(%filetype_to_cat %file_to_cat);

%filetype_to_cat =
    (
     "borders"	      => [qw(Z)],
     # XXX Information duplicated in data/Makefile
     "gesperrt"	      => [qw(1 2 3 3nocross),
			  sub { /^0:\d+(:-?\d+)?$/ },
			  sub { /^BNP:\d+(:-?\d+(:trailer=(no|\d+))?)?$/ },
			  sub { /^1s(:q\d)?$/ },
			 ],
     "fragezeichen"   => [qw(? ?? F:? F:??)],
     "handicap"	      => [qw(q0 q1 q2 q3 q4)],
     "landstrassen"   => [qw(B HH H N NN Pl)],
     "mount"   	      => [qw(St Gf CS)],
     "orte"	      => [qw(0 1 2 3 4 5 6)],
     "qualitaet"      => [qw(Q0 Q1 Q2 Q3)],
     "radwege"	      => [qw(RW0 RW1 RW2 RW3 RW4 RW5 RW6 RW7 RW8 RW9 RW10 RW)],
     "rbahn"	      => [qw(R R0 RA RB RC RBau RG RP)],
     "sbahn"	      => [qw(S0 SA SB SC SBau)],
     "sehenswuerdigkeit" => [qw(F:SW SW F:Shop Shop),
			     sub {
				 my $anchor  = qr{\|ANCHOR:[news]};
				 my $img     = qr{IMG:.*(?:gif|png)?($anchor)?};
				 /^((F:)?(?:SW|Shop)(\|$img)?|($img)?)$/
			     },
			    ],
     "strassen"	      => [qw(HH H N NN Pl)],
     "ubahn"	      => [qw(U0 UA UB UC UBau)],
     "wasserstrassen" => [qw(F:I F:W F:W0 F:W1 F:W2 W W0 W1 W2)],
     "*bahnhof_bg"    => [qw(bg bf)],
    );

my %older_file_to_cat =
    ('3.16' => {
		"flaechen" => [qw(F:Ae F:Cemetery F:Forest F:Green
			          F:Industrial F:Orchard F:Mine
			          F:P F:Pabove F:Sport)],
	       }
    );

%file_to_cat =
    ("ampeln"			=> [qw(? B B0 F X Zbr)],
     "berlin"			=> $filetype_to_cat{"borders"},
     "berlin_ortsteile"		=> $filetype_to_cat{"borders"},
     "brunnels"			=> [qw(Br Tu TuBr)],
     "comments_cyclepath"	=> $filetype_to_cat{"radwege"},
     "comments_danger"		=> [qw(CP CS)],
     "comments_ferry"		=> [qw(CS)],
     "comments_kfzverkehr"	=> [qw(-2 -1 +1 +2)],
     "comments_misc"		=> [qw(CP CP2 CS Roundabout MiniRoundabout)],
     "comments_mount"		=> $filetype_to_cat{"mount"},
     "comments_path"		=> [qw(CP CP2 CS PI)],
     "comments_route"		=> [qw(radroute)],
     "comments_scenic"		=> [qw(CS), sub { m{^View:([-+]?\d+):([-+]?\d+)} }], # XXX duplicated as $viewangle_qr in bbbike
     "comments_tram"		=> [qw(CS)],
     "deutschland"		=> $filetype_to_cat{"borders"},
     "exits"			=> [qw(X)],
     "faehren"			=> [qw(Q QQ)], # XXX QQ may be removed again some day
     "flaechen"			=> [qw(F:Ae F:ex-Ae F:Cemetery F:Forest F:Green
				       F:Industrial F:Orchard F:Mine
				       F:P F:Pabove F:Sport)],
     "fragezeichen"		=> $filetype_to_cat{"fragezeichen"},
     "fragezeichen-cooked"	=> $filetype_to_cat{"fragezeichen"},
     "gesperrt"			=> $filetype_to_cat{"gesperrt"},
     "gesperrt_car"		=> [@{$filetype_to_cat{"gesperrt"}}, "2:Anlieger"], # XXX Anlieger -> TBD
     "gesperrt_r"		=> $filetype_to_cat{"gesperrt"},
     "gesperrt_s"		=> $filetype_to_cat{"gesperrt"},
     "gesperrt_u"		=> $filetype_to_cat{"gesperrt"},
     "green"			=> [qw(green1 green2)],
     "grenzuebergaenge"         => [qw(GU)],
     "handicap_l"		=> $filetype_to_cat{"handicap"},
     "handicap_s"		=> $filetype_to_cat{"handicap"},
     "hoehe"			=> [qw(X XXX ? ???)],
     "housenumbers"		=> [qw(HNR)],
     "kneipen"			=> [qw(X)],
     "label"			=> [sub { /^(90)?([ns][ew]?|[ew])$/ }],
     "landstrassen"		=> $filetype_to_cat{"landstrassen"},
     "landstrassen-cooked"	=> $filetype_to_cat{"landstrassen"},
     "landstrassen2"		=> $filetype_to_cat{"landstrassen"},
     "landstrassen2-cooked"	=> $filetype_to_cat{"landstrassen"},
     "mount"			=> $filetype_to_cat{"mount"},
     "nolighting"		=> [qw(NL)],
     "obst"			=> [qw(X)],
     "orte"			=> $filetype_to_cat{"orte"},
     "orte2"			=> $filetype_to_cat{"orte"},
     "orte_city"		=> $filetype_to_cat{"orte"},
     "plaetze"			=> [qw(Pl)],
     "plz"			=> $filetype_to_cat{"borders"},
     "potsdam"			=> $filetype_to_cat{"borders"},
     "qualitaet_s"		=> $filetype_to_cat{"qualitaet"},
     "qualitaet_l"		=> $filetype_to_cat{"qualitaet"},
     "radwege"			=> $filetype_to_cat{"radwege"},
     "radwege_exact"		=> $filetype_to_cat{"radwege"},
     "rbahn"			=> $filetype_to_cat{"rbahn"},
     "rbahnhof"			=> $filetype_to_cat{"rbahn"},
     "sbahn"			=> $filetype_to_cat{"sbahn"},
     "sbahnhof"			=> $filetype_to_cat{"sbahn"},
     "sbahnhof_bg"		=> $filetype_to_cat{"*bahnhof_bg"},
     "sehenswuerdigkeit"	=> $filetype_to_cat{"sehenswuerdigkeit"},
     "strassen"			=> $filetype_to_cat{"strassen"},
     "strassen-cooked"		=> $filetype_to_cat{"strassen"},
     "strassen_bab"		=> [qw(BAB)],
     "ubahn"			=> $filetype_to_cat{"ubahn"},
     "ubahnhof"			=> $filetype_to_cat{"ubahn"},
     "ubahnhof_bg"		=> $filetype_to_cat{"*bahnhof_bg"},
     "vorfahrt"			=> [qw(X)],
     "wasserstrassen"		=> $filetype_to_cat{"wasserstrassen"},
     "wasserstrassen-lowres"	=> $filetype_to_cat{"wasserstrassen"},
     "wasserumland"		=> $filetype_to_cat{"wasserstrassen"},
     "wasserumland2"		=> $filetype_to_cat{"wasserstrassen"},
    );

sub _normalize_filename {
    my($filename) = @_;
    $filename =~ s{-orig$}{};
    $filename = basename $filename;
    $filename;
}

sub get_validity_checker {
    my($filename, %args) = @_;
    my $bbbike_version = delete $args{BBBikeVersion};
    die "Unhandled arguments: " . join(" ", %args) if %args;

    $filename = _normalize_filename($filename);
    my $allowed_cats;
    if (defined $bbbike_version && exists $older_file_to_cat{$bbbike_version}->{$filename}) {
	$allowed_cats = $older_file_to_cat{$bbbike_version}->{$filename};
    } elsif (exists $file_to_cat{$filename}) {
	$allowed_cats = $file_to_cat{$filename};
    }
    if ($allowed_cats) {
	my %cat;
	my @code;
	for my $elem (@$allowed_cats) {
	    if (ref $elem eq 'CODE') {
		push @code, $elem;
	    } else {
		$cat{$elem} = 1;
	    }
	}
	return { cat  => \%cat,
		 code => \@code,
	       };
    } else {
	warn "Cannot get validity checker for $filename";
	undef;
    }
}

sub get_static_categories {
    my($filename) = @_;
    $filename = _normalize_filename($filename);
    if (exists $file_to_cat{$filename}) {
	grep { ref $_ ne 'CODE' } @{ $file_to_cat{$filename} };
    } else {
	();
    }
}

sub check_cat {
    my($cat, $checker, $msgref) = @_;
    my(@cat) = $cat =~ m{^(.*);(.*)$};
    if (!@cat) {
	@cat = $cat;
    }
    for my $_cat (@cat) {
	$_cat =~ s{^(.+?)::.*$}{$1}; # XXX will change
    }
    for my $_cat (@cat) {
	$_cat =~ s{::?inwork$}{}; # XXX will probably change, too
    }
    my @msg;
 CHECK_CAT: {
	for my $_cat (@cat) {
	    next CHECK_CAT if $_cat eq '';
	    next CHECK_CAT if exists $checker->{cat}{$_cat};
	    for my $code (@{ $checker->{code} }) {
		local $_ = $_cat;
		next CHECK_CAT if $code->();
	    }
	    push @msg, "$_cat not valid";
	}
    }
    if (@msg && $msgref) {
	@$msgref = @msg;
    }
    @msg ? 0 : 1;
}

sub check_file {
    my($f, %args) = @_;
    my $bbbike_version = delete $args{BBBikeVersion};
    die "Unhandled arguments: " . join(" ", %args) if %args;

    my $checker = get_validity_checker($f, BBBikeVersion => $bbbike_version);
    if (!$checker) {
	warn "Cannot get validity checker for $f";
	return 0;
    }
    require Strassen::Core;
    my $s = Strassen->new($f);
    $s->init;
    my $errors = 0;
    while() {
	my $ret = $s->next;
	last if !@{ $ret->[Strassen::COORDS()] };
	my $cat = $ret->[Strassen::CAT()];
	my @msg;
	my $check_ret = check_cat($cat, $checker, \@msg);
	if (!$check_ret) {
	    $errors++;
	    warn "Errors in line " . $s->pos . ", category <$cat>: @msg\n";
	    if (defined $bbbike_version) {
		warn "Note that checks were done for BBBike version $bbbike_version.\n";
	    }
	}
    }

    $errors ? 0 : 1;
}

sub carry_penalty_for_special_vehicle {
    my($penalty, $special_vehicle) = @_;
    # XXX currently assume a constant factor for all carry
    # situations. Maybe this should be overridable using
    # addinfo?
    if ($special_vehicle eq 'trailer') {
	$penalty * 5;
    } elsif ($special_vehicle eq 'childseat') {
	$penalty * 3;
    } else {
	$penalty;
    }
}

1;

__END__
