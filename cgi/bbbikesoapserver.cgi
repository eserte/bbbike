#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbbikesoapserver.cgi,v 1.3 2005/05/12 21:11:55 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

# This is meant as a fallback, if mod_perl is not enabled or unstable

use FindBin;

use SOAP::Transport::HTTP;
SOAP::Transport::HTTP::CGI
#    ->dispatch_to('/home/e/eserte/src/bbbike/miscsrc', 'BBBikeSOAP')
    ->dispatch_to("$FindBin::RealBin/../miscsrc", 'BBBikeSOAP')
#    ->options => {compress_threshold => 10000}
    ->handle;

# No __END__ !
