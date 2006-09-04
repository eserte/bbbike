# -*- perl -*-

#
# $Id: Ovl.pm,v 1.16 2006/09/04 23:02:48 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://bbbike.sourceforge.net
#

package GPS::Ovl;

use strict;
use vars qw($VERSION @ISA $OVL_MAGIC $OVL_MAGIC_3_0 $OVL_MAGIC_4_0);
$VERSION = sprintf("%d.%02d", q$Revision: 1.16 $ =~ /(\d+)\.(\d+)/);

require File::Basename;

require GPS;
push @ISA, 'GPS';

$OVL_MAGIC     = "DOMGVCRD Ovlfile V2.0:";
$OVL_MAGIC_3_0 = "DOMGVCRD Ovlfile V3.0:";
$OVL_MAGIC_4_0 = "DOMGVCRD Ovlfile V4.0:";

BEGIN {
    if (!eval '
use Msg qw(frommain);
1;
') {
	warn $@ if $@;
	eval 'sub M ($) { $_[0] }';
	eval 'sub Mfmt { sprintf(shift, @_) }';
    }
}

use vars qw($color_mapping);
$color_mapping = 
    {1 => 'red',
     2 => 'green',
     3 => 'blue',
     4 => 'yellow',
     5 => 'black',
     6 => 'white',
     8 => 'pink',
     9 => 'lightblue',
    };

sub check {
    my($self_or_class, $file, %args) = @_;
    my $self;
    if ($self_or_class eq __PACKAGE__ || !UNIVERSAL::isa($self_or_class, __PACKAGE__)) { # static operation
	$self = $self_or_class->new($file);
    } else {
	$self = $self_or_class;
	$self->{File} = $file;
    }
    delete $self->{FileFormat};
    open(F, $file) or die "Can't open file $file: $!";
    my $first_line = <F>;
    if ($first_line =~ /^\[Symbol/) {
	$self->{FileFormat} = "ascii";
    } elsif (index($first_line, $OVL_MAGIC) == 0) {
	$self->{FileFormat} = "binary";
    } elsif (index($first_line, $OVL_MAGIC_3_0) == 0) {
	$self->{FileFormat} = "binary_3_0";
    } elsif (index($first_line, $OVL_MAGIC_4_0) == 0) {
	die "No support for OVL file format 4.0";
	$self->{FileFormat} = "binary_4_0";
    } else {
	warn "Cannot determine file format. First bytes: " . unpack("H*", $first_line) . "\n"
	    if $args{debug};
    }
    close F;
    defined $self->{FileFormat};
}

sub convert_to_route {
    my($class, $file, %args) = @_;
    my $self = $class->new($file);
    require GPS::GpsmanData;
    require File::Temp;
    my($fh,$tmpfile) = File::Temp::tempfile(UNLINK => 1,
					    SUFFIX => ".trk");
    print $fh $self->convert_to_gpsman;
    close $fh;
    my @res = GPS::GpsmanData->convert_to_route($tmpfile, %args);
    unlink $tmpfile;
    @res;
}

sub convert_to_gpsman {
    my $self = shift;

    $self->read;

    my $out = <<EOF;
% Written by $0 @{[ scalar localtime ]}
% Edit at your own risk!

!Format: DDD 1 WGS 84
!Creation: yes

EOF
    my $last_type;
    foreach my $sym (@{$self->{Symbols}}) {
	next unless $sym->{Coords};
	if ($sym->{Coords} == 1) {
	    if (!defined $last_type || $last_type ne "W") {
		$out .= "!W:\n";
		$last_type = "W";
	    }
	    my($long, $lat) = $sym->{Coords}[0];
	    $lat  = ($lat < 0 ? "S" : "N") . $lat;
	    $long = ($long < 0 ? "W" : "E") . $long;
	    my $text = $sym->{Label} || $sym->{Text} || "";
	    $text = substr($text, 0, 10);
	    $out .= sprintf "%s\t\t%s\t%s\n", $text, $lat, $long;
	} else {
	    my $filename = $self->{File} ? File::Basename::basename($self->{File}) : "unknown";
	    my $name = $sym->{Label} || $sym->{Text} || "TRACK ($filename)";
	    $name = $filename if $name =~ m{^Linie$};
	    if (!defined $last_type || $last_type ne 'T') {
		$out .= "!T:\t$name\n";
		$last_type = "T";
	    }
	    for my $c (@{ $sym->{Coords} }) {
		my($long, $lat) = @$c;
		$lat  = ($lat < 0 ? "S" : "N") . $lat;
		$long = ($long < 0 ? "W" : "E") . $long;
		my $date = "31-Dec-1989 01:00:00"; # XXX
		my $elevation = 0; # XXX
		$out .= sprintf "\t%s\t%s\t%s\t%s\n", $date, $lat, $long, $elevation;
	    }
	}
    }
    $out .= "\n";

    $out;
}

sub new {
    my($class, $file) = @_;
    my $self = $class->SUPER::new();
    $self->{File} = $file;
    $self;
}

sub read {
    my($self, %args) = @_;

    if (!UNIVERSAL::isa($self, "HASH") || !defined $self->{FileFormat}) {
	my $ret = $self->check($self->{File});
	return if !$ret;
    }

    if (defined $self->{FileFormat}) {
	my $method = "read_" . $self->{FileFormat};
	return $self->$method(%args);
    }
}

sub read_ascii {
    my($self) = @_;
    my @symbols;
    my $sym;
    my @coords;
    my $xkoord;

    my $flush = sub {
	if ($sym) {
	    $sym->{Coords} = [@coords] if @coords;
	    push @symbols, $sym if $sym && keys %$sym;
	    undef $sym;
	}
	@coords = ();
    };

    open(F, $self->{File}) or die "Can't open file $self->{File}: $!";
    while(<F>) {
	chomp;
	s/\r//;
	if (/\[Symbol/) {
	    $flush->();
	    $sym = {};
#XXX del:
#  	} elsif (/^\s*$/) {
#  	    $flush->();
	} elsif ($sym) {
	    if (/^XKoord\d+=(.*)$/) {
		$xkoord = $1;
	    } elsif (/^YKoord\d+=(.*)$/) {
		push @coords, [$xkoord, $1];
		undef $xkoord;
	    } elsif (/^Text=(.*)$/) {
		$sym->{Text} = $1;
	    } elsif (/^Col=(\d+)$/) {
		my $color = $color_mapping->{$1};
		$sym->{Color} = $color if defined $color;
	    }
	}
    }
    close F;
    $flush->();

    $self->{Symbols} = \@symbols;
}

sub as_string_ascii {
    my($self, $coords, %args) = @_;
    my $s = "";
    my $coord_i = 0;
    for my $coord (@$coords) {
	my($x,$y) = @$coord;
	$s .= "[Symbol ${coord_i}]\n";
	$s .= "XKoord${coord_i}=$x\n";
	$s .= "YKoord${coord_i}=$y\n";
	$coord_i++;
    }
    $s;
}

{
    my $p;
    my $buf;

    my $_forward = sub {
	my($count) = @_;
	$p += $count;
    };

    my $_seek_to = sub {
	my($to) = @_;
	$p = $to;
    };

    my $_read_float = sub {
	my $float = unpack("d", substr($buf, $p, 8));
	$p+=8;
	$float;
    };

    my $_read_long = sub {
	my $long = unpack("l", substr($buf, $p, 4)); # XXX l = native
	$p+=4;
	$long;
    };

    my $_read_uchar = sub {
	my $uchar = unpack("C", substr($buf, $p, 1));
	$p+=1;
	$uchar;
    };

    my $_read_short = sub {
	my $short = unpack("s", substr($buf, $p, 2)); # XXX s = native
	$p+=2;
	$short;
    };

    my $_read_ushort = sub {
	my $ushort = unpack("S", substr($buf, $p, 2)); # XXX S = native
	$p+=2;
	$ushort;
    };

    my $_read_coords = sub {
	my $len = &$_read_short;
	my @coords;
	for (1..$len) {
	    my($x, $y) = (&$_read_float, &$_read_float);
	    push @coords, [$x,$y];
	}
	@coords;
    };

    my $_read_coords_3_0 = sub {
	my $len = &$_read_short;
	my @coords;
	for (1..$len) {
	    my($x, $y, $z) = (&$_read_float, &$_read_float, &$_read_float);
	    #warn $z; # XXX tatsächlich die Höhe?
	    push @coords, [$x,$y];
	}
	@coords;
    };

    my $_read_coord = sub {
	[&$_read_float, &$_read_float];
    };

    my $_read_string = sub {
	for(my $pi=$p; $pi<length $buf; $pi++) {
	    if (ord substr($buf, $pi, 1) == 0) {
		my $res = substr($buf, $p, $pi-$p);
		$p = $pi+1;
		return $res;
	    }
	}
	my $res = substr($buf, $p);
	$p = length $buf;
	$res;
    };

    my $_read_fixed_string = sub {
	my $len = &$_read_short;
	my $res = substr($buf, $p, $len);
	$p += $len;
	$res;
    };

    my $_read_long_fixed_string = sub {
	my $len = &$_read_long;
	my $res = substr($buf, $p, $len);
	$res =~ s{\0$}{}; # probably at end...
	$p += $len;
	$res;
    };

    my $_read_short_or_long_fixed_string = sub {
	my $len = &$_read_short;
	if ($len) {
	    my $res = substr($buf, $p, $len);
	    $p += $len;
	    ($res, "short");
	} else {
	    my $x = &$_read_short;
	    warn "$x != 0x10" if $x != 0x10;
	    $len = &$_read_long;
	    my $res = substr($buf, $p, $len);
	    $res =~ s{\0$}{}; # probably at end...
	    $p += $len;
	    ($res, "long");
	}
    };

#  rot: gut zu fahrende Straßen mit max. mäßiger Verkehrsdichte. Auch asphaltierte autofreie Wege
#  grün: befahrbare aber nicht asphaltierte Feld und Waldwege
#  gelb: rel. verkehrsreiche Straßen, aber wichtige Strecke
#  blau: schlechte Straße, Kopfsteinpflaster
#  schwarz, dünne Zick-Zack Linie: unbefahrbarer Weg
#  weiß: Bundesstraße, keine Bewertung, nur zum Abdecken des Kartenuntergrundes 
#  verwendet
    sub read_binary {
	my($self, %args) = @_;
	my $d = $args{debug};

	open(F, $self->{File}) or die "Can't open file $self->{File}: $!";
	binmode F;
	local $/ = undef;
	$buf = <F>;
	close F;

	$p = 0;

	my $magic = &$_read_string;
	if ($magic ne $OVL_MAGIC) {
	    die "Wrong magic: $magic\n";
	}
	$_forward->(6);
	my $MapName = &$_read_string;
	warn "Description: $MapName\n" if $d;
	$_seek_to->(0x3d);
	my $DimmFc = &$_read_long;
	my $ZoomFc = &$_read_long;
	my $CenterLat  = &$_read_float; # XXX verdrehen? siehe binary_3_0
	my $CenterLong = &$_read_float;
	warn "Center=$CenterLat/$CenterLong\n" if $d;
	$_seek_to->(0xa9);

	my @symbols;
#my$trace=0;my$abort=0;
	while($p < length $buf) {
#if($trace){while(!$abort){sleep 1}$abort=0}
	    my $sym = {};
	    my $type = &$_read_short;
	    $sym->{Type} = $type;
	    if ($type == 3) {
		my @x;
		push @x, &$_read_short for 1..6;#print "\n";
		#XXXwarn "Type 3, x=@x";
		$sym->{Coords} = [&$_read_coords];
		my $color = $color_mapping->{$x[3]};
		push @x, $color;
		$sym->{Balloon} = "@x";
		$sym->{Color} = $color if defined $color;
	    } elsif ($type == 2) {
		#print "$type ";printf "%04x ", &$_read_short for 1..7;print "\n";
		my @x;
		push @x, &$_read_short for 1..2;
		my $subtype = &$_read_short;
		if ($subtype == 1) {
		    # NOP
		} elsif ($subtype == 0x10) {
		    push @x, &$_read_short for 1..2;
		    $sym->{Text} = &$_read_string;
		} else {
		    warn "Unknown subtype=$subtype p=".sprintf("%x",$p);
		    last;
		}
		push @x, &$_read_short for 1..4;
		warn "Type 2, x=@x" if $d;
		$sym->{Coords} = [&$_read_coords];
		$sym->{Label} = &$_read_fixed_string;

	    } elsif ($type == 6) {
		my @x;
		push @x, &$_read_short for 1..2;
		my $subtype = &$_read_short;
		if ($subtype == 1) {
		    # NOP
		} elsif ($subtype == 0x10) {
		    push @x, &$_read_short for 1..2;
		    $sym->{Text} = &$_read_string;
		} else {
		    warn "Unknown subtype=$subtype p=".sprintf("%x",$p);
		    last;
		}
		#print "X ";printf "%04x ", 
		push @x, &$_read_short for 1..6;#print "\n";
		warn "Type 6, x=@x" if $d;
		$sym->{Coords} = [&$_read_coord];
	    } else {
		warn "Unknown type=$type p=".sprintf("%x",$p);
		last;
	    }
	    push @symbols, $sym;
	    if ($d) {
		require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([$sym],[qw()])->Indent(1)->Useqq(1)->Dump
	    }
	}

	$self->{Symbols} = \@symbols;
    }

    sub read_binary_3_0 {
	my($self, %args) = @_;
	my $d = $args{debug};

	open(F, $self->{File}) or die "Can't open file $self->{File}: $!";
	binmode F;
	local $/ = undef;
	$buf = <F>;
	close F;

	$p = 0;

	my $magic = &$_read_string;
	if ($magic ne $OVL_MAGIC_3_0) {
	    die "Wrong magic: $magic\n";
	}
	$_seek_to->(0x27);
	my $ArbeitsLage = &$_read_fixed_string;
	warn "Arbeitslage: $ArbeitsLage\n" if $d;

	$_seek_to->(0x44);
	my $MapName = &$_read_string;
	warn "MapName: $MapName\n" if $d;

	$_seek_to->(0x163);
	my $DimmFc = &$_read_long;
	my $ZoomFc = &$_read_long;
	my $CenterLong = &$_read_float;
	my $CenterLat = &$_read_float;
	my $XXXLong = &$_read_float;
	my $XXXLat = &$_read_float;
	if ($d) {
	    warn "Center (long/lat)=$CenterLong/$CenterLat\n";
	    warn "XXX (long/lat)=$XXXLong/$XXXLat\n";
	    warn "DimmFC=$DimmFc, ZoomFC=$ZoomFc\n";
	}
	# next bytes (from 0x018b) seem to be always:
	#   ff 00 00 00 3a 00 06 00 01 00 05 00 00 00 00 00
	# following six varying bytes  (from 0x019b)

	$_seek_to->(0x19f);
	my @symbols;
	my %group_numbers;
	while ($p < length $buf) {
	    my $sym = {};
	    my $type = &$_read_ushort;
	    $sym->{Type} = $type;
	    $sym->{Pos} = $p-2;
	    if ($type == 0xbae4 || # ?
		$type == 0xb91c || # ?
		$type == 0xb55c || # ?
		$type == 0xbb2c || # mtbstrecke2003msymbol.ovl
		$type == 0xbae0 || # strfrankenfels2005tats.ovl
		0) {
		my @x;
		push @x, &$_read_short for 1..13;
		warn "$x[0] != 0x14" if $x[0] != 0x14;
		warn "$x[1] != 0" if $x[1] != 0;
		warn "$x[2] != 0x1e" if $x[2] != 0x1e;
		$sym->{GroupNumber} = $x[3];
		$group_numbers{$x[3]}++; if ($group_numbers{$x[3]} > 1) { warn "Multiple group number $x[3]?" }
		$sym->{Text} = &$_read_fixed_string;
		&$_read_short for 1..2;
	    } elsif ($type == 23|| # 0x17, found in mv01.ovl
		     $type == 3||
		     0) {
		my @x;
		push @x, &$_read_short for 1..9;
		if (0) {
		    warn "$x[0] != 0x24/1/2/3/6/7/22/26/42" if $x[0] != 0x24 && $x[0] !~ /^(1|2|3|6|7|22|26|42)$/; # Gruppe? ja, scheint so, weil die nächste Abfrage funktioniert
		}
		warn "$x[0] is not a group number" if !exists $group_numbers{$x[0]} && $x[0] != 1; # 1 is special???
		warn "$x[8] != 2/1/2050" if $x[8] !~ /^(1|2|2050)$/;
		my $string_type = &$_read_short;
		($sym->{TypeText}, $type) = &$_read_short_or_long_fixed_string;
		if ($type eq 'short') {
		    &$_read_short for 1..10;
		} elsif ($type eq 'long') {
		    &$_read_short for 1..9;
		} else {
		    die "unknown type $type";
		}
		$sym->{Coords} = [&$_read_coords_3_0];
	    } elsif ($type == 2|| # found in mv13.ovl
		     0) {
		my @x;
		push @x, &$_read_short for 1..10;
		warn "$x[0] != 1" if $x[0] !~ /^(1)$/;
		warn "$x[8] != 1/4098/4097" if $x[8] !~ /^(1|4098|4097)$/;
		$sym->{TypeText} = &$_read_fixed_string;
		&$_read_short for 1..12;
		$sym->{Coords} = [&$_read_coord];
		my @z;
		push @z, &$_read_uchar for 1..8;
		if (0) {	# zu viele Ausnahmen ...
		    my $z_str = join(" ", map { sprintf "%02x", $_ } @z);
		    warn "$z_str != 20 04 00 00 2c 00 76 81
                        30 00 00 00 02 00 e7 77
                        d1 d3 fc 08 ae d8 49 40
                        00 00 90 1d a5 de 49 40
                        08 25 00 00 8b 01 e8 77
			6d a7 44 d5 1c fd 47 40
                        "
			if $z_str !~ /^(20 04 00 00 2c 00 76 81|30 00 00 00 02 00 e7 77|d1 d3 fc 08 ae d8 49 40|00 00 90 1d a5 de 49 40|08 25 00 00 8b 01 e8 77|6d a7 44 d5 1c fd 47 40)$/;
		}
		$sym->{Label} = &$_read_fixed_string;
	    } elsif ($type == 6|| # found in Dors.ovl (gps track/waypoints?)
		     0) {
		my @x;
		push @x, &$_read_short for 1..10;
		my $x_str = join(" ", map { sprintf "%04x", $_ } @x);
		warn "$x_str != 0001 0000 0000 0000 0000 0000 0000 0000 1001 0000/0001 0000 0000 0000 0000 0000 0000 0000 0001 0000"
		    if $x_str !~ /^(0001 0000 0000 0000 0000 0000 0000 0000 1001 0000|0001 0000 0000 0000 0000 0000 0000 0000 0001 0000)$/;
		my $string_type = $x[8];
		if ($string_type == 0x1001) { # only high nibble significant???
		    &$_read_short for 1..2;
		    $sym->{Label} = &$_read_long_fixed_string;
		} else {	# 0x0001
		    $sym->{Label} = &$_read_fixed_string;
		    &$_read_short for 1..1;
		}
		my @y;
		push @y, &$_read_uchar for 1..30;
		my $y_str = join(" ", map { sprintf "%02x", $_ } @y);
		warn "$y_str != 01 00 00 00 2c 00 00 00 1e 00 ff 00 00 80 10 00 00 00 10 00 00 00 01 00 00 00 65 00 02 00
                        01 00 00 00 2c 00 00 00 1e 00 80 00 00 80 10 00 00 00 10 00 00 00 01 00 00 00 65 00 02 00"
		    if $y_str !~ /^(01 00 00 00 2c 00 00 00 1e 00 ff 00 00 80 10 00 00 00 10 00 00 00 01 00 00 00 65 00 02 00|01 00 00 00 2c 00 00 00 1e 00 80 00 00 80 10 00 00 00 10 00 00 00 01 00 00 00 65 00 02 00)$/;
		$sym->{Coords} = [&$_read_coord];

		my @z;
		push @z, &$_read_uchar for 1..8;
		my $z_str = join(" ", map { sprintf "%02x", $_ } @z);
		warn "$z_str != 00 00 00 00 b0 b8 e7 00" if $z_str ne "00 00 00 00 b0 b8 e7 00";
	    } elsif ($type == 9|| # Bitmap, found in mtbstrecke2003msymbol.ovl
		     0) {
		my @x;
		push @x, &$_read_uchar for 1..20;
		my $x_str = join(" ", map { sprintf "%02x", $_ } @x);
		warn "$x_str != 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 02 00 00 00"
		    if $x_str !~ /^(01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 02 00 00 00)$/;
		$sym->{TypeText} = &$_read_fixed_string;
		my @y;
		push @y, &$_read_uchar for 1..24;
		if (0) {	# zu viele Ausnahmen
		    my $y_str = join(" ", map { sprintf "%02x", $_ } @y);
		    # XXX hier breite/höhe kodiert?
		    warn "$y_str != 01 00 01 00 a0 cf 2a 00 00 00 1e 00 02 00 05 00 0f 00 00 00 0f 00 00 00
	                01 00 01 00 a0 cf 2a 00 00 00 1e 00 02 00 05 00 10 00 00 00 0f 00 00 00
			01 00 01 00 a0 cf 2a 00 00 00 1e 00 02 00 05 00 0b 00 00 00 0d 00 00 00
                        01 00 01 00 a0 cf 2a 00 00 00 1e 00 02 00 05 00 0b 00 00 00 0d 00 00 00
			01 00 01 00 a0 cf 2a 00 00 00 1e 00 02 00 05 00 0e 00 00 00 0e 00 00 00
			01 00 01 00 a0 cf 2a 00 00 00 1e 00 02 00 05 00 0c 00 00 00 0f 00 00 00
			01 00 01 00 a0 cf 2a 00 00 00 1e 00 02 00 05 00 12 00 00 00 11 00 00 00
            "
			if $y_str !~ /^(01 00 01 00 a0 cf 2a 00 00 00 1e 00 02 00 05 00 0f 00 00 00 0f 00 00 00|01 00 01 00 a0 cf 2a 00 00 00 1e 00 02 00 05 00 10 00 00 00 0f 00 00 00|01 00 01 00 a0 cf 2a 00 00 00 1e 00 02 00 05 00 0b 00 00 00 0d 00 00 00|01 00 01 00 a0 cf 2a 00 00 00 1e 00 02 00 05 00 0e 00 00 00 0e 00 00 00|01 00 01 00 a0 cf 2a 00 00 00 1e 00 02 00 05 00 0c 00 00 00 0f 00 00 00|01 00 01 00 a0 cf 2a 00 00 00 1e 00 02 00 05 00 12 00 00 00 11 00 00 00)$/;
		}

		$sym->{Coords} = [&$_read_coord];

		my @z;
		push @z, &$_read_uchar for 1..8;
		my $z_str = join(" ", map { sprintf "%02x", $_ } @z);
		warn "$z_str != 08 25 00 00 8b 01 e8 77
			9a 16 7b 40 3a ff 47 40
			7c a6 37 60 a8 fd 47 40
			72 00 f8 82 06 fd 47 40
			a2 37 00 3d fc fe 47 40
			f0 27 00 00 aa 01 83 7c
			d0 1a 00 00 1e 01 83 7c"
		    if $z_str !~ /^(08 25 00 00 8b 01 e8 77|9a 16 7b 40 3a ff 47 40|7c a6 37 60 a8 fd 47 40|72 00 f8 82 06 fd 47 40|a2 37 00 3d fc fe 47 40|f0 27 00 00 aa 01 83 7c|d0 1a 00 00 1e 01 83 7c)$/;

		my $bitmap_length = &$_read_long;
		&$_read_uchar for 1 .. $bitmap_length + 2; # XXX why +2?
	    } elsif ($type == 7|| # Dreieck, found in mtbstrecke2003msymbol.ovl
		     0) {
		my @x;
		push @x, &$_read_uchar for 1..20;
		my $x_str = join(" ", map { sprintf "%02x", $_ } @x);
		warn "$x_str != 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 02 10 00 00"
		    if $x_str !~ /^(01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 02 10 00 00)$/;
		$sym->{TypeText} = &$_read_fixed_string;
		my @y;
		push @y, &$_read_uchar for 1..26;
		if (0) {	# zu viele Ausnahmen
		    my $y_str = join(" ", map { sprintf "%02x", $_ } @y);
		    warn "$y_str != 01 00 01 00 00 00 2c 00 00 00 1e 00 ff 00 00 80 1b 00 00 00 08 00 00 00 01 00
			01 00 01 00 00 00 2c 00 00 00 1e 00 ff 00 00 80 1b 00 00 00 07 00 00 00 01 00
			01 00 01 00 00 00 2c 00 00 00 1e 00 ff 00 00 80 1b 00 00 00 05 00 00 00 01 00
			01 00 01 00 00 00 2c 00 00 00 1e 00 00 00 ff 80 0c 00 00 00 03 00 00 00 01 00
			01 00 01 00 00 00 2c 00 00 00 1e 00 00 00 ff 80 0c 00 00 00 03 00 00 00 01 00
"
			if $y_str !~ /^(01 00 01 00 00 00 2c 00 00 00 1e 00 ff 00 00 80 1b 00 00 00 08 00 00 00 01 00|01 00 01 00 00 00 2c 00 00 00 1e 00 ff 00 00 80 1b 00 00 00 07 00 00 00 01 00|01 00 01 00 00 00 2c 00 00 00 1e 00 ff 00 00 80 1b 00 00 00 05 00 00 00 01 00|01 00 01 00 00 00 2c 00 00 00 1e 00 00 00 ff 80 0c 00 00 00 03 00 00 00 01 00|01 00 01 00 00 00 2c 00 00 00 1e 00 00 00 ff 80 0c 00 00 00 03 00 00 00 01 00)$/;
		}

		my @y2;
		push @y2, &$_read_short for 1..3;
		if (0) {
		    warn "$y2[0] != 137|64|70|267" if $y2[0] !~ /^(137|64|70|267)$/; # etc. ...
		}

		my $y2_str = join(" ", map { sprintf "%04x", $_ } @y2[1..$#y2]);
		warn "$y2_str != 0066 0002"
		    if $y2_str !~ /^(0066 0002)$/;

		$sym->{Coords} = [&$_read_coord];

		my @z;
		push @z, &$_read_uchar for 1..8;
		if (0) {	# zu viele Ausnahmen
		    my $z_str = join(" ", map { sprintf "%02x", $_ } @z);
		    warn "$z_str != 5c 09 00 00 00 00 00 00
			18 00 00 00 18 00 00 00
			05 00 00 00 05 00 00 00
			58 06 00 00 00 00 00 00
			11 00 00 00 11 00 00 00
			07 00 00 00 07 00 00 00"
			if $z_str !~ /^(5c 09 00 00 00 00 00 00|18 00 00 00 18 00 00 00|05 00 00 00 05 00 00 00|58 06 00 00 00 00 00 00|11 00 00 00 11 00 00 00|07 00 00 00 07 00 00 00)$/;
		}
	    } elsif ($type == 5|| # Rechteck, found in mtbstrecke2003msymbol.ovl
		     0) {
		my @x;
		push @x, &$_read_uchar for 1..20;
		my $x_str = join(" ", map { sprintf "%02x", $_ } @x);
		warn "$x_str != 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 02 10 00 00"
		    if $x_str !~ /^(01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 02 10 00 00)$/;

		$sym->{TypeText} = &$_read_fixed_string;

		my @y;
		push @y, &$_read_uchar for 1..32;

		$sym->{Coords} = [&$_read_coord];

		my @z;
		push @z, &$_read_uchar for 1..8;


	    } else {
		warn "$type ???";
	    }
	    push @symbols, $sym;
	    if ($d) {
		require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([$sym],[qw()])->Indent(1)->Useqq(1)->Dump
	    }
	}
	$self->{Symbols} = \@symbols;
    }
}

sub tk_export {
    my($self, %args) = @_;
    # peacify -w
    my $top = $main::top = $main::top;
    my $file = $top->getSaveFile
	(-defaultextension => '.ovl',
	 -filetypes => [[M"OVL-Dateien" => '.ovl'],
			[M"Alle Dateien" => '*']],
	);
    return unless defined $file;
    require Karte::Standard;
    require Karte::Polar;
    $Karte::Polar::obj = $Karte::Polar::obj; # peacify -w
    my @polar_coords = map { [ $Karte::Polar::obj->standard2map(@$_) ] } @{ $args{coords} };
    my $s = $self->as_string_ascii(\@polar_coords);
    die "$s -> $file";#XXX
    open(OVL, ">$file") or main::status_message("Cannot write to $file: $!", "die");
    print OVL $s;
    close OVL;
}

1;

__END__
