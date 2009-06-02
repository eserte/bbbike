# -*- perl -*-

#
# $Id: FromMeta.pm,v 1.4 2009/06/02 05:32:49 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2009 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: srezic@cpan.org
# WWW:  http://www.bbbike.de
#

package Geography::FromMeta;

use strict;

sub load_meta {
    my($class, $metafile) = @_;
    if (open METAFH, $metafile) {
	local $/ = undef;
	my $metastring = <METAFH>;
	close METAFH;
	$metastring =~ s{^\$meta\s*=\s*}{};
	my $meta = eval $metastring;
	if ($@) {
	    warn "Cannot read meta data from $metafile";
	} else {
	    my $self = bless { %$meta }, $class; # XXX or fake class into something using the city/country name?
	    return $self;
	}
    }
    undef;
}

# cityname in native or common language
# XXX Note that osm2bbd currently does not set mapname
sub cityname {
    my $self = shift;
    $self->{mapname};
}

sub center {
    my $self = shift;
    if ($self->{center} || $self->{bbox}) {
	my($cx,$cy);
	if ($self->{center}) {
	    ($cx,$cy) = @{ $self->{center} };
	} else {
	    require Strassen::Util;
	    ($cx,$cy) = Strassen::Util::middle(@{ $self->{bbox} });
	}
	join ",", $cx, $cy;
    } else {
	undef;
    }
}

sub bbox { shift->{bbox} }
sub skip_features { %{ shift->{skip_features} || {} } }

sub _bbox_standard_coordsys {
    my $self = shift;
    if (($self->{coordsys}||'') eq 'wgs84') {
	my($x1,$y1,$x2,$y2) = @{ $self->bbox };
	require Karte::Polar;
	($x1,$y1) = $Karte::Polar::obj->map2standard($x1,$y1);
	($x2,$y2) = $Karte::Polar::obj->map2standard($x2,$y2);
	[$x1, $y1, $x2, $y2];
    } else {
	$self->bbox;
    }
}
sub _center_standard_coordsys {
    my $self = shift;
    if (($self->{coordsys}||'') eq 'wgs84') {
	my($x1,$y1) = split /,/, $self->center;
	require Karte::Polar;
	($x1,$y1) = $Karte::Polar::obj->map2standard($x1,$y1);
	"$x1,$y1";
    } else {
	$self->center;
    }
}


# sub datadir {
#     require File::Basename;
#     my $pkg = __PACKAGE__;
#     $pkg =~ s|::|/|g; # XXX other oses?
#     $pkg .= ".pm";
#     if (exists $INC{$pkg}) {
# 	return File::Basename::dirname(File::Basename::dirname($INC{$pkg}))
# 	    . "/data";
#     }
#     undef; # XXX better solution?
# }

1;

__END__
