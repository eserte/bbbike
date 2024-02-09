#!/usr/bin/perl
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use warnings;
use FindBin;
use lib "$FindBin::RealBin/..", $FindBin::RealBin;

use Config qw(%Config);
use File::Temp qw(tempdir);
use Test::More;

use BBBikeTest qw(eq_or_diff);

use BBBikeMapserver::Info;

plan skip_all => 'No /bin/sh' if !-x '/bin/sh';
plan 'no_plan';

{
    my $info = BBBikeMapserver::Info::get_info();
    ok exists $info->{mapserver_version}, "got mapserver version " . (defined $info->{mapserver_version} ? $info->{mapserver_version} : '<undef>');

    my $cached_info = BBBikeMapserver::Info::get_info();
    eq_or_diff $cached_info, $info, '2nd call returns cached info';
}

{
    local $ENV{PATH} = inject_map2img(
	'shp2img',
	'MapServer version 7.0.4 OUTPUT=PNG OUTPUT=JPEG OUTPUT=KML SUPPORTS=PROJ SUPPORTS=AGG SUPPORTS=FREETYPE SUPPORTS=CAIRO SUPPORTS=SVG_SYMBOLS SUPPORTS=RSVG SUPPORTS=ICONV SUPPORTS=FRIBIDI SUPPORTS=WMS_SERVER SUPPORTS=WMS_CLIENT SUPPORTS=WFS_SERVER SUPPORTS=WFS_CLIENT SUPPORTS=WCS_SERVER SUPPORTS=SOS_SERVER SUPPORTS=FASTCGI SUPPORTS=THREADS SUPPORTS=GEOS INPUT=JPEG INPUT=POSTGIS INPUT=OGR INPUT=GDAL INPUT=SHAPEFILE',
    ); # . $Config{path_sep} . $ENV{PATH};
    my $info = BBBikeMapserver::Info::get_info(forcerefresh => 1);
    $info->{map2img_path} =~ s{.*[/\\]}{}; # normalize tempdir
    eq_or_diff $info, {
        mapserver_version => '7.0.4',
	map2img_path => 'shp2img',
	OUTPUT => {
	    PNG => 1,
	    JPEG => 1,
	    KML => 1,
	},
	SUPPORTS => {
	    PROJ => 1,
	    AGG => 1,
	    FREETYPE => 1,
	    CAIRO => 1,
	    SVG_SYMBOLS => 1,
	    RSVG => 1,
	    ICONV => 1,
	    FRIBIDI => 1,
	    WMS_SERVER => 1,
	    WMS_CLIENT => 1,
	    WFS_SERVER => 1,
	    WFS_CLIENT => 1,
	    WCS_SERVER => 1,
	    SOS_SERVER => 1,
	    FASTCGI => 1,
	    THREADS => 1,
	    GEOS => 1
	},
	INPUT => {
	    JPEG => 1,
	    POSTGIS => 1,
	    OGR => 1,
	    GDAL => 1,
	    SHAPEFILE => 1,
	}
    }, 'simulated output for MapServer 7.x shp2img';
}

{
    local $ENV{PATH} = inject_map2img(
	'map2img',
	'MapServer version 8.0.0 OUTPUT=PNG OUTPUT=JPEG OUTPUT=KML SUPPORTS=PROJ SUPPORTS=AGG SUPPORTS=FREETYPE SUPPORTS=CAIRO SUPPORTS=SVG_SYMBOLS SUPPORTS=RSVG SUPPORTS=ICONV SUPPORTS=FRIBIDI SUPPORTS=WMS_SERVER SUPPORTS=WMS_CLIENT SUPPORTS=WFS_SERVER SUPPORTS=WFS_CLIENT SUPPORTS=WCS_SERVER SUPPORTS=SOS_SERVER SUPPORTS=OGCAPI_SERVER SUPPORTS=FASTCGI SUPPORTS=THREADS SUPPORTS=GEOS SUPPORTS=PBF INPUT=JPEG INPUT=POSTGIS INPUT=OGR INPUT=GDAL INPUT=SHAPEFILE INPUT=FLATGEOBUF',
    ); # . $Config{path_sep} . $ENV{PATH};
    my $info = BBBikeMapserver::Info::get_info(forcerefresh => 1);
    $info->{map2img_path} =~ s{.*[/\\]}{}; # normalize tempdir
    eq_or_diff $info, {
        mapserver_version => '8.0.0',
	map2img_path => 'map2img',
	OUTPUT => {
	    PNG => 1,
	    JPEG => 1,
	    KML => 1,
	},
	SUPPORTS => {
	    PROJ => 1,
	    AGG => 1,
	    FREETYPE => 1,
	    CAIRO => 1,
	    SVG_SYMBOLS => 1,
	    RSVG => 1,
	    ICONV => 1,
	    FRIBIDI => 1,
	    WMS_SERVER => 1,
	    WMS_CLIENT => 1,
	    WFS_SERVER => 1,
	    WFS_CLIENT => 1,
	    WCS_SERVER => 1,
	    SOS_SERVER => 1,
	    OGCAPI_SERVER => 1,
	    FASTCGI => 1,
	    THREADS => 1,
	    GEOS => 1,
	    PBF => 1,
	},
	INPUT => {
	    JPEG => 1,
	    POSTGIS => 1,
	    OGR => 1,
	    GDAL => 1,
	    SHAPEFILE => 1,
	    FLATGEOBUF => 1,
	},
    }, 'simulated output for MapServer 8.x map2img';
}

sub inject_map2img {
    my($exe, $v_contents) = @_;

    my $temppathdir = tempdir(TMPDIR => 1, CLEANUP => 1);
    my $map2img_path = "$temppathdir/$exe";
    open my $ofh, '>', $map2img_path or die "Can't write to $map2img_path: $!";
    print $ofh "#! /bin/sh\n";
    print $ofh "echo $v_contents\n";
    close $ofh or die $!;
    chmod 0755, $map2img_path;

    $temppathdir;
}

__END__
