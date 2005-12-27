# -*- perl -*-

#
# $Id: Ovl.pm,v 1.8 2005/12/26 19:52:15 eserte Exp $
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
$VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

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

    foreach my $sym (@{$self->{Symbols}}) {
	next unless $sym->{Coords};
	if ($sym->{Text}) {
	    # NYI XXX
	} elsif ($sym->{Label}) {
	    # NYI XXX
	} elsif ($sym->{Coords} == 1) {
	    # NYI XXX
	} else {
	    my $name = "TRACK"; # XXX better name!
	    $out .= "!T:\t$name\n";
	    for my $c (@{ $sym->{Coords} }) {
		my($long, $lat) = @$c;
		$lat  = ($lat < 0 ? "S" : "N") . $lat;
		$long = ($long < 0 ? "W" : "E") . $long;
		my $date = "31-Dec-1989 01:00:00"; # XXX
		my $elevation = 0; # XXX
		$out .= sprintf "\t%s\t%s\t%s\t%s\n", $date, $lat, $long, $elevation;
	    }
	    $out .= "\n";
	}
    }

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

    my $_read_short = sub {
	my $short = unpack("s", substr($buf, $p, 2)); # XXX s = native
	$p+=2;
	$short;
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

#  rot: gut zu fahrende Straßen mit max. mäßiger Verkehrsdichte. Auch asphaltierte autofreie Wege
#  grün: befahrbare aber nicht asphaltierte Feld und Waldwege
#  gelb: rel. verkehrsreiche Straßen, aber wichtige Strecke
#  blau: schlechte Straße, Kopfsteinpflaster
#  schwarz, dünne Zick-Zack Linie: unbefahrbarer Weg
#  weiß: Bundesstraße, keine Bewertung, nur zum Abdecken des Kartenuntergrundes 
#  verwendet
    my $color_mapping = 
	{1 => 'red', # rot/gut befahrbar?',
	 6 => 'white', #weiß/Bundesstraße?',
	 4 => 'yellow', #gelb/verkehrsreich?',
	 5 => 'black', # schwarz/unbefahrbar?
	 2 => 'green', # Feld/Waldwege
	 3 => 'blue', # Kopfsteinpflaster
	};

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
	    my $typ = &$_read_short;
	    $sym->{Typ} = $typ;
	    if ($typ == 3) {
		my @x;
		push @x, &$_read_short for 1..6;#print "\n";
		#XXXwarn "Type 3, x=@x";
		$sym->{Coords} = [&$_read_coords];
		my $color = $color_mapping->{$x[3]};
		push @x, $color;
		$sym->{Balloon} = "@x";
		$sym->{Color} = $color if defined $color;
	    } elsif ($typ == 2) {
		#print "$typ ";printf "%04x ", &$_read_short for 1..7;print "\n";
		my @x;
		push @x, &$_read_short for 1..2;
		my $subtyp = &$_read_short;
		if ($subtyp == 1) {
		    # NOP
		} elsif ($subtyp == 0x10) {
		    push @x, &$_read_short for 1..2;
		    $sym->{Text} = &$_read_string;
		} else {
		    warn "Unknown subtype=$subtyp p=".sprintf("%x",$p);
		    last;
		}
		push @x, &$_read_short for 1..4;
		warn "Type 2, x=@x";
		$sym->{Coords} = [&$_read_coords];
		$sym->{Label} = &$_read_fixed_string;

	    } elsif ($typ == 6) {
		my @x;
		push @x, &$_read_short for 1..2;
		my $subtyp = &$_read_short;
		if ($subtyp == 1) {
		    # NOP
		} elsif ($subtyp == 0x10) {
		    push @x, &$_read_short for 1..2;
		    $sym->{Text} = &$_read_string;
		} else {
		    warn "Unknown subtype=$subtyp p=".sprintf("%x",$p);
		    last;
		}
		#print "X ";printf "%04x ", 
		push @x, &$_read_short for 1..6;#print "\n";
		warn "Type 6, x=@x";
		$sym->{Coords} = [&$_read_coord];
	    } else {
		warn "Unknown type=$typ p=".sprintf("%x",$p);
		last;
	    }
#use Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->Dumpxs([$sym],[]); # XXX
#if($sym->{Text}=~ /ZollamtXXX/){last;$trace++;$SIG{USR1}=sub{$abort=1}}
	    push @symbols, $sym;
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
	my $CenterLong  = &$_read_float;
	my $CenterLat = &$_read_float;
	if ($d) {
	    warn "Center (long/lat)=$CenterLong/$CenterLat\n";
	    warn "DimmFC=$DimmFc, ZoomFC=$ZoomFc\n";
	}

	$_seek_to->(0x1a1);
	my @symbols;
	while($p < length $buf) {
#if($trace){while(!$abort){sleep 1}$abort=0}
	    my $sym = {};
	    my $typ = &$_read_short;
	    $sym->{Typ} = $typ;
	    if ($typ == 0x1) {
		&$_read_short for 1..9;
		$sym->{Text} = &$_read_fixed_string;
		&$_read_short for 1..10;
		$sym->{Coords} = [&$_read_coords_3_0];
		#require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([$sym],[qw()])->Indent(1)->Useqq(1)->Dump; # XXX
	    } elsif ($typ == 2) { # found in: mv13.ovl
		&$_read_short for 1..10;
		$sym->{Type} = &$_read_fixed_string;
		&$_read_short for 1..12;
		$sym->{Coords} = [&$_read_coord];
		&$_read_short for 1..4;
		$sym->{Text} = &$_read_fixed_string;
	    } elsif ($typ == 3) { # found in: mv14.ovl
		&$_read_short for 1..10;
		$sym->{Text} = &$_read_fixed_string;
		#&$_read_short for 1..11;
		#$sym->{Coords} = [&$_read_coord];
		&$_read_short for 1..10;
		$sym->{Coords} = [&$_read_coords_3_0];
		#require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([$sym],[qw()])->Indent(1)->Useqq(1)->Dump; # XXX
	    } elsif ($typ == 180) {
		&$_read_short for 1..14;
		$sym->{Text} = &$_read_fixed_string;
		&$_read_short for 1..10;
		$sym->{Coords} = [&$_read_coords_3_0];
	
	    } elsif ($typ == 20) {
		&$_read_short for 1..12;
		my $text1 = &$_read_fixed_string;
		warn "$text1\n" if $d;
		&$_read_short for 1..13;
		my $text2 = &$_read_fixed_string;
		warn "$text2\n" if $d;
		my $sym_nr = &$_read_short;
		warn "SymNr?=$sym_nr\n" if $d;
		&$_read_short for 1..9;
		$sym->{Coords} = [&$_read_coords_3_0];
	    } elsif ($typ == 23) {
		# do nothing...
	    } else {
		warn sprintf "Position=0x%x\n", $p;
		warn "unhandled type <$typ>"; # XXX
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
