#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 $FindBin::RealBin,
	);
use File::Basename;
use Time::HiRes qw(time);

BEGIN {
    if (!eval q{
	use Test::More;
	use LWP::UserAgent;
	1;
    }) {
	print "1..0 # skip no Test::More and/or LWP::UserAgent module\n";
	exit;
    }
}

use CGI;
use Getopt::Long;

use BBBikeTest qw(check_cgi_testing);

check_cgi_testing;

my $cgi_dir = $ENV{BBBIKE_TEST_CGIDIR} || "http://localhost/bbbike/cgi";
my $html_dir = $ENV{BBBIKE_TEST_HTMLDIR};

if (!GetOptions("cgidir=s" => \$cgi_dir,
		"htmldir=s" => \$html_dir,
	       )) {
    die "usage: $0 [-cgidir url] [-htmldir url]";
}

if (!defined $html_dir) {
    $html_dir = dirname $cgi_dir;
}

my @prog = qw(
	      bbbike.cgi
	      bbbike.en.cgi
	      bbbike2.cgi
	      bbbike2.en.cgi
	      mapserver_address.cgi
	      mapserver_comment.cgi
	      bbbike-data.cgi
	      bbbike-snapshot.cgi
	      bbbikegooglemap.cgi
	     );
if ($cgi_dir !~ m{\Qbbbike.hosteurope.herceg.de}) {
    push @prog, "bbbikegooglemap2.cgi";
}
if ($ENV{BBBIKE_LONG_TESTS}) {
    push @prog, 'wapbbbike.cgi';
}

use constant HARD_TIMEOUT => 30;
use constant DEFAULT_SOFT_TIMEOUT => 10;

# URLs which are sometimes slower than the rest,
# use possible maximum
my %prog2timeout = (qr{bbbike-(data|snapshot)\.cgi} => HARD_TIMEOUT);

my @static = qw(
		html/bbbike.css
		html/bbbikepod.css
		html/bbbikeprint.css
		html/bbbike_start.js
		html/bbbike_result.js
		html/pleasewait.html
		html/presse.html
		images/bg.jpg
		images/abc.gif
		images/ubahn.gif
	       );

use vars qw($mapserver_prog_url);
$mapserver_prog_url = $ENV{BBBIKE_TEST_MAPSERVERURL};
if (!defined $mapserver_prog_url) {
    do "$FindBin::RealBin/../cgi/bbbike.cgi.config";
}
if (defined $mapserver_prog_url) {
    push @prog, $mapserver_prog_url;
} else {
    diag("No URL for mapserv defined");
}

my $per_check_url_test_cases = 2;
my $extra_tests = 7;
plan tests => (scalar(@prog) + scalar(@static)) * $per_check_url_test_cases + $extra_tests;

# Note: in keep_alive connections it's not possible to change the
# timeout, thus we have the maximum specified here, and working
# with "soft timeouts" later.
my $ua = LWP::UserAgent->new(keep_alive => 1, timeout => HARD_TIMEOUT);
$ua->agent('BBBike-Test/1.0');
$ua->env_proxy;

delete $ENV{PERL5LIB}; # override Test::Harness setting
for my $prog (@prog) {
    my $qs = "";
    if ($prog =~ /mapserver_comment/) {
	$qs = "?" . CGI->new({comment=>"cgihead test",
			      subject=>"TEST IGNORE הצü",
			     })->query_string;
    }
    my $absurl = ($prog =~ /^http:/ ? $prog : "$cgi_dir/$prog");
    check_url("$absurl$qs", $prog);
}

for my $static (@static) {
    my $url = "$html_dir/$static";
    check_url($url);
}

# Check for Bot traps
{
    my $java_ua = LWP::UserAgent->new(keep_alive => 1);
    $java_ua->agent('Java/1.6.0_06 BBBike-Test/1.0');
    $java_ua->env_proxy;
    $java_ua->requests_redirectable([]);
    { # Redirect on start page
	my $resp = $java_ua->get("$cgi_dir/bbbike.cgi");
	is($resp->code, 302, 'Found redirect for Java bot');
	like($resp->header('location'), qr{/html/bbbike_small});
    }
    { # But allow for direct access (which bots do not do)
	my $resp = $java_ua->get("$cgi_dir/bbbike.cgi?info=1");
	is($resp->code, 200);
    }
}

# Typically two test cases, except for bbbike-data/snapshot
sub check_url {
    my($url) = @_;

    my $soft_timeout = DEFAULT_SOFT_TIMEOUT;
    for my $rx (keys %prog2timeout) {
	if ($url =~ $rx) {
	    $soft_timeout = $prog2timeout{$rx};
	    last;
	}
    }

    my $t0 = time;
    my $resp = $ua->head($url);
    my $t1 = time;
    ok($resp->is_success, $url) or diag $resp->content;
    {
	my $dt = $t1-$t0;
	cmp_ok $dt, "<=", $soft_timeout, "Request to $url was fast enough";
    }

    if ($url =~ /bbbike-data.cgi/) {
	is($resp->header('content-type'), "application/zip", "Expected mime-type for bbbike-data.cgi");
	like($resp->header("content-disposition"), qr{^attachment;\s*filename=bbbike_data.*\.zip$}, "Expected attachment marker");
    } elsif ($url =~ /bbbike-snapshot.cgi/) {
	like($resp->header('content-type'), qr{^( application/zip          # old bbbike-snapshot.cgi implementation and old github
					       |  application/octet-stream # new github redirect to codeload
					       )$}x, "Expected mime-type for bbbike-shapshot.cgi");
	like($resp->header("content-disposition"), qr{^attachment;\s*filename=(
							bbbike_snapshot_\d+\.zip # old bbbike-snapshot.cgi implementation in bbbike-data.cgi
						      | bbbike-master\.zip       # redirect to github
						      )$}x, "Expected attachment marker");

    }
}

__END__
