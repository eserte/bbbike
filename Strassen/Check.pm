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

use Strassen::Core;

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

=head3 get_islands

    my $islands_arrayref = Strassen::Check::get_islands($net, %opts);

For a given L<StrassenNetz> object, return an arrayref of "islands"
(for the data type see L</get_island>). The StrassenNetz object
requires to have a C<Strassen> field.

Options are provided as named parameters:

=over

=item C<< shortcut => I<$bool> >>

If set to a true value, then the functions is exited as soon as an
island has half of the unique points in the net. Use this if you're
interested only in getting the largest "island" (which would probably
be a "continent").

=item C<< debug => I<$bool> >>

If set to a true value, then debugging statements are emitted.
Defaults to false.

=item C<< number_of_unique_points => I<$int> >>

Number of unique numbers in the net. Only needed if any C<debug> or
C<shortcut> is set, and if missing, then an automatic call to
L</number_of_unique_points> is done.

=item C<< max_loops => I<$int> >>

Limit the number of loops to avoid endless iterations (may this ever
happen?). Defaults to 10.

=back

=cut

sub get_islands {
    my($net, %opts) = @_;

    my $debug                   = delete $opts{debug};
    my $number_of_unique_points = delete $opts{number_of_unique_points};
    my $max_loops               = delete $opts{max_loops} || 10;
    my $shortcut                = delete $opts{shortcut};
    die "Unhandled options: " . join(" ", %opts) if %opts;

    my $s = $net->{Strassen} || die "No Strassen object available in $net";

    if (!defined $number_of_unique_points) {
	if ($debug || $shortcut) {
	    $number_of_unique_points = Strassen::Check::number_of_unique_points($s);
	} # else not needed
    }

    $s->init_for_iterator('refpoint');
    my @islands;
    my %global_seen;
    my $flood_search_calls = 0;
 ITERATE_OVER_STREETS: while() {
	my $r = $s->next_for_iterator('refpoint');
	my @c = @{ $r->[Strassen::COORDS] };
	last if !@c;

	for my $c (@c) {
	    if (!exists $global_seen{$c}) {
		warn "flood search for refpoint=$c\n" if $debug;
		my $island = Strassen::Check::get_island($net, $c);
		push @islands, $island;
		while(my($k) = each %$island) {
		    $global_seen{$k} = 1;
		}
		if ($debug) {
		    warn "... found " . scalar(keys %$island) . " point(s) of total $number_of_unique_points in island\n";
		    warn "global_seen has now " . scalar(keys %global_seen) . " entries\n";
		}
		if ($shortcut) {
		    if (scalar(keys %$island) >= $number_of_unique_points/2) {
			warn "This is large enough, exiting loop.\n" if $debug;
			last ITERATE_OVER_STREETS;
		    }
		}
		$flood_search_calls++;
		if ($flood_search_calls > $max_loops) {
		    last ITERATE_OVER_STREETS;
		}
	    }
	}
    }

    \@islands;
}

=head3 number_of_unique_points

    my $number = Strassen::Check::number_of_unique_points($s)

For a given L<Strassen> object I<$s> return the count of "unique" points.

=cut

sub number_of_unique_points {
    my $s = shift;
    my %unique_points;
    $s->init_for_iterator('number_of_unique_points');
    while() {
	my $r = $s->next_for_iterator('number_of_unique_points');
	my @c = @{ $r->[Strassen::COORDS] };
	last if !@c;
	for my $c (@c) {
	    $unique_points{$c} = 1;
	}
    }
    scalar keys %unique_points;
}

1;

__END__

=head1 AUTHOR

Slaven Rezic

=cut
