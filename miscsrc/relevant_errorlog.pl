#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2011 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use Fatal qw(open close);

my $file = shift || "cat /var/log/apache2/bbbike.de_error.log-???????? /var/log/apache2/bbbike.de_error.log|";

open my($fh), $file;
while(<$fh>) {
    m{File does not exist: } and next;
    m{attempt to invoke directory as script: } and next;
    m{script not found or unable to stat: } and next;
    s{ \[error\] }{ };
    s{ \[client 127\.0\.0\.1\] }{ };
    if (m{bbbike-snapshot-debug\.cgi: .*?(\S+)$}) {
	my $req_duration = $1;
	if ($req_duration < 30) { # ca. 35s is the perlbal limit, which is quite critical
	    next;
	}
    }
    print;
}
close $fh;

__END__
