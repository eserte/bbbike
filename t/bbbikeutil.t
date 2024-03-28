#!/usr/bin/perl -w
# -*- mode:cperl;coding:utf-8 -*-

#
# Author: Slaven Rezic
#

use strict;
use utf8;

use FindBin;
use lib "$FindBin::RealBin/..";

use Cwd qw(realpath getcwd);
use File::Basename qw(dirname);

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

use BBBikeUtil qw(bbbike_root);

my @warnings;
$SIG{__WARN__} = sub { push @warnings, @_ };

my $bbbike_root = bbbike_root();
ok(-d $bbbike_root, 'Got a bbbike root directory');
is($bbbike_root, realpath(dirname(dirname(realpath($0)))), "Expected value for bbbike root (t is subdirectory)");

my $bbbike_aux_dir = BBBikeUtil::bbbike_aux_dir();
if (defined $bbbike_aux_dir) {
    ok(-d $bbbike_aux_dir, 'Got a bbbike-aux directory, and it exists');
} else {
    is $bbbike_aux_dir, undef, 'no bbbike-aux directory available';
}

{
    is(BBBikeUtil::s2hms(0),     "0:00:00", "s2hms checks");
    is(BBBikeUtil::s2hms(1),     "0:00:01");
    is(BBBikeUtil::s2hms(59),    "0:00:59");
    is(BBBikeUtil::s2hms(60),    "0:01:00");
    is(BBBikeUtil::s2hms(3599),  "0:59:59");
    is(BBBikeUtil::s2hms(3600),  "1:00:00");
    is(BBBikeUtil::s2hms(36000),"10:00:00");
}

{
    is(BBBikeUtil::m2km(1234,3,2), '1.230 km', 'm2km checks');
    is(BBBikeUtil::m2km(1239,3,2), '1.230 km', 'kaufmaennisches Runden not done here'); # XXX maybe it should?
    is(BBBikeUtil::m2km(1239,3),   '1.239 km', 'without sigdig');
    is(BBBikeUtil::m2km(1239,2),   '1.24 km',  'without sigdig, rounding by sprintf');
    is(BBBikeUtil::m2km(5,3,2),    '0.005 km', 'significant though below two digits');
    is(BBBikeUtil::m2km(50,3,1),   '0.050 km');
}

{
    # See also abbiegen.t and Strassen::Util::abbiegen for the same
    # problem
    my($angle,$dir) = BBBikeUtil::schnittwinkel(12960,8246,12918,8232,12792,8190);
    is $angle, 0, 'No nan on schnittwinkel call';
}

{
    my($angle,$dir) = BBBikeUtil::schnittwinkel(12960,8246,12918,8232,12918,8232);
    is $angle, undef, 'Should not die if two points are the same';
}

{
    my($angle,$dir) = BBBikeUtil::schnittwinkel(12960,8246,12960,8246,12918,8232);
    is $angle, undef, 'Should not die if two points are the same';
}

{
    my(undef,$dir) = BBBikeUtil::schnittwinkel(11671,13775, 11664,13990, 11836,13993);
    is $dir, 'r', 'right turn';
}

{
    my(undef,$dir) = BBBikeUtil::schnittwinkel(11671,13775, 11664,13990, 11492,14000);
    is $dir, 'l', 'left turn';
}

{
    is BBBikeUtil::ceil(1), 1, 'ceil with integer';
    is BBBikeUtil::ceil(1.0), 1;
    is BBBikeUtil::ceil(1.1), 2;
    is BBBikeUtil::ceil(1.9999999999), 2;
}

{
    # This list is already sorted
    my @test = (
		'Aachener Str.',
		'(am Bundeskanzleramt)',
		'(A.T.U-Einfahrt - ALDI-Parkplatz)',
		'Brommystr.',
		'Bröndbystr.',
		'Brontëweg',
		'Brook-Taylor-Str.',
		'Brösener Str.',
		'Brotteroder Str.',
		'Grünberger Str.',
		'("Grünes Band")',
		'Oschatzer Ring',
		'Öschelbronner Weg',
		'Osdorfer Str.',
		'Zwischen den Giebeln',
	       );

    {
	my @res = BBBikeUtil::sort_german(\@test);
	is_deeply \@res, \@test, 'sort_german';
    }

    {
	my @rev_test = reverse @test;
	my @res = BBBikeUtil::sort_german(\@test);
	is_deeply \@res, \@test, 'sort_german (2)';
    }
}

{
    my @test_with_polish = (
			    'Dąbie',
			    'Dabrun',
			    'Dechtow',
			    'Děčín',
			    'Dyrotz',
			    'Górzyca',
			    'Gosen',
			    'Leitzkau',
			    'Łęknica',
			    'Lemmersdorf',
			    'Sieversdorf b. Neustadt',
			    'Słońsk',
			    'Słubice',
			    'Summt',
			    'Świnoujście',
			    'Szczecin',
			    'Usedom',
			    'Ústí nad Labem',
			    'Ützdorf',
			    'Vehlefanz',
			   );
    {
	my @res = BBBikeUtil::sort_german(\@test_with_polish);
	is_deeply \@res, \@test_with_polish, 'sort_german (with some Polish characters)';
    }
}

{
    my $pre_cwd = getcwd();
    BBBikeUtil::save_pwd
	    (sub {
		 chdir "/";
	     });
    my $post_cwd = getcwd();
    is $post_cwd, $pre_cwd, "cwd restored (save_pwd operation)";
}

{
    my $pre_cwd = getcwd();
    {
	my $save_pwd = BBBikeUtil::save_pwd2();
	chdir "/";
    }
    my $post_cwd = getcwd();
    is $post_cwd, $pre_cwd, "cwd restored (save_pwd2 operation)";
}

for my $exec ('perl',
	      ('sh') x!! ($^O ne 'MSWin32'), # usually not available on Windows
	     ) {
    my $path = BBBikeUtil::is_in_path($exec);
    if (!$path) {
	diag "Strange: $exec is not found on this system";
    }
    my $cached_path1 = BBBikeUtil::is_in_path_cached($exec);
    my $cached_path2 = BBBikeUtil::is_in_path_cached($exec);
    is $cached_path1, $path, "Results of is_in_path and is_in_path_cached do not differ ($exec)";
    is $cached_path2, $cached_path1, "Same result for subsequent is_in_path_cached calls ($exec)";
}

for my $try_mod ('URI', 'CGI') {
 SKIP: {
	local $BBBikeTest::SIMULATE_WITHOUT_URI;
	if ($try_mod eq 'CGI') {
	    $BBBikeTest::SIMULATE_WITHOUT_URI = 1;
	}

	{
	    my $u = BBBikeUtil::uri_with_query("http://example.com", []);
	    is $u, 'http://example.com', "uri_with_query without param, impl $try_mod";
	}

	{
	    my $u = BBBikeUtil::uri_with_query("http://example.com", [foo=>"bar"]);
	    is $u, 'http://example.com?foo=bar', "uri_with_query, impl $try_mod";
	}

	{
	    my $u = BBBikeUtil::uri_with_query("http://example.com", [foo=>"bar", baz=>"blubber"]);
	    is $u, 'http://example.com?foo=bar&baz=blubber', "uri_with_query, more params, impl $try_mod";
	}

	{
	    my $u = BBBikeUtil::uri_with_query("https://example.com", [foo=>"with space"]);
	    is $u, 'https://example.com?foo=with%20space', "uri_with_query, with space, impl $try_mod";
	}

	{
	    my $u = BBBikeUtil::uri_with_query("https://example.com", [foo=>"B\xfclowstra\xdfe"]);
	    is $u, 'https://example.com?foo=B%C3%BClowstra%C3%9Fe', "uri_with_query, default encoding, impl $try_mod";
	}

	{
	    my $u = BBBikeUtil::uri_with_query("https://example.com", [foo=>"B\xfclowstra\xdfe"], encoding => 'utf-8');
	    is $u, 'https://example.com?foo=B%C3%BClowstra%C3%9Fe', "uri_with_query, explicit utf-8 encoding, impl $try_mod";
	}

	{
	    my $u = BBBikeUtil::uri_with_query("https://example.com", [foo=>"B\xfclowstra\xdfe"], encoding => 'iso-8859-1');
	    is $u, 'https://example.com?foo=B%FClowstra%DFe', "uri_with_query, explicit latin1 encoding, impl $try_mod";
	}

	{
	    my $u = BBBikeUtil::uri_with_query("https://example.com", [dangerous=>"<&>"]);
	    is $u, 'https://example.com?dangerous=%3C%26%3E', "uri_with_query, special html chars, impl $try_mod";
	}

	{
	    my $u = BBBikeUtil::uri_with_query("http://example.com", [], raw_query => [baz=>'?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~']);
	    is $u, 'http://example.com?baz=?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~', "uri_with_query only with raw_query, impl $try_mod";
	}

	{
	    my $u = BBBikeUtil::uri_with_query("http://example.com", [foo=>"bar"], raw_query => [baz=>'blubber']);
	    is $u, 'http://example.com?foo=bar&baz=blubber', "uri_with_query, with normal query and raw_query, impl $try_mod";
	}
    }
}

{
    is BBBikeUtil::module_path("BBBikeUtil"), $INC{"BBBikeUtil.pm"}, "module_path of BBBikeUtil";
    like BBBikeUtil::module_path('Time::Piece'), qr{\Q/Time/Piece.pm\E$}, "module_path of a module unlikely to be loaded"; # note that StrawberryPerl is also using forward slashes
    is BBBikeUtil::module_path("ThisModuleDoesNotExist$$"), undef, "module_path of non-existing module";
}

{
    is BBBikeUtil::module_exists("BBBikeUtil"), 1, "module_exists on BBBikeUtil";
    is BBBikeUtil::module_exists('Time::Piece'), 1, "module_exists on core module Time::Piece";
    is BBBikeUtil::module_exists("ThisModuleDoesNotExist$$"), 0, "module_exists on non-existing module";
}

is_deeply \@warnings, [], 'no warnings';

__END__
