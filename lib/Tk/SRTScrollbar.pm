#!/usr/local/bin/perl -w
# -*- perl -*-

#
# $Id: SRTScrollbar.pm,v 1.2 2004/10/02 08:50:09 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 1998 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

use Tk::Scrollbar;

package Tk::Scrollbar;

BEGIN {
    if ($] < 5.006) {
	$INC{"warnings.pm"} = 1;
	*warnings::unimport = sub { };
    }
}
no warnings 'redefine';

sub ClassInit
{
 my ($class,$mw) = @_;
 $mw->bind($class, "<Enter>", "Enter");
 $mw->bind($class, "<Motion>", "Motion");
 $mw->bind($class, "<Leave>", "Leave");

 $mw->bind($class, "<1>", "ButtonDown");
 $mw->bind($class, "<ButtonRelease-1>", "ButtonUp");
 $mw->bind($class, "<B1-Leave>", 'NoOp'); # prevent generic <Leave>
 $mw->bind($class, "<B1-Enter>", 'NoOp'); # prevent generic <Enter>
 $mw->bind($class, "<Control-1>", "ScrlTopBottom"); 

 $mw->bind($class, "<2>", "ButtonDown");
 $mw->bind($class, "<B2-Motion>", "Drag");
 $mw->bind($class, "<ButtonRelease-2>", "ButtonUp");
 $mw->bind($class, "<B2-Leave>", 'NoOp'); # prevent generic <Leave>
 $mw->bind($class, "<B2-Enter>", 'NoOp'); # prevent generic <Enter>
 $mw->bind($class, "<Control-2>", "ScrlTopBottom"); 

 $mw->bind($class, "<3>", "ButtonDown");
 $mw->bind($class, "<ButtonRelease-3>", "ButtonUp");
 $mw->bind($class, "<B3-Leave>", 'NoOp'); # prevent generic <Leave>
 $mw->bind($class, "<B3-Enter>", 'NoOp'); # prevent generic <Enter>

 $mw->bind($class, "<Up>",            ["ScrlByUnits","v",-1]);
 $mw->bind($class, "<Down>",          ["ScrlByUnits","v", 1]);
 $mw->bind($class, "<Control-Up>",    ["ScrlByPages","v",-1]);
 $mw->bind($class, "<Control-Down>",  ["ScrlByPages","v", 1]);

 $mw->bind($class, "<Left>",          ["ScrlByUnits","h",-1]);
 $mw->bind($class, "<Right>",         ["ScrlByUnits","h", 1]);
 $mw->bind($class, "<Control-Left>",  ["ScrlByPages","h",-1]);
 $mw->bind($class, "<Control-Right>", ["ScrlByPages","h", 1]);

 $mw->bind($class, "<Prior>",         ["ScrlByPages","hv",-1]);
 $mw->bind($class, "<Next>",          ["ScrlByPages","hv", 1]);

 $mw->bind($class, "<Home>",          ["ScrlToPos", 0]);
 $mw->bind($class, "<End>",           ["ScrlToPos", 1]);

 return $class;

}

sub ButtonDown 
{my $w = shift;
 my $e = $w->XEvent;
 my $element = $w->identify($e->x,$e->y);
 $w->configure("-activerelief" => "sunken");
 if ($e->b == 2 and
     (defined($element) && $element =~ /^(trough[12]|slider)$/o))
  {
	my $pos = $w->fraction($e->x, $e->y);
	my($head, $tail) = $w->get;
	my $len = $tail - $head;
		 
	$head = $pos - $len/2;
	$tail = $pos + $len/2;
	if ($head < 0) {
		$head = 0;
		$tail = $len;
	}
	elsif ($tail > 1) {
		$head = 1 - $len;
		$tail = 1;
	}
	$w->ScrlToPos($head);
	$w->set($head, $tail);

	$w->StartDrag($e->x,$e->y);
   }
 else
  {
   $w->Select($element,"initial", $e->b);
  }
}

sub Select 
{
 my $w = shift;
 my $element = shift;
 my $repeat  = shift;
 my $b       = shift;
 return unless defined ($element);
 if ($element eq "arrow1")
  {
   $w->ScrlByUnits("hv",-1);
  }
 elsif ($element eq "trough1" or $element eq "trough2" or $element eq 'slider')
  {
   if ($b == 1)
    {
     $w->ScrlByPages("hv",1);
    }
   else
    {
     $w->ScrlByPages("hv",-1);
    }
  }
 elsif ($element eq "arrow2")
  {
   $w->ScrlByUnits("hv", 1);
  }
 else
  {
   return;
  }

 if ($repeat eq "again")
  {
   $w->RepeatId($w->after($w->cget("-repeatinterval"),["Select",$w,$element,"again",$b]));
  }
 elsif ($repeat eq "initial")
  {
   $w->RepeatId($w->after($w->cget("-repeatdelay"),["Select",$w,$element,"again",$b]));
  }
}

1;

__END__
