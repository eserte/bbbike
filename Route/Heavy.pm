# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2002,2009,2018 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.de
#

package Route::Heavy;

use Route;

use vars qw($VERSION);
$VERSION = '1.10';

package Route;

use strict;

# XXX Msg.pm

sub as_strassen {
    my($self_or_file, %args) = @_;

    my $name = delete $args{name} || "Route";
    my $cat  = delete $args{cat}  || "#ff0000";

    require Strassen::Core;

    my $realcoords_ref;
    if (ref $self_or_file && $self_or_file->isa('Route')) {
	$realcoords_ref = $self_or_file->path;
    } else {
	my $in_file = $self_or_file;
	$args{'-fuzzy'} = delete $args{'fuzzy'};
	my $ret = Route::load($in_file, undef, %args);
	if (!$ret) {
	    die "Die Datei <$in_file> enthält keine Route";
	}

	$realcoords_ref = $ret->{RealCoords};
    }

    my $s = Strassen->new_from_data
	(@$realcoords_ref
	 ?
	 $name . "\t" . $cat . " " .
	 join(" ", map { $_->[0].",".$_->[1] } @$realcoords_ref) .
	 "\n"
	 :
	 ""
	);
	 
    $s;
}

sub new_from_strassen {
    my($class, $s) = @_;
    my @realcoords;
    $s->init;
    my $convsub = $s->get_conversion(-tomap => 'standard');
    while(1) {
	my $r = $s->next;
	my @c = @{ $r->[Strassen::COORDS()] };
	last if !@c;
	if ($convsub) {
	    @c = map { join(",", split(/,/, $convsub->($_))) } @c;
	}
	if (@realcoords && join(",",@{$realcoords[-1]}) eq $c[-1]) {
	    shift @c;
	}
	push @realcoords, map { [ split /,/ ] } @c;
    }
    Route->new_from_realcoords(\@realcoords);
}

sub load_from_string {
    my($string, @args) = @_;
    require File::Temp;
    my($fh, $file) = File::Temp::tempfile(UNLINK => !$Route::DEBUG)
	or die "Can't create temporary file: $!";
    print $fh $string;
    close $fh;
    my $ret = Route::load($file, @args);
    unlink $file if !$Route::DEBUG;
    $ret;    
}

sub get_bbox {
    my($coordref) = @_;
    my($x1,$y1,$x2,$y2);
    for my $coord (@$coordref) {
	my($x,$y) = @$coord;
	$x1 = $x if !defined $x1 || $x1 > $x;
	$x2 = $x if !defined $x2 || $x2 < $x;
	$y1 = $y if !defined $y1 || $y1 > $y;
	$y2 = $y if !defined $y2 || $y2 < $y;
    }
    ($x1,$y1,$x2,$y2);
}

1;

__END__
