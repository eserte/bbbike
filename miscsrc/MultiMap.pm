# -*- perl -*-

#
# $Id: MultiMap.pm,v 1.1 2006/01/11 22:39:22 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2006 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package MultiMap;

use BBBikePlugin;
push @ISA, 'BBBikePlugin';

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

sub register {
    $main::info_plugins{__PACKAGE__ . ""} =
	{ name => "MultiMap",
	  callback => sub { showmap(@_) },
	  callback_3_std => sub { showmap_url(@_) },
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

sub start_browser {
    my($url) = @_;
    main::status_message("Der WWW-Browser wird mit der URL $url gestartet.", "info");
    WWWBrowser::start_browser($url);
}

1;

__END__
