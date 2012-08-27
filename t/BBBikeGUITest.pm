# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2003,2006,2012 Slaven Rezic. All rights reserved.
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

use Strassen::Util;

use strict;
use vars qw($VERSION);
$VERSION = 2.00;

my($top, $c);

sub start_guitest {
    warn "Starting GUI test...\n";

    $top = $main::top;
    $c   = $main::c;

    pass "Actually starting GUI test";

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

    $top->after(500, sub { wait_for_chooser_window(0) });
}

sub wait_for_chooser_window {
    my($iteration) = @_;

    my $chooser_window;
    $top->Walk(sub {
    		   my $w = shift;
    		   if ($w->isa('Tk::Toplevel') && $w->title =~ m{^Stra.*en$}) { # XXX damn unicode!
    		       $chooser_window = $w;
    		   }
    	       });
    if ($chooser_window) {
	ok $chooser_window, 'Found chooser window';
	continue_guitest_with_chooser_window($chooser_window);
    } else {
	$iteration++;
	if ($iteration > 20) {
	    fail "Cannot find chooser window after $iteration iterations...";
	    exit_app();
	}
	wait_for_chooser_window($iteration);
    }
}

sub continue_guitest_with_chooser_window {
    my($chooser_window) = @_;

    my $chooser_entry;
    my $chooser_start;
    my $chooser_goal;
    $chooser_window->Walk(sub {
			      my $w = shift;
			      if ($w->isa('Tk::Entry')) {
				  $chooser_entry = $w;
			      } elsif ($w->isa('Tk::Button')) {
				  if ($w->cget('-text') eq 'Start') {
				      $chooser_start = $w;
				  } elsif ($w->cget('-text') eq 'Ziel') {
				      $chooser_goal = $w;
				  }
			      }
			  });
    ok $chooser_entry, 'Found chooser entry';
    ok $chooser_start, 'Found chooser start button';
    ok $chooser_goal, 'Found chooser goal button';

    $chooser_entry->insert("end", "Dudenstr");
    $chooser_start->invoke;
    $chooser_entry->delete(0, "end");
    $chooser_entry->insert("end", "Alexanderplatz");
    $chooser_goal->invoke;

    cmp_ok scalar(@main::realcoords), ">=", 10, 'More than 10 points in route';
    cmp_ok Strassen::Util::strecke($main::realcoords[0], [8763,8780]), "<", 100, "Start is near Dudenstr.";
    cmp_ok Strassen::Util::strecke($main::realcoords[-1], [10970,12822]), "<", 100, "Goal is near Alexanderplatz";
    #require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([\@main::realcoords],[qw()])->Indent(1)->Useqq(1)->Dump; # XXX

    remove_streets_layer();
    exit_app();
}

sub remove_streets_layer {
    main::plot("str", "s", -draw => 0);
    $top->update;
    {
	my @items = $c->find(withtag => "Dudenstr.");
	is @items, 0, "Street layer was removed, no more streets";
    }
}

sub exit_app {
    main::exit_app_noninteractive();
    pass 'Application exited';
}

1;

__END__
