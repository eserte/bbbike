# -*- perl -*-

#
# $Id: Wbmp.pm,v 1.2 2001/01/17 01:18:57 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2000 Online Office Berlin. All rights reserved.
# Large parts from wbmp.c from gd 1.8.3 converted to perl.
#
# Mail: info@onlineoffice.de
# WWW:  http://www.onlineoffice.de
#

package GD::Wbmp;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

use constant WBMP_WHITE => 1;
use constant WBMP_BLACK => 0;

sub write {
    my($gd_image, $fg) = @_;

    # create the WBMP
    my($width, $height) = $gd_image->getBounds;
    my $wbmp = createwbmp($width, $height, WBMP_WHITE);
    if (!$wbmp) {
	die "Could not create WBMP";
    }

    # fill up the WBMP structure
    my $pos = 0;
    for(my $y=0; $y<$height; $y++) {
	for(my $x=0; $x<$width; $x++) {
	    if ($gd_image->getPixel($x, $y) == $fg) {
		$wbmp->{Bitmap}[$pos] = WBMP_BLACK;
	    }
	    $pos++;
	}
    }

    # write the WBMP as a string
    writewbmp($wbmp);

}

sub createwbmp {
    my($width, $height, $color) = @_;

    my $wbmp = {Bitmap => [],
		Width  => $width,
		Height => $height,
	       };

    for (my $i = 0; $i<$width*$height; $wbmp->{Bitmap}[$i++] = $color) {}

    $wbmp;
}

sub writewbmp {
    my($wbmp) = @_;

    my $out_buf = "";

    # Generate the header
    $out_buf .= "\0";         # WBMP Type 0: B/W, Uncompressed bitmap
    $out_buf .= "\0";         # FixHeaderField

    # Size of the image
    my($width, $height) = ($wbmp->{Width}, $wbmp->{Height});
    $out_buf .= putmbi($width);      # width
    $out_buf .= putmbi($height);     # height

    # Image data
    for(my $row=0; $row<$height; $row++) {
        my $bitpos=8;
        my $octet=0;
        for(my $col=0; $col<$width; $col++) {
            $octet |= (($wbmp->{Bitmap}[ $row*$width + $col] == 1)
		       ? WBMP_WHITE
		       : WBMP_BLACK) << --$bitpos;
            if ($bitpos == 0) {
                $bitpos=8;
                $out_buf .= pack("C", $octet);
                $octet=0;
            }
        }
        if ($bitpos != 8) {
	    $out_buf .= pack("C", $octet);
	}
    }

    $out_buf;
}

# putmbi
#
# Put a multibyte intgerer in some kind of output stream
# I work here with a function pointer, to make it as generic
# as possible. Look at this function as an iterator on the
# mbi integers it spits out.
#
sub putmbi {
    my($i) = @_;

    my $out_buf = "";
    my($cnt, $l, $accu);

    # Get number of septets
    $cnt = 0;
    $accu = 0;
    while ( $accu != $i ) {
        $accu += $i & 0x7f << 7*$cnt++;
    }

    # Produce the multibyte output
    for ($l = $cnt-1; $l>0; $l--) {
        $out_buf .= pack("C", 0x80 | ($i & 0x7f << 7*$l ) >> 7*$l);
    }

    $out_buf .= pack("C", $i & 0x7f);
    $out_buf;
}

package GD::Image;

sub wbmp {
    my($image, $fg) = @_;
    GD::Wbmp::write($image, $fg);
}

return 1 if caller();

package main;
require GD;

my $im = new GD::Image(90,50);
my $white = $im->colorAllocate(255,255,255);
my $black = $im->colorAllocate(0,0,0);
$im->rectangle(30,10,60,40, $black);
open(TMP, ">/oo/tmp/test3.wbmp") or die $!;
binmode TMP;
#print TMP $im->png;
print TMP GD::Wbmp::write($im, $black);
close TMP;

__END__

=head1 NAME

GD::Wbmp - compatibility package for older GDs to enable wbmp output

=head1 SYNOPSIS

    use GD;
    use GD::Wbmp;
    $gd->wbmp;

=head1 DESCRIPTION

=head1 AUTHOR

Slaven Rezic - eserte@onlineoffice.de

=head1 SEE ALSO

GD(3).

=cut

