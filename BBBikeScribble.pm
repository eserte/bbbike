# -*- perl -*-

#
# $Id: BBBikeScribble.pm,v 1.5 2003/11/16 22:15:54 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package BBBikeScribble;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

package Tk::Babybike; # XXX
no strict; # XXX make strict!!!

use vars qw(
	    $scribble_mode
	    $scribble_frame $scribble_color @scribble_colors $show_scribble
	    $show_scribble_labels
	    $scribble_file $scribble_bbd $scribble_desc
	   );

use vars qw($IDX_SCRIBBLE $IDX_TIME $IDX_LABEL);
$IDX_SCRIBBLE = 0;
$IDX_TIME     = 1;
$IDX_LABEL    = 2;

use vars qw($lastitem);

# init
$scribble_color = 'blue'
    if !defined $scribble_color;
@scribble_colors = qw/red blue yellow3 green black white/
    if !@scribble_colors;
$show_scribble = 1
    if !defined $show_scribble;
$scribble_file = "/tmp/scribble.canvas"
    if !defined $scribble_file;
$scribble_bbd  = "/tmp/scribble.bbd"
    if !defined $scribble_bbd;
$scribble_desc  = "/tmp/scribble.desc"
    if !defined $scribble_desc;
$show_scribble_labels = 1
    if !defined $show_scribble_labels;

sub toggle_scribble_mode {
    if ($scribble_mode) {
	deselect_current_mode()
	    if defined &deselect_current_mode;
	if (defined &MM_SCRIBBLE) {
	    $map_mode = MM_SCRIBBLE();
	} else {
	    $main::map_mode = main::MM_SCRIBBLE(); # XXX
	}
    } else {
	if (defined &MM_BABYBIKE_SELECT) {
	    $map_mode = MM_BABYBIKE_SELECT();
	} else {
	    $main::map_mode = main::MM_SEARCH(); # XXX
	}
    }

    if ((defined &MM_SCRIBBLE && $map_mode == MM_SCRIBBLE()) ||
	(!defined &MM_SCRIBBLE && $main::map_mode == main::MM_SCRIBBLE())) { # XXX
	set_scribble_mode();
    } else {
	deselect_scribble_mode();
    }
}

sub set_scribble_mode {
    if (!$scribble_frame || !Tk::Exists($scribble_frame)) {
	$scribble_frame = $c->Frame
	    (-bg => '#c0c0c0');
	foreach my $color_name (@scribble_colors, 'delete', 'label') {
	    $scribble_frame->Radiobutton
		(-text => $color_name,
		 ($color_name !~ /^(delete|label)$/ ? (-fg => $color_name) : ()),
		 -value => $color_name,
		 -variable => \$scribble_color,
		 -padx => 0, -pady => 0,
		 -highlightthickness => 0,
		 -anchor => 'w',
		)->pack(-anchor => 'nw',
			-fill => 'x');
	}
    }
    $scribble_frame->idletasks;
    $scribble_frame->place('-relx' => 1,
			   '-x' => -$scribble_frame->reqwidth,
			   '-rely' => 1,
			   '-y' => -$scribble_frame->reqheight);
    if (!$show_scribble) {
	$show_scribble = 1;
	set_show_scribble();
    }
    $c->configure(-cursor => "hand2");
}

sub deselect_scribble_mode {
    if ($scribble_frame && Tk::Exists($scribble_frame)) {
	$scribble_frame->placeForget;
    }
}

sub set_show_scribble {
    $c->itemconfigure('scribble',
		      -state => ($show_scribble ? 'normal' : 'hidden'));
}

sub set_show_scribble_labels {
    $c->itemconfigure('scribble-label',
		      -state => ($show_scribble_labels ? 'normal' : 'hidden'));
}

sub load_scribble {
    my $mw = $c->toplevel;
    if ($c->find("withtag" => "scribble")) {
	if ($mw->messageBox(-title => 'Delete?',
			    -message => 'Delete existing scribble?',
			    -icon => 'question',
			    -type => 'YesNo') =~ /no/i) {
	    return;
	}
    }
    $mw->Busy(-recurse => 1);
    eval {
	$c->delete("scribble");
	$c->load_canvas($scribble_file);
    };
    my $err = $@;
    $mw->Unbusy;
    warn $err if $err;
}

sub save_scribble {
    my @items = $c->find("withtag" => "scribble");
    if (!@items) {
	common_dialog("No scribble to save");
	return;
    }

    my $mw = $c->toplevel;
    $mw->Busy(-recurse => 1);
    eval {
	$c->save_canvas($scribble_file, withtag => "scribble");
	warn "OK, saved to $scribble_file";
    };
    my $err = $@;
    eval {
	$anti_transpose = \&main::anti_transpose if !$anti_transpose;
	# XXX does not work with bbbike, only with tkbabybike
	# XXX is this still true???
	if (open(BBD, ">$scribble_bbd")) {
	    foreach my $item (@items) {
		my $color = $c->itemcget($item, -fill);
		my @tags = $c->gettags($item);
		(my $time  = $tags[$IDX_TIME]) =~ s/^T//;
		(my $label = $tags[$IDX_LABEL]) =~ s/^L//;
		my @coords = $c->coords($item);
		print BBD $label . ($label ne '' ? ' ' : '') .
		    scalar(localtime($time))."\t$color";
		for(my $i=0; $i<$#coords; $i+=2) {
		    my($x,$y) = $anti_transpose->($coords[$i],$coords[$i+1]);
		    printf BBD " %d,%d", $x,$y;
		}
		print BBD "\n";
	    }
	    close BBD;

	    if (open(DESC, ">$scribble_desc")) {
		foreach my $color_name (@scribble_colors) {
		    printf DESC "\$category_color{'$color_name'} = '#%02x%02x%02x';\n",
			map { $_/256 } $mw->rgb($color_name);
		}
		close DESC;
	    }
	}
    };
    $err .= $@;
    $mw->Unbusy;
    main::status_message($err, "error") if $err;
}

sub handle_button1_scribble {
    my($w,$e) = @_;
    if ($scribble_color eq 'delete') {
	my(@tags) = $c->gettags('current');
	if (grep {$_ eq 'scribble'} @tags) {
	    $c->delete('current');
	}
    } elsif ($scribble_color eq 'label') {
	my(@tags) = $c->gettags('current');
	if (grep {$_ eq 'scribble'} @tags) {
	    @tags = map { $_ eq 'current' ? () : $_ } @tags;
	    my $item = $c->find("withtag", "current");
	    (my $label = $tags[$IDX_LABEL]) =~ s/^L//;
	    my $mw = $c->toplevel;
	    my $t = $mw->Toplevel(-title => "Label");
	    $t->transient($mw);
	    my $e = $t->Entry(-textvariable => \$label)->grid(-columnspan => 2);
	    $e->focus;
	    my $cont = 0;
	    my $okcb = sub {
		$c->dtag($item, $tags[$IDX_LABEL]);
		$label =~ s/\s+/_/g;
		$c->addtag("L$label",
			   "withtag", $item,
			  );
		my(@c) = $c->coords($item);
		$c->createText(@c[0,1], -text => $label, -anchor => "sw",
			       -state => ($show_scribble_labels ? "normal" : "hidden"),
			       -tags => ['scribble', 'scribble-label']);
		# XXX deleting labels?
		$cont++;
	    };
	    Tk::grid(my $okb = $t->Button
		     (-text => 'OK',
		      -command => $okcb),
		     $t->Button
		     (-text => 'Cancel',
		      -command => sub { $cont++ }
		     )
		    );
	    $e->bind("<Return>" => sub { $okcb->() });
	    $t->waitVariable(\$cont);
	    $t->destroy;
	}
    } else {
	($lastx,$lasty) = ($c->canvasx($e->x), $c->canvasy($e->y));
	$lastitem =
	    $c->createLine($lastx,$lasty,$lastx,$lasty,
			   -width => 2, -fill => $scribble_color,
			   -capstyle => 'round',
			   -tags => ['scribble', "T".time, "L"]);
    }
}

sub handle_button1_motion_scribble {
    my($w,$e) = @_;
    my($cx,$cy) = ($c->canvasx($e->x), $c->canvasy($e->y));
    if ($scribble_color eq 'delete') {
	my(@items) = $c->find('overlapping', $cx-1,$cy-1,$cx+1,$cy+1);
	foreach my $item (@items) {
	    if (grep {$_ eq 'scribble'} $c->gettags($item)) {
		$c->delete($item);
	    }
	}
    } elsif ($scribble_color ne 'label') {
	$c->createLine($lastx,$lasty,$cx,$cy,
		       -width => 2, -fill => $scribble_color,
		       -capstyle => 'round',
		       -tags => ['scribble', "T".time, "L"]);
	($lastx,$lasty) = ($cx,$cy);
    }
}

1;

__END__
