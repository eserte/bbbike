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

use IO::Pipe ();

use BBBikeBuildUtil qw(get_pmake);

plan tests => 4;

my $pmake = get_pmake;
ok $pmake, "pmake call worked, result is $pmake";

{
    chdir "$FindBin::RealBin/.." or die $!;
    my $pmake_via_cmdline = IO::Pipe->new->reader
	($^X, '-I.', '-MBBBikeBuildUtil=get_pmake', '-e', 'print get_pmake')
	->getline;
    is $pmake_via_cmdline, $pmake, 'cmdline call also works';
}

{
    eval { get_pmake invalid => "option" };
    like $@, qr{^Unhandled args: invalid option}, 'check for invalid options';
}

{
    my $pmake = eval { get_pmake fallback => 0 };
    if (!$pmake) {
	like $@, qr{^No BSD make found on this system}, 'fallback => 0 without finding anything';
    } else {
	ok $pmake, "pmake call worked, no fallback requested";
    }
}

__END__
