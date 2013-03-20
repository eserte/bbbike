#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2012,2013 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use JSON::XS qw(decode_json);
use POSIX qw(strftime);

my $file = shift
    or die "File?";

my $data = do {
    open my $fh, $file
	or die "Can't open $file: $!";
    local $/;
    my $buf = <$fh>;
    decode_json $buf;
};

my $track_segs = $data->{trackSegs}
    or die "No trackSegs found in file '$file'";

# XXX Time Offset???
# XXX does it need a track name here?
print <<EOF;
% Written by $0 @{[ strftime "%FT%T", localtime ]} (local time)

!Format: DDD 2 WGS 84
!Creation: no

!T:
EOF

my $initial_trk_seg = 1;
for my $track_seg (@$track_segs) {
    if (!$initial_trk_seg) {
	print "!TS:\n";
    } else {
	$initial_trk_seg = 0;
    }
    for my $wpt (@$track_seg) {
	my($lat,$lng) = @{$wpt}{qw(lat lng)};
	# XXX use timestamp once it is there
	# XXX can we get also the altitude (missing here)?
	print "\t31-Dec-1989 01:00:00\t$lat\t$lng\n";
    }
}

__END__

=pod

Convert the bbbikeleaflet.js raw json tracks to gpsman format.

Mass conversion:

    for i in ~/biokovo/src/bbbike/tmp/www/upload-track/*.trk.json; do echo $i; ~/src/bbbike/miscsrc/rawjsontrk2gpsman.pl $i > /tmp/`basename $i`.trk; done 

See source code for a number of TODOs.

=cut
