# -*- perl -*-

#
# $Id: Shapefile.pm,v 1.12 2003/01/08 20:11:42 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package ESRI::Shapefile;

use strict;
use vars qw(@ISA);

use Class::Accessor; # workaround 5.00503 bug (???)
use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_accessors(qw/FileBase Main Index DBase/);

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
}

sub set_file {
    my($self, $file_base, %args) = @_;

    if ($file_base =~ /^(.*)\.(dbf|sbn|sbx|shp|shx)$/i) {
	$file_base = $1;
    }

    $self->FileBase($file_base);

    $self->require_all;

    $self->Main(ESRI::Shapefile::Main->new(-file => "$file_base.shp",
					   -root => $self));
    $self->Index(ESRI::Shapefile::Index->new(-file => "$file_base.shx",
					     -root => $self));
    $self->DBase(ESRI::Shapefile::DBase->new(-file => "$file_base.dbf",
					     -root => $self));
}

sub require_all {
    require ESRI::Shapefile::Main;
    require ESRI::Shapefile::Index;
    require ESRI::Shapefile::DBase;

}

1;

__END__
