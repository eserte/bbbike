# -*- perl -*-

#
# $Id: BBBikeGoogleMaps.pm,v 1.7 2008/02/09 18:59:13 eserte Exp $
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
$VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

use base qw(BBBikeDraw);

use vars qw($bbbike_googlemaps_url $maptype);
if (!defined $bbbike_googlemaps_url) {
    if ($ENV{SERVER_NAME} && $ENV{SERVER_NAME} eq 'www.herceg.de' && $ENV{REMOTE_ADDR} eq '192.168.1.5') {
	$bbbike_googlemaps_url = "http://localhost/~eserte/bbbike/cgi/bbbikegooglemap.cgi";
    } else {
	# Unfortunately I cannot use $BBBIKE_GOOGLEMAP_URL from BBBikeVar.pm here,
	# because it seems that POSTs content is not sent through the rewriting
	# rules...
	$bbbike_googlemaps_url = "http://78.47.225.30/cgi-bin/bbbikegooglemap.cgi";
	# XXX IP address will be changed to bbbike.de some day ...
    }
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

# nop, automatically drawn if coordinates exist
sub draw_route { }

# Without the need to POST:
sub flush_direct_redirect {
    my $self = shift;
    my $q = $self->{CGI} || CGI->new;
    my @wpt;
    if ($self->{BBBikeRoute}) {
	for my $wpt (@{ $self->{BBBikeRoute} }) {
	    push @wpt, join "!", $wpt->{Strname}, $wpt->{Coord};
	}
    }
    my @multi_c = @{ $self->{MultiCoords} || [] } ? @{ $self->{MultiCoords} } : @{ $self->{Coords} || [] } ? [ @{ $self->{Coords} } ] : ();
    my $q2 = CGI->new({coords  => [map { join "!", @$_ } @multi_c],
		       maptype => $maptype,
		       (@wpt ? (wpt => \@wpt) : ()),
		       (!@multi_c && !@wpt ? (wpt => join(",", $self->get_map_center)) : ()),
		      });
    print $q->redirect($bbbike_googlemaps_url . "?" . $q2->query_string);
    return;
}

sub mimetype { "text/html" }

sub flush {
    my $self = shift;
    my $q = $self->{CGI} || CGI->new;
    my @multi_c = @{ $self->{MultiCoords} || [] } ? @{ $self->{MultiCoords} } : @{ $self->{Coords} || [] } ? [ @{ $self->{Coords} } ] : ();
    my $oldcoords =
	@{ $self->{OldCoords} || [] }
	    ? join "!", @{ $self->{OldCoords} }
		: undef;
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
    for my $c (@multi_c) {
	my $coords = join "!", @$c;
	print $fh hidden("coords", $coords);
    }
    if (!@multi_c) {
	print $fh hidden("wpt", join(",", $self->get_map_center));
    }
    print $fh hidden("oldcoords", $oldcoords) if $oldcoords;
    print $fh hidden("maptype", $maptype);
    for my $wpt (@wpt) {
	print $fh hidden("wpt", $wpt);
    }
    print $fh "<noscript>";
    print $fh submit("Weiterleitung auf bbbikegooglemaps");
    print $fh "</noscript>";
    print $fh end_form, end_html;
}

sub get_map_center {
    my($self) = @_;
    my $x = int(($self->{Max_x} - $self->{Min_x})/2 + $self->{Min_x});
    my $y = int(($self->{Max_y} - $self->{Min_y})/2 + $self->{Min_y});
    ($x, $y);
}

1;

__END__
