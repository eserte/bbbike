# -*- perl -*-

#
# $Id: Kbd.pm,v 1.11 2002/04/30 11:41:59 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Tk::Kbd;
use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.11 $ =~ /(\d+)\.(\d+)/);

use base qw(Tk::Frame);
Construct Tk::Widget 'Kbd';

use vars qw(%modifier %reverse_modifier);
%modifier = (qw(Control_L Control
		Shift_L Shift
		Multi_key Multi_key
		Shift_R Shift
		Caps_Lock Lock
		Alt_L Alt
		Meta_L Meta
		Mode_switch Mode_switch));

use vars qw(%bm);
foreach my $bm (qw(BackSpace Return Tab Left Right Up Down)) {
    $bm{$bm} = __PACKAGE__ . "::" . $bm;
}
my $def_bitmaps = 0;

sub ClassInit {
    my($class, $mw) = @_;

    unless ($def_bitmaps) { # XXX ?
	my @leftright_bits = ("....1.....",
			      "..111.....",
			      "1111111111",
			      "..111.....",
			      "....1.....");
	my $bits1 = pack("b10"x5,@leftright_bits);
	$mw->DefineBitmap($bm{BackSpace} => 10,5, $bits1);
	$mw->DefineBitmap($bm{Left}      => 10,5, $bits1);
	my $bits4 = pack("b10"x5, map { scalar reverse } @leftright_bits);
	$mw->DefineBitmap($bm{Right}     => 10,5, $bits4);

	my @updown_bits = ("..1..",
			   ".111.",
			   "11111",
			   "..1..",
			   "..1..",
			   "..1..",
			   "..1..");

	my $up_bits   = pack("b5"x7, @updown_bits);
	my $down_bits = pack("b5"x7, reverse @updown_bits);

	$mw->DefineBitmap($bm{Up}   => 5,7, $up_bits);
	$mw->DefineBitmap($bm{Down} => 5,7, $down_bits);

	my $bits2 = pack("b10"x5,"....1....1",
				 "..111....1",
				 "1111111111",
				 "..111.....",
				 "....1.....");
	$mw->DefineBitmap($bm{Return} => 10,5, $bits2);

	my $bits3 = pack("b10"x7,"1..11.....",
			         "1111111111",
				 "1..11.....",
				 "..........",
				 ".....11..1",
				 "1111111111",
				 ".....11..1");
	$mw->DefineBitmap($bm{Tab} => 10,7, $bits3);
    }
}

sub Populate {
    my($w, $args) = @_;
    $w->SUPER::Populate($args);

    $w->ConfigSpecs
      (-configfile => ['METHOD', undef, undef, undef],
       -takefocus => ['PASSIVE', 'takeFocus', 'TakeFocus', 0],
      );
}

sub configfile {
    my $w = shift;
    if (@_) {
	my $file = shift;
	$w->create_layout($file);
	$w->{Configure}{-configfile} = $file;
    }
    $w->{Configure}{-configfile};
}

sub create_layout {
    my $w = shift;
    my $file = shift;

    if ($file) {
	$w->read_config($file);
    }

    $_->destroy for ($w->children);

    my %ch_keysym =
	(
	 0x020 => 'space',
	 0x021 => 'exclam',
	 0x022 => 'quotedbl',
	 0x023 => 'numbersign',
	 0x024 => 'dollar',
	 0x025 => 'percent',
	 0x026 => 'ampersand',
	 0x027 => 'apostrophe',
	 0x028 => 'parenleft',
	 0x029 => 'parenright',
	 0x02a => 'asterisk',
	 0x02b => 'plus',
	 0x02c => 'comma',
	 0x02d => 'minus',
	 0x02e => 'period',
	 0x02f => 'slash',
	 0x03a => 'colon',
	 0x03b => 'semicolon',
	 0x03c => 'less',
	 0x03d => 'equal',
	 0x03e => 'greater',
	 0x03f => 'question',
	 0x040 => 'at',
	 0x05b => 'bracketleft',
	 0x05c => 'backslash',
	 0x05d => 'bracketright',
	 0x05e => 'asciicircum',
	 0x05f => 'underscore',
	 0x060 => 'grave',
	 0x07b => 'braceleft',
	 0x07c => 'bar',
	 0x07d => 'braceright',
	 0x07e => 'asciitilde',
	 0x0a0 => 'nobreakspace',
	 0x0a1 => 'exclamdown',
	 0x0a2 => 'cent',
	 0x0a3 => 'sterling',
	 0x0a4 => 'currency',
	 0x0a5 => 'yen',
	 0x0a6 => 'brokenbar',
	 0x0a7 => 'section',
	 0x0a8 => 'diaeresis',
	 0x0a9 => 'copyright',
	 0x0aa => 'ordfeminine',
	 0x0ab => 'guillemotleft',
	 0x0ac => 'notsign',
	 0x0ad => 'hyphen',
	 0x0ae => 'registered',
	 0x0af => 'macron',
	 0x0b0 => 'degree',
	 0x0b1 => 'plusminus',
	 0x0b2 => 'twosuperior',
	 0x0b3 => 'threesuperior',
	 0x0b4 => 'acute',
	 0x0b5 => 'mu',
	 0x0b6 => 'paragraph',
	 0x0b7 => 'periodcentered',
	 0x0b8 => 'cedilla',
	 0x0b9 => 'onesuperior',
	 0x0ba => 'masculine',
	 0x0bb => 'guillemotright',
	 0x0bc => 'onequarter',
	 0x0bd => 'onehalf',
	 0x0be => 'threequarters',
	 0x0bf => 'questiondown',
	 0x0c0 => 'Agrave',
	 0x0c1 => 'Aacute',
	 0x0c2 => 'Acircumflex',
	 0x0c3 => 'Atilde',
	 0x0c4 => 'Adiaeresis',
	 0x0c5 => 'Aring',
	 0x0c6 => 'AE',
	 0x0c7 => 'Ccedilla',
	 0x0c8 => 'Egrave',
	 0x0c9 => 'Eacute',
	 0x0ca => 'Ecircumflex',
	 0x0cb => 'Ediaeresis',
	 0x0cc => 'Igrave',
	 0x0cd => 'Iacute',
	 0x0ce => 'Icircumflex',
	 0x0cf => 'Idiaeresis',
	 0x0d0 => 'ETH',
	 0x0d1 => 'Ntilde',
	 0x0d2 => 'Ograve',
	 0x0d3 => 'Oacute',
	 0x0d4 => 'Ocircumflex',
	 0x0d5 => 'Otilde',
	 0x0d6 => 'Odiaeresis',
	 0x0d7 => 'multiply',
	 0x0d8 => 'Ooblique',
	 0x0d9 => 'Ugrave',
	 0x0da => 'Uacute',
	 0x0db => 'Ucircumflex',
	 0x0dc => 'Udiaeresis',
	 0x0dd => 'Yacute',
	 0x0de => 'THORN',
	 0x0df => 'ssharp',
	 0x0e0 => 'agrave',
	 0x0e1 => 'aacute',
	 0x0e2 => 'acircumflex',
	 0x0e3 => 'atilde',
	 0x0e4 => 'adiaeresis',
	 0x0e5 => 'aring',
	 0x0e6 => 'ae',
	 0x0e7 => 'ccedilla',
	 0x0e8 => 'egrave',
	 0x0e9 => 'eacute',
	 0x0ea => 'ecircumflex',
	 0x0eb => 'ediaeresis',
	 0x0ec => 'igrave',
	 0x0ed => 'iacute',
	 0x0ee => 'icircumflex',
	 0x0ef => 'idiaeresis',
	 0x0f0 => 'eth',
	 0x0f1 => 'ntilde',
	 0x0f2 => 'ograve',
	 0x0f3 => 'oacute',
	 0x0f4 => 'ocircumflex',
	 0x0f5 => 'otilde',
	 0x0f6 => 'odiaeresis',
	 0x0f7 => 'division',
	 0x0f8 => 'oslash',
	 0x0f9 => 'ugrave',
	 0x0fa => 'uacute',
	 0x0fb => 'ucircumflex',
	 0x0fc => 'udiaeresis',
	 0x0fd => 'yacute',
	 0x0fe => 'thorn',
	 0x0ff => 'ydiaeresis',
	);

    my $y = 0;
    for my $r (@{$w->{Def}{'NormalKeyLabels'}}) {
	my $f = $w->Frame->pack(-fill=>'x',-expand=>1);
	my $x = 0;
	for my $c (@$r) {
	    my $key = $w->{Def}{'NormalKeys'}->[$y][$x];
	    $key = $c if (!defined $key);
	    next if $key =~ /^(Focus)$/; # XXX
	    my $mod = $modifier{$key};

	    my $shift_key_label = $w->{Def}{'ShiftKeyLabels'}->[$y][$x];
	    $shift_key_label = $c if (!defined $shift_key_label);

	    my %label;
	    for my $mode ('normal', 'shift') {
		my $text_c = $mode eq 'normal' ? $c : $shift_key_label;
		$text_c =~ s/\\([0-7]{3})/chr(oct($1))/eg;
		$text_c =~ s/\\n/\n/g;
		$text_c =~ s/\\(.)/$1/g;
		if ($text_c =~ /^(BackSpace|Return|Tab)$/) {
		    $label{$mode} = [-bitmap => $bm{$1}, -text => undef];
		} elsif ($text_c =~ /(left|right|up|down)$/) {
		    $label{$mode} = [-bitmap => $bm{ucfirst $1}, -text => undef];
		} elsif ($text_c eq 'space') {
		    $label{$mode} = [-text => ' 'x10, -bitmap => undef];
		} else {
		    $label{$mode} = [-text => $text_c, -bitmap => undef];
		}
	    }

	    $key =~ s/\\([0-7]{3})/chr(oct($1))/eg;

	    my $b;
	    if (defined $mod) {
		$b = $f->Checkbutton(@{ $label{'normal'} },
				     -indicatoron => 0,
				     -variable => \$w->{Modset}{$mod},
				     -takefocus => 0,
				     -command => [$w, 'change_modifier', $mod],
				    );
	    } else {
		$b = $f->KbdButton
		    (@{ $label{'normal'} },
		     -takefocus => 0,
		     -command => sub {
			 my $key = exists $ch_keysym{ord($key)} ? $ch_keysym{ord($key)} : $key;
			 $w->send_key($key);
		     });
		$w->{Button_NormalKeyLabel}{$b} = $label{'normal'};
		$w->{Button_ShiftKeyLabel}{$b}  = $label{'shift'};
	    }
	    if ($mod || length $key > 1) {
		$b->pack(-side=>'left', -fill=>'both', -expand=>1);
	    } else {
		$b->pack(-side=>'left', -fill=>'y');
	    }

	    $x++;
	}
	$y++;
    }
}

sub change_modifier {
    my($w, $mod) = @_;
    if (!defined $mod || $mod =~ /^(Shift|Lock)$/) {
	if (!$w->{KbdButtons}) {
	    $w->Walk(sub {
			 push @{ $w->{KbdButtons} }, $_[0]
			     if $_[0]->isa('Tk::KbdButton');
		     });
	}
	# use Tk::configure for SPEED!
	if ($w->{Modset}{"Shift"} || $w->{Modset}{"Lock"}) {
	    for my $ww (@{ $w->{KbdButtons} }) {
		Tk::configure($ww, @{$w->{Button_ShiftKeyLabel}{$ww}});
	    }
	} else {
	    for my $ww (@{ $w->{KbdButtons} }) {
		Tk::configure($ww, @{$w->{Button_NormalKeyLabel}{$ww}});
	    }
	}
    }
}

sub read_config {
    my($w, $file) = @_;
    my(%resources) = map { $_->[0] =~ s/^[^.*]*[.*]//;
			   ($_->[0] => $_->[1])
		       } $w->_read_x11_config($file);
    $w->{Def} = {};
    foreach my $k (qw(NormalKeys ShiftKeys AltgrKeys
		      KeyLabels  NormalKeyLabels
		      ShiftKeyLabels AltgrKeyLabels)) {
	my $def = $resources{$k};
	next if !defined $def;
	my @lines = map {
	    s/^\s+//; s/\s+$//;
	    [map { m|^/| ? eval "sprintf qq{$_}" : $_ } split /\s+/]
	} split /\s+\\n/, $def;
	$w->{Def}{$k} = \@lines;
    }
}

# stolen from Tk::CmdLine::LoadResources
sub _read_x11_config {
    my($w, $file) = @_;
    my @resource;

    if (open(SPEC, $file)) {
        my $resource     = undef;
        my $continuation = 0;

        while (defined(my $line = <SPEC>)) {
            chomp($line);
            next if ($line =~ /^\s*$/); # skip blank lines
            next if ($line =~ /^\s*!/); # skip comments
            $continuation = ($line =~ s/\s*\\$/ /); # search for trailing backslash
            unless (defined($resource)) { # it is the first line
                $resource = $line;
            } else { # it is a continuation line
                $line =~ s/^\s*//; # remove leading whitespace
                $resource .= $line;
            }
            next if $continuation;
            push(@resource, [ $1, $2 ])
		if ($resource =~ /^([^:\s]+)*\s*:\s*(.*)$/);
            $resource = undef;
        }

        close(SPEC);

        if (defined($resource)) { # special case - EOF after line with trailing backslash
            push(@resource, [ $1, $2 ])
		if ($resource =~ /^([^:\s]+)*\s*:\s*(.*)$/);
        }

    }

    @resource;
}

sub send_key {
    my($w, $key, $tw) = @_;
    if (!$tw) { $tw = $w->focusCurrent };
    die "No window has focus" if !$tw;

    my @mod_string;
    my $unset_shift_mod = 0;
    foreach my $mod (keys %{$w->{Modset}}) {
	push @mod_string, $mod if ($w->{Modset}{$mod});
	unless ($mod =~ /Lock/) {
            if ($w->{Modset}{"Shift"}) {
		$unset_shift_mod++;
	    }
            $w->{Modset}{$mod} = 0;
	}
    }

    my $mod_string;
    if (@mod_string) {
	$mod_string = join("-", @mod_string, "Key");
    } else {
	$mod_string = "Key";
    }
    $tw->eventGenerate("<$mod_string-$key>");

    if ($unset_shift_mod) {
	$w->change_modifier();
    }
}

######################################################################

package Tk::KbdButton;
use Tk qw(NoOp);
use base qw(Tk::Derived Tk::Button);
Construct Tk::Widget 'KbdButton';

sub ClassInit {
    my($class, $mw) = @_;

    $mw->bind($class, "<Enter>" => NoOp);
    $mw->bind($class, "<Leave>" => NoOp);
    $mw->bind($class, '<1>', => 'butDown');
    $mw->bind($class, "<ButtonRelease-1>" => 'butUp');

    $class;
}

sub Populate {
    my($w, $args) = @_;
    $w->SUPER::Populate($args);
    $w->ConfigSpecs(
        -repeatdelay     => [qw(PASSIVE repeatDelay    RepeatDelay    300)],
        -repeatinterval  => [qw(PASSIVE repeatInterval RepeatInterval 100)],
    );
}

sub butDown {
    my $b = shift;
    my $fire = shift || 'initial';

    if ($fire eq 'initial') {
        # XXX why isn't relief saving done the Tk::Button as
        #soon as callback is invoked?
        $b->{tk_firebutton_save_relief} = $b->cget('-relief');

	($b->{_Fg}, $b->{_Bg}) = ($b->cget(-fg), $b->cget(-bg));
	$b->configure(-fg => $b->{_Bg}, -bg => $b->{_Fg});

        $b->RepeatId($b->after( $b->cget('-repeatdelay'),
                [\&butDown, $b, 'again'])
                );
    } else {
        $b->invoke;
        $b->RepeatId($b->after( $b->cget('-repeatinterval'),
                [\&butDown, $b, 'again'])
                );
    }
}

sub butUp {
    my $b = shift;
    $b->CancelRepeat;
    $b->configure(-relief=>$b->{tk_firebutton_save_relief})
        if $b->{tk_firebutton_save_relief};
    $b->configure(-bg => $b->{_Bg}, -fg => $b->{_Fg});
    $b->invoke;
}

sub Invoke {
    my $b = shift;
    my($fg, $bg) = ($b->cget(-fg), $b->cget(-bg));
    $b->configure(-fg => $bg, -bg => $fg);
    $b->idletasks;
    $b->after(100);
    $b->configure(-fg => $fg, -bg => $bg);
    $b->invoke;
}

1;

__END__

=head1 NAME

Tk::Kbd - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Tk::Kbd;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Tk::Kbd was created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head1 AUTHOR

A. U. Thor, a.u.thor@a.galaxy.far.far.away

=head1 SEE ALSO

perl(1).

=cut
