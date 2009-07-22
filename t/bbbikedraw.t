#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbbikedraw.t,v 1.42 2008/12/07 19:20:36 eserte Exp $
# Author: Slaven Rezic
#

# ActivePerl 5.8.8 information
# * GD not available
# * Imager available, but built without png and jpeg support,
#   so basically useless
# * Image::Magick not available
# * MapServer backend needs mapserver binary

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
use BBBikeUtil qw(is_in_path);
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

    @modules = qw(GD/png GD/gif GD/jpeg
		  GD::SVG SVG
		  PDF PDF2
		  Imager/png Imager/jpeg
		  MapServer MapServer;noroute MapServer/pdf
		  ImageMagick/png ImageMagick/jpeg
		  BBBikeGoogleMaps
		 );

    if (0) { # berliner-stadtplan.com support for BBBike got lost somewhen in 2007 or so...
	if (eval { require BBBikeDraw::BerlinerStadtplan; 1 }) {
	    push @modules, "BerlinerStadtplan";
	}
    }
}

# Generate timings with:
#    perl bbbikedraw.t -only MapServer -only GD/png -only Imager -only ImageMagick -fullmap -v

# Timings are (on my 466MHz machine) with -fullmap:
# GD: 9s
# Imager: 37s
# MapServer: 60s
# ImageMagick: 461s (with VectorUtil XS)

# On a modern AMD Athlon with -fullmap (but later, more street data,
#   different software version etc.):
# GD: 6s
# Imager: 37s
# MapServer: 4s
# ImageMagick: 23s

# Later (2008-06) on the same AMD Athlon, but this time i386 mode,
#   different software versions etc.:
# GD/png: 8s
# Imager: 50s
# MapServer: 5s
# ImageMagick: 41s

# Later (2008-09) on the same AMD Athlon also in i386 mode, perl 5.8.8
#   different software versions etc.:
# GD/png: 13.62s (wall clock) 8.44s (cpu)
# Imager: 74.14s (wall clock) 51.01s (cpu)
# MapServer: 9.20s (wall clock) 5.47s (cpu)
# ImageMagick: 58.70s (wall clock) 37.48s (cpu)
# PDF: 36.78s (wall clock) 23.87s (cpu)
#
# and using the -usexs option:
# GD/png: 13.66s (wall clock) 8.05s (cpu)
# Imager: 81.03s (wall clock) 48.70s (cpu)
# MapServer: 7.16s (wall clock) 5.32s (cpu)
# ImageMagick: 64.52s (wall clock) 34.05s (cpu)
# PDF: 20.79s (wall clock) 19.77s (cpu)
#
# With -usexs and perl 5.10.0 (which is usually 2x as fast)
# GD/png: 5.96s (wall clock) 5.82s (cpu)
# Imager: 42.30s (wall clock) 41.16s (cpu)
# MapServer: 4.88s (wall clock) 4.77s (cpu)
# ImageMagick: N/A, no usable ImageMagick
# PDF: 25.03s (wall clock) 14.98s (cpu)

my @drawtypes = qw(all);
my $geometry = "640x480";
my $verbose = 0;
my $debug = 0;
my $do_fullmap = 0;
my $do_save = 0;
my @bbox = (8134,8581,9450,9718);
my $do_display_all;
my $flush_to_filename;
my $do_compress = 1;
my $do_outline = 1;
my $route_type = 'multi'; # or none or single
my $start_name = 'Start';
my $goal_name = 'Goal';
my $use_xs;

my @only_modules;

if ($ENV{BBBIKE_TEST_DRAW_ONLY_MODULES}) {
    @only_modules = split /,/, $ENV{BBBIKE_TEST_DRAW_ONLY_MODULES};
}

sub usage {
    die "usage $0: [-display|-displayall] [-save] [-v|-verbose] [-debug] [-fullmap] [-only module]
		   [-drawtypes type,type,...] [-bbox x0,y0,x1,y1] [-geometry wxh] [-noroute]
		   [-flushtofilename] [-[no]outline] [-[no]compress] [-start name] [-goal name] ...

-flushtofilename: Normally the internal flush will be done to a filehandle.
                  Change it to flush to a filename.
-displayall:      Display generated image with all available viewers for
		  this type.
-debug:		  In debug mode, all created files will be kept.
-nocompress:	  Do not compress output. Default is to compress where
		  possible.
-nooutline	  Do not use outlines when drawing streets.
-route none|single|multi:  Draw a sample route. May supercede a specified bbox.
-geometry wxh:    Default is $geometry.
-only module:     Test only the given module (may be set multiple times).
                  Can also be set with the environment variable BBBIKE_TEST_DRAW_ONLY_MODULES
-start name
-goal name:       Set name for start and goal
";
}

# ImageMagick support is experimental and incomplete anyway, so do not
# depend on this
if (!eval { require Image::Magick; 1 }) {
    warn "Image::Magick not available, do not test ImageMagick-related drawtypes...\n";
    @modules = grep { !/^ImageMagick/ } @modules;
}

if (!GetOptions(get_std_opts("display"),
		"displayall!" => \$do_display_all,
		"save!" => \$do_save,
		"v|verbose!" => \$verbose,
		"debug!" => \$debug,
		"fullmap|slow!" => \$do_fullmap, # -slow was the old option name
		"flushtofilename" => \$flush_to_filename,
		"compress!" => \$do_compress,
		"outline!" => \$do_outline,
		"route=s" => \$route_type,
		"geometry=s" => \$geometry,
		'only=s@' => sub {
		    push @only_modules, $_[1]; # Tests will fail with -only.
		},
		'drawtypes=s' => sub {
		    @drawtypes = split /,/, $_[1];
		},
		'bbox=s' => sub {
		    @bbox = split /,/, $_[1];
		},
		'start=s' => \$start_name,
		'goal=s'  => \$goal_name,
		'usexs!'  => \$use_xs,
	       )) {
    usage();
}

if ($use_xs) {
    eval 'use BBBikeXS';
    die $@ if $@;
}

if ($route_type !~ m{^(none|single|multi)$}) {
    warn "-route may only take none, single or multi.\n";
    usage();
}

my($width, $height) = split /x/, $geometry;

@modules = @only_modules if @only_modules;

if ($do_display_all) {
    $do_display = 1;
}

my $image_info_tests = 3;
my $tests_per_module = 1 + $image_info_tests;

plan tests => scalar @modules * $tests_per_module;

for my $module (@modules) {
 SKIP: {
	skip("PDF2 is not ready yet", $tests_per_module)
	    if $module eq 'PDF2';

	eval {
	    draw_map($module);
	};
	my $err = $@;
	is($err, "", "Draw with $module");

	if ($err && $module eq 'MapServer/pdf') {
	    diag <<EOF;
$module needs MapServer compiled with pdf support. Have pdflib installed
and try recompile with something like:

    sh configure --with-gd=/usr/local --with-pdf=/usr/local && make

EOF
	}
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
    my $cput0 = [times];

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
    } elsif ($module eq 'BBBikeGoogleMaps') {
	$imagetype = "http.html";
    }

    my($fh, $filename) = tempfile(UNLINK => !$debug,
				  SUFFIX => "-$module.$imagetype",
				 );

    if ($debug) {
	$BBBikeDraw::DEBUG = $BBBikeDraw::DEBUG = $debug;
	$BBBikeDraw::MapServer::DEBUG = $BBBikeDraw::MapServer::DEBUG = $debug;
	$BBBikeDraw::PDF::VERBOSE = $BBBikeDraw::PDF::VERBOSE = $debug;
	# XXX more to come...
    }

    my @coords;
    my @multicoords;
    my @pseudo_route;
    if ($route_type ne 'none') {
	no warnings 'qw';
	@coords = qw(8209,8773 8291,8773 8425,8775 8472,8776 8480,9080 8598,9074 8594,8777 8763,8780 8982,8781 9076,8783 9229,8785 9227,8890 9225,9038 9224,9053 9225,9111 9248,9350 9280,9476 9000,9509 9043,9745);
	if ($route_type eq 'multi') {
	    @multicoords = ([@coords],
			    [qw(8595,9495 8598,9264)],
			   );
	    @coords = ();
	}
	if (@coords) {
	    for(my $i = 0; $i <= $#coords; $i+=3) {
		push @pseudo_route, {Strname => "Test Waypoint " . ($#pseudo_route+2),
				     Coord => $coords[$i],
				    };
	    }
	}
    }

    my $draw = new BBBikeDraw
	NoInit     => 1,
	($flush_to_filename ? (Filename => $filename) : (Fh => $fh)),
	Geometry   => $geometry,
	Draw       => [@drawtypes],
	Outline	   => $do_outline,
        Scope      => "city",
        ImageType  => $imagetype,
	Module     => $module,
	Startname  => $start_name,
	Zielname   => $goal_name,
	(@coords ? (Coords => [@coords]) : ()),
	(@multicoords ? (MultiCoords => [@multicoords]) : ()),
	UseFlags   => 1,
	Wind       => {Windrichtung => 'N',
		       Windstaerke  => 3,
		      },
        StrLabel   => ['str:HH,H'],
	Compress   => $do_compress, # implemented for PDF
	MakeNet    => \&make_net,
	BBBikeRoute => \@pseudo_route,
    ;
    if ($do_fullmap) {
	$draw->set_bbox_max(Strassen->new("strassen"));
    } elsif (@bbox) {
	die "Bbox needs 4 coordinates" if @bbox != 4;
	$draw->set_bbox(@bbox);
    }
    $draw->init;
    $draw->create_transpose(-asstring => 1);
    $draw->draw_map if $draw->can("draw_map");
    if (!$attributes{noroute} && ($route_type ne 'none')) {
	$draw->draw_route if $draw->can("draw_route");
    }
    $draw->draw_wind if $draw->can("draw_wind");
    $draw->flush;
    close $fh;

    my $elapsed = tv_interval ( $t0, [gettimeofday]);
    my $elapsed_cpu = eval { require List::Util; List::Util::sum(times) - List::Util::sum(@$cput0) };
    if ($verbose) {
	warn sprintf("... drawing time: %.2fs (wall clock)", $elapsed) .
	    ($elapsed_cpu ? sprintf(" %.2fs (cpu)", $elapsed_cpu) : "") . "\n";
    }

    if ($do_display) {
	if ($do_display_all && $imagetype eq 'pdf') {
	    for my $pdf_viewer (get_all_viewers("pdf")) {
		$pdf_prog = $pdf_viewer; # change for do_display
		do_display($filename, $imagetype);
	    }
	} else {
	    do_display($filename, $imagetype);
	}
    }
    if ($do_save) {
	require File::Copy;
	require File::Basename;
	my $dest_filename = "/tmp/bbbikedraw." . $imagetype; 
	File::Copy::cp($filename, $dest_filename)
		or die "Can't copy $filename to $dest_filename: $!";
	warn "Saved to $dest_filename\n";
    }

    # This block should generate $image_info_tests tests:
    if ($imagetype =~ /^pdf$/) {
	my $fh;
	ok(open($fh, $filename), "File $filename opened");
	local $/ = undef;
	my $pdf_content = <$fh>;

	ok($pdf_content =~ m{^%PDF-1\.\d+}, "Looks like a PDF document");
	ok($pdf_content =~ m{Creator.*(BBBikeDraw|MapServer)}i, "Found Creator");
    } else {
    SKIP: {
	    my $image_info = image_info($filename);
	    if ($imagetype =~ /^(png|gif|jpeg)$/) {
		is($image_info->{file_media_type}, "image/$imagetype", "Correct mime type for $imagetype");
	    } elsif ($imagetype eq 'svg') {
		like($image_info->{file_media_type}, qr{^image/svg[+-]xml$}, "Correct mime type for $imagetype");
		if ($image_info->{file_media_type} eq 'image/svg-xml') {
		    diag <<EOF;
The recommended mime type for SVG is image/svg+xml, not image svg-xml.
See also http://www.svgfaq.com/ServerGen.asp or 
http://support.adobe.com/devsup/devsup.nsf/docs/50809.htm.
EOF
		}
	    } else {
		skip "image_info does not work for $imagetype", 3;
	    }
	    is($image_info->{width}, $width);
	    is($image_info->{height}, $height);
	}
    }
}

sub get_all_viewers {
    my($imagetype) = @_;
    if ($imagetype eq 'pdf') {
	my @pdf_viewers;
	# There's also kpdf, but kde programms does not run in a
	# non-KDE environment anymore...
	for my $pdf_viewer ("acroread", "xpdf", "gv") {
	    push @pdf_viewers, $pdf_viewer if is_in_path($pdf_viewer);
	}
	@pdf_viewers;
    } else {
	die "get_all_viewers not supported for $imagetype";
    }
}

sub make_net {
    require Strassen::Core;
    require Strassen::StrassenNetz;
    my $s = Strassen->new("strassen");
    my $net = StrassenNetz->new($s);
    $net->make_net;
    $net;
}

__END__
