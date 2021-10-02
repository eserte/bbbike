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

use BBBikeBuildUtil qw(get_pmake get_modern_perl module_path module_version);

plan tests => 8;

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

{
    my $perl = get_modern_perl(required_modules => { 'LWP' => 0 });
    ok $perl, "Got a possibly modern perl: $perl";
}

{
    my $perl = get_modern_perl(required_modules => { 'This::Module::Does::Not::Exist' => 0 });
    is $perl, $^X, "Got fallback (current perl)";
}

{
    is module_path("BBBikeBuildUtil"), $INC{"BBBikeBuildUtil.pm"}, "module_path of BBBikeBuildUtil";
}

{
    is module_version("BBBikeBuildUtil"), $BBBikeBuildUtil::VERSION, "module_version of BBBikeBuildUtil";
}

__END__
