# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 1999, 2000 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#

package Tk::LayerEditor;
use Tk::LayerEditorCore;
use Tk::Frame;
use vars qw($VERSION @ISA);
@ISA = qw(Tk::LayerEditorCore Tk::Frame);
Construct Tk::Widget 'LayerEditor';
$VERSION = $Tk::LayerEditorCore::VERSION;

sub Populate {
    my($w, $args) = @_;
    $w->Tk::Frame::Populate($args);

    $w->CommonPopulate($args);

    $w->ConfigSpecs
      (
       $w->SUPER::CommonConfigSpecs(),
      );
}

1;

__END__

=head1 NAME

Tk::LayerEditor - a gimp-like layer frame for changing layer attributes

=head1 SYNOPSIS

  use Tk;
  use Tk::LayerEditor;
  $top = new MainWindow;
  $c = $top->Canvas->pack;
  $le = $top->LayerEditor(...)->pack;
  $le->add(...);

=head1 DESCRIPTION

XXX

=head1 STANDARD OPTIONS

=head1 WIDGET-SPECIFIC OPTIONS

=head1 METHODS

=head1 EXAMPLES

=head1 BUGS/TODO

  - center icons
  - determine exact position of bar
  - do autoscrolling if the list is too big
  - bindings for right mouse click
  - tie visibility with Tie::Watch
  - do not display visibility image if first item has no Visible attribute
  - do not display any icons if first item has no Image attribute
  - split widget in DndHList and LayerEditor
  - check ok/apply/cancel methods

=head1 AUTHOR

Slaven Rezic <eserte@cs.tu-berlin.de>

=head1 COPYRIGHT

Copyright (c) 1999, 2000 Slaven Rezic. All rights reserved.
This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

Tk::Canvas(3), gimp(1).

=cut

