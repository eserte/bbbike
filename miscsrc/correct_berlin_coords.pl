#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2012 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use List::Util qw(min);

use PLZ;
use Strassen::Core;
use Strassen::MultiStrassen;
use VectorUtil qw(distance_point_line);

my $fz_s = Strassen->new_stream("$FindBin::RealBin/../data/fragezeichen-orig"); # -orig, because we want also "ignored" streets
my $new_fz_s = Strassen->new;
$fz_s->read_stream
    (sub {
	 my($rec) = @_;
	 $rec->[Strassen::NAME] =~ s{:.*}{}; # strip fragezeichen strings
	 $new_fz_s->push($rec);
     });
my $str_s = Strassen->new("$FindBin::RealBin/../data/strassen");
my $s = MultiStrassen->new($str_s, $new_fz_s);
my $sh = $s->get_hashref_name_to_pos
    (sub {
	 my $name = shift;
	 $name =~ s{\s\(.*\)$}{}; # strip citypart
	 $name;
     });
my $plz = PLZ->new;
$plz->load;
for my $rec (@{ $plz->{Data} }) {
    my $streettype = $plz->get_street_type($rec); # XXX hmmm, it's documented to work on the LOOK record
    my($street,$citypart) = @{$rec}[PLZ::FILE_NAME, PLZ::FILE_CITYPART];
    if ($streettype ne 'street') {
	warn "INFO: Skip $street ($citypart), it's a $streettype...\n";
	next;
    }
    my @nearest_recs;
    {
	my @filter_pos = @{ $sh->{$street} || [] };
	if (@filter_pos) {
	    my $filter_s = Strassen->new;
	    for my $pos (@filter_pos) {
		$filter_s->push($s->get($pos));
	    }
	    my @pos = $filter_s->choose_street($street, $citypart);
	    for my $pos (@pos) {
		push @nearest_recs, $filter_s->get($pos);
	    }
	}
    }
    if (!@nearest_recs) {
	warn "WARN: Cannot find $street ($citypart), skipping...\n";
	next;
    }

    my $coord = $rec->[PLZ::FILE_COORD];
    if (!$coord) {
	warn "WARN: No coord for $street ($citypart), skipping...\n";
	next;
    }

    my($px,$py) = split /,/, $coord;
    my @dists;
    my @c = map { [split /,/, $_] } map { @{ $_->[Strassen::COORDS] } } @nearest_recs;
    for my $i (1 .. $#c) {
	push @dists, distance_point_line($px,$py, @{$c[$i-1]}, @{$c[$i]});
    }
    my $min_dist = min @dists;
    printf "%4dm %s (%s)\tX %s\n", $min_dist, $street, $citypart, $coord;
}

__END__

=head1 DESCRIPTION

A helper script to find mismatched coordinates in Berlin.coords.data.
Best to pipe output of this script to sort to get a list of the worst
records:

    ./miscsrc/correct_berlin_coords.pl | sort -nr

The script also spits out INFO warnings for non-street records, and
WARN warnings for streets not in strassen (but probably should be in
fragezeichen).

Another use case: check completeness of strassen+fragezeichen vs.
Berlin.coords.data:

    ./miscsrc/correct_berlin_coords.pl |&grep '^WARN'

But this is duplicating misc/check-berlin-coords-data.pl in
bbbike-aux.

=head1 TODO

* Maybe U/S-Bhf should also be checked

* I could fix things manually (worst first) or maybe automatically
  e.g. if some threshold is exceeded.

=cut
