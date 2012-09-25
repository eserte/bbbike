#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

BEGIN {
    if (!eval q{
	use IPC::Run qw(run);
	use Test::More;
	1;
    }) {
	print "1..0 # skip no IPC::Run and/or Test::More modules\n";
	exit;
    }
}

plan 'no_plan';

use File::Temp qw(tempdir);
use Strassen::Core;

my $search_inaccessible_points = "$FindBin::RealBin/../miscsrc/search_inaccessible_points";

ok -x $search_inaccessible_points, "$search_inaccessible_points is executable";

{
    my $test_datadir = "$FindBin::RealBin/data-test";
    my $inaccessible;
    ok run([$search_inaccessible_points, '-street', "$test_datadir/strassen", '-blocked', "$test_datadir/gesperrt"], ">", \$inaccessible), 'Run search_inaccessible_points with test data';
    my $s = Strassen->new_from_data_string($inaccessible);
    isa_ok $s, 'Strassen';
}

{
    my($tempdir) = tempdir("data-test2-XXXXXXXX", CLEANUP => 1)
	or die "Can't create temporary directory: $!";
    my $strassen_file = "$tempdir/strassen";
    my $gesperrt_file = "$tempdir/gesperrt";

    {
	open my $fh, ">", $strassen_file or die $!;
	print $fh <<'EOF';
#: map: polar
#: encoding: utf-8
#:
Teststreet A	X 0,0 1,1 2,2
Teststreet B	X 0,0 1,0 2,0
Teststreet C	X 0,0 -1,0 -2,0
EOF
	close $fh or die $!;
    }

    {
	open my $fh, ">", $gesperrt_file or die $!;
	print $fh <<'EOF';
#: map: polar
#: encoding: utf-8
#:
Gesperrt	2 1,1 2,2
Einbahn1	1 1,0 2,0
Einbahn2	1 -2,0 -1,0
EOF
	close $fh or die $!;
    }

    my $inaccessible;
    ok run([$search_inaccessible_points, '-refpoint', '0,0', '-street', $strassen_file, '-blocked', $gesperrt_file], ">", \$inaccessible), 'Run search_inaccessible_points with controlled test data';
    my $s = Strassen->new_from_data_string($inaccessible);
    isa_ok $s, 'Strassen';
    is $s->get_global_directive('encoding'), 'utf-8', 'preserved encoding';
    is $s->get_global_directive('map'), 'polar', 'preserved map';
    is $s->count, 2, 'just two points expected'
	or diag $s->as_string;
    is $s->get(0)->[Strassen::COORDS]->[0], '2,2', 'expected coordinate from gesperrt';
    is $s->get(1)->[Strassen::COORDS]->[0], '2,0', 'expected coordinate from einbahn1';
}

__END__
