#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use autodie;
use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../lib", $FindBin::RealBin);

use File::Temp qw(tempdir);
use Test::More;

use BBBikeUtil qw(bbbike_root);
use BBBikeTest qw(eq_or_diff);

BEGIN {
    if (!eval q{ use IPC::Run qw(run binary); 1 }) {
	plan skip_all => 'IPC::Run needed for tests';
    }
}

plan 'no_plan';

my $script = bbbike_root . "/miscsrc/bbd_splitlines.pl";
my $tempdir = tempdir("bbd_spltlines_t_XXXXXXXX", TMPDIR => 1, CLEANUP => 1);

{
    my $source = <<'EOF';
#: test: global_directive
#:
single point	X 123,456
short line	X 0,0 1000,0
long line, unsplittable	X 0,0 2000,0
long line, splittable	X 0,0 1001,0 2000,0
EOF
    my $splitted = <<'EOF';
#: test: global_directive
#:
single point	X 123,456
short line	X 0,0 1000,0
long line, unsplittable	X 0,0 2000,0
long line, splittable	X 0,0 1001,0
long line, splittable	X 1001,0 2000,0
EOF

    {
	open my $ofh, ">", "$tempdir/test.bbd";
	binmode $ofh;
	print $ofh $source;
	close $ofh;

	ok run([$^X, $script, "$tempdir/test.bbd"], ">", binary, \my $out), "script runs ok with file argument";
	eq_or_diff $out, $splitted, "expected splitting";
    }

    {
	ok run([$^X, $script, "-"], "<", binary, \$source, ">", binary, \my $out), "script runs ok with stdin input";
	eq_or_diff $out, $splitted, "expected splitting";
    }
}

__END__
