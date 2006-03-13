# -*- perl -*-

#
# $Id: DBase.pm,v 1.12 2005/01/08 11:09:41 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2001,2002,2004,2005 Slaven Rezic. All rights reserved.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://bbbike.sourceforge.net
#

package ESRI::Shapefile::DBase;

use strict;
use vars qw(@ISA);

use Class::Accessor; # workaround 5.00503 bug (???)
use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_accessors(qw(File Root Data DBH XBase Init Fields FieldsHash));

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

sub STORABLE_freeze {
    my($self, $cloning) = @_;
    return if $cloning;
    # workaround with "\" to serialize also mere scalars
    ("", \$self->Root, \$self->File, \$self->Data, \$self->Init, \$self->Fields, \$self->FieldsHash);
}

sub STORABLE_thaw {
    my $self = shift;
    return if shift; # $cloning
    shift; # serialized
    $self->Root      (${shift()}); # ${ ... } is the workaround back
    $self->File      (${shift()});
    $self->Data      (${shift()});
    $self->Init      (${shift()});
    $self->Fields    (${shift()});
    $self->FieldsHash(${shift()});
}

sub set_file {
    my($self, $file) = @_;

    $self->File($file);

    open(F, $file) or die "Can't open $file: $!";

    close F;
}

sub init {
    my($self, %args) = @_;
    if (!$self->Init || $args{'-force'}) {
	if ($args{'-nopreload'}) {
	    $self->tie_array;
	} else {
	    $self->preload_records;
	}
	$self->Init(1);
    }
    $self;
}

sub preload_records {
    my $self = shift;
    my $sth = $self->_get_all_sth;
    my @data;
    while(my @row = $sth->fetchrow_array) {
	cp850_iso($_) foreach (@row);
	push @data, \@row;
    }
    $self->Data(\@data);
    $self->_finish_db;
}

{
    package ESRI::Shapefile::DBase::TieArray;
    sub TIEARRAY {
	bless [$_[1]], $_[0];
    }
    sub FETCH {
	$_[0]->[0]->get_records($_[1]);
    }
    sub STORE {
	die "Not supported";
    }
    sub FETCHSIZE {
	my $self = shift;
	$self->[0]->last_record + 1;
    }
}

sub tie_array {
    my $self = shift;
    my $xbase = $self->get_xbase_object;
    tie my @data, 'ESRI::Shapefile::DBase::TieArray', $xbase;
}

sub get_xbase_object {
    my $self = shift;
    if (!$self->XBase) {
	require XBase;
	$self->XBase(XBase->new($self->File));
	die "Can't create XBase object from @{[ $self->File ]}"
	    if !$self->XBase;
    }
    $self->XBase;
}

sub get_fields {
    my $self = shift;

    $self->get_xbase_object;

    if (!$self->Fields) {
	$self->Fields([ $self->XBase->field_names ]);
    }

    if (!$self->FieldsHash) {
	my %h;
	for my $i (0 .. scalar @{ $self->Fields }) {
	    $h{$self->Fields->[$i]} = $i;
	}
	$self->FieldsHash(\%h);
    }

    @{ $self->Fields };
}

sub _get_all_sth {
    my $self = shift;

    require File::Basename;
    require DBI;

    my($name, $dir) = File::Basename::fileparse($self->File, '\..*');
    my $dbh = DBI->connect("DBI:XBase:$dir") or die $DBI::errstr;
    my $sth = $dbh->prepare("select * from $name") or die $dbh->errstr;
    $sth->execute or die $sth->errstr;

    $self->DBH($dbh);

    $sth;
}

sub _finish_db {
    my $self = shift;
    if ($self->DBH) {
	$self->DBH->disconnect;
	$self->DBH(undef);
    }
}

sub cp850_iso {
    $_[0] =~ tr/\204\224\201\216\231\232\341\202\370/äöüÄÖÜßé°/;
}

return 1 if caller();

######################################################################

if ($0 =~ /merge_with_bbd/) {
    my $shapefile = shift or die "Shapefile?";
    my $bbdfile   = shift or die "bbd file?";
    my $outfile   = shift or die "new bbd file for output?";

    require ESRI::Shapefile;
    my $esri = ESRI::Shapefile->new;
    $esri->set_file($shapefile);
    $esri->DBase->merge_with_bbd($bbdfile, $outfile);
}

$DBI::errstr = $DBI::errstr if 0; # peacify -w

__END__
