#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: winter_optimization.pl,v 1.4 2005/03/15 20:49:53 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Verwendung:

# Dieses Skript aufrufen, in .../bbbike/tmp/winter_optimization.st
# wird ein Penalty-Netz erzeugt. Dann in bbbike Sucheinstellungen ->
# Penalty -> Penalty für Net/Storable-Datei anklicken und die erzeugte
# Datei auswählen.

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

if (!GetOptions("display" => \$do_display,
		"one-instance" => \$one_instance,
	       )) {
    die "usage: $0 [-display] [-one-instance]\n";
}

my $outfile = "$FindBin::RealBin/../tmp/winter_optimization.st";

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

my %str;
$str{"s"} = Strassen->new("strassen");
$str{"br"} = Strassen->new("brunnels");
$str{"qs"} = Strassen->new("qualitaet_s");
$str{"rw"} = Strassen->new("radwege_exact");
$str{"kfz"} = Strassen->new("comments_kfzverkehr");
$str{"tram"} = Strassen->new("comments_tram");
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

	    my $rw = $net{"rw"}->{Net}{$k1}{$k2};
	    if (defined $rw) {
		if ($rw =~ /^RW(2|8|)$/) {
		    $res = 1;
		    push @reason, "Radweg";
		}
	    }

	    my $main_cat;
	    my $is_bridge;
	    for (@$cat) {
		next if $_ eq 'Pl';
		if ($_ eq 'Br') {
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

	    my $cat_num = {NN => 1,
			   N  => 3,
			   NH => 4,
			   H  => 5,
			   HH => 6,
			   B  => 6,
			  }->{$main_cat};
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
	    if (defined $kfz) {
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

	    my $tram = $net{"tram"}->{Net}{$k1}{$k2};
	    if (defined $tram) {
		$res -= 1;
		push @reason, "Tram";
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

store($net, "$outfile~");
chmod 0644, "$outfile~";
rename "$outfile~", $outfile
    or die "Can't rename from $outfile~ to $outfile: $!";

__END__
