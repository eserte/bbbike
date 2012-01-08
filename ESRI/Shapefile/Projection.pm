# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2012 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package ESRI::Shapefile::Projection;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use Class::Accessor; # workaround 5.00503 bug (???)
use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_accessors(qw/File Root Proj4/);

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;

    my(%args) = @_;

    if ($args{-root}) {
	$self->Root($args{-root});
    }
    if ($args{-file}) {
	$self->File($args{-file});
    }
    $self->Init();

    $self;
}

sub Init {
    my $self = shift;

    require Geo::GDAL;
    require Geo::Proj4;

    my $srs = Geo::OSR::SpatialReference->new;
    my $prj_text = do { open my $fh, $self->File or die "Can't open file '" . $self->File . "': $!"; local $/; <$fh> };
    $srs->ImportFromWkt($prj_text);
    my $proj4_string = $srs->ExportToProj4;
    my $proj4 = Geo::Proj4->new($proj4_string);
    $self->Proj4($proj4);
}

# Returns ($lat,$lon)
sub convert_to_polar {
    my($self, $x, $y) = @_;
    $self->Proj4->inverse($x, $y);
}

1;

__END__
