#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: hv_impl.t,v 1.14 2003/08/07 21:31:57 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2001,2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

use Test;

BEGIN {

    print "1..1\nok 1\n"; exit;

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
if ($v > 0) {
    Strassen::set_verbose(1);
}

use vars qw($algorithm);
$algorithm = "C-A*";

my $leaktest = exists &Devel::Leak::NoteSV;

ok(1);

ok(defined &Strassen::Inline::search_c);

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
ok(!(!@arr || ref $arr[0] ne 'ARRAY'));

{
    my $handle;
    Devel::Leak::NoteSV($handle) if $leaktest;
    {
	my @arr = Strassen::Inline::search_c($net, $fixed_start, $fixed_goal);
	ok(@arr);
	ok(ref $arr[0] eq 'ARRAY');
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
ok(!($@ !~ /not reachable/));

do "$FindBin::RealBin/common.pl";
die $@ if $@;

__END__
