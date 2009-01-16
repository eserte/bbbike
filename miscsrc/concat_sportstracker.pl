#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: concat_sportstracker.pl,v 1.1 2009/01/16 22:07:28 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2008 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Concatenate a number of Nokia Sports Tracker files together. Note
# that only data relevant for plotting (e.g. with the "Draw gpsman
# data" menu entry in the bbbike application) or for use with
# GPS::GpsmanData::Any is preserved. Also, only the first activity
# entry is preserved. This means that the result won't validate
# against the sportstracker_1_82.rnc schema (which isn't official,
# anyway)

use strict;
use XML::LibXML;

my @files = @ARGV;
print qq{<?xml version="1.0" encoding="UTF-8"?><workout>\n};
my $has_activity_node;
for my $file (@files) {
    my $root = XML::LibXML->new->parse_file($file)->documentElement;
    if (!$has_activity_node) {
	print $_->serialize for $root->findnodes("/workout/activity");
	$has_activity_node = 1;
    }
    print "<events>\n";
    for my $event_node ($root->findnodes("/workout/events/event")) {
	print $event_node->serialize;
    }
    print "</events>\n";
    print "<eventlocations>\n";
    for my $eventlocation_node ($root->findnodes("/workout/eventlocations/eventlocation")) {
	print $eventlocation_node->serialize;
    }
    print "</eventlocations>\n";
}
print "</workout>";


__END__
