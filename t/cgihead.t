#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: cgihead.t,v 1.2 2003/06/23 22:04:48 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use Test;

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "1..0 # skip: no Test module\n";
	exit;
    }
}

use Getopt::Long;
my $cgi_dir = "http://localhost/~eserte/bbbike/cgi";

if (!GetOptions("cgidir=s" => \$cgi_dir,
	       )) {
    die "usage: $0 [-cgidir url]";
}

my @prog = qw(bbbike.cgi
	      mapserv
	      mapserver_address.cgi
	      mapserver_comment.cgi
	      wapbbbike.cgi
	     );

plan tests => scalar @prog;

for my $prog (@prog) {
    my $qs = "";
    if ($prog =~ /mapserver_comment/) {
	$qs = "?comment=cgihead+test";
    }
    system("HEAD -H 'User-Agent: BBBike-Test/1.0' $cgi_dir/$prog$qs > /tmp/head.$prog.log");
    ok($?, 0, "$cgi_dir/$prog");
}


__END__
