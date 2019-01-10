#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 $FindBin::RealBin,
	);

use Storable qw(dclone);

use Strassen::MultiStrassen;

use BBBikeTest qw(using_bbbike_test_data);

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

plan 'no_plan';

using_bbbike_test_data;

my $strassen = Strassen->new('strassen');
my $gesperrt = Strassen->new('gesperrt');
my $hoehe    = Strassen->new('hoehe');

{
    my $multi = MultiStrassen->new($strassen, $gesperrt);
    isa_ok $multi, 'MultiStrassen';
    isa_ok $multi, 'Strassen';

    my $r = $multi->next;
    is $r->[Strassen::NAME], 'Dudenstr.';

    my $found_in_gesperrt;
    while () {
	$r = $multi->next;
	last if !$r->[Strassen::COORDS];
	if ($r->[Strassen::NAME] eq 'ein Poller') {
	    $found_in_gesperrt++;
	    last;
	}
    }
    ok $found_in_gesperrt, 'found a record from gesperrt file';
}

{
    my $ms1 = MultiStrassen->new($strassen);
    my $ms2 = MultiStrassen->new($strassen);
    ok $ms1->shallow_compare($ms2), 'shallow compare of effective simple Strassen objects';
}

{
    my $ms1 = MultiStrassen->new($strassen, $gesperrt);
    my $ms2 = MultiStrassen->new($strassen, $gesperrt);
    ok $ms1->shallow_compare($ms2), 'shallow compare of simple MultiStrassen objects';
}

{
    my $ms1 = MultiStrassen->new($strassen, $gesperrt);
    my $ms2 = MultiStrassen->new($strassen, $hoehe);
    ok !$ms1->shallow_compare($ms2), 'a difference';
}

{
    my $hoehe_clone = dclone $hoehe;
    my $ms1 = MultiStrassen->new($strassen, $hoehe);
    my $ms2 = MultiStrassen->new($strassen, $hoehe_clone);
    ok $ms1->shallow_compare($ms2), 'first the same';

    $hoehe_clone->{Modtime}-=86400; # fake a change
    ok !$ms1->shallow_compare($ms2), 'difference with changed mtime';
}


__END__
