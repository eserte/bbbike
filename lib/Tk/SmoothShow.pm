# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2009 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Tk::SmoothShow;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

sub show {
    my($f, $delta, $wait) = @_;
    return if !Tk::Exists($f);
    if (!$f->manager) {
	$f->place(-x => 0, -y => 0, -relwidth => 1, -height => 0);
    }
    return if ($f->height >= $f->reqheight);

    $delta = 2 if !$delta;
    $wait = 10 if !$wait;

    my $increase;
    $increase = sub {
	my($new_height) = @_;
	return if !Tk::Exists($f);
	$new_height = $f->reqheight if $new_height > $f->reqheight;
	$f->place(-height => $new_height);
	if ($new_height < $f->reqheight) {
	    $f->after($wait, sub { $increase->($new_height+$delta) });
	}
    };

    $f->after($wait, sub { $increase->($f->height+$delta) });
}

sub hide {
    my($f, $delta, $wait) = @_;
    return if !Tk::Exists($f);
    return if !$f->manager;
    return if $f->height <= 0;

    $delta = 2 if !$delta;
    $wait = 10 if !$wait;

    my $decrease;
    $decrease = sub {
	my($new_height) = @_;
	return if !Tk::Exists($f);
	$new_height = 0 if $new_height < 0;
	$f->place(-height => $new_height);
	if ($new_height > 0) {
	    $f->after($wait, sub { $decrease->($new_height-$delta) });
	} else {
	    $f->placeForget;
	}
    };

    $f->after($wait, sub { $decrease->($f->height-$delta) });
}

1;

__END__
