# -*- perl -*-

#
# $Id: BBBikeGUITest.pm,v 1.3 2006/08/29 23:06:28 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003,2006 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

#
# Usage:
#   cd .../bbbike
#   env BBBIKE_GUI_TEST=BBBikeGUITest perl -It ./bbbike -public
#

package BBBikeGUITest;

use Test::More qw(no_plan);

#plan tests => 1;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

sub start_guitest {
    warn "Starting GUI test...\n";

    my $top = $main::top;
    my $c   = $main::c;

    ok(1, "Actually starting GUI test");

 SKIP: {
	skip "No cursor control tests for now...", 1;

	skip "Tk::CursorControl not installed", 1
	    if !eval { require Tk::CursorControl };

	my $cc = $top->CursorControl;
	$cc->warpto($c);
	$c->eventGenerate("<Key-S>");
	ok(1);
    }

    main::plot("str", "s", -draw => 1);
    $top->update;
    pass("Streets plotted");

    my(@t) = $c->find(withtag => "Dudenstr.");
    cmp_ok(scalar(@t), ">", 0, "Found Dudenstr");
    my @c = $c->coords($t[0]);
    my($x,$y) = @c[0,1];
    @t = eval { main::nearest_line_points($x,$y,$c->gettags($t[0])) };
    is($t[0], 0, "First index in Dudenstr.");
    my($tx,$ty) = main::transpose(@{ $t[2] });
    cmp_ok(abs($tx-$x), "<", 1)
	or diag "result from nearest_line_points: @t";
    cmp_ok(abs($ty-$y), "<", 1)
	or diag "result from nearest_line_points: @t";

    main::plot("str", "s", -draw => 0);
    $top->update;
    cmp_ok(scalar($c->find(withtag => "Dudenstr.")), "==", 0, "No more streets");
}

1;

__END__
