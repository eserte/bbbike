#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: db_impl.t,v 1.12 2004/12/18 10:44:10 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2001, 2002, 2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

BEGIN {

}

use Cwd;
BEGIN { $root = "../.." }
use lib ($root, "$root/lib", "$root/data");
use lib @lib::ORIG_INC;
use Strassen;
use Strassen::Build;
use StrassenNetz::CNetFile;
use Storable;
use FindBin;
use Getopt::Long;
require Strassen::Inline2;
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

use vars qw($net $algorithm);

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..1\n";
	print "ok 1 # skip tests only work with installed Test::More module\n";
	exit;
    }

    $tests = 24;
}

BEGIN { plan tests => $tests }

if (!GetOptions("v+" => \$v)) {
    die "usage: $0 [-v]";
}
if ($v > 0) {
    Strassen::set_verbose(1);
}

$algorithm = "C-A*-2";

my $leaktest = exists &Devel::Leak::NoteSV;

my($start_coord, $goal1_coord, $goal2_coord);
# pick up some random coords
my $s = Strassen->new("strassen");
my $inacc = Strassen->new("inaccessible_strassen");
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

pass("Initialization");
ok(defined &Strassen::Inline2::search_c, "Search sub defined");

$net = StrassenNetz->new($s);
#  my $prefix = "/tmp/test_strassen";

#  ok($net->create_mmap_net_if_needed($prefix));

#  ok(Strassen::CNetFile::mmap_net_file($net, $net->filename_c_net_mmap($prefix)));
#  $net->{CNetCoord2Ptr} = retrieve($net->filename_c_net_coord2ptr($prefix));
#  ok($net->{CNetCoord2Ptr});
#  ok(exists $net->{CNetCoord2Ptr}{$start_coord});

$net->use_data_format($StrassenNetz::FMT_MMAP);
#require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([$net->can("make_net")],[])->Deparse(1)->Indent(1)->Useqq(1)->Dump; # XXX

if (0) { # This does not work because search_c does not use
    # StrassenNetz::search, where BlockingNet is activated
    $net->make_net;
    $net->make_sperre("gesperrt", Type => [qw(einbahn sperre wegfuehrung)]);
} else {
    $net->make_net(-blocked => "gesperrt");
    $net->make_sperre("gesperrt", Type => [qw(wegfuehrung)]);
}

ok($net->reachable($start_coord), "$start_coord reachable");
ok($net->reachable($goal1_coord), "$goal1_coord reachable");
ok($net->reachable($goal2_coord), "$goal2_coord reachable");

@arr = Strassen::Inline2::search_c($net, $start_coord, $goal1_coord);
ok(@arr, "Path between $start_coord and $goal1_coord");
is(ref $arr[0], 'ARRAY', "Path elements correct");

@arr = Strassen::Inline2::search_c($net, $start_coord, $goal2_coord);
ok(@arr, "Path between $start_coord and $goal2_coord");
is(ref $arr[0], 'ARRAY', "Path elements correct");

{
    my $handle;
    Devel::Leak::NoteSV($handle) if $leaktest;
    {
	my @arr = Strassen::Inline2::search_c($net, $fixed_start, $fixed_goal);
	ok(@arr, "Path between $fixed_start and $fixed_goal");
	is(ref $arr[0], 'ARRAY', "Path elements correct");
    }
    Devel::Leak::CheckSV($handle) if $leaktest;
}

#use Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->Dumpxs([@arr],[]); # XXX

# should not segv:
@arr = eval { Strassen::Inline2::search_c($net, "not", "existing") };
isnt($@, "", "Expected error message");
is(scalar @arr, 0, "Expected no result");

do "$FindBin::RealBin/common.pl";
die $@ if $@;

__END__
