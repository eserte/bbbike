#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbbikedraw.t,v 1.15 2005/01/20 00:26:34 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data",
	 "$FindBin::RealBin",
	 "$FindBin::RealBin/../projects/www.berliner-stadtplan.com/lib",
	);
use Strassen::Core;
use BBBikeDraw;
use File::Temp qw(tempfile);
use Getopt::Long;

use BBBikeTest;

my @modules;

BEGIN {
    if (!eval q{
	use Test::More;
	use Time::HiRes qw(gettimeofday tv_interval);
	use Image::Info qw(image_info);
	1;
    }) {
	print "1..0 # skip: no Test, Time::HiRes and/or Image::Info modules\n";
	exit;
    }

    @modules = qw(GD/png GD/gif GD/jpeg GD::SVG SVG PDF PDF2
		  Imager/png Imager/jpeg
		  MapServer MapServer;noroute
		  ImageMagick/png ImageMagick/jpeg
		 );

    if (eval { require BBBikeDraw::BerlinerStadtplan; 1 }) {
	push @modules, "BerlinerStadtplan";
    }
}

# Timings are (on my 466MHz machine) with -slow:
# GD: 9 s
# Imager: 37 s
# MapServer: 60 s
# ImageMagick: 461 s (with VectorUtil XS)

my @drawtypes = qw(all);
my $width = 640;
my $height = 480;
my $geometry = $width."x".$height;
my $verbose = 0;
my $debug   = 0;
my $do_slow = 0;

my @only_modules;

if (!GetOptions(get_std_opts("display"),
		"v|verbose!" => \$verbose,
		"debug!" => \$debug,
		"slow!" => \$do_slow,
		'only=s@' => sub {
		    push @only_modules, $_[1]; # Tests will fail with -only.
		},
	       )) {
    die "usage $0: [-display] [-v|-verbose] [-debug] [-slow] [-only module] ...";
}

@modules = @only_modules if @only_modules;

my $tests_per_module = 4;

plan tests => scalar @modules * $tests_per_module;

for my $module (@modules) {
 SKIP: {
	skip("PDF2 is not ready yet", $tests_per_module)
	    if $module eq 'PDF2';

	eval {
	    draw_map($module);
	};
	is($@, "", "Draw with $module");
    }
}

if ($do_display) {
    warn "Hit on <RETURN>\n";
    <STDIN>;
}

sub draw_map {
    my $module = shift;
    warn "Module $module...\n" if $verbose;

    my $t0 = [gettimeofday];

    ($module, my @attributes) = split /;/, $module;
    my %attributes = map {($_,1)} @attributes;

    my $imagetype = "png";
    if ($module eq 'GD::SVG') {
	$module = "GD";
	$imagetype = "svg";
    } elsif ($module =~ m{(.*)/(.*)}) {
	$module = $1;
	$imagetype = $2;
    } elsif ($module eq 'SVG') {
	$imagetype = "svg";
    } elsif ($module =~ /^PDF2?$/) {
	$imagetype = "pdf";
    } elsif ($module eq 'BerlinerStadtplan') {
	$imagetype = "http.html";
    }

    my($fh, $filename) = tempfile(UNLINK => !$debug,
				  SUFFIX => "-$module.$imagetype",
				 );

    if ($debug) {
	$BBBikeDraw::DEBUG = $BBBikeDraw::DEBUG = $debug;
	$BBBikeDraw::MapServer::DEBUG = $BBBikeDraw::MapServer::DEBUG = $debug;
	# XXX more to come...
    }

    my $draw = new BBBikeDraw
	NoInit     => 1,
	Fh         => $fh,
	Geometry   => $geometry,
	Draw       => [@drawtypes],
	Outline	   => 1,
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
	$draw->set_bbox(8134,8581,9450,9718);
    }
    $draw->init;
    $draw->create_transpose(-asstring => 1);
    $draw->draw_map if $draw->can("draw_map");
    if (!$attributes{noroute}) {
	$draw->draw_route if $draw->can("draw_route");
    }
    $draw->flush;
    close $fh;

    my $elapsed = tv_interval ( $t0, [gettimeofday]);
    if ($verbose) {
	warn sprintf "... drawing time: %.2fs\n", $elapsed;
    }

    if ($do_display) {
	do_display($filename, $imagetype);
    }

 SKIP: {
	my $image_info = image_info($filename);
	if ($imagetype =~ /^(png|gif|jpeg)$/) {
	    is($image_info->{file_media_type}, "image/$imagetype", "Correct mime type for $imagetype");
	} elsif ($imagetype eq 'svg') {
	    is($image_info->{file_media_type}, "image/svg-xml", "Correct mime type for $imagetype");
	} else {
	    skip "image_info does not work for $imagetype", 3;
	}
	is($image_info->{width}, $width);
	is($image_info->{height}, $height);
    }
}


__END__
