#!/usr/local/bin/perl -w
# -*- perl -*-

#
# $Id: cgiinfo.cgi,v 1.1 2003/06/21 14:36:03 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

use CGI;
use URI::Escape;

my $q = new CGI;
print $q->header;
print "<html><head><title>CGIInfo</title>";
print "</head><body>";
if (defined $q->param('reqline') &&
    $q->param('reqline') =~
    /^[^ ]+ ([^ ]+) ([^ ]+) \[([^\]]+)\] \"([^\"]+)\" (\d+) (\d+)/) {
    my($referer, $agent, $date) = ($1, uri_unescape($2), $3);
    my($error, $size) = ($5, $6);
    print "<table>\n";
    print "<tr><td><b>Referer</b></td><td>$referer</td></tr>\n";
    print "<tr><td><b>Agent</b></td><td>$agent</td></tr>\n";
    print "<tr><td><b>Date</b></td><td>$date</td></tr>\n";
    print "<tr><td><b>Error</b></td><td>";
    if ($error >= 400) { print "<font color=\"red\">" }
    elsif ($error >= 300) { print "<font color=\"orange\">" }
    print $error . "</td></tr>\n";
    print "<tr><td><b>Size</b></td><td>$size</td></tr>\n";
    print "</table>";
} else {
    print "Can't parse " . $q->param('reqline') . "<p>";
}
print "</body></html>\n";

__END__
