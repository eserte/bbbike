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
use FindBin;
use lib "$FindBin::RealBin/..";

use Strassen::Core;

my $times_expr = qr{(\d+)\s*x\s*(\d+)};
my $plus_expr = qr{\d+\s*(?:\+\s*\d+)+};

my $file = shift || "$FindBin::RealBin/../data/gesperrt";

my @res;
my @steps_without_count;
Strassen->new_stream($file)->read_stream
    (sub {
	 my $r = shift;
	 return if $r->[Strassen::CAT] !~ m{^0};
	 if (my($steps) = $r->[Strassen::NAME] =~ m{(\d+|$times_expr|$plus_expr)\s+Stufe}) {
	     if ($steps =~ $times_expr) {
		 $steps = $1 * $2;
	     } elsif ($steps =~ $plus_expr) {
		 my($total_steps) = $steps =~ s{^(\d+)}{};
		 while($steps =~ m{\s*\+\s*(\d+)}g) {
		     $total_steps += $1;
		 }
		 $steps = $total_steps;
	     } # else $steps
	     if (my($time) = $r->[Strassen::CAT] =~ m{0:(\d+)}) {
		 push @res, [$time/$steps, $steps, $time, $r];
	     }
	 } elsif ($r->[Strassen::NAME] =~ m{treppe}i) {
	     push @steps_without_count, $r;
	 }
     });

print "Steps without count:\n" . join("\n", map { $_->[Strassen::NAME] } @steps_without_count), "\n";
print "-"x70,"\n";

@res = sort { $b->[0] <=> $a->[0] } @res;
print join("\n", map { join("\t", @{$_}[0,1,2], $_->[3]->[Strassen::NAME]) } @res), "\n";

__END__
