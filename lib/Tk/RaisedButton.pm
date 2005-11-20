# -*- perl -*-

#
# $Id: RaisedButton.pm,v 1.2 2005/11/19 20:02:03 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

# evtl. per import festlegen, ob alle Tk::Buttons sich wie
# Tk::RaisedButton verhalten sollen

package Tk::RaisedButton;
use Tk;
use base 'Tk::Button';

Construct Tk::Widget 'RaisedButton';

sub Enter
{
 my $w = shift;
 my $E = shift;
 if ($w->cget('-state') ne 'disabled')
  {
   $w->configure('-state' => 'active', '-relief' => 'raised');
  }
 $Tk::window = $w;
}

sub Leave
{
 my $w = shift;
 $w->configure('-state'=>'normal') if ($w->cget('-state') ne 'disabled');
 $w->configure('-relief' => "flat");
 undef $Tk::window;
}

1;

__END__
