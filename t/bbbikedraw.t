#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbbikedraw.t,v 1.6 2003/11/16 22:15:22 eserte Exp $
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

    @modules = qw(GD Imager MapServer ImageMagick);
}

# Timings are (on my 466MHz machine) with -slow:
# GD: 9 s
# Imager: 37 s
# MapServer: 60 s
# ImageMagick: 461 s (with VectorUtil XS)

plan tests => scalar @modules * 4;

my @drawtypes = "all";
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

    my($fh, $filename) = tempfile(UNLINK => 1,
				  SUFFIX => "-$module.png",
				 );
    my $draw = new BBBikeDraw
	NoInit     => 1,
	Fh         => $fh,
	Geometry   => $geometry,
	Draw       => [@drawtypes],
        Scope      => "city",
        ImageType  => "png",
	Module     => $module,
    ;
    if ($do_slow) {
	$draw->set_bbox_max(Strassen->new("strassen"));
    } else {
	$draw->set_bbox(8000,8000,9000,9000);
    }
    $draw->init;
    $draw->create_transpose(-asstring => 1);
    $draw->draw_map if $draw->can("draw_map");
    $draw->flush;
    close $fh;

    my $elapsed = tv_interval ( $t0, [gettimeofday]);
    if ($verbose) {
	warn sprintf "... drawing time: %.2fs\n", $elapsed;
    }

    if ($display) {
	system("xv $filename &");
    }

    my $image_info = image_info($filename);
    ok($image_info->{file_media_type}, "image/png");
    ok($image_info->{width}, $width);
    ok($image_info->{height}, $height);
}

__END__
