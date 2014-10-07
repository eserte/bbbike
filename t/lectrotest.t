#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

use FindBin;
use lib (
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/..",
        );
use Strassen::Core;
use Strassen::StrassenNetz;

my $tests = 5;
plan tests => $tests;

use Getopt::Long;
my $debug;
GetOptions("debug" => \$debug) or die "usage?";

my $s0 = Strassen->new("strassen");
my $inaccessible_strassen = Strassen->new('inaccessible_strassen');
my $s = $s0->new_with_removed_points($inaccessible_strassen);
my $net = StrassenNetz->new($s);
$net->make_net;

{
    my @points;
    sub gen {
	if (!@points) {
	    @points = map { Strassen::parse($_)->[1][0] } @{ $s->{Data} };
	}
	$points[rand(@points)];
    }
}

for (1..$tests) {
    my $start = gen();
    my $goal  = gen();
    is eval { ref search($start, $goal) }, 'ARRAY'
	or diag "Search between $start and $goal failed" . ($@ ? " ($@)" : '');
}

sub search {
    my($from,$to) = @_;
    my(@res) = $net->search($from, $to);
    print STDERR "$from -> $to...  \r"
	if $debug;
    $res[0];
}

__END__
