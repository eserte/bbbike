#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: redirect-bbbike.cgi,v 1.7 2005/03/24 07:30:31 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# XXX Wird dieses Skript irgendwo verwendet?

use strict;
use CGI qw(:standard);
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data",
	);

my $bbbike_url = "http://user.cs.tu-berlin.de/~eserte/bbbike/cgi/bbbike.cgi"; # the fallback
if (eval { require BBBikeVar; 1 }) {
    $BBBike::BBBIKE_DIRECT_WWW = $BBBike::BBBIKE_DIRECT_WWW; # peacify -w
    $bbbike_url = $BBBike::BBBIKE_DIRECT_WWW;
    #$bbbike_url = "http://www/~eserte/bbbike/cgi/bbbike.cgi";
} else {
    #warn "Can't get value of BBBIKE_DIRECT_WWW, use fallback:";
}

my $redirect = $bbbike_url;
if (query_string() ne "") {
    $redirect .= "?" . query_string();
}
print redirect($redirect);

__END__
