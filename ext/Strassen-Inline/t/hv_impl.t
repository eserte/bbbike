#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: hv_impl.t,v 1.18 2004/12/18 10:44:06 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001,2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..1\n";
	print "ok 1 # skip tests only work with installed Test::More module\n";
	exit;
    }
}

BEGIN {
# ***FILTER=2***
#    print "1..1\nok 1\n"; exit;
# ***FILTER=1***
     plan tests => 17
# ***FILTER=all***
}

use Cwd;
BEGIN { $root = "../.." }
use lib ($root, "$root/lib", "$root/data");
use lib @lib::ORIG_INC;
use Strassen;
use FindBin;
use Getopt::Long;
require Strassen::Inline;
Inline->init;

BEGIN {
    eval {
	require Devel::Leak;
	import Devel::Leak;
    };
    if ($@) {
	warn "Devel::Leak not found, memory leak tests not activated.\n";
    }
}

if (!GetOptions("v+" => \$v)) {
    die "usage: $0 [-v]";
}
if (defined $v && $v > 0) {
    Strassen::set_verbose(1);
}

use vars qw($algorithm);
$algorithm = "C-A*";

my $leaktest = defined &Devel::Leak::NoteSV;

pass("Initialization");

ok(defined &Strassen::Inline::search_c, "Search sub defined");

my($start_coord, $goal1_coord, $goal2_coord);
# pick up some random coords
my $s = Strassen->new("strassen");
my $inacc = Strassen->new("inaccessible_strassen");
# XXX check for inaccessible_strassen, otherwise skip!
my $inacc_hash = $inacc->get_hashref;
for my $coordref (\$start_coord, \$goal1_coord, \$goal2_coord) {
    while(1) {
	$$coordref = $s->get(rand($#{$s->{Data}}))->[Strassen::COORDS][0];
	last if (!exists $inacc_hash->{$$coordref});
    }
}
# fixed start/goal (for better comparisons)
my $fixed_start = $s->get(0)->[Strassen::COORDS][0];
my $fixed_goal  = $s->get($#{$s->{Data}})->[Strassen::COORDS][-1];

use vars qw($net);
$net = StrassenNetz->new($s);
$net->make_net;
$net->make_sperre("gesperrt", Type => [qw(einbahn sperre wegfuehrung)]);

@arr = Strassen::Inline::search_c($net, $start_coord, $goal1_coord);
ok(!(!@arr || ref $arr[0] ne 'ARRAY'), "Path result");

{
    my $handle;
    Devel::Leak::NoteSV($handle) if $leaktest;
    {
	my @arr = Strassen::Inline::search_c($net, $fixed_start, $fixed_goal);
	ok(@arr, "Path between $fixed_start and $fixed_goal");
	is(ref $arr[0], 'ARRAY', "Path elements correct");
	#XXX use Devel::Peek;Dump($arr[0]);
	if ($v > 2) {
	    require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([$fixed_start, $fixed_goal, \@arr, scalar @{ $arr[0] }],[])->Indent(1)->Useqq(1)->Dump; # XXX
	}

    }
    Devel::Leak::CheckSV($handle) if $leaktest;
}

$@ = "";
eval {
    # should not segv:
    Strassen::Inline::search_c($net, "not", "existing");
};
ok(!($@ !~ /not reachable/), "Reachable error message");

do "$FindBin::RealBin/common.pl";
die $@ if $@;

__END__
