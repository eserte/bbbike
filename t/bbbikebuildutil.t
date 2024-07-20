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

use BBBikeBuildUtil qw(get_pmake get_modern_perl module_path module_version monkeypatch_manifind is_system_perl);
use BBBikeUtil qw(save_pwd2);

plan tests => 24;

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
    my $pmake_canV = eval { get_pmake canV => 1, fallback => 0 };
    isnt $pmake_canV, 'bmake', "bmake cannot cope with -V correctly, result is " . (defined $pmake_canV ? $pmake_canV : "<undef>");
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
    my $perl = get_modern_perl();
    ok $perl, "Got a possibly modern perl: $perl";
}

{
    ok !eval { get_modern_perl(unknown_option => 1); 1 }, 'error on unknown option';
    like $@, qr{unhandled args}i, 'error message';
}

{
    my $perl = get_modern_perl(required_modules => { 'LWP' => 0 });
    ok $perl, "Got a possibly modern perl with LWP installed: $perl";
}

{
    my $perl = get_modern_perl(required_modules => { 'This::Module::Does::Not::Exist' => 0 });
    is $perl, $^X, "Got fallback (current perl)";
}

{
    my $perl = get_modern_perl(required_modules => { 'This::Module::Does::Not::Exist' => 0 }, fallback => 0);
    is $perl, undef, "No fallback";
}

SKIP: {
    skip "Capture::Tiny required", 2
	if !eval { require Capture::Tiny; 1 };
    my $perl;
    my $stderr = Capture::Tiny::capture_stderr
	    (sub {
		 $perl = get_modern_perl(required_modules => { 'This::Module::Does::Not::Exist' => 0 }, fallback => 0, debug => 1);
	     });
    is $perl, undef, "No fallback (with debug option)";
    like $stderr, qr{No matching perl found, and fallback is disabled}, 'expected debugging message';
}

{
    is \&module_path, \&BBBikeUtil::module_path, 'module_path comes from BBBikeUtil'; # comprehensive tests are now in bbbikeutil.t
}

{
    is module_version("BBBikeBuildUtil"), $BBBikeBuildUtil::VERSION, "module_version of BBBikeBuildUtil";
}

{
    my $tmpdir = tempdir(TMPDIR => 1, CLEANUP => 1);
    ok BBBikeBuildUtil::is_same_file(__FILE__, __FILE__), 'same file';
    ok !BBBikeBuildUtil::is_same_file(__FILE__, $^X), 'not the same file';

    { open my $ofh, ">", "$tmpdir/original" or die $! };

 SKIP: {
	my $symlink_exists = eval { symlink("",""); 1 };
	skip "No symlink support", 2 if !$symlink_exists;

	symlink("$tmpdir/original", "$tmpdir/symlink");
	ok BBBikeBuildUtil::is_same_file("$tmpdir/original", "$tmpdir/symlink"), 'same file for symlinks';
	ok BBBikeBuildUtil::is_same_file("$tmpdir/symlink", "$tmpdir/original"), 'same file for symlinks, reversed';
    }

    link "$tmpdir/original", "$tmpdir/hardlink";
    ok BBBikeBuildUtil::is_same_file("$tmpdir/original", "$tmpdir/hardlink"), 'same file for hardlinks';
}

SKIP: {
    skip "No is_system_perl check available for this system", 2
	if $^O ne 'linux' || $^X ne '/usr/bin/perl';
    ok is_system_perl(), 'running on system perl';
    ok is_system_perl('/usr/bin/perl'), '/usr/bin/perl is system perl';
}

# should be last (as it is monkeypatching things)
{
    my $tmpdir = tempdir(TMPDIR => 1, CLEANUP => 1);
    my $save_pwd = save_pwd2;
    chdir $tmpdir or die "Unexpected error: cannot chdir to $tmpdir: $!";
    { open my $ofh, '>', "testfile1"; close $ofh or die $! }
    monkeypatch_manifind();
    my $res = ExtUtils::Manifest::manifind();
    is_deeply $res, { 'testfile1' => '' }, 'manifind result';
}

__END__
