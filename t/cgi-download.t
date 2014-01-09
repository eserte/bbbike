#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;

BEGIN {
    if (!eval q{
	use Archive::Zip;
	use LWP::UserAgent;
	use Test::More;
	1;
    }) {
	print "1..0 # skip no LWP::UserAgent, Archive::Zip, and/or Test::More modules\n";
	exit;
    }
}

use FindBin;
use lib ($FindBin::RealBin, "$FindBin::RealBin/..");

use File::Temp qw(tempfile);
use Getopt::Long;

use BBBikeTest qw(check_cgi_testing zip_ok get_std_opts $cgidir);
check_cgi_testing; # may exit

plan tests => 4;

GetOptions(get_std_opts("cgidir"))
    or die "usage";

my $ua = LWP::UserAgent->new(keep_alive => 1);
$ua->agent("BBBike-Test/1.0");
$ua->env_proxy;

my($tmpfh,$tempfile) = tempfile(UNLINK => 1, SUFFIX => "_cgi-download.t.zip")
    or die $!;
for my $def (
	     ['bbbike-data.cgi',     qr{^data/\.modified$}, qr{^data/strassen$}],
	     ['bbbike-snapshot.cgi', qr{^BBBike-snapshot-\d+/bbbike$}, qr{^BBBike-snapshot-\d+/data/strassen$}],
	    ) {
    my($baseurl, @member_checks) = @$def;
    my $resp = $ua->get("$cgidir/$baseurl", ':content_file' => $tempfile);
    ok $resp->is_success, "Fetching $baseurl"
	or diag $resp->status_line;
    zip_ok $tempfile, -memberchecks => \@member_checks;
}

__END__
