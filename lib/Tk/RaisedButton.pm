# -*- perl -*-

#
# $Id: RaisedButton.pm,v 1.1 1999/12/20 01:20:09 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

# XXX package Tk::RaisedButton verwenden!!!!!
# oder per import festlegen, ob Tk::Button oder Tk::RaisedButton

package
   Tk::Button;
use Tk::Button;

local $^W = 0;

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
