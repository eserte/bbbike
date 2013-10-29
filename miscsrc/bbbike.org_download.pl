#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2011,2012,2013 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 $FindBin::RealBin,
	);

use Getopt::Long;

use BBBikeOrgDownload;

sub usage ();

our $VERSION = '0.03';

my $url;
my $city;
my $o;
my $agent_suffix;
my $debug = 0;

GetOptions(
	   "url=s" => \$url,
	   "debug!" => \$debug,
	   "city=s" => \$city,
	   "o=s" => \$o, # download directory, for tests only
	   "agentsuffix=s" => \$agent_suffix, # for tests only
	  )
    or usage;
@ARGV and usage;

my $bod = BBBikeOrgDownload->new(
				 agentsuffix => $agent_suffix,
				 downloaddir => $o,
				 url         => $url,
				 debug       => $debug,
				);

if (!$city) {
    my @cities = $bod->listing();
    for (@cities) { print $_, "\n" }
} else {
    $bod->get_city($city);
}

sub usage () {
    die <<EOF;
usage: $0 [-url ...] [-city ...]
EOF
}

__END__
