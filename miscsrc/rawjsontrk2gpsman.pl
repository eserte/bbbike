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
use POSIX qw(strftime setlocale LC_TIME);

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
my $ua = $data->{ua};

setlocale(LC_TIME, 'C');

my $tzoffset = strftime('%z', localtime);
if (my($sgn,$h,$m) = $tzoffset =~ m{^([+-])(\d{2})(\d{2})$}) {
    $tzoffset = $h + $m/60;
    $tzoffset *= -1 if $sgn eq '-';
} else {
    warn "Cannot parse tzoffset <$tzoffset>, undefined results follow...";
}

print <<EOF;
% Written by $0 @{[ strftime "%FT%T", localtime ]} (local time)

!Format: DDD $tzoffset WGS 84
!Creation: no

EOF
if ($ua) {
    print <<EOF;
!Uploaded from UA: $ua

EOF
}

print <<EOF;
!T:	ACTIVE LOG
EOF

my $initial_trk_seg = 1;
for my $track_seg (@$track_segs) {
    if (!$initial_trk_seg) {
	print "!TS:\n";
    } else {
	$initial_trk_seg = 0;
    }
    for my $wpt (@$track_seg) {
	my($lat,$lng,$time,$alt,$acc,$altacc) = @{$wpt}{qw(lat lng time alt acc altacc)};
	my $datetime;
	if (defined $time) {
	    $time /= 1000; # ms -> s
	    $datetime = strftime "%d-%b-%Y %H:%M:%S", localtime $time;
	} else {
	    $datetime = '31-Dec-1989 01:00:00';
	}
	$alt = '' if !defined $alt;
	print "\t$datetime\t$lat\t$lng\t$alt\n";
    }
}

__END__

=head1 DESCRIPTION

Convert the bbbikeleaflet.js raw json tracks to gpsman format.

Mass conversion:

    for i in ~/biokovo/src/bbbike/tmp/www/upload-track/*.trk.json; do echo $i; ~/src/bbbike/miscsrc/rawjsontrk2gpsman.pl $i > /tmp/`basename $i`.trk; done 

=head1 TODO

* It seems it's not possible to store acc and altacc in the gpsman
  format. This would only be possible with the gpx format (hdop,
  vdop).

=cut
