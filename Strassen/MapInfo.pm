# -*- perl -*-

#
# $Id: MapInfo.pm,v 1.17 2007/07/21 22:09:23 eserte Exp $
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
    my($class, $filename, %args) = @_;
    my $self = {};
    bless $self, $class;

    if ($filename) {
	$self->read_mif($filename, %args);
    }

    $self;
}

=item read_mif($filename)

Read a MIF file. The filename may be specified with or without the
.mif/.MIF extension.

=cut

sub read_mif {
    my($self, $filename, %args) = @_;

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
	    push @data, "$name\tX " . join(" ", @$current_record) . "\n";
	    $rec_i++;
	    $current_record = undef;
	}
    };

    if ($args{CustomPush}) {
	$push = sub {
	    if ($current_record) {
		$args{CustomPush}->($self, $current_record, $column_data, $rec_i);
		undef $current_record;
		$rec_i++;
	    }
	};
    }

    my $conv = sub { join(",",@_) };

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
		    $current_record = [$conv->($x,$y)];
		} elsif (/^\s*([-+\d\.]+)\s+([-+\d\.]+)/) {
		    push @$current_record, $conv->($1,$2);
		}
	    } elsif ($mode == MODE_COLUMNS) {
		$l =~ /^\s*(\S+)\s*(\S+)/;
		push @{ $self->{MIF_COLUMNS} }, [$1, $2];
	    } elsif ($l =~ /delimiter\s+"(.)"/i) {
		$self->{MIF_DELIMITER} = $1;
	    } elsif ($l =~ /^coordsys\s+earth\s+projection\s+1\s*,\s*0/i) {
		require Karte::Polar;
		require Karte::Standard;
		my $obj = $Karte::Polar::obj;
		$conv = sub {
		    join(",", $Karte::Standard::obj->trim_accuracy($obj->map2standard(@_)));
		};
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
	$coordsysline = qq{CoordSys Earth Projection 1, 0\n};
    }
    if (!defined $coordsysline) {
	$coordsysline = qq{CoordSys NonEarth Units "m" Bounds ($minx,$miny) ($maxx,$maxy)\n};
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
Version $version
Charset "WindowsLatin1"
Delimiter ","
${coordsysline}COLUMNS 2
  Name     Char($max_name_length)
  Category Char($max_cat_length)
Data

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
    require Storable;

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

    my $scope = $args{scope}; # undef, "city" or "region"
    if (defined $scope) {
	$scope = "region" if $scope eq "brb";
	die "Wrong scope $scope" if $scope !~ /^( city | region )$/x;
    }
    my $if_city = sub {
	!defined $scope || $scope eq 'city' ? @_ : ();
    };
    my $if_region = sub {
	!defined $scope || $scope eq 'region' ? @_ : ();
    };

    my @depend_on_master_streets =
	qw(ampeln brunnels comments_cyclepath comments_ferry
	   comments_kfzverkehr comments_misc comments_mount
	   comments_path comments_route comments_tram
	   gesperrt green hoehe nolighting
	  );
    my %depend_on_master_streets = map {($_=>1)} @depend_on_master_streets;

    my @master_streets =
	($if_city->("strassen", "plaetze"),
	 $if_region->("landstrassen", "landstrassen2"), "faehren");

    my @street_files =
	([[@master_streets], "strassen", NAME => "Name", CAT => "Category"],
	 ["ampeln", "ampeln",
	  NAME => "Trafficlight_Comment", CAT => "Traffic_Category"],
	 ["brunnels", "brunnels",
	  NAME => "Brunnel_Comment", CAT => "Brunnel_Category"],
	 [["comments_cyclepath", "radwege_exact"], "radwege",
	  NAME => "Cyclepath_Comment", CAT => "Cyclepath_Category"],
	 ["comments_ferry", "comments_ferry",
	  NAME => "Ferry_Comment", CAT => "Ferry_Category"],
	 ["comments_kfzverkehr", "comments_kfzverkehr",
	  NAME => "Traffic_Comment", CAT => "Traffic_Category"],
	 ["comments_misc", "comments_misc",
	  NAME => "Comment", CAT => "Comment_Category"],
	 ["comments_mount", "comments_mount",
	  NAME => "Mount_Comment", CAT => "Mount_Category"],
	 ["comments_path", "comments_path",
	  NAME => "Path_Comment", CAT => "Path_Category"],
	 ["comments_route", "comments_route",
	  NAME => "Route_Comment", CAT => "Route_Category"],
	 ["comments_tram", "comments_tram",
	  NAME => "Tram_Comment", CAT => "Tram_Category"],
	 ["gesperrt", "gesperrt",
	  NAME => "Blocking_Comment", CAT => "Blocking_Category"],
	 ["green", "green",
	  NAME => "Green_Comment", CAT => "Green_Category"],
	 [[$if_city->("handicap_s"), $if_region->("handicap_l")], "handicap",
	  NAME => "Handicap_Comment", CAT => "Handicap_Category"],
	 ["hoehe", "hoehe",
	  NAME => "Elevation"],
	 ["nolighting", "nolighting",
	  NAME => "Nolighting_Comment", CAT => "Nolighting_Category"],
	 [[$if_city->("qualitaet_s"), $if_region->("qualitaet_l")], "qualitaet",
	  NAME => "Quality_Comment", CAT => "Quality_Category"],
	 [["orte", "orte2"], "orte",
	  NAME => "Place_Name", NAME_ADD => "Place_AddName",
	  CAT => "Place_Category"],
	 ["sehenswuerdigkeit", "sehenswuerdigkeit",
	  NAME => "Sight_Name", CAT => "Sight_Category"],
	 # missing: vorfahrt
	);
    # Returns: strassen files, label, dest filename, mapping
    my $getdef = sub {
	my $def = Storable::dclone($_[0]);
	my @ret;
	push @ret, shift @$def;
	my $label = $ret[-1];
	$label = $label->[0] if ref $label eq 'ARRAY';
	push @ret, $label;
	push @ret, shift @$def;
	push @ret, $def;
	@ret;
    };

    my $rgb = sub {
	($_[0]<<16)+($_[1]<<8)+$_[2];
    };

    my %category_color =
	(B  => $rgb->(255,0,0), # red
	 HH => $rgb->(255,255,0),
	 H  => $rgb->(255,255,0),
	 NH => $rgb->(120,120,120),
	 N  => $rgb->(120,120,120),
	 NN => $rgb->(0,200,0),

	 Q0 => $rgb->(0,128,0),
	 q0 => $rgb->(0,128,0),
	 Q1 => $rgb->(0,180,0),
	 q1 => $rgb->(0,180,0),
	 Q2 => $rgb->(255,128,0),
	 q2 => $rgb->(255,128,0),
	 Q3 => $rgb->(255,0,0),
	 q3 => $rgb->(255,0,0),
	 Q4 => $rgb->(200,0,0),
	 q4 => $rgb->(200,0,0),
	 RW => $rgb->(0,0,200),
	);
    my $def_color = 0; # black
    my %category_width =
	(
	 B  => 4,
	 HH => 4,
	 H  => 3,
	 NH => 3,
	 N  => 3,
	 NN => 3,

	 Q0 => 2,
	 Q1 => 2,
	 Q2 => 2,
	 Q3 => 2,
	 Q4 => 2,

	 q0 => 1,
	 q1 => 1,
	 q2 => 1,
	 q3 => 1,
	 q4 => 1,

	 RW => 3,
	);
    my $def_width = 1;
    my %category_style =
	(
	 Q0 => 46,
	 Q1 => 46,
	 Q2 => 46,
	 Q3 => 46,
	 Q4 => 46,

	 # Laengs mit Querstreifen: 26

	 q0 => 46, # nur Querstreifen
	 q1 => 46,
	 q2 => 46,
	 q3 => 46,
	 q4 => 46,

	 # 3 ist dotted
	 RW => 4, # dashed (short)
	);
    my $def_style = 2; # solid
    my %category_symbol =
	("SW|IMG:airport.gif" => 52, # airport
	 "SW|IMG:hospital.gif" => 56,
	 "SW|IMG:church.gif" => 65, # church or monastir
	 0 => 66, # place or church
	 1 => 66, # place or church
	 2 => 66, # place or church
	 3 => 66, # place or church
	 4 => 66, # place or church
	 5 => 66, # place or church
	 6 => 66, # place or church
	);
    my $def_symbol = 35; # star
    my %category_fontsize =
	(
	);
    my $def_fontsize = 12;

    my $mid = "";
    my $mif = "";
    my %mid;
    my %mif;

    my %column_to_index;
    my @column_names;

    my $onefile = $args{onefile} || 0;
    if ($onefile) {
	# single output file
	@column_names =
	    qw(Name Category
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
	       Place_Name Place_AddName Place_Category
	       Sight_Name Sight_Category
	      );
	# XXX missing columns: Author, AcquireAuthor,CreationDate, AcquireDate
	{
	    my $i = 0;
	    for (@column_names) {
		$column_to_index{$_} = $i;
		$i++;
	    }
	}

	$mif = <<EOF;
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
    } else {
	# multiple output files
	for my $def (@street_files) {
	    my(undef, $label, undef, $field_map_ref) = $getdef->($def);
	    my @field_map = @$field_map_ref;
	    my %field_map = @field_map;
	    $mif{$label} = <<EOF;
VERSION $version
CHARSET "WindowsLatin1"
DELIMITER ","
${coordsysline}COLUMNS @{[ scalar values %field_map ]}
EOF
	    for(my $i = 1; $i <= $#field_map; $i+=2) {
		my $column = $field_map[$i];
		$mif{$label} .= <<EOF;
  $column [% TYPE_${column} %]
EOF
	    }
	    $mif{$label} .= <<EOF;
DATA

EOF

	    $mid{$label} = "";
	}
    }

    my($minx,$miny,$maxx,$maxy);
    my %max_len;

    my $master_s = MultiStrassen->new(@master_streets);
    require Strassen::StrassenNetz;
    my $master_net = StrassenNetz->new($master_s);
    eval { require BBBikeXS };
    $master_net->make_net;
    my $net = $master_net->{Net};
#XXX use Data::Dumper;open(X,">/tmp/bla.dump")or die;print X Dumper $net; close X;

 FILELOOP:
    for my $def (@street_files) {
	my($file, $label, undef, $field_map_ref) = $getdef->($def);
	my @field_map = @$field_map_ref;
	my %field_map = @field_map;
	if ($onefile) {
	    while(my($k,$v) = each %field_map) {
		my $inx = $column_to_index{$v};
		if (!defined $inx) {
		    warn "Cannot find index for $v, skipping"; # XXX should die some day
		    next FILELOOP;
		}
		$field_map{$k} = $inx;
	    }
	} else {
	    @column_names = ();
	    my $inx = 0;
	    for(my $i = 0; $i <= $#field_map; $i+=2) {
		$field_map{$field_map[$i]} = $inx;
		push @column_names, $field_map[$i+1];
		$inx++;
	    }
	}

	my $str;
	my $do_depend = 0;
	if (ref $file eq 'ARRAY') {
	    my @s;
	    for my $file (@$file) {
		eval {
		    push @s, Strassen->new($file);
		    $do_depend++ if ($depend_on_master_streets{$file});
		};
		if ($@) {
		    warn "$@, skipping $file";
		}
	    }
	    if (!@s) {
		warn "No file found, skipping MultiStrassen completely...";
		next;
	    }
	    $str = MultiStrassen->new(@s);
	    if ($args{v}) { print STDERR "@$file...\n" }
	} else {
	    eval {
		$str = Strassen->new($file);
		$do_depend++ if ($depend_on_master_streets{$file});
		if ($args{v}) { print STDERR "$file...\n" }
	    };
	    if (!$str) {
		warn "$@, skipping $file...";
		next;
	    }
	}

	if ($do_depend) {
	    print STDERR "  Dependency check for $label...\n" if $args{v};
	    my $new_str = Strassen->new;
	    $str->init;
	    while(1) {
		my $r = $str->next;
		my $coords = $r->[Strassen::COORDS()];
		last if !@$coords;
		if (@$coords == 1) {
		    if (exists $net->{$coords->[0]}) {
			$new_str->push($r);
		    }
		} else {
		    for my $i (0 .. $#$coords-1) {
			if ((exists $net->{$coords->[$i]} &&
			     exists $net->{$coords->[$i]}{$coords->[$i+1]}) ||
			    (exists $net->{$coords->[$i+1]} &&
			     exists $net->{$coords->[$i+1]}{$coords->[$i]})) {
			    $new_str->push($r);
			    last;
			}
		    }
		}
	    }
	    $str = $new_str;
	}

	my($this_minx, $this_miny, $this_maxx, $this_maxy) = $str->bbox;
	$minx = $this_minx if !defined $minx || $this_minx < $minx;
	$miny = $this_miny if !defined $miny || $this_miny < $miny;
	$maxx = $this_maxx if !defined $maxx || $this_maxx > $maxx;
	$maxy = $this_maxy if !defined $maxy || $this_maxy > $maxy;

	my $out_mif = $onefile ? \$mif : \$mif{$label};
	my $out_mid = $onefile ? \$mid : \$mid{$label};

	$str->init;
	while(1) {
	    my $r = $str->next;
	    my $coords = $r->[Strassen::COORDS()];
	    my $no_coords = @$coords;
	    last if !$no_coords;

	    my $cat = $r->[Strassen::CAT()];
	    my $name = $r->[Strassen::NAME()];
	    my $addname;
	    if ($name =~ /(.*)\|(.*)/) {
		($name, $addname) = ($1, $2);
	    }

	    if ($no_coords == 1) {
		my($x, $y) = split /,/, $coords->[0];
		($x,$y) = $trim_accuracy->($conv->($x,$y)) if $conv;
		$$out_mif .= "Point $x $y\n";

		my $color = $category_color{$cat};
		$color = $def_color if !defined $color;
		my $symbol = $category_symbol{$cat};
		$symbol = $def_symbol if !defined $symbol;
		my $fontsize = $category_fontsize{$cat};
		$fontsize = $def_fontsize if !defined $fontsize;

		$$out_mif .= "    Symbol ($symbol,$color,$fontsize)\n";
	    } elsif ($cat =~ /^F:(.*)/) {
		$cat = $1;

		$$out_mif .= "Region 1\n  $no_coords\n";
		for my $p (@$coords) {
		    my($x, $y) = split /,/, $p;
		    ($x,$y) = $trim_accuracy->($conv->($x,$y)) if $conv;
		    $$out_mif .= "$x $y\n";
		}

		my $color = $category_color{$cat};
		$color = $def_color if !defined $color;
		if ($cat =~ /^#(..)(..)(..)/) {
		    $color = $rgb->(hex($1), hex($2), hex($3));
		}

		$$out_mif .= "    Pen (1,2,0)\n";
		$$out_mif .= "    Brush (2,$color,16777215)\n"; # solid fill

	    } else {
		$$out_mif .= "Pline $no_coords\n";
		for my $p (@$coords) {
		    my($x, $y) = split /,/, $p;
		    ($x,$y) = $trim_accuracy->($conv->($x,$y)) if $conv;
		    $$out_mif .= "$x $y\n";
		}

		my $color = $category_color{$cat};
		$color = $def_color if !defined $color;
		my $style = $category_style{$cat};
		$style = $def_style if !defined $style;
		my $width = $category_width{$cat};
		$width = $def_width if !defined $width;

		$$out_mif .= "    Pen ($width,$style,$color)\n";
	    }

	    my @data_row = ("") x @column_names;
	    if (exists $field_map{"NAME"}) {
		my $data_row_inx = $field_map{"NAME"};
		my $column_name = $column_names[$data_row_inx];
		$data_row[$data_row_inx] = $name;
		$max_len{$column_name} = length $name
		    if (!exists $max_len{$column_name} ||
			$max_len{$column_name} < length $name
		       );
	    }
	    if (exists $field_map{"NAME_ADD"}) {
		my $data_row_inx = $field_map{"NAME_ADD"};
		my $column_name = $column_names[$data_row_inx];
		$data_row[$data_row_inx] = $addname;
		$max_len{$column_name} = length $addname
		    if (!exists $max_len{$column_name} ||
			$max_len{$column_name} < length $addname
		       );
	    }
	    if (exists $field_map{"CAT"}) {
		my $data_row_inx = $field_map{"CAT"};
		my $column_name = $column_names[$data_row_inx];
		$data_row[$data_row_inx] = $cat;
		$max_len{$column_name} = length $cat
		    if (!exists $max_len{$column_name} ||
			$max_len{$column_name} < length $cat
		       );
	    }
	    $_ =~ s/\"//g for @data_row; # XXX better solution
	    $$out_mid .= join(",", map { qq{"$_"} } @data_row) . "\n";
	}
    }

    ($minx,$miny) = $trim_accuracy->($conv->($minx,$miny)) if $conv;
    ($maxx,$maxy) = $trim_accuracy->($conv->($maxx,$maxy)) if $conv;

    my %t_args;
    while(my($key) = each %max_len) {
	$t_args{"TYPE_$key"} = "Char(" . ($max_len{$key}+1) . ")";
    }
    my $t = Template->new(DEBUG => 'undef');
    my $new_mif;
    my %new_mif;
    my %new_mid;
    my %tpl_vars = (minx => $minx,
		    miny => $miny,
		    maxx => $maxx,
		    maxy => $maxy,
		    %t_args,
		   );

    if ($onefile) {
	$t->process(\$mif, { %tpl_vars }, \$new_mif)
	    or warn $t->error;
    } else {
	for my $def (@street_files) {
	    my(undef, $label, $destfile, undef) = $getdef->($def);
	    $new_mif{$destfile} = "";
	    $t->process(\$mif{$label}, { %tpl_vars }, \$new_mif{$destfile})
		or warn $t->error;
	    $new_mid{$destfile} = $mid{$label};
	}
    }

    if ($onefile) {
	($new_mif, $mid);
    } else {
	(\%new_mif, \%new_mid);
    }
}

=item export_datadir($data_directory, $filename, %args)

Like export(), but use a data directory instead.

=cut

sub export_datadir {
    my($data_directory, $filename, %args) = @_;
    my($mif, $mid) = create_mif_mid_from_data_directory($data_directory, %args);
    if (ref $mif eq 'HASH') {
	while(my($file, $data) = each %$mif) {
	    my $mid_data = $mid->{$file};
	    if ($mid_data eq "") {
		warn "MID for $file is empty, skipping...\n";
		next;
	    }
	    open(MIF, ">${filename}_${file}.MIF") or die "Can't create ${filename}_${file}.MIF: $!";
	    print MIF $data;
	    close MIF;

	    open(MID, ">${filename}_${file}.MID") or die "Can't create ${filename}_${file}.MID: $!";
	    print MID $mid_data;
	    close MID;
	}
    } else {
	open(MIF, ">$filename.MIF") or die "Can't create $filename.MIF: $!";
	print MIF $mif;
	close MIF;
	open(MID, ">$filename.MID") or die "Can't create $filename.MID: $!";
	print MID $mid;
	close MID;
    }
}

=back

=cut

# XXX Hack: autoloader does not work for inherited methods
for my $method (qw(get_anti_conversion)) {
    my $code = 'sub ' . $method . ' { shift->Strassen::' . $method . '(@_) }';
    #warn $code;
    eval $code;
    die "$code: $@" if $@;
}

return 1 if caller;

require Getopt::Long;
my $use_datadir;
my %args;
if (!Getopt::Long::GetOptions(\%args, "o=s", "scope=s", "onefile!", "map=s", "tomap=s", "v!")) {
    die "usage!";
}
my $o = delete $args{o};
if (!defined $o) { die "-o option missing" }
my $s;
if (@ARGV == 0) {
    die "Strassen file missing";
} elsif (@ARGV == 1) {
    my $f = shift;
    if ($f =~ /\.(mi[fd])$/) {
	my $mi = Strassen::MapInfo->new($f);
	$mi->{GlobalDirectives}{map} = $args{map} if $args{map};
	$mi->write($o);
	exit(0);
    } elsif (-d $f) { # it is a data directory
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

=head1 EXAMPLES

Example usage from command line:

    perl -Ilib Strassen/MapInfo.pm -o /tmp/brb -scope region -tomap polar -v data_corrected/

Converting a mapinfo file into a bbd file:

    perl -Ilib -MStrassen::MapInfo -MKarte -MKarte::Polar -e '$s = Strassen->new($ARGV[0]); $s->write($ARGV[1])' mapinfofile bbdfile

=head1 AUTHOR

Slaven Rezic <eserte@users.sourceforge.net>

=head1 COPYRIGHT

Copyright (c) 2004 Slaven Rezic. All rights reserved.
This is free software; you can redistribute it and/or modify it under the
terms of the GNU General Public License, see the file COPYING.

=head1 SEE ALSO

L<Strassen::Core>.
