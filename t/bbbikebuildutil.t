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
use File::Temp qw(tempdir);

use BBBikeBuildUtil qw(get_pmake get_modern_perl module_path module_version);
use BBBikeUtil qw(save_pwd2);

plan tests => 9;

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
	ok $pmake, "get_pmake call worked, no fallback requested";
    }
 SKIP: {
	skip "pmake-like executable not found", 1
	    if !$pmake;
	my $tmpdir = tempdir(TMPDIR => 1, CLEANUP => 1);
	my $save_pwd = save_pwd2;
	chdir $tmpdir or die "Unexpected error: cannot chdir to $tmpdir: $!";
	# Create a Makefile with BSD-specific directives
	open my $ofh, '>', 'Makefile' or die "Error writing Makefile: $!";
	print $ofh <<"EOF";
TEST=1
all:
.if defined(TEST)
\t\@echo "Success"
.endif
EOF
	close $ofh or die "Error closing Makefile filehandle: $!";

	local $ENV{MAKEFLAGS}; # protect from gnu make brain damage (MAKEFLAGS is set to "w" in recursive calls)
	open my $fh, '-|', $pmake or die $!;
	chomp(my $result = <$fh>);
	is $result, 'Success', "Running simple Makefile with $pmake worked";
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
