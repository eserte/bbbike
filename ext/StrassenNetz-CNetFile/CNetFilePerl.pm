# -*- perl -*-

#
# $Id: CNetFilePerl.pm,v 1.9 2003/04/13 15:57:02 eserte Exp $
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

    tie %{ $self->{Net} }, 'StrassenNetz::CNetFile::Net', $self;

    if ($StrassenNetz::VERBOSE) {
	warn "Strassen::CNetFile::make_net finished\n";
    }
}

sub reachable {
    my($self, $coord) = @_;
    exists $self->{CNetCoord2Ptr}->{$coord};
}

######################################################################
# These two classes are for $self->{Net}{$xy1}{$xy2} emulation. The
# first tie class returns the $self->{Net}{$xy1} part, while the second
# tie class returns the distance for $self->{Net}{$xy1}{$xy2}.
# No STOREs, DELETEs, EXISTS etc. are allowed.

package StrassenNetz::CNetFile::Net;

sub TIEHASH {
    my($pkg, $str_net) = @_;
    bless {StrassenNetz => $str_net}, $pkg;
}

sub FETCH {
    my($self, $key) = @_;
    tie my %val, 'StrassenNetz::CNetFile::Net_Level2',
	$self->{StrassenNetz}, $key;
    \%val;
}

sub STORE {
    die "A STORE is not allowed in " . __PACKAGE__ . ". Args: @_";
}

######################################################################

package StrassenNetz::CNetFile::Net_Level2;

sub TIEHASH {
    my($pkg, $str_net, $key1) = @_;
    bless {StrassenNetz => $str_net, Key1 => $key1}, $pkg;
}

# Some hackery here. We get all the neighbors for the point Key1 and
# check whether the neighbor matches $key2 through the internal mmap
# pointer. get_coord_struct returns pointers without mmap start added,
# while translate_pointer returns a pointer with mmap start added,
# thus we have to subtract the mmap start ($str_net->{CNetMmap}). If
# all ropes tear, then fallback to strecke_s.
sub FETCH {
    my($self, $key2) = @_;
    my $str_net = $self->{StrassenNetz};
    my(undef,undef,undef,@neighbors) = $str_net->get_coord_struct($str_net->translate_pointer($str_net->{CNetCoord2Ptr}->{$self->{Key1}}));
    my $n_ptr = $str_net->translate_pointer($str_net->{CNetCoord2Ptr}->{$key2}) - $str_net->{CNetMmap};
    for(my $n_i = 0; $n_i < $#neighbors; $n_i += 2) {
	if ($neighbors[$n_i] eq $n_ptr) {
	    return $neighbors[$n_i+1];
	}
    }
    warn "Can't find distance for $self->{Key1} - $key2! Try the hard way...";
    require Strassen::Util;
    int(Strassen::Util::strecke_s($self->{Key1}, $key2));
}

sub STORE {
    die "A STORE is not allowed in " . __PACKAGE__ . ". Args: @_";
}

1;
