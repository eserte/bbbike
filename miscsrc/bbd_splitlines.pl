#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbd_splitlines.pl,v 1.2 2009/01/14 22:27:46 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2008 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../lib");

use Strassen::Core;
use Strassen::Util;

use constant MIN_TOTAL_LENGTH => 1500;
use constant SPLIT_LENGTH => 1000;

my $file = shift or die "Please specify bbd file";

my $s = Strassen->new($file);

print $s->global_directives_as_string;

my $take_it = sub {
    my $r = shift;
    print $r->[Strassen::NAME], "\t", $r->[Strassen::CAT], " ", join(" ", @{$r->[Strassen::COORDS]}), "\n"; # XXX use function
    no warnings 'exiting';
    next;
};

$s->init;
while(1) {
    my $r = $s->next;
    my $c = $r->[Strassen::COORDS];
    last if (@$c == 0);
    $take_it->($r) if @$c < 2;
    my $total_len = Strassen::Util::strecke_s($c->[0], $c->[-1]);
    $take_it->($r) if $total_len < MIN_TOTAL_LENGTH;
    my $sofar = 0;
    my $first_index = 0;
    for my $i (1 .. $#$c) {
	$sofar += Strassen::Util::strecke_s($c->[$i-1], $c->[$i]);
	if ($i < $#$c && $sofar > SPLIT_LENGTH) {
	    print $r->[Strassen::NAME], "\t", $r->[Strassen::CAT], " ", join(" ", @{$c}[$first_index .. $i]), "\n"; #XXX use function
	    $first_index = $i;
	    $sofar = 0;
	}
    }
    print $r->[Strassen::NAME], "\t", $r->[Strassen::CAT], " ", join(" ", @{$c}[$first_index .. $#$c]), "\n"; #XXX use function
}

__END__
