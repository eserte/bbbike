#!/usr/bin/env perl
# -*- perl -*-

#
# $Id: check_browserinfo.pl,v 1.1 2000/07/24 23:13:19 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2000 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

use FindBin;
use lib "$FindBin::RealBin/../lib";
use BrowserInfo;

open(L, "../misc/browserlist.txt") or die $!;
while(<L>) {
    chomp;
    $ENV{HTTP_USER_AGENT} = $_;
    my $bi = new BrowserInfo(CGI->new({}));
    print <<EOF;
$ENV{HTTP_USER_AGENT}:
      NAME=$bi->{'user_agent_name'}
   VERSION=$bi->{'user_agent_version'}
	OS=$bi->{'user_agent_os'}
    COMPAT=$bi->{'user_agent_compatible'}

EOF
}
close L;

1;

__END__
