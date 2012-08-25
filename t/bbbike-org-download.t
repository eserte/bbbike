#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use File::Temp qw(tempdir);
use Strassen::Core ();

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

my $download_script = "$FindBin::RealBin/../miscsrc/bbbike.org_download.pl";

ok -e $download_script, 'Download script exists';

my @listing;
{
    chomp(@listing = `$^X $download_script`);
    # 2012-03-16: there are 231 cities available + original bbbike data
    cmp_ok scalar(@listing), ">=", 100, 'More than 100 cities found';
    
    ok grep { $_ eq 'Wien' } @listing, 'Found Wien in listing';
}

{
    my $random = $ENV{BBBIKE_TEST_SLOW_NETWORK} ? 0 : 1;

    my($dir) = tempdir("bbbike.org_download_XXXXXXXX", CLEANUP => 1, TMPDIR => 1)
	or die "Cannot create temporary directory: $!";
    my $city = $random ? $listing[rand(@listing)] : 'Cusco';
    system($^X, $download_script, "-city", $city, "-o", $dir, "-agentsuffix", " (testing)");
    is $?, 0, "Downloading city '$city'";
    ok -d "$dir/$city", "Directory $dir/$city exists";
    ok -f "$dir/$city/strassen", "strassen found for $city";
    ok -f "$dir/$city/meta.yml", "meta.yml found for $city";

    my $s = Strassen->new("$dir/$city/strassen");
    isa_ok $s, 'Strassen';
}

__END__
