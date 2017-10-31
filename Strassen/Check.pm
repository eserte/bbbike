# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2017 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Strassen::Check;

=head1 NAME

Strassen::Check - collection of functions for checking Strassen and StrassenNetz data integrity

=cut

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

=head1 DESCRIPTION

=head2 FUNCTIONS

=head3 get_island

    my $island_hashref = Strassen::Check::get_island($net, $act_coord);

For a given L<StrassenNetz> object I<$net> and a reference point
I<$act_coord> (format "x,y") return the "island" of all reachanble
points as a hash reference ("x,y" => undef, ...).

Formerly known as "flood_search" in L<search_inaccessible_points>.

=cut 

# XXX Here no handling of carry_points
sub get_island {
    my($net, $act_coord) = @_;
    my $net_net = $net->{Net};

    my($start_x,$start_y) = split /,/, $act_coord;

    # A mysterious bug affecting perls < 5.18.0 in a following
    # environment:
    # - Linux, e.g. Debian/wheezy (does not happen on FreeBSD)
    # - large dataset (i.e. osm derived data, does not happen
    #   for original bbbike data)
    # If this is given, then the "last if !keys %OPEN" line causes
    # a crash if %OPEN has some 2^16 keys (this number could be
    # coincidence, though):
    #
    # *** glibc detected *** perl5.16.3: munmap_chunk(): invalid pointer: 0x0000000005d4ca18 ***
    #
    # Workaround: explicitely reset the iterator earlier
    # for these perls.
    use constant PERL_HASHMEM_BUG => $] < 5.018;

    my %CLOSED;
    my %OPEN;

    $OPEN{$act_coord} = undef;

    while (1) {
	$CLOSED{$act_coord} = undef;
	delete $OPEN{$act_coord};

	while (my $neighbor = each %{ $net_net->{$act_coord} }) {
	    next if exists $CLOSED{$neighbor};
	    $OPEN{$neighbor} = undef;
	}

	last if !keys %OPEN; # side-effect: resets iterator
	$act_coord = each %OPEN;
	keys %OPEN if PERL_HASHMEM_BUG; # workaround for buggy perls
    }

    return \%CLOSED;
}

1;

__END__

=head1 AUTHOR

Slaven Rezic

=cut
