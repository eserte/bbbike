#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib ($FindBin::RealBin, "$FindBin::RealBin/..");

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
my $debug;
GetOptions(
    "doit!" => \$doit,
    "debug" => \$debug,
)
    or die "usage: $0 [-doit] [-debug]\n";

if (!$doit) {
    plan skip_all => 'Use -doit to actually run tests';
    exit 0;
}

plan 'no_plan';

my $downloadosm_script = "$FindBin::RealBin/../miscsrc/downloadosm";
my $tmpdir = tempdir(TMPDIR => 1, CLEANUP => ($debug ? 0 : 1)) or die "Can't create temporary directory";

{
    my @cmd = ($^X, $downloadosm_script, ($debug ? ('-debug', 3) : ()), "-o", $tmpdir, "--", qw(13.255164 52.587692 13.267383 52.584465));
    system @cmd;
    is $?, 0, "Run @cmd";
    my @files = bsd_glob("$tmpdir/download_*.osm.gz");
    cmp_ok scalar(@files), ">=", 1, "Found at least one gzipped .osm file in download directory"
	or diag "Contents of $tmpdir: " . join("\n", bsd_glob("$tmpdir/*"));
    for my $file (@files) {
	if (1 && is_in_path('gunzip')) { # xmllint/libxml2 is supposed to handle gzipped files, however XML::LibXML::parse_string cannot, so we gunzip here
	    system 'gunzip', $file;
	    $file =~ s{\.gz$}{};
	    xmllint_file($file, "xmllint for " . basename($file));
	} elsif (0) {
	    # XXX this code path would work if XML::LibXML::parse_string could handle compressed files
	    xmllint_file($file, "xmllint for " . basename($file))
		or diag "File format: ".`file $file`;
	}
    }
}

if ($debug) {
    diag "DEBUG: temporary files kept in $tmpdir";
}

__END__
