# -*- perl -*-

#
# $Id: Main.pm,v 1.12 2004/08/19 21:02:29 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001,2002 Slaven Rezic. All rights reserved.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package ESRI::Shapefile::Main;

use strict;

use constant FILECODE => 9994;
use constant VERSION => 1000;

BEGIN {
    for (["Null"       => 0], # Null Shape 
	 ["Point"      => 1],
	 ["PolyLine"   => 3],
	 ["Polygon"    => 5],
	 ["MultiPoint" => 8],
	 ["PointZ"     => 11],
	 ["PolyLineZ"  => 13],
	 ["PolygonZ"   => 15],
	 ["MultiPointZ"=> 18],
	 ["PointM"     => 21],
	 ["PolyLineM"  => 23],
	 ["PolygonM"   => 25],
	 ["MultiPointM"=> 28],
	 ["MultiPatch" => 31],
	) {
	(my $shape_type = $_->[0]) =~ s/\W//g;
	my $cmd = 'use constant SHAPE_'.uc($shape_type).' => '.$_->[1];
	#warn $cmd;
	eval $cmd;
    }
}

use Class::Accessor; # workaround 5.00503 bug (???)
use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_accessors(qw/File Root Header Records FH Init/);

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
    $self->Init(0);

    $self;
}

# -force => 1: force initialization (useful for -nopreload => 1 and next_record)
sub init {
    my($self, %args) = @_;
    if (!$self->Init || $args{'-force'}) {
	$self->set_file($self->File, %args);
	$self->Init(1);
    }
}

# -nopreload => 1: do not preload Records member ... the user can
#    iterate with the next_record method or preload himself by using
#    preload_records
sub set_file {
    my($self, $file, %args) = @_;

    $self->File($file);

    my $fh;
    if ($] < 5.006) {
	require Symbol;
	$fh = Symbol::gensym();
    }
    open($fh, $file) or die "Can't open $file: $!";
    $self->FH($fh);
    binmode $fh;

    read $fh, my($header), 100;
    $self->Header(ESRI::Shapefile::Main::Header->new($header));

    $self->preload_records unless $args{'-nopreload'};

}

sub preload_records {
    my $self = shift;
    my $fh = $self->FH;

    my @records;
    while(!eof $fh) {
	push @records, ESRI::Shapefile::Main::Record->new($self);
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
    ESRI::Shapefile::Main::Record->new($self);
}

######################################################################

package ESRI::Shapefile::Main::Header;

use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_accessors(qw/FileCode FileLength Version ShapeType BoundingBox/);

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;

    my $buf = shift;

    $self->FileCode(unpack("N", substr($buf, 0, 4)));
    die "Wrong file code @{ $self->FileCode }"
	if $self->FileCode != ESRI::Shapefile::Main::FILECODE;
    $self->FileLength(unpack("N", substr($buf, 24, 4)));
    $self->Version(unpack("V", substr($buf, 28, 4)));
    die "Wrong version @{ $self->Version }"
	if $self->Version != ESRI::Shapefile::Main::VERSION;
    $self->ShapeType(unpack("V", substr($buf, 32, 4)));

    my %bounding_box;
    my $pos = 36;
    for (qw(Xmin Ymin Xmax Ymax Zmin Zmax Mmin Mmax)) {
	# XXX d on Bigendian?
	$bounding_box{$_} = unpack("d", substr($buf, $pos, 8));
	$pos+=8;
    }
    $self->BoundingBox(\%bounding_box);
    $self;
}

######################################################################

package ESRI::Shapefile::Main::Record;

use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_accessors(qw(RecordNumber ContentLength ShapeType));

sub new {
    my $class = shift;
    my $root  = shift;

    read $root->FH, my($header), 12;

    my $shape_type = unpack("V", substr($header, 8, 4));

    my $new_class =
	{ ESRI::Shapefile::Main::SHAPE_POINT()    => "Point",
	  ESRI::Shapefile::Main::SHAPE_POLYLINE() => "PolyLine",
	  ESRI::Shapefile::Main::SHAPE_POLYGON()  => "Polygon",
	  ESRI::Shapefile::Main::SHAPE_NULL()     => "Null",
	  #XXX
	}->{$shape_type};
    if (!defined $new_class) {
	die "Unhandled shape type $shape_type at pos " . tell($root->FH);
    }
    $new_class = "ESRI::Shapefile::Main::Record::" . $new_class;

    my $record = $new_class->new_from_file($root);

    $record->RecordNumber(unpack("N", substr($header, 0, 4)));
    # here, ContentLength is in Bytes
    $record->ContentLength(unpack("N", substr($header, 4, 4)) * 2);
    $record->ShapeType($shape_type);

    $record;
}

######################################################################

package ESRI::Shapefile::Main::Record::Null;

use base qw(ESRI::Shapefile::Main::Record Class::Accessor::Fast);

sub new_from_file {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
}

######################################################################

package ESRI::Shapefile::Main::Record::Point;

use base qw(ESRI::Shapefile::Main::Record Class::Accessor::Fast);

__PACKAGE__->mk_accessors(qw(Point));

sub new_from_file {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;

    my $root = shift;

    read $root->FH, my($header), 16;

    $self->Point([unpack("d2", $header)]);

    $self;
}

######################################################################

package ESRI::Shapefile::Main::Record::PolyLine;

use base qw(ESRI::Shapefile::Main::Record Class::Accessor::Fast);

__PACKAGE__->mk_accessors(qw(Box Lines));

sub new_from_file {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;

    my $root = shift;

    read $root->FH, my($header), 40;

    # XXX big endian?
    $self->Box([unpack("d4", substr($header, 0, 32))]);

    my $num_parts  = unpack("V", substr($header, 32, 4));
    my $num_points = unpack("V", substr($header, 36, 4));

    my $parts_len = $num_parts*4;
    read $root->FH, $header, $parts_len;
    my(@parts)  = unpack("V$num_parts", $header);

    # 8 is length of a double
    read $root->FH, $header, $num_points*8*2;
    # XXX big endian?
    my(@points) = map { [ unpack("d".2,$_) ] } unpack("a16"x($num_points), $header);
    my @lines;
    for my $part_i (0 .. $#parts) {
	my $end_index = ($part_i < $#parts ? $parts[$part_i+1]-1 : $#points);
	my @line;
	for my $i ($parts[$part_i] .. $end_index) {
	    push @line, $points[$i];
	}
	push @lines, \@line;
    }

    $self->Lines(\@lines);

    $self;
}

######################################################################

package ESRI::Shapefile::Main::Record::Polygon;

use base qw(ESRI::Shapefile::Main::Record Class::Accessor::Fast);

__PACKAGE__->mk_accessors(qw(Box Areas));

sub new_from_file {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;

    my $root = shift;

    read $root->FH, my($header), 40;

    # XXX big endian?
    $self->Box([unpack("d4", substr($header, 0, 32))]);

    my $num_parts  = unpack("V", substr($header, 32, 4));
    my $num_points = unpack("V", substr($header, 36, 4));

    my $parts_len = $num_parts*4;
    read $root->FH, $header, $parts_len;
    my(@parts)  = unpack("V$num_parts", $header);

    # 8 is length of a double
    read $root->FH, $header, $num_points*8*2;
    # XXX big endian?
    my(@points) = map { [ unpack("d".2,$_) ] } unpack("a16"x($num_points), $header);
    my @lines;
    for my $part_i (0 .. $#parts) {
	my $end_index = ($part_i < $#parts ? $parts[$part_i+1]-1 : $#points);
	my @line;
	for my $i ($parts[$part_i] .. $end_index) {
	    push @line, $points[$i];
	}
	push @lines, \@line;
    }

    $self->Areas(\@lines);

    $self;
}


1;

__END__
