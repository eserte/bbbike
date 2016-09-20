#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2016 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use Getopt::Long;

sub usage (;$) {
    warn $_[0], "\n" if $_[0];
    die <<EOF;
usage: $0 city.coords.data > new.city.coords.data
       $0 -c city.coords.data
EOF
}

my $check;
GetOptions('c|check' => \$check)
    or usage;

# --check checks for correct sorting, uniqness, correct number of
# fields and correct ZIP format.

# The sort result is the same like running this with FreeBSD's sort
# with a German locale --- with the bug that "ﬂ" is not handled correctly.
# This is reflected in the perl script below (no substitution for "ﬂ").
#
# Maybe in future this could be reimplemented to use Unicode::Collate,
# but Unicode::Collate is significantly slower

my $file = shift
    or usage "coords.data file is not specified";
@ARGV and usage "Too many arguments";

open my $fh, '<', $file
    or die "Can't open $file: $!";
my @data;
my %seen;
while(<$fh>) {
    chomp;
    my @F = split /\|/, $_;
    my $sortkey = do { no warnings 'uninitialized'; lc join("|", @F[0..2]) };
    $sortkey =~ tr/‰ˆ¸ƒ÷‹·ÈË/aouaouaee/;
    if ($check) {
	if ($seen{$sortkey}++) {
	    die "Duplicate: $_\n";
	}
	if (@F < 2) {
	    die "Too less fields: " . scalar(@F) . " in '$_'\n";
	}
	if (@F > 4) {
	    die "Too many fields: " . scalar(@F) . " in '$_'\n";
	}
	if (do { no warnings; $F[2] !~ m{^(|\d{5})$} }) {
	    die "Not a ZIP: '$F[2]' in '$_'\n";
	}
    }
    push @data, [$sortkey, $_];
}

if ($check) {
    for my $i (1 .. $#data) {
	if ($data[$i-1]->[0] gt $data[$i]->[0]) {
	    die "File $file is not sorted (line $i): '$data[$i-1]->[1]' gt '$data[$i]->[1]'\n";
	}
    }
    exit 0;
} else {
    @data = sort { $a->[0] cmp $b->[0] } @data;
    for my $data (@data) {
	print $data->[1], "\n";
    }
}

__END__
