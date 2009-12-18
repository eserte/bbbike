#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: lectrotest.t,v 1.2 2006/04/05 22:52:28 eserte Exp $
# Author: Slaven Rezic
#

use strict;

BEGIN {
    if (!eval q{
	use Test::LectroTest;
	1;
    }) {
	print "1..0 # skip no Test::LectroTest module\n";
	exit;
    }
}

use Test::LectroTest trials => 5;
use Test::LectroTest::Generator qw( :common Gen );
use FindBin;
use lib ("$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/..",
        );
use Strassen::Core;
use Strassen::StrassenNetz;

use Getopt::Long;
my $debug;
GetOptions("debug" => \$debug) or die "usage?";

my $s = Strassen->new("strassen");
my $net = StrassenNetz->new($s);
$net->make_net;

my $str_gen = Gen {
    Elements(map { Strassen::parse($_)->[1][0] } @{ $s->{Data} } )->generate(@_);
};

Property {
    ##[ x <- $str_gen, y <- $str_gen ]##
    ref search( $x, $y ) eq 'ARRAY'
}, name => "search does not fail" ;


sub search {
    my($from,$to) = @_;
    my(@res) = $net->search($from, $to);
    print STDERR "$from -> $to...  \r"
	if $debug;
    $res[0];
}

__END__
