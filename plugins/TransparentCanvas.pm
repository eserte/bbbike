# -*- perl -*-

#
# $Id: TransparentCanvas.pm,v 1.8 2007/10/14 20:19:47 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2006 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Description (en): Experimental: make BBBike canvas transparent
# Description (de): Experimentell: transparente BBBike-Karte erzeugen
package TransparentCanvas;

use BBBikePlugin;
push @ISA, 'BBBikePlugin';

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

use X11::Protocol;

our $shape_pixmap;

sub register {
    my $top = $main::top;
    if ($Tk::platform eq 'MSWin32') {
	my $warntext = "TransparentCanvas is not usable under Windows platform";
	if ($main::booting) {
	    warn $warntext;
	} else {
	    main::status_message($warntext, "warn");
	}
    } else {
	$top->bind("<Control-t>" => sub { doit() });
	$top->bind("<Control-T>" => sub { remove() });
	if (!$main::booting) {
	    $top->messageBox(-title => "Info",
			     -icon => "info",
			     -message => "C-t: Make transparent\nS-C-t: Remove transparency\nKey commands may also be used in the header area",
			    );
	}
    }
}

sub remove {
    my $x11 = new X11::Protocol;
    $x11->init_extension('SHAPE')
	or main::status_message("SHAPE extension not available", "die");
    my $top = $main::top;
    my($wrapper) = $top->wrapper;
    if ($shape_pixmap) {
	$x11->FreePixmap($shape_pixmap);
	undef $shape_pixmap;
    }
    $x11->ShapeMask($wrapper, 'Bounding', 'Set', 0, 0, "None");
}

sub doit {
    my $x11 = new X11::Protocol;
    $x11->init_extension('SHAPE')
	or main::status_message("SHAPE extension not available", "die");

    my $c = $main::c;
    my $top = $main::top;
    my($wrapper) = $top->wrapper;
    my $transbg = "\xd6\xd7\xd6";
    my $transbg2 = "\xd6\xda\xd6"; # requested canvas background is not equal to the visible!
    my $transbg3 = "\xd7\xdb\xd7"; # slightly different color, seen with xorg on FreeBSD 7
    my $id = $c->id;

    if ($shape_pixmap) {
	$x11->FreePixmap($shape_pixmap);
	undef $shape_pixmap;
    }

    my $top_width = $top->width;
    my $top_height = $top->height;
    my $c_x = $c->rootx - $top->rootx;
    my $c_y = $c->rooty - $top->rooty;

    # menu height is not included:
    my(undef, $menu_height) = $top->wrapper;
    $top_height+=$menu_height;
    $c_y+=$menu_height;

    $shape_pixmap = $x11->new_rsrc;
    $x11->CreatePixmap($shape_pixmap, $wrapper, 1, $top_width, $top_height);
    my $gc = $x11->new_rsrc;
    $x11->CreateGC($gc, $shape_pixmap, 'foreground' => $x11->white_pixel);
    my $delgc = $x11->new_rsrc;
    $x11->CreateGC($delgc, $shape_pixmap, 'foreground' => $x11->black_pixel);

    # Toplevel is visible
    $x11->PolyFillRectangle($shape_pixmap, $gc,
			    [(0, 0), $top_width, $top_height]);

    $x11->ShapeMask($wrapper, 'Bounding', 'Set', 0, 0, $shape_pixmap);

    # Silly method to force a Canvas update. Just update does not do...
    $c->move("all", 1, 1);
    $top->update;
    $c->move("all", -1, -1);
    $top->update;

    my $tmpfile1 = "/tmp/transparent_canvas_".$<.".xwd";
    my $tmpfile2 = "/tmp/transparent_canvas_".$<.".ppm";

    unlink $tmpfile1;
    unlink $tmpfile2;
    {
	my $cmd = "xwd -id $id > $tmpfile1";
	system $cmd;
	$? == 0 or main::status_message("Failure while running <$cmd>: $?", "die");
    }
    {
	my $cmd = "convert $tmpfile1 $tmpfile2";
	system $cmd;
	$? == 0 or main::status_message("Failure while running <$cmd>: $?", "die");
    }
    open my $fh, $tmpfile2
	or main::status_message("Can't write to $tmpfile2: $!", "die");
    binmode $fh;
    my %imgmeta;
    my($width, $height);
    my $state = "fmt";
    while(!eof $fh) {
	chomp(my $line = <$fh>);
	next if $line =~ /^\#/;
	$imgmeta{$state} = $line;
	if ($state eq 'fmt') {
	    if ($imgmeta{fmt} ne "P6") {
		main::status_message("Supports only P6 (ppm binary), not $imgmeta{fmt}", "die");
	    }
	    $state = "wh";
	} elsif ($state eq 'wh') {
	    ($width, $height) = split / /, $imgmeta{wh};
	    $state = "maxval";
	} elsif ($state eq 'maxval') {
	    if ($imgmeta{maxval} ne 255) {
		main::status_message("Supports only maxval=255", "die");
	    }
	    last;
	}
    }

    # Canvas is invisible by default
    $x11->PolyFillRectangle($shape_pixmap, $delgc,
			    [($c_x, $c_y), $width, $height]);

    local $/ = \3;
    my $x = 0;
    my $y = 0;
    my @p;
    while(<$fh>) {
	if ($_ ne $transbg && $_ ne $transbg2 && $_ ne $transbg3) {
	    push @p, $x+$c_x, $y+$c_y;
	    if (scalar @p > 10000) {
		$x11->PolyPoint($shape_pixmap, $gc, 'Origin', @p);
		@p = ();
	    }
	}
	$x++;
	if ($x>=$width) {
	    $x = 0;
	    $y++;
	}
    }
    $x11->PolyPoint($shape_pixmap, $gc, 'Origin', @p);

    $x11->ShapeMask($wrapper, 'Bounding', 'Set', 0, 0, $shape_pixmap);
}

# REPO BEGIN
# REPO NAME tk_sleep /home/e/eserte/work/srezic-repository 
# REPO MD5 2fc80d814604255bbd30931e137bafa4

=head2 tk_sleep

=for category Tk

    $top->tk_sleep($s);

Sleep $s seconds (fractions are allowed). Use this method in Tk
programs rather than the blocking sleep function. The difference to
$top->after($s/1000) is that update events are still allowed in the
sleeping time.

=cut

sub tk_sleep {
    my($top, $s) = @_;
    my $sleep_dummy = 0;
    $top->after($s*1000,
                sub { $sleep_dummy++ });
    $top->waitVariable(\$sleep_dummy)
	unless $sleep_dummy;
}
# REPO END

1;

__END__
