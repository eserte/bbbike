#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib "$FindBin::RealBin/..";

use File::Temp qw(tempdir);
use Test::More;

use BBBikeWinUtil ();

# Ironically, this test probably works only on Unix systems, not
# on systems with '\' as directory separator.
if ($^O eq 'MSWin32') {
    plan skip_all => 'Not on Win32 systems';
    exit 0;
}

plan 'no_plan';

my $tempdir = tempdir('bbbikewinutil-adjustpath-t-XXXXXXXX', CLEANUP => 1, TMPDIR => 1);

{
    local $^X = "$tempdir/cygwin\\usr\\bin\\perl.exe";
    local $ENV{PATH} = 'C:\\Windows';
    BBBikeWinUtil::adjust_path();
    is $ENV{PATH}, "C:\\Windows", 'no change to PATH in a cygwin-like environment';
}

{
    local $^X = "$tempdir/strawberry\\perl\\bin\\perl.exe";
    local $ENV{PATH} = 'C:\\Windows';
    BBBikeWinUtil::adjust_path();
    is $ENV{PATH}, "C:\\Windows", 'no change to PATH without c\\bin etc.';
}

mkdir "$tempdir/strawberry\\c\\bin" or die $!;

{
    local $^X = "$tempdir/strawberry\\perl\\bin\\perl.exe";
    local $ENV{PATH} = 'C:\\Windows';
    BBBikeWinUtil::adjust_path();
    is $ENV{PATH}, "C:\\Windows;$tempdir/strawberry\\c\\bin", 'add c\\bin to PATH';
}

mkdir "$tempdir/strawberry\\perl\\bin" or die $!;

{
    local $^X = "$tempdir/strawberry\\perl\\bin\\perl.exe";
    local $ENV{PATH} = 'C:\\Windows';
    BBBikeWinUtil::adjust_path();
    is $ENV{PATH}, "C:\\Windows;$tempdir/strawberry\\c\\bin;$tempdir/strawberry\\perl\\bin", 'add both directories to PATH';
}

__END__
