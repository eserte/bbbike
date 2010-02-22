# -*- perl -*-

#
# $Id: FahrinfoRealtime.pm,v 1.4 2008/01/15 21:02:20 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2006,2010 Slaven Rezic. All rights reserved.
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
$VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

use vars qw($icon);

use Strassen::Strasse;

# XXX use Msg.pm some day
sub M ($) { $_[0] } # XXX
sub Mfmt { sprintf M(shift), @_ } # XXX

sub register {
    _create_image();
    $main::info_plugins{__PACKAGE__ . ""} =
	{ name => "Ist-Abfahrtszeiten ÖPNV",
	  callback => sub { show(@_) },
	  visibility => sub { visibility(@_) },
	  icon => $icon,
	};
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

# Following the old code, not working anymore

sub get_and_show_result {
    my($haltestelle) = @_;
    eval {
	require LWP::UserAgent;
	require XML::LibXML;
	require CGI;
	require Encode;

	my $q = CGI->new({mstnr => $haltestelle,
			  language => "d",
			  client => "wap"});
	CGI->import('-oldstyle_urls');
	my $url = "http://www.fahrinfo-berlin.de/realtime/query?" . $q->query_string;
	#XXX my $url = "file:/tmp/bla.wml";
	main::status_message(M("Lade URL $url"), "info");
	warn $url;
	my $ua = LWP::UserAgent->new;
	my $resp = $ua->get($url);
	if (!$resp->is_success) {
	    die M("Fehler beim Lesen der URL $url\n");
	}
	my $p = XML::LibXML->new;
	$p->recover(1);
	my $xml = $resp->content;
	$xml =~ s{^[\s\r\n]*}{}gm;
	Encode::from_to($xml, "iso-8859-1", "utf-8");

	my $root = $p->parse_string($xml);
	my $doc = $root->documentElement;

warn "[$xml]";

	if ($xml =~ /Ihre Eingabe konnte nicht interpretiert werden/i) {
	    my($new_haltestelle) = $haltestelle =~ m{^(.*)\s+\S+$};
	    if ($new_haltestelle && length($new_haltestelle) < length($haltestelle)) {
		return get_and_show_result($new_haltestelle);
	    }
	    # else fall through...
	}
	if ($doc->findnodes("//option")) {
	    my(@haltestellen) = map { $_->textContent } $doc->findnodes('//option/@value');
	    show_haltestellen_selection(\@haltestellen);
	} else {
	    my $res = "";
	    my $node_nr = 1;
	    for my $node ($doc->findnodes("/wml/card/p")) {
		if ($node_nr == 1) {
		    $res .= $node->textContent . "\n"; # title
		} elsif ($node->findnodes(".//a")) {
		    # link, ignore
		} else {
		    my $text = $node->textContent;
		    $res .= $text;
		}
		$node_nr++;
	    }
	    show_result($res);
	}
    };
    if ($@) {
	main::status_message($@, "err");
    }
}

sub show_result {
    my($res) = @_;
    if ($Tk::VERSION < 804) {
	$res = Encode::encode("iso-8859-1", $res);
    }
    my $txt = get_textwidget();
    $txt->insert("1.0", $res);
    
}

sub show_haltestellen_selection {
    my($haltestellen) = @_;
    if ($Tk::VERSION < 804) {
	$haltestellen = [ map { Encode::encode("iso-8859-1", $_) } @$haltestellen ];
    }
    my $txt = get_textwidget();

    my $linkcount = 0;
    for my $haltestelle (@$haltestellen) {
	$txt->insert("end", $haltestelle . "\n", "link$linkcount");
	$txt->tagBind("link$linkcount", "<ButtonRelease-1>" =>
		      [ sub {
			    get_and_show_result($_[1]);
			}, $haltestelle ]
		     );
	$linkcount++;
    }

    for (0 .. $linkcount-1) {
	$txt->tagConfigure("link$_", -underline => 1, -foreground => "blue3");
	$txt->tagBind("link$_", "<Enter>" => sub {
			  $txt->configure(-cursor => "hand2");
		      });
	$txt->tagBind("link$_", "<Leave>" => sub {
			  $txt->configure(-cursor => undef);
		      });
    }
}

sub get_textwidget {
    my $t = main::redisplay_top($main::top, __PACKAGE__,
				-title => M"Ist-Abfahrtszeiten",
				-class => "BbbikePassive",
			       );
    if (defined $t) {
	my $txt = $t->Scrolled("ROText", -scrollbars => "oe",
			       -width => 40, -height => 20,
			       -font => $main::font{fixed},
			       -wrap => "word",
			      )->pack(qw(-fill both -expand 1));
	$t->Advertise(Text => $txt);
    } else {
	$t = $main::toplevel{__PACKAGE__ . ""};
    }
    my $txt = $t->Subwidget("Text");
    $txt->delete("1.0", "end");
    $txt;
}

1;

__END__
