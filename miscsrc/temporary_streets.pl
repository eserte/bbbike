#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: temporary_streets.pl,v 1.2 2001/12/15 00:18:17 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven.rezic@berlin.de
# WWW:  http://www.rezic.de/eserte/
#

# Narrow the list to only temporary parts which are separated by:
# # temporary:
# ...
# # ^

my @files = @ARGV;
die "No files" if !@files;

foreach my $file (@files) {

    my $temporary = 0;

    open(F, $file) or die $!;
    while(<F>) {
	if ($temporary) {
	    if (/^\#\s+\^/) {
		$temporary = 0;
	    } else {
		print $_;
	    }
	} elsif (/^\#\s+temporary\:/) {
	    $temporary = 1;
	}
    }
    close F;

    if ($temporary) {
	warn "Temporary opened in $file but not closed\n";
    }
}

__END__
