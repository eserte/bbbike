#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbbike-snapshot.cgi,v 1.2 2008/02/22 21:56:08 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2008 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib "$FindBin::RealBin/..";
use CGI;
use BBBikeVar;

my $q = CGI->new;

{
    # Don't use RealBin here
    require FindBin;
    $FindBin::Bin = $FindBin::Bin if 0; # cease -w
    my $f = "$FindBin::Bin/Botchecker_BBBike.pm";
    if (-r $f) {
	eval {
	    local $SIG{'__DIE__'};
	    require $f;
	    Botchecker_BBBike::run_bbbike_snapshot($q);
	};
	warn $@ if $@;
    }
}

if ($q->param('local')) {
    # Do not use FindBin, because it does not work with Apache::Registry
    (my $target = $0) =~ s{bbbike-snapshot.cgi}{bbbike-data.cgi};
    do $target;
} else {
    print $q->redirect($BBBike::BBBIKE_UPDATE_GITHUB_ARCHIVE);
}

# no __END__ for Apache::Registry
