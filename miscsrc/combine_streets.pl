#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: combine_streets.pl,v 1.11 2005/02/25 01:46:11 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999,2001,2002,2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net/
#

# XXX  maybe the
# implementation should be better...

=head1 NAME

combine_streets.pl - combine streets

=head1 DESCRIPTION

Zusammenfassen von Straﬂen
Zusammengefasst werden kann, wenn:
 - Die Straﬂen den gleichen Namen haben (Voraussetzung: Straﬂen m¸ssen
   evtl. durch den Bezirksnamen n‰her klassifiziert werden, ist aber
   wegen der weiteren Bedingungen unproblematisch).
 - Start- oder Endpunkt von zwei Straﬂen zusammenfallen
 - Die Kategorie bei beiden Straﬂen die gleiche ist.

=head1 AUTHOR

Slaven Rezic <slaven.rezic@berlin.de>

=head1 COPYRIGHT

Copyright (c) 1999,2001 Slaven Rezic. All rights reserved.
This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data",
	 );
use Strassen;
use strict;
use Getopt::Long;

my $make_closed_polygon;
if (!GetOptions("closedpolygon!" => \$make_closed_polygon)) {
    die "usage";
}

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

my $strfile = shift || die "Name der Straﬂen-Datei?";
my $tmpfile;
if ($strfile eq '-') {
    require POSIX;
    $tmpfile = POSIX::tmpnam();
    open(TMP, ">$tmpfile") or die "Can't write to $tmpfile: $!";
    while(<STDIN>) {
	print TMP $_;
    }
    close TMP;
    $strfile = $tmpfile;
}

my $s = new Strassen $strfile;
$s->init;
my $count = 0;
while(1) {
    my $r = $s->next;
    last if !@{ $r->[Strassen::COORDS] };
    if (++$count%100 == 0) {
	print STDERR "$count\r";
    }

    # Calculate keys for beginning and end of current street data record.
    # In the following, index=0 is always the beginning and index=1 is
    # always the end, both in @keys and in $strdata.
    my(@keys)  = (keyname($r, 0), keyname($r, -1));

    my $append = 0;    # 1, if we should push, -1, if we should unshift
    my $old_firstlast; # beginning/end index for already recorded data
    my $new_firstlast; # beginning/end index for current data

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
#	my $newkey = keyname($strdata[$inx]->[1], 0);
#	$strdata->[$old_firstlast]{$newkey} = $inx;

	if (exists $strdata->[0]{$keys[$other_firstlast]}) {

	    shift @{ $strdata[$inx]->[1] };
	    my $inx2 = $strdata->[0]{$keys[$other_firstlast]};
	    if ($inx != $inx2) {
		unshift @{ $strdata[$inx]->[1] },
   		    reverse @{ $strdata[$inx2]->[1] };
		delete $strdata->[0]{$keys[$other_firstlast]};
		del_all_same_key($inx2);
		undef $strdata[$inx2];
	    }

	} elsif (exists $strdata->[1]{$keys[$other_firstlast]}) {

	    shift @{ $strdata[$inx]->[1] };
	    my $inx2 = $strdata->[1]{$keys[$other_firstlast]};
	    if ($inx != $inx2) {
		unshift @{ $strdata[$inx]->[1] },
		    @{ $strdata[$inx2]->[1] };
		delete $strdata->[1]{$keys[$other_firstlast]};
		del_all_same_key($inx2);
		undef $strdata[$inx2];
	    }

	}

    } elsif ($append == 1) {
	$inx = $strdata->[$old_firstlast]{$keys[$new_firstlast]};
	push @{ $strdata[$inx]->[1] },
             @{ $r->[1] };
#warn "del $keys[$new_firstlast]";
	delete $strdata->[$old_firstlast]{$keys[$new_firstlast]};
#	my $newkey = keyname($strdata[$inx]->[1], -1);
#	$strdata->[$old_firstlast]{$newkey} = $inx;

	if (exists $strdata->[0]{$keys[$other_firstlast]}) {

	    pop @{ $strdata[$inx]->[1] };
	    my $inx2 = $strdata->[0]{$keys[$other_firstlast]};
	    if ($inx != $inx2) {
		push @{ $strdata[$inx]->[1] },
   		    @{ $strdata[$inx2]->[1] };
		delete $strdata->[0]{$keys[$other_firstlast]};
		del_all_same_key($inx2);
		undef $strdata[$inx2];
	    }

	} elsif (exists $strdata->[1]{$keys[$other_firstlast]}) {

	    pop @{ $strdata[$inx]->[1] };
	    my $inx2 = $strdata->[1]{$keys[$other_firstlast]};
	    if ($inx != $inx2) {
		push @{ $strdata[$inx]->[1] },
   		    reverse @{ $strdata[$inx2]->[1] };
		delete $strdata->[1]{$keys[$other_firstlast]};
		del_all_same_key($inx2);
		undef $strdata[$inx2];
	    }

	}

    } else {
	push @strdata, $r;
	$inx = $#strdata;
    }

    # Recalculate keys for the processed data record.
    my($firstkey, $lastkey) = (keyname($strdata[$inx], 0),
			       keyname($strdata[$inx], -1),
			      );
    $strdata->[0]{$firstkey} = $inx;
    $strdata->[1]{$lastkey}  = $inx;
}

foreach my $r (@strdata) {
    if (defined $r) {
	my @coords = @{ $r->[Strassen::COORDS] };
	if ($make_closed_polygon && @coords > 0 &&
	    $coords[0] ne $coords[-1]) {
	    push @coords, $coords[0];
	}
	print "$r->[Strassen::NAME]\t$r->[Strassen::CAT] " . join(" ", @coords) . "\n";
    }
}

if (defined $tmpfile) {
    unlink $tmpfile;
}

# ugly hack...
sub del_all_same_key {
    my($inx) = @_;
    for my $first_last (0 .. 1) {
	my(@mark);
	while(my($k,$v) = each %{ $strdata->[$first_last] }) {
	    if ($v == $inx) {
		push @mark, $k;
	    }
	}
	foreach (@mark) { delete $strdata->[$first_last]{$_} }
    }
}

sub keyname {
    my($r, $inx) = @_;
#use Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->Dumpxs([\@strdata, $r, caller],[]); # XXX
    "$r->[Strassen::NAME]\t$r->[Strassen::CAT]\t" . $r->[Strassen::COORDS][$inx];
}

__END__
