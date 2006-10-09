#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbbikedraw.t,v 1.23 2006/10/07 19:44:23 eserte Exp $
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

    @modules = qw(GD/png GD/gif GD/jpeg GD::SVG SVG PDF PDF2
		  Imager/png Imager/jpeg
		  MapServer MapServer;noroute MapServer/pdf
		  ImageMagick/png ImageMagick/jpeg
		 );

    if (eval { require BBBikeDraw::BerlinerStadtplan; 1 }) {
	push @modules, "BerlinerStadtplan";
    }

    if (!eval { require GD::SVG; 1 }) { # Module does not pass tests anymore
	@modules = grep { $_ ne "GD::SVG" } @modules;
    }
}

# Timings are (on my 466MHz machine) with -slow:
# GD: 9s
# Imager: 37s
# MapServer: 60s
# ImageMagick: 461s (with VectorUtil XS)

# On a modern AMD Athlon with -slow (but later, more street data,
#   different software version etc.):
# GD: 6s
# Imager: 37s
# MapServer: 4s
# ImageMagick: 23s

my @drawtypes = qw(all);
my $width = 640;
my $height = 480;
my $geometry = $width."x".$height;
my $verbose = 0;
my $debug   = 0;
my $do_slow = 0;
my $do_save = 0;
my @bbox;
my $do_display_all;
my $flush_to_filename;
my $do_compress = 1;

my @only_modules;

if (!GetOptions(get_std_opts("display"),
		"displayall!" => \$do_display_all,
		"save!" => \$do_save,
		"v|verbose!" => \$verbose,
		"debug!" => \$debug,
		"slow!" => \$do_slow,
		"flushtofilename" => \$flush_to_filename,
		"compress!" => \$do_compress,
		'only=s@' => sub {
		    push @only_modules, $_[1]; # Tests will fail with -only.
		},
		'drawtypes=s' => sub {
		    @drawtypes = split /,/, $_[1];
		},
		'bbox=s' => sub {
		    @bbox = split /,/, $_[1];
		},
	       )) {
    die "usage $0: [-display|-displayall] [-save] [-v|-verbose] [-debug] [-slow] [-only module]
		   [-drawtypes type,type,...] [-bbox x0,y0,x1,y1]
		   [-flushtofilename] [-[no]compress] ...

-flushtofilename: Normally the internal flush will be done to a filehandle.
                  Change it to flush to a filename.
-displayall:      Display generated image with all available viewers for
		  this type.
-debug:		  In debug mode, all created files will be kept.
-nocompress:	  Do not compress output. Default is to compress where
		  possible.
";
}

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
	($flush_to_filename ? (Filename => $filename) : (Fh => $fh)),
	Geometry   => $geometry,
	Draw       => [@drawtypes],
	Outline	   => 1,
        Scope      => "city",
        ImageType  => $imagetype,
	Module     => $module,
	Startname  => "Start",
	Zielname   => "Goal",
	Coords     => ["9222,8787", "8209,8769"],
	UseFlags   => 1,
	Wind       => {Windrichtung => 'N',
		       Windstaerke  => 3,
		      },
        StrLabel   => ['str:HH,H'],
	Compress   => $do_compress, # implemented for PDF
    ;
    if ($do_slow) {
	$draw->set_bbox_max(Strassen->new("strassen"));
    } elsif (@bbox) {
	die "Bbox needs 4 coordinates" if @bbox != 4;
	$draw->set_bbox(@bbox);
    } else {
	$draw->set_bbox(8134,8581,9450,9718);
    }
    $draw->init;
    $draw->create_transpose(-asstring => 1);
    $draw->draw_map if $draw->can("draw_map");
    if (!$attributes{noroute}) {
	$draw->draw_route if $draw->can("draw_route");
    }
    $draw->draw_wind if $draw->can("draw_wind");
    $draw->flush;
    close $fh;

    my $elapsed = tv_interval ( $t0, [gettimeofday]);
    if ($verbose) {
	warn sprintf "... drawing time: %.2fs\n", $elapsed;
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

	local $TODO;
	if ($module =~ /MapServer/) {
	    $TODO = "Does not generate a PDF document, there's a PDFlib exception";
	}
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

__END__
