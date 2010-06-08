# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2000-2002,2010 Slaven Rezic. All rights reserved.
#

package Tk::Ruler;

=head1 NAME

Tk::Ruler - draw a horizontal ruler

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use Tk qw(NORMAL_BG BLACK WHITE);
use base qw(Tk::Frame);

use strict;
use vars qw($VERSION);
$VERSION = 1.2;

Construct Tk::Widget 'Ruler';

=head1 STANDARD OPTIONS

=over 4

=back

=head1 WIDGET-SPECIFIC OPTIONS

=over 4

=back

=cut

sub Populate {
    my($w, $args) = @_;

    if ($Tk::platform ne 'MSWin32') {
	$args->{"-relief"} = "sunken" unless exists $args->{"-relief"};
	# XXX -orient: horiz/vert
	$args->{"-border"} = 2        unless exists $args->{"-border"};
    }
    $args->{"-height"} = 3        unless exists $args->{"-height"};

    $w->SUPER::Populate($args);

    if ($Tk::platform eq 'MSWin32') {
    	#$w->packPropagate(0); # efficiency
	$w->Label(-background => BLACK
		  )->place(-relx => 0, -rely => 0,
			   -relwidth => 1, -height => 1);
	$w->Label(-background => BLACK
		  )->place(-relx => 0, -rely => 0,
			   -width => 1, -relheight => 1);
	$w->Label(-background => WHITE
		  )->place(-relx => 1, '-x' => -1, -rely => 0,
			   -width => 1, -relheight => 1);
	$w->Label(-background => WHITE
		  )->place(-relx => 0, -rely => 1, '-y' => -1,
			   -relwidth => 1, -height => 1);
    }

    $w->ConfigSpecs
	("-padx" => ['PASSIVE', "padX", "Pad", undef],
	 "-pady" => ['PASSIVE', "padY", "Pad", undef],
	 "-background" => [[qw/SELF/], "background", "Background", undef],
	);
}

=head1 METHODS

=cut

sub rulerGrid {
    my($w, %args) = @_;
    $w->grid(%args,
#	     -sticky => "news",
	     -sticky => "ew",
	     (defined $w->cget(-padx) ? (-padx => $w->cget(-padx)) : ()),
	     (defined $w->cget(-pady) ? (-pady => $w->cget(-pady)) : ()),
	    );
    $w->parent->gridRowconfigure
	($args{-row},
	 -weight => 0,
	);
    $w;
}

sub rulerPack {
    my($w, %args) = @_;
    $w->pack(%args,
	     -fill => 'x',
	     (defined $w->cget(-padx) ? (-padx => $w->cget(-padx)) : ()),
	     (defined $w->cget(-pady) ? (-pady => $w->cget(-pady)) : ()),
	    );
}

1;

__END__

=head1 COPYRIGHT

(c) 2000-2002,2010 Slaven Rezic

=cut
