#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::RealBin/..", $FindBin::RealBin;

use File::Temp 'tempdir';
use Test::More 'no_plan';
use Time::HiRes 'sleep';

use Strassen::Util;

use BBBikeTest qw(eq_or_diff);

sub touch ($);
sub touch_until_newer ($$);

ok $Strassen::Util::cachedir, '$cachedir is defined';
ok -d $Strassen::Util::cachedir, '$cachedir points to an existing directory';
ok $Strassen::Util::cacheable, '$cacheable is true by default';
is $Strassen::Util::cacheprefix, 'b_de', '$cacheprefix is set to Berlin/Germany by default';
cmp_ok scalar(@Strassen::Util::cacheable), '>=', 1, 'at least one cache method in @cacheable';

my $testcachedir = tempdir("strassen-util-cache-t-cache-XXXXXXXX", TMPDIR => 1, CLEANUP => 1);
$Strassen::Util::cachedir = $testcachedir;
my $testdatadir = tempdir("strassen-util-cache-t-data-XXXXXXXX", TMPDIR => 1, CLEANUP => 1);
my $testsource1 = "$testdatadir/source1";
touch $testsource1;
my $testsource2 = "$testdatadir/source2";
touch $testsource2;

is Strassen::Util::get_from_cache('cache1', $testsource1), undef, 'no cache file available for single source';
is Strassen::Util::get_from_cache('cache1', [$testsource1, $testsource2]), undef, 'no cache file available for multiple sources';
my $data1 = { a => { b => 'c', d => 'e' } };
ok Strassen::Util::write_cache($data1, 'cache1'), 'write_cache was successful';
my $cache_data1 = Strassen::Util::get_from_cache('cache1', $testsource1);
eq_or_diff $cache_data1, $data1, 'cached data is the same as original data';
my $cache_file = Strassen::Util::try_cache(Strassen::Util::get_cachefile('cache1'), 0, $data1); # yes, it's so complicated to get the cache file name
ok $cache_file, 'returned cache file';
ok -e $cache_file, 'cache file exists';

touch_until_newer $testsource1, $cache_file;
is Strassen::Util::get_from_cache('cache1', $testsource1), undef, 'cache was invalidated';

is Strassen::Util::get_from_cache('bärlin', $testsource1), undef, 'cache file name may contain characters in the latin1 range';
is Strassen::Util::get_from_cache('Wrocław', $testsource1), undef, 'cache file name may contain characters outside the latin1 range';

sub touch ($) {
    my $file = shift;
    if (-e $file) {
	utime time, time, $file or die "error while setting ${file}'s mtime to current time: $!";
    } else {
	open my $fh, '>>', $file or die "error while creating empty $file: $!";
    }
}

sub touch_until_newer ($$) {
    my($srcfile, $destfile) = @_;
    my $mtime_dest = (stat $destfile)[9];
    for (1..5) {
	touch $srcfile;
	my $mtime_src = (stat $srcfile)[9];
	last if $mtime_dest < $mtime_src;
	sleep 0.5;
	#diag "touch_until_newer $srcfile $destfile: need another iteration";
    }
}

__END__
