#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: correct_data.pl,v 1.9 2004/03/08 00:09:44 eserte Exp $
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
#       also convert .bbd
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
use vars qw($v_output $minpoints @ref_dist);
_init_ref_dist();
my $file;
my %conv;
my $s;
my $reverse;

sub process {
    local @ARGV = @_;
    local $| = 1;

    my $conv_data_file;

    if (!GetOptions("refdist=s" => \$ref_dist,
		    "correction=s" => \$corr_data,
		    "verboseoutput!" => \$v_output,
		    "convdata=s" => \$conv_data_file,
		    "minpoints=s" => \$minpoints,
		    "reverse!" => \$reverse,
		   )) {
	die "usage: $0 [-refdist dist1,dist2,...] [-correction datfile] [-verboseoutput] [-minpoints ...] [-convdata ...] [-reverse] streetfile";
    }
    _init_ref_dist();

    $file = shift(@ARGV) || "-";

    local $SIG{INT} = sub { die "Interrupt" };

    if ($conv_data_file) {
	tie %conv, 'DB_File::Lock', $conv_data_file, O_RDWR|O_CREAT, 0644, $DB_HASH, "write"
	or die "Can't tie $conv_data_file: $!";
    }

    $s = Strassen->new($file);
    iterate {
	my $new_coords_ref = &convert_record;
	next if !$new_coords_ref;
	$_->[Strassen::COORDS] = $new_coords_ref;
	print Strassen::arr2line2($_), "\n";
    } $s;

    untie %conv;
}

sub convert_record {
    my @new_coords;
    my $comment_printed = 0;
    my $coord_i = -1;
    for my $c (@{ $_->[Strassen::COORDS] }) {
	$coord_i++;
	if (exists $conv{$c}) {
	    push @new_coords, $conv{$c};
	} else {
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
			    if !$comment_printed && $s;
			$comment_printed++;
			print "# coord_i=$coord_i, coord=$c, refdist=$ref_dist: $count sample(s)\n"
			    if $v_output;
			next if ($count < $minpoints);
			my $k_obj = Karte::create_obj("Karte::Custom", %$ret);
			my $new_c;
			if ($reverse) {
			    $new_c = join(",", map { int }
					  $k_obj->standard2map(split /,/, $c));
			} else {
			    $new_c = join(",", map { int }
					  $k_obj->map2standard(split /,/, $c));
			}
			$conv{$c} = $new_c;
			push @new_coords, $new_c;
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
		print $msg if $v_output;
		warn $msg;
		return;
	    }
	}
    }
    \@new_coords;
}

sub _init_ref_dist {
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

