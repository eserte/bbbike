#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib "$FindBin::RealBin/..";

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

use BBBikeBuildUtil qw(get_pmake);

plan tests => 2;

my $pmake = get_pmake;
ok $pmake, "pmake call worked, result is $pmake";

{
    chdir "$FindBin::RealBin/.." or die $!;
    open my $fh, '-|', $^X, '-MBBBikeBuildUtil=get_pmake', '-e', 'print get_pmake'
	or die $!;
    my $pmake_via_cmdline = <$fh>;
    close $fh;
    is $pmake_via_cmdline, $pmake, 'cmdline call also works';
}

__END__
