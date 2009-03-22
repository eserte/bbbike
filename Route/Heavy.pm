# -*- perl -*-

#
# $Id: Heavy.pm,v 1.9 2006/09/25 22:52:28 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002,2009 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package Route::Heavy;

use Route;

use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.9 $ =~ /(\d+)\.(\d+)/);

package Route;

use strict;

# XXX Msg.pm

sub as_strassen {
    my($self_or_file, %args) = @_;

    my $name = delete $args{name} || "Route";
    my $cat  = delete $args{cat}  || "#ff0000";

    require Strassen;

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
    while(1) {
	my $r = $s->next;
	last if !@{ $r->[Strassen::COORDS()] };
	if (@realcoords && $realcoords[-1] eq $r->[Strassen::COORDS()][0].",".$r->[Strassen::COORDS()][1]) {
	    shift @{ $r->[Strassen::COORDS()] };
	}
	push @realcoords, map { [ split /,/ ] } @{ $r->[Strassen::COORDS()] };
    }
    Route->new_from_realcoords(\@realcoords);
}

# XXX make more sophisticated
sub get_sample_coords {
    my($coordref, $max_samples) = @_;
    my @res;
    if (@$coordref < $max_samples) {
	@res = @$coordref;
    } else {
	my $delta = @$coordref/$max_samples;
	for(my $i=0; $i<@$coordref;$i+=$delta) {
	    push @res, $coordref->[$i];
	}
    }
    @res;
}

sub load_from_string {
    my($string, @args) = @_;
    require File::Temp;
    my($fh, $file) = File::Temp::tempfile(UNLINK => !$Route::DEBUG);
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
