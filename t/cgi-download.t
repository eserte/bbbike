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

use BBBikeTest qw(check_cgi_testing zip_ok get_std_opts $cgidir checkpoint_apache_errorlogs output_apache_errorslogs);
check_cgi_testing; # may exit

plan tests => 6;

GetOptions(get_std_opts("cgidir"))
    or die "usage";

my $ua = LWP::UserAgent->new(keep_alive => 1);
$ua->agent("BBBike-Test/1.0");
$ua->env_proxy;

my $snapshot_github_rootdir_qr = qr{(BBBike-snapshot-\d+|bbbike-master)};
my $snapshot_rootdir_qr = qr{BBBike-snapshot-\d+};

my $is_local_server = $cgidir =~ m{^http://localhost};

my($tmpfh,$tempfile) = tempfile(UNLINK => 1, SUFFIX => "_cgi-download.t.zip")
    or die $!;
for my $def (
	     # base URL                      SKIP condition                member checks
	     ['bbbike-data.cgi',             undef,                        qr{^data/\.modified$}, qr{^data/strassen$}],
	     ['bbbike-snapshot.cgi',         sub { $LWP::VERSION < 6.05 }, qr{^$snapshot_github_rootdir_qr/bbbike$}, qr{^$snapshot_github_rootdir_qr/data/strassen$}],
	     ['bbbike-snapshot.cgi?local=1', undef,                        qr{^$snapshot_rootdir_qr/bbbike$}, qr{^$snapshot_rootdir_qr/data/strassen$}],
	    ) {
    my($baseurl, $SKIP_condition, @member_checks) = @$def;
 SKIP: {
	skip "LWP $LWP::VERSION may have problems with downloads from github", 2
	    if $SKIP_condition && $SKIP_condition->();
	checkpoint_apache_errorlogs if $is_local_server;
    my $resp = $ua->get("$cgidir/$baseurl", ':content_file' => $tempfile);
	ok $resp->is_success && !$resp->header('X-Died'), "Fetching $baseurl"
	    or do {
		output_apache_errorslogs if $is_local_server;
		diag $resp->status_line;
		diag $resp->headers->as_string;
	    };
	    
	zip_ok $tempfile, -memberchecks => \@member_checks;
    }
}

__END__
