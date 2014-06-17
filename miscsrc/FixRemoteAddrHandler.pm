# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2006,2009,2011,2014 Slaven Rezic. All rights reserved.
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

    <IfModule mod_perl.c>
        PerlRequire .../path/to/bbbike/miscsrc/FixRemoteAddrHandler.pm
        PerlTransHandler FixRemoteAddrHandler::handler
        # alternatively use PerlLogHandler, but is not recommended
    </IfModule>

=cut

use strict;
use vars qw($VERSION);
$VERSION = '1.05';

use constant MP2 => (exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2);
BEGIN {
    if (MP2) {
	require Apache2::RequestRec;
	require Apache2::Connection;
	require Apache2::Const;
        Apache2::Const->import(qw(DECLINED));
    } else {
	require Apache::Constants;
	Apache::Constants->import(qw(DECLINED));
    }
}

sub handler {
    my $r = shift;

    my $forwarded_for = $r->headers_in->{"X-Forwarded-For"};
    if ($forwarded_for) {
	my(@ips) = split /\s*,\s*/, $forwarded_for;
	if ($ips[-1]) {
	    $r->connection->remote_ip($ips[-1]);
	}
    }

    DECLINED;
}

1;

__END__
