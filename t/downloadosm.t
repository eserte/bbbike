#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib $FindBin::RealBin;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

use File::Basename qw(basename);
use File::Glob qw(bsd_glob);
use File::Temp qw(tempdir);
use Getopt::Long;

use BBBikeUtil qw(is_in_path);
use BBBikeTest qw(xmllint_file);

my $doit;
GetOptions("doit!" => \$doit)
    or die "usage: $0 [-doit]";

if (!$doit) {
    plan skip_all => 'Use -doit to actually run tests';
    exit 0;
}

plan 'no_plan';

my $downloadosm_script = "$FindBin::RealBin/../miscsrc/downloadosm";
my $tmpdir = tempdir(TMPDIR => 1, CLEANUP => 1) or die;

{
    my @cmd = ($^X, $downloadosm_script, "-o", $tmpdir, "--", "52.587692", "13.255164", "52.584465", "13.267383");
    system @cmd;
    is $?, 0, "Run @cmd";
    my @files = bsd_glob("$tmpdir/download_*.osm.gz");
    cmp_ok scalar(@files), ">=", 1, "Found at least one gzipped .osm file in download directory"
	or diag "Contents of $tmpdir: " . join("\n", bsd_glob("$tmpdir/*"));
    for my $file (@files) {
	if (is_in_path('gunzip')) {
	    system 'gunzip', $file;
	    $file =~ s{\.gz$}{};
	    xmllint_file($file, "xmllint for " . basename($file));
	}
    }
}

__END__
