#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: mapserver_comment.cgi,v 1.12 2004/05/09 13:58:31 eserte Exp $
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
use vars qw($realbin);
use FindBin;
BEGIN { # taint fixes
    ($realbin) = $FindBin::RealBin =~ /^(.*)$/;
    $ENV{PATH} = "/usr/bin:/usr/sbin:/bin:/sbin";
}
# from bbbike.cgi
use lib (#"/home/e/eserte/src/bbbike",
	 "$realbin/..", # falls normal installiert
	 "$realbin/../BBBike", # falls in .../cgi-bin/... installiert
	 "$realbin/BBBike", # weitere Alternative
	);
use BBBikeVar;
use Mail::Send;
use File::Basename;
use CGI qw(:standard -no_xhtml);
use vars qw($debug $bbbike_url $bbbike_root $bbbike_html $use_cgi_bin_layout
	    @Mail_Send_open);

eval {
    local $SIG{'__DIE__'};
    #warn "$0.config";
    do "$realbin/bbbike.cgi.config";
};
warn $@ if $@;

my($to, $comment);

eval {
    # from bbbike.cgi:
    $bbbike_url = url;
    ($bbbike_root = $bbbike_url) =~ s|[^/]*/[^/]*$|| if !defined $bbbike_root;
    if (!defined $bbbike_html) {
	$bbbike_html   = "$bbbike_root/" . ($use_cgi_bin_layout ? "BBBike/" : "") .
	    "html";
    }

    $to = $BBBike::EMAIL;
    my $mscgi_remote = $BBBike::BBBIKE_MAPSERVER_URL;
    my $mscgi_local  = "http://www/~eserte/cgi/mapserv.cgi";
    my $msadrcgi_remote = dirname($BBBike::BBBIKE_MAPSERVER_URL) . "/mapserver_address.cgi";
    my $msadrcgi_local = "http://www/~eserte/bbbike/cgi/mapserver_address.cgi";

    if ($debug) {
	require Sys::Hostname;
	if (Sys::Hostname::hostname() =~ /herceg\.de$/) {
	    $to = "eserte\@vran.herceg.de";
	}
    }

    my $subject = param("subject") || "BBBike/Mapserver comment";
    $subject = substr($subject, 0, 70) . "..." if length $subject > 70;
    my $msg = Mail::Send->new(Subject => $subject,
			      To      => $to,
			     );
    die "Kann kein Mail::Send-Objekt erstellen" if !$msg;

    my $mapx = param("mapx");
    my $mapy = param("mapy");

    my($link1, $link2);

    if (0) {
	# XXX link query is different for remote server
	# XXX supply also the image extents?
	my $link_query = "mapxy=" . CGI::escape("$mapx $mapy") . "&layer=qualitaet&layer=handicap&layer=radwege&layer=bahn&layer=gewaesser&layer=flaechen&layer=grenzen&layer=orte&layer=route&mode=nquery&map=%2Fhome%2Fe%2Feserte%2Fsrc%2Fbbbike%2Fmapserver%2Fbrb%2Fbrb.map&program=%2F%7Eeserte%2Fcgi%2Fmapserv.cgi";

	my($map_width,$map_height) = (4000, 4000); # meters
	my($img_width,$img_height) = (550, 550); # pixels

	my($minx,$maxx,$miny,$maxy) = ($mapx-$map_width/2, $mapx+$map_width/2,
				       $mapy-$map_height/2, $mapy+$map_height/2);
	$link_query="map=%2Fhome%2Fe%2Feserte%2Fsrc%2Fbbbike%2Fmapserver%2Fbrb%2Fbrb.map&mode=browse&zoomdir=0&zoomsize=2&imgxy=" . CGI::escape($img_width/2 . " " . $img_height/2) . "&imgext=" . CGI::escape("$minx $miny $maxx $maxy") . "&program=%2F%7Eeserte%2Fcgi%2Fmapserv.cgi";

	$link1 = "$mscgi_remote?$link_query";
	$link2 = "$mscgi_local?$link_query";
    } else {
	if (defined $mapx && defined $mapy) {
	    my $coords_esc = CGI::escape(join(",", map { int } ($mapx, $mapy)));
	    $link1 = "$msadrcgi_remote?coords=$coords_esc";
	    $link2 = "$msadrcgi_local?coords=$coords_esc";
	}
    }

    if (param("email")) {
	$msg->add("Reply-To", param("email"));
    }

    my $fh = $msg->open(@Mail_Send_open);
    die "Kann open mit @Mail_Send_open nicht durchführen" if !$fh;

    $comment =
	"Von: " . (param("email")||"anonymous\@bbbike.de") . "\n" .
	"An:  $to\n\n" .
	(defined $mapx ? "Kartenkoordinaten: " . $mapx . "/" . $mapy . "\n\n" : "") .
        "Kommentar:\n" .
	param("comment") . "\n";
    print $fh $comment . "\n";
    print $fh "Remote: ", $link1, "\n" if defined $link1;
    print $fh "Lokal:  ", $link2, "\n" if defined $link2;
    $fh->close or die "Can't close mail filehandle";

    print header,
	start_html(-title=>"Kommentar abgesandt",
		   -style=>{'src'=>"$bbbike_html/bbbike.css"}),
	"Danke, der folgende Kommentar wurde an $to gesendet:",br(),br(),
	 pre($comment),
	 end_html;
};
if ($@) {
    warn $@;
    error_msg($@);
}

sub error_msg {
    print header,
	  start_html(-title=>"Fehler beim Versenden",
		     -style=>{'src'=>"$bbbike_html/bbbike.css"}),
	  "Der Kommentar konnte wegen eines internen Fehlers ($_[0])nicht abgesandt werden. Bitte stattdessen eine Mail an ", a({-href=>"mailto:$to"},$to),
	  " mit dem folgenden Inhalt versenden:",br(),br(),
	  pre($comment),
	  end_html;
    exit;
}

__END__

=head1 NAME

mapserver_comment.cgi - send comments about mapserver data

=head1 SYNOPSIS

none

=head1 DESCRIPTION

Send comments about mapserver data via email. The receiver is the
C<$EMAIL> address in L<BBBikeVar>.

=head2 Configuration

To define the mail sending method, define the C<@Mail_Send_open>
variable in C<bbbike.cgi.config>. The value of this variable is the
same as the arguments of the C<open> method of L<Mail::Send>. To
define an SMTP server, use the following:

    @Mail_Send_open = ("smtp", Server => "mail.example.com");

=head1 AUTHOR

Slaven Rezic

=cut
