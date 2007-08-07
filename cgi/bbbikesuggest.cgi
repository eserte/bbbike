#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbbikesuggest.cgi,v 1.1 2007/08/07 22:35:35 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2007 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use CGI qw(:standard);
use FindBin;

my $str = lc param("str");
open my $fh, "-|", "grep", "-i", "^".$str, "$FindBin::RealBin/../data/Berlin.coords.data" or die $!;
print header;
print "<html><body>";
my $i = 0;
my $last;
while(<$fh>) {
    chomp;
    my($s) = split /\|/, $_;
    next if defined $last && $s eq $last;
    print CGI::escapeHTML($s) . "<br>";
    $last = $s;
    last if $i++ > 100;
}
print "</body></html>";

__END__
