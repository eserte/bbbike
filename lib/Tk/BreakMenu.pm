# -*- perl -*-

#
# $Id: BreakMenu.pm,v 1.3 2002/08/01 21:30:53 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2000 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package
    Tk::Menu;
use strict;
use vars qw($VERSION);

$VERSION = '0.01';

=head2 BreakMenu

    use Tk::BreakMenu;
    $menu->BreakMenu;

Insert -columnbreak => 1 to prevent menus from being longer than the screen.

=cut

sub BreakMenu {
    my $menu = shift;

    return if $Tk::VERSION < 800; # -columnbreak is introduced in Tk 8.0

    for my $i (0 .. $menu->index("last")) {
	if ($menu->type($i) eq 'cascade') {
	    my $cascade = $menu->entrycget($i, '-menu');
	    $cascade->BreakMenu;
	}
    }

    return unless $menu->cget('-type') eq 'normal'; # XXX check if this is working

    if ($menu->reqheight > $menu->screenheight) {
	for my $i (0 .. $menu->index("last")) {
	    if ($menu->yposition($i) + 30 > $menu->screenheight) { # reserve space for titlebar
		$menu->entryconfigure($i, -columnbreak => 1);
	    }
	}
    }
}

1;

__END__




