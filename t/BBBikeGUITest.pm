# -*- perl -*-

#
# $Id: BBBikeGUITest.pm,v 1.1 2004/01/04 11:12:30 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeGUITest;

use Test::More qw(no_plan);

#plan tests => 1;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

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
    ok(scalar $c->find(withtag => "Dudenstr.") > 0, "Found Dudenstr");
    my(@t) = $c->find(withtag => "Dudenstr.");
    my($xy) = ($c->coords($t[0]))[0];
    is((main::nearest_line_points(split /,/, $xy))[1], $xy);

    main::plot("str", "s", -draw => 0);
    $top->update;
    ok(scalar $c->find(withtag => "Dudenstr.") == 0, "No more streets");
}

1;

__END__
