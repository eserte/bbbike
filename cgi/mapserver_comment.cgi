#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: mapserver_comment.cgi,v 1.1 2003/01/01 21:00:49 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
# from bbbike.cgi
use lib (#"/home/e/eserte/src/bbbike",
	 "$FindBin::RealBin/..", # falls normal installiert
	 "$FindBin::RealBin/../BBBike", # falls in .../cgi-bin/... installiert
	 "$FindBin::RealBin/BBBike", # weitere Alternative
	);
use BBBikeVar;
use Mail::Send;
use CGI qw(:standard -no_xhtml);
use vars qw($debug $bbbike_url $bbbike_root $bbbike_html $use_cgi_bin_layout);

eval {
    local $SIG{'__DIE__'};
    #warn "$0.config";
    do "$FindBin::RealBin/bbbike.cgi.config";
};
warn $@ if $@;

# from bbbike.cgi:
$bbbike_url = url;
($bbbike_root = $bbbike_url) =~ s|[^/]*/[^/]*$|| if !defined $bbbike_root;
if (!defined $bbbike_html) {
    $bbbike_html   = "$bbbike_root/" . ($use_cgi_bin_layout ? "BBBike/" : "") .
	"html";
}

my $to = $BBBike::EMAIL;
my $mscgi_remote = $BBBike::BBBIKE_MAPSERVER_URL;
my $mscgi_local  = "http://www/~eserte/cgi/mapserv.cgi";
if ($debug) {
    require Sys::Hostname;
    if (Sys::Hostname::hostname() =~ /herceg\.de$/) {
	$to = "eserte";
    }
}

my $msg = Mail::Send->new(Subject => "BBBike/Mapserver comment",
			  To      => $to,
			 );

my $mapx = param("mapx");
my $mapy = param("mapy");
# XXX link query is different for remote server
# XXX supply also the image extents?
my $link_query = "mapxy=" . CGI::escape("$mapx $mapy") . "&layer=qualitaet&layer=handicap&layer=radwege&layer=bahn&layer=gewaesser&layer=flaechen&layer=grenzen&layer=orte&layer=route&mode=nquery&map=%2Fhome%2Fe%2Feserte%2Fsrc%2Fbbbike%2Fmapserver%2Fbrb%2Fbrb.map&program=%2F%7Eeserte%2Fcgi%2Fmapserv.cgi";
my $link1 = "$mscgi_remote?$link_query";
my $link2 = "$mscgi_local?$link_query";

my $fh = $msg->open;
my $comment =
    "Kartenkoordinaten: " . $mapx . "/" . $mapy . "\n" .
    "Von: " . (param("email")||"anonymous\@bbbike.de") . "\n" .
    "An:  $to\n" .
    "Kommentar:\n" .
    param("comment") . "\n";
print $fh $comment;
print $fh "Remote: ", $link1, "\n";
print $fh "Lokal:  ", $link2, "\n";
$fh->close;

print header,start_html(-title=>"Kommentar abgesandt",
			-style=>{'src'=>'/~eserte/bbbike/html/bbbike.css'}),
    pre("Danke, der folgende Kommentar wurde abgesandt:\n\n" . $comment),
    end_html;

__END__
