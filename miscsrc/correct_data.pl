#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: correct_data.pl,v 1.15 2004/06/08 21:51:27 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# TODO: pre-populate %conv (i.e. from "strassen")
#       load_conv/save_conv behaves badly for concurrent processes

package BBBike::CorrectData;

use FindBin;
use lib ("$FindBin::RealBin",
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data",
	);
use strict;
require "convert_berlinmap.pl";
use Strassen::Core;
use Karte;
use Object::Iterate qw(iterate);
use Getopt::Long;
use DB_File::Lock;
use Fcntl;
use Strassen::Util;
use BBBikeXS;

my $corr_data = "$FindBin::RealBin/../misc/gps_correction_all.dat";
my $ref_dist = "10000,20000,40000";
use vars qw($v_output $minpoints @ref_dist $reverse);
_init_ref_dist();
$v_output = 0 if !defined $v_output;
my $file;
my %conv;
my $conv_read_only;
my $s;
my $keep_everything;
my $in_place;
my $force;
my $in_berlin_check;
my $in_berlin_sub;
my $is_bbr;
# See also data_corrected/Makefile
my @INNER_BERLIN_COORDS = qw(-5400 19500 20800 1950);

sub process {
    local @ARGV = @_;
    local $| = 1;

    my $conv_data_file;

    if (!GetOptions("refdist=s" => \$ref_dist,
		    "correction=s" => \$corr_data,
		    "verboseoutput|v+" => \$v_output,
		    "convdata=s" => \$conv_data_file,
		    "convreadonly|convro!" => \$conv_read_only,
		    "minpoints=s" => \$minpoints,
		    "reverse!" => \$reverse,
		    "keepeverything!" => \$keep_everything,
		    "inplace!" => \$in_place,
		    "f|force!" => \$force,
		    "inberlincheck!" => \$in_berlin_check,
		    "bbr" => \$is_bbr,
		   )) {
	die <<EOF;
usage: $0 [-refdist dist1,dist2,...] [-correction datfile] [-verboseoutput ...] [-minpoints ...] [-convdata ...] [-reverse] [-keepeverything]
[-inplace] [-force] [-inberlincheck] [-bbr] streetfile
EOF
    }
    _init_ref_dist();

    $file = shift(@ARGV) || "-";

    local $SIG{INT} = sub { die "Interrupt" };

    if ($conv_data_file) {
	my $flags = 0;
	my $lock_flags;
	if ($conv_read_only) {
	    $flags = O_RDONLY;
	    $lock_flags = "read";
	} else {
	    $flags = O_RDWR|O_CREAT;
	    $lock_flags = "write";
	}
	tie %conv, 'DB_File::Lock', $conv_data_file, $flags, 0644, $DB_HASH, $lock_flags
	    or die "Can't tie $conv_data_file: $!";
    }

    if ($in_berlin_check) {
	require List::Util;
	require VectorUtil;

	system("$FindBin::RealBin/combine_streets.pl -closedpolygon $FindBin::RealBin/../data/berlin > /tmp/berlin_polygon.bbd") == 0 or
	    die "Creating berlin_polygon.bbd";

	my $berlin = Strassen->new("/tmp/berlin_polygon.bbd");
	my @polygon = map { [ split /,/, $_ ] } @{ $berlin->get(0)->[Strassen::COORDS] };

	my $minx = List::Util::min(map { $_->[0] } @polygon);
	my $miny = List::Util::min(map { $_->[1] } @polygon);
	my $maxx = List::Util::max(map { $_->[0] } @polygon);
	my $maxy = List::Util::max(map { $_->[1] } @polygon);

 	$in_berlin_sub = sub {
 	    my $c = shift;
	    my($px,$py) = split /,/, $c;
	    return 1 if (VectorUtil::point_in_grid($px,$py,@INNER_BERLIN_COORDS));
	    return 0 if (!VectorUtil::point_in_grid($px,$py,$minx,$miny,$maxx,$maxy));
	    return 1 if (VectorUtil::point_in_polygon([$px,$py],\@polygon));
	    return 0;
	};
    }

    if ($is_bbr) {
	require Route;
	my $r = Route::load($file);
	for my $p (@{ $r->{SearchRoutePoints} }) {
	    my($x,$y) = split /,/, $p->[0];
	    ($x,$y) = convert_record_for_x_y($x,$y);
	    $p->[0] = "$x,$y";
	}
	for my $p (@{ $r->{RealCoords} }) {
	    # "int" to avoid strings in route dump
	    my($x,$y) = map { int } convert_record_for_x_y(@$p);
	    $p = [$x,$y];
	}

	Route::save(-file => "-", -object => $r);
	return;
    }

    my $in_place_file;
    if ($in_place) {
	require File::Temp;
	(my($fh),$in_place_file) = File::Temp::tempfile();#XXXUNLINK => 1);
	select $fh;
    }

    if ($keep_everything) {
	$s = Strassen->new($file, NoRead => 1);
	my $fh = $s->open_file;
	while(<$fh>) {
	    my $l = $_;
	    my $r = Strassen::parse($l);
	    if ($l =~ /^\s*#/ ||
		!$r->[Strassen::COORDS] || !@{ $r->[Strassen::COORDS] }) {
		print $l;
	    } else {
		local $_ = $r;
		my $new_coords_ref = &convert_record;
		if ($new_coords_ref) {
		    $r->[Strassen::COORDS] = $new_coords_ref;
		    print Strassen::arr2line2($r), "\n";
		}
	    }
	}
    } else {
	$s = Strassen->new($file);
	iterate {
	    my $new_coords_ref = &convert_record;
	    if ($new_coords_ref) {
		$_->[Strassen::COORDS] = $new_coords_ref;
		print Strassen::arr2line2($_), "\n";
	    }
	} $s;
    }

    if ($in_place_file) {
	select STDOUT;

	require File::Compare;
	require File::Copy;
	if (File::Compare::compare($file, $in_place_file) != 0) {
	    if (!$force) {
		print STDERR "Overwrite $file? (Y/n) ";
		my $ans = <STDIN>;
		if ($ans =~ /^n/i) {
		    die "Do not overwrite $file\n";
		}
	    }
	    File::Copy::copy($in_place_file, $file) or
		    die "Can't copy $in_place_file to $file: $!";
	} else {
	    warn "No change in $file\n";
	}
    }

    untie %conv;
}

sub convert_record_for_x_y {
    my($x, $y) = @_;
    local $_ = ["", ["$x,$y"], ""];
    my $new_coord_ref = &convert_record;
    split /,/, $new_coord_ref->[0];
}

sub convert_record {
    my @new_coords;
    my $comment_printed = 0;
    my $coord_i = -1;
    for my $c (@{ $_->[Strassen::COORDS] }) {
	$coord_i++;

	(my $real_c = $c) =~ s/^(:.*:)//;
	my $pre_label = $1 || "";

	my $new_c;
	if ($real_c !~ /^[-+]?\d+,[-+]?\d+$/) {
	    $new_c = $real_c;
	    goto PUSH;
	}

	if (exists $conv{$real_c}) {
	    $new_c = $conv{$real_c};
	} else {

	    if ($in_berlin_sub) {
		if ($in_berlin_sub->($real_c)) {
		    $new_c = $real_c;
		    # but do not add to %conv
		    goto PUSH;
		}
	    }

	    eval {
	    TRY: {
		    my $loop_i = -1;
		    for my $ref_dist (@ref_dist) {
			$loop_i++;
			my @args =
			    (-datafromany => $corr_data,
			     -refpoint => "$c,$ref_dist",
			     '-nooutput', '-reusemapdata',
			     (defined $minpoints ? (-minpoints => $minpoints) : ()), # hier eigentlich egal
			    );
			my $ret = BBBike::Convert::process(@args);
			my $count = delete $ret->{Count};
			print "# $_->[Strassen::NAME], Pos=" . $s->pos . "\n"
			    if $v_output && !$comment_printed && $s;
			$comment_printed++;
			print "# coord_i=$coord_i, coord=$c, refdist=$ref_dist: $count sample(s)\n"
			    if $v_output >= 2;
			next if ($count < $minpoints);
			my $k_obj = Karte::create_obj("Karte::Custom", %$ret);
			my $_new_c;
			if ($reverse) {
			    $_new_c = join(",", map { int }
					   $k_obj->standard2map(split /,/, $c));
			} else {
			    $_new_c = join(",", map { int }
					   $k_obj->map2standard(split /,/, $c));
			}
			$conv{$c} = $_new_c unless $conv_read_only;
			$new_c = $_new_c;
			last TRY;
		    }
		    die;
		}
	    };
	    if ($@) {
		die if ($@ =~ /interrupt/i);
		my $msg = "# $_->[Strassen::NAME]";
		if ($s) { $msg .= ", Pos=" . $s->pos }
		$msg .= " ($c): cannot convert\n";
		print $msg if $v_output >= 2;
		warn $msg;
		return;
	    }
	}

    PUSH:
	if (defined $new_c) {
	    $new_c = "$pre_label$new_c";
	    push @new_coords, $new_c;
	}
    }
    \@new_coords;
}

sub _init_ref_dist {
    $minpoints = 5 if !defined $minpoints;
    @ref_dist = split /,/, $ref_dist;
}

return 1 if caller;

process(@ARGV);

__END__

# Sample one-liner for deleting a region from the conv database
# (call form data_converted directory):

perl -I../lib -MDB_File -MVectorUtil=point_in_grid -e 'tie %db, "DB_File", "conv.db", O_RDWR, 0644 or die $!; while(my($k,$v) = each %db) { if (point_in_grid(split(/,/,$k),@ARGV)) { push @p, $k } } for (@p) { delete $db{$_} } warn "@p" ' -- 28450 81000 48200 95850

# Force identity conversions for coords in some files
# (call from data directory):

perl -I.. -I../lib -MStrassen -MObject::Iterate=iterate -MDB_File -e 'tie %db, "DB_File", "../data_converted/conv.db", O_RDWR, 0600 or die; $s=MultiStrassen->new("strassen","wasserstrassen","ubahn");iterate { for my $c (@{ $_->[Strassen::COORDS] }) { $db{$c} = $c } } $s'

# Delete all points in conv.db for a data file
# (call from data_converted directory):

perl -I../lib -I.. -MDB_File -MStrassen -MObject::Iterate=iterate -e 'tie %db, "DB_File", "conv.db", O_RDWR, 0644 or die $!; $s=Strassen->new("../data/radwege");iterate { for $c (@{$_->[Strassen::COORDS]}) { delete $db{$c} } } $s'

