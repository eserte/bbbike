#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2026 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# WWW:  https://github.com/eserte/bbbike
#

use strict;
use warnings;
use FindBin;
use lib "$FindBin::RealBin/..", "$FindBin::RealBin/../lib";

use CGI ();

use BBBikeCGI::Util;

my $bbbike_cgi = "$FindBin::RealBin/bbbike.cgi";

my $q = CGI->new;
my @points = BBBikeCGI::Util::my_multi_param($q, 'point');
if (@points != 2) {
    cgi_error('Expected exactly two point parameters, got ' . scalar @points);
}

my $qq = CGI->new('');
$qq->param('startc_wgs84', swap_latlon($points[0]));
$qq->param('zielc_wgs84', swap_latlon($points[0]));
$qq->param('output_as', 'gpx-route');
$qq->param('pref_seen', 1);
$qq->param('appid', 'osmand-custom-1');
for my $key ($q->param) {
    if ($key eq 'pref_seen') {
	# handled by this script
    } elsif ($key =~ /^pref_/) {
	for my $val (BBBikeCGI::Util::my_multi_param($q, $key)) {
	    $qq->param($key, $val);
	}
    }
}

$ENV{QUERY_STRING} = $qq->query_string;
exec $bbbike_cgi;

sub cgi_error {
    my $message = shift;
    print $q->header(
	-status => '400 Bad Request',
	-type => 'text/html',
    );
    print $message;
    exit 0;
}

sub swap_latlon {
    my $latlon = shift;
    my($lat,$lon) = split /,/, $latlon;
    join ',', $lon, $lat;
}

__END__
