# -*- perl -*-

#
# $Id: MapInfo.pm,v 1.8 2004/03/10 16:31:07 eserte Exp $
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

require Strassen::Core;
require Strassen::MultiStrassen;

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
    my $trim_accuracy;
    my $coordsysline;
    if ($args{map} || $args{tomap}) {
	$args{map}   ||= "standard";
	$args{tomap} ||= "standard";
	require Karte;
	Karte::preload(":all");
	$conv = sub {
	    $Karte::map{$args{map}}->map2map($Karte::map{$args{tomap}}, @_);
	};
	$trim_accuracy = sub {
	    $Karte::map{$args{tomap}}->trim_accuracy(@_);
	};
    }

    ($minx,$miny) = $trim_accuracy->($conv->($minx,$miny)) if $conv;
    ($maxx,$maxy) = $trim_accuracy->($conv->($maxx,$maxy)) if $conv;

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
	    ($x,$y) = $trim_accuracy->($conv->($x,$y)) if $conv;
	    $mif .= "Point $x $y\n";
	} else {
	    $mif .= "Pline $no_coords\n";
	    for my $p (@{ $r->[Strassen::COORDS()] }) {
		my($x, $y) = split /,/, $p;
		($x,$y) = $trim_accuracy->($conv->($x,$y)) if $conv;
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

=item create_mif_mid_from_data_directory($data_directory, %args)

Static method. Take a data directory and return two strings
containing MIF and MID data.

Additional arguments may be: map => I<maptoken> and tomap =>
I<maptoken>.

=cut

# XXX Partially same code in create_mif_mid
sub create_mif_mid_from_data_directory {
    my($datadir, %args) = @_;
    local @Strassen::datadirs = $datadir;
    my $version = "300";

    require Template;

    my $conv;
    my $trim_accuracy;
    my $coordsysline;
    if ($args{map} || $args{tomap}) {
	$args{map}   ||= "standard";
	$args{tomap} ||= "standard";
	require Karte;
	Karte::preload(":all");
	$conv = sub {
	    $Karte::map{$args{map}}->map2map($Karte::map{$args{tomap}}, @_);
	};
	$trim_accuracy = sub {
	    $Karte::map{$args{tomap}}->trim_accuracy(@_);
	};
    }

    if ($args{tomap} eq 'polar') {
	$coordsysline = "";
    }
    if (!defined $coordsysline) {
	$coordsysline = qq{COORDSYS NonEarth Units "m" Bounds ([% minx %],[% miny %]) ([% maxx %],[% maxy %])\n};
    }

    my @column_names = qw(Name Category
			  Elevation
			  Trafficlight_Comment Trafficlight_Category
			  Blocking_Comment Blocking_Category
			  Cyclepath_Comment Cyclepath_Category
			  Quality_Comment Quality_Category
			  Handicap_Comment Handicap_Category
			  Mount_Comment Mount_Category
			  Path_Comment Path_Category
			  Route_Comment Route_Category
			  Tram_Comment Tram_Category
			  Traffic_Comment Traffic_Category
			  Ferry_Comment Ferry_Category
			  Brunnel_Comment Brunnel_Category
			  Green_Comment Green_Category
			  Nolighting_Comment Nolighting_Category
			  Comment Comment_Category
			 );
    # XXX missing columns: Author, AcquireAuthor,CreationDate, AcquireDate
    my %column_to_index;
    {
	my $i = 0;
	for (@column_names) {
	    $column_to_index{$_} = $i;
	    $i++;
	}
    }

    my $mid = "";
    my $mif = <<EOF;
VERSION $version
CHARSET "WindowsLatin1"
DELIMITER ","
${coordsysline}COLUMNS @{[ scalar @column_names ]}
EOF
    for my $column (@column_names) {
	$mif .= <<EOF;
  $column [% TYPE_${column} %]
EOF
    }
    $mif .= <<EOF;
DATA

EOF

    my($minx,$miny,$maxx,$maxy);
    my @max_len;

 FILELOOP:
    for my $def ([["strassen", "landstrassen", "landstrassen2", "plaetze", "faehren"], NAME => "Name", CAT => "Category"],
		 ["ampeln", NAME => "Trafficlight_Comment", CAT => "Traffic_Category"],
		 ["brunnels", NAME => "Brunnel_Comment", CAT => "Brunnel_Category"],
		 [["comments_cyclepath", "radwege_exact"], NAME => "Cyclepath_Comment", CAT => "Cyclepath_Category"],
		 ["comments_ferry", NAME => "Ferry_Comment", CAT => "Ferry_Category"],
		 ["comments_kfzverkehr", NAME => "Traffic_Comment", CAT => "Traffic_Category"],
		 ["comments_misc", NAME => "Comment", CAT => "Comment_Category"],
		 ["comments_mount", NAME => "Mount_Comment", CAT => "Mount_Category"],
		 ["comments_path", NAME => "Path_Comment", CAT => "Path_Category"],
		 ["comments_route", NAME => "Route_Comment", CAT => "Route_Category"],
		 ["comments_tram", NAME => "Tram_Comment", CAT => "Tram_Category"],
		 ["gesperrt", NAME => "Blocking_Comment", CAT => "Blocking_Category"],
		 ["green", NAME => "Green_Comment", CAT => "Green_Category"],
		 [["handicap_s", "handicap_l"], NAME => "Handicap_Comment", CAT => "Handicap_Category"],
		 ["hoehe", NAME => "Elevation"],
		 ["nolighting", NAME => "Nolighting_Comment", CAT => "Nolighting_Category"],
		 [["qualitaet_s", "qualitaet_l"], NAME => "Quality_Comment", CAT => "Quality_Category"],
		 # missing: vorfahrt
		) {
	my $file = shift @$def;
	my %field_map = @$def;
	while(my($k,$v) = each %field_map) {
	    my $inx = $column_to_index{$v};
	    if (!defined $inx) {
		warn "Cannot find index for $v, skipping"; # XXX should die some day
		next FILELOOP;
	    }
	    $field_map{$k} = $inx;
	}

	my $str;
	eval {
	    if (ref $file eq 'ARRAY') {
		$str = MultiStrassen->new(@$file);
		if ($args{v}) { print STDERR "@$file...\n" }
	    } else {
		$str = Strassen->new($file);
		if ($args{v}) { print STDERR "$file...\n" }
	    };
	};
	if (!$str) {
	    warn "$@, skipping $file...";
	    next;
	}

	my($this_minx, $this_miny, $this_maxx, $this_maxy) = $str->bbox;
	$minx = $this_minx if !defined $minx || $this_minx < $minx;
	$miny = $this_miny if !defined $miny || $this_miny < $miny;
	$maxx = $this_maxx if !defined $maxx || $this_maxx > $maxx;
	$maxy = $this_maxy if !defined $maxy || $this_maxy > $maxy;

	$str->init;
	while(1) {
	    my $r = $str->next;
	    my $no_coords = @{ $r->[Strassen::COORDS()] };
	    last if !$no_coords;

	    if ($no_coords == 1) {
		my($x, $y) = split /,/, $r->[Strassen::COORDS()]->[0];
		($x,$y) = $trim_accuracy->($conv->($x,$y)) if $conv;
		$mif .= "Point $x $y\n";
	    } else {
		$mif .= "Pline $no_coords\n";
		for my $p (@{ $r->[Strassen::COORDS()] }) {
		    my($x, $y) = split /,/, $p;
		    ($x,$y) = $trim_accuracy->($conv->($x,$y)) if $conv;
		    $mif .= "$x $y\n";
		}
		$mif .= "    Pen (1,2,1)\n";
	    }

	    my @data_row = ("") x @column_names;
	    if (exists $field_map{"NAME"}) {
		my $data_row_inx = $field_map{"NAME"};
		$data_row[$data_row_inx] = $r->[Strassen::NAME()];
		$max_len[$data_row_inx] = length $r->[Strassen::NAME()]
		    if (!defined $max_len[$data_row_inx] ||
			$max_len[$data_row_inx] < length $r->[Strassen::NAME()]
		       );
	    }
	    if (exists $field_map{"CAT"}) {
		my $data_row_inx = $field_map{"CAT"};
		$data_row[$data_row_inx] = $r->[Strassen::CAT()];
		$max_len[$data_row_inx] = length $r->[Strassen::CAT()]
		    if (!defined $max_len[$data_row_inx] ||
			$max_len[$data_row_inx] < length $r->[Strassen::CAT()]
		       );
	    }
	    $_ =~ s/\"//g for @data_row; # XXX better solution
	    $mid .= join(",", map { qq{"$_"} } @data_row) . "\n";
	}
    }

    ($minx,$miny) = $trim_accuracy->($conv->($minx,$miny)) if $conv;
    ($maxx,$maxy) = $trim_accuracy->($conv->($maxx,$maxy)) if $conv;

    my %t_args;
    {
	my $i = 0;
	for (@column_names) {
	    $t_args{"TYPE_$_"} = "Char(" . ($max_len[$i]+1) . ")";
	    $i++;
	}
    }
    my $t = Template->new(DEBUG => 'undef');
    my $new_mif;
    $t->process(\$mif,
		{
		 minx => $minx,
		 miny => $miny,
		 maxx => $maxx,
		 maxy => $maxy,
		 %t_args,
		}, \$new_mif);

    ($new_mif, $mid);
}

=item export_datadir($data_directory, $filename, %args)

Like export(), but use a data directory instead.

=cut

sub export_datadir {
    my($data_directory, $filename, %args) = @_;
    my($mif, $mid) = create_mif_mid_from_data_directory($data_directory, %args);
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

require Getopt::Long;
my $use_datadir;
my %args;
if (!Getopt::Long::GetOptions(\%args, "o=s", "map=s", "tomap=s", "v!")) {
    die "usage!";
}
my $o = delete $args{o};
if (!defined $o) { die "-o option missing" }
my $s;
if (@ARGV == 0) {
    die "Strassen file missing";
} elsif (@ARGV == 1) {
    my $f = shift;
    if (-d $f) { # it is a data directory
	$use_datadir = 1;
	$s = $f;
    } else {
	$s = Strassen->new($f);
    }
} else {
    $s = MultiStrassen->new(@ARGV);
}
if ($use_datadir) {
    export_datadir($s, $o, %args);
} else {
    export($s, $o, %args);
}

=head1 AUTHOR

Slaven Rezic <eserte@users.sourceforge.net>

=head1 COPYRIGHT

Copyright (c) 2004 Slaven Rezic. All rights reserved.
This is free software; you can redistribute it and/or modify it under the
terms of the GNU General Public License, see the file COPYING.

=head1 SEE ALSO

L<Strassen::Core>.
