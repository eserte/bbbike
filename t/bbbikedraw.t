#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

# StrawberryPerl 5.14.2.1 information
# * Image::Magick not available
# * Cairo not available
# * MapServer backend needs mapserver binary

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data",
	 "$FindBin::RealBin",
	);
use Strassen::Core;
use BBBikeDraw;
use BBBikeUtil qw(is_in_path);
use BBBikeMapserver::Info qw();
use File::Temp qw(tempfile);
use Getopt::Long;

use BBBikeTest;

BEGIN {
    if (!eval q{
	use Test::More;
	use Time::HiRes qw(gettimeofday tv_interval);
	use Image::Info qw(image_info);
	1;
    }) {
	print "1..0 # skip no Test, Time::HiRes and/or Image::Info modules\n";
	exit;
    }
}

my @module_defs = (
		   {mod=>'GD/png',            on_live=>1},
		   {mod=>'GD/gif',            on_live=>0},
		   {mod=>'GD/jpeg',           on_live=>0},
		   {mod=>'GD::SVG',           on_live=>0},
		   {mod=>'SVG',               on_live=>0},
		   {mod=>'PDF',               on_live=>0},
		   {mod=>'PDFCairo',          on_live=>1},
		   {mod=>'Imager/png',        on_live=>0},
		   {mod=>'Imager/jpeg',       on_live=>0},
		   {mod=>'MapServer',         on_live=>0},
		   {mod=>'MapServer;noroute', on_live=>1},
		   {mod=>'ImageMagick/png',   on_live=>0},
		   {mod=>'ImageMagick/jpeg',  on_live=>0},
		   {mod=>'BBBikeGoogleMaps',  on_live=>0},
		   {mod=>'MapServer/pdf',     on_live=>0},
		  );
my %mod2def = map {($_->{mod} => $_)} @module_defs;

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

# Later (2015-01) on a xen vm running Debian/wheezy, with perl 5.20.1 (self-compiled)
# Command is:
#   perl5.20.1 bbbikedraw.t -only GD/png -only Imager/png -only ImageMagick/png -fullmap -v         
# Results:
# Module GD/png...
# ... drawing time: 3.33s (wall clock) 2.88s (cpu)
# Module Imager/png...
# ... drawing time: 11.71s (wall clock) 11.63s (cpu)
# Module ImageMagick/png...
# ... drawing time: 19.20s (wall clock) 20.13s (cpu)
#
# And now with -usexs option:
# Module GD/png...
# ... drawing time: 2.29s (wall clock) 2.29s (cpu)
# Module Imager/png...
# ... drawing time: 10.89s (wall clock) 10.88s (cpu)
# Module ImageMagick/png...
# ... drawing time: 16.45s (wall clock) 17.39s (cpu)
#
# On a i5-2500T @ 2.3GHz, FreeBSD 9.2, perl 5.20.1 (self-compiled)
# Module GD/png...
# ... drawing time: 12.23s (wall clock) 10.38s (cpu)
# Module Imager/png...
# ... drawing time: 42.75s (wall clock) 41.48s (cpu)
# Module ImageMagick/png...
# ... drawing time: 63.34s (wall clock) 62.44s (cpu)
#
# And now with the -usexs option (times vary, so two samples given here)
# Module GD/png...
# ... drawing time: 5.25s (wall clock) 5.22s (cpu)
# ... drawing time: 6.83s (wall clock) 6.76s (cpu)
# Module Imager/png...
# ... drawing time: 36.18s (wall clock) 34.91s (cpu)
# ... drawing time: 31.81s (wall clock) 31.52s (cpu)
# Module ImageMagick/png...
# ... drawing time: 55.77s (wall clock) 55.19s (cpu)
# ... drawing time: 56.70s (wall clock) 56.06s (cpu)

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

sub find_mod ($) {
    my $mod = shift;
    my $module_def = $mod2def{$mod};
    if (!$module_def) {
	die "Unknown module '$mod'";
    }
    $module_def;
}

sub find_matching_mods ($) {
    my $rx = shift;
    my @res;
    for my $module_def (@module_defs) {
	if ($module_def->{mod} =~ $rx) {
	    push @res, $module_def;
	}
    }
    @res;
}

my @only_modules;

if ($ENV{BBBIKE_TEST_DRAW_ONLY_MODULES}) {
    @only_modules = split /,/, $ENV{BBBIKE_TEST_DRAW_ONLY_MODULES};
}
if ($ENV{BBBIKE_TEST_DRAW_SKIP_MODULES}) {
    for my $mod (split /,/, $ENV{BBBIKE_TEST_DRAW_SKIP_MODULES}) {
	my $module_def = find_mod $mod;
	$module_def->{skip} = 'Skipped because of BBBIKE_TEST_DRAW_SKIP_MODULES';
    }
}
if ($ENV{BBBIKE_TEST_SKIP_MAPSERVER}) {
    for my $module_def (find_matching_mods qr{^MapServer}) {
	$module_def->{skip} = 'Skipped because of BBBIKE_TEST_SKIP_MAPSERVER';
    }
}
if ($ENV{BBBIKE_TEST_FOR_LIVE}) {
    for my $module_def (@module_defs) {
	$module_def->{skip} = 'Test only modules used on live server'
	    if !$module_def->{on_live};
    }
}

sub usage {
    die "usage $0: [-display|-displayall] [-save] [-v|-verbose] [-debug] [-fullmap] [-only module] [-skip module]
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
                  as a comma-separated string
-skip module:     Skip given modules from the standard set (may be set multiple times).
                  Can also be set with the environment variable BBBIKE_TEST_DRAW_SKIP_MODULES
                  as a comma-separated string
-start name
-goal name:       Set name for start and goal
";
}

# ImageMagick support is experimental and incomplete anyway, so do not
# depend on this
if (!eval { require Image::Magick; 1 }) {
    for my $module_def (find_matching_mods qr{^ImageMagick}) {
	$module_def->{skip} = 'Skipped because Image::Magick not available, do not test ImageMagick-related drawtypes...';
    }
}

# No Cairo on Windows available
if ($^O eq 'MSWin32' && !eval { require Cairo; 1 }) {
    for my $module_def (find_matching_mods qr{^PDFCairo}) {
	$module_def->{skip} = 'Skipped because Cairo is not available on Windows, do not test Cairo-related drawtypes...';
    }
}

# No Mapserver for Windows
if ($^O eq 'MSWin32') {
    for my $module_def (find_matching_mods qr{^MapServer}) {
	$module_def->{skip} = 'Skip MapServer tests on Windows...';
    }
}

my $mapserver_info = BBBikeMapserver::Info::get_info();
if (!defined $mapserver_info->{mapserver_version} || (
    !$mapserver_info->{OUTPUT}->{PDF} && !$mapserver_info->{SUPPORTS}->{CAIRO}
)) {
    my $module_def = find_mod 'MapServer/pdf';
    $module_def->{skip} = 'Skipping MapServer/pdf tests, Mapserver was built without pdflib';
    # pdflib is considered non-free in Debian; and I deliberately
    # compiled Mapserver without pdflib on cvrsnica because of
    # spurious crashes
}

# The following two modules are theoretically available under Windows,
# but usually not bundled neither in stock StrawberryPerl nor in
# the distributed version with bbbike
if ($^O eq 'MSWin32') {
    if (!eval { require GD::SVG; 1 }) {
	for my $module_def (find_matching_mods qr{^GD::SVG}) {
	    $module_def->{skip} = "GD::SVG not installed, skip tests...";
	}
    }
    if (!eval { require SVG; 1 }) {
	for my $module_def (find_matching_mods qr{^SVG}) {
	    $module_def->{skip} = "SVG not installed, skip tests...";
	}
    }
}

my @skip_modules;
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
		'only=s@' => \@only_modules,
		'skip=s@' => \@skip_modules,
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

if (@skip_modules) {
    for my $module (@skip_modules) {
	my $module_def = find_mod $module;
	$module_def->{skip} = "Skip $module because of -skip option";
    }
}

if (@only_modules) {
    my @new_module_defs;
    for my $module (@only_modules) {
	my $module_def = find_mod $module;
	push @new_module_defs, $module_def;
    }
    @module_defs = @new_module_defs;
}

if ($do_display_all) {
    $do_display = 1;
}

my $image_info_tests = 3;
my $additional_pdf_tests = 2;
my $tests_per_module = 1 + $image_info_tests;

my $total_additional_pdf_tests = $additional_pdf_tests * grep { $_->{mod} =~ /pdf/i } @module_defs;
plan tests => $total_additional_pdf_tests + scalar @module_defs * $tests_per_module;

for my $module_def (@module_defs) {
 SKIP: {
    TODO: {
	    my $skip = $module_def->{skip};
	    my $todo = $module_def->{todo};
	    my $module = $module_def->{mod};
	    my $number_of_tests = $tests_per_module + ($module =~ /pdf/i ? $additional_pdf_tests : 0);
	    skip $skip, $number_of_tests if $skip;
	    todo_skip $todo, $number_of_tests if $todo;
	    eval {
		draw_map($module);
	    };
	    my $err = $@;
	    is($err, "", "Draw with $module");
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
    } elsif ($module =~ /^(?:PDF|PDFCairo)$/) {
	$imagetype = "pdf";
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
	$BBBikeDraw::PDFCairo::VERBOSE = $BBBikeDraw::PDFCairo::VERBOSE = $debug;
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
	my $pdf_content = do {
	    local $/ = undef;
	    <$fh>;
	};

	ok($pdf_content =~ m{^%PDF-1\.\d+}, "Looks like a PDF document");

	my $TODO_cairo = ($module eq 'PDFCairo' || ($module eq 'MapServer' && $mapserver_info->{SUPPORTS}->{CAIRO})
			  ? 'Cairo has no support for Create, Author... in pdfs'
			  : undef);

	{
	    local $TODO = $TODO_cairo;
	    ok($pdf_content =~ m{Creator.*(BBBikeDraw|MapServer)}i, "Found Creator");
	}

	my $info = pdfinfo $filename;
    SKIP: {
	    skip "pdfinfo not available", $additional_pdf_tests
		if !$info;
	    if ($module eq 'PDF') {
		like $info->{Creator}, qr{^BBBikeDraw::PDF version \d+\.\d+}, 'expected creator';
		like $info->{Producer}, qr{^PDF::Create version \d+\.\d+}, 'expected producer';
	    } else {
	    SKIP: {
		    skip "CPAN::Version not available", 1
			if !eval { require CPAN::Version; 1 };
		    my($cairo_version) = $info->{Producer} =~ m{^cairo (\d+\.\d+\.\d+)};
		    if (CPAN::Version->vge($cairo_version, "1.15.4")) {
			local $TODO = "cairo 1.15.4+ has pdf metadata support, but not yet supported by the perl module";
			like $info->{Creator}, qr{^BBBikeDraw::PDFCairo version \d+\.\d+}, 'expected creator';
		    } else {
			like $info->{Creator}, qr{^cairo \d+\.\d+\.\d+}, 'expected creator';
		    }
		}
		like $info->{Producer}, qr{^cairo \d+\.\d+\.\d+}, 'expected producer';
	    }
	}
    } else {
    SKIP: {
	    my $image_info = image_info($filename);
	    if ($imagetype =~ /^(png|gif|jpeg)$/) {
		is($image_info->{file_media_type}, "image/$imagetype", "Correct mime type for $imagetype");
	    } elsif ($imagetype eq 'svg') {
		skip "Image::Info too old (try 1.31_50 or better)", 3
		    if !defined $image_info->{file_media_type} && $Image::Info::VERSION < 1.3150;
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
	for my $pdf_viewer (qw(evince xpdf acroread gv)) {
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
