# -*- perl -*-

#
# $Id: CNetFilePerl.pm,v 1.7 2003/01/08 20:59:08 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001, 2002 Slaven Rezic. All rights reserved.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package StrassenNetz::CNetFilePerl;

package StrassenNetz::CNetFile;

use Strassen::StrassenNetz;
use Strassen::StrassenNetzHeavy; # XXX hack
@StrassenNetz::CNetFile::ISA = qw(StrassenNetz);
use strict;

sub make_net {
    my($self) = @_;
    my $cache_prefix = Strassen::Util::get_cachefile($self->get_cachefile);

    require Strassen::Build;
    require Strassen::Util;
    require Storable;

    my $try = 0;
# XXX do not hardcode "gesperrt"
    $self->create_mmap_net_if_needed($cache_prefix, -blocked => "gesperrt");
    $self->mmap_net_file($self->filename_c_net_mmap($cache_prefix));

    $self->{CNetCoord2Ptr} = Strassen::Util::get_from_cache($self->get_cachefile . "_coord2ptr", [$self->{Strassen}->{File}])
	or die "Should not happen: Cachefile coord2ptr is not current";
    $self->{Net2Name} = Strassen::Util::get_from_cache($self->get_cachefile . "_net2name", [$self->{Strassen}->{File}])
	or die "Should not happen: Cachefile net2name is not current";

    if ($StrassenNetz::VERBOSE) {
	warn "Strassen::CNetFile::make_net finished\n";
    }
}

sub reachable {
    my($self, $coord) = @_;
    exists $self->{CNetCoord2Ptr}->{$coord};
}

1;
