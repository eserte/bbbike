#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: restrict_bbd_data.pl,v 2.8 2008/05/13 19:32:22 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002,2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

=head1 NAME

restrict_bbd_data.pl - Restrict bbd data to a given bounding box

=head1 SYNOPSIS

    restrict_bbd_data.pl
        [ -bbox x1,y1,x2,y2 | -in file1,... | -notin file1,... |
          -polygon "x1,y1 x2,y2 ..."]
        -scope [city|region|wideregion] | -strdata file1,file2,...
        -o outputfile

=head1 DESCRIPTION

Restricts bbd data to the bounding box given by C<-bbox>. The bbd data
is either the default C<strassen> and C<landstrassen> if C<-scope> is
specified, or a comma-separated list if C<-strdata> is specified. The
generated bbd is written to I<outputfile>.

Stdin/out operation with:

    restrict_bbd_data.pl -bbox ... -strdata=- -o=- < ... > ...

It is possible to specify multiple -bbox options. In this case the
points should be at least in one of the bounding boxes.

bbd files specified with C<-in>/C<-notin> may be used to restrict by
points (not) contained in these files.

C<-polygon> takes an option in the format "x1,y1 x2,y2 ...". Note that
the spaces in the option value must be quoted for the shell.

=cut

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data",
	);
use Strassen;
use Getopt::Long;
use BBBikeRouting;
eval 'use BBBikeXS';

@Strassen::datadirs = ();

my @bbox_s;
my @contains_polygons_s;
my @in;
my @notin;
my $scope = "city";
my $outfile;
my $strdata;

sub usage {
    my $msg = shift;
    warn $msg if $msg;
    require Pod::Usage;
    Pod::Usage::pod2usage(1);
}

if (!GetOptions('bbox=s@' => \@bbox_s,
		'polygon=s@' => \@contains_polygons_s,
		"scope=s" => \$scope,
		"datadir=s@" => \@Strassen::datadirs,
		"str|strdata=s" => \$strdata,
		"in=s" => sub {
		    @in = split /,/, $_[1];
		},
		"notin=s" => sub {
		    @notin = split /,/, $_[1];
		},
		"o=s" => \$outfile,
	       )) {
    usage();
}

usage() if @ARGV;
usage() if (!@bbox_s && !@contains_polygons_s && !@in && !@notin);
my @bboxes;
if (@bbox_s) {
    for my $bbox_s (@bbox_s) {
	my @bbox = split /,/, $bbox_s;
	usage("Wrong bounding box") if @bbox != 4;
	#warn "Bounding box is @bbox\n";
	if ($bbox[0] > $bbox[2]) { @bbox[0,2] = @bbox[2,0] }
	if ($bbox[1] > $bbox[3]) { @bbox[1,3] = @bbox[3,1] }
	push @bboxes, \@bbox;
    }
}
my @contains_polygons;
if (@contains_polygons_s) {
    for (@contains_polygons_s) {
	push @contains_polygons, [map { [split /,/] } split / /];
    }
    require VectorUtil;
}

my($in_net, $notin_net);
if (@in) {
    my $in_s = MultiStrassen->new(@in);
    $in_net = StrassenNetz->new($in_s);
    $in_net->make_net;
}
if (@notin) {
    my $notin_s = MultiStrassen->new(@notin);
    $notin_net = StrassenNetz->new($notin_s);
    $notin_net->make_net;
}

die "-o is missing" if !$outfile;

my $s;
if ($strdata) {
    $s = MultiStrassen->new(split /,/, $strdata)
	or die "Can't make Strassen object of $strdata";
} else {
    my $routing = BBBikeRouting->new->init_context;
    my $context = $routing->Context;
    $context->Scope($scope) if $scope;
    $s = $routing->init_str;
}

my $new_s = Strassen->new;
$s->init;
while(1) {
    my $r = $s->next;
    last if !@{ $r->[Strassen::COORDS] };

    my @new_c;
    my $push_it = sub {
	my $new_r = [];
	for (0 .. Strassen::LAST) {
	    next if $_ == Strassen::COORDS;
	    $new_r->[$_] = $r->[$_];
	}
	$new_r->[Strassen::COORDS] = [@new_c];
	$new_s->push($new_r);
	@new_c = ();
    };

    # XXX Should be combinable with -bbox
    if ($in_net) {
	for my $i (1 .. $#{ $r->[Strassen::COORDS] }) {
	    my($xy1,$xy2) = ($r->[Strassen::COORDS][$i-1],
			     $r->[Strassen::COORDS][$i]);
	    if (exists $in_net->{Net}{$xy1}{$xy2}) {
		$new_s->push($r);
		last;
	    }
	}
    } elsif ($notin_net) {
    CHECK_IT: {
	    for my $i (1 .. $#{ $r->[Strassen::COORDS] }) {
		my($xy1,$xy2) = ($r->[Strassen::COORDS][$i-1],
				 $r->[Strassen::COORDS][$i]);
		if (exists $notin_net->{Net}{$xy1}{$xy2}) {
		    last CHECK_IT;
		}
	    }
	    $new_s->push($r);
	}
    } else {
	# XXX What about gaps, that is, if a street leaves the bbox and
	# enters again?
	for my $c (@{ $r->[Strassen::COORDS] }) {
	    my($x,$y) = split /,/, $c;
	    my $in = 0;
	    for my $bbox (@bboxes) {
		if ($x >= $bbox->[0] && $x <= $bbox->[2] &&
		    $y >= $bbox->[1] && $y <= $bbox->[3]) {
		    $in = 1;
		    last;
		}
	    }
	    for my $polygon (@contains_polygons) {
		if (VectorUtil::point_in_polygon([$x,$y], $polygon)) {
		    $in = 1;
		    last;
		}
	    }
	    if ($in) {
		push @new_c, $c;
	    } else {
		if (@new_c) {
		    $push_it->();
		}
	    }
	}
	if (@new_c) {
	    $push_it->();
	}
    }
}
$new_s->write($outfile);

__END__

=head1 EXAMPLES

Return all streets in Moabit. First get the Moabit coordinates from
berlin_ortsteile and paste them into the following cmdline:

    ./restrict_bbd_data.pl -polygon "8219,12994 8204,13344 8305,13354 8331,13507 8138,13801 7843,14329 7864,14349 7838,14410 7660,145322,14644 6944,14812 6594,14695 5939,14796 5721,14903 5583,14969 5147,14959 5167,14761 5243,14608 5086,14532 4080,14258 4151,13918 4426,13979 4487,13791 4197,13699 4324,13212 4461,12638 4497,12613 4573,12689 4619,12994 4720,13080 4944,13105 5126,13024 5279,12892 5304,12841 5299,12603 5330,12476 5436,12283 5573,12232 5705,12262 5814,12401 5944,12583 6013,12762 6067,12858 6230,12910 6464,12894 6704,12668 7023,12367 7237,12317 7408,12397 7557,12542 7781,12635 7948,12786 8059,12953 8171,12989 8219,12994" -strdata ../data/strassen -o -

=cut
