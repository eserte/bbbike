# -*- perl -*-

#
# $Id: BBBikeEdit.pm,v 1.128 2009/02/14 13:39:57 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 1998,2002,2003,2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

# better: use auto-loading

package BBBikeEdit;

package main;
use strict;
use vars qw($top $c $scale %font
	    $special_edit $edit_mode $edit_normal_mode
	    %str_draw %str_obj %str_file %p_file %p_draw %p_obj %ampeln
	    $os $verbose %category_color @realcoords $progress
	    $tmpdir $progname %tmpfiles);
my($c1, $c2, $f1, $f2);
my(%crossing, $net);
my $radweg_file;
my $ampelschaltung_file;
my $autosave = 1;
my($lastrw1, $lastrw2);
my $radweg_last_b2_mode;

my(@radweg_data, %radweg);
my(@ampel_data, %ampel_schaltung, $ampelschaltung_obj);
my @lastampeldate;
my $rel_time_begin = "";
my($ampel_hlist, $ampel2_hlist,
   $ampel_current_crossing, $ampel_current_coord,
   $ampel_red_itemstyle, $ampel_green_itemstyle, $ampel_blue_itemstyle,
   @ampel_entry, $ampel_add, $ampel_extra,
   $ampel_time_photo,
   $ampelschaltung2,
   %ampel_all_cycle, $ampel_draw_restrict
  );
my $ampel_show_all = 0;
my(%label_index, $label_anchor, $label_text, $label_coord, $label_rotated,
   $label_i, $label_entry);
my(%vorfahrt_index, $vorfahrt_anchor, $vorfahrt_text, $vorfahrt_coord,
   @vorfahrt_build);

######################################################################
# Allgemein
#
sub edit_mode_toggle {
    my $type = shift;
    eval $type . '_edit_toggle()';
    warn $@ if $@;
}

sub edit_mode_undef {
    my $type = shift;
    eval $type . '_undef_all()';
    warn $@ if $@;
}

sub edit_mode_save_as {
    main::status_message("Using edit mode is deprecated!", "die");
    my $type = shift;
    eval $type . '_save_as()';
    warn $@ if $@;
}

######################################################################
# Radwege
#
sub radweg_edit_toggle {
    main::status_message("Using radweg edit mode is deprecated!", "die");
    if ($special_edit eq 'radweg') {
	radweg_edit_modus();
    } else {
	radweg_edit_off();
    }
}

sub radweg_edit_activate {
    $special_edit = 'radweg';
    set_mouse_desc();
}

sub radweg_edit_modus {
    require Radwege;
    $special_edit = 'radweg';
#XXX utilize $edit_normal_mode?
#XXX    switch_edit_berlin_mode() if (!defined $edit_mode or $edit_mode ne 'b');
    radweg_open();
    unless ($str_draw{'s'}) {
	plot('str','s', -draw => 1);
    }
    unless ($c->find("withtag", "rw-edit")) {
	radweg_draw_canvas();
    }
    if (keys %crossing == 0) {
	my $s = new Strassen $str_file{'s'} . "-orig";
	%crossing = %{ $s->all_crossings(RetType => 'hash',
					 UseCache => 1,
					 Kurvenpunkte => 1) };
    }
    set_mouse_desc();
    my $cursorfile = defined &main::build_text_cursor ? main::build_text_cursor("RW") : undef;
    $main::c->configure(-cursor => $cursorfile);

    $radweg_last_b2_mode = $main::b2_mode;
    $main::b2_mode = main::B2M_CUSTOM();
    $main::b2m_customcmd = \&radweg_edit_mouse3;
    main::set_b2();
}

sub radweg_undef_all {
    undef %crossing;
}

sub radweg_edit_off {
    $special_edit = '';
    set_mouse_desc();
## efficiency:
#    $c->delete("rw");
    if (defined $radweg_last_b2_mode) {
	$main::c->configure(-cursor => undef);
	$main::b2_mode = $radweg_last_b2_mode;
	undef $radweg_last_b2_mode;
	undef $main::b2m_customcmd;
	main::set_b2();
    }
}

sub radweg_edit_mouse1 {
    return unless grep($_ =~ /^[sl]$/, $c->gettags('current'));
    my($i,$pm,$p1a,$p2a) = nearest_line_points_mouse($c);
    return if (!defined $i);
    my $p1 = Route::_coord_as_string($p1a);
    my $p2 = Route::_coord_as_string($p2a);
    my $index;
    if (exists $radweg{$p1}->{$p2}) {
	$index = $radweg{$p1}->{$p2};
    } elsif (exists $radweg{$p2}->{$p1}) {
	$index = $radweg{$p2}->{$p1};
    } else {
	$index = radweg_new_point($p1, $p2);
    }
    radweg_display_index($index);
}

sub radweg_edit_mouse3 {
    return if !defined $lastrw1 or !defined $lastrw2;
    my($i,$pm,$p1a,$p2a) = nearest_line_points_mouse($c);
    return if (!defined $i);
    my $p1 = Route::_coord_as_string($p1a);
    my $p2 = Route::_coord_as_string($p2a);
    my $index;
    if (exists $radweg{$p1}->{$p2}) {
	$index = $radweg{$p1}->{$p2};
    } elsif (exists $radweg{$p2}->{$p1}) {
	$index = $radweg{$p2}->{$p1};
    } else {
	$index = radweg_new_point($p1, $p2);
    }
    $radweg_data[$index]->[2] = $lastrw1;
    $radweg_data[$index]->[3] = $lastrw2;
    radweg_save() if $autosave;
    radweg_draw_canvas($index);
    radweg_display_index($index);
}

sub radweg_display_index {
    my($index) = @_;
    my $t = redisplay_top($top, "radweg", -title => 'Radwege');
    if (defined $t) {
	my $mainf = $t->Frame->pack(-fill => 'both', -expand => 1);
	$f1 = $mainf->Frame(-relief => 'ridge',
			    -bd => 2,
			   )->pack(-side => 'left', -fill => 'both',
				   -expand => 1);
	$f2 = $mainf->Frame(-relief => 'ridge',
			    -bd => 2,
			   )->pack(-side => 'left', -fill => 'both',
				   -expand => 1);

	foreach my $dir ('1', '2') {
	    eval
	      "\$c$dir = \$f$dir" . 
	      '->Canvas(-bg => "white", -width => 30, -height => 30)->pack;';
	    die $@ if $@;
	    foreach my $type (@Radwege::category_order) {
		my $name = $Radwege::category_name{$type};
		eval "\$f$dir->Radiobutton(-text => '$name', -value => '$type')->pack(-anchor => 'w');";
		die $@ if $@;
	    }
	}

	my $redisplay_sub = sub {
	    radweg_draw_canvas();
	};
	my $close_sub = sub {
	    $t->destroy;
	};
	my $save_sub = sub {
	    radweg_save();
	};

	my $butf = $t->Frame->pack(-fill => 'x', -expand => 1);
	my $redisplayb = $butf->Button(-text => 'Neu zeichnen',
				       -command => $redisplay_sub,
				      )->pack(-side => 'left');
	$redisplayb->focus;
	$butf->Button(-text => 'Sichern',
		      -command => $save_sub,
		     )->pack(-side => 'left');
	$butf->Checkbutton(-text => 'Auto-Sichern',
			   -variable => \$autosave,
			  )->pack(-side => 'left');
	my $closeb = $butf->Button
	  (Name => 'close',
	   -command => $close_sub)->pack(-side => 'left');
	$t->bind('<Escape>' => $close_sub);
    }

    foreach my $dir ('1', '2') {
	my $idx1 = ($dir eq '1' ? 2 : 3);
	my $reverse = ($dir eq '1' ? 0 : 1);
	eval 
	  "radweg_draw_arrow(\$c$dir, $index, $reverse);" .
	  "";
	die $@ if $@;
    }
    foreach my $w ($f1->children) {
	if ($w->isa('Tk::Radiobutton')) {
	    $w->configure
	      (-variable => \$radweg_data[$index]->[2],
	       -command => sub { radweg_draw_canvas($index);
				 radweg_save() if $autosave;
				 $lastrw1 = $radweg_data[$index]->[2];
				 $lastrw2 = $radweg_data[$index]->[3];
			     },
	      );

	}
    }
    foreach my $w ($f2->children) {
	if ($w->isa('Tk::Radiobutton')) {
	    $w->configure
	      (-variable => \$radweg_data[$index]->[3],
	       -command => sub { radweg_draw_canvas($index);
				 radweg_save() if $autosave;
				 $lastrw1 = $radweg_data[$index]->[2];
				 $lastrw2 = $radweg_data[$index]->[3];
			     },
	      );
	}
    }
}

# XXX still using internally the old format and not a Strassen object
sub BBBikeEdit::radweg_open {
    require Strassen::Core;
    my $s = Strassen->new("$str_file{rw}-orig");
    if (!$s) {
	status_message("Can't find $str_file{rw}-orig", "err");
	return;
    }
    $radweg_file = $s->file;
    $s->init;
    my %rev_category_code = reverse %Radwege::category_code;
    @radweg_data = ();
    %radweg = ();
    while(1) {
	my $r = $s->next;
	last if !@{ $r->[Strassen::COORDS()] };
	# same as in miscsrc/convert_radwege:
	my @l = @{$r->[Strassen::COORDS()]}[0,1];
	my($hin,$rueck) = split /;/, $r->[Strassen::CAT()];
	$l[2] = $rev_category_code{$hin} || "kein";
	$l[3] = $rev_category_code{$rueck} || "kein";
	radweg_new_point(@l);
    }
    BBBikeEdit::ask_for_co($top, $radweg_file);
}

sub radweg_old_open {
    require MyFile;
    $radweg_file = MyFile::openlist(*RW, map { "$_/$str_file{rw}-orig" }
				       @Strassen::datadirs);
    warn "radweg_file=$radweg_file" if $verbose;
    if ($radweg_file) {
	@radweg_data = ();
	%radweg = ();
	while(<RW>) {
	    next if (/^\s*\#/);
	    chomp;
	    my(@l) = split(/\s+/);
	    radweg_new_point(@l);
	}
	close RW;
	BBBikeEdit::ask_for_co($top, $radweg_file);
    }
}

sub radweg_save {
    main::status_message("Using radwege edit mode is deprecated!", "die");
    if ($radweg_file) {
	BBBikeEdit::ask_for_co($main::top, $radweg_file);
	open(RW, ">$radweg_file") or main::status_message($!, "die");
	binmode RW; # XXX check on NT
	print RW _auto_rcs_header();
	for my $F (@radweg_data) {
	    my(@F) = @$F;
	    print RW "\t$Radwege::category_code{$F[2]};$Radwege::category_code{$F[3]} $F[0] $F[1]\n";
	}
	close RW;
    }
}

sub radweg_old_save {
    main::status_message("Using edit mode is deprecated!", "die");
    if ($radweg_file) {
	BBBikeEdit::ask_for_co($main::top, $radweg_file);
	open(RW, ">$radweg_file") or main::status_message($!, "die");
	binmode RW; # XXX check on NT
	print RW _auto_rcs_header();
	print RW join("\n", map { join("\t", @$_) } @radweg_data), "\n";
	close RW;
    }
}

sub radweg_save_as {
    main::status_message("Using edit mode is deprecated!", "die");
    my $file = $top->getSaveFile;
    if ($file) {
	$radweg_file = $file;
	radweg_save();
    }
}

sub radweg_new_point {
    my($p1, $p2, $dir1, $dir2) = @_;
    $dir1 = 'kein' if (!defined $dir1);
    $dir2 = 'kein' if (!defined $dir2);
    push @radweg_data, [$p1, $p2, $dir1, $dir2];
    if (exists $radweg{$p1}->{$p2} or
	exists $radweg{$p2}->{$p1}) {
	warn "Die Strecke $p1 -> $p2 existiert bereits!";
    }
    $radweg{$p1}->{$p2} = $#radweg_data;
    $radweg{$p2}->{$p1} = $#radweg_data;
    return $#radweg_data;
}

sub radweg_draw_arrow {
    my($c, $index, $reverse) = @_;
    $c->delete('all');
    $c->idletasks;
    my($c_w, $c_h) = ($c->width, $c->height);
    my($x1,$y1,$x2,$y2) = (split(/,/, $radweg_data[$index]->[0]),
			   split(/,/, $radweg_data[$index]->[1]),
			  );
    my $len = Strassen::Util::strecke_s($radweg_data[$index]->[0],
					$radweg_data[$index]->[1]);
    my($cx1, $cy1, $cx2, $cy2) = ($c_w/2, $c_h/2,
				  ($x2-$x1)/$len*15+$c_w/2,
				  ($y1-$y2)/$len*15+$c_h/2);
    $c->createLine($cx1, $cy1, $cx2, $cy2,
		   -arrow => ($reverse ? 'first' : 'last'),
		   -width => 4,
		  );
}

sub BBBikeEdit::radweg_draw_canvas {
    my $index = shift;
    my @data;
    my %color;
    require Radwege;
    while(my($k,$v) = each %Radwege::category_code) {
	$color{$k} = $category_color{$v};
    }
    if (defined $index) {
	$c->delete("rw-$index");
	@data = $radweg_data[$index];
    } else {
	$c->delete("rw");
	$index = 0;
	@data = @radweg_data;
    }
    if (@data > 1) {
	IncBusy($top);
	require File::Basename;
	$progress->Init(-dependents => $c,
			-label => File::Basename::basename($radweg_file));
    }
local $scale = 1;#XXX remove $scale
    eval {
	my $i = 0;
	foreach my $l (@data) {
	    $progress->Update($i/($#data+1)) if @data > 1 && $i++ % 80 == 0;
	    my($x1, $y1, $x2, $y2) = (split(/,/, $l->[0]),
				      split(/,/, $l->[1]),
				     );
	    ($x1,$y1) = main::transpose($x1,$y1);
	    ($x2,$y2) = main::transpose($x2,$y2);
	    my $alpha = atan2($y2-$y1, $x2-$x1);
	    my $beta  = $alpha-3.141592653/2;
	    my($dx, $dy) = (3*cos($beta), 3*sin($beta));
	    if ($l->[2] ne 'kein') {
		$c->createLine($scale*($x1-$dx), $scale*($y1-$dy),
			       $scale*($x2-$dx), $scale*($y2-$dy),
			       -fill => $color{$l->[2]},
			       -width => 3,
			       -tags => ['rw', "rw-$index", 'rw-edit']);
	    }
	    if ($l->[3] ne 'kein') {
		$c->createLine($scale*($x1+$dx), $scale*($y1+$dy),
			       $scale*($x2+$dx), $scale*($y2+$dy),
			       -fill => $color{$l->[3]},
			       -width => 3,
			       -tags => ['rw', "rw-$index", 'rw-edit']);
	    }
	    $index++;
	}
	restack();
    };
    warn $@ if $@;
    if (@data > 1) {
	$progress->Finish;
	DecBusy($top);
    }
}

######################################################################
# Ampelschaltungen
#
sub ampel_edit_toggle {
    if ($special_edit eq 'ampel') {
	ampel_edit_modus();
    } else {
	ampel_edit_off();
    }
}

sub ampel_edit_modus {
    $progress->InitGroup;
    require Ampelschaltung;
    $special_edit = 'ampel';
#XXX utilize $edit_normal_mode?
#XXX    switch_edit_berlin_mode() if (!defined $edit_mode or $edit_mode ne 'b');

    IncBusy($top);
    $progress->Init(-dependents => $c,
		    -label => "Berechnen des Straßennetzes...");
    eval {
	my $s;
	if (keys %crossing == 0) {
	    $s = new Strassen $str_file{'s'} . "-orig";
	    %crossing = %{ $s->all_crossings(RetType => 'hash',
					     UseCache => 1,
					     Kurvenpunkte => 1) };
	}
	if (!defined $net) {
	    $s = new Strassen $str_file{'s'} . "-orig" if !$s;
	    $net = new StrassenNetz $s;
	    $net->make_net(Progress => $progress);
	}
    };
    status_message($@, 'err') if ($@);
    $progress->Finish;
    DecBusy($top);

    ampel_open();

    unless ($ampelschaltung2) {
	$ampelschaltung2 = new Ampelschaltung2;
	if (!$ampelschaltung2->open) {
	    warn "Ampelschaltung2 konnte nicht geladen werden.";
	    undef $ampelschaltung2;
	}
    }

    unless ($p_draw{'lsa'}) {
	plot('p','lsa', -draw => 1);
    }
    special_raise("lsa-fg");
#XXX
#     if (!defined $ampel_time_photo) {
# 	$ampel_time_photo = $top->Photo
# XXX gif => xpm
# 	  (-file => Tk::findINC("ampel_time.gif"));
#     }
#     if (defined $ampel_time_photo) {
# 	foreach (@ampel_data) {
	    
# 	}
#     }

    $ampel_draw_restrict = "";
    ampel_meta_draw_canvas();

    set_mouse_desc();

    $progress->FinishGroup;
}

sub ampel_edit_off {
    $special_edit = '';
    set_mouse_desc();
}

sub ampel_undef_all {
    undef $ampelschaltung2;
    undef %crossing;
    undef $net;
}

sub ampel_edit_mouse1 {
    my @tags = $c->gettags('current');
    unless (grep { $_ =~ /^lsa/ && $_ !~ /^lsas-t/ } @tags) {
	(my($item), @tags) = find_below($c, "lsa-fg");
	if (!defined $item) {
	    warn "lsa tag not found at current point";
	    return;
	}	    
    }
    my $p1 = $tags[1]; # XXX oder 2
    if (!exists $ampel_schaltung{$p1}) {
	ampel_new_point($p1);
    }
    ampel_display($p1);
}

sub ampel_edit_mouse3 { }

# XXX Statt Indices Konstanten verwenden!
sub ampel_display {
    my($p1) = @_;
    if (exists $crossing{$p1}) {
	$ampel_current_crossing = join("/", @{$crossing{$p1}});
	$ampel_current_crossing = substr($ampel_current_crossing, 0, 42)
	  . "..."
	    if length($ampel_current_crossing) > 45;
	$ampel_current_coord = $p1;
    }
    my $index = $ampel_schaltung{$p1};
    my $t = redisplay_top($top, "ampelschaltung",
			  -title => 'Ampelschaltung',
			 );
    my(@header_list) =
	qw(Wochentag Zeit von nach grün rot Zyklus Comment Date lost);
    my(@entry_desc) =
	(qw(Wochentag Zeit), "von (Himmelsrichtung)",
	 "nach (Himmelsrichtung)", "Grünphase", "Rotphase",
	 "Zyklus", "Kommentar", "Datum");
    my $hlist_cols = scalar @entry_desc;
    my $hlist_out_cols = scalar @header_list;
    if (defined $t) {
	require Tk::HList;
	require Tk::Adjuster;
	require Tk::Balloon;
	my $mainf = $t->Frame->pack(-fill => 'both', -expand => 1);
	my $lf = $mainf->Frame->pack;
	$lf->Label(-textvariable => \$ampel_current_crossing,
		   -anchor => 'w',
		  )->pack(-side => 'left');
	$lf->Label(-textvariable => \$ampel_current_coord,
		   -anchor => 'w',
		  )->pack(-side => 'left');
	$ampel_hlist = $mainf->Scrolled
	  ('HList',
	   -header  => 1,
	   -columns => $hlist_out_cols,
	   -selectmode => 'single',
	   -scrollbars => 'osoe',
	   -width => 50,
	   -height => 5,
	  )->packAdjust(-expand => 1, -fill => 'both');
	$ampel2_hlist = $mainf->Scrolled
	  ('HList',
	   -header  => 1,
	   -columns => $hlist_out_cols,
	   -selectmode => 'single',
	   -scrollbars => 'osoe',
	   -width => 50,
	   -height => 6,
	  )->pack(-expand => 1, -fill => 'both');
	eval {
	    require Tk::ItemStyle;
	    require Tk::ResizeButton;
	    require BBBikeTkUtil;
	    my $headerstyle = $ampel_hlist->ItemStyle('window', -padx => 0,
						      -pady => 0);
	    my(@header, @header2);
	    my $i = 0;
	    my $scr_hlist  = $ampel_hlist->Subwidget('scrolled');#XXX
	    my $scr2_hlist = $ampel2_hlist->Subwidget('scrolled');#XXX
	    for (@header_list) {
		my $ii = $i;
		$header[$i] = $ampel_hlist->ResizeButton
		  (-text => $_,
		   -relief => 'flat', -pady => 0,
		   -widget => \$scr_hlist,
		   -command => sub { BBBikeTkUtil::sort_hlist($scr_hlist, $ii) },
		   -column => $i,
		   -padx => 0, -pady => 0,
		  );
		$header2[$i] = $ampel2_hlist->ResizeButton
		  (-text => $_,
		   -relief => 'flat', -pady => 0,
		   -widget => \$scr2_hlist,
		   -command => sub { BBBikeTkUtil::sort_hlist($scr2_hlist, $ii) },
		   -column => $i,
		   -padx => 0, -pady => 0,
		  );
		$i++;
	    }
	    $i = 0;
	    for $i (0 .. $#header) {
		$ampel_hlist->header('create', $i, -itemtype => 'window',
				     -widget => $header[$i],
				     -style => $headerstyle);
		$ampel2_hlist->header('create', $i, -itemtype => 'window',
				      -widget => $header2[$i],
				      -style => $headerstyle);
	    }
	};
	if ($@) {
	    warn $@ if $verbose;
	    foreach ($ampel_hlist, $ampel2_hlist) {
		my $i = 0;
		foreach my $h (@header_list) {
		    $_->header('create', $i, -text => $h);
		    $i++;
		}
	    }
	}

	eval {
	    require Tk::ItemStyle;
	    $ampel_red_itemstyle =
	      $mainf->ItemStyle('text', -foreground => 'red',
				-background => $mainf->cget(-background));
	    $ampel_green_itemstyle =
	      $mainf->ItemStyle('text', -foreground => 'DarkGreen',
				-background => $mainf->cget(-background));
	    $ampel_blue_itemstyle =
	      $mainf->ItemStyle('text', -foreground => 'blue',
				-background => $mainf->cget(-background));
	};

	my @entry_width = (3,5,2,2,3,3,3,10,8);

	my $entry_f = $mainf->Frame->pack(-fill => "x");

	my $current_field = "";
	{
	    my $status_f = $mainf->Frame->pack(-fill => "x");
	    $status_f->Label(-relief => "sunken",
			     -width => 20,
			     -bd => 2,
			     -anchor => "w",
			     -textvariable => \$current_field,
			    )->pack(-side => "left");
	    my $rel_time_begin_e = $status_f->Entry
		(-textvariable => \$rel_time_begin,
		 -width => 8,
		)->pack(-side => "left");
	    $rel_time_begin_e->bind
		("<FocusIn>" => sub {
		     $current_field = "Anfangszeit für relative Zeiteingabe";
		 });
	}

	for my $j (0 .. $hlist_cols-1) {
	    my $j = $j;
	    $ampel_entry[$j] = $entry_f->Entry(-width => $entry_width[$j]
					      )->pack(-side => 'left');
	    $ampel_entry[$j]->bind("<FocusIn>" => sub {
				       $current_field = $entry_desc[$j];
				   });
	    $entry_f->Label(-text => '->')->pack(-side => 'left')
		if ($j == 2); # zwischen "von" und "nach"
	}
	for my $j (0 .. $hlist_cols-2) {
	    $ampel_entry[$j]->bind('<Return>' => sub {
				       $ampel_entry[$j+1]->tabFocus;
				   });
	}
	$ampel_entry[1]->bind
	    ("<FocusOut>" => sub {
		 my $time = $ampel_entry[1]->get;
		 if ($rel_time_begin !~ /^\s*$/ && $time !~ /^\s*$/) {
		     if (my($h0,$m0,$s0) = $rel_time_begin =~ /^(\d{1,2}):(\d{2}):(\d{2})$/) {
			 if (my($m,$s) = $time =~ /^(\d{1,2}):(\d{2})$/) {
			     my $h = 0;
			     $s += $s0;
			     if ($s >= 60) { $m++; $s %= 60 }
			     $m += $m0;
			     if ($m >= 60) { $h++; $s %= 60 }
			     $h += $h0;
			     if ($h >= 24) {
				 status_message("Wrap date!", "warn");
			     }
			     $ampel_entry[1]->delete("0", "end");
			     $ampel_entry[1]->insert
				 ("end", sprintf "%d:%02d:%02d", $h, $m, $s);
			 }
		     } else {
			 status_message("Falsches Format für Startwert der relativen Zeitangabe", "error");
		     }
		 }
	     });

	$ampel_entry[4]->configure(-fg => 'DarkGreen');
	$ampel_entry[5]->configure(-fg => 'red');
	$ampel_entry[6]->configure(-fg => 'blue');
	$ampel_add = $entry_f->Button(-text => 'Add')->pack;
	$ampel_entry[$hlist_cols-1]->bind('<Return>' => sub {
					      $ampel_add->invoke
					  });

	my $close_sub = sub {
	    $t->destroy;
	};
	my $save_sub = sub {
	    ampel_save();
	};

	my $butf = $t->Frame->pack(-fill => 'x');
	$butf->Button(-text => 'Sichern',
		      -command => $save_sub,
		     )->pack(-side => 'left');
	$butf->Checkbutton(-text => 'Auto-Sichern',
			   -variable => \$autosave,
			  )->pack(-side => 'left');
	$butf->Checkbutton(-text => 'Alle zeigen',
			   -variable => \$ampel_show_all,
			  )->pack(-side => 'left');
	$butf->Button(-text => 'Dump',
		      -command => sub {
			  if ($ampelschaltung2) {
			      my $dump = $ampelschaltung2->dump;
			      my $dump_file = "/tmp/ampelschaltung.dump";
			      open(DUMP, "> $dump_file")
				  or main::status_message("Kann nicht nach $dump_file schreiben: $!", "die");
			      print DUMP $dump;
			      close DUMP;
			      main::status_message("Erfolgreich nach $dump_file geschrieben", "info");
			  } else {
			      main::status_message("Kein Ampelschaltung-Objekt vorhanden?!", "err");
			  }
		      })->pack(-side => "left");
	my $closeb = $butf->Button
	  (Name => 'close',
	   -command => $close_sub)->pack(-side => 'left');

	my $butf2 = $t->Frame->pack(-fill => 'x');
	$butf2->Button(-text => 'Canvas neu zeichnen',
		       -command => \&ampel_meta_draw_canvas
		       )->pack(-side => 'left');
	$butf2->Radiobutton(-text => 'Alle',
			    -variable => \$ampel_draw_restrict,
			    -value => '',
			    -command => \&ampel_meta_draw_canvas
			    )->pack(-side => 'left');
	$butf2->Radiobutton(-text => 'Tages-',
			    -variable => \$ampel_draw_restrict,
			    -value => 'tagesverkehr',
			    -command => \&ampel_meta_draw_canvas
			    )->pack(-side => 'left');
	$butf2->Radiobutton(-text => 'Berufs-',
			    -variable => \$ampel_draw_restrict,
			    -value => 'berufsverkehr',
			    -command => \&ampel_meta_draw_canvas
			    )->pack(-side => 'left');
	$butf2->Radiobutton(-text => 'Nacht-',
			    -variable => \$ampel_draw_restrict,
			    -value => 'nachtverkehr',
			    -command => \&ampel_meta_draw_canvas
			    )->pack(-side => 'left');
	$butf2->Label(-text => 'Verkehr')->pack(-side => 'left');

	$t->bind('<Escape>' => $close_sub);
    }

    my $add_hlist_entry = sub {
	my($i) = shift;
	my(@data) = split(/,/, $ampel_data[$index]->[$i]);
	if ((!defined $data[6] or $data[6] eq '') and
	    (defined $data[4] and $data[4] ne '') and
	    (defined $data[5] and $data[5] ne '')
	   ) {
	    # Zyklus berechnen, falls möglich
	    $data[6] = $data[4]+$data[5];
	}
	if ((defined $data[4] and $data[4] ne '') and
	    (defined $data[5] and $data[5] ne '')
	   ) {
	    # verlorene Zeit
	    my %res = Ampelschaltung::lost(-rot   => $data[5],
					   -gruen => $data[4],
					  );
	    $data[9] = sprintf "%.1f", $res{-zeit};
	}
	$ampel_hlist->add($i, -text => $data[0], -data => $i);
	for my $j (1 .. $hlist_out_cols-1) {
	    $ampel_hlist->itemCreate($i, $j, -text => $data[$j]);
	}
	$ampel_hlist->itemConfigure($i, 4, -style => $ampel_green_itemstyle)
	  if ($ampel_green_itemstyle);
	$ampel_hlist->itemConfigure($i, 5, -style => $ampel_red_itemstyle)
	  if ($ampel_red_itemstyle);
	$ampel_hlist->itemConfigure($i, 6, -style => $ampel_blue_itemstyle)
	  if ($ampel_blue_itemstyle);
	$ampel_hlist->see($i);
    };

    my $add_hlist_entry2 = sub {
	my($e, $i) = @_;
	if ((!defined $e->{Cycle} or $e->{Cycle} eq '') and
	    (defined $e->{Red} and $e->{Red} ne '') and
	    (defined $e->{Green} and $e->{Green} ne '')
	   ) {
	    # Zyklus berechnen, falls möglich
	    $e->{Cycle} = $e->{Red}+$e->{Green};
	}
	if ((defined $e->{Red} and $e->{Red} ne '') and
	    (defined $e->{Green} and $e->{Green} ne '')
	   ) {
	    # verlorene Zeit
	    my %res = Ampelschaltung::lost(-rot   => $e->{Red},
					   -gruen => $e->{Green},
					  );
	    $e->{Lost} = sprintf "%.1f", $res{-zeit};
	}
	$ampel2_hlist->add($i, -text => $e->{Day}, -data => $i);
	my $j = 1;
	foreach (qw(Time DirFrom DirTo Green Red Cycle Comment Date Lost)) {
	    $ampel2_hlist->itemCreate($i, $j, -text => $e->{$_});
	    $j++;
	}
	$ampel2_hlist->itemConfigure($i, 4, -style => $ampel_green_itemstyle)
	  if ($ampel_green_itemstyle);
	$ampel2_hlist->itemConfigure($i, 5, -style => $ampel_red_itemstyle)
	  if ($ampel_red_itemstyle);
	$ampel2_hlist->itemConfigure($i, 6, -style => $ampel_blue_itemstyle)
	  if ($ampel_blue_itemstyle);
	$ampel2_hlist->see($i);
    };

    $ampel_hlist->delete('all');
    my $last = $#{$ampel_data[$index]};
    for(my $i=2; $i<=$last; $i++) {
	$add_hlist_entry->($i);
    }

    {
	my $i = 0;
	$ampel2_hlist->delete('all');
	foreach my $e ($ampelschaltung2->find_by_point($p1)) {
	    if ($ampel_show_all ||
		(!((!defined $e->{Green} || $e->{Green} eq '') and
		   (!defined $e->{Red}   || $e->{Red} eq '')))
	       ) {
		$add_hlist_entry2->($e, $i);
	    }
	    $i++;
	}
    }

    for my $j (0 .. $hlist_cols-1) {
	$ampel_entry[$j]->delete(0, 'end');
    }
    for my $lastampeldate_i (0, 1, 8) { # wo-tag, zeit, datum
	next if ($lastampeldate_i == 1 && $rel_time_begin !~ /^\s*$/);
	$ampel_entry[$_]->insert(0, $lastampeldate[$_])
	    if defined $lastampeldate[$_];
    }
    $ampel_entry[0]->tabFocus;

    my @neighbors = keys %{$net->{Net}{$p1}};

    my $draw_arrow = sub {
	my $path = shift;
	if ($path ne '') {
	    $c->delete('lsas-dir');
	    my(@data) = split(/,/, $ampel_data[$index]->[$path]);
	    my $from = Strassen::Util::best_from_direction
	      ($p1, \@neighbors, $data[2]);
	    die unless $from;
	    my $to   = Strassen::Util::best_from_direction
	      ($p1, \@neighbors, $data[3]);
	    die unless $to;
	    my($fromx, $fromy) = split /,/, $from;
	    my($x1, $y1) = split /,/, $p1;
	    my($tox, $toy) = split /,/, $to;
	    my $len1 = _strecke($fromx, $fromy, $x1, $y1);
	    my $len2 = _strecke($tox, $toy, $x1, $y1);
	    if ($len1 != 0 && $len2 != 0) {
		$c->createLine($x1+($fromx-$x1)/$len1*20+4,
			       $y1+($fromy-$y1)/$len1*20+4,
			       $x1+4, $y1+4,
			       $x1+($tox-$x1)/$len2*20+4,
			       $y1+($toy-$y1)/$len2*20+4,
			       -smooth => 1,
			       -arrow => 'last',
			       -tags => ['lsas', 'lsas-dir'],
			       -fill => 'blue',
			       -width => 3,
			      );
		eval { $c->raise('lsa-X', 'lsas-dir') }; # XXX
		warn $@ if $@;
	    }
	}
    };

    my $draw_arrow2 = sub {
	my $e = shift;
	if ($e) {
	    $c->delete('lsas-dir');
	    my $from = Strassen::Util::best_from_direction
	      ($p1, \@neighbors, $e->{DirFrom});
	    die unless $from;
	    my $to   = Strassen::Util::best_from_direction
	      ($p1, \@neighbors, $e->{DirTo});
	    die unless $to;
	    my($fromx, $fromy) = split /,/, $from;
	    my($x1, $y1) = split /,/, $p1;
	    my($tox, $toy) = split /,/, $to;
	    my $len1 = _strecke($fromx, $fromy, $x1, $y1);
	    my $len2 = _strecke($tox, $toy, $x1, $y1);
	    if ($len1 != 0 && $len2 != 0) {
		$c->createLine($x1+($fromx-$x1)/$len1*20+4,
			       $y1+($fromy-$y1)/$len1*20+4,
			       $x1+4, $y1+4,
			       $x1+($tox-$x1)/$len2*20+4,
			       $y1+($toy-$y1)/$len2*20+4,
			       -smooth => 1,
			       -arrow => 'last',
			       -tags => ['lsas', 'lsas-dir'],
			       -fill => 'blue',
			       -width => 3,
			      );
		eval { $c->raise('lsa-X', 'lsas-dir') }; # XXX
		warn $@ if $@;
	    }
	}
    };

    $ampel_add->configure
      (-command => sub {
	   my $e = '';
	   my $has_data;
	   for my $j (0 .. $hlist_cols-1) {
	       my $ee = $ampel_entry[$j]->get;
	       if ($ee ne '') {
		   $has_data++;
	       }
	       if ($j == 1 and $ee =~ /^\d+$/) {
		   $ee .= ":00"; # Minuten anhängen
	       }
	       $e .= ($e eq '' ? $ee : ",$ee");
	   }
	   return if !$has_data;
	   $last++;
	   push @{ $ampel_data[$index] }, $e;
	   $add_hlist_entry->($last);
	   $draw_arrow->($last);
	   ampel_save() if $autosave;
	   my(@data) = split(/,/, $ampel_data[$index]->[$last]);
	   @lastampeldate = @data;
       });

    $ampel_hlist->bind('<Delete>' => sub {
			   my $path = $ampel_hlist->info('anchor');
			   if ($path ne '') {
			       my $inx = $ampel_hlist->info('data', $path);
			       $ampel_hlist->delete('entry', $path);
			       splice @{$ampel_data[$index]}, $inx, 1;
			       ampel_save() if $autosave;
			   }
		       });

    $ampel_hlist->configure
      (-browsecmd => 
       sub {
	   my $path = $ampel_hlist->info('anchor');
	   my $inx = $ampel_hlist->info('data', $path);
	   $draw_arrow->($inx);
	   my(@data) = split(/,/, $ampel_data[$index]->[$inx]);
	   for my $j (0 .. $hlist_cols-1) {
	       $ampel_entry[$j]->delete(0, 'end');
	       $ampel_entry[$j]->insert(0, $data[$j]);
	   }
       });

    $ampel2_hlist->configure
      (-browsecmd => 
       sub {
	   my $path = $ampel2_hlist->info('anchor');
	   my $inx = $ampel2_hlist->info('data', $path);
	   my @e = $ampelschaltung2->find_by_point($p1);
	   $draw_arrow2->($e[$inx]);
       });
}

sub ampel_open {
    my $base = "ampelschaltung-orig";
    require Ampelschaltung;
    $ampelschaltung_obj = new Ampelschaltung;
    $ampelschaltung_obj->open($base, UpdateCycle => 1);

    require MyFile;
    $ampelschaltung_file = MyFile::openlist
      (*RW, map { "$_/$base" }
       @Strassen::datadirs);
    if ($ampelschaltung_file) {
	@ampel_data = ();
	%ampel_schaltung = ();
	while(<RW>) {
	    next if (/^\s*\#/);
	    chomp;
	    my(@l) = split(/\t/);
	    ampel_new_point(@l);
	}
	close RW;
	if (!-w $ampelschaltung_file) {
	    require Tk::Dialog;
	    $top->Dialog
	      (-title => 'Warnung',
	       -text => "Achtung: auf die Datei $ampelschaltung_file kann nicht geschrieben werden.",
	       -buttons => ['OK'])->Show;
	}
    }
}

sub ampel_save {
    if ($ampelschaltung_file) {
	BBBikeEdit::ask_for_co($main::top, $ampelschaltung_file);
	open(RW, ">$ampelschaltung_file") or main::status_message($!, "die");
	binmode RW; # XXX check on NT
	print RW _auto_rcs_header();
	print RW join("\n", map { join("\t", @$_) } @ampel_data), "\n";
	close RW;
    }
}

sub ampel_save_as {
    my $file = $top->getSaveFile;
    if ($file) {
	$ampelschaltung_file = $file;
	ampel_save();
    }
}

sub ampel_new_point {
    my($p1, $kreuzung, @schaltung) = @_;
    if (!$crossing{$p1}) {
	warn "*** No crossing for point $p1 [$kreuzung @schaltung] found ***";
	return;
    }
    $kreuzung = join("/", @{ $crossing{$p1} })
      if !defined $kreuzung || $kreuzung eq '';
    push @ampel_data, [$p1, $kreuzung, @schaltung];
    if (exists $ampel_schaltung{$p1}) {
	warn "Die Ampelschaltung für $p1 existiert bereits!";
    }
    $ampel_schaltung{$p1} = $#ampel_data;
    return $#ampel_data;
}

sub ampel_meta_draw_canvas {
    %ampel_all_cycle = ();
    ampel_draw_canvas();
    ampel_draw_canvas(-obj => 2);
    ampel_draw_canvas_cycle();
}

sub ampel_draw_canvas {
    my(%args) = @_;
    my $index = $args{'-index'};
    my $obj   = $args{-obj} || '1';
    my(@points, %points);
    my $file;
    if ($obj eq '2') { # XXX doesn't work yet
	return if !$ampelschaltung2;
	# kein delete. Der Aufruf mit -obj => 2 muss *nach* -obj => 1 folgen
	$file = $ampelschaltung2->{File};
	%points = $ampelschaltung2->create_points;
	@points = keys %points;
	$index = 0;
    } else {
	if (defined $index) {
	    $c->delete("lsas-$index");
	    @points = create Ampelschaltung::Point $ampel_data[$index];
	} else {
	    $c->delete("lsas");
	    $c->delete("lsas-t");
	    $index = 0;
	    @points = @{ $ampelschaltung_obj->{Data} };
	}
    }
    if (@points > 1) {
	IncBusy($top);
	require File::Basename;
	$progress->Init
	  (-dependents => $c,
	   -label => File::Basename::basename($ampelschaltung_file));
    }
    eval {
	my $i = 0;
	foreach my $l (@points) {
	    $progress->Update($i/($#points+1)) if $i++ % 80 == 0;
	    if ($obj eq '2') {
		my $point = $points{$l}->[0]->{Point};
		my($x1, $y1) = split /,/, $point;
		my $entries = $points{$l};
		my(@entries);
		if ($ampel_draw_restrict ne "") {
		    foreach my $e (@$entries) {
			if (Ampelschaltung::verkehrszeit
			    ($e->{Day}, $e->{Time}) eq $ampel_draw_restrict) {
			    push @entries, $e;
			}
		    }
		} else {
		    @entries = @$entries;
		}
		foreach my $e (@entries) {
		    next if !defined $e->{Cycle} or $e->{Cycle} eq '';
		    (my $nr = $e->{Cycle}) =~ s/\D//g;
		    $ampel_all_cycle{$point}->{$nr}++ if $nr;
		}
		$c->createLine($scale*($x1+4), $scale*($y1+5),
			       $scale*($x1+4), $scale*($y1+5),
			       -width => 3,
			       -fill => 'blue',
			       -tags => 'lsas');
		$index++;
	    } else {
		my $point = $l->{Point};
		my($x1, $y1) = split /,/, $point;
		my(@entries);
		if ($ampel_draw_restrict ne "") {
		    foreach my $e ($l->entries) {
			if (Ampelschaltung::verkehrszeit
			    ($e->{Day}, $e->{Time}) eq $ampel_draw_restrict) {
			    push @entries, $e;
			}
		    }
		} else {
		    @entries = $l->entries;
		}
		my $entries = scalar @entries;
		my $width = ($entries < 3 ? 4 : 
			     ($entries > 6 ? 8 : $entries+2));
		foreach my $e (@entries) {
		    next if !defined $e->{Cycle} or $e->{Cycle} eq '';
		    (my $nr = $e->{Cycle}) =~ s/\D//g;
		    $ampel_all_cycle{$point}->{$nr}++ if $nr;
		}
		$c->createLine($scale*($x1+4), $scale*($y1+5),
			       $scale*($x1+4), $scale*($y1+5),
			       -width => $width,
			       -fill => 'red',
			       -tags => ['lsas', "lsas-$index"]);
		$index++;
	    }
	}
	$c->itemconfigure('lsas',
			  -capstyle => 'round',
			  );
	restack();
    };
    warn $@ if $@;
    if (@points > 1) {
	$progress->Finish;
	DecBusy($top);
    }
}

sub ampel_draw_canvas_cycle {
    while(my($k, $v) = each %ampel_all_cycle) {
	my($x,$y) = transpose(split /,/, $k);
	my $zyklus = join(",", sort { $a <=> $b } keys %$v);
	if ($zyklus ne "") {
	    #$c->createText($x,$y, -text => $zyklus, -tags => ["lsas-t"]);
	    draw_text_intelligent($c, $x, $y, -text => $zyklus, -font => $font{'tiny'}, -tags => ["lsas-t"]);
	}
    }
#     $c->itemconfigure('lsas-t',
# 		      -font => $font{'tiny'},
# 		      -anchor => 'nw',
# 		     );
}

#XXX portabler, aber leider gibt es ab und zu X11-Fehler (X_TranslateCoords)
sub ampeln_on_route_canvas {
    my(@realcoords) = @_;

    die "Funktioniert nur mit Tk Version > 800.000" if $Tk::VERSION < 800;

    my $s = new Strassen $str_file{'s'};# XXX gecachte Version verwenden
    my %crossing = %{ $s->all_crossings(RetType => 'hash',
					UseCache => 1,
					Kurvenpunkte => 1,
				       ) };
    my $t = $top->Toplevel;
    my $multi = 4;
    my $pc = $t->Canvas(-width => 95*$multi, -height => 250*$multi)->pack;
    my $drittel = $pc->cget(-width)/3;
    my $extra_width = 8*$multi;
    $pc->createLine($drittel-$extra_width, 0,
		    $drittel-$extra_width, $pc->cget(-height));
    $pc->createLine($drittel, 0,
		    $drittel, $pc->cget(-height));
    $pc->createLine(2*$drittel, 0,
		    2*$drittel, $pc->cget(-height));
    my $y = 0;
    my $font = $pc->fontCreate(-size => 8, -family => 'helvetica');#XXX
    my $bold_font = $pc->fontCreate($pc->fontActual($font));
    $pc->fontConfigure($bold_font, -weight => 'bold');
    my $asc = $pc->fontMetrics($font, -ascent);
    my $des = $pc->fontMetrics($font, -descent);
    my $y_height = $asc + $des + 2;

    # Header
    $pc->createText(3, $y, -anchor => 'nw',
		    -text => 'Ampel',
		    -font => $bold_font);
    $pc->createText($drittel+3, $y, -anchor => 'nw',
		    -text => 'grün',
		    -font => $bold_font);
    $pc->createText(2*$drittel+3, $y, -anchor => 'nw',
		    -text => 'rot',
		    -font => $bold_font);
    $y+=$y_height;
    $pc->createLine(0, $y, $pc->cget(-width), $y);

    # XXX der postscript-Code arbeitet nicht korrekt
    my $y_add_bug = 4;

    my $ampel_s_reihe = sub {
	my $drittel = $pc->cget(-width)/3;
	my $x = $drittel+1;
	my $xadd = 1;
	for(my $s = 10; ; $s+=5) {
	    if ($x + $pc->fontMeasure($font, $s) < $drittel*2-1) {
		$pc->createText($x, $y+$y_add_bug, -anchor => 'nw',
				-text => $s,
				-font => $font);
	    } else {
		last;
	    }
	    $x += $pc->fontMeasure($font, $s) + $xadd;
	}
	$x = $drittel*2+1;
	for(my $s = 30; ; $s+=5) {
	    if ($x + $pc->fontMeasure($font, $s) < $drittel*3-1) {
		$pc->createText($x, $y+$y_add_bug, -anchor => 'nw',
				-text => $s,
				-font => $font);
	    } else {
		last;
	    }
	    $x += $pc->fontMeasure($font, $s) + $xadd;
	}
    };

    my $last;
    foreach (@realcoords) {
	my $p = "$_->[0],$_->[1]";
	if (exists $ampeln{$p}) {
	    if (defined $last and $p eq $last) {
		next;
	    } else {
		$last = $p;
	    }
	    if (exists $crossing{$p}) {
		my(@c) = @{$crossing{$p}};
		if (@c > 4) { # höchstens vier Straßen pro Kreuzung
		    splice @c, 4;
		}
		foreach (@c) {
		    s/\s*\(.*\)$//; # Klammerzusatz löschen
		}
		# Solange Straßennamen verkürzen, bis der gesamte String
		# in die Zelle passt. Dabei wird versucht, balanciert zu
		# kürzen.
		while(1) {
		    my $c = join("/", @c);
		    last if length($c) < 10; # Endlosschleife vermeiden
		    if ($t->fontMeasure($font, $c) > $drittel-$extra_width) {
			my $max_length = 0;
			foreach (@c) {
			    $max_length = length($_)
			      if (length($_) > $max_length);
			}
			foreach (@c) {
			    chop if (length($_) >= $max_length);
			}
		    } else {
			last;
		    }
		}
		my $c = join("/", @c);
		$pc->createText(1, $y+$y_add_bug, -anchor => 'nw',
				-text => $c,
				-font => $font);
		if ($ampeln{$_->[0].",".$_->[1]} eq '?') {
		    $pc->createText(1+$drittel-$extra_width, $y+$y_add_bug,
				    -anchor => 'nw',
				    -text => '?',
				    -font => $font);
		}
		&$ampel_s_reihe;
		$y+=$y_height;
		$pc->createLine(0, $y, $pc->cget(-width), $y);
	    }
	}
    }
    while ($y < $pc->cget(-height)) {
	&$ampel_s_reihe;
	$y+=$y_height;
	$pc->createLine(0, $y, $pc->cget(-width), $y);
    }
    my $tmpfile = "$tmpdir/$progname" . "_$$.ps";
    $tmpfiles{$tmpfile}++;
    $pc->update;
    $pc->postscript(-pagewidth => '9.5c',
		    -pagex => "0.5c",
		    -pagey => "0.5c",
		    -pageanchor => 'sw',
		    -file => $tmpfile);
    require BBBikePrint;
    print_postscript($tmpfile);
    $t->destroy;
}

sub ampeln_on_route_enscript {
    my(@realcoords) = @_;

    do { status_message("Drucken nicht möglich. Grund: das Programm `Enscript' ist nicht vorhanden.","err"); return } if !is_in_path("enscript");

    my $s = (defined $str_obj{'s'}
	     ? $str_obj{'s'}
	     : new Strassen $str_file{'s'});
    my %crossing = %{ $s->all_crossings(RetType => 'hash',
					UseCache => 1,
					Kurvenpunkte => 1,
				       ) };

    my $size = "8";
    my $normal_font = "Courier$size";
    open(E, "| enscript -B -s 6 -e -f $normal_font -o $tmpdir/ampeln_on_route.ps");

    my $y_add = 14;
    my $x_begin = 5;
    my $x_end   = 269;
    my $y_begin = 787;
    my $y_end   = 4;
    my $y_second_line = $y_begin-14;
    my $y = $y_second_line;

    # senkrechte Linien und waagerechte Linien
    {
	my $x_begin = $x_begin-1;
	print E "\000ps{
$x_begin $y_begin moveto $x_end $y_begin lineto stroke
$x_begin $y_end moveto $x_end $y_end lineto stroke
$x_begin $y_begin moveto $x_begin $y_end lineto stroke
127 $y_begin moveto 127 $y_end lineto stroke
155 $y_begin moveto 155 $y_end lineto stroke
212 $y_begin moveto 212 $y_end lineto stroke
gsave [1 3] 45 setdash
184 $y_second_line moveto 184 $y_end lineto stroke
240 $y_second_line moveto 240 $y_end lineto stroke
grestore
$x_end $y_begin moveto $x_end $y_end lineto stroke
}";
    }

    my $last;

    print E "\000font{CourierBold$size}";
    printf E 
      "%-21s %-3s %-6s %-13s %-13s", "Ampel", "Dir", "Zykl", "grün", "rot";
    print E "\000ps{$x_begin $y moveto $x_end $y lineto stroke}\n";
    $y -= $y_add;
    print E "\000font{$normal_font}";

    foreach (@realcoords) {
	my $p = "$_->[0],$_->[1]";
	if (exists $ampeln{$p}) {
	    if (defined $last and $p eq $last) {
		next;
	    } else {
		$last = $p;
	    }
	    if (exists $crossing{$p}) {
		my(@c) = @{$crossing{$p}};
		if (@c > 4) { # höchstens vier Straßen pro Kreuzung
		    splice @c, 4;
		}
		foreach (@c) {
		    s/\s*\(.*\)$//; # Klammerzusatz löschen
		}
		# Solange Straßennamen verkürzen, bis der gesamte String
		# in die Zelle passt. Dabei wird versucht, balanciert zu
		# kürzen.
		while(1) {
		    my $c = join("/", @c);
		    last if length($c) <= 25;
		    my $max_length = 0;
		    foreach (@c) {
			$max_length = length($_)
			  if (length($_) > $max_length);
		    }
		    foreach (@c) {
			chop if (length($_) >= $max_length);
		    }
		}
		my $c = join("/", @c);
		printf E
		  "%-25s %-4s", $c, 
		  ($ampeln{$_->[0].",".$_->[1]} eq '?' ? '?' : '')
		  ;
		print E "\000ps{$x_begin $y moveto $x_end $y lineto stroke}\n";
		$y -= $y_add;
	    }
	}
    }
    while ($y > 0) {
 	printf E "%-25s %-4s", "", "";
	print E "\000ps{$x_begin $y moveto $x_end $y lineto stroke}\n";
	$y -= $y_add;
    }
    close E;

    require BBBikePrint;
    print_postscript("$tmpdir/ampeln_on_route.ps");
}

# Alte Version für Ampelschaltung1 (mit vorgegebenen Rot/Grünphasen-Dauern)
sub old_ampeln_on_route_enscript {
    my(@realcoords) = @_;

    do { status_message("Drucken nicht möglich. Grund: das Programm `Enscript' ist nicht vorhanden.","err"); return } if !is_in_path("enscript");

    my $s = (defined $str_obj{'s'}
	     ? $str_obj{'s'}
	     : new Strassen $str_file{'s'});
    my %crossing = %{ $s->all_crossings(RetType => 'hash',
					UseCache => 1,
					Kurvenpunkte => 1,
				       ) };

    my $normal_font = "Courier5";
    open(E, "| enscript -B -s 2 -e -f $normal_font -o $tmpdir/ampeln_on_route.ps");

    my $y = 783;
    my $y_add = 7;
    my $x_begin = 5;
    my $x_end   = 269;
    my $y_begin = 791;
    my $y_end   = 4;

    # senkrechte Linien und waagerechte Linien
    {
	my $x_begin = $x_begin-1;
	print E "\000ps{
$x_begin $y_begin moveto $x_end $y_begin lineto stroke
$x_begin $y_end moveto $x_end $y_end lineto stroke
$x_begin $y_begin moveto $x_begin $y_end lineto stroke
81 $y_begin moveto 81 $y_end lineto stroke
96 $y_begin moveto 96 $y_end lineto stroke
177 $y_begin moveto 177 $y_end lineto stroke
$x_end $y_begin moveto $x_end $y_end lineto stroke
}";
    }

    my $last;
    my $reihe = '';
    for(my $s = 10; $s <= 50; $s+=5) {
	$reihe .= sprintf "%2d ", $s;
    }
    for(my $s = 30; $s <= 75; $s+=5) {
	$reihe .= sprintf "%2d ", $s;
    }

    print E "\000font{CourierBold5}";
    printf E 
      "%-25s %-4s %-26s %s", "Ampel", "", "grün", "rot";
    print E "\000ps{$x_begin $y moveto $x_end $y lineto stroke}\n";
    $y -= $y_add;
    print E "\000font{$normal_font}";

    foreach (@realcoords) {
	my $p = "$_->[0],$_->[1]";
	if (exists $ampeln{$p}) {
	    if (defined $last and $p eq $last) {
		next;
	    } else {
		$last = $p;
	    }
	    if (exists $crossing{$p}) {
		my(@c) = @{$crossing{$p}};
		if (@c > 4) { # höchstens vier Straßen pro Kreuzung
		    splice @c, 4;
		}
		foreach (@c) {
		    s/\s*\(.*\)$//; # Klammerzusatz löschen
		}
		# Solange Straßennamen verkürzen, bis der gesamte String
		# in die Zelle passt. Dabei wird versucht, balanciert zu
		# kürzen.
		while(1) {
		    my $c = join("/", @c);
		    last if length($c) <= 25;
		    my $max_length = 0;
		    foreach (@c) {
			$max_length = length($_)
			  if (length($_) > $max_length);
		    }
		    foreach (@c) {
			chop if (length($_) >= $max_length);
		    }
		}
		my $c = join("/", @c);
		printf E
		  "%-25s %-4s %s", $c, 
		  ($ampeln{$_->[0].",".$_->[1]} eq '?' ? '?' : ''),
		  $reihe;
		print E "\000ps{$x_begin $y moveto $x_end $y lineto stroke}\n";
		$y -= $y_add;
	    }
	}
    }
    while ($y > 0) {
 	printf E "%-25s %-4s %s", "", "", $reihe;
	print E "\000ps{$x_begin $y moveto $x_end $y lineto stroke}\n";
	$y -= $y_add;
    }
    close E;

    require BBBikePrint;
    print_postscript("$tmpdir/ampeln_on_route.ps");
}

if (defined $os && $os eq 'win') {
    *BBBikeEdit::ampeln_on_route = \&ampeln_on_route_canvas;
} else {
    *BBBikeEdit::ampeln_on_route = \&ampeln_on_route_enscript;
}

######################################################################
# Labels
#
sub label_edit_toggle {
    if ($special_edit eq 'label') {
	label_edit_modus();
    } else {
	label_edit_off();
    }
}

sub label_edit_modus {
    $special_edit = 'label';
#XXX utilize $edit_normal_mode?
    switch_edit_berlin_mode() if (!defined $edit_mode or $edit_mode ne 'b');
    unless ($str_draw{'s'}) {
	plot('str','s', -draw => 1);
    }
    label_undef_all();
    plot('p',"lb", -draw => 1);

    $p_obj{'lb'}->init;
    my $i = 0;
    while(1) {
	my $ret = $p_obj{'lb'}->next;
	last if !@{$ret->[1]};
	$label_index{$ret->[1][0]} = $i;
	$i++;
    }

    if (keys %crossing == 0) {
	my $s = new Strassen $str_file{'s'} . "-orig";
	%crossing = %{ $s->all_crossings(RetType => 'hash',
					 UseCache => 1,
					 Kurvenpunkte => 1) };
    }
    set_mouse_desc();
}

sub label_undef_all {
    undef %crossing;
    undef %label_index;
}

sub label_edit_off {
    $special_edit = '';
    set_mouse_desc();
    plot('p',"lb", -draw => 0);
}

sub label_edit_mouse1 {
    my(@tags) = $c->gettags('current');
    return unless grep($_ =~ /^pp$/, @tags);
    $label_coord = $tags[1];
    $label_i = (exists $label_index{$label_coord} 
		? $label_index{$label_coord}
		: undef);
    if (defined $label_i) {
	my $ret = $p_obj{'lb'}->get($label_i);
	$label_text = $ret->[0];
	if ($ret->[2] =~ /^(90)?(.*)/) {
	    $label_anchor = $2;
	    $label_rotated = $1;
	}
    } else {
	$label_text = "";
	$label_anchor = 's';
	$label_rotated = '';
    }
    my $t = redisplay_top($top, "labels", -title => 'Labels');
    if (defined $t) {
	$label_entry = $t->Entry(-textvariable => \$label_text)->pack;
	my $rf = $t->Frame->pack;
	foreach my $anchor (qw(n nw w sw s se e ne c)) {
	    $rf->Radiobutton(-text => $anchor,
			     -variable => \$label_anchor,
			     -value => $anchor)->pack(-side => 'left');
	}
	$t->Checkbutton(-text => 'Senkrecht',
			-variable => \$label_rotated,
			-onvalue => '90',
			-offvalue => '')->pack;
	$t->Button(-text => 'OK',
		   -command => sub { &label_set_i;
				     $t->withdraw; },
		  )->pack;
    }
    $label_entry->focus;
}

sub label_set_i {
    if (!defined $label_i) {
	$label_i = $p_obj{'lb'}->count;
    }
    $p_obj{'lb'}->set($label_i, [$label_text, $label_coord,
				 "$label_rotated$label_anchor"]);
    $label_index{$label_coord} = $label_i;
    $p_obj{'lb'}->write;
    plot('p','lb');
}

sub label_save_as {
    main::status_message("Using edit mode is deprecated!", "die");
    return unless $p_obj{'lb'};
    my $file = $top->getSaveFile;
    if ($file) {
	$p_obj{'lb'}->write($file);
    }
}

######################################################################
#
# Vorfahrt
#

sub vorfahrt_edit_toggle {
    if ($special_edit eq 'vorfahrt') {
	vorfahrt_edit_modus();
    } else {
	vorfahrt_edit_off();
    }
}

use vars qw($p_obj_vf);
sub vorfahrt_edit_modus {
    $special_edit = 'vorfahrt';
#XXX utilize $edit_normal_mode?
#XXX    switch_edit_berlin_mode() if (!defined $edit_mode or $edit_mode ne 'b');
    unless ($str_draw{'s'}) {
	plot('str','s', -draw => 1);
    }
    vorfahrt_undef_all();
    plot('p',"vf", -draw => 1);

    $p_obj_vf = new Strassen $p_file{'vf'} . "-orig" unless $p_obj_vf;
    $p_obj_vf->init;
    my $i = 0;
    while(1) {
	my $ret = $p_obj_vf->next;
	last if !@{$ret->[1]};
	$vorfahrt_index{$ret->[1][0]} = $i;
	$i++;
    }

    if (keys %crossing == 0) {
	my $s = new Strassen $str_file{'s'} . "-orig";
	%crossing = %{ $s->all_crossings(RetType => 'hash',
					 UseCache => 1,
					 Kurvenpunkte => 1) };
    }

    set_mouse_desc();
}

sub vorfahrt_undef_all {
    undef %crossing;
}

sub vorfahrt_edit_off {
    $special_edit = '';
    set_mouse_desc();
    plot('p',"vf", -draw => 0);
}

# XXXX
# XXX 3 Punkte aufzeichnen und dann fragen, ob Vorfahrtsregelung
# gespeichert werden soll
# oder: Punkt anklicken, Grafiken für alle möglichen Vorfahrtsregelungen
# als Button ausgeben. Nach Anklicken autosave.
# Delete sollte auch möglich sein. Falls bereits Vorfahrtsregelung
# vorhanden, sollte diese gehighlited werden. (Vielleicht dann lieber
# Checkbuttons als Buttons).
sub vorfahrt_edit_mouse1 {
    my(@tags) = $c->gettags('current');
    return unless grep($_ =~ /^(pp|vf.*|lsa.*)$/, @tags);

=begin comment

    $vorfahrt_coord = $tags[1];
    $vorfahrt_i = (exists $vorfahrt_index{$vorfahrt_coord} 
		? $vorfahrt_index{$vorfahrt_coord}
		: undef);
    if (defined $vorfahrt_i) {
	my $ret = $p_obj_vf->get($vorfahrt_i);
	$vorfahrt_text = $ret->[0];
	if ($ret->[2] =~ /^(90)?(.*)/) {
	    $vorfahrt_anchor = $2;
	    $vorfahrt_rotated = $1;
	}
    } else {
	$vorfahrt_text = "";
	$vorfahrt_anchor = 's';
	$vorfahrt_rotated = '';
    }
    my $t = redisplay_top($top, "vorfahrts", -title => 'Vorfahrts');
    if (defined $t) {
	$vorfahrt_entry = $t->Entry(-textvariable => \$vorfahrt_text)->pack;
	my $rf = $t->Frame->pack;
	foreach my $anchor (qw(n nw w sw s se e ne c)) {
	    $rf->Radiobutton(-text => $anchor,
			     -variable => \$vorfahrt_anchor,
			     -value => $anchor)->pack(-side => 'left');
	}
	$t->Checkbutton(-text => 'Senkrecht',
			-variable => \$vorfahrt_rotated,
			-onvalue => '90',
			-offvalue => '')->pack;
	$t->Button(-text => 'OK',
		   -command => sub { &vorfahrt_set_i;
				     $t->withdraw; },
		  )->pack;
    }
    $vorfahrt_entry->focus;

=end comment

=cut

}

=begin comment

# XXXX
sub vorfahrt_set_i {
    if (!defined $vorfahrt_i) {
	$vorfahrt_i = $p_obj_vf->count;
    }
    $p_obj_vf->set($vorfahrt_i, [$vorfahrt_text, $vorfahrt_coord,
				 "$vorfahrt_rotated$vorfahrt_anchor"]);
    $vorfahrt_index{$vorfahrt_coord} = $vorfahrt_i;
    $p_obj_vf->write;
    plot('p','vf');
}

=end comment

=cut

sub vorfahrt_save {
    main::status_message("Using edit mode is deprecated!", "die");
    return unless $p_obj_vf;
    $p_obj_vf->write;
}

sub vorfahrt_save_as {
    main::status_message("Using edit mode is deprecated!", "die");
    return unless $p_obj_vf;
    my $file = $top->getSaveFile;
    if ($file) {
	$p_obj_vf->write($file);
    }
}

sub _strecke {
    my($x1,$y1,$x2,$y2) = @_;
    my $dx = $x2-$x1;
    my $dy = $y2-$y1;
    sqrt($dx*$dx+$dy*$dy);
}

sub _auto_rcs_header {
    "# DO NOT EDIT!\n" .
    "# ". "\$" . "Id: " . "\$\n";
}

# here starts the real future clean cool package
package BBBikeEdit;
use Fcntl; # für DB_File;
use Class::Struct;
use Strassen;
use BBBikeEditUtil;
use BBBikeGPS;
use File::Basename;

BEGIN {
    if (!eval '
use Msg qw(frommain);
1;
') {
	warn $@ if $@;
	eval 'sub M ($) { $_[0] }';
	eval 'sub Mfmt { sprintf(shift, @_) }';
    }
}

undef &BBBikeEdit::new;
struct('top'      => "\$",
       'toplevel' => "\$", # toplevel from redisplay_top
       'datadir'  => "\$",
       'canvas'   => "\$",
       'str_file' => "\$",
       'p_file'   => "\$",
       'coord_system' => "\$",
       'file2base' => "\$",
      );

undef &LinePartInfo::new;
struct(LinePartInfo => [ 'basefile' => "\$",
			 'line'     => "\$",
			 'filetype' => "\$",
		       ]);

use constant BBBIKEEDIT_TOPLEVEL => "bbbikeedit";

use vars qw($sel_file $tmpdir);
if (!defined $tmpdir) {
    $tmpdir = $main::tmpdir || "/tmp";
}

use vars qw($auto_reload);
$auto_reload = 1 if !defined $auto_reload;

use vars qw($crosshairs_activated);

# Return true if the file is writable (eventually after checking out).
sub ask_for_co {
    my($top, $file) = @_;
    if (!-e $file) {
	if (!open(TOUCH, "> $file")) {
	    main::status_message("Die Datei $file kann nicht angelegt werden: $!", "warn");
	} else {
	    close TOUCH;
	}
    }
    if (!-e $file) {
	$top->messageBox(-title => "Warnung",
			 -message => "Achtung: die Datei $file kann nicht erzeugt werden. Bitte Berechtigungen überprüfen",
			);
	return 0;
    }
    if (!-w $file) {
	if (!(-e dirname($file)."/RCS/".basename($file.",v") ||
	      -e $file.",v")) {
	    $top->messageBox(-title => "Warnung",
			     -message => "Die Datei $file kann nicht geschrieben werden. Bitte Berechtigungen überprüfen",
			    );
	    return 0;
	}
	require Tk::Dialog;
	my $ans = $top->Dialog
	    (-title => 'Warnung',
	     -text => "Achtung: auf die Datei $file kann nicht geschrieben werden.\nSoll ein \"co -l\" ausgeführt werden?",
	     -buttons => ['Ja', 'Nein'])->Show;
	if ($ans eq 'Ja') {
	    require BBBikeUtil;
	    my $ok = BBBikeUtil::rcs_co($file);
	    if (!$ok) {
		$top->Dialog
		    (-title => 'Warnung',
		     -text =>
		     "\"co -l $file\" hat einen Fehler gemeldet. " .
		     "Bitte stderr überprüfen.",
		     -buttons => ['OK'])->Show;
		return 0;
	    }
	} else {
	    return 0;
	}
    }
    1;
}

sub create {
    my($pkg) = @_;
    my $o = $pkg->new();
    $o->top($main::top);
    $o->toplevel(\%main::toplevel);
    $o->datadir($main::datadir);
    $o->canvas($main::c);
    $o->str_file(\%main::str_file);
    $o->p_file(\%main::p_file);
    $o->coord_system($main::coord_system_obj);
    eval {
	BBBikeEditUtil::base();
	$o->file2base(\%BBBikeEditUtil::file2base);
    };
    if ($@) {
	# BASE is not really used these days, so just warn... 
	warn $@;
    }
    $o;
}

# Return information about clicked line as a LinePartInfo struct
sub click_info {
    my $o = shift;
    my(@tags) = $o->canvas->gettags("current");
    if (@tags) {
	my $abk = $tags[0];
	my $pos = $tags[3];
	# XXX p_file is not supported (yet)
	my $str_filename;
	my $filetype = "str";
	if ($abk =~ /^[wi]$/) { # exception because of
                                # _get_wasser_obj, include also _i_slands
	    if ($main::wasserstadt) {
		$str_filename = $o->str_file->{"w"};
	    }
	    if ($main::wasserumland) {
		if ($str_filename) {
		    main::status_message("Ambigous. Please select only *one* Gewässer region", "die");
		}
		$str_filename = "wasserumland";
	    }
	    if ($main::str_far_away{"w"}) {
		if ($str_filename) {
		    main::status_message("Ambigous. Please select only *one* Gewässer region", "die");
		}
		$str_filename = "wasserumland2";
	    }
	} elsif ($abk eq 'l' && 0) { # exception because of _get_landstr_obj
	    # XXX NYI
	} elsif (exists $o->str_file->{$abk}) {
	    $str_filename = $o->str_file->{$abk};
	} elsif ($abk =~ /^v-SW/ && exists $o->str_file->{"v"}) {
	    $str_filename = $o->str_file->{$abk};
	} elsif ($abk =~ m{^temp_sperre(?:_s)?$}) {
	    my $info = main::get_temp_blockings_files();
	    $str_filename = $info->{file};
	    $filetype = "temp_blockings";
	}
	if ($str_filename) {
	    my $ret = LinePartInfo->new;
	    $ret->basefile($str_filename);
	    $pos =~ s/^.*-//;
	    $ret->line($pos);
	    $ret->filetype($filetype);
	    return $ret;
	}

	if (exists $o->p_file->{$abk} && defined $pos) {
#XXX _get_orte_obj exception not handled
	    my $ret = LinePartInfo->new;
	    $ret->basefile($o->p_file->{$abk});
	    $pos =~ s/^.*-//;
	    $ret->line($pos);
	    $ret->filetype("p");
	    return $ret;
	}
	warn "Tags not recognized: @tags\n";
    }
    undef;
}

# this is a per file-hash:
use vars qw(%click_readonly_warning_seen);

sub click {
    my $o = shift;
    my $click_info = $o->click_info;
    die "No (str or p) line recognised" if !$click_info;

    if ($click_info->filetype eq "temp_blockings") {
	open TEMP_BLOCKINGS, $click_info->basefile
	    or main::status_message("Can't open " . $click_info->basefile . ": $!", "die");
	my $line = $main::temp_blocking_inx_mapping{ $click_info->line };
	my $record = 0;
	my $linenumber = 1;
	while(<TEMP_BLOCKINGS>) {
	    if (m<^\s*\{>) {
		if ($record == $line) {
		    start_editor($click_info->basefile, $linenumber);
		    return;
		}
		$record++;
	    }
	    $linenumber++;
	}
	main::status_message("Can't find record number " . $click_info->line . " in " . $click_info->basefile, "die");
    }

    my $ev = $o->canvas->XEvent;
    my($cx,$cy) = ($o->canvas->canvasx($ev->x),
		   $o->canvas->canvasy($ev->y));
    my($tx,$ty) = map { int } main::anti_transpose($cx,$cy);

    # Get file name
    my $file;
    if ($click_info->basefile =~ m|^/|) { # XXX better use file_name_is_absolute
	$file = $click_info->basefile . "-orig";
    } else {
	$file = $o->datadir . "/" . $click_info->basefile . "-orig";
    }
    if (!$main::edit_mode_flag || !-e $file) {
	warn "Fallback to non-orig file";
	$file =~ s{-orig$}{};
    }
    if (!-r $file) {
	main::status_message("Can't read file $file", "die");
    }

    # Read-only vs. read-write
    my $readonly = 0;
    my @entry_args = ();
    my @button_args = ();
    if (!$main::edit_mode_flag) {
	$readonly = 1;
    } elsif (!-w $file) {
	if (!$click_readonly_warning_seen{$file}) {
	    main::status_message(Mfmt("Kann die Datei %s nicht öffnen. Wenn notwendig, ein RCS-Checkout durchführen. Dialog wird nun im Nur-Lese-Modus geöffnet.", $file), "warn");
	    $click_readonly_warning_seen{$file}++;
	}
	$readonly = 1;
    }
    if ($readonly) {
	if ($Tk::VERSION >= 804) {
	    @entry_args = (-state => "readonly");
	} else {
	    @entry_args = (-state => "disabled");
	}
	@button_args = (-state => "disabled");
    }

    my @rec;
    if (eval { require DB_File; 1 }) {
	if (!tie @rec, 'DB_File', $file, ($readonly ? O_RDONLY : O_RDWR), 0644, $DB_File::DB_RECNO) {
	    main::status_message(Mfmt("Die Datei %s kann mit DB_File nicht geöffnet werden: %s", $file, $!), "die");
	}
    } elsif (eval { require Tie::File; 1 }) {
	# note that record separator is probably always Unix-styled
	if (!tie @rec, "Tie::File", $file, mode => ($readonly ? O_RDONLY : O_RDWR), recsep => "\n") {
	    main::status_message(Mfmt("Die Datei %s kann mit Tie::File nicht geöffnet werden: %s", $file, $!), "die");
	}
    } else {
	# XXX vielleicht sollte es einen fallback mit open und read geben
	main::status_message("Kann die Funktion nicht durchführen: entweder Tie::File oder DB_File fehlt", "die");
    }

    require Tk::Ruler;
    require Tk::LabEntry;

    my $top = $o->top;
    my $t = $top->Toplevel(-title => M("BBBike-Editor") . ": " . $click_info->basefile);

    if (tied @rec) {
	$t->OnDestroy(sub { untie @rec });
    }

    $t->transient($top) unless defined $main::transient && !$main::transient;
    my($name, $cat, $coords);

    my $e1 = $t->LabEntry(-label => M("Name"),
			  -labelPack => [-side => "left"],
			  -textvariable => \$name,
			  @entry_args,
			 )->pack(-fill=>"x");
    $e1->focus;
    $t->LabEntry(-label => M("Kategorie"),
		 -labelPack => [-side => "left"],
		 -textvariable => \$cat,
		 @entry_args,
		)->pack(-fill=>"x");
    {
	my $f = $t->Frame->pack(-fill=>"x");
	$f->LabEntry(-label => M("Koordinaten"),
		     -labelPack => [-side => "left"],
		     -textvariable => \$coords,
		     @entry_args,
		    )->pack(-side => "left", -fill=>"x");
	$f->Button(-text => M"Umdrehen",
		   -command => sub {
		       my(@coords) = split /\s+/, $coords;
		       @coords = reverse @coords;
		       $coords = join(" ", @coords);
		   },
		   @button_args,
		  )->pack(-side => "left");
	$f->Button(-text => $main::texteditor || "Editor",
		   -command => sub {
		       # XXX don't duplicate code, see below
		       # XXX ufff... this is also in  BBBikeAdvanced::find_canvas_item_file for the F9 key :-(
		       my $count = 0;
		       my $rec_count = 0;
		       foreach (@rec) {
			   if (!/^\#/) {
			       if ($count == $click_info->line) {
				   start_editor($file, $rec_count+1);
				   return;
			       }
			       $count++;
			   }
			   $rec_count++;
		       }
		       main::status_message("Cannot find line " . $click_info->line, "die");
		   })->pack(-side => "left");
    }

    {
	$t->Ruler->rulerPack(-pady => 2, -padx => 2);
	my $f = $t->Frame->pack(-anchor => "w", -fill => "x");
	$f->Button(-text => M("Kommentar senden"),
		   -command => sub {
		       send_comment(-w => $t,
				    -file => $file,
				    -name => $name,
				    -cat => $cat,
				    -coords => $coords,
				    -clickcoords => [$tx,$ty],
				   );
		   })->pack(-anchor => "w");
    }

    my $okb;
    {
	$t->Ruler->rulerPack(-pady => 2, -padx => 2);
	my $f = $t->Frame->pack;
	if (!$readonly) {
	    $okb = $f->Button(Name => 'ok')->pack(-side => "left");
	}
	$f->Button(Name => 'cancel',
		   -command => sub {
		       $t->destroy;
		   })->pack(-side => "left");
    }

    my $count = 0;
    my $rec_count = 0;
use Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->Dumpxs([$click_info],[]); # XXX

 TRY: {
	foreach (@rec) {
	    if (!/^\#/) {
		if ($count == $click_info->line) {
		    my $l = Strassen::parse($_);
		    $name = $l->[Strassen::NAME];
		    $cat  = $l->[Strassen::CAT];
		    $coords = join(" ", @{$l->[Strassen::COORDS]});

		    my $coordsys = $o->coord_system->coordsys;
		    my $base = $o->file2base->{basename $file};
		    ## XXX $base is not really used today, so do not warn...
		    #main::status_message("Can't get base from $file", "error") if !defined $base;

		    # use only coordinates in coordsys and strip coordsys
		    my @coords;
		    foreach my $coord (@{$l->[Strassen::COORDS]}) {
			my($x,$y,$this_base) = @{Strassen::to_koord1_slow($coord)};
			if (!defined $this_base) {
			    $this_base = $base;
			}
			local $^W = 0;
			if ($this_base eq $coordsys) {
			    push @coords, [$x,$y];
			}
		    }

		    main::mark_street
			    (-coords =>
			     [[ main::transpose_all(@coords) ]],
			     -type => 's',
			     -dont_center => 1,
			    );

		    last TRY;
		}
		$count++;
	    }
	    $rec_count++;
	}
	die "Can't find line <" . $click_info->line . "> in file <$file> which contains <$rec_count> lines and <$count> non-comment lines";
    }

    my $modtime_file = (stat($file))[9];

    if ($okb) {
	$okb->configure(-command => sub {
			    if ($modtime_file != (stat($file))[9]) {
				die "File modified in the meantime!";
			    } else {
				my @l;
				$l[Strassen::NAME] = $name;
				$l[Strassen::CAT]  = $cat;
				$l[Strassen::COORDS] = $coords;
				my $l = Strassen::_arr2line(\@l);
				$rec[$rec_count] = $l;
			    }
			    if (eval { require "$FindBin::RealBin/miscsrc/insert_points" }) {
				$BBBikeModify::datadir = $main::datadir;
				BBBikeModify::do_log($t, "changerec", "$rec_count $name\t$cat $coords", $file);
			    } else {
				warn $@ if $@;
			    }
			    if ($auto_reload) {
				main::reload_all();
			    }
			    $t->destroy;
			});
    }

}

sub start_editor {
    my($file, $line) = @_;
    require BBBikeUtil;
    my @try = ((defined $main::texteditor && $main::texteditor !~ m{^\s*$} ? $main::texteditor : ()),
	       "gnuclient",
	       "emacsclient",
	       "emacsclient-snapshot",
	       "vi",
	      );
    for my $try (@try) {
	if ($try =~ m{gnuclient} && BBBikeUtil::is_in_path($try)) {
	    system($try, '-q', '+'.$line, $file);
	    if ($?/256 != 0) {
		main::status_message("Error while starting $try", "die");
	    }
	    return;
	} elsif ($try =~ m{emacsclient} && BBBikeUtil::is_in_path($try)) {
	    system($try, '-n', '+'.$line, $file);
	    if ($?/256 != 0) {
		main::status_message("Error while starting $try", "die");
	    }
	    return;
	} elsif ($try eq 'vi' && BBBikeUtil::is_in_path($try) && BBBikeUtil::is_in_path("xterm")) {
	    system("xterm", "-e", "vi", "+".$line, $file);
	    if ($?/256 != 0) {
		main::status_message("Error while starting $try in an xterm", "die");
	    }
	    return;
	} elsif (BBBikeUtil::is_in_path($try)) {
	    system($try, "+".$line, $file);
	    if ($?/256 != 0) {
		main::status_message("Error while starting $try", "die");
	    }
	    return;
	}
    }
    main::status_message("Cannot find any text editor, tried @try", "die");
}

sub send_comment {
    my(%args) = @_;
    my($top, $file, $name, $cat, $coords, $clickcoords) = @args{qw(-w -file -name -cat -coords -clickcoords)};
    my $t = $top->Toplevel(-title => M("Kommentar senden"));
    $t->transient($top) unless defined $main::transient && !$main::transient;
    $t->Label(-text => M("Kartenobjekt").":")->pack(-anchor => "w");
    my $fixed_text = "File: $file\nName: $name\nCategory: $cat\nCoords: $coords\nCoords at mouse: " . join(",", @$clickcoords) . "\n\n";
    my $fixed_w = $t->Scrolled("ROText",
			       -scrollbars => "os",
			       -wrap => "none",
			       -bg => $t->cget('-bg'),
			       -borderwidth => 0,
			       -height => 5, -width => 50)->pack(-fill => "both", -expand => 1);
    $fixed_w->insert("end", $fixed_text);
    $t->Label(-text => M("Kommentar").":")->pack(-anchor => "w");
    my $var_w = $t->Scrolled("Text",
			     -scrollbars => "ose",
			     -height => 5, -width => 50)->pack(-fill => "both", -expand => 1);
    $var_w->focus;
    
    {
	$t->Ruler->rulerPack(-pady => 2, -padx => 2);
	my $f = $t->Frame->pack;
	$f->Button(Name => 'ok',
		   -text => M"Mail senden",
		   -command => sub {
		       my $var_text = $var_w->Contents;
		       if ($var_text =~ m{\A\s*\z}) {
			   main::status_message(M("Leere Nachricht. Es wird keine Mail versandt."), "error");
		       } else {
			   require BBBikeMail;
			   require BBBikeVar;
			   my $full_msg = $fixed_text . "\nComment:\n" . $var_text . "\n";
			   my $backup_file = "$main::tmpdir/bbbike_send_comments_backup.txt";
			   if (open(BACKUP, ">> $backup_file")) {
			       print BACKUP $full_msg . "-------------------------------------------\n";
			       close BACKUP;
			       warn "Written mail contents to backup file $backup_file.\n";
			   } else {
			       warn "Cannot write to $backup_file: $!\n";
			   }
			   # Send mail to software maintainer
			   # and CC to data maintainers
			   BBBikeMail::send_mail($BBBike::EMAIL, "BBBike comment (Perl/Tk $main::VERSION)",
						 $full_msg,
						 CC => $BBBike::EMAIL_NEWSTREET,
						);
			   main::status_message(M("Mail wurde eventuell versandt."), "infodlg");
		       }
		       $t->destroy;
		   })->pack(-side => "left");
	$f->Button(Name => 'cancel',
		   -command => sub { $t->destroy })->pack(-side => "left");
    }
}

sub init_with_edittools {
    require BBBikeAdvanced;
    main::set_line_coord_interactive(-geometry => "-0+0");
    ## I don't use this anymore:
    #main::coord_to_markers_dialog(-geometry => "-0+120");
    editmenu($main::top, -geometry => "-0-0");
}

sub editmenu {
    my($top, %args) = @_;
    my $geometry = delete $args{-geometry};
    my $t = main::redisplay_top($main::top, "edit_menu",
				-title => M"Editier-Menü",
				-geometry => $geometry,
			       );
    return if !defined $t;

    require BBBikeAdvanced;
    my $sample_b;
    {
	my $f0 = $t->Frame->pack(-fill => 'x');
	$sample_b = $f0->Button(-text => M("Neu laden"),
		    -command => sub { main::reload_all() },
		    -anchor => "w",
		   )->pack(-side => "left", -fill => "x", -expand => 1);
	my $auto = $f0->Checkbutton(-text => "Auto",
				    -variable => \$auto_reload,
				    -anchor => "w",
				   )->pack(-side => "left");
	my $chb = $f0->Checkbutton(-text => "Crosshairs", # XXX translation?
				   -variable => \$crosshairs_activated,
				   -command => sub {
				       require BBBikeCrosshairs;
				       if ($crosshairs_activated) {
					   BBBikeCrosshairs::activate();
				       } else {
					   BBBikeCrosshairs::deactivate();
				       }
				   },
				   -anchor => "w",
				  )->pack(-side => "left");
	if (Tk::Exists($main::balloon)) {
	    $main::balloon->attach($auto, -msg => M('Automatisches Neuladen nach jeder Änderung'));
	    $main::balloon->attach($chb, -msg => M(<<EOF)); # XXX translation
F4: rotate crosshairs to left
F5: rotate crosshairs to right
Shift-F4: make crosshairs right-angled
Shift-F5: align with street under
F6: enlarge additional rectangle
F7: shrink additional rectangle
Shift-F7: turn off additional rectangle
EOF
	}
    }
    my $insert_point_mode = 0;
    my $old_mode;
    my $cb = $t->Checkbutton
	(-text => M("Punkt einfügen"),
	 -indicatoron => 0,
	 -variable => \$insert_point_mode,
	 -command => sub {
	     if ($insert_point_mode) {
		 $old_mode = $main::map_mode;
		 $main::map_mode = main::MM_INSERTPOINT();
		 my $cursorfile = main::build_text_cursor("Insert");
		 $main::c->configure(-cursor => defined $cursorfile ? $cursorfile : "hand2");
	     } else {
		 if (defined $old_mode) {
		     $main::map_mode = $old_mode;
		     undef $old_mode;
		 }
		 $main::c->configure(-cursor => undef);
	     }
	 },
	 -padx => 12, # XXX X11 only? Font dependent? (was 14 once (for helvetica?))
	 -anchor => "w", 
	)->pack(-fill => "x");
    $cb->configure(-pady => ($sample_b->reqheight-$cb->reqheight)/2);
    $t->Button(-text => M("Mehrere Punkte einfügen"),
	       -command => sub {
		   if (main::insert_multi_points() && $auto_reload) {
		       main::reload_all();
		   }
	       },
	       -anchor => "w", 
	      )->pack(-fill => "x");
    {
	my $f = $t->Frame->pack(-fill => "x", -anchor => "w");
	$f->gridColumnconfigure($_, -weight => 29) for (0, 1);

	my $row = 0;
	$f->Button(-text => M("Punkt bewegen (F3)"),
		   -command => sub {
		       if (main::change_points() && $auto_reload) {
			   main::reload_all();
		       }
		   },
		   -anchor => "w",
		  )->grid(-column => 0, -row => $row, -sticky => "nesw");
	$f->Button(-text => M("Linie bewegen"),
		   -command => sub {
		       if (main::change_line() && $auto_reload) {
			   main::reload_all();
		       }
		   },
		   -anchor => "w",
		  )->grid(-column => 1, -row => $row, -sticky => "nesw");

	$row++;

	$f->Button(-text => M("Punkt suchen"),
		   -command => \&main::grep_point, # never reload necessary
		   -anchor => "w",
		  )->grid(-column => 0, -row => $row, -sticky => "nesw");
	$f->Button(-text => M("Linie suchen"),
		   -command => \&main::grep_line, # never reload necessary
		   -anchor => "w",
		  )->grid(-column => 1, -row => $row, -sticky => "nesw");
	
	$row++;

	{
	    my @files = ((!defined $main::edit_mode || $main::edit_mode eq '')
			 && !$main::edit_normal_mode
			 ? BBBikeEditUtil::get_generated_files()
			 : BBBikeEditUtil::get_orig_files()
			);
	    if (!@files) {
		main::status_message(Mfmt("Keine Dateien in %s gefunden", $main::datadir), "err");
		return;
	    }
	    my $ff = $f->Frame->grid(-column => 0, -row => $row, -columnspan => 2, -sticky => 'nesw');
	    $ff->Button(-text => M("Neu hinzufügen zu: "),
			-command => sub {
			    my $file = $sel_file;
			    if ($file !~ m|^/|) { # XXX use file_name_is_absolute
				$file = "$main::datadir/$file";
			    }
			    addnew($t, $file)
			},
		       )->pack(-side => "left");
	    require Tk::BrowseEntry;
	    my $be = $ff->BrowseEntry(#-state => "readonly",
				      -textvariable => \$sel_file,
				      ($Tk::VERSION >= 804
				       ? (-autolistwidth => 1)
				       : ()
				      )
				     )->pack(-side => "left");
	    $be->Subwidget("slistbox")->configure(-exportselection => 0);
	    $be->insert("end", @files);
	}

	$row++;

	$f->Button(-text => M("Punkt löschen"),
		   -command => sub {
		       if (main::delete_point() && $auto_reload) {
			   main::reload_all();
		       }
		   },
		   -anchor => "w",
		  )->grid(-column => 0, -row => $row, -sticky => 'nesw');

	$f->Button(-text => M("Linie glätten"),
		   -command => sub {
		       if (main::smooth_line() && $auto_reload) {
			   main::reload_all();
		       }
		   },
		   -anchor => 'w',
		  )->grid(-column => 1, -row => $row, -sticky => 'nesw');

	$row++;
    }
##XXX not yet:
#     $t->Button(-text => M("Linien löschen"),
# 	       -command => \&main::delete_lines,
# 	       -anchor => "w",
# 	      )->pack(-fill => "x");
    $t->Label(-justify => "left",
	      -text => M("F8 zum Editieren des Elements unter dem Mauszeiger.\nF2 zum Einfügen eines Punktes."),
	     )->pack(-anchor => "w");
    # XXX Sometimes it happens that the mouse is over the mainwindow,
    # but the edit window still has the focus. For this case I have
    # the Escape binding to fix things.
    $t->bind("<Escape>" => sub {
		 $main::top->focus;
	     });

    $t->update;
    if (!$geometry) {
	$t->Popup(-popover => $top,
		  -popanchor => 'e',
		  -overanchor => 'e',
		 );
    }
}

sub addnew {
    my($top, $file) = @_;
    if (!@main::inslauf_selection) {
	main::status_message(M("Keine Punkte zum Einfügen"), "err");
	return;
    }
    return if !BBBikeEdit::ask_for_co($top, $file);
    my $std_prefix = { BBBikeEditUtil::base() }->{basename($file)};
    my $prefix = "";
    if ($main::coord_system_obj->coordsys ne $std_prefix) {
	$prefix = $main::coord_system_obj->coordsys;
    }
    my $t = $top->Toplevel(-title => M("Neu hinzufügen"));
    $t->transient($top) unless defined $main::transient && !$main::transient;
    $t->Popup(@main::popup_style);
    my($name, $cat, $coords);
    $coords = join(" ", @main::inslauf_selection);
    my($e, $be);
    Tk::grid($t->Label(-text => M("Name")),
	     $e = $t->Entry(-textvariable => \$name),
	     -sticky => "w");
    $e->focus;
    Tk::grid($t->Label(-text => M("Kategorie")),
	     $be = $t->BrowseEntry(-textvariable => \$cat,
				   ($Tk::VERSION >= 804
				    ? (-autolistwidth   => 1,
				       -listheight      => 20,
				       -autolimitheight => 1,
				      )
				    : ()
				   ),
				  ),
	     -sticky => "w");
    Tk::grid($t->Label(-text => M("Koordinaten")),
	     $t->Entry(-textvariable => \$coords),
	     -sticky => "w");
    my $row = 3;
    {
	my $f = $t->Frame->grid(-row => $row++, -column => 0,
				-columnspan => 2, -sticky => "ew");
	$f->Button(Name => "ok",
		   -command => sub {
		       # Trim all:
		       for my $ref (\$name, \$cat, \$coords) {
			   $$ref =~ s{^\s+}{};
			   $$ref =~ s{\s+$}{};
		       }
		       if ($name eq "") {
			   main::status_message(M"Kein Name eingetragen","err");
			   return;
		       }
		       if ($cat eq "") {
			   main::status_message(M"Keine Kategorie eingetragen","err");
			   return;
		       }
		       if ($coords eq "") {
			   main::status_message(M"Keine Kategorie eingetragen","err");
			   return;
		       }
		       $cat =~ s/\s.*//; # remove comment
		       my $line = Strassen::arr2line([$name,$coords,$cat]);
		       ask_for_co($t, $file);
		       if (!open(ADD, ">>$file")) {
			   main::status_message(Mfmt("Kann auf %s nicht schreiben: %s", $file, $!),"err");
			   return;
		       }
		       binmode ADD;
		       print ADD $line;
		       close ADD;

		       if (eval { require "$FindBin::RealBin/miscsrc/insert_points" }) {
			   $BBBikeModify::datadir = $main::datadir;
			   BBBikeModify::do_log($t, "add", "$name\t$cat $coords", $file);
		       } else {
			   warn $@ if $@;
		       }

		       if ($auto_reload) {
			   main::reload_all();
		       }

		       # XXX delete_route light
		       main::reset_button_command();
		       main::reset_selection();

		       $t->destroy;
		   },
		  )->pack(-side => "left");
	$f->Button(Name => "cancel",
		   -command => sub { $t->destroy }
		  )->pack(-side => "left");
    }

    require Strassen::Cat;
    require BBBikeUtil;
    my @cat = Strassen::Cat::get_static_categories($file);
    if (!@cat) {
	@cat = sort keys %main::category_attrib;
    }
    # We have some conflicting categories like 1 (Einbahnstraße OR Ort),
    # B (Bahnübergang OR Bundesstraße). Therefore disable category label
    # expansion for some files:
    if ($file !~ m{\b(ampeln|gesperrt|gesperrt_car)(-orig)?$}) {
	@cat = map {
	    my $cat = $_;
	    (my $cat_label = $cat) =~ s{^F:}{};
	    if (exists $main::category_attrib{$cat_label}) {
		$cat_label = $main::category_attrib{$cat_label}->[0];
	    } else {
		$cat_label = "";
	    }
	    [$cat, $cat_label];
	} @cat;
	my $max_cat_length = BBBikeUtil::max(map { length $_->[0] } @cat);
	$max_cat_length = 4 if $max_cat_length < 4;
	@cat = map { sprintf "%-${max_cat_length}s   %s", @$_ } @cat;
    }

    $be->insert("end", @cat);
}

sub insert_point_from_canvas {
    my $c = shift;
    my($point, @neighbors) = main::nearest_line_points_mouse($c);
    if (@neighbors) {
	$main::c->SelectionOwn(-command => sub {
				   @main::inslauf_selection = ();
				   @main::ext_selection = ();
			       });
	my($middle, $first, $last) = map { join(",", @$_) } @neighbors;
	if ($SRTShortcuts::force_edit_mode) {
	    for ($first, $last) {
		$_ = find_corresponding_orig_point($c, $_);
	    }
	    $middle = $main::coord_prefix . join(",", $main::coord_output_sub->(split /,/, $middle));
	}
	@main::inslauf_selection = ($first, $middle, $last);
	warn "insert coords=@main::inslauf_selection\n";
	if (main::insert_points() && $auto_reload) {
	    main::reload_all();
	}
    }
}

sub find_corresponding_orig_point {
    my($c, $point) = @_;
    my($cx,$cy) = main::transpose(split /,/, $point);
    for my $delta (1 .. 3) {
	my(@items) = $c->find("overlapping",
			      $cx-$delta, $cy-$delta,
			      $cx+$delta, $cy+$delta);
	my @items2;
	my %seen;
	for my $item (@items) {
	    my @tags = $c->gettags($item);
	    if (grep { $_ eq 'pp' } @tags) {
		if (!$seen{$tags[2]}) {
		    push @items2, $item;
		    $seen{$tags[2]} = 1;
		}
	    }
	}

	if (@items2 == 1) {
	    my $orig = ($c->gettags($items2[0]))[2];
	    my $coord = ($c->gettags($items2[0]))[1];
	    if ($orig =~ /^ORIG:(.*)/) { # This is obsolete XXX
		return $1;
	    } elsif ($coord =~ /-?\d+,-?\d+/) {
		return $coord;
	    }
	} elsif (@items2 > 1) {
require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([map { [$_, $c->gettags($_)] } @items2],[])->Indent(1)->Useqq(1)->Dump; # XXX

	    main::status_message("XXX multiple item conflict, please write code for this!", "die");
	}
    }
    main::status_message("Could not found orig point for $point", "die");
}

use vars qw(@points $point_nr $auto_create);

sub relgps_filename { "$main::datadir/relation_gps" }

sub create_relation_menu {
    my($top) = @_;
    my $t = $top->Toplevel(-title => "Create relation menu");
    $t->transient($top) unless defined $main::transient && !$main::transient;

    main::plot("str", "relgps", -draw => 1, -filename => relgps_filename());

    my $old_mode = $main::map_mode;
    $main::map_mode = main::MM_CREATERELATION();

    $t->OnDestroy(sub {
		      $main::map_mode = $old_mode;
		      main::plot("str", "relgps", -draw => 0);
		  });


    @points = (undef);
    foreach my $pnr (1 .. 2) {
	push @points, {};
	my $f = $t->Frame->pack(-anchor => "w");
	$f->Label(-text => "Point $pnr")->pack(-side => "left");
	$f->Entry(-textvariable => \$points[$pnr]->{Coord})->pack(-side => "left");
	$f->Label(-textvariable => \$points[$pnr]->{Type})->pack(-side => "left");
	$f->Label(-textvariable => \$points[$pnr]->{Comment})->pack(-side => "left");
    }
    $point_nr = 1;

    $t->Button(-text => "Reset current",
	       -command => sub {
		   foreach (@points) {
		       foreach my $key (qw(Coord Type Comment)) {
			   $_->{$key} = "";
		       }
		   }
		   $point_nr = 1;
	       })->pack;

    {
	my $f = $t->Frame->pack;
	my($b, $activate_create_button);
	$activate_create_button = sub {
	    $b->configure(-state => ($auto_create ? "disabled" : "normal"));
	};
	$f->Checkbutton(-text => "Auto-Create",
			-variable => \$auto_create,
			-command => $activate_create_button,
		       )->pack(-side => "left");
	$b = $f->Button(-text => "Create",
			-command => [\&do_create_relation],
		       )->pack(-side => "left");
	$activate_create_button->();
    }
    {
	my $f = $t->Frame->pack;
	$f->Button(-text => "Delete from map",
		   -command => sub {
		       main::plot("str", "relgps", -draw => 0);
		       $t->destroy;
		   })->pack;
	$f->Button(-text => "Close",
		   -command => sub {
		       $t->destroy;
		   })->pack;
    }

    $t->update;
    $t->Popup(-popover => $top,
	      -popanchor => 'sw',
	      -overanchor => 'sw',
	     );
}

# XXX this is specific for creating GPS-berlinmap relationships
sub create_relation_from_canvas {
    my $c = shift;

    my(@tags) = $c->gettags('current');
    return if !@tags || !defined $tags[0];

    require BBBikeAdvanced;
    my $inslauf_selection_count = $#main::inslauf_selection;
    main::buttonpoint();
    if ($inslauf_selection_count == $#main::inslauf_selection) {
	return; # nothing was inserted
    }
    # last point in @main::inslauf_selection was just inserted
    my $point = $main::inslauf_selection[-1];

    if ($tags[0] =~ /^(xxx|L\d+)/) {
	# XXX special GPS point handling
	$points[$point_nr]->{Type} = 'GPS';
	$points[$point_nr]->{Comment} = $tags[2];
    } else {
	$points[$point_nr]->{Type} = 'bbbike';
	$points[$point_nr]->{Comment} = "";
    }
    $points[$point_nr]->{Coord} = $point;

    if ($point_nr == 1) {
	$point_nr++;
    } else {
	if ($auto_create) {
	    do_create_relation();
	}
	$point_nr = 1; # XXX?
    }
}

# parameters: points array reference (optional, if not given then use
# global @points variable)
sub do_create_relation {
    my $pointsref = shift;
    my @points = @points;
    if ($pointsref && ref $pointsref eq 'ARRAY') {
	@points = @$pointsref;
    }

    die "Same coords!" if ($points[1]->{Coord} eq $points[2]->{Coord} &&
			   $points[1]->{Type} ne $points[2]->{Type});
    die "Empty coords!" if ($points[1]->{Coord} eq '' ||
			    $points[2]->{Coord} eq '');

    $main::str_file{'relgps'} = relgps_filename();
    my $file = "$main::str_file{'relgps'}-orig";
    ask_for_co($main::top, $file);
    open(RELFILE, ">>$file") or main::status_message("Can't write to $file: $!", "die");
    binmode RELFILE;
    my @order = (1,2);
    if ($points[2]->{Type} eq 'GPS') {
	@order = (2,1);
    }
    print RELFILE $points[$order[0]]->{Comment};
    print RELFILE "\tGPS ";
    print RELFILE join(" ", map { $points[$_]->{Coord} } @order);
    print RELFILE "\n";
    close RELFILE;

    main::plot("str", "relgps", FastUpdate => 1, -draw => 1);
}

use vars qw($gps_penalty_koeff $gps_penalty_multiply
	    $bbd_penalty_koeff $bbd_penalty_multiply $bbd_penalty_file
	    $bbd_penalty_invert
	    $st_net_koeff $st_net_penalty_file
	   );

sub build_gps_penalty_for_search {
    require Strassen::Core;
    my $s = new Strassen relgps_filename();
    die "Can't get " . relgps_filename() if !$s;
    $s->init;
    my $penalty = {};
    while(1) {
	my $r = $s->next;
	last if !@{ $r->[Strassen::COORDS()] };
	$penalty->{$r->[Strassen::COORDS()]->[1]}++;
    }
#XXX evtl. weiteren Modus, der die Genauigkeit der Punkte berücksichtigt
# (falls mehrere Punkte auf den gleichen Punkt verweisen, dann die
# Varianz ausrechnen und berücksichtigen)
    $main::penalty_subs{gpspenalty} = sub {
	my($pen, $next_node) = @_;
	if (exists $penalty->{$next_node}) {
	    if ($gps_penalty_multiply) {
		$pen *= $gps_penalty_koeff * $penalty->{$next_node};
	    } else {
		$pen *= $gps_penalty_koeff;
	    }
	    #warn "Hit penalty node $next_node\n";#XXX
	}
	$pen;
    };
}

sub choose_bbd_file_for_penalty {
    my $f = $main::top->getOpenFile
	(-filetypes =>
	 [
	  # XXX use Strassen->filetypes?
	  [M"BBD-Dateien", '.bbd'],
	  [M"Alle Dateien", '*'],
	 ],
	 -initialdir => $main::datadir,
	);
    return if !defined $f;
    $bbd_penalty_file = $f;
}

sub build_bbd_penalty_for_search {
    if (!defined $bbd_penalty_file) {
	choose_bbd_file_for_penalty();
	return if (!defined $bbd_penalty_file);
    }
    require Strassen::Core;
    my $s = new Strassen $bbd_penalty_file;
    die "Can't get $bbd_penalty_file" if !$s;
    $s->init;
    my $penalty = {};
    while(1) {
	my $r = $s->next;
	last if !@{ $r->[Strassen::COORDS()] };
	for my $i (0 .. $#{ $r->[Strassen::COORDS()] }-1) {
	    # XXX beide Richtungen???
	    $penalty->{$r->[Strassen::COORDS()]->[$i] . "," . $r->[Strassen::COORDS()]->[$i+1]}++;
	    $penalty->{$r->[Strassen::COORDS()]->[$i+1] . "," . $r->[Strassen::COORDS()]->[$i]}++;
	}
    }

    if ($bbd_penalty_invert) {
	warn M"Die Bedeutung der Penalty-Daten invertieren...\n";
	my $new_penalty = {};
	if (!$main::net) {
	    $bbd_penalty_invert = 0;
	    main::status_message(M"Nur möglich, wenn ein Netz existiert", "die");
	}
	my $net = $main::net->{Net};
	while(my($k1,$v) = each %$net) {
	    while(my($k2,$v2) = each %$v) {
		my $k12 = "$k1,$k2";
		my $k21 = "$k2,$k1";
		if (!exists $penalty->{$k12}) {
		    $new_penalty->{$k12}++;
		}
		if (!exists $penalty->{$k21}) {
		    $new_penalty->{$k21}++;
		}
	    }
	}
	$penalty = $new_penalty;
    }

    $main::penalty_subs{bbdpenalty} = sub {
	my($pen, $next_node, $last_node) = @_;
	if (exists $penalty->{$last_node.",".$next_node}) {
	    if ($bbd_penalty_multiply) {
		$pen *= $bbd_penalty_koeff * $penalty->{$last_node.",".$next_node};
	    } else {
		$pen *= $bbd_penalty_koeff;
	    }
	    #warn "Hit penalty node $next_node\n";#XXX
	}
	$pen;
    };
}

sub choose_st_net_file_for_penalty {
    my $f = $main::top->getOpenFile
	(-filetypes =>
	 [
	  [M"Net/Storable-Dateien", '.st'],
	  [M"Alle Dateien", '*'],
	 ],
	 -initialdir => $main::datadir,
	);
    return if !defined $f;
    $st_net_penalty_file = $f;
}

sub build_st_net_penalty_for_search {
    if (!defined $st_net_penalty_file) {
	choose_st_net_file_for_penalty();
	return if (!defined $st_net_penalty_file);
    }
    require Storable;
    my $penalty = Storable::retrieve($st_net_penalty_file);
    die "Can't retrieve $st_net_penalty_file" if !$penalty;

    $main::penalty_subs{stnetpenalty} = sub {
	my($pen, $next_node, $last_node) = @_;
	if (exists $penalty->{$last_node.",".$next_node}) {
	    my $this_penalty = $penalty->{$last_node.",".$next_node};
	    $this_penalty = $st_net_koeff * $this_penalty + (100-$st_net_koeff*100)
		if $st_net_koeff != 1;
	    if ($this_penalty < 1) { $this_penalty = 1 } # avoid div by zero or negative values
	    $pen *= (100 / $this_penalty);
	}
	$pen;
    };
}

######################################################################
# edit GPSMAN waypoints

use vars qw($edit_gpsman_waypoint_tl @edit_gpsman_history);

sub set_edit_gpsman_waypoint {
    if ($main::map_mode eq main::MM_CUSTOMCHOOSE()) {
	main::status_message(M("GPS-Punkte-Editor-Modus wahrscheinlich schon gesetzt"), "warn");
	return;
    }
    $main::map_mode = main::MM_CUSTOMCHOOSE();
    my $cursorfile = main::build_text_cursor("Edit wpt");
    $main::c->configure(-cursor => defined $cursorfile ? $cursorfile : "hand2");
    main::status_message(M("Waypoints editieren"), "info");
    $main::customchoosecmd = sub {
	my($c,$e) = @_;
	my(@tags) = $c->gettags("current");
	return unless grep { $_ =~ /^(?:xxx|L\d+)-fg$/ } @tags;
	edit_gpsman_waypoint($tags[2]);
    };
}

sub edit_gpsman_waypoint {
    my($wpt_tag) = @_;
    require DB_File;
    require Fcntl;
    require GPS::GpsmanData;
    require Karte::Polar;
    require Karte::Berlinmap1996;
    my $polarmap = $Karte::Polar::obj;
    my $b1996map = $Karte::Berlinmap1996::obj;

    my($basefile, $wpt, $descr) = split m|/|, $wpt_tag;
    if (!defined $basefile || !defined $wpt) {
	main::status_message(Mfmt("Der Tag <%s> kann nicht geparst werden", $wpt_tag), "err");
	return;
    }
    if (!-d $main::gpsman_data_dir) {
	main::status_message(Mfmt("Die GPSMan-Datei muss sich im Verzeichnis <%s> befinden", $main::gpsman_data_dir), "err");
	return;
    }
    my $file = find_gpsman_file($basefile);
    if (!defined $file) {
	main::status_message(Mfmt("Die Datei <%s> konnte nicht im Verzeichnis <%s> oder den Unterverzeichnissen gefunden werden", $basefile, $main::gpsman_data_dir), "err");
	return;
    }
    ask_for_co($main::top, $file);
    tie my @gpsman_data, 'DB_File', $file, &Fcntl::O_RDWR, 0644, $DB_File::DB_RECNO
	or do {
	    main::status_message(Mfmt("Die Datei <%s> kann nicht geöffnet werden: %s", $file, $!), "err");
	    return;
	};

    my $tl;
    my $create_tl = sub {
	if (Tk::Exists($edit_gpsman_waypoint_tl)) {
	    $_->destroy for $edit_gpsman_waypoint_tl->children;
	    $edit_gpsman_waypoint_tl->deiconify;
	    $tl = $edit_gpsman_waypoint_tl;
	    $tl->Walk(sub {
			  my $w = shift;
			  eval {
			      $w->configure(-state => "normal");
			  };
		      });
	    $tl->raise;
	} else {
	    $tl = $main::top->Toplevel(-title => "Waypoint");
	    $edit_gpsman_waypoint_tl = $tl;
	    $tl->transient($main::top) if $main::transient;
	    $tl->Popup(@main::popup_style);
	}
    };

    foreach my $inx (0 .. $#gpsman_data) {
	my $line = $gpsman_data[$inx];
	if ($line =~ /^\Q$wpt\E\t/) {
	    my @f = split /\t/, $line;
	    local $_ = $line;
	    my $wptobj = GPS::GpsmanData::parse_waypoint();
	    #my $descr = $f[1]; # equivalent
	    my $descr = $wptobj->Comment;
	    $create_tl->();
	    my $row = 0;
	    $tl->Label(-text => M("+ für Kreuzungen benutzen")."\n"."Waypoint $wpt")->grid(-column => 0, -row => $row, -sticky => "w");
	    my $Entry = "Entry";
	    my @EntryArgs = (-width => 40);
	    if (eval {require Tk::HistEntry; Tk::HistEntry->VERSION(0.37)}) {
		$Entry = 'HistEntry';
		@EntryArgs = (-match => 1, -dup => 0);
	    }
	    my $garmin_valid_chars = sub {
		$_[0] =~ /^[-A-ZÄÖÜa-zäöüß.+0-9 -]*$/; # the same as in ~/.gpsman-dir/patch.tcl
	    };
	    my $e = $tl->$Entry
		(-validate => "key",
		 -vcmd => $garmin_valid_chars,
		 @EntryArgs,
		 -textvariable => \$descr)->grid(-column => 1, -row => $row, -sticky => "w");
	    if ($e->can('history')) {
		$e->history([@edit_gpsman_history]);
	    }
	    $e->focus;
	    my $wait = 0;
	    my $b = $tl->Button(-text => "OK",
			       -command => sub { $descr ne "" and $wait = 1 })
		->grid(-column => 3, -row => $row);
	    $e->bind("<Return>" => sub { $b->invoke });
	    $e->bind("<Escape>" => sub { $wait = -1 });

	    my($px,$py) = $polarmap->map2standard
		(map { GPS::GpsmanData::convert_DMS_to_DDD($_) }
		 $wptobj->Longitude, $wptobj->Latitude);
	    my @nearest_crossings = get_nearest_crossing_obj(0,$px,$py, -uniquename => 1);
	    my(@descr2) = map { $_->{CrossingName} } @nearest_crossings;
	    my $descr2 = @descr2 ? $descr2[0] : "";
	    my $create_rel = @descr2 > 0 && $nearest_crossings[0]->{Source} eq 'BBBikeData';
	    $row++;
	    $tl->Label(-text => M("Nächste Kreuzung"))->grid(-column => 0, -row => $row, -sticky => "w");
	    my $e2 = $tl->BrowseEntry(-width => 40,
				      -textvariable => \$descr2,
				      -choices => \@descr2)->grid(-column => 1, -row => $row, -sticky => "w");
	    $tl->Checkbutton(-text => M"Relation erzeugen",
			     -variable => \$create_rel)->grid(-column => 2, -row => $row, -sticky => "w");

	    my $b2 = $tl->Button(-text => "OK",
				 -command => sub { $descr2 ne "" and $wait = 2 })
		->grid(-column => 3, -row => $row);
	    $e2->bind("<Return>" => sub { $b2->invoke });
	    $e2->bind("<Escape>" => sub { $wait = -1 });

	    $tl->OnDestroy(sub { $wait = -1 });
	    $tl->waitVariable(\$wait);

	    if ($wait == 2) {
		$descr = $descr2;
		if ($create_rel) {
		    my($tx,$ty) = map { int } $b1996map->standard2map($px,$py);
		    my($cr_obj) = get_nearest_crossing_obj(1, $tx,$ty, -onlybbbikedata => 1);
		    if (!$cr_obj) {
			main::status_message("Can't create relation: no crossing for $tx/$ty", "err");
			die;
		    }
		    my @p = (undef,
			     {Coord => $cr_obj->{Coord},
			      Type => "bbbike",
			      Comment => ""},
			     {Coord => "$tx,$ty",
			      Type => "GPS",
			      Comment => "$basefile/".$wptobj->Ident."/$descr"}
			    );
		    do_create_relation(\@p);
		}
	    }

	    if ($wait == 1 || $wait == 2) {
		if ($e->can('historyAdd')) {
		    my @crossings = split /\+/, $descr;
		    foreach (@crossings) {
			$e->historyAdd($_);
		    }
		    @edit_gpsman_history = $e->history;
		}
		$f[1] = $descr;
		$gpsman_data[$inx] = join("\t", @f);
	    }
	    untie @gpsman_data;
	    $tl->withdraw if Tk::Exists($tl);
	    return;
	} elsif ($line =~ /^\t\Q$wpt\E\t/) { # track waypoint
	    $create_tl->();
	    my @f = split /\t/, $line;
	    my $acc = "";
	    if ($f[4] =~ /^(~+|\?)/) {
		$acc = $1;
	    }
	    #my $weiter = 0;
	    #my $close = sub { $weiter = 1 };
	    my $disable = sub {
		$tl->Walk(sub {
			      my $w = shift;
			      eval {
				  $w->configure(-state => "disabled");
			      };
			  });
	    };
	    my $set_accuracy = sub {
		$f[4] =~ s/^(~*\|?)/$acc/;
		my $new_line = join("\t", @f);
		warn $new_line;
		$gpsman_data[$inx] = $new_line;
		$disable->();
		untie @gpsman_data;
		#$close->();
	    };
	    my $f = $tl->Frame->pack;
	    for my $accval ('', '?', '~', '~~') {
		$f->Radiobutton(-text => $accval eq '' ? '!' : $accval,
				-value => $accval,
				-variable => \$acc,
				-indicator => 0,
				-command => $set_accuracy)->pack(-side => "left");
	    }
	    $tl->Button(Name => "close",
			#-command => $close,
			-command => sub {
			    untie @gpsman_data;
			    $tl->withdraw if Tk::Exists($tl);
			},
		       )->pack;
	    #$tl->OnDestroy(sub { $weiter = -1 });
	    #$tl->waitVariable(\$weiter);
	    #untie @gpsman_data;
	    #$tl->withdraw if Tk::Exists($tl);
	    return;
	}

    }

    main::status_message(Mfmt("Kann den Punkt <%s> nicht finden", $wpt), "warn");
    untie @gpsman_data;
}

# from bbbike.cgi (changed)
use vars qw(%crossings %gpspoints %gpspoints_hash %str_obj);
sub all_crossings {
    my $edit_mode = shift;
    my $strname = ($edit_mode ? "strassen-orig" : "strassen");
    if (!$str_obj{$edit_mode}) {
	$str_obj{$edit_mode} = Strassen->new($strname)
	    or die "Can't get $strname";
    }
    if (scalar keys %{$crossings{$edit_mode}} == 0) {
	%{$crossings{$edit_mode}} = %{ $str_obj{$edit_mode}->all_crossings(RetType => 'hash', UseCache => 1) };
    }
}

# from bbbike.cgi (changed)
#use vars qw(%kr);
sub new_kreuzungen {
    my $edit_mode = shift;
#    if (!$kr{$edit_mode}) {
    if (scalar keys %{$crossings{$edit_mode}} == 0) {
	all_crossings($edit_mode);
#	$kr{$edit_mode} = new Kreuzungen Hash => $crossings{$edit_mode};
#	$kr{$edit_mode}->make_grid;
    }
    if (!$gpspoints{$edit_mode}) {
	my $gpsname = "$Strassen::Util::cachedir/" . ($edit_mode ? "points.bbd-orig" : "points.bbd");
	my $gpspoints_o = Strassen->new($gpsname);
	if (!$gpspoints_o) {
	    warn "Cannot get GPS points from $gpsname";
	} else {
	    $gpspoints_hash{$edit_mode} = $gpspoints_o->get_hashref;
	    $gpspoints{$edit_mode} = Kreuzungen->new(Hash => $gpspoints_hash{$edit_mode});
	    $gpspoints{$edit_mode}->make_grid(Width => 100);
	}
    }

#    $kr{$edit_mode};
}

# from bbbike.cgi (changed)
sub get_nearest_crossing_name {
    my($edit_mode, $x,$y) = @_;
    my @ret = map { $_->{CrossingName} } get_nearest_crossing_obj($edit_mode, $x,$y);
    my %saw;
    grep(!$saw{$_}++, @ret);
}

# from bbbike.cgi (changed)
sub get_nearest_crossing_obj {
    my($edit_mode, $x,$y, %args) = @_;
    new_kreuzungen($edit_mode);

    my @ret;

    my $ret = $str_obj{$edit_mode}->nearest_point("$x,$y", FullReturn => 1);
    $ret->{CrossingName} = ($ret && $crossings{$edit_mode}->{$ret->{Coord}}
			    ? join("+", map { Strassen::strip_bezirk($_) } @{ $crossings{$edit_mode}->{$ret->{Coord}}})
			    : "");
    $ret->{Source} = "BBBikeData";
    push @ret, $ret;

    my $ret2;
    if ($gpspoints{$edit_mode} && !$args{-onlybbbikedata}) {
	push @ret, map { my $cr_name = $gpspoints_hash{$edit_mode}->{$_->[0]};
			 $cr_name = (split '/', $cr_name)[2];
			 +{Coord => $_->[0],
			   Dist => $_->[1],
			   CrossingName => $cr_name,
			   Source => "GPSData",
			  }
		     } $gpspoints{$edit_mode}->nearest($x,$y,IncludeDistance => 1);
    }

    @ret = map  { $_->[1] }
	   sort { $a->[0] <=> $b->[0] }
	   map  { [$_->{Dist}, $_] }
	   @ret;

    if ($args{-uniquename}) {
	my %saw;
	@ret = grep(!$saw{$_->{CrossingName}}++, @ret);
    }

    @ret;
}

use vars qw($remember_map_mode_for_edit_gps_track);
sub edit_gps_track_mode {
    $remember_map_mode_for_edit_gps_track = $main::map_mode
	if $main::map_mode ne main::MM_CUSTOMCHOOSE_TAG();
    $main::map_mode = main::MM_CUSTOMCHOOSE_TAG();
    my $cursorfile = main::build_text_cursor("GPS trk");
    $main::c->configure(-cursor => defined $cursorfile ? $cursorfile : "hand2");
    main::status_message(M("Track zum Editieren auswählen"), "info");
    $main::customchoosecmd = sub {
	my($c,$e) = @_;
	my(@tags) = $c->gettags("current");
	for (@tags) {
	    if (/(.*\.trk)/) {
		edit_gps_track_by_basename($1);
		last;
	    } elsif (/^(L\d+)$/ && exists $main::str_file{$1} &&
		     $main::str_file{$1} =~ /(\d+\.trk)/) {
		edit_gps_track_by_basename($1);
		last;
	    }
	}
    };
}

sub edit_gps_track_by_basename {
    my $basename = shift;
    my $file = find_gpsman_file($basename);
    edit_gps_track($file);
}

use vars qw($recent_gps_point_layer $recent_gps_street_layer);
sub edit_gps_track {
    my $file = shift;
    if (-r $file) {
	local $main::lazy_plot = 0; # somehow does not work
	main::IncBusy($main::top);
	eval {
	    if ($main::edit_mode) {
		if ($main::edit_mode eq 'b') {
		    require "$ENV{HOME}/src/bbbike/miscsrc/gpsman2bbd.pl";
		    BBBike::GpsmanConv::gpsman2bbd(qw(-deststreets streets.bbd-orig -destpoints points.bbd-orig -destmap berlinmap -destdir /tmp), $file, qw(-forcepoints));
#		    system("$ENV{HOME}/src/bbbike/miscsrc/gpsman2bbd.pl -deststreets streets.bbd-orig -destpoints points.bbd-orig -destmap berlinmap -destdir /tmp $file -forcepoints");
		} else {
		    main::status_message("No support for edit mode $main::edit_mode", "error");
		    die;
		}
	    } else {
		require "$ENV{HOME}/src/bbbike/miscsrc/gpsman2bbd.pl";
		BBBike::GpsmanConv::gpsman2bbd(qw(-destdir /tmp), $file, qw(-forcepoints));
#		system("$ENV{HOME}/src/bbbike/miscsrc/gpsman2bbd.pl -destdir /tmp $file -forcepoints");
	    }

	    my $abk   = main::plot_layer('p', "/tmp/points.bbd");
	    my $abk_s = main::plot_layer('str', "/tmp/streets.bbd");

	    main::special_raise($abk_s);
	    main::special_raise($abk);
	    main::special_raise($abk."-fg");

	    $recent_gps_street_layer = $abk_s;
	    $recent_gps_point_layer  = $abk;
	};
	my $err = $@;
	main::DecBusy($main::top);
	warn $err if $err;

    } else {
	warn "Can't find file $file";
    }

    if (defined $remember_map_mode_for_edit_gps_track) {
	undef $main::customchoosecmd;
	main::set_map_mode($remember_map_mode_for_edit_gps_track);
	undef $remember_map_mode_for_edit_gps_track;
    }
}

sub show_gps_track_mode {
    $remember_map_mode_for_edit_gps_track = $main::map_mode
	if $main::map_mode ne main::MM_CUSTOMCHOOSE_TAG();
    $main::map_mode = main::MM_CUSTOMCHOOSE_TAG();
    my $cursorfile = main::build_text_cursor("GPS trk");
    $main::c->configure(-cursor => defined $cursorfile ? $cursorfile : "hand2");
    main::status_message(M("Track zum Anzeigen auswählen"), "info");
    $main::customchoosecmd = sub {
	my($c,$e) = @_;
	my(@tags) = $c->gettags("current");
	my $base;
	for (@tags) {
	    if (/(.*\.trk)/) {
		$base = $1;
		last;
	    } elsif (/^(L\d+)$/ && exists $main::str_file{$1} &&
		     $main::str_file{$1} =~ /(\d+\.trk)/) {
		$base = $1;
		last;
	    }
	}
	if ($base) {
	    my $file = find_gpsman_file($base);
	    if (!$file) {
		main::status_message(M("Keine Datei zu $base gefunden"));
		return;
	    }
	    BBBikeGPS::do_draw_gpsman_data($main::top, $file, -solidcoloring => 1);

	    if (defined $remember_map_mode_for_edit_gps_track) {
		undef $main::customchoosecmd;
		main::set_map_mode($remember_map_mode_for_edit_gps_track);
		undef $remember_map_mode_for_edit_gps_track;
	    }
	}
    };
}

use vars qw($prefer_tracks); # "bahn" or "street"

sub find_gpsman_file {
    my $basename = shift;
    require File::Spec;
    my $rootdir = $main::gpsman_data_dir;
    if (defined $prefer_tracks && $prefer_tracks eq 'bahn') {
	$rootdir .= "/bahn";
    }
    my $file = (File::Spec->file_name_is_absolute($basename)
		? $basename
		: "$rootdir/$basename"
	       );
    if (!-r $file) {
	undef $file;
	require File::Find;
	File::Find::find(sub {
			     if ($File::Find::name =~ /\b(RCS|CVS)\b/) {
				 $File::Find::prune = 1;
				 return;
			     }
			     if ($_ eq $basename) {
				 $file = $File::Find::name;
				 $File::Find::prune = 1;
			     }
			 }, $rootdir);
	if (defined $file) {
	    warn "Datei <$file> für Basename <$basename> gefunden\n";
	}
    }
    $file;
}

sub clone {
    my $orig = shift;
    my $clone;
    if (eval { require Storable; 1 }) {
	$clone = Storable::dclone($orig);
    } else {
	require Data::Dumper;
	my $clone;
	$clone = eval Data::Dumper->new([$orig], ['clone'])->Indent(0)->Purity(1)->Dump;
    }
    $clone;
}

# XXX further implementation needed:
#     * verschiedene Typen von blockings editierbar machen, mindestens jedoch
#       "3" und "q4". Untermenü zum Auswählen des aktuellen blocking-typs.
#       das Zeichnen der zusätzlichen Sperrungen mit dem normalen
#       Zeichnen möglichst unifizieren.
#     * beim Abspeichern sollte der Typ nicht mehr angegeben werden müssen
#     * beim Laden ebenfalls nicht. Im cgi und in bbbike wird statt pauschal
#       "make_sperre" nach Kategorien differenziert und je Strassen-Objekte
#       für make_sperre und merge_handicap_net on-the-fly generiert
#     * Teile von miscsrc/bbbike-check-temp-blockings modularisieren
#       und nach bbbike/BBBikeTempBlockings.pm verschieben: Laden der
#       temp-blockings.pl-Datei, Checken, was davon aktuell ist
#     * bbbike: Einzelne blockings sollten ein/ausgeblendet werden können
sub temp_blockings_editor {
    my $t = main::redisplay_top($main::top, "temp_blockings_editor",
				-title => M"Temporäre Sperrungen");
    return if !defined $t;
    require File::Spec;
    require File::Basename;
    require File::Copy;
    require POSIX;

    require Tk::PathEntry;
    require Tk::Date;
    require Tk::NumEntry;
    require Tk::LabFrame;
    require Tk::ROText;

    $t->gridColumnconfigure($_, -weight => 1) for (1..2);
    $t->gridRowconfigure   ($_, -weight => 1) for (1..8);

    eval {
	require "$FindBin::RealBin/miscsrc/check_bbbike_temp_blockings";
    }; warn $@ if $@;

    my $initialdir = $BBBike::check_bbbike_temp_blockings::temp_blockings_dir . "/";
    my $pl_file = $BBBike::check_bbbike_temp_blockings::temp_blockings_pl;
    my $file = $initialdir;
    my $as_data; # default set below with "invoke"
    my $prewarn_days = 1;
    my $blocking_type = "gesperrt";
    my $edit_after = 0;
    my $do_delete_blockings = 1;
    my $auto_cross_road_blockings = 0;
    my $is_in_work = 1;
    my $meta_data_handling = "append";
    my $pe;
    my $as_data_cb;
    Tk::grid($t->Label(-text => M("bbd-Datei").":"),
	     $pe = $t->PathEntry(-textvariable => \$file),
	     $as_data_cb = $t->Checkbutton(-text => "as data",
					   -variable => \$as_data,
					   -command => sub {
					       $pe->configure(-state => $as_data ? "disabled" : "normal"),
					   },
					  ),
	     -sticky => "w",
	    );
    $pe->focus;
    $pe->icursor("end");
    $as_data_cb->invoke; # default to "as data"

    Tk::grid($t->Label(-text => M("Beschreibung").":"),
	     -sticky => "w",
	    );
    my $txt;
    Tk::grid($txt = $t->Scrolled("Text", -scrollbars => "e",
				 -width => 40, -height => 3,
				),
	     -sticky => "ew",
	     -columnspan => 2);
    my $real_txt = $txt->Subwidget("scrolled");

    my $btn_f;
    {
	my %info = $txt->gridInfo;
	my $txt_row = $info{-row};
	$btn_f = $t->Frame->grid(-row => $txt_row, -column => 2, -sticky => "nw");
    }

    my $paste_b = $btn_f->Button
	(-text => "Paste", -bd => 1, -padx => 0, -pady => 0
	)->pack(-anchor => "w");
    my $act_b = $btn_f->Button
	(-text => "Date", -bd => 1, -padx => 0, -pady => 0
	)->pack(-anchor => "w");
    my $fmt_b = $btn_f->Button
	(-text => "Fmt", -bd => 1, -padx => 0, -pady => 0
	)->pack(-anchor => "w");

    my $source_id;
    Tk::grid($t->Label(-text => "Source-ID"),
	     $t->Entry(-width => 20,
		       -textvariable => \$source_id,
		      ),
	     -sticky => "w",
	    );

    my($start_w, $end_w);
    my($start_undef, $end_undef);
    Tk::grid($t->Label(-text => M"Start"),
	     $start_w = $t->Date(-choices => ["now", "tomorrow"]),
	     $t->Checkbutton(-text => "undef",
			     -variable => \$start_undef),
	     -sticky => "w",
	    );

    Tk::grid($t->Label(-text => M"Ende"),
	     $end_w = $t->Date(-choices => ["now", "tomorrow"]),
	     $t->Checkbutton(-text => "undef",
			     -variable => \$end_undef),
	     -sticky => "w",
	    );

    Tk::grid($t->Label(-text => M"Vorwarnzeit in Tagen"),
	     $t->NumEntry(-textvariable => \$prewarn_days,
			  -width => 3,
			  -minvalue => 0,
			 ),
	     -sticky => "w",
	    );

    my $cs = 3;
    {
	my $f = $t->LabFrame(-label => M"Typ",
			     -labelside => "acrosstop");
	Tk::grid($f, -sticky => "ew", -columnspan => $cs);
	$f->Radiobutton(-text => M"gesperrt",
			-value => "gesperrt",
			-variable => \$blocking_type,
		       )->pack(-anchor => "w");
	$f->Radiobutton(-text => M"Einbahnstraße (Richtung manuell korrigieren!)",
			-value => "oneway",
			-variable => \$blocking_type,
		       )->pack(-anchor => "w");
	$f->Radiobutton(-text => M"handicap",
			-value => "handicap-q4",
			-variable => \$blocking_type,
		       )->pack(-anchor => "w");
	$f->Radiobutton(-text => M"handicap in einer Richtung (Richtung manuell korrigieren!)",
			-value => "handicap-q4-oneway",
			-variable => \$blocking_type,
		       )->pack(-anchor => "w");
    }

    Tk::grid($t->Checkbutton(-text => M"Überqueren der gesperrten Straßen nicht möglich",
			     -variable => \$auto_cross_road_blockings,
			    ),
	     -sticky => "w",
	     -columnspan => $cs,
	    );

    Tk::grid($t->Checkbutton(-text => M"Baustelle",
			     -variable => \$is_in_work,
			    ),
	     -sticky => "w",
	     -columnspan => $cs,
	    );

    {
	my $f = $t->LabFrame(-label => M"Metadaten",
			     -labelside => "acrosstop");
	Tk::grid($f, -sticky => "ew", -columnspan => $cs);
	$f->Radiobutton(-text => M"Nach STDERR schreiben",
			-value => "",
			-variable => \$meta_data_handling,
		       )->pack(-anchor => "w");
	$f->Radiobutton(-text => M"An zentrale pl-Datei anhängen",
			-value => "append",
			-variable => \$meta_data_handling,
		       )->pack(-anchor => "w");
	$f->Radiobutton(-text => M"Existierenden Eintrag ersetzen",
			-value => "replace",
			-variable => \$meta_data_handling,
		       )->pack(-anchor => "w");
	$f->Radiobutton(-text => M"Existierenden Eintrag ersetzen, alte Strecken beibehalten",
			-value => "replace_preserve_data",
			-variable => \$meta_data_handling,
		       )->pack(-anchor => "w");
    }

    {
	my $f = $t->LabFrame(-label => M"Im Anschluss...",
			     -labelside => "acrosstop");
	Tk::grid($f, -sticky => "ew", -columnspan => $cs);
	

	$f->Checkbutton(-text => M"Dateien editieren",
			-variable => \$edit_after,
		       )->pack(-anchor => "w");
	$f->Checkbutton(-text => M"Sperrungen in BBBike löschen",
			-variable => \$do_delete_blockings,
		       )->pack(-anchor => "w");
    }

    my $get_text = sub {
	my $btxt = $real_txt->get("1.0", "end");
	$btxt =~ s/\n\Z//;
	$btxt =~ s/\s+/ /gs;
	$btxt;
    };

    $paste_b->configure
	(-command => sub {
	     $real_txt->delete("1.0","end");
	     my($selection) = $real_txt->SelectionGet;
	     if ($selection =~ /\t/) {
		 # very probably from choose_ort window
		 chomp $selection;
		 my($action, $content, $id) = split /\t/, $selection;
		 $real_txt->insert("end", $content);
		 $id =~ s{[^A-Za-z0-9_.-]}{}g;
		 $source_id = $id;
	     } else {
		 $real_txt->insert("end", $selection);
	     }
	 });

    $act_b->configure
	(-command => sub {
	     require BBBikeEditUtil;
	     my $btxt = $get_text->();
	     $real_txt->delete("1.0","end");
	     $real_txt->insert("end", $btxt);
	     my($new_start_time, $new_end_time, $new_prewarn_days) =
		 BBBikeEditUtil::parse_dates($btxt);
	     if (defined $new_prewarn_days) {
		 $prewarn_days = $new_prewarn_days;
	     }
	     my @parse_error;
	     if (defined $new_start_time) {
		 $start_w->configure(-value => $new_start_time);
	     } else {
		 push @parse_error, "Startdatum";
	     }
	     if (defined $new_end_time) {
		 $end_w->configure  (-value => $new_end_time);
	     } else {
		 push @parse_error, "Enddatum";
	     }
	     if (@parse_error) {
		 main::status_message("Kann " . join(" und ", @parse_error) .
				      " nicht parsen", "warn");
	     }
	 });

    $fmt_b->configure
	(-command => sub {
	     my $btxt = $real_txt->get("1.0", "end");
	     $btxt =~ s/^(?:NEW|CHANGED|UNCHANGED|REMOVED)(,\s+\((coords|text)\))?\s*//;
	     $btxt =~ s/[;,]\s+umleitung//i;
	     $btxt =~ s/\s*\(\d{1,2}:\d{2}\)\s*$//; # seen in vmz records
	     $real_txt->delete("1.0","end");
	     $real_txt->insert("end", $btxt);
	 });

    Tk::grid($t->Button
	     (-text => "Ok",
	      -command => sub {
		  if (!$as_data) {
		      if (!defined $file || $file =~ /^\s*$/) {
			  $t->messageBox(-message => "Dateiname fehlt oder `as data' wählen");
			  return;
		      }
		      if (-d $file) {
			  $t->messageBox(-message => "Bitte neue bbd-Datei auswählen oder `as data' wählen");
			  return;
		      }
		      if (-e $file) {
			  my $ans = $t->messageBox(-type => "YesNo", -icon => "question", -message => "Soll die existierende Datei `$file' überschrieben werden?");
			  if ($ans !~ /yes/i) {
			      return;
			  }
		      }
		  }
		  my $blocking_text = $get_text->();
		  $blocking_text =~ s/\'/\\\'/g; # mask for perl sq string
		  if ($blocking_text eq '') {
		      $t->messageBox(-message => "Beschreibender Text fehlt");
		      return;
		  }
		  if ($blocking_text =~ m{[\x{0100}-\x{fffd}]}) {
		      my $ans = $t->messageBox(-type => 'OkCancel', -icon => 'question', -message => "Unicode-Zeichen oberhalb des Codespoints 255 enthalten. Diese Zeichen können zurzeit nicht verwendet werden. Automatisch konvertieren? Achtung: Informationsverlust kann auftreten!");
		      if ($ans !~ /ok/i) {
			  return;
		      }
		      if (eval { require Text::Unidecode; 1 }) {
			  $blocking_text = unidecode_any($blocking_text, "iso-8859-1");
		      }
		  }
		  my $start_time = $start_undef ? undef : $start_w->get;
		  my $end_time   = $end_undef   ? undef : $end_w->get;
		  if ((!$start_undef && !defined $start_time) ||
		      (!$end_undef && !defined $end_time)) {
		      $t->messageBox(-message => "Bitte Start/Endzeit eintragen oder `undef' wählen");
		      return;
		  }
		  if ($start_time) {
		      $start_time -= $prewarn_days * 86400;
		  }

		  if ($as_data) {
		      require File::Temp;
		      (my($fh), $file) = File::Temp::tempfile(SUFFIX => ".bbd",
							      UNLINK => 1);
		  }

		  main::save_user_dels($file,
				       -type => $blocking_type,
				       ($is_in_work ? (-addinfo => "inwork") : (-addinfo => "temp")),
				      );
		  if ($auto_cross_road_blockings) {
		      my $add_userdels = add_cross_road_blockings();
		      if ($add_userdels) {
			  $add_userdels->append($file);
		      }
		  }

		  my $rel_file = $file;
		  if (index($rel_file, $initialdir) != 0) {
		      $rel_file = File::Spec->abs2rel($rel_file); # XXX base needed?
		  } else {

		      $rel_file = File::Basename::basename($rel_file); # XXX handle deeper hiearchies?
		  }

		  File::Copy::copy($pl_file, "$pl_file~");
		  my @old_contents;
		  open(PL_FILE, $pl_file)
		      or main::status_message("Can't open $pl_file: $!", "die");
		  @old_contents = <PL_FILE>;
		  close PL_FILE;

		  my $blocking_type2 = $blocking_type;
		  if ($blocking_type =~ /^handicap/) {
		      $blocking_type = "handicap";
		  } elsif ($blocking_type eq 'oneway') {
		      $blocking_type = "gesperrt";
		  } elsif ($blocking_type ne "gesperrt") {
		      main::status_message("Unknown blocking type <$blocking_type>", "info");
		  }
		  $start_time = "undef" if $start_undef;
		  $end_time = "undef" if $end_undef;
		  my $pl_entry = <<EOF;
     { from  => $start_time, # @{[ $start_undef ? "" : POSIX::strftime("%Y-%m-%d %H:%M", localtime $start_time) ]}
       until => $end_time, # @{[ $end_undef ? "XXX" : POSIX::strftime("%Y-%m-%d %H:%M", localtime $end_time) ]}
       text  => '$blocking_text',
       type  => '$blocking_type',
EOF
		  if (defined $source_id && $source_id !~ /^\s*$/) {
		      $pl_entry .= <<EOF;
       source_id => '$source_id',
EOF
		  }
		  if ($meta_data_handling eq 'replace_preserve_data') {
		      $pl_entry .= "###PRESERVE DATA\n";
		  } else {
		      if ($as_data) {
			  my $s = Strassen->new($file);
			  if ($s->count == 0) {
			      $t->messageBox(-message => "Keine Blockierungen ausgewählt");
			      return;
			  }
			  $pl_entry .= "       data  => <<EOF,\n" . $s->as_string . "EOF\n";
		      } else {
			  $pl_entry .= <<EOF;
       file  => '$rel_file',
EOF
		      }
		  }
		  $pl_entry .= <<EOF;
     },
EOF

		  if ($old_contents[-1] =~ m{^\s*\);\s*$}) {
		      splice @old_contents, -1, 0, $pl_entry;
		      if ($meta_data_handling eq 'append') {
			  ask_for_co($t, $pl_file);
			  open(PL_OUT, "> $pl_file")
			      or main::status_message("Kann auf $pl_file nicht schreiben: $!", "die");
			  binmode PL_OUT;
			  print PL_OUT join "", @old_contents;
			  close PL_OUT;
		      } elsif ($meta_data_handling eq 'replace' ||
			       $meta_data_handling eq 'replace_preserve_data') {
			  my $ret = temp_blockings_editor_replace
			      (-string => $pl_entry,
			       -text   => $blocking_text,
			       -preserve_data => $meta_data_handling eq 'replace_preserve_data',
			       -source_id => $source_id,
			      );
			  if (!$ret) {
			      return;
			  }
		      } else {
			  print STDERR join "", @old_contents;
		      }
		  } else {
		      main::status_message("Can't parse old contents in file <$pl_file>", "err");
		      return;
		  }

		  if ($do_delete_blockings) {
		      main::delete_user_dels(-force => 1);
		  }

		  if (Tk::Exists($t)) {
		      $t->destroy;
		  }

		  my $check_cmd = "$FindBin::RealBin/miscsrc/check_bbbike_temp_blockings";
		  if (eval { require Tk::ExecuteCommand; 1 }) {
		      $main::top->update;
		      my $check_tl = $main::top->Toplevel(-title => "check_bbbike_temp_blockings problems");
		      $check_tl->withdraw;
		      my $exec = $check_tl->ExecuteCommand (-command => $check_cmd)->pack(qw(-fill both -expand 1));
		      $exec->terse_gui;
		      $exec->execute_command;
		      my($stat,$err) = $exec->get_status;
		      if ($stat != 0) {
			  $check_tl->deiconify;
			  $check_tl->raise;
		      } else {
			  $check_tl->destroy;
		      }
							    
		  } else {
		      my $err = `$check_cmd`;
		      if ($? != 0) {
			  my $t = $main::top->Toplevel(-title => "check_bbbike_temp_blockings problems");
			  my $txt = $t->Scrolled("ROText")->pack(-fill => "both",
								 -expand => 1);
			  $txt->insert("end", $err);
			  $txt->insert("end", "\nBitte auch STDERR beachten!");
		      }
		  }

		  # Im Anschluss...
		  if ($edit_after) {
		      if (fork == 0) {
			  exec("emacsclient", "-n", $pl_file);
			  CORE::exit(1);
		      }
		      if (!$as_data) {
			  if (fork == 0) {
			      exec("emacsclient", "-n", $file);
			      CORE::exit(1);
			  }
		      }
		  }
	      }),
	     $t->Button
	      (-text => M"Abbruch",
	       -command => sub {
		   $t->destroy;
	       }),
	      -sticky => "ew",
	     );

warn "XXX 13";
    $pe->idletasks; # to fill the variable
warn "XXX 14";
    $pe->xview(1);#XXX does not work???
warn "XXX 15";
}

sub temp_blockings_editor_preserve_data {
    my($new, $old) = @_;
    my $data_or_file = "";
    my $stage = '';
    for my $line (split /\n/, $old) {
	if ($stage eq '') {
	    if ($line =~ /^\s*data/) {
		$stage = 'in_data';
		$data_or_file .= $line . "\n";
	    } elsif ($line =~ /^\s*file/) {
		# no stage change, just one line
		$data_or_file .= $line . "\n";
	    }
	} elsif ($stage eq 'in_data') {
	    $data_or_file .= $line . "\n";
	    if ($line =~ /^EOF/) {
		$stage = '';
	    }
	}
    }
    if ($new !~ s/^###PRESERVE DATA\n/$data_or_file/m) {
	warn "Can't find PRESERVE DATA tag in <$new>";
	main::status_message("Can't find PRESERVE DATA tag!", "die");
    }
    $new;
}

sub temp_blockings_editor_replace {
    my(%args) = @_;
    my $ret = 0;
    my $new_string = $args{-string};
    my $new_text   = $args{-text};
    my $preserve_data = $args{-preserve_data};
    my $source_id = $args{-source_id};
    if (!eval { require String::Similarity; 1 }) {
	main::status_message($@, "die");
    }
    use vars qw(@temp_blocking);
    my $pl_file = $BBBike::check_bbbike_temp_blockings::temp_blockings_pl;
    do $pl_file;
    if (!@temp_blocking) {
	main::status_message("Keine Einträge in <$pl_file> gefunden", "die");
    }

    my $max_index;
    my $max_similarity;
    my $found_through_source_id;
    # First find exactly matching records through source_id
    if (defined $source_id && $source_id !~ /^\s*$/) {
	for(my $index = $#temp_blocking; $index >= 0; $index--) {
	    my $record = $temp_blocking[$index];
	    if (defined $record->{source_id} &&
		$record->{source_id} eq $source_id) {
		$found_through_source_id = 1;
		$max_index = $index;
		last;
	    }
	}
    }

    if (!defined $max_index) {
	# Nothing found? Then try the best similar record.
	for my $index (0 .. $#temp_blocking) {
	    my $record = $temp_blocking[$index];
	    my $similarity = String::Similarity::similarity(lc $record->{text}, lc $new_text);
	    if (!defined $max_similarity || $similarity > $max_similarity) {
		$max_index = $index;
		$max_similarity = $similarity;
	    }
	}
	if ($max_similarity == 0) {
	    main::status_message("Keinen ähnlichen Eintrag gefunden", "info");
	    return $ret;
	}
    }

    open(PL_IN, "< $pl_file")
	or main::status_message("Kann $pl_file nicht lesen: $!", "die");
    my $stage = "pre";
    my %s;
    my $record_count = -1;
    while(<PL_IN>) {
	if (/^\s*\{/) {
	    $record_count++;
	    if ($record_count == $max_index) {
		$stage = "inner";
	    }
	} elsif (/^\s*\}/) {
	    $s{$stage} .= $_;
	    if ($record_count == $max_index) {
		$stage = "post";
	    }
	    next;
	}
	$s{$stage} .= $_;
    }
    close PL_IN;

    if ($preserve_data) {
	$new_string = temp_blockings_editor_preserve_data($new_string, $s{inner});
    }

    my $yesno;
    {
	require Tk::DialogBox;
	my $d = $main::top->DialogBox
	    (-title => M"Ersetzen",
	     -buttons => [M"Ja", M"Manuell wählen", M"Nein"],
	    );
	$d->add("Label", -text => "Replace the following record:")->pack(-fill => "x");
	my $t1 = $d->add("Scrolled", "ROText", -width => 50, -height => 10,
			 -scrollbars => "osoe")->pack(-fill => "x");
	$d->add("Label", -text => "with:")->pack(-fill => "x");
	my $t2 = $d->add("Scrolled", "ROText", -width => 50, -height => 10,
			 -scrollbars => "osoe")->pack(-fill => "x");
	my $info_label = "? (index = $max_index, ";
	if ($found_through_source_id) {
	    $info_label .= "Found through same source id)";
	} else {
	    $info_label .= "similarity factor = $max_similarity)";
	}
	$d->add("Label", -text => $info_label)->pack(-fill => "x");

	if (eval { require Algorithm::Diff; 1 }) {
	    my @old = split /(\s+)/, $s{"inner"};
	    my @new = split /(\s+)/, $new_string;
	    for ($t1, $t2) {
		$_->tagConfigure("delchunk",    -foreground => "red");
		$_->tagConfigure("inschunk",    -foreground => "green");
		$_->tagConfigure("changechunk", -foreground => "orange");
	    }
	    Algorithm::Diff::traverse_balanced
		    (\@old, \@new,
		     { MATCH => sub {
			   my($old,$new) = @_;
			   $t1->insert("end", $old[$old]);
			   $t2->insert("end", $new[$new]);
		       },
		       DISCARD_A => sub {
			   my($old,undef) = @_;
			   $t1->insert("end", $old[$old], "delchunk");
		       },
		       DISCARD_B => sub {
			   my(undef,$new) = @_;
			   $t2->insert("end", $new[$new], "inschunk");
		       },
		       CHANGE => sub {
			   my($old,$new) = @_;
			   $t1->insert("end", $old[$old], "changechunk");
			   $t2->insert("end", $new[$new], "changechunk");
		       },
		     }
		    );
	} else {
	    $t1->insert("end", $s{"inner"});
	    $t2->insert("end", $new_string);
	}

	$yesno = $d->Show;
    }

    if ($yesno eq M"Ja") {
	ask_for_co($main::top, $pl_file);
	open PL_OUT, "> $pl_file" or main::status_message($!, "die");
	binmode PL_OUT;
	print PL_OUT $s{pre} . $new_string . $s{post};
	close PL_OUT;
	$ret = 1;
    } elsif ($yesno eq M"Manuell wählen") {
	my $t = $main::top->Toplevel(-title => M"Manuell wählen");
	$t->transient($main::top) if $main::transient;
	require Tk::HList;
	my $hl = $t->Scrolled("HList",
			      -width => 50,
			      -height => 10,
			      -selectmode => "single",
			     )->pack(-fill => "both",
				     -expand => 1);
	    open(PL_IN, "< $pl_file")
	or main::status_message("Kann $pl_file nicht lesen: $!", "die");

	my $stage = "pre";
	my %s;
	my @records;
	while(<PL_IN>) {
	    if (/^\s*\{/) {
		push @records, "";
		$stage = "inner";
	    } elsif (/^\s*\);/) {
		$stage = "post";
	    }
	    if ($stage eq 'inner') {
		$records[-1] .= $_;
	    } else {
		$s{$stage} .= $_;
	    }
	}
	close PL_IN;

	my $rec_i = 0;
	for my $rec (@records) {
	    $hl->add($rec_i, -text => $rec);
	    $rec_i++;
	}

	{
	    my $search_term = "";
	    my $search_sub = sub {
		search_in_hlist($hl, $search_term,
				-nocase => 1,
				-match => 'substr');
	    };
	    my $search_f = $t->Frame->pack(-fill => 'x');
	    $search_f->Button(-text => M"Suchen",
			      -command => $search_sub)->pack(-side => "left");
	    my $search_e = $search_f->Entry(-textvariable => \$search_term)->pack(-side => "left", -fill => 'x');
	    $search_e->bind("<Return>" => $search_sub);
	}

	my $weiter;
	{
	    my $f = $t->Frame->pack(-fill => "x");
	    Tk::grid($f->Button(Name => "ok",
				-command => sub {
				    $weiter = +1;
				},
			       ),
		     $f->Button(Name => "cancel",
				-command => sub {
				    $weiter = -1;
				}
			       ),
		    );
	}


    TRYAGAIN:
	$t->OnDestroy(sub { $weiter = -1 });
	$t->waitVariable(\$weiter);

	if ($weiter == 1) {
	    my($sel) = $hl->selectionGet;
	    if (!defined $sel) {
		goto TRYAGAIN;
	    }

	    ask_for_co($t, $pl_file);
	    open PL_OUT, "> $pl_file" or main::status_message($!, "die");
	    binmode PL_OUT;
	    print PL_OUT $s{pre};
	    if ($sel > 0) {
		print PL_OUT join("", @records[0 .. $sel-1]);
	    }
	    print PL_OUT $new_string;
	    if ($sel+1 <= $#records) {
		print PL_OUT join("", @records[$sel+1 .. $#records]);
	    }
	    print PL_OUT $s{post};
	    close PL_OUT;

	    $ret = 1;
	} else {
	    # do nothing
	}

	$t->destroy if Tk::Exists($t);

    } else {
	# do nothing
    }

    $ret;
}

sub search_in_hlist {
    my($hl, $search_term, %args) = @_;
    my $begin_at = $args{-beginat} || 'anchor';
    my $match_type = $args{-match} || 'exact';
    my $no_case = $args{-nocase};

    if ($no_case) {
	$search_term = lc $search_term;
    }

    my $curr_entry;
    if ($begin_at eq 'anchor') {
	$curr_entry = $hl->info('anchor');
	if (!defined $curr_entry || $curr_entry eq '') {
	    $curr_entry = ($hl->info('children'))[0];
	}
    } else {
	$curr_entry = $hl->info($begin_at);
    }
    if (!defined $curr_entry || $curr_entry eq '') {
	return;
    }

    my $wrapped = 0;
    my $no_next = 0;
    while (1) {
	while(1) {
	    if (!$no_next) {
		$curr_entry = $hl->info('next', $curr_entry);
	    } else {
		$no_next = 0;
	    }
	    last if !defined $curr_entry || $curr_entry eq ''; # at bottom
	    for my $col_i (0 .. $hl->cget(-columns) - 1) {
		my $text = $hl->itemCget($curr_entry, $col_i, '-text');
		$text = lc $text if $no_case;

		my $found = sub {
		    $hl->anchorSet($curr_entry);
		    $hl->see($curr_entry);
		    return $curr_entry;
		};

		if ($match_type eq 'exact') {
		    if ($text eq $search_term) {
			return $found->();
		    }
		} elsif ($match_type =~ /^substr/) {
		    if (index($text, $search_term) > -1) {
			return $found->();
		    }
		} elsif ($match_type =~ /^regex/) {
		    if ($text =~ /$search_term/) {
			return $found->();
		    }
		}
	    }
	}
	if ($wrapped) {
	    return;
	} else {
	    $wrapped = 1;
	    $no_next = 1;
	    $curr_entry = ($hl->info('children'))[0];
	}
    }
}

sub add_cross_road_blockings {
    # Do not reuse $main::net, because there are already the deletions stored!
    require Strassen::Core;
    require Strassen::StrassenNetz;
    my $str = Strassen->new("strassen");
    my $str_net = StrassenNetz->new($str);
    $str_net->make_net;
    # XXX use del_token?
    my $dels_str = $main::net->create_user_deletions_object;
    my $dels_net = StrassenNetz->new($dels_str);
    $dels_net->make_net;
    my $str_net_Net  = $str_net->{Net};
    my $dels_net_Net = $dels_net->{Net};
    $dels_str->init;
    my %cross_road_blockings;
    my %seen;
    while(1) {
	my $r = $dels_str->next;
	last if !@{ $r->[Strassen::COORDS()] };
	for my $p (@{ $r->[Strassen::COORDS()] }) {
	    next if $seen{$p};
	    next if keys %{ $dels_net_Net->{$p} } == 1; # Endpunkt der Sperrung
	    my %all_neighbors = map {($_,1)} keys %{ $str_net_Net->{$p} };
	    for (keys %{ $dels_net_Net->{$p} }) {
		delete $all_neighbors{$_};
	    }
	    if (keys %all_neighbors > 1) {
		for my $p1 (keys %all_neighbors) {
		    for my $p2 (keys %all_neighbors) {
			next if $p1 eq $p2;
			$cross_road_blockings{$p1}{$p}{$p2}++;
		    }
		}
	    }
	    $seen{$p}++;
	}
    }

    my $add_userdels = Strassen->new;
    while(my($p1,$v) = each %cross_road_blockings) {
	while(my($p,$v2) = each %$v) {
	    while(my($p2) = each %$v2) {
		$add_userdels->push(["userdel auto", [$p1, $p, $p2], "3"]);
	    }
	}
    }

    require Strassen::Combine;
    my $add_userdels_combined = $add_userdels->make_long_streets(-ignorecat => ["3"]);

    $add_userdels_combined;
}

{
    my($map, $c, $transpose, $abk, $s);

    sub draw_pp_draw_code {
	my $r = shift;
	for my $p (@{ $r->[Strassen::COORDS()] }) {
	    my($ox,$oy) = split /,/, $p;
	    my($prefix) = $ox =~ m/^([^0-9+-]+)/; # stores prefix
	    $prefix = "" if !defined $prefix;
	    $ox =~ s/^([^0-9+-]+)//; # removes prefix
	    my $map = $prefix ? $Karte::map_by_coordsys{$prefix} : $map;
	    #if (!defined $map) { warn "@$r $p $prefix" }
	    my($x, $y)  = $map->map2standard($ox,$oy);
	    my($cx,$cy) = $transpose->($x,$y);
	    $c->createLine($cx,$cy,$cx,$cy,
			   -tags => ['pp', "$x,$y",
				     "ORIG:$prefix$ox,$oy", "pp-$abk"],
			  );
	}
    }

    sub draw_pp_init_code {
	my(undef, $file, %args) = @_;
	$c = $main::c;
	$transpose = \&main::transpose;
	$abk = $args{-abk} || '';
	$c->delete("pp-$abk");

	my @orig_files;
	if (ref $file eq "ARRAY") {
	    @orig_files = map { "$_-orig" } @$file;
	    $s = MultiStrassen->new(@orig_files);
	} else {
	    @orig_files = $file."-orig";
	    $s = Strassen->new(@orig_files);
	}

	my $nonorig_s;
	if (ref $file eq 'ARRAY') {
	    $nonorig_s = MultiStrassen->new(@$file);
	} else {
	    $nonorig_s = Strassen->new($file);
	}

	my $maptoken = $args{-map};
	require Karte;
	Karte::preload(":all");
	require BBBikeEditUtil;
	$map = $Karte::map{$maptoken};
	my $mapprefix = $map->coordsys if $map;
	for my $f (@orig_files) {
	    my $baseprefix = { BBBikeEditUtil::base() }->{$f};
	    if (defined $mapprefix && $mapprefix ne $baseprefix) {
		warn "Ambigous base prefixes ($mapprefix vs $baseprefix)";
	    } else {
		$mapprefix = $baseprefix;
	    }
	}
	$map = $Karte::map_by_coordsys{$mapprefix};
	($s, $nonorig_s);
    }

    sub draw_pp_post_draw_code {
	$c->itemconfigure('pp',
			  -capstyle => $main::capstyle_round,
			  -width => 5,
			 );
	main::pp_color();
    }
}

sub draw_pp {
    my($s) = draw_pp_init_code(@_);
    my $top = $main::top;
    main::IncBusy($top);
    eval {
	$s->init;
	while(1) {
	    my $r = $s->next;
	    last if !@{ $r->[Strassen::COORDS()] };
	    draw_pp_draw_code($r);
	}
	draw_pp_post_draw_code();
    };
    my $err = $@;
    main::DecBusy($top);
    main::status_message($err, "die") if $err;
}

sub move_marks_by_delta {
    my @coords = @main::coords;
    my $c = $main::c;

    if (@coords != 2) {
	main::status_message(M"Genau zwei Koordinaten erwartet!", "error");
	return;
    }
    my $dx = $coords[1]->[0] - $coords[0]->[0];
    my $dy = $coords[1]->[1] - $coords[0]->[1];
 MARKITEMS:
    for my $i ($c->find("withtag" => "show")) {
	my @t = $c->gettags($i);
	for (@t) {
	    next MARKITEMS if ($_ eq 'show_adjusted');
	}
	$c->move($i, $dx, $dy);
	$c->addtag("show_adjusted", withtag => $i);
    }
}

sub reset_mark_adjusted_tag {
    my $c = $main::c;
    $c->dtag("show_adjusted");
}

# REPO BEGIN
# REPO NAME unidecode_any /home/e/eserte/work/srezic-repository 
# REPO MD5 59f056efd990dc126e49f5e846eee797

=head2 unidecode_any($text, $encoding)

Similar to Text::Unidecode::unidecode, but convert to the given
$encoding. This will return an octet string in the given I<$encoding>.
If all you want is just to restrict the charset of the string to a
specific encoding charset, then it's best to C<Encode::decode> the
result again with I<$encoding>.

=cut

sub unidecode_any {
    my($text, $encoding) = @_;

    require Text::Unidecode;
    require Encode;

    # provide better conversions for german umlauts
    my %override = ("\xc4" => "Ae",
		    "\xd6" => "Oe",
		    "\xdc" => "Ue",
		    "\xe4" => "ae",
		    "\xf6" => "oe",
		    "\xfc" => "ue",
		   );
    my $override_rx = "(" . join("|", map { quotemeta } keys %override) . ")";
    $override_rx = qr{$override_rx};

    my $res = "";

    if (!eval {
	Encode->VERSION(2.12); # need v2.12 to support coderef
	$res = Encode::encode($encoding, $text,
			      sub {
				  my $ch = chr $_[0];
				  if ($ch =~ $override_rx) {
				      return $override{$ch};
				  } else {
				      my $ascii = unidecode($ch);
				      Encode::_utf8_off($ascii);
				      $ascii;
				  }
			      });
	1;
    }) {
	for (split //, $text) {
	    my $conv = eval { Encode::encode($encoding, $_, Encode::FB_CROAK()) };
	    if ($@) {
		$res .= Text::Unidecode::unidecode($_);
	    } else {
		$res .= $conv;
	    }
	}
    }

    $res;
}
# REPO END


1;
