#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: basic.t,v 1.1 2004/03/26 22:04:36 eserte Exp $
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
	     grep { /(\.PL|\.pl|\.cgi|\.pm)$/ } keys %$manifest);
warn scalar @files;

plan tests => scalar @files;

for my $f (@files) {
    my @add_opt;
    if ($f =~ m{Tk/.*\.pm}) {
	push @add_opt, "-MTk";
    }
    system($^X, "-c", "-Ilib", @add_opt, "./$f");
    is($?, 0, "Check $f");
}

__END__
