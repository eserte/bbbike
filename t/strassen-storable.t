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

use Benchmark;
use Getopt::Long;

use Strassen::Core;
use Strassen::Storable;
use Strassen::MultiStrassen;

BEGIN {
    if (!eval q{
	use Test::More;
	die "No data/Makefile" if !-e "$FindBin::RealBin/../data/Makefile";
	1;
    }) {
	print "# tests only work with installed Test::More and a Makefile in the data directory\n";
	print "1..1\n";
	print "ok 1\n";
	exit;
    }
}

use BBBikeTest qw(get_pmake);
use BBBikeUtil qw(is_in_path);

# results with perl 5.20.1, Debian/wheezy, Xen VM:
# Strassen::Storable: 0.07
# Strassen: 0.08

my $skip_build;
my $bench;
if (!GetOptions(
		"skip-build" => \$skip_build,
		"bench" => \$bench,
	       )) {
    die "usage!";
}

if (!$skip_build) {
    my $make = get_pmake;
    if ($^O eq 'MSWin32' && !is_in_path($make)) { # XXX no pmake or similar availabl on Windows
	plan skip_all => 'Cannot build Storable files, a suitable pmake is not available';
    }
    diag "Regenerating storable files in data, please be patient...\n";
    local $ENV{MAKEFLAGS}; # protect from gnu make brain damage (MAKEFLAGS is set to "w" in recursive calls)
    system("cd $FindBin::RealBin/../data && $make storable >/dev/null 2>&1");
}

plan tests => 10;

my %times;
for my $def (
	     ['Strassen', ''],
	     ['Strassen::Storable', '.st']
	    ) {
    my($class, $ext) = @$def;
    if ($bench) {
	my $t = timeit(1, sub { do_tests($class, $ext) });
	$times{$class} += $t->[$_] for (1..4);
    } else {
	do_tests($class, $ext);
    }
}

if ($bench) {
    print STDERR join("\n",
		      map { "$_: $times{$_}" }
		      sort { $times{$a} <=> $times{$b} }
		      keys %times), "\n";
}

sub do_tests {
    my($class, $ext) = @_;
    my $ss = $class->new("strassen$ext");
    isa_ok $ss, $class;
    my $sl = $class->new("landstrassen$ext");
    isa_ok $sl, $class;

 TODO: {
	todo_skip "MultiStrassen support not possible yet with Strassen::Storable files", 2;
	my $sm = MultiStrassen->new($ss, $sl);
	isa_ok $sm, "MultiStrassen";
	isa_ok $sm, "Strassen";
    }

    {
	my $c = 0;
	while() {
	    my $r = $ss->next;
	    last if !@{ $r->[Strassen::COORDS] };
	    $c++;
	}
	cmp_ok $c, ">", 1000, "More than thousand streets (-> $c) found";
    }
}

__END__
