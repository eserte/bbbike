#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 1999,2001,2002,2003,2011,2014 Slaven Rezic. All rights reserved.
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

Copyright (c) 1999,2001,2002,2003,2011,2014 Slaven Rezic. All rights reserved.
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
if (!GetOptions("closedpolygon!" => \$make_closed_polygon,
		"samestreets!" => \$combine_same_streets,
	       )) {
    die <<EOF;
    usage: $0 [-closedpolygon] [-samestreets] bbdfile
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
	require File::Temp;
	my $tmpfh;
	($tmpfh,$tmpfile) = File::Temp::tempfile(SUFFIX => "_combine_steeets.bbd", UNLINK => 1)
	    or die "Can't create temporary file: $!";
	while (<STDIN>) {
	    print $tmpfh $_;
	}
	close $tmpfh
	    or die "While writing to temporary file: $!";
	$strfile = $tmpfile;
    }

    my $s = Strassen->new($strfile, UseLocalDirectives => 1);
    my $out = $s->make_long_streets(-closedpolygon => $make_closed_polygon);
    $out->set_global_directives($s->get_global_directives);
    $out->write("-");
}

sub combine_same_streets {
    my $strfile = shift || die "strfile?";
    my $s = Strassen->new($strfile);
    my $out = $s->combine_same_streets;
    $out->set_global_directives($s->get_global_directives);
    $out->write("-");
}

__END__
