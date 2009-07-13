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

# XXX Temporary --- will be moved somewhere some day!

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);
use VectorUtil;
use Strassen::Core;

my $ignore_rx; # XXX some day

die "usage: $0 from to" if @ARGV != 2;
my($p1,$p2) = @ARGV;
my $trks = Strassen->new("$FindBin::RealBin/../tmp/streets-accurate-categorized-split.bbd");
$trks->make_grid(#Exact => 1, # XXX too slow?!
		 UseCache => 1);

my @included;
my %seen;

my(@grids) = keys %{{ map { ($_=>1) }
			  (join(",", $trks->grid(split /,/, $p1)),
			   join(",", $trks->grid(split /,/, $p2))) # XXX alle Gitter dazwischen auch!
		      }};
for my $grid (@grids) {
    next if !exists $trks->{Grid}{$grid};
    for my $n (@{ $trks->{Grid}{$grid} }) {
	my $r = $trks->get($n);
	next if $ignore_rx && $r->[Strassen::NAME] =~ $ignore_rx;
	next if $seen{$r->[Strassen::NAME]};
    TRY_RECORD: {
	    for my $r_i (1 .. $#{ $r->[Strassen::COORDS] }) {
		my($r1,$r2) = @{$r->[Strassen::COORDS]}[$r_i-1,$r_i];
		for my $checks ([$r1, $p1],
				[$r1, $p2],
				[$r2, $p1],
				[$r2, $p2],
			       ) {
		    if ($checks->[0] eq $checks->[1]) {
			push @included, [$r, [$checks->[0]], [$checks->[1]]];
			$seen{$r->[Strassen::NAME]} = 1;
			next TRY_RECORD;
		    }
		}
		if (VectorUtil::intersect_lines(split(/,/, $p1),
						split(/,/, $p2),
						split(/,/, $r1),
						split(/,/, $r2),
					       )) {
		    $seen{$r->[Strassen::NAME]} = 1;
		    push @included, [$r, [$r1,$r2], [$p1,$p2]];
		}
	    }
	}
    }
}

require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([\@included],[qw()])->Indent(1)->Useqq(1)->Dump; # XXX


__END__
