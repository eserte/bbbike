#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbbikedraw.t,v 1.7 2003/11/28 00:19:08 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data"
	);
use Strassen::Core;
use BBBikeDraw;
use BBBikeUtil qw(is_in_path);
use File::Temp qw(tempfile);
use Getopt::Long;

my @modules;

BEGIN {
    if (!eval q{
	use Test;
	use Time::HiRes qw(gettimeofday tv_interval);
	use Image::Info qw(image_info);
	1;
    }) {
	print "1..0 # skip: no Test, Time::HiRes and/or Image::Info modules\n";
	exit;
    }

    @modules = qw(GD/png GD/gif GD/jpeg GD::SVG SVG PDF
		  Imager/png Imager/jpeg MapServer
		  ImageMagick/png ImageMagick/jpeg);
}

# Timings are (on my 466MHz machine) with -slow:
# GD: 9 s
# Imager: 37 s
# MapServer: 60 s
# ImageMagick: 461 s (with VectorUtil XS)

plan tests => scalar @modules * 4;

my @drawtypes = qw(all);
my $width = 640;
my $height = 480;
my $geometry = $width."x".$height;
my $display = 0;
my $verbose = 0;
my $do_slow = 0;

if (!GetOptions("display!" => \$display,
		"v|verbose!" => \$verbose,
		"slow!" => \$do_slow,
		"only=s" => sub {
		    @modules = $_[1]; # Tests will fail with -only.
		},
	       )) {
    die "usage $0: [-display] [-v|-verbose] [-slow] [-only module]";
}

for my $module (@modules) {
    eval {
	draw_map($module);
    };
    ok($@, "");
}

if ($display) {
    warn "Hit on <RETURN>\n";
    <STDIN>;
}

sub draw_map {
    my $module = shift;
    warn "Module $module...\n" if $verbose;

    my $t0 = [gettimeofday];

    my $imagetype = "png";
    if ($module eq 'GD::SVG') {
	$module = "GD";
	$imagetype = "svg";
    } elsif ($module =~ m{(.*)/(.*)}) {
	$module = $1;
	$imagetype = $2;
    } elsif ($module eq 'SVG') {
	$imagetype = "svg";
    } elsif ($module eq 'PDF') {
	$imagetype = "pdf";
    }

    my($fh, $filename) = tempfile(UNLINK => 1,
				  SUFFIX => "-$module.$imagetype",
				 );

    my $draw = new BBBikeDraw
	NoInit     => 1,
	Fh         => $fh,
	Geometry   => $geometry,
	Draw       => [@drawtypes],
        Scope      => "city",
        ImageType  => $imagetype,
	Module     => $module,
	Startname  => "Start",
	Zielname   => "Goal",
	Coords     => ["9222,8787", "8209,8769"],
    ;
    if ($do_slow) {
	$draw->set_bbox_max(Strassen->new("strassen"));
    } else {
	$draw->set_bbox(8000,8000,9000,9000);
    }
    $draw->init;
    $draw->create_transpose(-asstring => 1);
    $draw->draw_map if $draw->can("draw_map");
    $draw->draw_route if $draw->can("draw_route");
    $draw->flush;
    close $fh;

    my $elapsed = tv_interval ( $t0, [gettimeofday]);
    if ($verbose) {
	warn sprintf "... drawing time: %.2fs\n", $elapsed;
    }

    if ($display) {
	if ($imagetype eq 'svg') {
	    if (is_in_path("mozilla")) {
		system("mozilla $filename &");
	    } else {
		warn "Can't display $filename";
	    }
	} elsif ($imagetype eq 'pdf') {
	    if (is_in_path("xpdf")) {
		system("xpdf $filename &");
	    } else {
		warn "Can't display $filename";
	    }
	} else {
	    if (is_in_path("xv")) {
		system("xv $filename &");
	    } elsif (is_in_path("display")) {
		system("display $filename &");
	    } else {
		warn "Can't display $filename";
	    }
	}
    }

 SKIP: {
	my $image_info = image_info($filename);
	if ($imagetype =~ /^(png|gif|jpeg)$/) {
	    ok($image_info->{file_media_type}, "image/$imagetype");
	} elsif ($imagetype eq 'svg') {
	    ok($image_info->{file_media_type}, "image/svg-xml");
	} else {
	    skip "image_info does not work for $imagetype", 1
		for 1..3;
	    last SKIP;
	}
	ok($image_info->{width}, $width);
	ok($image_info->{height}, $height);
    }
}


__END__
