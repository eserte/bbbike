#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassen-gpsman.t,v 1.3 2005/02/13 10:40:48 eserte Exp $
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
	warn $@;
    }
}

my $tests = 4;
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

__END__
