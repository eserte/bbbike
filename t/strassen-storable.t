#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassen-storable.t,v 1.3 2005/04/05 22:54:52 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data");
use Strassen;
use Benchmark;
use Getopt::Long;

BEGIN {
    if (!eval q{
	use Test;
	die "No data/Makefile" if !-e "$FindBin::RealBin/../data/Makefile";
	1;
    }) {
	print "# tests only work with installed Test mode and a Makefile in the data directory\n";
	print "1..1\n";
	print "ok 1\n";
	exit;
    }
}

## results with 5.8.0:
# normal: 0.078125
# Storable: 0.4375

BEGIN { plan tests => 8 }

use vars qw($fast $bench $v);

if (!GetOptions("fast" => \$fast,
		"bench" => \$bench,
		"v" => \$v)) {
    die "usage!";
}

use vars qw($token %times $ext);

my $make = $^O =~ m{bsd}i ? "make" : "pmake";

unless ($fast) {
    warn "Regenerating storable files in data, please be patient...\n";
    system("cd $FindBin::RealBin/../data && $make storable >/dev/null 2>&1");
}

for $ext ("", ".st") {
    if ($bench) {
	my $t = timeit(1, 'do_tests()');
	$times{$token} += $t->[$_] for (1..4);
    } else {
	do_tests();
    }
}

if ($bench) {
    print STDERR join("\n",
		      map { "$_: $times{$_}" }
		      sort { $times{$a} <=> $times{$b} }
		      keys %times), "\n";
}

sub do_tests {
    $token = ($ext ? "Storable" : "normal");
    my $ss = new Strassen "strassen$ext";
    ok($ss->isa("Strassen"));
    my $sl = new Strassen "landstrassen$ext";
    ok($sl->isa("Strassen"));
    my $sm = new MultiStrassen($ss, $sl);
    ok($sm->isa("MultiStrassen"));
    ok($sm->isa("Strassen"));
}

__END__
