# -*- perl -*-

#
# $Id: Countdown.pm,v 1.2 2004/10/02 08:49:14 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Tk::Countdown;
use strict;
use base qw(Tk::Derived Tk::Label);
Construct Tk::Widget 'Countdown';

sub Populate {
    my($w,$args) = @_;
    $w->SUPER::Populate($args);
    $w->ConfigSpecs(-takeoffcmd => ['CALLBACK']);
}

sub start {
    my $w = shift;
    my $resolution = shift;
    if ($resolution <= 0) {
	$resolution = 1;
    }
    $w->{Repeat} = $w->repeat($resolution*1000, sub {
				  my $text = $w->cget(-text);
				  $text--;
				  $w->configure(-text => $text);
				  if ($text <= 0) {
				      $w->{Repeat}->cancel;
				      $w->Callback(-takeoffcmd => $w);
				  }
			      }
			     );
}

1;

__END__
