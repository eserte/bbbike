#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: winter_optimization.pl,v 1.4 2005/03/15 20:49:53 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004,2010 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../data",
	);
use Strassen;
eval 'use BBBikeXS';
#use Hash::Util qw(lock_keys);
use Getopt::Long;
use Storable qw(store);
use Fcntl qw(LOCK_EX LOCK_NB);

my $do_display = 0;
my $one_instance = 0;
my $winter_hardness = 'snowy';

if (!GetOptions("display" => \$do_display,
		"one-instance" => \$one_instance,
		"winter-hardness=s" => \$winter_hardness,
	       )) {
    die "usage: $0 [-display] [-one-instance] [-winter-hardness snowy|very_snowy|dry_cold]\n";
}

# compat for old integers
if ($winter_hardness eq '1') {
    $winter_hardness = 'snowy';
} elsif ($winter_hardness eq '2') {
    $winter_hardness = 'very_snowy';
}

my %usability_desc =
    ($winter_hardness eq 'snowy'
     ? (cat_to_usability => { NN => 1,
			      N  => 3,
			      NH => 4,
			      H  => 5,
			      HH => 6,
			      B  => 6,
			    },
	do_kfz_adjustment  => 1, # use -2/-1/+1/+2 adjustment from comments_kfzverkehr
	do_cobblestone_opt => 1,
	do_tram_opt        => 1,
       )
     : $winter_hardness eq 'very_snowy'
     ? (cat_to_usability => { NN => 1,
			      N  => 2,
			      NH => 4,
			      H  => 5,
			      HH => 6,
			      B  => 6,
			    },
	do_kfz_adjustment  => 1, # use -2/-1/+1/+2 adjustment from comments_kfzverkehr
	do_cobblestone_opt => 1,
	do_tram_opt        => 1,
       )
     : $winter_hardness eq 'dry_cold'
     ? (cat_to_usability => { NN => 1, # dry but icy cyclepaths
			      N  => 6,
			      NH => 6,
			      H  => 6,
			      HH => 6,
			      B  => 6,
			    },
	do_kfz_adjustment  => 0,
	do_cobblestone_opt => 0,
	do_tram_opt        => 0,
       )
     : die "winter-hardness should be snowy, very_snowy, or dry_cold"
    );
my %cat_to_usability   = %{ $usability_desc{cat_to_usability} };
my $do_cobblestone_opt =    $usability_desc{do_cobblestone_opt};
my $do_kfz_adjustment  =    $usability_desc{do_kfz_adjustment};
my $do_tram_opt        =    $usability_desc{do_tram_opt};
my $do_cyclepath_opt   = 0; # Bei Winterwetter können Radwege komplett ignoriert werden
my $do_bridge_opt      = 0; # I don't think anymore bridges are critical (and mostly if you have to use one, then usually you cannot avoid it at all)

my $outfile = "$FindBin::RealBin/../tmp/winter_optimization." . $winter_hardness . ".st";

my $lock_file = "/tmp/winter_optimization.lck";
if ($one_instance) {
    open(LCK, "> $lock_file");
    if (!flock LCK, LOCK_EX|LOCK_NB) {
	warn "winter_optimization process running, waiting for lock...\n";
	flock LCK, LOCK_EX;
	if (!-e $outfile) {
	    die "$outfile was not built?";
	}
	warn "release lock, assume $outfile is built\n";
	exit 0;
    }
}

my $strassen_orig = "$FindBin::RealBin/../data/strassen-orig";

my %str;
if (-r $strassen_orig) {
    my($strassen_with_NH_file) = create_strassen_with_NH();
    $str{"s"} = Strassen->new($strassen_with_NH_file);
} else {
    $str{"s"} = Strassen->new("strassen");
}

if ($do_bridge_opt) {
    $str{"br"} = Strassen->new("brunnels");
}
$str{"qs"} = Strassen->new("qualitaet_s");
if ($do_cyclepath_opt) {
    $str{"rw"} = Strassen->new("radwege_exact");
}
if ($do_kfz_adjustment) {
    $str{"kfz"} = Strassen->new("comments_kfzverkehr");
}
if ($do_tram_opt) {
    $str{"tram"} = Strassen->new("comments_tram");
}
#lock_keys %str;

my %net;
for my $type (keys %str) {
    $net{$type} = StrassenNetz->new($str{$type});
    my %args = (-usecache => 1);
    if ($type =~ /^(s|qs)$/) {
	$args{-net2name} = 1;
    }
    if ($type eq 's') {
	$args{-multiple} = 1;
    }
    if ($type eq 'rw') {
	$args{-obeydir} = 1;
    }
    $net{$type}->make_net_cat(%args);
}
#lock_keys %net;

my $net = {};

while(my($k1,$v) = each %{ $net{"s"}->{Net} }) {
    while(my($k2,$cat) = each %$v) {
	#my($xxx) = $net{"s"}->get_street_record($k1, $k2); next if $xxx->[Strassen::NAME] !~ /admiralbrücke/i;#XXX

        my $res = 99999;
	my @reason;

    CALC: {
	    my $quality_penalty = 0;
	    if ($do_cobblestone_opt) {
		my $q = $net{"qs"}->{Net}{$k1}{$k2};
		if (defined $q) {
		    if ($q =~ /^Q(\d+)/) {
			my $cat = $1;
			my $rec = $net{"qs"}->get_street_record($k1, $k2);
			if ($rec->[Strassen::NAME] =~ /(kopfstein|verbundstein)/i) {
			    if ($cat =~ /^3/) {
				$res = 0;
				push @reason, "Schlechtes Kopfsteinpflaster";
				last CALC;
			    } else {
				$res = 1;
				push @reason, "Kopfsteinpflaster";
			    }
			} elsif ($cat ne "0") {
			    $quality_penalty = 1;
			    push @reason, "Quality penalty";
			}
		    }
		}
	    }

	    if ($do_cyclepath_opt) {
		my $rw = $net{"rw"}->{Net}{$k1}{$k2};
		if (defined $rw) {
		    if ($rw =~ /^RW(2|8|)$/) {
			$res = 1;
			push @reason, "Radweg";
		    }
		}
	    }

	    my $main_cat;
	    my $is_bridge;
	    for (@$cat) {
		next if $_ eq 'Pl';
		if ($do_bridge_opt && $_ eq 'Br') {
		    $is_bridge = 1;
		} elsif (defined $main_cat) {
		    my $rec = $net{"s"}->get_street_record($k1, $k2);
		    require Data::Dumper;
		    print STDERR Data::Dumper->new([$rec,"$k1 $k2"],[])->Indent(1)->Useqq(1)->Dump;
		    warn "Multiple main categories found: $_ vs. $main_cat";
		} else {
		    $main_cat = $_;
		}
	    };
	    next if !defined $main_cat; # may happen for "Pl"

	    my $cat_num = $cat_to_usability{$main_cat};
	    if (!defined $cat_num) {
		my $rec = $net{"s"}->get_street_record($k1, $k2);
		require Data::Dumper;
		print STDERR Data::Dumper->new([$rec,"$k1 $k2"],[])->Indent(1)->Useqq(1)->Dump;
		warn "Category $main_cat unhandled...\n";
		last CALC;
	    }

	    if (!$is_bridge && defined $net{"br"}->{Net}{$k1}{$k2} && $net{"br"}->{Net}{$k1}{$k2} eq 'Br') {
		$is_bridge = 1;
	    }

	    my $kfz = $net{"kfz"}->{Net}{$k1}{$k2};
	    if ($do_kfz_adjustment && defined $kfz) {
		$cat_num += $kfz;
		push @reason, $main_cat . $kfz;
	    } else {
		push @reason, $main_cat;
	    }

	    $res = $cat_num if $cat_num < $res;

	    if ($is_bridge) {
		$res -= 2;
		push @reason, "Brücke";
	    }

	    $res -= $quality_penalty;

	    if ($do_tram_opt) {
		my $tram = $net{"tram"}->{Net}{$k1}{$k2};
		if (defined $tram) {
		    $res -= 1;
		    push @reason, "Tram";
		}
	    }

	    if    ($res < 0) { $res = 0 }
	    elsif ($res > 6) { $res = 6 }
	}

	if (defined $res) {
	    $cat = $res;
	} else {
	    $cat = 0;
	}

	my $out_cat = int($cat/6*100);
	$net->{"$k1,$k2"} = $out_cat;

	if ($do_display) {
	    my $color = ['#ff0000',
			 '#ffaa00',
			 '#ffdd00',
			 '#f6ff00',
			 '#c7ff00',
			 '#00ff26',
			 #'#00ffe1',
			 '#0000ff',
			]->[$cat];
	    print "$cat " . join(", ", @reason) . "\t$color; $k1 $k2\n";
	}
    }
}

store($net, "$outfile.$$~");
chmod 0644, "$outfile.$$~";
rename "$outfile.$$~", $outfile
    or die "Can't rename from $outfile.$$~ to $outfile: $!";

# The data/Makefile rules .strassen.tmp and strassen,
# without the NH replacement
sub create_strassen_with_NH {
    use File::Temp qw(tempfile);
    use IPC::Run qw(run);
    my($tmpfh,$tmpfile) = tempfile(SUFFIX => ".bbd", UNLINK => 1);
    run(["$FindBin::RealBin/convert_orig_to_bbd", "-keep-directive", "alias",
	 $strassen_orig],
	">", $tmpfile) or die $!;
    run(["$FindBin::RealBin/grepstrassen", "-v", "--namerx", ' \(Potsdam\)', 'plaetze'],
	">>", $tmpfile) or die $!;
    run(["$FindBin::RealBin/grepstrassen", "-ignoreglobaldirectives", "-catrx", ".", "routing_helper-orig"],
	"|",
	["$FindBin::RealBin/replacestrassen", "-catexpr", 's/.*/NN::igndisp/'],
	">>", $tmpfile) or die $!;
    $tmpfile
}

__END__

=head1 NAME

winter_optimization.pl - create a penalty net for the winter

=head1 SYNOPSIS

Very snowy, useful for the first days with snow:

   winter_optimization.pl -winter-hardness very_snowy

Somewhat snowy, useful when more streets are already cleared:

   winter_optimization.pl -winter-hardness snowy

Dry cold, but all streets are cleared, no ice expected except
footpaths and cyclepaths:

   winter_optimization.pl -winter-hardness dry_cold

=head1 DESCRIPTION

=head2 CGI

Note that currently the winter hardness has to be set in the config
file F<bbbike.cgi.config> as variable C<$winter_hardness>. Winter
optimization is turned on only if C<$use_winter_optimization> is set
to true. Usually this could be done automatically for the winter
months, see F<bbbike-biokovo.cgi.config> for an example.

=head2 Perl/Tk application

After calling this script there is a penalty file created in the
directory F<.../bbbike/tmp> with name
F<winter_optimization.I<$hardness>.st>, where I<$hardness> is the
winter hardness used in the script call.

Choose then in the Perl/Tk application the menu item Sucheinstellungen
-> Penalty -> Penalty für Net/Storable-Datei and choose the created
file in the file dialog.

To create a bbd file with the calculated penalties, which then may be
displayed in the Perl/Tk version:

   winter_optimization.pl -winter-hardness ... -display > wi.bbd

=head1 AUTHOR

Slaven Rezic

=cut
