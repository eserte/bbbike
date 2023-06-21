#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2008,2023 Slaven Rezic. All rights reserved.
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

use constant DEFAULT_SNAPSHOT_IS_LOCAL => 0;

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

my $local = $q->param('local');
if (!defined $local || $local eq '') {
    $local = DEFAULT_SNAPSHOT_IS_LOCAL;
}

if ($local) {
    # Do not use FindBin, because it does not work with Apache::Registry
    (my $target = $0) =~ s{bbbike-snapshot.cgi}{bbbike-data.cgi};
    do $target;
} else {
    print $q->redirect($BBBike::BBBIKE_UPDATE_GITHUB_ARCHIVE);
}

# no __END__ for Apache::Registry
