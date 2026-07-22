#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 $FindBin::RealBin,
	);

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

use BBBikeTest qw(image_ok);

plan 'no_plan';

chdir "$FindBin::RealBin/../images" or die $!;
for (glob("*.*")) {
    next if /\.(svg|xcf)$/;
    next if /\.xpm$/; # XXX xpmtoppm cannot handle the color "opaque"
    SKIP: {
        if ($_ eq 'px_1t.gif' && should_skip_px_1t_gif()) {
            Test::More::skip("px_1t.gif fails with problematic libgif7 version", 2);
        }
        image_ok($_, $_);
    }
}

sub should_skip_px_1t_gif {
    my $libgif_version = `dpkg-query -W -f='\${Version}' libgif7 2>/dev/null`;
    if (defined $libgif_version && length $libgif_version) {
        chomp $libgif_version;
        my $rc = system('dpkg', '--compare-versions', $libgif_version, 'ge', '5.2.2-1ubuntu1.2');
        if ($rc == 0) {
            return 1;
        }
    }
    return 0;
}

__END__
