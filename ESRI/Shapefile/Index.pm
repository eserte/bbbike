# -*- perl -*-

#
# $Id: Index.pm,v 1.5 2003/01/08 20:11:59 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package ESRI::Shapefile::Index;

use strict;
use vars qw(@ISA);

use Class::Accessor; # workaround 5.00503 bug (???)
use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_accessors(qw(File Root Header Records FH Init));

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;

    my(%args) = @_;

    if ($args{-file}) {
	$self->set_file($args{-file});
    }
    if ($args{-root}) {
	$self->Root($args{-root});
    }
    $self->Init(0);

    $self;
}

sub init {
    my($self, %args) = @_;
    if (!$self->Init || $args{'-force'}) {
	$self->set_file($self->File, %args);
	$self->Init(1);
    }
}

sub set_file {
    my($self, $file, %args) = @_;

    $self->File($file);

return 0; # XXX not yet
    my $fh;
    if ($] < 5.006) {
	require Symbol;
	$fh = Symbol::gensym();
    }
    open($fh, $file) or die "Can't open $file: $!";
    $self->FH($fh);
    binmode $fh;

    read $fh, my($header), 100;
    $self->Header(ESRI::Shapefile::Index::Header->new($header));

    $self->preload_records unless $args{'-nopreload'};
}

sub preload_records {
    my $self = shift;
    my $fh = $self->FH;

    my @records;
    while(!eof $fh) {
	push @records, ESRI::Shapefile::Index::Record->new($self);
    }
    $self->Records(\@records);

    close $fh;
    $self->FH(undef);
}

sub next_record {
    my $self = shift;
    if (!defined $self->FH) {
	require Carp; Carp::cluck(); # XXX debugging
	warn "File descriptor already closed";
	return;
    }
    if (eof $self->FH) {
	close $self->FH;
	$self->FH(undef);
	return undef;
    }
    ESRI::Shapefile::Index::Record->new($self);
}

######################################################################

package ESRI::Shapefile::Index::Header;

use ESRI::Shapefile::Main;
@ESRI::Shapefile::Index::Header::ISA = qw(ESRI::Shapefile::Main::Header);

######################################################################

package ESRI::Shapefile::Index::Record;

use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_accessors(qw(Offset ContentLength));

sub new {
    my $class = shift;
    my $root  = shift;

    my $self = bless {}, $class;

    read $root->FH, my($buf), 4*2;

    # both Offset and ContentLength are converted to bytes
    $self->Offset(unpack("N", substr($buf, 0, 4)) * 2);
    $self->ContentLength(unpack("N", substr($buf, 4, 4)) * 2);

    $self;
}

1;

__END__
