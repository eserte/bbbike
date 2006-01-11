# -*- perl -*-

#
# $Id: AltBerlin.pm,v 1.1 2006/01/11 21:54:58 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2006 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package AltBerlin;

use BBBikePlugin;
push @ISA, 'BBBikePlugin';

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

sub register {
    $main::info_plugins{__PACKAGE__ . ""} =
	{ name => "Alt-Berlin (1946)",
	  callback => sub { altberlin(@_) },
	};
}

sub altberlin {
    my(%args) = @_;

    my $px = $args{px};
    my $py = $args{py};

    my $url = sprintf "http://www.alt-berlin.info/cgi/stp/lana.pl?nr=10&gr=5&nord=%f&ost=%f", $py, $px;
    start_browser($url);
}

sub start_browser {
    my($url) = @_;
    main::status_message("Der WWW-Browser wird mit der URL $url gestartet.", "info");
    WWWBrowser::start_browser($url);
}

1;

__END__


