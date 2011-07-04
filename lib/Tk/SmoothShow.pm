# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2009,2011 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Tk::SmoothShow;

use strict;
use vars qw($VERSION);
$VERSION = '1.03';

use Time::HiRes qw(time);

sub show {
    my($f, %args) = @_;
    return if !Tk::Exists($f);
    if (!$f->manager) {
	$f->place(-x => 0, -y => 0, -relwidth => 1, -height => 0);
    }
    return if ($f->height >= $f->reqheight);

    my $speed = delete $args{-speed} || 200; # px per second
    my $wait  = delete $args{-wait}  || 10;  # miliseconds
    my $completecb = delete $args{-completecb};
    die "Unhandled arguments: " . join(" ", %args) if %args;

    my $start_time = time;

    my $increase;
    $increase = sub {
	return if !Tk::Exists($f);
	my $delta = time - $start_time;
	my $new_height = int($speed * $delta);
	$new_height = $f->reqheight if $new_height > $f->reqheight;
	$f->place(-height => $new_height);
	if ($new_height < $f->reqheight) {
	    $f->after($wait, $increase);
	} else {
	    $completecb->($f) if $completecb;
	}
    };

    $f->after($wait, $increase);
}

sub hide {
    my($f, %args) = @_;
    return if !Tk::Exists($f);
    return if !$f->manager;
    return if $f->height <= 0;

    my $speed = delete $args{-speed} || 200; # px per second
    my $wait  = delete $args{-wait}  || 10;  # miliseconds
    my $completecb = delete $args{-completecb};
    die "Unhandled arguments: " . join(" ", %args) if %args;

    my $start_time = time;
    my $start_height = $f->height;

    my $decrease;
    $decrease = sub {
	return if !Tk::Exists($f);
	my $delta = time - $start_time;
	my $new_height = $start_height - int($speed * $delta);
	$new_height = 0 if $new_height < 0;
	$f->place(-height => $new_height);
	if ($new_height > 0) {
	    $f->after($wait, $decrease);
	} else {
	    $f->update; # needed for slow systems, other $f->height is not updated, it seems
	    $f->placeForget;
	    $completecb->($f) if $completecb;
	}
    };

    $f->after($wait, $decrease);
}

1;

__END__
