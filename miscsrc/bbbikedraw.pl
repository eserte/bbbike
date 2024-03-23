#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2001,2011,2017,2024 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Interface to BBBikeDraw.pm

use strict;
use warnings;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data"
	);
use Getopt::Long;
use Strassen;
use BBBikeDraw;

my $w = 1024;
my $h = 768;
my $geometry;
my @drawtypes = ('str');
my @restrict;
my $outfile;
my $dimfile;
my $ipaq = 0; # optimizations for the ipaq (line widths...)
my $small_screen;
my $outline;
my @outlinecat;
my $outtype;
my $scope;
my $fill_image; # fill image with data from outer scope
my $use_imagemagick;
my $use_mapserver;
my $use_imager;
my $use_module;
my $bbox;
my $minplacecat;
my $draw_scale_bar = 1;
my $fontsizescale;
my $background;
my $custom_places;
my $route_file;
my $marker_point;
my $q;
my $debug;
my $do_routelist;
my $compress;
my $interlaced;

if (!GetOptions("w=i" => \$w,
		"h=i" => \$h,
		"geometry=s" => \$geometry,
		"bbox=s" => \$bbox,
		"drawtypes|layers=s" => sub { @drawtypes = split /,/, $_[1] },
		"restrict=s" => sub { @restrict = split /,/, $_[1] },
		"drawscalebar!" => \$draw_scale_bar,
		"o=s" => \$outfile,
		"dimfile=s" => \$dimfile,
		"outline!" => \$outline,
		"outlinecat=s" => sub { @outlinecat = split /,/, $_[1] },
		"outtype|imagetype=s" => \$outtype,
		"ipaq!" => \$ipaq,
		"smallscreen!" => \$small_screen,
		"scope=s" => \$scope,
		"datadirs=s" => sub { unshift @Strassen::datadirs, split /,/, $_[1] },
		"fillimage!" => \$fill_image,
		"imagemagick!" => \$use_imagemagick,
		"mapserver!" => \$use_mapserver,
		"imager!" => \$use_imager,
		"module=s" => \$use_module,
		"minplacecat=i" => \$minplacecat,
		"fontsizescale=f" => \$fontsizescale,
		"bg|background=s" => \$background,
		"customplaces=s" => \$custom_places,
		"routefile=s" => \$route_file,
		"markerpoint=s" => \$marker_point,
		"routelist!" => \$do_routelist,
		"interlaced!" => \$interlaced,
		"compress!" => \$compress,
		"q|quiet!" => \$q,
		"debug" => \$debug,
	       )) {
    usage();
}

if ($q) {
    $BBBikeDraw::MapServer::Conf::QUIET = 1;
    $BBBikeDraw::MapServer::Conf::QUIET = $BBBikeDraw::MapServer::Conf::QUIET if 0; # cease -w
}
if ($debug) {
    # XXX this list is not comprehensive yet
    $BBBikeDraw::GoogleMapsStatic::DEBUG = $BBBikeDraw::GoogleMapsStatic::DEBUG = 1;
    $BBBikeDraw::MapServer::DEBUG        = $BBBikeDraw::MapServer::DEBUG        = 1;
}

if (!defined $geometry) {
    $geometry = $w."x".$h;
}

if (!defined $outfile) {
    open(OUT, ">&STDOUT");
} else {
    open(OUT, ">$outfile") or die "Can't write to $outfile: $!";
}
if (-t OUT) {
    die "No output to terminal permitted. Please use a pipe or redirection.\n";
}

binmode OUT;

my @extra_args;
if ($ipaq) {
    push @extra_args, CategoryWidths => {B  => 2,
					 HH => 2,
					 H  => 2,
					 NH => 1,
					 N  => 1,
					 NN => 1,
					};
}
if ($small_screen) {
    push @extra_args, SmallScreen => 1;
}
if (defined $outline) {
    push @extra_args, Outline => $outline;
}
if (@outlinecat) {
    push @extra_args, OutlineCat => \@outlinecat;
}
if (defined $scope) {
    if ($scope !~ m{^(city|region|wideregion)$}) {
	die "Invalid scope '$scope' (valid is: city, region, or wideregion)";
    }
    push @extra_args, Scope => $scope;
} elsif ($fill_image) {
    # scope=city, but fill image
    push @extra_args, Scope => 'region';
}
if (defined $outtype) {
    push @extra_args, ImageType => $outtype;
}

if (defined $use_module) {
    push @extra_args, Module => $use_module;
} else {
    if ($use_imagemagick) {
	push @extra_args, Module => "ImageMagick";
    }
    if ($use_imager) {
	push @extra_args, Module => "Imager";
    }
    if ($use_mapserver) {
	push @extra_args, Module => "MapServer";
    }
}
if (defined $minplacecat) {
    push @extra_args, MinPlaceCat => $minplacecat;
}
if (@restrict) {
    push @extra_args, Restrict => \@restrict;
}
if (!$draw_scale_bar) {
    push @extra_args, NoScale => 1;
}
if ($fontsizescale) {
    push @extra_args, FontSizeScale => $fontsizescale;
}
if (defined $background) {
    push @extra_args, Bg => $background;
}
if (defined $interlaced) {
    push @extra_args, Interlaced => $interlaced;
}
if (defined $route_file) {
    # XXX no magic defined for gpsman files, extra handling needed.
    # Also, some other formats like gpx are better handled by the
    # gpsman code.
    if ($route_file =~ m{\.(trk|xml(.gz)?|gpx(.gz)?)$}) {
	require GPS::GpsmanData::Any;
	my $gpsman = GPS::GpsmanData::Any->load($route_file);
	my @multicoords;
	for my $chunk (@{ $gpsman->Chunks }) {
	    push @multicoords, [ map { join(",", @$_) } $chunk->do_convert_to_route ];
	}
	push @extra_args, MultiCoords => \@multicoords;
    } else {
	require Route;
	my $load = Route::load($route_file);
	my @coords = map { join(",", @$_) } @{ $load->{RealCoords} };
	push @extra_args, Coords => \@coords;
	my(@strnames) = make_netz()->route_to_name([ map { [split ','] } @coords ]);
	if (@strnames) {
	    push @extra_args, Startname => Strassen::strip_bezirk($strnames[0]->[0]);
	    push @extra_args, Zielname => Strassen::strip_bezirk($strnames[-1]->[0]);
	}
    }
}
if (defined $marker_point) {
    push @extra_args, MarkerPoint => $marker_point;
}
if ($compress) {
    push @extra_args, Compress => 1;
}

my $draw = new BBBikeDraw
    NoInit   => 1,
    Fh       => \*OUT,
    Geometry => $geometry,
    Draw     => [@drawtypes],
    MakeNet  => \&make_netz,
    @extra_args,
    ;
if (defined $bbox) {
    my(@bbox) = split /,/, $bbox;
    if (@bbox != 4) {
	die "Bounding box must consist of four comma separated integers";
    }
    $draw->set_bbox(@bbox);
} elsif (defined $route_file) {
    # bbox automatically set in pre_draw, see below
} else {
    $draw->set_bbox_max(get_strassen());
}
$draw->init;
if ($route_file) {
    $draw->pre_draw;
} else {
    $draw->create_transpose(-asstring => 1);
}
$draw->draw_map if $draw->can("draw_map");
if (defined $custom_places) {
    if ($use_mapserver) {
	warn "-customplaces not available for -mapserver";
    } else {
	$draw->draw_custom_places($custom_places);
    }
}
if ($route_file) {
    $draw->draw_route;
    if ($do_routelist) {
	$draw->add_route_descr(
			       -net => make_netz(),
			       -lang => 'de',
			      )
	    if $draw->can("add_route_descr");
    }
}

$draw->flush;
close OUT;

if (defined $dimfile) {
    require Data::Dumper;
    open(DIM, ">$dimfile") or die "Can't write to $dimfile: $!";
    while(my($k,$v) = each %$draw) {
	delete $draw->{$k} if $k =~ /^(_|Image$)/;
    }
    print DIM Data::Dumper->Dumpxs([$draw], ['draw']);
    close DIM;
}

{
    my $s;
    sub get_strassen {
	return $s if $s;
	my @s = ('strassen');
	if (defined $scope) {
	    if ($scope eq 'region' || $scope eq 'wideregion') {
		push @s, 'landstrassen';
		if ($scope eq 'wideregion') {
		    push @s, 'landstrassen2';
		}
	    }
	}		
	$s = @s == 1 ? Strassen->new($s[0]) : MultiStrassen->new(@s);
    }
}

{
    my $net;
    sub make_netz {
	return $net if $net;
	my $s = get_strassen();
	require Strassen::StrassenNetz;
	$net = StrassenNetz->new($s);
	$net->make_net(UseCache => 1);
	$net;
    }
}

sub usage {
    die <<EOF;
usage: $0 [options]

-w width                   Generate an image with the specified width
-h height                  Generate an image with the specified height
-geometry widthxheight     Generate an image with the specified width and
                           height
-bbox x1,y1,x2,y2          Use the specified bounding box from the source map
-drawtypes type1,type2,... Draw the specified types. By default only streets
                           are drawn.
-layers type1,type2,..     Alias for drawtypes
-routefile file		   Draw the specified bbr file (some other GPS file
			   formats are also supported)
-routelist                 Add also a route list page if supported (e.g. PDF)
-markerpoint x,y           Draw a marker
-restrict cat1,cat2,...    Restrict to the specified categories.
-o outfile                 Use the specified file for the output. Otherwise
                           the output goes to stdout.
-dimfile dimfile           Use the specified file for the dimension information
                           file. If not specified, no dimfile will be created.
-[no]outline               Use outlines for streets etc.
-outlinecat cat1,cat2,...  ?
-outtype | -imagetype type Use the specified image type for the output file.
                           Default is png.
-[no]ipaq                  Use optimizations for handheld devices like iPAQ
-scope scope               Use the specified scope. By default "city" is used.
-datadirs directory,...    Use another data directory for map data.
-[no]fillimage             ?
-imagemagick               Use the ImageMagick backend instead of GD. This
                           will result in higher quality images, but the
                           creation time will be *much* longer.
-mapserver  		   Use MapServer backend instead of GD.
-imager  		   Use Imager backend instead of GD.
-module ModuleName	   Use any backend instead of GD. Note that it's
			   recommended to use -mapserver instead of
			   -module MapServer.
-minplacecat cat           Draw places with at least the specified category.
-[no]drawscalebar          Draw scale bar. Default is true.
-fontsizescale float       Scale default font sizes for place labels.
-bg|-background color      Specify background color (as GD colors).
                           Use "transparent" for a transparent background.
-[no]interlaced		   Specify if interlaced images should be generated, if
			   supported by the used module. Usually this defaults
			   to a true value.
-compress		   Turn compression on. May help in reducing size for pdf
			   output.
-q			   Be quiet.
-debug                     Turn debugging on.
EOF
}

__END__
