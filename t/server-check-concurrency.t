#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

# Check if the throttling (if there's any) is too sharp.
# (e.g. perlbal's Throttle plugin would accept only
# two concurrent requests from the same IP address)

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
    if ($ENV{BBBIKE_TEST_NO_NETWORK}) {
        print "1..0 # skip due no network\n";
        exit;
    }
    if ($^O eq 'MSWin32') {
	print "1..0 # skip Uses fork, not on Windows\n";
	exit;
    }
}

use IO::Select;
use IO::Pipe;
use LWP::UserAgent;

use BBBikeTest qw($htmldir $cgiurl check_cgi_testing checkpoint_apache_errorlogs output_apache_errorslogs);

check_cgi_testing;

my $concurrency = 4;

plan tests => $concurrency;

#my $test_url = "$htmldir/images/favicon.ico"; # too fast to be concurrent
my $test_url = $cgiurl;

my $is_local_server = $test_url =~ m{^http://localhost};

checkpoint_apache_errorlogs if $is_local_server;

my $sel = IO::Select->new;
for (1..$concurrency) {
    my $pipe = IO::Pipe->new;
    if (fork == 0) {
	$pipe->writer;
	my $ua = LWP::UserAgent->new(agent => "BBBike-Test/1.0");
	my $resp = $ua->get($test_url);
	$pipe->print($resp->code . "\n");
	CORE::exit(0);
    }
    $pipe->reader;
    $sel->add($pipe);
}

$SIG{ALRM} = sub { die "Timeout!" };
alarm(60);

my $got_errors;
while(my @ready = $sel->can_read(30)) {
    for my $fh (@ready) {
	chomp(my $got = <$fh>);
	is $got, 200, "got 200 from $fh"
	    or $got_errors++;
	$sel->remove($fh);
    }
    last if $sel->handles == 0;
}

if ($is_local_server && $got_errors) {
    diag output_apache_errorslogs;
}

__END__
