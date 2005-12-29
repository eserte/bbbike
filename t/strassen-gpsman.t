#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassen-gpsman.t,v 1.5 2005/12/28 19:04:49 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);
use Getopt::Long;
use Strassen::Core;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip: no Test::More module\n";
	exit;
    }
}

my $have_nowarnings;
BEGIN {
    $have_nowarnings = 1;
    eval 'use Test::NoWarnings';
    if ($@) {
	$have_nowarnings = 0;
	#warn $@;
    }
}

my $tests = 4 + 3;
plan tests => $tests + $have_nowarnings;

my $gpsman_dir = "$FindBin::RealBin/../misc/gps_data";
if (!GetOptions("gpsmandir=s" => \$gpsman_dir)) {
    die <<EOF;
usage: $0 [-gpsmandir directory]
EOF
}

SKIP: {
    skip("No gpsman data directory found", $tests) if !-d $gpsman_dir;

    my @trk = glob("$gpsman_dir/*.trk");
    skip("No tracks in $gpsman_dir found", $tests) if !@trk;
    my @wpt = glob("$gpsman_dir/*.wpt");
    skip("No waypoint files in $gpsman_dir found", $tests) if !@wpt;
    
    my $trk = $trk[rand @trk];
    my $wpt = $wpt[rand @wpt];

    my $s1 = Strassen->new($trk);
    isa_ok($s1, "Strassen");
    isa_ok($s1, "Strassen::Gpsman");
    my $s2 = Strassen->new($wpt);
    isa_ok($s2, "Strassen");
    isa_ok($s2, "Strassen::Gpsman");

    #require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([$s1, $s2],[qw()])->Indent(1)->Useqq(1)->Dump; # XXX

}

{
    my $trk_sample = <<'EOF';
% Written by /home/e/eserte/src/bbbike/bbbike Wed Dec 28 19:10:26 2005
% Edit at your own risk!

!Format: DDD 1 WGS 84
!Creation: yes

!T:	TRACK
	31-Dec-1989 01:00:00	N53.0945536138593	E12.8748931621168	0
	31-Dec-1989 01:00:00	N53.0943054383567	E12.8761002946735	0
!T:	TRACK
	31-Dec-1989 01:00:00	N53.0940612438672	E12.877531259314	0
	31-Dec-1989 01:00:00	N53.0933655007711	E12.8813741665033	0
	31-Dec-1989 01:00:00	N53.0931727960854	E12.8831759358179	0
	31-Dec-1989 01:00:00	N53.0930156939216	E12.8844531899105	0
	31-Dec-1989 01:00:00	N53.0929946513017	E12.8857984410851	0
	31-Dec-1989 01:00:00	N53.0929775683148	E12.8873675328466	0
	31-Dec-1989 01:00:00	N53.0931440997843	E12.8891516695014	0
	31-Dec-1989 01:00:00	N53.0933489067498	E12.8905605502346	0
	31-Dec-1989 01:00:00	N53.0933013449282	E12.8904135187235	0

EOF
    my $s = Strassen::Gpsman->new_from_string($trk_sample);
    isa_ok($s, "Strassen");
    isa_ok($s, "Strassen::Gpsman");
    cmp_ok(scalar(@{$s->data}), "==", 2, "Track sample has two lines");
}

__END__
