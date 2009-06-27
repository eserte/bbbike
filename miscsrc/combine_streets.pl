#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: combine_streets.pl,v 1.16 2008/05/18 16:01:51 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999,2001,2002,2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net/
#

=head1 NAME

combine_streets.pl - combine streets

=head1 AUTHOR

Slaven Rezic <slaven.rezic@berlin.de>

=head1 COPYRIGHT

Copyright (c) 1999,2001 Slaven Rezic. All rights reserved.
This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Strassen::Combine>

=cut

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data",
	 );
use Strassen;
use Strassen::Combine;
use strict;
use Getopt::Long;

my $make_closed_polygon;
my $combine_same_streets;
my $encoding;
if (!GetOptions("closedpolygon!" => \$make_closed_polygon,
		"samestreets!" => \$combine_same_streets,
		"encoding=s" => \$encoding,
	       )) {
    die <<EOF;
    usage: $0 [-closedpolygon] [-samestreets] [-encoding encoding] bbdfile
EOF
}

my $strfile = shift;
if ($combine_same_streets) {
    combine_same_streets($strfile);
} else {
    make_long_streets($strfile);
}

sub make_long_streets {
    my $strfile = shift || die "Name der Straßen-Datei?";

    my $tmpfile;
    if ($strfile eq '-') {
	require POSIX;
	$tmpfile = POSIX::tmpnam();
	open(TMP, ">$tmpfile") or die "Can't write to $tmpfile: $!";
	while (<STDIN>) {
	    print TMP $_;
	}
	close TMP;
	$strfile = $tmpfile;
    }

    my $s = Strassen->new($strfile);
    my $out = $s->make_long_streets;
    $out->set_global_directives({ encoding => [$encoding] }) if $encoding;
    $out->write("-");
}

sub combine_same_streets {
    my $strfile = shift || die "strfile?";
    my $s = Strassen->new($strfile);
    my $out = $s->combine_same_streets;
    $out->write("-");
}

__END__
