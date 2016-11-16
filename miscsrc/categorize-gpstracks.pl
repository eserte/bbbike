#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2016 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;

my @line_defs =
    (
     { rx => qr{\((?:car|bus|tram)},                           type => 'Car',   dash => '8.3' },
     { rx => qr{\((?:plane)},                                  type => 'Plane', dash => '1,4' },
     { rx => qr{\((?:ship|ferry)},                             type => 'Ship',  dash => '2,8' },
     { rx => qr{\((?:train|s-bahn|u-bahn|draisine|funicular)}, type => 'Train', dash => '3,8' },
     { rx => qr{\((?:pedes)},                                  type => 'Pedes', dash => '8,3,8,6' },
     { rx => qr{\.trk\t},                                      type => 'Uncat' },
    );

print "#: line_color: #c000c0\n";
for my $oldspec ('', 'Old') {
    for my $line_def (@line_defs) {
	my($type, $dash) = @{$line_def}{qw(type dash)};
	if (defined $dash) {
	    print "#: line_dash.GPSs$type$oldspec: $dash\n";
	}
    }
}
for my $oldspec ('Old') {
    for my $line_def (@line_defs) {
	my $type = $line_def->{type};
	print "#: line_color.GPSs$type$oldspec: #a0a030\n";
    }
}
print "#:\n";

while(<STDIN>) {
    my $cat = '';
 LINE_DEF: for my $line_def (@line_defs) {
	if ($_ =~ $line_def->{rx}) {
	    $cat = $line_def->{type};
	    last LINE_DEF;
	}
    }
    my $oldspec = (m{^200[0-7]} ? 'Old' : '');
    s{\tGPSs}{\tGPSs$cat$oldspec};
    print $_;
}

__END__

=head1 NAME

categorize-gpstracks.pl - add color and dash pattern to bbd files containing GPS tracks

=head1 SYNOPSIS

    categorize-gpstracks.pl < in.bbd > out.bbd

=cut
