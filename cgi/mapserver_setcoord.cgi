#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: mapserver_setcoord.cgi,v 1.2 2003/05/29 20:24:21 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use CGI qw(:standard);
use strict;

my $imgwidth = 550; # XXX 
my $imgheight = 550; # XXX

my @imgext = split / /, param("imgext");
my $mapwidth = $imgext[2] - $imgext[0];
my $mapheight = $imgext[3] - $imgext[1];
my $set = param("coordset");
param($set . "c", join(",",
		       param("img.x")/$imgwidth*$mapwidth   + $imgext[0],
		       $imgext[3] - param("img.y")/$imgheight*$mapheight));
if ($set eq 'ziel') {
    my $q2 = CGI->new(query_string());
    $q2->param("output_as", "mapserver");
    $q2->param("pref_seen", "true");
    $q2->param("startc", param("startc"));
    $q2->param("zielc", param("zielc"));
    print redirect("http://www/~eserte/bbbike/cgi/bbbike.cgi?"
		   . $q2->query_string);
} else { # start
#XXX    my $q2 = CGI->new(query_string());
#    print redirect(referer() . "&startc=" . param("startc"));
    push @INC, "/home/e/eserte/src/bbbike"; # XXX
    require BBBikeMapserver;
    require FindBin; $FindBin::RealBin = $FindBin::RealBin; # peacify -w
    my $ms = BBBikeMapserver->new(-tmpdir => "/tmp"); # XXX
    $ms->read_config("$FindBin::RealBin/bbbike.cgi.config");
    $ms->start_mapserver(-start => param("startc")); # XXX bbbikeurl etc.
}

