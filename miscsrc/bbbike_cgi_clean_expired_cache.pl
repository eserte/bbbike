#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2013 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use Getopt::Long;
use LWP::UserAgent;

my $host = "bbbike.de";
my $doit = 1;
GetOptions(
	   "host=s" => \$host,
	   "n" => sub { $doit = 0 },
	  )
    or die "usage: $0 [-host ...] [-n]";

my @cgis = qw(bbbike.cgi bbbike2.cgi bbbike.en.cgi bbbike2.en.cgi);
my $ua = LWP::UserAgent->new;
$ua->agent($ua->_agent . " (BBBike-Tools)");

my $has_errors = 0;

for my $cgi (@cgis) {
    my $url = 'http://' . $host . '/cgi-bin/' . $cgi . '?clean_expired_cache=1';
    print STDERR "$url... ";
    if ($doit) {
	my $resp = $ua->get($url);
	if (!$resp->is_success) {
	    $has_errors++;
	    print STDERR "(no success)";
	}
	print STDERR "\n";
	for my $line (split /\n/, $resp->content) {
	    print STDERR "  $line\n";
	}
    } else {
	print STDERR "(dry run mode)\n";
    }
}

exit($has_errors ? 1 : 0);

__END__
