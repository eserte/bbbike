#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: cgihead.t,v 1.10 2004/05/10 07:03:22 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;
use File::Basename;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip: no Test::More module\n";
	exit;
    }
}

use Getopt::Long;
my $cgi_dir = $ENV{BBBIKE_TEST_CGIDIR} || "http://localhost/~eserte/bbbike/cgi";
my $html_dir = $ENV{BBBIKE_TEST_HTMLDIR};

if (!GetOptions("cgidir=s" => \$cgi_dir,
	       )) {
    die "usage: $0 [-cgidir url]";
}

if (!defined $html_dir) {
    $html_dir = dirname $cgi_dir;
}

my @prog = qw(bbbike.cgi
	      mapserver_address.cgi
	      mapserver_comment.cgi
	      wapbbbike.cgi
	     );

my @static = qw(html/bbbike.css
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

plan tests => scalar @prog + scalar @static;

delete $ENV{PERL5LIB}; # override Test::Harness setting
for my $prog (@prog) {
    my $qs = "";
    if ($prog =~ /mapserver_comment/) {
	$qs = "?comment=cgihead+test;subject=TEST+IGNORE";
    }
    my $absurl = ($prog =~ /^http:/ ? $prog : "$cgi_dir/$prog");
    check_url("$absurl$qs", $prog);
}

for my $static (@static) {
    my $url = "$html_dir/$static";
    check_url($url);
}

sub check_url {
    my($url, $prog) = @_;
    if (!defined $prog) {
	$prog = basename $url;
    }
    (my $safefile = $prog) =~ s/[^A-Za-z0-9._-]/_/g;
    system("HEAD -H 'User-Agent: BBBike-Test/1.0' '$url' > /tmp/head.$safefile.log");
    is($?, 0, $url);
}

__END__
