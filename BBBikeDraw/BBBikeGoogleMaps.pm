# -*- perl -*-

#
# $Id: BBBikeGoogleMaps.pm,v 1.3 2007/05/04 20:39:34 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2007 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://bbbike.sourceforge.net
#

package BBBikeDraw::BBBikeGoogleMaps;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

use base qw(BBBikeDraw);

use vars qw($bbbike_googlemaps_url $maptype);
if (!defined $bbbike_googlemaps_url) {
    # Unfortunately I cannot use $BBBIKE_GOOGLEMAP_URL from BBBikeVar.pm here,
    # because it seems that POSTs content is not sent through the rewriting
    # rules...
    $bbbike_googlemaps_url = "http://bbbike.radzeit.de/cgi-bin/bbbikegooglemap.cgi";
}

$maptype = "hybrid" unless $maptype;

use CGI qw(:standard);

use Karte;
Karte::preload(qw(Standard Polar));

sub module_handles_all_cgi { 1 }

sub pre_draw {
    my $self = shift;
    $self->{PreDrawCalled}++;
}

sub flush_direct_redirect {
    my $self = shift;
    my $q = $self->{CGI} || CGI->new;
    my $coords = join "!", @{ $self->{Coords} || [] };
    my @wpt;
    if ($self->{BBBikeRoute}) {
	for my $wpt (@{ $self->{BBBikeRoute} }) {
	    push @wpt, join "!", $wpt->{Strname}, $wpt->{Coord};
	}
    }
    my $q2 = CGI->new({coords  => $q->param("coords"),
		       maptype => $maptype,
		       (@wpt ? (wpt => \@wpt) : ()),
		      });
    print $q->redirect($bbbike_googlemaps_url . "?" . $q2->query_string);
    return;
}

sub mimetype { "text/html" }

sub flush {
    my $self = shift;
    my $q = $self->{CGI} || CGI->new;
    my $coords = join "!", @{ $self->{Coords} || [] };
    my @wpt;
    if ($self->{BBBikeRoute}) {
	for my $wpt (@{ $self->{BBBikeRoute} }) {
	    push @wpt, join "!", $wpt->{Strname}, $wpt->{Coord};
	}
    }

    my $fh = $self->{Fh} || \*STDOUT;

    print $fh header(-type => $self->mimetype,
		     -Vary => "User-Agent",
		    );
    print $fh start_html(-onLoad => "init()",
			 -script => <<EOF);
function init() {
    document.forms[0].submit();
}
EOF
    print $fh start_form(-action => $bbbike_googlemaps_url,
			 -method => "POST");
    print $fh hidden("coords", $coords);
    print $fh hidden("maptype", $maptype);
    for my $wpt (@wpt) {
	print $fh hidden("wpt", $wpt);
    }
    print $fh "<noscript>";
    print $fh submit("Weiterleitung auf bbbikegooglemaps");
    print $fh "</noscript>";
    print $fh end_form, end_html;
}

1;

__END__
