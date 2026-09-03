#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2026 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# WWW:  https://github.com/eserte/bbbike
#

use strict;
use warnings;
use FindBin;
use lib "$FindBin::RealBin/..", "$FindBin::RealBin/../lib";

use File::Temp qw(tempfile);
use Test::More tests => 15;

my ($tfh, $testfile) = tempfile(UNLINK => 1);
print $tfh <<'EOF';
Street A	NN 1000,2000 1100,2100 1200,2200
Street B	NN 13.405,52.520 13.406,52.521 13.407,52.522
Street C	NN -10.5,+20.5 -11.5,+21.5
Street D	NN 500,600
EOF
close $tfh;

my $bbbike_grep_cmd = "$^X -I$FindBin::RealBin/.. -I$FindBin::RealBin/../lib $FindBin::RealBin/../miscsrc/bbbike-grep";

{
    my $cmd = "$bbbike_grep_cmd -h --add-file $testfile -- \"Street A\"";
    my $output = `$cmd`;
    is($? >> 8, 0, "Exit status 0 for standard text search");
    like($output, qr/Street A/, "Found Street A via text search");
}

{
    my $cmd = "$bbbike_grep_cmd -h --add-file $testfile -- \"1000,2000 1100,2100\"";
    my $output = `$cmd`;
    is($? >> 8, 0, "Exit status 0 for forward coordinate search");
    like($output, qr/Street A/, "Found Street A via forward coordinate search");
}

{
    my $cmd = "$bbbike_grep_cmd -h --add-file $testfile -- \"1100,2100 1000,2000\"";
    my $output = `$cmd`;
    is($? >> 8, 0, "Exit status 0 for reversed coordinate search (default)");
    like($output, qr/Street A/, "Found Street A via reversed coordinate search");
}

{
    my $cmd = "$bbbike_grep_cmd -h --no-also-reverse-coords --add-file $testfile -- \"1100,2100 1000,2000\"";
    my $output = `$cmd`;
    isnt($? >> 8, 0, "Exit status non-zero with --no-also-reverse-coords for reversed coordinates");
    unlike($output, qr/Street A/, "Street A not found when --no-also-reverse-coords is active");
}

{
    my $cmd = "$bbbike_grep_cmd -h --no-also-reverse-coordinates --add-file $testfile -- \"1100,2100 1000,2000\"";
    my $output = `$cmd`;
    isnt($? >> 8, 0, "Exit status non-zero with --no-also-reverse-coordinates alias");
}

{
    my $cmd = "$bbbike_grep_cmd -h --add-file $testfile -- \"13.406,52.521 13.405,52.520\"";
    my $output = `$cmd`;
    is($? >> 8, 0, "Exit status 0 for reversed float coordinates");
    like($output, qr/Street B/, "Found Street B via reversed float coordinates");
}

{
    my $cmd = "$bbbike_grep_cmd -h --add-file $testfile -- \"-11.5,+21.5 -10.5,+20.5\"";
    my $output = `$cmd`;
    is($? >> 8, 0, "Exit status 0 for reversed signed coordinates");
    like($output, qr/Street C/, "Found Street C via reversed signed coordinates");
}

{
    my $cmd = "$bbbike_grep_cmd -h --rx --add-file $testfile -- \"1100,2100 1000,2000\"";
    my $output = `$cmd`;
    is($? >> 8, 0, "Exit status 0 for reversed coordinate search in rx mode");
    like($output, qr/Street A/, "Found Street A in rx mode");
}
