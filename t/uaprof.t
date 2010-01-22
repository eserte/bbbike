#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use Getopt::Long;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

plan tests => 1;

my $www_cache = 1;
my $db_cache  = 1;
my $debug = 0;
GetOptions("dbcache!"  => \$db_cache,
	   "wwwcache!" => \$www_cache,
	   "d|debug!"  => \$debug,
	  )
    or die "usage: $0 [-nodbcache] [-nowwwcache] [-debug]";

my $uaprof_cache_dir = "$FindBin::RealBin/../tmp/uaprof";
my $uaprof_cache_file = "$uaprof_cache_dir/nds.nokia.com/uaprof/N6100r100.xml";
if (!$www_cache) {
    rename $uaprof_cache_file, "$uaprof_cache_file~"
	or warn "Could not move $uaprof_cache_file to backup ($!), continuing...";
}
if (!$db_cache) {
    rename $uaprof_cache_file.".db", "$uaprof_cache_file.db~"
	or warn "Could not move $uaprof_cache_file.db to backup ($!), continuing...";
}

open my $fh, "-|", $^X, "$FindBin::RealBin/../lib/BrowserInfo/UAProf.pm",
    "http://nds.nokia.com/uaprof/N6100r100.xml", "ScreenSize",
    ($debug ? "-d" : ())
    or die "Can't run UAProf module: $!";
my $buf = "";
while(<$fh>) {
    $buf .= $_;
}
close $fh
    or die $!;
chomp $buf;
is($buf, '128x128', 'Running uaprof');

__END__
