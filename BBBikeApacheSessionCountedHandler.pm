# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2011 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeApacheSessionCountedHandler;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use BBBikeApacheSessionCounted;

use Apache2::Const qw(OK);
use Apache2::RequestRec ();
use Apache2::RequestIO ();

sub handler : method {
    my($class, $r) = @_;
    my $session_id = $r->args;
    my $sess = BBBikeApacheSessionCounted::tie_session($session_id);
    if (!$sess) {
	die "Cannot tie session with id $session_id";
    }
    $r->content_type('application/octet-stream');
    $r->print((tied %$sess)->{serialized});
    OK;
}

1;

__END__
