# -*- perl -*-

#
# $Id: FromMeta.pm,v 1.2 2009/02/25 23:44:32 eserte Exp $
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
