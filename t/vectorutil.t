#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: vectorutil.t,v 1.2 2009/01/17 21:25:30 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

plan tests => 8;

use_ok('VectorUtil', 'intersect_rectangles', 'normalize_rectangle', 'enclosed_rectangle');

{
    my @r = (0,0,1,1);
    is_deeply([normalize_rectangle(@r)], [@r], "Rectangle already normalized");
}

{
    my @r = (1,1,0,0);
    is_deeply([normalize_rectangle(@r)], [0,0,1,1], "Both describing points need to be swapped");
}

{
    my @r1 = (13.515757392546, 52.4391675592859,
	      13.5297615625, 52.4326147413096);
    @r1 = normalize_rectangle(@r1);

    {
	my @r2 = (13.520982,52.427651,13.530982,52.43765);
	@r2 = normalize_rectangle(@r2);
	ok(intersect_rectangles(@r1, @r2), "Intersection");
    }

    {
	my @r2 = (13.520982,52.427651,13.530982,52.43260);
	@r2 = normalize_rectangle(@r2);
	ok(!intersect_rectangles(@r1, @r2), "No intersection");
    }

    #use Tk;my$mw=tkinit;my $c=$mw->Scrolled("Canvas")->pack(qw(-fill both -expand 1));$mw->bind("<minus>" => sub { $c->scale("all",0,0,0.5,0.5);$c->configure(-scrollregion=>[$c->bbox("all")]); }); $c->createRectangle(515757,43916,529761,43261);$c->createRectangle(520982,42765,530982,43260);$c->configure(-scrollregion=>[$c->bbox("all")]);MainLoop;
}

{
    my @outer = (0,0,3,3);
    my @inner = (1,1,2,2);
    ok(enclosed_rectangle(@outer, @inner), "enclosed easy case");
}

{
    my @outer = (0,0,3,3);
    my @inner = (-1,-1,2,2);
    ok(!enclosed_rectangle(@outer, @inner), "not enclosed, intersecting");
}

{
    my @outer = (0,0,3,3);
    my @inner = (-2,-2,-1,-1);
    ok(!enclosed_rectangle(@outer, @inner), "not enclosed");
}
    
__END__
