# -*- perl -*-

#
# $Id: Build.pm,v 1.16 2003/11/15 14:26:36 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2001, 2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package Strassen::Build;
use strict;
use vars qw($VERSION);

$VERSION = sprintf("%d.%02d", q$Revision: 1.16 $ =~ /(\d+)\.(\d+)/);

package StrassenNetz::CNetFile;

use vars qw($FILE_VERSION $MAGIC $VERBOSE);
use Config;

$FILE_VERSION = 1;
$MAGIC = 'stnt'; # STrassenNeTz

require Strassen::Util;

# Format of mmap file:
# (all little endian longs)
#   at the top of the file: magic and file version number
#
#   foreach coordinate
#     x of this coordinate
#     y of this coordinate
#     number of successors
#     foreach successor:
#       relative pointer to successor struct
#       distance from this point to successor point in m
#
# The coord2ptr file is a Storable file of a hash which does the
# coordinate string ("x,y") to relative pointer mapping.
#

# %args may be
#   -blocked => $sperre_file: file for blocked streets, usually "gesperrt"
sub create_mmap_net {
    my($self, $file_prefix, %args) = @_;
#    $self->make_net_classic if (!$self->{Net});
    warn "Create classic net...\n" if $VERBOSE;
    if (!$self->{Net}) {
	if ($self->can("make_net_XS")) {
	    $self->make_net_XS;
	} else {
	    $self->make_net_classic;
	}
    }

    if ($args{-blocked}) {
	my $blocked_type = $args{-blockedtype} || [qw(einbahn sperre)];
	warn "Remove blocked streets from file $args{-blocked}, type @$blocked_type ...\n" if $VERBOSE;
	$self->StrassenNetz::make_sperre($args{-blocked},
					 Type => $blocked_type);
    }

    use constant SIZEOF_LONG => 4; # XXX only for intel

    my $coord2ptr          = {};
    my $coord2structlength = {};
    my $total_structlength = SIZEOF_LONG*2; # room for magic and version number

    my $mmap_file = $self->filename_c_net_mmap($file_prefix);

    # XXX these values are only for intel platforms valid!
    use constant LENGTH_HEADER => SIZEOF_LONG*3; # three longs for x, y, number of succ
    use constant LENGTH_SUCC   => SIZEOF_LONG*2; # two longs for pointer and distance
    # XXX this will go away ...
    require Config;
    if ($Config::Config{"byteorder"} ne "1234" &&
	$Config::Config{"byteorder"} ne "12345678") {
	warn "*"x70,"\n";
	warn "* This will only work on little endian machines!\n";
	warn "*"x70,"\n";
	warn "See";
    }

    warn "First pass: calculate structs and create \$coord2ptr Hash...\n"
	if $VERBOSE;
    while(my($coord, $val) = each %{ $self->{Net} }) {
	$coord2ptr->{$coord} = $total_structlength;
	my $this_structlength = LENGTH_HEADER + LENGTH_SUCC * scalar keys %$val;
	$total_structlength += $this_structlength;
    }

    warn "Second pass: create mmap file...\n" if $VERBOSE;
    open(F, "> $mmap_file") or die "Can't create $mmap_file: $!";
    binmode F;

    print F $MAGIC;
    print F pack("V", $FILE_VERSION);

    while(my($coord, $val) = each %{ $self->{Net} }) {
	my($x,$y) = split /,/, $coord;
	my $header = pack("VVV", $x, $y, scalar keys %$val);
	print F $header;
	while(my($succ, $dist) = each %{ $val }) {
	    my $ptr = $coord2ptr->{$succ};
	    if (!defined $ptr) {
		die "No pointer in coord2ptr hash for $succ";
	    }
	    my $succrecord = pack("VV", $ptr, $dist);
	    print F $succrecord;
	}
    }
    close F;

    warn "Write cache files...\n" if $VERBOSE;
    Strassen::Util::write_cache($coord2ptr, $self->get_cachefile(%args) . "_coord2ptr");
    Strassen::Util::write_cache($self->{Net2Name}, $self->get_cachefile(%args) . "_net2name");

    1;
}

sub filename_c_net_mmap {
    my($self, $file_prefix) = @_;
    $file_prefix . "_net_" . $Config{byteorder} . ".mmap";
}

sub create_mmap_net_if_needed {
    my($self, $file_prefix, %args) = @_;
    my @depend_files = ($self->{Strassen}->file);
    if ($args{-blocked}) {
	my $blocked = Strassen->new($args{-blocked}, NoRead => 1);
	if (!$blocked) {
	    die "Can't read file $args{-blocked}";
	}
	push @depend_files, $blocked->file;
    }
    warn "Dependent files for mmap creation: @depend_files\n" if $VERBOSE;
    my $doit = 0;
    for my $f ($self->{Strassen}->file) {
	if (! -e $f) {
	    $doit = 1;
	    last;
	}
    }
    if (   !$doit &&
	   (!Strassen::Util::valid_cache($self->get_cachefile(%args) . "_coord2ptr",
					 \@depend_files)
	    || !-e $self->filename_c_net_mmap($file_prefix)
	    || !Strassen::Util::valid_cache($self->get_cachefile(%args) . "_net2name",
					    \@depend_files)
	   )
       ) {
	$doit = 1;
    } else {
	for my $f (@depend_files) {
	    if (-M $f < -M $self->filename_c_net_mmap($file_prefix)) {
		$doit = 1;
		last;
	    }
	}
    }

    if ($doit) {
	$self->create_mmap_net($file_prefix, %args);
    } else {
	1;
    }
}


1;

__END__
