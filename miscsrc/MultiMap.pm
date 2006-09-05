# -*- perl -*-

#
# $Id: MultiMap.pm,v 1.4 2006/09/05 21:40:39 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2006 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Description (en): Link to GoYellow, WikiMapia and MultiMap
# Description (de): Links zu GoYellow, WikiMapia und MultiMap
package MultiMap;

use BBBikePlugin;
push @ISA, 'BBBikePlugin';

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

sub register {
    $main::info_plugins{__PACKAGE__ . "_MultiMap"} =
	{ name => "MultiMap",
	  callback => sub { showmap(@_) },
	  callback_3_std => sub { showmap_url(@_) },
	};
    $main::info_plugins{__PACKAGE__ . "_GoYellow"} =
	{ name => "GoYellow",
	  callback => sub { showmap_goyellow(@_) },
	  callback_3_std => sub { showmap_url_goyellow(@_) },
	};
    $main::info_plugins{__PACKAGE__ . "_WikiMapia"} =
	{ name => "WikiMapia",
	  callback => sub { showmap_wikimapia(@_) },
	  callback_3_std => sub { showmap_url_wikimapia(@_) },
	};
}

sub showmap_url {
    my(%args) = @_;

    my $px = $args{px};
    my $py = $args{py};
    my $scale = $args{mapscale_scale};
    my @allowed_scales = (5000, 10000, 25000, 50000, 100000, 200000,
			  500_000, 1_000_000, 2_000_000, 4_000_000,
			  10_000_000, 20_000_000, 40_000_000);
 TRY: {
	for my $i (0 .. $#allowed_scales-1) {
	    if ($scale < ($allowed_scales[$i]+$allowed_scales[$i+1])/2) {
		$scale = $allowed_scales[$i];
		last TRY;
	    }
	}
	$scale = $allowed_scales[0];
    }
	
    sprintf "http://www.multimap.com/map/browse.cgi?scale=%d&lon=%f&lat=%f", $scale, $px, $py;
}

sub showmap {
    my(%args) = @_;
    my $url = showmap_url(%args);
    start_browser($url);
}

sub showmap_url_goyellow {
    my(%args) = @_;

    my $px = $args{px};
    my $py = $args{py};
    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    sprintf "http://www.goyellow.de/map?lat=%f&lon=%f&z=%d&mt=1",
	$py, $px, $scale;
}

sub showmap_goyellow {
    my(%args) = @_;
    my $url = showmap_url_goyellow(%args);
    start_browser($url);
}

sub showmap_url_wikimapia {
    my(%args) = @_;

    my $px = $args{px};
    my $py = $args{py};

    for ($px, $py) {
	s{\.}{};
	$_ = substr($_, 0, 8); # XXX what about <10° and >100°?
	if (length($_) < 8) {
	    $_ .= " "x(8-length($_));
	}
    }

    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    sprintf "http://wikimapia.org/s/#y=%s&x=%s&z=%d&l=5&m=a",
	$py, $px, $scale;
}

sub showmap_wikimapia {
    my(%args) = @_;
    my $url = showmap_url_wikimapia(%args);
    start_browser($url);
}

sub start_browser {
    my($url) = @_;
    main::status_message("Der WWW-Browser wird mit der URL $url gestartet.", "info");
    WWWBrowser::start_browser($url);
}

1;

__END__
