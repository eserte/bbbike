#!/usr/local/bin/perl -w
# -*- perl -*-

#
# $Id: str_stat.pl,v 1.12 2007/09/05 20:23:44 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998,2004,2006 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net/
#

use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../lib");
use Strassen::Core;
use Strassen::MultiStrassen;
use Strassen::Stat;
use Getopt::Long;
use strict;

my %seen;
my %str;

my $do_wasserstrassen = 0;

my $do_area;
my $splitlines;
my $as_bbd;
if (!GetOptions("area!" => \$do_area,
		"splitlines" => \$splitlines,
		"asbbd!" => \$as_bbd,
	       )) {
    die "usage: $0 [-area] [-splitlines] [-asbbd] file ...
-area: calculate areas instead of lines
-splitlines: split lines like in railways and undergrounds
-asbbd: create bbd file
";
}

my @strfile = @ARGV;
if (!@strfile) {
    $do_wasserstrassen = 1;
    @strfile = "strassen";
}

if ($do_wasserstrassen) {
    do_wasserstrassen();
}

my $str_total_total_len = 0;
{
    my $s;
    if (@strfile > 1) {
	$s = MultiStrassen->new(@strfile);
    } else {
	$s = Strassen->new(@strfile);
	if ($s->get_global_directives->{map}->[0] eq 'polar') {
	    warn qq{NOTE: Turning on "polar" hack...\n};
	    *Strassen::Util::strecke_s = \&Strassen::Util::strecke_s_polar;
	    *Strassen::Util::strecke   = \&Strassen::Util::strecke_polar;
	}
    }
    $s->init;
    while(1) {
	my $r = $s->next;
	last if !@{$r->[1]};
	my @name = $r->[Strassen::NAME];
	if ($splitlines) {
	    @name = split /,/, $name[0];
	}
	my($total_area, $total_len);
	if ($do_area) {
	    $total_area = Strassen::area($r);
	    $str_total_total_len += $total_area/1_000_000;
	} else {
	    $total_len = Strassen::total_len($r);
	    $str_total_total_len += $total_len/1_000;
	}
	for my $name (@name) {
	    if (defined $total_area) {
		$str{$name} += $total_area/1_000_000;
	    } else {
		$str{$name} += $total_len/1_000;
	    }
	}
    }
}


if (%seen) {
    print "Seen:\n";
    print join("\n",
	       map { sprintf "%-30s %6.2f km≤ = %5.f ha",
			 $_, $seen{$_}, $seen{$_}*100
		     } sort { $seen{$b} <=> $seen{$a} } keys %seen), "\n";
    
    print "-" x 70, "\n";
}

if ($do_area) {
    print "Fl‰chen:\n";
} else {
    print "Straﬂen:\n";
}
my $unit = $do_area ? 'km≤' : 'km';
print join("\n",
	   map { sprintf("%-40s %6.2f $unit", $_, $str{$_})
		     . ($do_area ? sprintf(" = %5.f ha = %d m≤", $str{$_}*100, $str{$_}*1000*1000) : "")
	       } sort { $str{$b} <=> $str{$a} } keys %str), "\n";

if ($do_area) {
    print "Gesamte Fl‰che: ";
} else {
    print "Gesamtes Straﬂennetz: ";
}
printf "%6.2f $unit\n", $str_total_total_len;

sub do_wasserstrassen {
    my $s = new MultiStrassen
	Strassen->new("wasserumland"),
	Strassen->new("wasserumland2"),
	Strassen->new("wasserstrassen");

    my $last_seen;
    $s->init;
    while(1) {
	my $r = $s->next;
	last if !@{$r->[Strassen::COORDS]};
	my $is_insel = $r->[Strassen::CAT] =~ /^F:I/;
	next if $r->[Strassen::CAT] !~ /^F:/ || (!$is_insel && $r->[Strassen::NAME] eq '');
	if ($is_insel) { # Insel abziehen
	    $seen{$last_seen} -= Strassen::area($r)/1_000_000;
	} else {
	    $seen{$r->[Strassen::NAME]} += Strassen::area($r)/1_000_000;
	    $last_seen = $r->[Strassen::NAME];
	}
    }
}
