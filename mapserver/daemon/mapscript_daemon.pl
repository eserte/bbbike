#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: mapscript_daemon.pl,v 1.2 2003/07/08 22:15:15 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use FindBin;
#use lib "$FindBin::RealBin/../../lib";
#use Text::ScriptTemplate;
use HTTP::Daemon;
use HTTP::Status;
# XXX do not hardcode
use blib "/usr/local/src/mapserver/mapserver-3.6.4/mapscript/perl";
use mapscript;
use CGI qw(:standard -no_xhtml);
use File::Temp qw(tempfile);
use File::Spec;
use File::Basename qw(basename);
use Getopt::Long;
use strict;

my $DEBUG = 0;
my $port = 1234;
my $mapfile = "brb-b.map";

if (!GetOptions("p|port=i" => \$port,
		"debug!" => \$DEBUG,
		"mapfile=s" => \$mapfile,
	       )) {
    die "usage!";
}

my $d = HTTP::Daemon->new(LocalPort => $port) || die;
print "Please contact me at: <URL:", $d->url, ">\n";
while (my $c = $d->accept) {
    my $r = $c->get_request;
    warn "Got request " . $r->method . " path=" . $r->url->path
	if $DEBUG;
    if ($r->method eq 'GET' and $r->url->path =~ m{/image/(.*)}) {
	my $img = $1;
	my $fs_file = File::Spec->catfile(File::Spec->tmpdir(), $img);
	$c->send_file_response($fs_file);
	unlink $fs_file;
    } else {
	$c->send_basic_header(200);
	my($fh, $filename) = tempfile(UNLINK => 1, SUFFIX => ".html");
	base_page($fh);
	close $fh;
	$c->send_file_response($filename);
	unlink $filename;
	warn "sent page $filename"
	    if $DEBUG;
    }

    $c->force_last_request;
    $c->close;
    undef($c);
    warn "waiting for new connection"
	if $DEBUG;
}

sub base_page {
    my $fh = shift;
    print $fh start_html();

    my $abs_mapfile = "$FindBin::RealBin/../brb/" . $mapfile;
    my $map = new mapscript::mapObj($abs_mapfile)
	or die "Can't open $abs_mapfile";
    my $img = $map->draw();

    my $url = $img->saveWebImage(1, 0, 0, 0);
    printf $fh "<IMG SRC=\"%s\" WIDTH=%d HEIGHT=%d>\n", $url, $map->{width}, $map->{height};
    $img = $map->drawLegend();
    $url = $img->saveWebImage(1, 0, 0, 0);
    printf $fh "<P><IMG SRC=\"%s\">\n", $url;

    $img = $map->drawScalebar();
    $url = $img->saveWebImage(1, 0, 0, 0);
    printf $fh "<P><IMG SRC=\"%s\">\n", $url;

    print $fh end_html();
}

sub mapscript::imageObj::saveWebImage {
    my($img, $type) = @_;
    my($fh, $temp) = tempfile(DIR => File::Spec->tmpdir(),
			      SUFFIX => ".png");
    $img->saveImage($temp, $type, 0, 0, 0);
    chmod 0644, $temp;
    "/image/" . basename($temp);
}


__END__
