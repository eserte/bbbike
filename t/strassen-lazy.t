#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassen-lazy.t,v 1.11 2005/04/06 21:03:03 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data");

BEGIN {
    if (!eval q{
	use Strassen::Lazy;
	require Object::Realize::Later; Object::Realize::Later->VERSION(0.13);
	use Test;
	1;
    }) {
	warn $@;
	print "1..0 # skip no Test/Object::Realize::Later modules\n";
	exit;
    }
}

BEGIN { plan tests => 22 }

{
    my $s = Strassen::Lazy->new("strassen");
    ok(UNIVERSAL::isa($s, "Strassen::Lazy"));
    my $r;
    $r = $s->get(1); # trigger realization
    ok($s->isa("Strassen"));
    ok($r);
    ok($r->[Strassen::NAME], "Methfesselstr."); # by default the second name
    $r = $s->get_by_name("Mehringdamm");
    ok($r);
    ok($r->[Strassen::NAME], "Mehringdamm");
}

{
    my $s = MultiStrassen::Lazy->new(qw(strassen landstrassen landstrassen2));
    ok(UNIVERSAL::isa($s, "MultiStrassen::Lazy"));
    my $r;
    $r = $s->get(1); # trigger realization
    ok($s->isa("MultiStrassen"));
    ok($r);
    ok($r->[Strassen::NAME], "Methfesselstr."); # by default the second name
    $r = $s->get_by_name("Sonntagstr.");
    ok($r);
    ok($r->[Strassen::NAME], "Sonntagstr.");
    $r = $s->get_by_name("B96");
    ok($r);
    ok($r->[Strassen::NAME], "B96");
}

my $projectdir = "$FindBin::RealBin/../projects/radlstadtplan_muenchen/data_Muenchen_DE";

if (-d $projectdir && -f "$projectdir/strassen") {
    local @Strassen::datadirs = $projectdir;
    {
	my $s = Strassen::Lazy->new("strassen");
	my $r;
	$r = $s->get(1); # trigger realization
	ok($s->isa("Strassen"));
	ok($r);
	$r = $s->get_by_name("Arcostr.");
	ok($r);
	ok($r->[Strassen::NAME], "Arcostr.");
    }

    {
	my $s = MultiStrassen::Lazy->new("strassen");
	my $r;
	$r = $s->get(1); # trigger realization
	ok($s->isa("MultiStrassen"));
	ok($r);
	$r = $s->get_by_name("Arcostr.");
	ok($r);
	ok($r->[Strassen::NAME], "Arcostr.");
    }
} else {
    skip("No $projectdir available", 1) for 1..8;
}

__END__

=head1 BENCHMARK

Here's a benchmark script to test the performance gain of ::Lazy.
Please run the script twice to fill the all_crossings-Cache first.

    use Strassen;
    use Strassen::Lazy;
    use Time::HiRes qw(gettimeofday tv_interval);
    
    @s = qw(strassen landstrassen landstrassen2);
    
    $x = [gettimeofday];
    $s = MultiStrassen->new(@s);
    $s->all_crossings(RetType => 'hashpos',UseCache => 1,Kurvenpunkte => 1);
    warn tv_interval($x);
    
    $x = [gettimeofday];
    $s = MultiStrassen::Lazy->new(@s);
    $s->all_crossings(RetType => 'hashpos',UseCache => 1,Kurvenpunkte => 1);
    warn tv_interval($x);

=cut
