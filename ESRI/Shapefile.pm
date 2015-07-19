# -*- perl -*-

#
# Copyright (C) 2001,2012 Slaven Rezic. All rights reserved.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.de
#

package ESRI::Shapefile;

use strict;
use vars qw(@ISA $VERSION);
$VERSION = '0.02';

use Class::Accessor; # workaround 5.00503 bug (???)
use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_accessors(qw/FileBase Main Index DBase Projection/);

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
}

sub set_file {
    my($self, $file_base, %args) = @_;

    if ($file_base =~ /^(.*)\.(dbf|sbn|sbx|shp|shx|prj)$/i) {
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
    {
	# XXX maybe do it/do it not depending on some %args parameter
	my $prj_file = "$file_base.prj";
	if (-r $prj_file) {
	    eval {
		$self->Projection(ESRI::Shapefile::Projection->new(-file => $prj_file,
								   -root => $self));
	    };
	    warn "Could not instantiate Projection member:\n$@\nContinuing, but automatic coordinate conversion won't be possible..." if $@;
	}
    }

}

sub require_all {
    require ESRI::Shapefile::Main;
    require ESRI::Shapefile::Index;
    require ESRI::Shapefile::DBase;
    require ESRI::Shapefile::Projection;

}

1;

__END__
