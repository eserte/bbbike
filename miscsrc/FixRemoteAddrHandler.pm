# -*- perl -*-

#
# $Id: FixRemoteAddrHandler.pm,v 1.3 2007/03/31 20:08:08 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2006,2009 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package FixRemoteAddrHandler;

=head1 NAME

FixRemoteAddrHandler - fix remote IP addresses for behind-proxy operation

=head1 SYNOPSIS

Usage in httpd.conf:

   PerlRequire /home/e/eserte/src/bbbike/miscsrc/FixRemoteAddrHandler.pm
   PerlLogHandler FixRemoteAddrHandler::handler

When using Apache2 and mod_perl2:

   <Perl>
       use Apache2::compat;
   </Perl>

and then the same as before.

=cut

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

use Apache::Constants qw(DECLINED);

sub handler {
    my $r = shift;

    my $forwarded_for = $r->header_in("X-Forwarded-For");
    if ($forwarded_for) {
	$r->connection->remote_ip($forwarded_for);
    }

    DECLINED;
}

1;

__END__
