#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: draw_ovl,v 2.8 2004/12/29 23:32:12 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven.rezic@berlin.de
# WWW:  http://www.rezic.de/eserte/
#

# Description (en): draw .ovl files
# Description (de): .ovl-Dateien zeichnen
package OvlFile;
use base qw(BBBikePlugin);

use strict;
use vars qw($button_image $del_button_image);

# Plugin register method
sub register {

    if (!defined $button_image) {
	$button_image = $main::top->Photo
	    (-format => 'gif',
	     -data => <<EOF);
R0lGODlhDwAPAMIAAP8AAAAAANfX1////21tbf///////////yH5BAEAAAcALAAAAAAPAA8A
AANHeACnGiCE5hy7R2Zme5Ychn1g1ISLJAmDoKpUE7Q068aZXQ9TPOuvYADYIByMBIKE1kMe
lTne85nszQLOZJUiyWp7MiEslgAAOw==
EOF
    }

    if (!defined $del_button_image) {
	$del_button_image = $main::top->Photo
	    (-format => 'gif',
	     -data => <<EOF);
R0lGODlhDwAPAMIAAP8AAAAAANfX1////21tbf///////////yH5BAEAAAcALAAAAAAPAA8A
AAMneACnzq1BRl20td757IbYco1kaZJilKITWGqnsprLzErup9rSWF8JADs=
EOF
    }

    add_buttons();
}

sub add_buttons {
    my $mf = $main::top->Subwidget("ModePluginFrame");
    return unless defined $mf;

    my $b = $mf->Button
	(main::image_or_text($button_image, 'Open OVL'),
	 -command => sub {
	     my $f = $main::top->getOpenFile
		 (-filetypes =>
		  [
		   ["OVL-Dateien", ['.ovl', '.OVL']],
		   ["Alle Dateien", '*'],
		  ]
		 );
	     if (defined $f) {
		 bbbike_draw_symbols($f);
	     }
	 });
    BBBikePlugin::replace_plugin_widget($mf, $b, __PACKAGE__.'_open');
    $main::balloon->attach($b, -msg => "Open OVL file")
	if $main::balloon;

    my $b2 = $mf->Button
	(main::image_or_text($del_button_image, 'Del OVL'),
	 -command => sub {
	     bbbike_del_ovl();
	 });
    BBBikePlugin::replace_plugin_widget($mf, $b2, __PACKAGE__.'_del');
    $main::balloon->attach($b2, -msg => "Del OVL")
	if $main::balloon;
}

sub new {
    my($class, $file) = @_;
    bless {File => $file}, $class;
}

sub read {
    my $self = shift;
    my $file = $self->{File};
    if (open(F, $file)) {
	if (scalar <F> =~ /^\[Symbol/) {
	    close F;
	    return $self->read_ascii;
	}
	close F;
    }
    return $self->read_binary;
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

sub read_binary {
    my($self) = @_;
    open(F, $self->{File}) or die "Can't open file $self->{File}: $!";
    binmode F;
    local $/ = undef;
    my $buf = <F>;
    close F;

    my $p = 0;

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

    my $magic = &$_read_string;
    if ($magic ne "DOMGVCRD Ovlfile V2.0:") {
	die "Wrong magic: $magic\n";
    }
    $_forward->(6);
    my $MapName = &$_read_string;
    warn "Description: $MapName\n";
    $_seek_to->(0x3d);
    my $DimmFc = &$_read_long;
    my $ZoomFc = &$_read_long;
    my $CenterLat  = &$_read_float;
    my $CenterLong = &$_read_float;
    warn "Center=$CenterLat/$CenterLong\n";
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
#  rot: gut zu fahrende Straßen mit max. mäßiger Verkehrsdichte. Auch asphaltierte autofreie Wege
#  grün: befahrbare aber nicht asphaltierte Feld und Waldwege
#  gelb: rel. verkehrsreiche Straßen, aber wichtige Strecke
#  blau: schlechte Straße, Kopfsteinpflaster
#  schwarz, dünne Zick-Zack Linie: unbefahrbarer Weg
#  weiß: Bundesstraße, keine Bewertung, nur zum Abdecken des Kartenuntergrundes 
#  verwendet
	    my $color = {1 => 'red', # rot/gut befahrbar?',
			 6 => 'white', #weiß/Bundesstraße?',
			 4 => 'yellow', #gelb/verkehrsreich?',
			 5 => 'black', # schwarz/unbefahrbar?
			 2 => 'green', # Feld/Waldwege
			 3 => 'blue', # Kopfsteinpflaster
			}->{$x[3]};
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

sub draw_symbols {
    my($self, $c, $transpose, %args) = @_;
    my @create_args;
    my @tags;
    if ($args{-tags}) {
	push @tags, (UNIVERSAL::isa($args{-tags}, 'ARRAY')
		     ? @{ $args{-tags} }
		     : $args{-tags}
		    );
    }

    my @first_coord;
    foreach my $sym (@{$self->{Symbols}}) {
	if ($sym->{Coords} && @{ $sym->{Coords} }) {
	    @first_coord = $transpose->(@{ $sym->{Coords}[0] });
	}
    }

    foreach my $sym (@{$self->{Symbols}}) {
	next unless $sym->{Coords};
	my @tags = @tags;
	if (defined $sym->{Balloon}) {
	    push @tags, $sym->{Balloon};
	}
	if ($sym->{Text}) {
	    (my $text = $sym->{Text}) =~ s/\x0d\x0a/\n/g;
	    $c->createText($transpose->(@{$sym->{Coords}[0]}),
			   -text => $text,
			   -anchor => "w",
			   @create_args,
			   (@tags ? (-tags => \@tags) : ()),
			  );
	} elsif ($sym->{Label}) {
	    $c->createText($transpose->(@{$sym->{Coords}[0]}),
			   -text => $sym->{Label},
			   #-anchor => "w", (center???)
			   @create_args,
			   (@tags ? (-tags => \@tags) : ()),
			  );
	} elsif (@{$sym->{Coords}} == 1) {
	    my($tx,$ty) = $transpose->(@{$sym->{Coords}[0]});
	    $c->createLine($tx,$ty,$tx+1,$ty,-width => 3,
			   @create_args,
			   (@tags ? (-tags => \@tags) : ()),
			  );
	} else {
	    my @tc;
	    foreach (@{$sym->{Coords}}) {
		push @tc, $transpose->(@$_);
	    }
	    $c->createLine(@tc, @create_args,
			   (defined $sym->{Color} ? (-fill => $sym->{Color}) : ()),
			   (@tags ? (-tags => \@tags) : ()),
			  );
	}
    }

    if (@first_coord && $c->can("see")) {
	$c->see(@first_coord);
    }
}

sub bbbike_del_ovl {
    $main::c->delete("ovl");
}

sub bbbike_draw_symbols {
    my($file) = @_;
    my $self = new OvlFile $file;
    $self->read;
    require Karte;
    require Karte::Polar;
    $Karte::Polar::obj=$Karte::Polar::obj;
    my $transpose;
    if ($main::coord_system_obj) {
	$transpose = sub { main::transpose($Karte::Polar::obj->map2map($main::coord_system_obj, @_)) };
    } else {
	$transpose = sub { main::transpose($Karte::Polar::obj->map2standard(@_)) };
    }
    $self->draw_symbols($main::c, $transpose, -tags => 'ovl');
}

return 1 if caller();

package main;

require Tk;
my $top = MainWindow->new;
$top->Canvas->pack;
#XXX

__END__
