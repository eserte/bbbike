# -*- perl -*-

#
# $Id: Build.pm,v 1.19 2007/05/09 20:38:01 eserte Exp $
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

$VERSION = sprintf("%d.%02d", q$Revision: 1.19 $ =~ /(\d+)\.(\d+)/);

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

    use constant SIZEOF_LONG => 4; # regardless of $Config{longsize};

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

    my $temp_mmap_file = "$mmap_file.~$$~";
    warn "Second pass: create mmap file (temporary $temp_mmap_file first)...\n" if $VERBOSE;
    
    open my $ofh, ">", $temp_mmap_file
	or die "Can't create $temp_mmap_file: $!";
    binmode $ofh;

    print $ofh $MAGIC;
    print $ofh pack("V", $FILE_VERSION);

    while(my($coord, $val) = each %{ $self->{Net} }) {
	my($x,$y) = split /,/, $coord;
	my $header = pack("VVV", $x, $y, scalar keys %$val);
	print $ofh $header;
	while(my($succ, $dist) = each %{ $val }) {
	    my $ptr = $coord2ptr->{$succ};
	    if (!defined $ptr) {
		die "No pointer in coord2ptr hash for $succ";
	    }
	    my $succrecord = pack("VV", $ptr, $dist);
	    print $ofh $succrecord;
	}
    }
    close $ofh
	or die "Failure while writing $temp_mmap_file: $!";
    warn "Rename $temp_mmap_file to final destination $mmap_file...\n" if $VERBOSE;
    rename $temp_mmap_file, $mmap_file
	or do {
	    unlink $temp_mmap_file;
	    die "Failure while renaming $temp_mmap_file to $mmap_file: $!";
	};

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
    my $mmap_filename = $self->filename_c_net_mmap($file_prefix);
    my @depend_files = ($self->{Strassen}->dependent_files);
    if ($args{-blocked}) {
	my $blocked = Strassen->new($args{-blocked}, NoRead => 1);
	if (!$blocked) {
	    die "Can't read file $args{-blocked}";
	}
	push @depend_files, $blocked->dependent_files;
    }
    warn "Dependent files for mmap creation: @depend_files\n" if $VERBOSE;
    my $doit = 0;
#     for my $f ($self->{Strassen}->file) {
# 	if (! -e $f) {
# 	    $doit = 1;
# 	    warn "$f does not exist => update net\n" if $VERBOSE;
# 	    last;
# 	}
#     }
    if (   !$doit &&
	   (!-e $mmap_filename
	    || !Strassen::Util::valid_cache($self->get_cachefile(%args) . "_coord2ptr", [$mmap_filename])
	    || !Strassen::Util::valid_cache($self->get_cachefile(%args) . "_net2name", [$mmap_filename])
	   )
       ) {
	$doit = 1;
	warn "Cache is not valid\n" if $VERBOSE;
    } else {
	for my $f (@depend_files) {
	    if (-M $f < -M $mmap_filename) {
		$doit = 1;
		warn "Dependent file $f was changed => update net\n" if $VERBOSE;
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
