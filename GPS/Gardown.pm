# -*- perl -*-

#
# $Id: Gardown.pm,v 1.1 2005/04/15 23:55:17 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2005 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package GPS::Gardown;

use strict;
use vars qw($VERSION @ISA);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

require GPS;
push @ISA, 'GPS';

sub magics { ('^[WT]  ') }

sub convert_to_route {
    my($self, $file, %args) = @_;
    my $res = $self->parse($file, %args);
    map { [@{$_}[0,1]] } @{ $res->{points } };
}

sub parse {
    my($self, $file, %args) = @_;

    require Karte::Standard;
    require Karte::Polar;
    my $obj = $Karte::Polar::obj;

    my @res;
    my $type;
    open(FH, $file) or die "Can't open $file: $!";
    while(<FH>) {
	chomp;
	my(@l) = split /\s+/;
	$type = $l[0];
	my($lat, $long, $desc);
	if ($type eq 'T') {
	    $lat  = join " ", @l[1,2];
	    $long = join " ", @l[3,4];
	} else {
	    $lat  = join " ", @l[2,3];
	    $long = join " ", @l[4,5];
	    $desc = $l[11] || $l[1];
	}

	$long = Karte::Polar::dmm_string2ddd($long);
	$lat  = Karte::Polar::dmm_string2ddd($lat);
	my($x,$y) = Karte::Standard->trim_accuracy($obj->map2standard($long, $lat));
	if (!@res || ($x != $res[-1]->[0] ||
		      $y != $res[-1]->[1])) {
	    push @res, [$x, $y, $desc];
	}
    }
    close FH;

    return { type => $type,
	     points => \@res,
	   };
}

1;

__END__
