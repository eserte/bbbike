#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: cgihead.t,v 1.6 2003/11/17 07:21:05 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;

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

if (!GetOptions("cgidir=s" => \$cgi_dir,
	       )) {
    die "usage: $0 [-cgidir url]";
}

my @prog = qw(bbbike.cgi
	      mapserver_address.cgi
	      mapserver_comment.cgi
	      wapbbbike.cgi
	     );

use vars qw($mapserver_prog_url);
do "$FindBin::RealBin/../cgi/bbbike.cgi.config";
if (defined $mapserver_prog_url) {
    push @prog, $mapserver_prog_url;
} else {
    diag("No URL for mapserv defined");
}

plan tests => scalar @prog;

delete $ENV{PERL5LIB}; # override Test::Harness setting
for my $prog (@prog) {
    my $qs = "";
    if ($prog =~ /mapserver_comment/) {
	$qs = "?comment=cgihead+test";
    }
    my $absurl = ($prog =~ /^http:/ ? $prog : "$cgi_dir/$prog");
    (my $safefile = $prog) =~ s/[^A-Za-z0-9._-]/_/g;
    system("HEAD -H 'User-Agent: BBBike-Test/1.0' $absurl$qs > /tmp/head.$safefile.log");
    is($?, 0, $absurl);
}


__END__
