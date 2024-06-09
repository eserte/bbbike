# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2012,2024 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# WWW:  https://github.com/eserte/bbbike
#

package ESRI::Shapefile::Projection;

use strict;
use warnings;

our $VERSION = '1.00';

use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_accessors(qw/File Root Proj/);

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

    require Geo::LibProj::FFI;
    my $ctx = Geo::LibProj::FFI::PJ_DEFAULT_CTX();

    my $prj_text = do { open my $fh, $self->File or die "Can't open file '" . $self->File . "': $!"; local $/; <$fh> };
    my $proj = Geo::LibProj::FFI::proj_create_crs_to_crs($ctx, $prj_text, 'EPSG:4326', undef)
	or die "Error while calling proj_create_crs_to_crs with projection '$prj_text'";
    $self->Proj($proj);
}

# Returns ($lat,$lon)
sub convert_to_polar {
    my($self, $x, $y) = @_;
    my $c_from = Geo::LibProj::FFI::proj_coord($x, $y, 0, 0);
    my $c_to = Geo::LibProj::FFI::proj_trans($self->Proj, Geo::LibProj::FFI::PJ_FWD(), $c_from);
    ($c_to->enu_e, $c_to->enu_n);
#    ($c_to->lam, $c_to->phi); # would return the same
}

sub DESTROY {
    my $self = shift;
    if ($self->Proj) {
	Geo::LibProj::FFI::proj_destroy($self->Proj);
	$self->Proj(undef);
    }
}

1;

__END__
