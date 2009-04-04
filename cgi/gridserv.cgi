#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: gridserv.cgi,v 1.7 2009/04/04 11:22:10 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2006 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# This could be used for a Googlemaps-like client

use strict;
use FindBin;
use lib (
	 # normal install
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 # radzeit install
	 "$FindBin::RealBin/../BBBike",
	 "$FindBin::RealBin/../BBBike/lib",
	);
use CGI qw(:standard);

my $x = int param("x") || 0;
my $y = int param("y") || 0;

binmode STDOUT;
print header("image/png");

#my $grid = 128;
my $grid = 512;
my $centerx = 8070;
my $centery = 8000-130;
my $deltax = 100*$grid/70;
my $deltay = $deltax;

my $cache_dir = "/tmp/mapserver_cache/$grid";
if (!-d $cache_dir) {
    require File::Path;
    File::Path::mkpath($cache_dir);
}

my $cache_file = "$cache_dir/".$x."_".$y.".png";
if (!-r $cache_file || !-s $cache_file) {
    open my $ofh, ">", $cache_file
	or die "Can't write to $cache_file: $!";

    require BBBikeDraw::MapServer;
    my $draw = BBBikeDraw->new
	(NoInit => 1,
	 Fh => $ofh,
	 Geometry => $grid."x".$grid,
	 Draw => ["all"],
	 Outline => 1,
	 Scope => "wideregion",
	 ImageType => "png",
	 Module => "MapServer",
	);
    $draw->set_bbox($centerx+$deltax*$x,$centery+$deltay*$y,
		    $centerx+$deltax*($x+1),$centery+$deltay*($y+1),
		   );
    $draw->init;
    $draw->create_transpose(-asstring => 1);
    $draw->draw_map;
    $draw->flush;
    close $ofh or die $!;
}

open my $fh, $cache_file or die $!;
local $/ = \8192;
while (<$fh>) {
    print $_;
}

=head1 SYNC

   cd ~/src/bbbike && rsync -e "ssh -2 -p 5022" -a cgi/gridserv.cgi root@bbbike.de:/var/www/domains/radzeit.de/www/cgi-bin/gridserv.cgi
   cd ~/src/bbbike && rsync -e "ssh -2 -p 5022" -a html/google2brb.* root@bbbike.de:/var/www/domains/radzeit.de/www/BBBike/html/

=cut
