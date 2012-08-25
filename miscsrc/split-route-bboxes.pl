#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2012 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
my $bbbike_root;
BEGIN { $bbbike_root = "$FindBin::RealBin/.." }
use lib (
	 $bbbike_root,
	 "$bbbike_root/lib",
	);

use File::Temp qw(tempfile);
use Getopt::Long;
use Route;
use Route::Heavy;
use Strassen::Util;
use VectorUtil;

my $make_cmdline;
my $do_exec;
my $do_view;
my $as_bbd;
my %scale_density = (hi => 10_000, # meters per width
		     lo => 20_000,
		    );
GetOptions(
	   "make-cmdline" => \$make_cmdline,
	   "exec" => \$do_exec,
	   "view" => \$do_view,
	   "as-bbd" => \$as_bbd,
	   "hi-scale=f" => sub { $scale_density{hi} = $_[1] },
	   "lo-scale=f" => sub { $scale_density{lo} = $_[1] },
	  )
    or die "usage: $0 [-make-cmdline | -view | -exec | -as-bbd] [-hi-scale ...] [-lo-scale ...] routefile";

if ($do_view) {
    $do_exec = 1;
}
if ($do_exec) {
    $make_cmdline = 1;
}

my $file = shift or die "route file?";
my $res = Route::load($file);
my $realcoords = $res->{RealCoords};
my @r_bbox = Route::get_bbox($realcoords);

my $bbox_width  = abs($r_bbox[2]-$r_bbox[0]);
my $bbox_height = abs($r_bbox[3]-$r_bbox[1]);
my $is_portrait = $bbox_height >= $bbox_width;

my($advance_x_direction, $advance_y_direction, $r_bbox_start_indexes) = get_advance_directions($realcoords->[0], \@r_bbox);

my $advance_x_factor = $advance_x_direction * ($is_portrait ? 1 : sqrt(2));
my $advance_y_factor = $advance_y_direction * ($is_portrait ? sqrt(2) : 1);

my($start_x,$start_y) = @r_bbox[@$r_bbox_start_indexes];
my $page_i = 1;
my $realcoords_i = 0;
my @cmds;
my @pagefiles;
while(1) {
    my $scale = get_scale_density($start_x,$start_y);
    my $advance_x = $advance_x_factor * $scale;
    my $advance_y = $advance_y_factor * $scale;
    my $next_x = int($start_x + $advance_x);
    my $next_y = int($start_y + $advance_y);
    if ($make_cmdline) {
	my $out_filename;
	if ($do_exec) {
	    (undef,$out_filename) = tempfile(SUFFIX => '.pdf', UNLINK => 1)
		or die $!;
	    push @pagefiles, $out_filename;
	} else {
	    $out_filename = "/tmp/out$page_i.pdf";
	    $page_i++;
	}
	push @cmds, "$^X $bbbike_root/miscsrc/bbbikedraw.pl -drawtypes all -routefile $file -module PDFCairo -o $out_filename -bbox $start_x,$start_y,$next_x,$next_y -scope wideregion";
    } elsif ($as_bbd) {
	print "Page $page_i\tX $start_x,$start_y $start_x,$next_y $next_x,$next_y $next_x,$start_y $start_x,$start_y\n";
	$page_i++;
    } else {
	print "($start_x,$start_y,$next_x,$next_y)\n";
    }
#require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([[$advance_x_direction,$advance_y_direction],[$next_x,$next_y], \@r_bbox],[qw()])->Indent(1)->Useqq(1)->Dump; # XXX

    if ((($advance_x_direction > 0 && $next_x > $r_bbox[2]) ||
	 ($advance_x_direction < 0 && $next_x < $r_bbox[0]))
	&&
	(($advance_y_direction > 0 && $next_y > $r_bbox[3]) ||
	 ($advance_y_direction < 0 && $next_y < $r_bbox[1]))) {
	last;
    }

    # Find next starting point
    #XXX rough approximation: ($start_x,$start_y) = ($next_x,$next_y);
    my($next_start_x,$next_start_y);
#require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([[$start_x,$start_y,$next_x,$next_y]],[qw()])->Indent(1)->Useqq(1)->Dump; # XXX
    for my $i ($realcoords_i+1 .. $#{ $realcoords }-1) {
	my($x1,$y1,$x2,$y2) = (
			       @{ $realcoords->[$i] },
			       @{ $realcoords->[$i+1] },
			      );
	($next_start_x,$next_start_y) = VectorUtil::intersect_line_rectangle($x1,$y1,$x2,$y2, $start_x,$start_y,$next_x,$next_y);
	if (defined $next_start_x) {
#warn "($next_start_x,$next_start_y, $i)";
	    $realcoords_i = $i;
	    last;
	}
    }

    if (!defined $next_start_x) {
	warn "Cannot find any intersection anymore... strange, are we done?";
	last;
    }

    my @new_r_bbox = Route::get_bbox([@{ $realcoords }[$realcoords_i..$#$realcoords]]);
    ($start_x,$start_y) = @new_r_bbox[@$r_bbox_start_indexes];
    @r_bbox = @new_r_bbox;
}

if (@cmds) {
    # last one should output the route list
    $cmds[-1] .= " -routelist";
}
if (@cmds) {
    for (@cmds) {
	print $_, "\n";
	if ($do_exec) {
	    system $_;
	    die "Failed with $?" if $? != 0;
	}
    }
    if ($do_exec) {
	my $cmd = "pdftk @pagefiles cat output /tmp/out.pdf";
	system $cmd;
	die "$cmd failed with $?" if $? != 0;
	warn "Output file is /tmp/out.pdf\n";
	if ($do_view) {
	    system "xpdf", "-z", "100", "/tmp/out.pdf";
	}
    }
}

sub get_scale_density {
    my($x,$y) = @_;
    my $c = "$x,$y";
    if (outside_berlin_and_potsdam($c)) {
	$scale_density{lo};
    } else {
	$scale_density{hi};
    }
}

sub get_advance_directions {
    my($start_xy, $r_bbox) = @_;
    my $nearest = undef;
    my($advance_x_direction, $advance_y_direction, $r_bbox_indexes);
    for my $def (
		 [[0,1], +1, +1], # Südwest -> ...
		 [[0,3], +1, -1], # Nordwest -> ...
		 [[2,1], -1, +1], # Südost -> ...
		 [[2,3], -1, -1], # Nordost -> ...
		) {
	my $this_r_bbox_indexes = $def->[0];
	my $corner = [@{$r_bbox}[@$this_r_bbox_indexes]];
	my $this_advance_x_direction = $def->[1];
	my $this_advance_y_direction = $def->[2];

	my $s = Strassen::Util::strecke($start_xy, $corner);
	if (!defined $nearest || $s < $nearest) {
	    $advance_x_direction = $this_advance_x_direction;
	    $advance_y_direction = $this_advance_y_direction;
	    $r_bbox_indexes = $this_r_bbox_indexes;
	    $nearest = $s;
	}
    }
    ($advance_x_direction, $advance_y_direction, $r_bbox_indexes);
}

# XXX Taken from bbbike.cgi
sub outside_berlin_and_potsdam {
    my($c) = @_;
    my $result = 0;
    eval {
	require VectorUtil;
	my $berlin = Strassen->new("berlin");
	$berlin->count == 1 or die "Record count of berlin is not 1";
	$berlin->init;
	my $potsdam = Strassen->new("potsdam");
	$potsdam->count == 1 or die "Record count of potsdam is not 1";
	$potsdam->init;
	my $berlin_border = [ map { [split /,/] } @{ $berlin->next->[Strassen::COORDS()] } ];
	my $potsdam_border = [ map { [split /,/] } @{ $potsdam->next->[Strassen::COORDS()] } ];
	my $p = [split /,/, $c];
	$result = 1 if (!VectorUtil::point_in_polygon($p,$berlin_border) &&
			!VectorUtil::point_in_polygon($p,$potsdam_border));

    };
    warn $@ if $@;
    $result;
}

__END__

=head1 OPTIONS

* -view

Create all single PDFs, combine into one and show with L<xpdf(1)>.

* -exec

Just create the final PDF as F</tmp/out.pdf>.

* -make-cmdline

Show what needs to be executed. Use like this:

    ./miscsrc/split-route-bboxes.pl ~/.bbbike/route/berlin-niederfinow-schwedt-szczecin.bbr -make-cmdline | sh -x -

Then:

    pdftk /tmp/out?.pdf cat output /tmp/out.pdf

* -hi-scale, -lo-scale

Change the scaling limits.

* -as-bbd

Output page bboxes as bbd data to stdout.

=cut
