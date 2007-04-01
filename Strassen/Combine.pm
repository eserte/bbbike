# -*- perl -*-

#
# $Id: Combine.pm,v 1.5 2007/03/31 16:36:30 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999,2001,2006,2007 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

=head1 NAME

Strassen::Combine - combine streets

=head1 DESCRIPTION

 Zusammenfassen von Straßen

 Zusammengefasst werden kann, wenn:
 - Die Straßen den gleichen Namen haben (Voraussetzung: Straßen müssen
   evtl. durch den Bezirksnamen näher klassifiziert werden, ist aber
   wegen der weiteren Bedingungen unproblematisch).
 - Start- oder Endpunkt von zwei Straßen zusammenfallen
 - Die Kategorie bei beiden Straßen die gleiche ist.

=head2 METHODS

Die beiden Methoden werden in die Klasse L<Strassen> geladen. Als
Ausgabe wird ein neues B<Strassen>-Objekt erzeugt.

=head3 make_long_streets(%args)

Arguments: -closedpolygon, -v, -ignorecat

=head3 combine_same_streets

=head1 TODO

 * Wünschenswert wäre wenigstens eine Umordnung der Straßen bei einer
   streckenweise Teilung (z.B. Einbahnstraßen)

   Also beispielsweise:

   Straße	Kat 0,0 1,1 2,2
   Straße	Kat; 2,2 3,3 4,4
   Straße	Kat; 4,4 3,4 2,2
   Straße	Kat 4,4 5,5

 * Lokale Direktiven sollten möglichst beibehalten werden. Eventuell
   muss es ein Regelwerk geben, ob Straßen zusammengefasst werden
   dürfen, wenn lokale Direktiven unterschiedlich sind, und ob die
   lokalen Direktiven bei der neuen Datei verworfen werden oder
   zusammengefasst

=head1 HISTORY

Dieses Modul war früher das Skript F<miscsrc/combine_streets.pl>. Das
Skript existiert immer noch, aber der komplette Code ist in dieses
Modul gewandert.

=head1 AUTHOR

Slaven Rezic <eserte@users.sourceforge.net>

=head1 COPYRIGHT

Copyright (c) 1999,2001,2006,2007 Slaven Rezic. All rights reserved.
This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

F<miscsrc/combine_streets.pl>

=cut

package Strassen::Combine;
use Strassen::Core;

package Strassen;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

sub make_long_streets {
    my($self, %args) = @_;

    my $make_closed_polygon = delete $args{'-closedpolygon'} || 0;
    my $v = delete $args{'-v'} || 0;
    my $ignorecat = delete $args{'-ignorecat'} || [];

    die "Unhandled arguments: " . join(" ", %args) if %args;

    my %ignorecat = map { ($_,1) } @$ignorecat;

    my @strdata;
    # $strdata: 0: first, 1: last
    #           => zeigen auf Hashes
    #           KEY: X,Y-Koordinaten
    #           VAL: Index auf @strdata
    my $strdata;
    #XXXX
    # reversed index: 0: first, 1: last
    #           => zeigen auf Arrays
    #           KEY: Index auf @strdata
    #           VAL: X,Y-Koordinaten
    #XXXXmy $rev_strdata;

    # ugly hack...
    my $del_all_same_key = sub {
	my($inx) = @_;
	for my $first_last (0 .. 1) {
	    my(@mark);
	    while(my($k,$v) = each %{ $strdata->[$first_last] }) {
		if ($v == $inx) {
		    CORE::push(@mark, $k);
		}
	    }
	    foreach (@mark) { delete $strdata->[$first_last]{$_} }
	}
    };

    my $keyname = sub {
	my($r, $inx) = @_;
	#use Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->Dumpxs([\@strdata, $r, caller],[]); # XXX
	"$r->[Strassen::NAME]\t$r->[Strassen::CAT]\t" . $r->[Strassen::COORDS][$inx];
    };

    $self->init;
    my $count = 0;
    while (1) {
	my $r = $self->next;
	last if !@{ $r->[Strassen::COORDS] };
	if ($ignorecat{$r->[Strassen::CAT]}) {
	    CORE::push(@strdata, $r);
	    next;
	}
	if ($v && ++$count%100 == 0) {
	    print STDERR "$count\r";
	}

	# Calculate keys for beginning and end of current street data record.
	# In the following, index=0 is always the beginning and index=1 is
	# always the end, both in @keys and in $strdata.
	my(@keys)  = ($keyname->($r, 0), $keyname->($r, -1));

	my $append = 0;	# 1, if we should push, -1, if we should unshift
	my $old_firstlast; # beginning/end index for already recorded data
	my $new_firstlast;	# beginning/end index for current data

	# The current data has to be reversed if the match is begin/begin or
	# end/end. The matching tail is common to the old and new street data
	# record, so one of both (the new one) should be removed (with shift
	# or pop).

	if (exists $strdata->[0]{$keys[0]}) {
	    # CASE 1: beginning matches with another already recorded beginning
	    shift @{ $r->[1] };
	    @{ $r->[1] } = reverse @{ $r->[1] };
	    $append = -1;
	    $old_firstlast = 0;
	    $new_firstlast = 0;
	} elsif (exists $strdata->[1]{$keys[0]}) {
	    # CASE 2: beginning matches with another already recorded end
	    shift @{ $r->[1] };
	    $append = 1;
	    $old_firstlast = 1;
	    $new_firstlast = 0;
	} elsif (exists $strdata->[0]{$keys[1]}) {
	    # CASE 3: end matches with another already recorded beginning
	    pop @{ $r->[1] };
	    $append = -1;
	    $old_firstlast = 0;
	    $new_firstlast = 1;
	} elsif (exists $strdata->[1]{$keys[1]}) {
	    # CASE 4: end matches with another already recorded end
	    pop @{ $r->[1] };
	    @{ $r->[1] } = reverse @{ $r->[1] };
	    $append = 1;
	    $old_firstlast = 1;
	    $new_firstlast = 1;
	}

	my $other_firstlast;
	if ($append) {
	    $other_firstlast = 1 - $new_firstlast;
	}

	my $inx; # Index of already recorded street data which matched (or 0).
	if ($append == -1) {
	    $inx = $strdata->[$old_firstlast]{$keys[$new_firstlast]};
	    unshift @{ $strdata[$inx]->[1] },
                @{ $r->[1] };
	    #warn "del $keys[$new_firstlast]";
	    delete $strdata->[$old_firstlast]{$keys[$new_firstlast]};
	    #	my $newkey = $keyname->($strdata[$inx]->[1], 0);
	    #	$strdata->[$old_firstlast]{$newkey} = $inx;

	    if (exists $strdata->[0]{$keys[$other_firstlast]}) {

		shift @{ $strdata[$inx]->[1] };
		my $inx2 = $strdata->[0]{$keys[$other_firstlast]};
		if ($inx != $inx2) {
		    unshift @{ $strdata[$inx]->[1] },
			reverse @{ $strdata[$inx2]->[1] };
		    delete $strdata->[0]{$keys[$other_firstlast]};
		    $del_all_same_key->($inx2);
		    undef $strdata[$inx2];
		}

	    } elsif (exists $strdata->[1]{$keys[$other_firstlast]}) {

		shift @{ $strdata[$inx]->[1] };
		my $inx2 = $strdata->[1]{$keys[$other_firstlast]};
		if ($inx != $inx2) {
		    unshift @{ $strdata[$inx]->[1] },
			@{ $strdata[$inx2]->[1] };
		    delete $strdata->[1]{$keys[$other_firstlast]};
		    $del_all_same_key->($inx2);
		    undef $strdata[$inx2];
		}

	    }

	} elsif ($append == 1) {
	    $inx = $strdata->[$old_firstlast]{$keys[$new_firstlast]};
	    CORE::push(@{ $strdata[$inx]->[1] },
		       @{ $r->[1] });
	    #warn "del $keys[$new_firstlast]";
	    delete $strdata->[$old_firstlast]{$keys[$new_firstlast]};
	    #	my $newkey = $keyname->($strdata[$inx]->[1], -1);
	    #	$strdata->[$old_firstlast]{$newkey} = $inx;

	    if (exists $strdata->[0]{$keys[$other_firstlast]}) {

		pop @{ $strdata[$inx]->[1] };
		my $inx2 = $strdata->[0]{$keys[$other_firstlast]};
		if ($inx != $inx2) {
		    CORE::push(@{ $strdata[$inx]->[1] },
			       @{ $strdata[$inx2]->[1] });
		    delete $strdata->[0]{$keys[$other_firstlast]};
		    $del_all_same_key->($inx2);
		    undef $strdata[$inx2];
		}

	    } elsif (exists $strdata->[1]{$keys[$other_firstlast]}) {

		pop @{ $strdata[$inx]->[1] };
		my $inx2 = $strdata->[1]{$keys[$other_firstlast]};
		if ($inx != $inx2) {
		    CORE::push(@{ $strdata[$inx]->[1] },
			       reverse @{ $strdata[$inx2]->[1] });
		    delete $strdata->[1]{$keys[$other_firstlast]};
		    $del_all_same_key->($inx2);
		    undef $strdata[$inx2];
		}

	    }

	} else {
	    CORE::push(@strdata, $r);
	    $inx = $#strdata;
	}

	# Recalculate keys for the processed data record.
	my($firstkey, $lastkey) = ($keyname->($strdata[$inx], 0),
				   $keyname->($strdata[$inx], -1),
				  );
	$strdata->[0]{$firstkey} = $inx;
	$strdata->[1]{$lastkey}  = $inx;
    }

    my $out_str = Strassen->new();

    foreach my $r (@strdata) {
	if (defined $r) {
	    my @coords = @{ $r->[Strassen::COORDS] };
	    if ($make_closed_polygon && @coords > 0 &&
		$coords[0] ne $coords[-1]) {
		CORE::push(@coords, $coords[0]);
	    }
	    $out_str->push([$r->[Strassen::NAME], \@coords, $r->[Strassen::CAT]]);
	}
    }

    $out_str;

}

sub combine_same_streets {
    my($self) = @_;

    my $out_str = Strassen->new();

    require Strassen::StrassenNetz;
    my $net = StrassenNetz->new($self);
    $net->make_net_cat(-multiple => 1,
		       -net2name => 1,
		      );
    while(my($p1,$v) = each %{ $net->{Net2Name} }) {
	while(my($p2, $v2) = each %$v) {
	    my @rec = map { $self->get($_) } @$v2;
	    my $rec = [join(", ", map { $_->[Strassen::NAME] } @rec),
		       [$p1, $p2],
		       $rec[0]->[Strassen::CAT]
		      ];
	    $out_str->push($rec);
	}
    }

    $out_str;
}

1;

__END__
