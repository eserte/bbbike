#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: basic.t,v 1.2 2004/05/10 22:17:02 eserte Exp eserte $
# Author: Slaven Rezic
#

use strict;
use FindBin;
use ExtUtils::Manifest;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip: no Test::More module\n";
	exit;
    }
}

chdir "$FindBin::RealBin/.." or die $!;

my $manifest = ExtUtils::Manifest::maniread();

my @files = (qw(bbbike cmdbbbike cbbbike smsbbbike),
	     grep { !m{/test.pl$} }
	     grep { !m{ext/Strassen-Inline2/t/common.pl$} }
	     grep { /(\.PL|\.pl|\.cgi|\.pm)$/ }
	     keys %$manifest);

my $tests_per_file = 2;
plan tests => $tests_per_file * scalar @files;

for my $f (@files) {
 SKIP: {
	skip "$f not ready for stand-alone test", $tests_per_file
	    if $f =~ m{^ (BBBikeWeather.pm | BBBikePrint.pm) $}x;
	my @add_opt;
	if ($f =~ m{Tk/.*\.pm}) {
	    push @add_opt, "-MTk";
	}
	if ($f =~ /(.*)Heavy(.*)/) {
	    my $non_heavy = "$1$2";
	    $non_heavy =~ s{/\.pm$}{.pm};
	    $non_heavy =~ s{/}{::}g;
	    $non_heavy =~ s{\.pm$}{}g;
	    if ($non_heavy ne "BBBike") {
		push @add_opt, "-M$non_heavy";
	    }
	}
	*OLDERR = *OLDERR; # cease -w
	open(OLDERR, ">&STDERR") or die;
	my $diag_file = "/tmp/bbbike-basic.text";
	open(STDERR, ">$diag_file") or die $!;

	my $can_w = 1;
	if ($f =~ m{^( lib/Tk/FastSplash.pm # keep it small without peacifiers
		   )$}x) {
	    $can_w = 0;
	}

	system($^X, ($can_w ? "-w" : ()), "-c", "-Ilib", @add_opt, "./$f");
	close STDERR;
	open(STDERR, ">&OLDERR") or die;
	die "Signal caught" if $? & 0xff;
	is($?, 0, "Check $f")
	    or do {
		system("cat $diag_file");
	    };

	{
	    my $warn = "";
	    open(DIAG, $diag_file) or die $!;
	    while(<DIAG>) {
		next if / syntax OK/;
		$warn .= $_;
	    }
	    close DIAG;
	    is($warn, "", "Warnings in $f");
	}

	unlink $diag_file;
    }
}

__END__
