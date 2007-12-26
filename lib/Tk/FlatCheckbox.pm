# -*- perl -*-

#
# $Id: FlatCheckbox.pm,v 1.3 2007/10/19 20:55:38 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998,2001,2002,2007 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: srezic@cpan.org
# WWW:  http://www.rezic.de/eserte/
#

# XXX borderwidth ist krampfig ... check it

package Tk::FlatCheckbox;
use Tk::Derived;
use Tk::Canvas;
use strict;
use vars qw($VERSION @ISA);
@ISA = qw(Tk::Derived Tk::Canvas);
Construct Tk::Widget 'FlatCheckbox';

$VERSION = '0.08';

my %trace;
my %trace_rev;

sub ClassInit
{
 my ($class,$mw) = @_;
 $mw->bind($class,"<1>", "Invoke");
 $mw->bind($class,"<space>", "Invoke");
 $mw->bind($class,"<Enter>", "Enter");
 $mw->bind($class,"<Leave>", "Leave");
 return $class;
}

sub Populate {
    my($w, $args) = @_;
    if ($args->{-borderwidth}) {
	$w->{Configure}{borderwidth} = delete $args->{-borderwidth};
    }
    $w->{Configure}{borderwidth} = 2;#XXXXX
    $w->ConfigSpecs
      (
       #-borderwidth => ['METHOD', 'borderWidth', 'BorderWidth', 30],#XXX
       -image        => ['METHOD', 'image', 'Image', undef],
       -variable     => ['METHOD', 'variable', 'Variable', undef],
       -command      => ['CALLBACK', 'command', 'Command', undef],
       -state        => ['PASSIVE', 'state', 'State', 'active'], #XXX
       -text         => ['METHOD', 'text', 'Text', undef],
       '-font'       => ['PASSIVE', 'font', 'Font', undef],
       -raiseonenter => ['PASSIVE', 'raiseOnEnter', 'RaiseOnEnter', 0],
       -onvalue      => ['PASSIVE', 'onValue', 'Value', 1],
       -offvalue     => ['PASSIVE', 'offValue', 'Value', 0],
      );
}

sub ConfigChanged {
    my($w, $args) = @_;

    # XXX hack
    if ($args->{'-raiseonenter'}) {
	$w->Tk::Canvas::configure(-borderwidth => 2);
    }
}

sub QueueLayout {
    my($w, @args) = @_;
    $w->afterIdle([@args]);
}

sub _set_image {
    my($w) = @_;
    $w->delete('image');
    my $img = $w->{Configure}{'image'};
    return if !defined $img;
    $w->configure(-width => $img->width + $w->_get_bd*2,
		  -height => $img->height + $w->_get_bd*2
		 );
    $w->{'_ImageX'} = 1 + $w->{Configure}{borderwidth};
    $w->{'_ImageY'} = 1 + $w->{Configure}{borderwidth};
    $w->createImage($w->{'_ImageX'}, $w->{'_ImageY'},
		    -anchor => 'nw', -image => $img,
		    -tags => ['image', 'content']);
}

sub image {
    my($w, $img) = @_;
    if (@_ >= 2) {
	$w->{Configure}{'image'} = $img;
	$w->QueueLayout($w, '_set_image');
    }
    $w->{Configure}{'image'};
}

sub text {
    my($w, $text) = @_;
    if (@_ < 2) {
	$w->{Configure}{'text'};
    } else {
	$w->delete('text');
	return if !defined $text;
	$w->{Configure}{'text'} = $text;
	$w->QueueLayout($w, '_draw_text');
    }
}

sub font {
    my($w, $font) = @_;
    if (@_ < 2) {
	$w->{Configure}{'font'};
    } else {
	$w->{Configure}{'font'} = $font;
	$w->draw_text;
    }
}

sub _draw_text {
    my $w = shift;
    my $font = $w->{Configure}{'font'};
    my $text = $w->{Configure}{'text'};
    if (!defined $font) {
	my $dummy = $w->createText(0,0);
	$font = $w->{Configure}{'font'} = $w->itemcget($dummy, '-font');
	$w->delete($dummy);
    }
    my $string_width = $w->fontMeasure($font, $text);
    $w->configure(-width => $string_width + $w->_get_bd*2,
		  -height => $w->fontMetrics($font, -ascent) +
		             $w->fontMetrics($font, -descent) + $w->_get_bd*2,
		 );
    $w->{'_ImageX'} = 1 + $w->{Configure}{borderwidth};
    $w->{'_ImageY'} = 1 + $w->{Configure}{borderwidth};
    $w->createText($w->{'_ImageX'}, $w->{'_ImageY'},
		   -anchor => 'nw', -text => $text, '-font' => $font,
		   -tags => ['text', 'content']);
}

sub variable {
    my($w, $varref) = @_;
    if (@_ < 2) {
	$w->{Configure}{'variable'};
    } else {
	eval {
	    require Tie::Watch;
	};
	if (!$@) {
	    my $watch = $trace{$varref};
	    if (!$watch) {
		$watch = new Tie::Watch
		    -variable => $varref,
		    -store => sub { _store_scalar(@_) };
		$trace_rev{$watch} = [$w];
		$trace{$varref} = $watch;
	    } else {
		if (!grep { $_ eq $w } @{ $trace_rev{$watch} }) {
		    push @{ $trace_rev{$watch} }, $w;
		}
	    }
	} else {
	    warn "Can't find Tie::Watch --- tie of variables will not work";
	}
	$w->{Configure}{'variable'} = $varref;
	$w->afterIdle(sub { $w->_update_state });
    }
}

sub _get_bd {
    my $w = shift;
    if ($w->cget(-raiseonenter)) {
	0;
    } else {
	$w->{Configure}{borderwidth};
    }
}

# XXX really a specilized Tie::Watch method
sub _store_scalar {
    my($self, $newval) = @_;
    $self->Store($newval);
    foreach my $w (@{ $trace_rev{$self} }) {
	$w->_update_state if $w && Tk::Exists($w);
    }
}

sub _update_state {
    my $w = shift;
    my $varref = $w->{Configure}{'variable'};
    if (!defined $varref) {
	$w->{Configure}{'state'} = 0;
    } elsif (defined $$varref) {
	$w->{Configure}{'state'} = $$varref eq $w->cget(-onvalue);
    }
    $w->DrawCheck;
}

sub DrawCheck {
    my $w = shift;
    if ($w->{Configure}{'state'}) {
#  	my $img = $w->{Configure}{'image'};
#  	if (defined $img) {
#  	    $w->createRectangle($w->{'_ImageX'} + $img->width-5,
#  				$w->{'_ImageY'} + $img->height-5,
#  				$w->{'_ImageX'} + $img->width,
#  				$w->{'_ImageY'} + $img->height,
#  				-outline => undef, -fill => 'red',
#  				-tags => 'check');
#	}
	my $item = ($w->find("withtag", "content"))[0];
	if (defined $item) {
	    my(@bbox) = $w->bbox($item);
	    $w->createRectangle($bbox[2]-5, $bbox[3]-5,
				$bbox[2], $bbox[3],
				-outline => undef, -fill => 'red',
				-tags => 'check');
	}
    } else {
	$w->delete('check');
    }
}

sub invoke {
    my $w = shift;
    $w->{Configure}{'state'} = ($w->{Configure}{'state'} ? 0 : 1);
    if ($w->cget('-variable')) {
	$ {$w->cget('-variable')} = $w->{Configure}{'state'} ? $w->cget(-onvalue) : $w->cget(-offvalue);
    }
    $w->DrawCheck;
    if (defined $w->cget(-command)) {
	$w->Callback(-command);
    }
}

sub bind {
    shift->Tk::bind(@_);
}

# sub borderwidth {
#     my $w = shift;
#     if (@_) {
# 	$w->{Configure}{'borderwidth'} = shift;
#     }
#     $w->{Configure}{'borderwidth'};
# }

sub Invoke {
    my $w = shift;
    $w->invoke() unless($w->cget("-state") eq "disabled");
}

sub Enter {
    my $w = shift;
    if ($w->cget(-raiseonenter)) {
	$w->configure(-relief => "raised");
    } else {
	$w->{"_OrigBG_"} = $w->cget(-bg) unless defined $w->{"_OrigBG_"};
	$w->configure(-bg => Tk::ACTIVE_BG);
    }
}

sub Leave {
    my $w = shift;
    if ($w->cget(-raiseonenter)) {
	$w->configure(-relief => "flat");
    } else {
	if (defined $w->{"_OrigBG_"}) {
	    $w->configure(-bg => $w->{"_OrigBG_"});
	    delete $w->{"_OrigBG_"};
	}
    }
}

1;

__END__

=head1 NAME

Tk::FlatCheckbox - an alternative checkbutton implementation for perl/Tk

=head1 SYNOPSIS

    use Tk::FlatCheckbox;
    $mw->FlatCheckbox->pack;

=head1 DESCRIPTION

B<Tk::FlatCheckbox> is an alternative checkbutton implementation.
Unlike L<Tk::Checkbutton>, it uses a small square in the corner of the
widget to indicate the on/off state. This can be used for instance for
checkbuttons with images in a flat reliefed layout.

=head1 WIDGET-SPECIFIC OPTIONS

B<Tk::FlatCheckbox> supports some of L<Tk::Checkbutton> options. These
are:

=over

=item -borderwidth

=item -image

=item -variable

=item -command

=item -state

=item -text

=item -font

=item -onvalue

=item -offvalue

=back

Please refer to the L<Tk::Checkbutton> documentation for these options.

Additionaly, these options are supported:

=over

=item -raiseonenter => BOOL

Indicate whether a border should be raised if moving the mouse over
the widget.

=back

=head1 SEE ALSO

L<Tk::CheckButton>, L<Tk::FlatRadiobutton>

=head1 AUTHOR

Slaven ReziE<0x107> <srezic@cpan.org>

=head1 COPYRIGHT

Copyright (c) 1998,2001,2002,2007 Slaven ReziE<0x107>. All rights reserved.
This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
