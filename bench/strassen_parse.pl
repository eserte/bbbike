#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2009 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use Benchmark qw(cmpthese);
use Test::More qw(no_plan);

my $line = "Möckernstr.	N 8769,9290 8773,9524 8777,9601 8779,9812 8779,9851 8780,9968 8783,10166 8804,10303 8824,10366 8878,10514 8922,10618 8939,10657 9022,10857";

is_deeply(parse($line), parse_rx($line));

cmpthese(-1, {parse => sub { parse($line) },
	      parse_rx => sub {parse_rx($line) },
	     }
	);
	 
sub parse {
    # $_[0] is $line
    # my $_[0] = shift;
    return [undef, [], undef] if !$_[0];
    my $tab_inx = index($_[0], "\t");
    if ($tab_inx < 0) {
	warn "Probably tab character is missing (line <$_[0]>)\n";
	[$_[0]];
    } else {
	my @s = split /\s+/, substr($_[0], $tab_inx+1);
	my $category = shift @s;
	[substr($_[0], 0, $tab_inx), \@s, $category];
    }
}

sub parse_rx {
    return [undef, [], undef] if !$_[0];
    my($name, $cat, $coords) = $_[0] =~ m{^([^\t]+)\t(\S+)\s+(.*)};
    if (!defined $name) {
	warn "Probably tab character is missing (line <$_[0]>)\n";
	[$_[0]];
    } else {
	[$name, [split /\s+/, $coords], $cat];
    }
}

__END__

=pod

Results:

FreeBSD 7, perl 5.8.8:

            Rate parse_rx    parse
parse_rx 90863/s       --      -1%
parse    92140/s       1%       --

FreeBSD 7, perl 5.10.1

             Rate    parse parse_rx
parse     96328/s       --      -6%
parse_rx 102867/s       7%       --

Linux (Debian etch), perl 5.10.1

             Rate    parse parse_rx
parse     73454/s       --     -51%
parse_rx 150377/s     105%       --

=cut
