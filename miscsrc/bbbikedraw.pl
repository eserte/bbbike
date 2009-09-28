#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbbikedraw.pl,v 1.23 2008/08/22 19:47:45 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven.rezic@berlin.de
# WWW:  http://www.rezic.de/eserte/
#

# Interface to BBBikeDraw.pm

use strict;
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

if (!GetOptions("w=i" => \$w,
		"h=i" => \$h,
		"geometry=s" => \$geometry,
		"bbox=s" => \$bbox,
		"drawtypes=s" => sub { @drawtypes = split /,/, $_[1] },
		"restrict=s" => sub { @restrict = split /,/, $_[1] },
		"drawscalebar!" => \$draw_scale_bar,
		"o=s" => \$outfile,
		"dimfile=s" => \$dimfile,
		"outline!" => \$outline,
		"outlinecat=s" => sub { @outlinecat = split /,/, $_[1] },
		"outtype|imagetype=s" => \$outtype,
		"ipaq!" => \$ipaq,
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
					 H  => 2,
					 HH => 2,
					 N  => 1,
					 NN => 1,
					};
}
if (defined $outline) {
    push @extra_args, Outline => $outline;
}
if (@outlinecat) {
    push @extra_args, OutlineCat => \@outlinecat;
}
if (defined $scope) {
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
	push @extra_args, Coords => [ map { join(",", @$_) } @{ $load->{RealCoords} } ];
    }
}
if (defined $marker_point) {
    push @extra_args, MarkerPoint => $marker_point;
}

my $draw = new BBBikeDraw
    NoInit   => 1,
    Fh       => \*OUT,
    Geometry => $geometry,
    Draw     => [@drawtypes],
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
    $draw->set_bbox_max(new Strassen
			(defined $scope && $scope eq 'region'
			 ? "landstrassen"
			 : (defined $scope && $scope eq 'wideregion'
			    ? 'landstrassen2' : "strassen"))
		       );
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
}
$draw->flush;
close OUT;

if (defined $dimfile) {
    require Data::Dumper;
    open(DIM, ">$dimfile") or die "Can't write to $dimfile: $!";
    while(my($k,$v) = each %$draw) {
	delete $draw->{$k} if $k =~ /^_/;
    }
    print DIM Data::Dumper->Dumpxs([$draw], ['draw']);
    close DIM;
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
-routefile file		   Draw the specified bbr file (some other GPS file
			   formats are also supported)
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
-bg|-background color      Specify background color (as GD colors)
-q			   Be quiet.
-debug                     Turn debugging on.
EOF
}

__END__
