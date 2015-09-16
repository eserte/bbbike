#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use File::Temp ();
use Test::More;

BEGIN {
    if (!eval q{ use IPC::Run qw(run); 1 }) {
	plan skip_all => 'IPC::Run not available';
    }
}

plan 'no_plan';

my $any2bbd = "$FindBin::RealBin/../miscsrc/any2bbd";
my @basecmd = ($^X, $any2bbd);

{
ok !run [@basecmd], '2>', \my $err;
like $err , qr{^Missing option -o for output file, use -o - for stdout at };
}

{
my $tmp = File::Temp->new(SUFFIX => '_any2bbd.trk');
$tmp->print(<<'EOF');
% Written by /home/e/eserte/src/bbbike/miscsrc/gpx2gpsman [GPS::GpsmanData] 2015-08-02 22:16:45 +0200

!Format: DDD 2 WGS 84
!Creation: no

!T:	2015-08-01 09:43:12 Tag	srt:device=eTrex 30	colour=#000000
	01-Aug-2015 09:43:12	N52.5078067929	E13.4600815549	87.14
	01-Aug-2015 09:43:23	N52.5080102216	E13.4595810715	86.66
EOF
$tmp->close;

ok run [@basecmd, $tmp, '-o', '-'], '>', \my $out, '2>', \my $err;
is $out, <<'EOF';
2015-08-01 09:43:12 Tag	#000080 14219,11413 14185,11435
EOF
like $err, qr{.*_any2bbd\.trk\.\.\. OK \(Strassen::Gpsman\)};
}

__END__
