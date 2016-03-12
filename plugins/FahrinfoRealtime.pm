# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2006,2010,2016 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Description (de): Interface zu ÖPNV-Ist-Fahrzeiten bei Fahrinfo
package FahrinfoRealtime;

use BBBikePlugin;
push @ISA, 'BBBikePlugin';

use strict;
use vars qw($VERSION);
$VERSION = '1.05';

use vars qw($icon);

use Strassen::Strasse;

# XXX use Msg.pm some day
sub M ($) { $_[0] } # XXX
sub Mfmt { sprintf M(shift), @_ } # XXX

sub register {
    my $is_berlin = $main::city_obj && $main::city_obj->cityname eq 'Berlin';
    if ($is_berlin) {
	_create_image();
	$main::info_plugins{__PACKAGE__ . ""} =
	    { name => "Ist-Abfahrtszeiten ÖPNV",
	      callback => sub { show(@_) },
	      visibility => sub { visibility(@_) },
	      icon => $icon,
	    };
    } else {
	main::status_message("Das FahrinfoRealtime-Plugin ist nur für Berlin verfübar.", "err")
		if !$main::booting;
    }
}

sub _create_image {
    if (!defined $icon) {
	# Got from: http://www.bvg.de/images/favicon.ico
	# and scaled to 16x16 using ImageMagick/convert
	$icon = $main::top->Photo
	    (-format => 'gif',
	     -data => <<EOF);
R0lGODlhEAAQAPcAAB8cByclCCkkByklByglCCklCS4rBy0pCSwoCi0qCC8sCTEtCDAtCjMu
DD05CTw5DEE+C0E/DEZADEhCDElCDUxFDUxHDU5GDEVCEEtIEFFLDlVSEFlWEVxWEV1YEWRf
D2BZE2FYE2JbEWBcE2JgEGdiE2ZgFWlhEm5mFG5pFXZuF3lvFYV7F4iAF4qEGY+HGZKKHJWK
GJeLGZeLGpmPG5WRHZyUGqCVHaOXHKKYG6OaH6idHqSaIKegHKmhH6yjHbClHrCnH7OpHraw
H6+oIbCkILSpILSrIbmwIsS5IsW9I8i6IMi8I8/DJM3GItDCJNDGJdTIJtXKJdbIKNfMKdjI
JNjMI9rPJd7PJ9jNKNrRJtvRKODTJ+TTJubWJebYKuTdKu/fLO/iKPPiK/HiLPLlK/XjLfTl
LPXkLPXmLPfnLfrpLPvrLv3rKfzrK/3qK/3rKv3rK/7qKv7qK/7rKv7rK//qK//rKv/rK/zq
LPzrLf3qLP3rLP3rLv7qLP7qLf7rLP7rLf/qLP/rLP7qLv7rLv3sKf3sK/7tKf7sKv7tK//u
Kv/uK//vKv7sLP7tLP7tLf/sLP7tLv7uLP/uLf/vLP/vLf/uLv/uL//vLv/wLf/wLszMzAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAJwALAAAAAAQABAAAAj4AAcJHEiwoMGD
BO3gsaNwEJ6HDhc29ONHkMU5gyzasUhxkJ04cerU+QMIkJ85gP78ARlSjhw/K/nwiQOnDh+T
cgC9kUOH0aJEgSTB4QOJjyNGiNoQojOmyhQyZrrkQeNFT5gnWNYAurTDgIMSRS58EfIhSwgG
FJpQqgQjgg8EPA4kYSHCBQQnUsQUyiQjAQkNWizUMNHiBAomOrhE0jSjgAcJW1SAqEBkxIof
AXBoyhRjghIBQ3oMWEAlRQcwGGxUakSDwIYHVqIAyFDGiAIODY5gUnQlxw0obNIAWaJIDZIX
Qc7c2XOo0qZHbgxVgvQGziRLlQz1CQgAOw==
EOF
    }
}

sub show {
    my(%args) = @_;
    my $street = $args{street};
    $street = Strasse::strip_bezirk($street);
    my @tags = @{ $args{tags} };
    my($type) = grep { /^[ub]-fg/ } @tags;
    my $haltestelle = "";
    if ($type) {
	$type =~ s{^(.).*}{$1};
	$type = "s" if $type =~ /^b$/i;
	$haltestelle .= "$type ";
    }
    $haltestelle .= $street;
    $haltestelle =~ s{^\s*\(}{};
    $haltestelle =~ s{\)\s*$}{};
    get_and_show_result($haltestelle);
}

sub visibility {
    my(%args) = @_;
    return 0 if (!$args{street});
    my @tags = @{ $args{tags} };
    return 0 if (!grep { /^[ub]-fg/ || /^s$/ } @tags);
    1;
}

sub get_and_show_result {
    my($haltestelle) = @_;
    require CGI;
    require Encode;
    $haltestelle = Encode::encode("iso-8859-1", $haltestelle);
    CGI->import('-oldstyle_urls');
    my $qs = CGI->new({ input  => $haltestelle,
			submit => 'Anzeigen',
		      })->query_string;
    my $url = 'http://www.fahrinfo-berlin.de/IstAbfahrtzeiten/index;ref=1?' . $qs;
    start_browser($url);
}

sub start_browser {
    my($url) = @_;
    main::status_message("Der WWW-Browser wird mit der URL $url gestartet.", "info");
    require WWWBrowser;
    WWWBrowser::start_browser($url);
}

__END__
