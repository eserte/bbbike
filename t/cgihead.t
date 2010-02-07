#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: cgihead.t,v 1.20 2009/02/25 23:46:23 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;
use File::Basename;

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
	      wapbbbike.cgi
	      bbbike-data.cgi
	      bbbike-snapshot.cgi
	      bbbikegooglemap.cgi
	     );
if ($cgi_dir !~ m{(bbbike.hosteurope|radzeit)\Q.herceg.de}) {
    push @prog, "bbbikegooglemap2.cgi";
}

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

my $extra_tests = 7;
plan tests => scalar(@prog) + scalar(@static) + $extra_tests;

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
    my $java_ua = LWP::UserAgent->new;
    $java_ua->agent('Java/1.6.0_06 BBBike-Test/1.0');
    $java_ua->requests_redirectable([]);
    { # Redirect on start page
	my $resp = $java_ua->get("$cgi_dir/bbbike.cgi");
	is($resp->code, 302, 'Found redirect for Java bot');
	like($resp->header('location'), qr{BBBike/html/bbbike_small});
    }
    { # But allow for direct access (which bots do not do)
	my $resp = $java_ua->get("$cgi_dir/bbbike.cgi?info=1");
	is($resp->code, 200);
    }
}

sub check_url {
    my($url, $prog) = @_;
    if (!defined $prog) {
	$prog = basename $url;
    }
    (my $safefile = $prog) =~ s/[^A-Za-z0-9._-]/_/g;
    my $ua = LWP::UserAgent->new;
    $ua->agent('BBBike-Test/1.0');
    my $resp = $ua->head($url);
    ok($resp->is_success, $url) or diag $resp->content;

    if ($url =~ /bbbike-data.cgi/) {
	is($resp->content_type, "application/zip", "Expected mime-type for bbbike-data.cgi");
	like($resp->header("content-disposition"), qr{^attachment;\s*filename=bbbike_data.*\.zip$}, "Expected attachment marker");
    } elsif ($url =~ /bbbike-snapshot.cgi/) {
	is($resp->content_type, "application/zip", "Expected mime-type for bbbike-shapshot.cgi");
	like($resp->header("content-disposition"), qr{^attachment;\s*filename=bbbike_snapshot_\d+\.zip$}, "Expected attachment marker");
    }
}

__END__
