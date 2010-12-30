#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2010 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../lib");

use JSON::XS;

use Strassen::Core;

my $file = shift or die "Specify file";
my $s = Strassen->new($file);

my %strnames;

$s->init;
while() {
    my $r = $s->next;
    my @c = @{ $r->[Strassen::COORDS] };
    last if !@c;
    $strnames{$r->[Strassen::NAME]} = 1;
}

print encode_json [ sort keys %strnames ];


__END__
