# -*- perl -*-

#
# $Id: MapInfo.pm,v 1.5 2004/02/25 23:56:49 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (c) 2004 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://bbbike.sourceforge.net
#

package Strassen::MapInfo;

use strict;
use vars qw(@ISA);

@ISA = 'Strassen';

=head1 NAME

Strassen::MapInfo - read MapInfo files into a Strassen object

=head1 SYNOPSIS

    use Strassen::MapInfo;
    $s = Strassen::MapInfo->new("file.mif");

    Strassen::MapInfo::export($s, "exportfile");

    perl Strassen/MapInfo.pm infile.bbd -o outfile

=head1 DESCRIPTION

This module handles MapInfo files (usually with extensions .mif and
.mid extensions).

=head2 METHODS

=over

=cut

sub new {
    my($class, $filename, %arg) = @_;
    my $self = {};
    bless $self, $class;

    if ($filename) {
	$self->read_mif($filename);
    }

    $self;
}

=item read_mif($filename)

Read a MIF file. The filename may be specified with or without the
.mif/.MIF extension.

=cut

sub read_mif {
    my($self, $filename) = @_;

    $filename =~ s/\.mid$//i;
 TRY: {
	for my $suf ("", ".mif", ".MIF") {
	    open(MIF, "$filename$suf") and do {
		$filename = "$filename$suf";
		last TRY;
	    }
	}
	die "Can't open $filename: $!";
    }

    $self->{MIF_DELIMITER} = "\t";
    use constant MODE_HEADER  => 0;
    use constant MODE_COLUMNS => 1;
    use constant MODE_DATA    => 2;
    my $mode = MODE_HEADER;
    my $current_record;
    my @data;
    $self->{MIF_COLUMNS} = [];
    my $column_data;
    my $name_column;
    my $rec_i = 0;

    my $push = sub {
	if ($current_record) {
	    my $name = "";
	    if (defined $name_column && $column_data) {
		$name = $column_data->[$rec_i][$name_column];
	    }
	    $name =~ s/\t//g;
	    # XXX What's a good guess for the category
	    # XXX Write other column data into an info file --- but for now
	    # it is not possible to use file-less info data.
	    push @data, "$name\tX " . join(" ", @$current_record);
	    $rec_i++;
	    $current_record = undef;
	}
    };

    # XXX A lot of directives are not handled for now
    while(<MIF>) {
	my @l = split /[\015\012]/, $_;
	for my $l (@l) {
	    next if ($l =~ /^\s*$/);
	    if ($l =~ /^data$/i) {
		if (@{ $self->{MIF_COLUMNS} }) {
		    $column_data = $self->read_mid($filename);
		    $name_column = $self->guess_name_column;
		}
		$mode = MODE_DATA;
	    } elsif ($l =~ /^columns/i) {
		$mode = MODE_COLUMNS;
	    } elsif ($mode == MODE_DATA) {
		if (/^pline/i) { # XXX other geometry types and pen not handled
		    $push->();
		    $current_record = [];
		} elsif (/^point\s+([-+\d\.]+)\s+([-+\d\.]+)/i) {
		    my($x, $y) = ($1, $2);
		    $push->();
		    $current_record = ["$x,$y"];
		} elsif (/^\s*([-+\d\.]+)\s+([-+\d\.]+)/) {
		    push @$current_record, "$1,$2";
		}
	    } elsif ($mode == MODE_COLUMNS) {
		$l =~ /^\s*(\S+)\s*(\S+)/;
		push @{ $self->{MIF_COLUMNS} }, [$1, $2];
	    } elsif ($l =~ /delimiter\s+"(.)"/i) {
		$self->{MIF_DELIMITER} = $1;
	    }
	}
    }
    $push->();
    close MIF;

    $self->{Data} = [ @data ];
}

sub guess_name_column {
    my $self = shift;

    use constant CHECK_NAME    => 0;
    use constant CHECK_NAME_RX => 1;
    use constant CHECK_ID      => 2;
    use constant CHECK_ID_RX   => 3;
    use constant CHECK_FIRST   => 4;
    for my $check (CHECK_NAME .. CHECK_FIRST) {
	my $col_i = 0;
	for my $coldef (@{ $self->{MIF_COLUMNS} }) {
	    if (($check == CHECK_NAME && $coldef->[0]    =~ /^name$/i) ||
		($check == CHECK_NAME_RX && $coldef->[0] =~ /name/i) ||
		($check == CHECK_ID && $coldef->[0]      =~ /^id$/i) ||
		($check == CHECK_ID_RX && $coldef->[0]   =~ /id/i) ||
		($check == CHECK_FIRST && 1)) {
		return $col_i;
	    }
	    $col_i++;
	}
    }
    undef; # should not happen
}

=item read_mid($filename)

Read a MID file. The filename may be specified with or without the
.mid/.MID extension. This method has to be called from read_mif.

=cut

sub read_mid {
    my($self, $filename) = @_;

    $filename =~ s/\.mif$//i;
 TRY: {
	for my $suf ("", ".mid", ".MID") {
	    open(MID, "$filename$suf") and do {
		$filename = "$filename$suf";
		last TRY;
	    }
	}
	warn "Can't open MID file: $!";
	return;
    }

    my @column_data;
    require Text::CSV_XS;
    my $csv = Text::CSV_XS->new({
				 binary => 1,
				 sep_char => $self->{MIF_DELIMITER},
				});
    while(<MID>) { # XXX Mac format not readable with this loop!
	s/[\015\012]+//g;
	if ($csv->parse($_)) {
	    push @column_data, [ $csv->fields ];
	} else {
	    warn "Can't parse line $_";
	}
    }
    \@column_data;
}

=item create_mif_mid($strassen_object, %args)

Static method. Take a Strassen object and return two strings
containing MIF and MID data.

Additional arguments may be: map => I<maptoken> and tomap =>
I<maptoken>.

=cut

sub create_mif_mid {
    my($self, %args) = @_;
    my $version = "300";
    my($minx,$miny,$maxx,$maxy) = $self->bbox;

    my $conv;
    my $coordsysline;
    if ($args{map} || $args{tomap}) {
	$args{map}   ||= "standard";
	$args{tomap} ||= "standard";
	require Karte;
	Karte::preload(":all");
	$conv = sub {
	    $Karte::map{$args{map}}->map2map($Karte::map{$args{tomap}}, @_);
	};
    }

    ($minx,$miny) = $conv->($minx,$miny) if $conv;
    ($maxx,$maxy) = $conv->($maxx,$maxy) if $conv;

    if ($args{tomap} eq 'polar') {
	$coordsysline = "";
    }
    if (!defined $coordsysline) {
	$coordsysline = qq{COORDSYS NonEarth Units "m" Bounds ($minx,$miny) ($maxx,$maxy)\n};
    }
    my($max_name_length, $max_cat_length) = (1, 1);
    $self->init;
    while(1) {
	my $r = $self->next;
	last if !@{ $r->[Strassen::COORDS()] };
	$max_name_length = length($r->[Strassen::NAME()])
	    if $max_name_length < length($r->[Strassen::NAME()]);
	$max_cat_length = length($r->[Strassen::CAT()])
	    if $max_cat_length < length($r->[Strassen::CAT()]);
    }

    my $mid = "";
    my $mif = <<EOF;
VERSION $version
CHARSET "WindowsLatin1"
DELIMITER ","
${coordsysline}COLUMNS 2
  Name     Char($max_name_length)
  Category Char($max_cat_length)
DATA

EOF

    $self->init;
    while(1) {
	my $r = $self->next;
	my $no_coords = @{ $r->[Strassen::COORDS()] };
	last if !$no_coords;

	if ($no_coords == 1) {
	    my($x, $y) = split /,/, $r->[Strassen::COORDS()]->[0];
	    ($x,$y) = $conv->($x,$y) if $conv;
	    $mif .= "Point $x $y\n";
	} else {
	    $mif .= "Pline $no_coords\n";
	    for my $p (@{ $r->[Strassen::COORDS()] }) {
		my($x, $y) = split /,/, $p;
		($x,$y) = $conv->($x,$y) if $conv;
		$mif .= "$x $y\n";
	    }
	    $mif .= "    Pen (1,2,1)\n";
	}

	(my $name = $r->[Strassen::NAME()]) =~ s/\"//g; # XXX better solution!
	(my $cat  = $r->[Strassen::CAT()])  =~ s/\"//g; # XXX better solution!
	$mid .= qq{"$name","$cat"\n};
    }

    ($mif, $mid);
}

=item export($strassen_object, $filename, %args)

Static method. Take a Strassen object and a filename without extension
and write a MIF and a MID file (with extension). See create_mif_mid
for additional arguments.

=cut

sub export {
    my($self, $filename, %args) = @_;
    my($mif, $mid) = create_mif_mid($self, %args);
    open(MIF, ">$filename.MIF") or die "Can't create $filename.MIF: $!";
    print MIF $mif;
    close MIF;
    open(MID, ">$filename.MID") or die "Can't create $filename.MID: $!";
    print MID $mid;
    close MID;
}

=back

=cut

return 1 if caller;

require Strassen;
require Getopt::Long;
my %args;
if (!Getopt::Long::GetOptions(\%args, "o=s", "map=s", "tomap=s")) {
    die "usage!";
}
my $o = delete $args{o};
if (!defined $o) { die "-o option missing" }
my $s;
if (@ARGV == 0) {
    die "Strassen file missing";
} elsif (@ARGV == 1) {
    my $f = shift;
    $s = Strassen->new($f);
} else {
    $s = MultiStrassen->new(@ARGV);
}
export($s, $o, %args);

=head1 AUTHOR

Slaven Rezic <eserte@users.sourceforge.net>

=head1 COPYRIGHT

Copyright (c) 2004 Slaven Rezic. All rights reserved.
This is free software; you can redistribute it and/or modify it under the
terms of the GNU General Public License, see the file COPYING.

=head1 SEE ALSO

L<Strassen::Core>.
