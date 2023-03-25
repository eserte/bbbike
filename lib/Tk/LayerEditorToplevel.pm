# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 1999, 2000 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#

package Tk::LayerEditorToplevel;
use Tk::Toplevel;
use Tk::LayerEditorCore;
use vars qw(@ISA $VERSION);
@ISA = qw(Tk::LayerEditorCore Tk::Toplevel);
$VERSION =  $Tk::LayerEditorCore::VERSION;
Construct Tk::Widget 'LayerEditorToplevel';

sub Populate {
    my($w, $args) = @_;
    $w->Tk::Toplevel::Populate($args);

    my $f = $w->Component('Frame' => 'buttons'
			 )->pack(-fill => 'x', -side => "bottom");

    $w->CommonPopulate($args);

    if (delete $args->{'buttons'}) {
	my $o_b = $f->Button(-command => [$w, 'OK'],
			    )->pack(-side => 'left',
				    -expand => 1,
				    -fill => 'x'
				   );
	$w->Advertise('ok' => $o_b);
	my $a_b = $f->Button(-command => [$w, 'Apply'],
			    )->pack(-side => 'left',
					-expand => 1,
				    -fill => 'x');
	$w->Advertise('apply' => $a_b);
	my $c_b = $f->Button(-command => [$w, 'Cancel'],
			    )->pack(-side => 'left',
				    -expand => 1,
				    -fill => 'x');
	$w->Advertise('cancel' => $c_b);
    } else {
	my $c_b = $f->Button(-command => [$w, 'destroy'],
			    )->pack(-fill => 'x');
	    $w->Advertise('close' => $c_b);
    }

    $w->ConfigSpecs
      (
       $w->SUPER::CommonConfigSpecs(),
       -okcmd             => ['CALLBACK',undef,undef,undef],
       -applycmd          => ['CALLBACK',undef,undef,undef],
       -cancelcmd         => ['CALLBACK',undef,undef,undef],
       -transient         => ['METHOD',undef,undef,undef],
       -title             => ['METHOD','title','Title','Layer editor'],
       -oklabel           => ['METHOD','okLabel','OkLabel','OK'],
       -applylabel        => ['METHOD','applyLabel','ApplyLabel','Apply'],
       -cancellabel       => ['METHOD','cancelLabel','CancelLabel','Cancel'],
       -closelabel        => ['METHOD','closeLabel','CloseLabel','Close'],
      );
}

sub transient {
    my($w) = shift;
    my $ret;
    if (@_) {
	if ($_[0]) {
	    $ret = $w->SUPER::transient($_[0]);
	} else {
	    $ret = $w->SUPER::transient;
	}
    }
    $ret;
}

sub title {
    my($w) = shift;
    if (@_) {
	$w->Tk::Toplevel::title($_[0]);
    } else {
	$w->Tk::Toplevel::title;
    }
}

sub _set_label {
    my($w, $subwname, $val) = @_;
    my $subw = $w->Subwidget($subwname);
    if ($subw) {
	if (defined $val) {
	    $subw->configure(-text => $val);
	} else {
	    return $subw->cget(-text);
	}
    }
}

sub oklabel     { $_[0]->_set_label('ok',     $_[1]) }
sub applylabel  { $_[0]->_set_label('apply',  $_[1]) }
sub cancellabel { $_[0]->_set_label('cancel', $_[1]) }
sub closelabel  { $_[0]->_set_label('close',  $_[1]) }

sub OK {
    my $w = shift;
    $w->Call(-okcmd);
}

sub Apply {
    my $w = shift;
    $w->Call(-applycmd);
}

sub Cancel {
    my $w = shift;
    $w->Call(-cancelcmd);
}

1;

__END__

=head1 NAME

Tk::LayerEditorToplevel - a gimp-like layer dialog

=head1 SYNOPSIS

  use Tk;
  use Tk::LayerEditorToplevel;
  $top = new MainWindow;
  $c = $top->Canvas->pack;
  $le = $top->LayerEditor(...)->pack;
  $le->add(...);

=head1 DESCRIPTION

This is a Tk::LayerEditor widget embedded in a Toplevel window. See
the L<Tk::LayerEditor|Tk::LayerEditor> documentation for further
options and methods.

=head1 STANDARD OPTIONS

=head1 WIDGET-SPECIFIC OPTIONS

=head1 METHODS

=head1 EXAMPLES

=head1 BUGS/TODO

=head1 AUTHOR

Slaven Rezic <eserte@cs.tu-berlin.de>

=head1 COPYRIGHT

Copyright (c) 1999, 2000 Slaven Rezic. All rights reserved.
This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

Tk::LayerEditor(3), Tk::Toplevel(3).

=cut

