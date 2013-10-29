#!/usr/bin/perl -w
# -*- mode:cperl;coding:utf-8 -*-

#
# Author: Slaven Rezic
#

use strict;
use utf8;

use FindBin;
use lib "$FindBin::RealBin/..";

use Cwd qw(realpath cwd);
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

use_ok 'BBBikeUtil', 'bbbike_root';

my $bbbike_root = bbbike_root();
ok(-d $bbbike_root, 'Got a bbbike root directory');
is($bbbike_root, realpath(dirname(dirname(realpath($0)))), "Expected value for bbbike root (t is subdirectory)");

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
    my $pre_cwd = cwd();
    BBBikeUtil::save_pwd
	    (sub {
		 chdir "/";
	     });
    my $post_cwd = cwd();
    is $post_cwd, $pre_cwd, "cwd restored (save_pwd operation)";
}

{
    my $pre_cwd = cwd();
    {
	my $save_pwd = BBBikeUtil::save_pwd2();
	chdir "/";
    }
    my $post_cwd = cwd();
    is $post_cwd, $pre_cwd, "cwd restored (save_pwd2 operation)";
}


__END__
