#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: correct_data_map.pl,v 1.4 2004/03/03 23:14:33 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use FindBin;
use lib ("$FindBin::RealBin",
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data",
	);
use strict;
use Strassen::Util;
use Data::Dumper;
use Getopt::Long;
require "correct_data.pl";
use your qw($BBBike::CorrectData::v_output
	    $BBBike::CorrectData::minpoints
	    @BBBike::CorrectData::ref_dist
	   );

my $statefile = "/tmp/correct_data_map.state";

{
    my($x, $y);
    my $delta = 500;
    my $dir = "^";
    my $step = 1;
    my $step_i = 0;
    my $change_step_i = 0;

    sub next_snail_coords {
	if (!defined $x) {
	    ($x, $y) = (0, 0);
	    return ($x, $y);
	}
	my($xdelta, $ydelta) = @{ +{ "^" => [ 0, 1],
				     "<" => [-1, 0],
				     "v" => [ 0,-1],
				     ">" => [ 1, 0],
				   }->{$dir}
			       };
	$x += $xdelta*$delta;
	$y += $ydelta*$delta;

	$step_i++;
	if ($step_i == $step) {
	    $step_i = 0;

	    $dir = { "^" => "<",
		     "<" => "v",
		     "v" => ">",
		     ">" => "^" }->{$dir};

	    $change_step_i++;
	    if ($change_step_i == 2) {
		$step++;
		$change_step_i = 0;
	    }
	}

	return ($x, $y);
    }

    sub dumpstate {
	open(DUMP, ">$statefile") or die $!;
	print DUMP Data::Dumper->new
	    ([
	      $x,
	      $y,
	      $delta,
	      $dir,
	      $step,
	      $step_i,
	      $change_step_i,
	     ],[
		qw(
		   $x
		   $y
		   $delta
		   $dir
		   $step
		   $step_i
		   $change_step_i
		  )
	       ])->Indent(1)->Useqq(1)->Dump;
	close DUMP;
    }

    sub restore {
	open(DUMP, "<$statefile") or die $!;
	local $/ = undef;
	my $buf = <DUMP>;
	close DUMP;
	eval $buf; die $@ if $@;
	warn "Start at ($x, $y) with direction $dir";
    }

    sub init {
	my(%args) = @_;
	$x = $args{"x"} if exists $args{"x"};
	$y = $args{"y"} if exists $args{"y"};
	$delta = $args{"delta"} if exists $args{"delta"};
    }
}

my %opt;

## These options should match the parameters in data_corrected/Makefile
#$BBBike::CorrectData::v_output = 1;
$BBBike::CorrectData::minpoints = 5;
@BBBike::CorrectData::ref_dist = (10000,20000,40000,80000,120000);

local $| = 1;
local $SIG{INT} = sub { dumpstate(); exit };

# With Ctrl-C the current state is dumped to a temporary file. With -restore
# this state file is restored.
if (!GetOptions(\%opt, "restore!", "x=i", "y=i", "delta=i", "point=s",
		"state|statefile=s")) {
    die "usage:
Initial start:
	perl correct_data_map.pl | tee /tmp/corrdata.bbd

Continue:
	perl correct_data_map.pl -restore | tee -a /tmp/corrdata.bbd

Additional options: [-x coord -y coord | -point x,y] -delta length_in_m

";
}

if ($opt{point}) {
    ($opt{"x"}, $opt{"y"}) = split /,/, delete $opt{"point"};
}

$statefile = $opt{"state"} if $opt{"state"};

if ($opt{"restore"}) {
    restore();
}
if (defined $opt{"x"} || defined $opt{"y"} || defined $opt{"delta"}) {
    init(%opt);
}

while(1) {
    my($x, $y) = next_snail_coords();
    local $_ = ["Name", ["$x,$y"], "X"];

    my $new_coord_ref = &BBBike::CorrectData::convert_record;
    next if !$new_coord_ref;
    my($newx,$newy) = split /,/, $new_coord_ref->[0];
    my $dist = int Strassen::Util::strecke([$x,$y], [$newx,$newy]);
    my $r = $dist > 500 ? 500 : $dist;
    $r = $r/500*255;
    my $cat = sprintf "#%02x%02x%02x", $r,0,0;
    print "$x,$y ($dist m)\t$cat $x,$y $newx,$newy\n";
}

__END__
