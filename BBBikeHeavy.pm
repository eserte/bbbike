# -*- perl -*-

#
# $Id: BBBikeHeavy.pm,v 1.41 2009/01/21 21:39:25 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeHeavy;

$VERSION = sprintf("%d.%02d", q$Revision: 1.41 $ =~ /(\d+)\.(\d+)/);

package main;
use strict;
use BBBikeGlobalVars;
use BBBikeUtil qw(STAT_MODTIME);

BEGIN {
    if (!defined &M) {
	eval 'sub M ($) { @_ }'; warn $@ if $@;
    }
}

# Automatisches Scrolling, wenn der Benutzer die Maus zum Rand des Canvases
# bewegt.
### AutoLoad Sub
sub BBBikeHeavy::start_followmouse {
    # Bei Versionen bis einschließlich 800.013 kann man mit dieser
    # Funktion Tk zum Absturz bringen.
    # Hmmm... anscheinend auch mit 800.022 schlecht. containing() scheint
    # böse zu sein. Aber 803.023 scheint zu gehen...
    return $Tk::VERSION < 803;
    stop_followmouse(); # vorsichtshalber...
    my $scroll_lock;
    my $followmouse_last;
    my $set_scroll_lock = sub {
	$scroll_lock = $c->after(100,
				 sub { undef $scroll_lock });
    };
    $followmouse_repeat = $c->repeat
      (10, sub {
	   return if !$c;
	   my $e = $c->XEvent;
	   return if $scroll_lock or !$e;
	   # XXX Das hier scheint böse zu sein:
	   my $under_w = $c->containing($e->X, $e->Y);
	   if (!defined $under_w or $under_w ne $c) {
	       undef $followmouse_last;
	       return;
	   }
	   my($x, $y) = ($e->x, $e->y);
	   my $real_canvas_width  = $c->width;
	   my $real_canvas_height = $c->height;
	   my $pad = 30;
	   if ($x < $pad) {
	       $c->xview(scroll => -1, 'units');
	       $set_scroll_lock->();
	   }
	   if ($y < $pad) {
	       # Das Scrollen nach oben um 0.3 Sekunden verzögern, weil
	       # der Benutzer evtl. nur das Menü erreichen wollte.
	       my $now = Tk::timeofday();
	       if (!defined $followmouse_last) {
		   $followmouse_last = $now;
		   return;
	       }
	       if (defined $followmouse_last and
		   $followmouse_last+.300 < $now ) {
	       } else {
		   return;
	       }
	       $c->yview(scroll => -1, 'units');
	       $set_scroll_lock->();
	   } else {
	       undef $followmouse_last;
	   }
	   if ($x > $real_canvas_width-$pad) {
	       $c->xview(scroll => +1, 'units');
	       $set_scroll_lock->();
	   }
	   if ($y > $real_canvas_height-$pad) {
	       $c->yview(scroll => +1, 'units');
	       $set_scroll_lock->();
	   }
       });
}

### AutoLoad Sub
sub BBBikeHeavy::stop_followmouse {
    if ($followmouse_repeat) {
	$followmouse_repeat->cancel;
	undef $followmouse_repeat;
    }
}

# Dump an human-readable error message with error string $errstring for
# string eval'ed code $evalcode
sub BBBikeHeavy::string_eval_die {
    my($errstring, $evalcode) = @_;
    my($line) = $errstring =~ /line\s+(\d+)/;
    if (defined $line) {
	$line--; # human vs. machine numbering
	my(@l) = split /\n/, $evalcode;
	my $from_line = $line - 3; $from_line = 0   if $from_line < 0;
	my $to_line   = $line + 3; $to_line   = $#l if $to_line   > $#l;
	status_message("$errstring\n" .
		       join("", map { sprintf "%4d %s\n", $_+1, $l[$_] } ($from_line .. $to_line)) .
		       "\n", "die");
    } else {
	status_message($errstring, "die");
    }
}

### AutoLoad Sub
sub BBBikeHeavy::load_plugins {
    my($pluginref) = @_;
    my @plugins = @$pluginref;
    my @errors;
    foreach my $plugin (@plugins) {
	load_plugin($plugin, \@errors);
    }
    if (@errors) {
	my $text = join("\n", map {$_->[0]} @errors);
	my $type = $errors[0]->[1]; # should use the highest severity, but in this case everything's "err"
	main::status_message($text, $type);
    }
}

### AutoLoad Sub
sub BBBikeHeavy::load_plugin {
    my($file, $errorref) = @_;
    my @plugin_args;
    if ($file =~ /^(.*)=(.*)$/) {
	$file = $1;
	#@plugin_args = split / /, $2;
	require Text::ParseWords;
	@plugin_args = Text::ParseWords::shellwords($2);
    }
    $file .= ".pm" if ($file !~ /\.pm$/);
    my($mod) = fileparse($file, '\..*');
    my $loading_error = 0;
    my $add_error = sub {
	my($text, $type) = @_;
	if ($errorref) {
	    push @$errorref, [$text,$type];
	} else {
	    main::status_message($text, $type);
	}
	undef;
    };
    if (-r $file) {
	do $file or do {
	    return $add_error->(Mfmt("Die Datei %s konnte nicht geladen werden: %s", $file, $@), "err");
	};
	$INC{"$mod.pm"} = $file;
    } elsif (-r "$FindBin::RealBin/$file") {
	do "$FindBin::RealBin/$file" or do {
	    return $add_error->(Mfmt("Die Datei %s konnte nicht geladen werden: %s", "$FindBin::RealBin/$file", $@), "err");
	};
	$INC{"$mod.pm"} = "$FindBin::RealBin/$file";
    } else {
	my $ok = 0;
	if (!file_name_is_absolute($file)) {
	    foreach my $d (@INC) {
		if (-r "$d/$file") {
		    do $file;
		    $INC{"$mod.pm"} = "$d/$file";
		    $ok = 1;
		    last;
		}
	    }
	}

	if (!$ok) {
	    eval 'require $file';
	    if ($@) {
		my $err = $@;
		return $add_error->(Mfmt("Die Datei %s konnte nicht geladen werden. Grund: %s", $file, $@), "err");
	    }
	}
    }
    eval $mod.'::register(@plugin_args)';
    if ($@) {
	return $add_error->(Mfmt("Das Plugin %s konnte nicht registriert werden. Grund: %s", $mod, $@), "err");
    }
    1;
}

sub BBBikeHeavy::layer_editor {
    require Tk::LayerEditorToplevel;
    Tk::LayerEditorToplevel->VERSION(0.11);
    # XXX max. 1 layereditor öffnen bzw. Änderungen per Hooks an andere
    # editoren propagieren
    my @elem;
    my $reorder_elems = sub {
	@elem = (
		 {'Image' => $ampel_klein_photo,
		  'Text'  => M"Ampeln",
		  'Visible' => $p_draw{'lsa'},
		  'Data' => {Tag => 'lsa-fg',
			     Type  => 'p',
			     Subtype => 'lsa',
			    }
		 },
		 {'Image' => $search_photo,
		  'Text'  => M"Route",
		  'Visible' => (@realcoords > 0),
		  'Data' => {Group => 'route',}
		 },
		 {'Image' => $strasse_photo,
		  'Text'  => M"Straßen",
		  'Visible' => $str_draw{'s'},
		  'Data' => {Group => 'str_s',
			     Type  => 's',
			     Subtype => 's',
			    }
		 },
		 {'Image' => $landstrasse_photo,
		  'Text'  => M"Landstraßen",
		  'Visible' => $str_draw{'l'},
		  'Data' => {Group => 'str_l',
			     Type => 's',
			     Subtype => 'l',
			    }
		 },
		 {'Image' => $ort_photo,
		  'Text'  => M"Orte",
		  'Visible' => $p_draw{'o'},
		  'Data' => {Group => 'p_o',
			     Type  => 'p',
			     Subtype => 'o',
			    }
		 },
		 {'Image' => $ubahn_photo,
		  'Text'  => M"U-Bahn",
		  'Visible' => $str_draw{'u'},
		  'Data' => {Group => 'str_u',
			     Type  => 's',
			     Subtype => 'u',
			    }
		 },
		 {'Image' => $sbahn_photo,
		  'Text'  => M"S-Bahn",
		  'Visible' => $str_draw{'b'},
		  'Data' => {Group => 'str_b',
			     Type => 's',
			     Subtype => 'b',
			    }
		 },
		 {'Image' => $rbahn_photo,
		  'Text'  => M"Regionalbahn",
		  'Visible' => $str_draw{'r'},
		  'Data' => {Group => 'str_r',
			     Type => 's',
			     Subtype => 'r',
			    }
		 },
		 {'Image' => $wasser_photo,
		  'Text'  => M"Gewässser",
		  'Visible' => $str_draw{'w'},
		  'Data' => {Group => 'str_w',
			     Type => 's',
			     Subtype => 'w',
			    }
		 },
		 {'Image' => $flaechen_photo,
		  'Text'  => M"Flächen",
		  'Visible' => $str_draw{'f'},
		  'Data' => {Group => 'str_f',
			     Type => 's',
			     Subtype => 'f',
			    }
		 },
		 {'Text'  => M"Grenzen von Berlin",
		  'Visible' => $str_draw{'g'},
		  'Data' => {Group => 'str_g',
			     Type => 's',
			     Subtype => 'g',
			    }
		 },
		 {'Text'  => M"Grenzen von Potsdam",
		  'Visible' => $str_draw{'gP'},
		  'Data' => {Group => 'str_g',
			     Type => 's',
			     Subtype => 'gP',
			    }
		 },
		 {'Text'  => M"Staatsgrenzen",
		  'Visible' => $str_draw{'gD'},
		  'Data' => {Group => 'str_g',
			     Type => 's',
			     Subtype => 'gD',
			    }
		 },
		 {'Text'  => M"Kneipen etc.",
		  'Visible' => $p_draw{'kn'},
		  'Data' => {Group => 'p_kn',
			     Type => 'p',
			     Subtype => 'kn',
			    }
		 },
		 {'Text'  => M"Sehenswürdigkeiten",
		   'Image' => $star_photo,
		  'Visible' => $str_draw{'v'},
		  'Data' => {Group => 'v',
			     Type => 's',
			     Subtype => 'v',
			    }
		 },
##XXX toggling won't work with this definition alone
# 		 {'Text'  => M"Persönliche Orte",
# 		  'Visible' => $p_draw{'personal'},
# 		  'Data' => {Tag => 'personal-fg',
# 			     Type => 'p',
# 			     Subtype => 'personal',
# 			    }
# 		 },
		);
	if ($advanced) {
	    push @elem, {Image => undef,
			 Text => 'pp',
			 Visible => $p_draw{'pp'},
			 Data => {Tag => 'pp',
				  Type => 'p',
				  Subtype => 'pp',
				 }
			};
	    push @elem, {Image => undef,
			 Text => '?',
			 Visible => $str_draw{'fz'},
			 Data => {Tag => 'fz',
				  Type => 's',
				  Subtype => 'fz',
				 }
			};
	}
	while(my($abk, $val) = each %str_draw) {
	    next if $abk !~ /^L\d/;
	    if ($val && (defined $str_file{$abk} || $str_obj{$abk})) {
		my $layer_name = $layer_name{$abk}; $layer_name = "Layer $abk" if !defined $layer_name ;
		if (defined $str_file{$abk}) {
		    $layer_name .= " (" .basename($str_file{$abk}).")";
		}
		push @elem,
		    {Image => $layer_icon{$abk},
		     Text => $layer_name,
		     Visible => $val,
		     Data => {Tag => "$abk", # XXX apparently without "-s"
			      Type => 's',
			      Subtype => $abk,
			     }
		    };
	    }
	}
	while(my($abk, $val) = each %p_draw) {
	    next if $abk !~ /^L\d/;
	    if ($val && (defined $p_file{$abk} || $p_obj{$abk})) {
		my $layer_name = $layer_name{$abk}; $layer_name = "Layer $abk" if !defined $layer_name;
		if (defined $p_file{$abk}) {
		    $layer_name .= " (" .basename($p_file{$abk}).")";
		}
		push @elem,
		    {Image => $layer_icon{$abk},
		     Text => $layer_name,
		     Visible => $val,
		     Data => {Tags => [$abk, "$abk-fg", "$abk-img", "$abk-label"],
			      Type => 'p',
			      Subtype => $abk,
			     }
		    };
	    }
	}
	push @elem,
	    {Image => undef,
	     Text => "Personal",
	     Visible => \$BBBikePersonal::show_places,
	     Data => {Tags => ["personal-label", "personal-fg"],
		      Type => 'p',
		      Subtype => 'personal',
		     }
	    };

	my $score = 0;
	my %score;
	foreach (reverse real_stack_order()) {
	    $score{$_} = $score;
	    $score++;
	}
	# using ST :-)
	@elem = map { $_->[1] }
	        sort { $a->[0] <=> $b->[0] }
		map {
		    if (exists $tag_group{$_->{Data}{Group}} &&
			defined $tag_group{$_->{Data}{Group}} &&
			exists $score{$tag_group{$_->{Data}{Group}}->[0]}
		       ) {
			[$score{$tag_group{$_->{Data}{Group}}->[0]}, $_]
		    } else {
			my $tag = ($_->{Data}{Tags}
				   ? $_->{Data}{Tags}[0]
				   : $_->{Data}{Tag});
#XXXvvv del: sollten keine warnings mehr auftreten
if (!defined $tag) {
warn "Tag is undefined for: ";
require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([$_],[])->Indent(1)->Useqq(1)->Dump; # XXX
}
#XXX^^^
			[$score{$tag}, $_] # XXX oder 0?
		    }
		} @elem;
    };
    $reorder_elems->();

    my $bbl = $top->LayerEditorToplevel
	(-title => M"Layer-Editor",
	 -closelabel => M"Schließen",
	 -orderchange => sub {
	     my $items = $_[1];
	     foreach my $item (reverse @$items) {
		 if (defined $item->{Data}{Group} && exists $tag_group{$item->{Data}{Group}}) {
		     foreach (@{ $tag_group{$item->{Data}{Group}} }) {
			 special_raise($_, 1);
		     }
		 } elsif (defined $item->{Data}{Tags}) {
		     foreach (@{ $item->{Data}{Tags} }) {
			 special_raise($_, 1);
		     }
		 } elsif (defined $item->{Data}{Tag}) {
		     special_raise($item->{Data}{Tag}, 1);
		 }
	     }
	     restack()
	 },
	 -visibilitychange => sub {
	     my($w, $data, $vis) = @_;
	     if (defined $data->{Group} && $data->{Group} eq 'route') {
		 if ($vis) {
		     # do nothing...
		 } else {
		     reset_button_command();
		 }
	     } elsif ($data->{Subtype} eq 'personal') {
		 $BBBikePersonal::show_places = $vis;
		 if (defined &BBBikePersonal::toggle_show) {
		     BBBikePersonal::toggle_show();
		 }
	     } else {
		 eval "\$" . ($data->{Type} eq 's' ? 'str' : 'p') .
		     '_draw{"' . $data->{Subtype} . '"} = ' .
			 ($vis ? "1" : "0");
		 warn __LINE__ . ": $@" if $@;
		 if (exists $check_sub{$data->{Subtype}}) {
		     $check_sub{$data->{Subtype}}->();
		 } else {
		     if ($data->{Type} eq 'p') {
			 plot('p',$data->{Subtype});
		     } else {
			 plot('str',$data->{Subtype});
		     }
		 }
	     }
	 },
	 -transient => $top,
	);
    $bbl->add(@elem);

    # Hooks
    my $bblpath = $bbl->PathName;
    for my $hook (qw(after_new_layer after_delete_layer)) {
	Hooks::get_hooks($hook)->add
		(sub {
		     $reorder_elems->();
		     $bbl->add(@elem);
		 }, $bblpath);
    }
    $bbl->OnDestroy
	(sub {
	     # Maybe something was deleted/added, so call the hooks
	     for my $hook (qw(after_new_layer after_delete_layer)) {
		 Hooks::get_hooks($hook)->execute_except($bblpath);
	     }
	     # Finally delete
	     for my $hook (qw(after_new_layer after_delete_layer)) {
		 Hooks::get_hooks($hook)->del($bblpath);
	     }
	 });
}

# Funktionen für Darstellung einer berlinmap-Karte
# XXX mehr in eval einklammern
### AutoLoad Sub
sub BBBikeHeavy::getmap {
    my($x, $y, $type, %args) = @_;
    if (!defined $x) {
	my($px, $py) = $c->pointerxy;
	$px -= $c->rootx;
	$py -= $c->rooty;
	($x, $y) = ($c->canvasx($px), $c->canvasy($py));
    }
    if ($dont_delete_map && !$args{'-from_check'}) {
	push @map_surround_img, $map_img;
	undef $map_img;
    } else {
	delete_map();
    }

    if (!$map_draw) {
	return;
    }

    my $rotate_cmd = '';
    if (0 && $orientation eq 'portrait') { # XXXXXX
	$rotate_cmd = ' | pnmrotate -noantialias 90 ';
    } elsif ($orientation ne 'landscape') {
	status_message(M"Die Karte kann nur im Landscape-Modus gezeichnet werden.", 'warn');
	$map_draw = 0;
	return;
    }

    if (!defined $type) {
	$type = $map_default_type;
    }

    if (!$args{-fallback} && $use_map_fallback) {
	$args{-fallback} = [ grep { $_ ne $type }
			     "b2002", "b2003", "b2004", "brbmap", "de2002"
			   ];
    }

    my $o = $Karte::map{$type};
    if (!defined $o) {
	$map_draw = 0;
	die Mfmt("Dem Kartentyp %s kann kein Objekt zugeordnet werden", $type);
    }
    my $width  = $o->width;
    my $height = $o->height;
    my $bx1    = $o->x1;
    my $by2    = $o->y2;
    my $toppm  = $o->to_ppm;

    my($mapx, $mapy, $mapxx, $mapyy);
    if ($coord_system eq 'standard') {
	my($tx,$ty);
	if ($type eq 'brbmap' || $type eq 'de2002') { # XXX Check for available resources??? Also valid for other map types???
	    my $c = join(",", anti_transpose($x, $y));
	    local @INC = (@INC, "$FindBin::RealBin/miscsrc");
	    require "convert_berlinmap.pl";
	    my $ret;
	    for my $ref_dist (qw(10000 20000 40000 80000 160000 320000)) {
		$ret = BBBike::Convert::process
		    (-datafromany => "$FindBin::RealBin/misc/gps_correction_all.dat",
		     -refpoint => "$c,$ref_dist",
		     '-reverse',
		     '-nooutput', '-reusemapdata',
		    );
		last if ($ret && $ret->{Count} >= 5);
	    }
	    if ($ret) {
		my $k_obj = Karte::create_obj("Karte::Custom", %$ret);
		my $new_c = join(",", map { int }
				 $o->standard2map
				 ($k_obj->standard2map(split/,/, $c)));
		($tx,$ty) = split /,/, $new_c;
	    }
	} else {
	    ($tx,$ty) = $o->standard2map(anti_transpose($x, $y));
	}
	($mapx, $mapy, $mapxx, $mapyy) = $o->coord($tx, $ty);
    } elsif ($coord_system eq $type) {
	($mapx, $mapy, $mapxx, $mapyy) = $o->coord(anti_transpose($x, $y));
    } else {
	($mapx, $mapy, $mapxx, $mapyy) = $o->coord($coord_system_obj->map2map($o, anti_transpose($x, $y)));
	($bx1,$by2) = ($o->x1/$coord_system_obj->x1,
		       $o->y2/$coord_system_obj->y2);
	status_message("Transformation $coord_system nach $type", 'info');
    }
#    if ($orientation eq 'portrait') {
#	my $swap = $mapxx;
#	$mapxx = $mapyy;
#	$mapyy = $swap;
#    }

#warn "x,y=$x, $y; anti_transpose=" . anti_transpose($x, $y)."mapx/y=($mapx, $mapy, $mapxx, $mapyy)";

    # XXX da berlinmap-Koordinaten gegenüber den Standard-Koordinaten (Hafas)
    # gedreht sind, stimmt die Karte mit den Vektoren an den Rändern
    # nicht mehr überein.
    my($newwidth, $newheight);
    my($deltax, $deltay);
    {
	my($xx, $yy); # Zuweisung weiter oben machen XXX
	if ($coord_system eq 'standard' ||
	    ($coord_system ne $type)) {
	    ($xx, $yy) = ($bx1, $by2);
	} else {
	    ($xx, $yy) = (1, 1);
	}
	my($x0, $y0, $x1, $y1, $xd, $yd) =
	  (transpose(0, 0),
	   transpose($width  * $xx,
		     $height * $yy),
	   transpose($mapxx * $xx,
		     $mapyy * $yy),
	  );
	($newwidth, $newheight) = map { int } (abs($x1-$x0), abs($y1-$y0));
	($deltax, $deltay)      = (abs($xd-$x0), abs($yd-$y0));
    }

    my $filename = get_file_or_url($o, $mapx, $mapy);

## XXX geht nicht :(
#     # Hack: lieber XPM statt GIF verwenden, weil schneller und 8bit
#     if ($filename =~ m|^(.*map)/(...)\.gif$|) {
# 	my($dir, $coord) = ($1, $2);
# 	my $xpmfile = $dir . "_xpm/$coord.xpm.gz";
# 	if (-f $xpmfile) {
# 	    require Tk::Pixmap;
# 	    $filename = "$tmpdir/$coord.xpm";
# 	    system("zcat $xpmfile > $filename");
# 	    $tmpfiles{$filename}++;
# 	    $toppm = "xpmtoppm";
# 	}
#     }

    my $tmpfile;
    if (! -r $filename || ! -f $filename) {
	warn "Map $filename non-existent!\n";

	if ($devel_host) {
	    if ($type eq 'brbmap' && -d "$FindBin::RealBin/misc") {
		eval q{
		       use DB_File;
		       use Fcntl;
		       my %gismap;
		       tie %gismap, 'DB_File', "$FindBin::RealBin/misc/gismap_missing",
		       O_CREAT|O_RDWR, 0644, $DB_HASH;
		       $gismap{$filename}++;
		       untie %gismap;
		      };
	    }
	    warn __LINE__ . ": $@" if $@;
	}

	if ($args{-fallback} && @{ $args{-fallback} }) {
	    my $new_type = shift @{ $args{-fallback} };
	    warn "Try fallback type $new_type...\n";
	    return getmap($x, $y, $new_type, %args);
	}

	if ($devel_host) {
	    $c->createRectangle($x-$deltax, $y-$deltay,
				$x+$newwidth-$deltax, $y+$newheight-$deltay,
				-fill => 'white',
				-outline => 'red', -tags => 'map');
	    if ($o->can("coord_from_filename")) {
		my $ci = $o->coord_from_filename($filename);
		if (defined $ci) {
		    $c->createText($x+$newwidth/2-$deltax,
				   $y+$newheight/2-$deltay,
				   -anchor => 'c',
				   -text => $ci,
				   -font => $font{tiny},
				   -tags => 'map');
		}
	    }
	}
	restack_delayed();
	if (0 && $type ne 'brbmap' && $map_default_type ne 'brbmap') { # XXXX ("0 &&")
	    getmap($x, $y, 'brbmap', -recursive => 1);
	} elsif ($type ne 'berlinmap' && $map_default_type ne 'berlinmap') {
#	    getmap($x, $y, 'berlinmap', -recursive => 1);
	} else {
	    $top->bell;
	    status_message(Mfmt("Die Datei <%s> existiert nicht.", $filename),
			   'warn');
	    $map_draw = 0;
	}
	# XXX what about map_surround?
	goto CLEANUP;
    }
    $tmpfile = "$tmpdir/bbbikemap.$$";

    my $too_big = sub {
	if ($newwidth > 1400 || $newheight > 1000) {
	    status_message("Die Karte zu groß ($newwidth x $newheight) und wird nicht angezeigt", "info");
	    return 1;
	}
	0;
    };

    my $convert_image = sub {
	my($filename, $nofail) = @_;
	my $map_img;
	if ($newwidth  != $width ||
	    $newheight != $height ||
	    $rotate_cmd ne '' ||
	    $map_color =~ /^(mono|pixmap|gray)$/
	   ) {
	    return if $too_big->();
	    my $cmd;
	    $cmd = "$toppm $filename " .
	      $rotate_cmd .
		" | pnmscale -xsize $newwidth -ysize $newheight ";
	    if ($map_color eq 'color') {
		$cmd .= " > $tmpfile";
	    } elsif ($map_color eq 'gray') {
		$cmd .= " | ppmtopgm | ppmtobmp > $tmpfile";
	    } elsif ($map_color eq 'pixmap') {
		$cmd .= " | ppmquant 256 | ppmtoxpm > $tmpfile";
	    } elsif ($map_color eq 'mono') {
		$cmd .= " | ppmtopgm | pgmtopbm -floyd | pbmtoxbm > $tmpfile";
	    } else { die }
	    warn "Doing system <$cmd>\n" if $verbose;
	    system($cmd);
	    if ($?) {
		return undef if $nofail;
		status_message(Mfmt("Die Karte <%s> kann nicht mit " .
				    "<%s> und <pnmscale> " .
				    "konvertiert werden.", $filename, $toppm),
			       'warn');
		$map_draw = 0;
		goto CLEANUP;
	    }
	    eval {
		$map_img = image_from_file($top, $tmpfile,
					   -colormode => $map_color,
					   -mimetype => "image/x-ppm");
	    };
	    warn $@ if $@;
	} else {
	    eval {
		$map_img = image_from_file($top, $filename,
					   -colormode => $map_color,
					   -mimetype => $o->mimetype);
	    };
	    warn $@ if $@;
	}
	$map_img;
    };

    status_message("");
    $progress->Init; # (-dependents => $c);

    IncBusy($top);
    eval {
	eval {
	    die "map_color=$map_color rotate_cmd=$rotate_cmd"
	      if $map_color ne 'color' or $rotate_cmd ne '';
	    die "newwidth=$newwidth width=$width " .
	      "newheight=$newheight height=$height"
		if $newwidth == $width and $newheight == $height;
	    die "too big" if $too_big->();
	    require GfxConvert;
	    GfxConvert::transform_image($filename, $tmpfile,
					-in_mime => $o->mimetype,
					-out_mime => $o->mimetype,
					-width => $newwidth,
					-height => $newheight);
	    if ($o->mimetype eq 'image/png') {
		require Tk::PNG;
	    } elsif ($o->mimetype eq 'image/jpeg') {
		require Tk::JPEG;
	    } elsif ($o->mimetype eq 'image/tiff') {
		require Tk::TIFF;
	    }
	    $map_img = $top->Photo(-file => $tmpfile);
	};
	warn __LINE__ . ": $@" if $@ and $verbose;
	if ($@ || !defined $map_img) {
	    $map_img = $convert_image->($filename);
	}
	if (!defined $map_img && $@ !~ /too big/) {
	    status_message($@, 'warn');
	    $map_draw = 0;
	    return;
	}
	if ($verbose) {
	    warn "Create image $map_img at (", $x-$deltax, "/", $y-$deltay,
		 ") with anchor nw";
	}
	$c->createImage($x-$deltax, $y-$deltay,
			-image => $map_img,
			-anchor => 'nw', -tags => ['map']);

	if ($map_surround && !$o->noenvironment) {
	    $escape = 0;
	    my $progress_count = 1;
	LOOP: foreach my $ix (-1 .. 1) {
		foreach my $iy (-1 .. 1) {
		    next if $ix == 0 and $iy == 0;
		    $progress->Update($progress_count/9); $progress_count++;
		    last LOOP if ($escape);
		    my $filename = get_file_or_url($o,
						   $o->incx($mapx, $ix),
						   $o->incy($mapy, $iy));
		    next if ! -r $filename || ! -f $filename;
		    my $img = $convert_image->($filename, 'nofail');
		    next if !defined $img;
		    $c->createImage($x-$deltax+($ix*$newwidth),
				    $y-$deltay+($iy*$newheight),
				    -image => $img,
				    -anchor => 'nw', -tags => ['map']);
		    push @map_surround_img, $img;
		}
	    }
	}

	restack_delayed();
    };
  CLEANUP:
    unlink($tmpfile) if defined $tmpfile;
    $progress->Finish;
    DecBusy($top);
}

### AutoLoad Sub
sub BBBikeHeavy::get_file_or_url {
    my($o, $mapx, $mapy) = @_;
    my $filename;
  TRY: {
      TRYCACHE: {
	    # Cachefile verwenden, falls gewünscht und möglich
	    if ($use_wwwcache && $o->can('cache')) {
		my $tmpfile = $o->cache($mapx, $mapy, 0);
		# $tmpfile löschen? XXX überprüfen!
		if (-f $tmpfile) {
		    $filename = $tmpfile;
		    last TRY; # Erfolg
		}
	    }
	}

	  my $get_by_lwp = sub {
	      if ($do_wwwmap && $o->can('url')) {
		  my $ua = get_user_agent();
		  if (!$ua) {
		      return; # kein Erfolg
		  }
		  my $res;
		  my $tmpurlfile;
		  my $content = "";
		  my $get_content = sub {
		      my($chunk, $res, $prot) = @_;
		      $top->update;
		      die "Aborted" if ($escape);
		      $content .= $chunk;
		  };
		  my $req_url = $o->url($mapx, $mapy);
		  return 0 if !defined $req_url;

		  IncBusy($top);
		  eval {
		      my $req = HTTP::Request->new('GET', $req_url);
		      $tmpurlfile = "$tmpdir/bbbike_url.$$";
		      print STDERR
			  Mfmt("Die URL <%s> wird geholt (LWP) ... ",
			       $req->url);
		      $escape = 0;
		      $res = $ua->request($req, $get_content, 1024);
		  };
		  DecBusy($top);

		  if (!defined $res || !$res->is_success || $content eq '') {
		      if (!$res) {
			  status_message(Mfmt("Keine Antwort von %s",
					      $req_url));
		      } else {
			  status_message($res->as_string);
		      }
		      return; # kein Erfolg
		  } else {
		      if (!open(TMP, ">$tmpurlfile")) {
			  status_message
			      (Mfmt("Kann auf %s nicht schreiben: %s",
				    $tmpurlfile, $!));
			  return;
		      }
		      binmode TMP;
		      print TMP $content;
		      close TMP;
		  }
		  print STDERR "OK\n";
		  $filename = $tmpurlfile;
		  $tmpfiles{$tmpurlfile}++;
		  # Cachefile erstellen
		  if ($use_wwwcache && $o->can('cache')) {
		      my $cachefile = $o->cache($mapx, $mapy, 1);
		      if ($cachefile) {
			  copy($filename, $cachefile);
		      }
		  }
		  return 1;
	      }
	      return 0;
	  };

	  # XXX %tk_widget-Lösung funktioniert nicht optimal
	  # besser mit fork, auch unter Win32, arbeiten!
	  # (aber zunächst unter win98 und winnt austesten!)
	  my $get_by_http_pm = sub {
	      if ($do_wwwmap && $o->can('url')) {
		  eval { require Http };
		  if ($@) {
		      status_message($@, 'warn') if $verbose;
		      return; # wirklich kein Erfolg
		  }
		  local $Http::tk_widget = $top;
		  local $Http::timeout = 4;
		  local $Http::user_agent = ["Mozilla/4.78 [de] (WinNT; U)",
					     "Mozilla/4.75 [de] (Win98)",
					     "Mozilla/4.77 (Win95)",
					    ]->[rand(3)];
		  my %res;
		  my $tmpurlfile;

		  my $requrl = $o->url($mapx, $mapy);
		  return 0 if !defined $requrl;

		  # Popping up transient toplevels are bugging ---
		  # therefore a place()d frame is used.
		  my $abort_w = $top->Frame->place(-relx => 0.5, -rely => 0.5);
		  $abort_w->Button(-text => M"Abort WWW",
				   -command => sub {
				       $abortWWW = -1;
				   })->pack;

		  IncBusy($top);
		  eval {

		      $abort_w->raise if $abort_w; # over InputO widget

		      $tmpurlfile = "$tmpdir/bbbike_url.$$";
		      open(WWW, ">$tmpurlfile") or
			  die Mfmt("Kann auf die Datei %s nicht schreiben: %s", $tmpurlfile, $!);
		      binmode WWW;
		      print STDERR
			  Mfmt("Die URL <%s> wird geholt (Http.pm) ... ",
			       $requrl);
		      $abortWWW = 0;
		      %res = Http::get("url" => $requrl,
				       ($proxy ? ("proxy" => $proxy) : ()),
				       "debug" => $verbose,
				       "waitVariable" => \$abortWWW,
				      );
		      if ($res{"error"} == 200 && $abortWWW != -1) {
			  print WWW $res{"content"};
		      }
		      close WWW;
		  };
		  DecBusy($top);

		  $abort_w->destroy if $abort_w && Tk::Exists($abort_w);

		  if ($res{"error"} != 200) {
		      status_message(Mfmt("Fehler beim Holen der URL %s",
					  $requrl));
		      return; # kein Erfolg
		  }
		  if ($abortWWW == -1) {
		      status_message(Mfmt("Benutzerabbruch beim Holen der URL %s",
					  $requrl));
		      return; # kein Erfolg
		  }
		  print STDERR "OK\n";
		  $filename = $tmpurlfile;
		  $tmpfiles{$tmpurlfile}++;
		  # Cachefile erstellen
		  if ($use_wwwcache && $o->can('cache')) {
		      my $cachefile = $o->cache($mapx, $mapy, 1);
		      if ($cachefile) {
			  copy($filename, $cachefile);
		      }
		  }
		  return 1;
	      }
	      return 0;
	  };

	  if (!$get_by_http_pm->()) {
	      undef $filename; # sicherheitshalber
	      status_message(M"Fehler bei der WWW-Verbindung");
	  }
## Http.pm has better Tk support than LWP::UserAgent
#  	      ||
#  	  $get_by_lwp->()
#  	      ;
    }
    if (!defined $filename) {
	$filename = $o->filename($mapx, $mapy);
    }
    $filename;
}

### AutoLoad Sub
sub BBBikeHeavy::get_user_agent {
    return $ua if defined $ua;
    eval { require LWP::UserAgent };
    return undef if $@;
    $ua = LWP::UserAgent->new;
    $ua->agent("$progname/$VERSION");
    $ua->timeout(30);
    $ua->env_proxy;
    if ($os eq 'win' && eval { require Win32Util; 1 }) {
	Win32Util::lwp_auto_proxy($ua);
    }
    if ($proxy) {
	$ua->proxy(['http','ftp'], $proxy);
    }
    $ua;
}

### AutoLoad Sub
sub BBBikeHeavy::delete_map {
    $c->delete('map');
    if (defined $map_img) {
	eval { $map_img->delete };
	undef $map_img;
    }
    if (@map_surround_img) {
	foreach (@map_surround_img) {
	    eval { $_->delete }; # möglicherweise nicht mehr vorhanden
	}
	undef @map_surround_img;
    }
}

# Gibt eine Meldung aus, wie Module nachinstalliert werden können.
### AutoLoad Sub
sub BBBikeHeavy::perlmod_install_advice {
    my(@mod) = @_;
    @mod = grep { !exists $perlmod_install_advice_seen{$_} } @mod;
    return if !@mod;
    $perlmod_install_advice_seen{$_}++ for (@mod);
    if ($auto_install_cpan) {
	require AutoInstall::Tk;
	my $r = AutoInstall::Tk::do_autoinstall_tk(@mod);
	if ($r > 0) {
	    for my $mod (@mod) {
		warn "Re-require $mod...\n";
		eval "require $mod";
		die __LINE__ . ": $@" if $@;
	    }
	}
    } else {
	my $shell = ($os eq 'win' ? M"Eingabeaufforderung" : M"Shell");
	my $command = "";
	my $gui_command = "";
	if ($os eq 'win') {
	    $command =
		"    ppm\n" .
		"    " . join("\n    ", map { "install $_" } @mod) . "\n" .
		"    quit\n";
	    require Config;
	    # Guess recent ActivePerl
	    if ($] >= 5.008008 && $Config::Config{cf_email} =~ m{activestate}i) {
		$gui_command = M("Alternativ kann der GUI-Paketmanager kann im Start-Menü unter Programme > ActivePerl > Perl Package Manager verwendet werden.\n")
	    }
	} else {
	    if ($^O eq 'freebsd') {
		my @pkg;
		foreach my $perlname (@mod) {
		    my $pkgname = "p5-" . $perlname;
		    $pkgname =~ s/::/-/g;
		    push @pkg, $pkgname;
		}
		$command = "    pkg_add -r @pkg\n";
		$command .= M("oder")."\n";
	    } elsif (-f '/etc/apt/sources.list') {
		my @deb;
		foreach my $perlname (@mod) {
		    # code taken from debian's /usr/bin/dh-make-perl:
		    my $pkgname = lc $perlname;
		    $pkgname =~ s/::/-/;
		    $pkgname = 'lib'.$pkgname unless $pkgname =~ /^lib/;
		    $pkgname .= '-perl' unless ($pkgname =~ /-perl$/);
		    # ensure policy compliant names and versions (from Joeyh)...
		    $pkgname =~ s/[^-.+a-zA-Z0-9]+/-/g;
		    push (@deb, $pkgname);
		}
		$command = "    apt-get install @deb\n";
		$command .= M("oder")."\n";
	    }
	    $command .= "    $^X -MCPAN -e \"install " . join(", ", @mod) . "\"\n";
	}
	status_message
	    (
	     Mfmt((@mod > 1
		   ? "Die fehlenden Perl-Module können aus der %s mit dem Kommando\n"
		   : "Das fehlende Perl-Modul kann aus der %s mit dem Kommando\n"), $shell) .
	     $command .
	     M"aus dem Internet geholt und installiert werden.\n" .
	     ($gui_command ? "\n$gui_command" : ""),
	     "err");
	0;
    }
}

### AutoLoad Sub
sub BBBikeHeavy::pdf_export {
    my(%args) = @_;

    # XXX A better solution would be some kind of "can_handle_imagetype"
    # method in BBBikeDraw.pm. This would return false and a list of
    # all missing modules, or "true" if everything's ok
    if (!eval { require PDF::Create; 1 }) {
	status_message("PDF::Create is not available", "warn");
	# XXX This is not exactly true --- the necessary PDF::Create
	# version is only available at sourceforge
	perlmod_install_advice("PDF::Create");
	return 1;
    }

    $args{-ext} = ".pdf";
    $args{-imagetype} = "pdf";
    BBBikeHeavy::any_bbbikedraw_export(%args);
}

### AutoLoad Sub
sub BBBikeHeavy::svg_export {
    my(%args) = @_;

    # XXX see above
    if (!eval { require SVG; 1 }) {
	status_message("SVG is not available", "warn");
	perlmod_install_advice("SVG");
	return 1;
    }

    $args{-ext} = ".svg";
    $args{-imagetype} = "svg";
    BBBikeHeavy::any_bbbikedraw_export(%args);
}



# any export via BBBikeDraw
# Return true on success
### AutoLoad Sub
sub BBBikeHeavy::any_bbbikedraw_export {
    my(%args) = @_;
    my $use_visible_map = $args{-visiblemap} || !@realcoords;
    my $file = $args{-file} || $top->getSaveFile(-defaultextension => $args{'-ext'});
    my $geometry = $args{-geometry} || "auto";
    return unless defined $file;
    require BBBikeDraw;
    open(OUT, ">$file") or
	status_message
	    (Mfmt("Kann auf %s nicht schreiben: %s",
		  $file, $!));

    my $scope = 'city';
    if ($str_file{'l'}) {
	if ($str_far_away{'l'}) {
	    $scope = 'wideregion';
	} else {
	    # XXX str_regions (Sachsen-Anhalt etc.)???
	    $scope = 'region';
	}
    }

    my @draw = ('title');
    push @draw, 'ampel' if ($p_draw{'lsa'});
    push @draw, 'berlin' if ($p_draw{'g'});
    push @draw, 'potsdam' if ($p_draw{'gP'});
    push @draw, 'deutschland' if ($p_draw{'gD'});
    push @draw, 'wasser' if ($str_draw{'w'});
    push @draw, 'flaechen' if ($str_draw{'f'});
    push @draw, 'ubahn' if ($str_draw{'u'});
    push @draw, 'sbahn' if ($str_draw{'b'});
    push @draw, 'rbahn' if ($str_draw{'r'});
    push @draw, 'str' if ($str_draw{'s'});
    push @draw, 'ort' if ($p_draw{'o'});
    push @draw, 'wind';
    push @draw, 'strname' if ($str_name_draw{'s'});
    push @draw, 'ubahnname' if ($str_name_draw{'u'});
    push @draw, 'sbahnname' if ($str_name_draw{'s'});

    IncBusy($top);
    eval {
	my $draw = BBBikeDraw->new
	    (ImageType => $args{-imagetype},
	     Module => $args{-module},
	     Coords => [map { join ",", @$_ } @realcoords],
	     Fh => \*OUT,
	     Scope => $scope,
	     Geometry => $geometry, # landscape or portrait
	     Draw => [@draw],
	     NoInit => 1,
	     ($net ? (MakeNet => sub { $net }) : ()),
	    );
	if ($use_visible_map) {
	    # use visible map for bounding box
	    my($minx,$miny,$maxx,$maxy) = $c->get_corners;
	    ($minx,$miny) = anti_transpose($minx,$miny);
	    ($maxx,$maxy) = anti_transpose($maxx,$maxy);
	    $draw->set_bbox($minx,$miny,$maxx,$maxy);
	    $draw->init;
	    $draw->create_transpose;
	} else {
	    # else use bounding box of route
	    $draw->init;
	    $draw->pre_draw;
	}
	$draw->draw_map if $draw->can("draw_map");
	if (@realcoords) {
	    $draw->draw_route if $draw->can("draw_route");
	    if ($net && $draw->can("add_route_descr")) {
		$draw->add_route_descr(-net => $net)
	    }
	}
	$draw->flush;
    };
    my $err = $@;
    DecBusy($top);
    close OUT;
    if ($err) {
	unlink $file;
	status_message(Mfmt("Die %s-Datei konnte nicht erstellt werden. Grund: %s", $args{-imagetype}, $err), "err");
	return 0;
    } else {
	return 1;
    }
}

######################################################################
# Zeigt den Dialog mit den Routen-Registern an.
### AutoLoad Sub
sub BBBikeHeavy::show_register {
    my $t = redisplay_top($top, M"Register",
			  -title => M"Routen-Register");
    return if !defined $t;

    $top->Advertise(RegisterWindow => $t);

    $t->protocol('WM_DELETE_WINDOW', sub { $t->withdraw });

    $t->Label(-text => M("Abspeichern").":")->grid(-row => 0,
						   -column => 0,
						   -sticky => 'w');
    $t->Label(-text => M("Anzeigen").":")->grid(-row => 1,
						-column => 0,
						-sticky => 'w');
    $t->Checkbutton(-text => M("Karte zentrieren"),
		    -variable => \$register_window_adjust)
	->grid(-row => 2, -column => 0, -sticky => "w", -columnspan => 2);
    my $sf = $t->Frame->grid(-row => 0, -column => 1,
			     -sticky => 'w');
    my $rf = $t->Frame->grid(-row => 1, -column => 1,
			     -sticky => 'w');

    if ($advanced) {
	# XXX there are still some issues (see below)
	$t->Button(-text => M("In Datei speichern"),
		   -command => \&save_register_routes,
		  )->grid(-row => 0,
			  -column => 2,
			  -sticky => 'we');
	$t->Button(-text => M("Von Datei laden"),
		   -command => \&load_register_routes,
		  )->grid(-row => 1,
			  -column => 2,
			  -sticky => 'we');
    }

    my @ret_b;
    foreach my $i (0 .. 9) {
	my $ii = $i;
	my $text = (!$ii ? M"Undo" : $ii);
	my $b;
	$b = $sf->Button
	    (-text => $text,
	     -command => sub {
		 if ($save_route{$ii}) {
		     require Tk::Dialog;
		     if ($top->Dialog
			 (-text    => M"Gespeicherte Route ersetzen?",
			  -buttons => [M"Ja", M"Nein"],
			  -default_button => M"Nein",
			 )->Show ne M"Ja") {
			 return;
		     }
		 }
		 save_route_to_register($ii);
		 $ret_b[$ii]->configure(-fg => 'red');
		 $b->configure(-fg => 'red');

		 if ($balloon) {
		     my $text = get_route_description();
		     if ($text ne '') {
			 foreach ($b, $ret_b[$ii]) {
			     $balloon->attach($_, -msg => $text);
			 }
		     }
		 }
	     }
	    )->pack(-side => 'left');
	$ret_b[$i] = $rf->Button
	    (-text => $text,
	     -command => sub {
		 if (get_route_from_register($ii)) {
		     center_whole_route() if $register_window_adjust;
		 } else {
		     $top->messageBox
			 (-title => M"Leeres Register",
			  -text => M"Hier ist keine Route gespeichert.",
			  -icon => 'error',
			  -type => 'Ok');
		 }
	     }
	    )->pack(-side => 'left');
	$t->Advertise("SaveButton_" . $i => $b);
	$t->Advertise("LoadButton_" . $i => $ret_b[$i]);
    }
}

# XXX evtl. croaks on not defined added points in net
# XXX bikepwr values are not valid in new session
# XXX really use .bbrs extension?
### AutoLoad Sub
sub BBBikeHeavy::save_register_routes {
    my $f = $top->getSaveFile(-defaultextension => ".bbrs");
    return unless $f;
    open(F, ">$f") or die Mfmt("Schreiben auf <%s> nicht möglich: %s", $f, $!);
    require Data::Dumper;
    print F Data::Dumper->new([\%save_route], ['*save_route'])->Indent(0)->Dump;
    close F;
}

### AutoLoad Sub
sub BBBikeHeavy::load_register_routes {
    my $f = $top->getOpenFile(-title => M"Register laden",
			      -filetypes => [['Register-Datei' => '.bbrs'],
					     ['Alle Dateien' => '*']],
			     );
    return unless $f;
    require Safe;
    my $s = Safe->new;
    my $reg_t = $top->Subwidget("RegisterWindow");
    if ($reg_t) {
	foreach my $b ($reg_t->Subwidget) {
	    $b->configure(-fg => "black"); # XXX do not hardcode?
	}
    }
    $s->share(qw(%save_route));
    $s->rdo($f);
    if ($reg_t) {
	my $i = 1;
	while(my $b = $reg_t->Subwidget("SaveButton_" . $i)) {
	    if ($save_route{$i}) {
		$b->configure(-fg => "red");
		if (my $b2 = $reg_t->Subwidget("LoadButton_" . $i)) {
		    $b2->configure(-fg => "red");
		}
	    }
	    $i++;
	}
    }
}

######################################################################
### Kalorien-Fenster
### AutoLoad Sub
sub BBBikeHeavy::show_calories {
    if (!$show_calories) {
	if (Tk::Exists($toplevel{Calories})) {
	    $toplevel{Calories}->destroy;
	}
	return;
    }

    my $t = redisplay_top($top, 'Calories',
			  -title => M"Kalorienverbrauch");
    return if !defined $t;
    my $withdraw_sub = sub { $t->destroy;
			     $show_calories = 0 };
    $t->protocol('WM_DELETE_WINDOW', $withdraw_sub);
    $t->Label(-text => M"Kalorienverbrauch")->pack;
    my $f = $t->Frame->pack;
    foreach my $def ([\@power, 'W:', \@calories_power, 'kcal'],
		     #[\@speed, 'km/h:', \@calories_speed, 'kcal'],
		    ) {
	for(my $i=0; $i<=$#power; $i++) {
	    $f->Label(-textvariable => \$def->[0][$i]
		 )->grid(-row => $i, -column => 0, -sticky => 'e');
	    $f->Label(-text => $def->[1]
		     )->grid(-row => $i, -column => 1, -sticky => 'w');
	    $f->Label(-textvariable => \$def->[2][$i]
		     )->grid(-row => $i, -column => 2, -sticky => 'e');
	    $f->Label(-text => $def->[3]
		     )->grid(-row => $i, -column => 3, -sticky => 'w');
	}
    }
}

# This is not executed by default anymore. Somewhere in FreeBSD 2 or
# 3, there used to be a datasize limit by the default login.conf. See
# http://www.freebsd.org/cgi/cvsweb.cgi/src/etc/login.conf for a
# history. This limit was removed in revision 1.21 of this file. I
# don't know of any other OSes with default resource limits.
sub BBBikeHeavy::check_available_memory {
    if ($os eq 'unix') {
	# Check for limited resources.
	my $soft_data;
	eval {
	    local $^W = 0;
	    require BSD::Resource; # can't be autoused
	    ($soft_data) = BSD::Resource::getrlimit(&BSD::Resource::RLIMIT_DATA);
	    $soft_data /= 1024 if $soft_data != -1;
	};
	if ($@ && $^O =~ /bsd/) {
	    # There's a bug in freebsd4.3 limits issuing a warning. Ignore it.
	    open(L, "limits -d|");
	    while (<L>) {
		if (/datasize(?:-cur)?\s+(\d+)/) {
		    $soft_data = $1;
		    last;
		}
	    }
	    close L;
	}
	if (defined $soft_data &&
	    $soft_data != -1 &&
	    $soft_data < MINMEM) {
	    warn
		Mfmt("
Achtung:

 Der frei verfügbare Speicherplatz ist durch resource limits auf %s kB
 eingeschränkt worden. Empfohlen sind %s kB. In der csh/tcsh kann
 man die Einschränkung mit `limit datasize unlimited' aufheben, in der sh/bash
 mit `ulimit -d %s`. Zusätzlich muss man evtl. seine Login-Klasse
 ändern oder die Werte in /etc/login.conf erhöhen.

 Siehe auch limits(1) und login.conf(5).

", $soft_data, MINMEM, MINMEM);
	}
    }
}

### AutoLoad Sub
sub BBBikeHeavy::reload_all {
    my(%args) = @_;

    if ($BBBikeLazy::mode) {
	# XXX files reloaded here are not in @changed_files, so nets cannot be rebuild!
	bbbikelazy_reload();
    }

    my @changed_files;

    my %change;
    foreach my $type (keys %str_obj) {
	my $o = $str_obj{$type};
	next if !$o;
	if (!$o->is_current) {
	    $o->reload;
	    $change{"str"}->{$type} = 1;
	    push @changed_files, $o->dependent_files;
	}
    }
    foreach my $type (keys %p_obj) {
	my $o = $p_obj{$type};
	warn "Should not happen: No object for point type $type", next if !$o;
	if (!$o->is_current) {
	    $o->reload;
	    $change{"p"}->{$type} = 1;
	    push @changed_files, $o->dependent_files;
	}
    }

    # Special handling for hoehe layers
    if ($change{"p"}->{"hoehe"}) {
	read_hoehe(-force => 1);
    }

    $progress->InitGroup;
    while(my($linetype, $v) = each %change) {
	while(my($type, $vv) = each %$v) {
	    if ($verbose) {
		warn "Updating $linetype $type ...\n";
	    }
	    plot($linetype,$type, FastUpdate => 1);
	}
    }
    $progress->FinishGroup;

    # Need to delete comments_net?
    if ($comments_net) {
	if (exists $change{str}->{comm}) {
	    undef $comments_net;
	} else {
	    for my $src ($comments_net->sourceobjects) {
		if (!$src->is_current) {
		    undef $comments_net;
		    last;
		}
	    }
	}
    }

    if (!$edit_mode_flag || $args{force}) { # be fast in edit mode, do not rebuild nets

	my %changed_files = map {($_,1)} @changed_files;

	if ($handicap_s_net) {
	    for my $src ($handicap_s_net->sourcefiles) {
		if (exists $changed_files{$src}) {
		    warn "Need to rebuild handicap net (because of $src)...\n" if $verbose;
		    undef $handicap_s_net;
		    make_handicap_net();
		    last;
		}
	    }
	}

	if ($qualitaet_s_net) {
	    for my $src ($qualitaet_s_net->sourcefiles) {
		if (exists $changed_files{$src}) {
		    warn "Need to rebuild qualitaet net (because of $src)...\n" if $verbose;
		    undef $qualitaet_s_net;
		    make_qualitaet_net();
		    last;
		}
	    }
	}

	my $need_to_rebuild_net = 0;
	if ($net) {
	    for my $net_file ($net->sourcefiles) {
		if (exists $changed_files{$net_file}) {
		    warn "Need to rebuild net (because of $net_file)...\n" if $verbose;
		    $need_to_rebuild_net = 1;
		    last;
		}
	    }
	}
	if ($need_to_rebuild_net) {
	    make_net();
	}
    }
    
}

sub BBBikeHeavy::make_temp {
    my($ext) = @_;
    $ext = "tmp" if !$ext;
    my $tmpfile = "$tmpdir/$progname" . "_" . $$ . ".$ext";
    unlink $tmpfile;
    $tmpfiles{$tmpfile}++;
    $tmpfile;
}

sub BBBikeHeavy::make_unique_temp {
    my($ext) = @_;
    $ext = "tmp" if !$ext;
    my @l = localtime;
    $l[5]+=1900;
    $l[4]++;
    my $date = sprintf "%04d%02d%02dT%02d%02d%02d", @l[5,4,3,2,1,0];
    my $tmpfile = "$tmpdir/$progname" . "_" . $$ . "_" . $date . ".$ext";
    unlink $tmpfile;
    $tmpfiles{$tmpfile}++;
    $tmpfile;
}

sub BBBikeHeavy::save_route_as_gpx {
    my(%args) = @_;
    if (!eval { require Strassen::GPX; 1 }) {
	perlmod_install_advice("XML::LibXML", "XML::Twig");
    } else {
	require Route;
	require Route::Heavy;
	my $file = $top->getSaveFile(-defaultextension => '.gpx');
	return unless defined $file;
	my $tmpfile = "$tmpdir/bbbike-$<-$$.bbr";
	load_save_route(1, $tmpfile);
	my $s = Route::as_strassen($tmpfile,
				   name => "Route",
				   cat => "X",
				   fuzzy => 0,
				  );
	if (!$s) {
	    status_message("Fataler Fehler: $tmpfile lässt sich nicht konvertieren", "die");
	}
	my $s_gpx = Strassen::GPX->new($s);
	my $out = $s_gpx->bbd2gpx(%args);

	open(FH, "> $file") or status_message("Can't write to $file: $!", "die");
	binmode FH;
	print FH $out;
	close FH;

	unlink $tmpfile;
    }
}

sub BBBikeHeavy::save_route_as_kml {
    my(%args) = @_;
    if (!eval { require Strassen::KML; 1 }) {
	perlmod_install_advice("XML::LibXML");
    } else {
	require Route;
	require Route::Heavy;
	my $file = $top->getSaveFile(-defaultextension => '.kml');
	return unless defined $file;
	my $tmpfile = "$tmpdir/bbbike-$<-$$.bbr";
	load_save_route(1, $tmpfile);
	my $route_name = "Route";
	if (@route_strnames) {
	    $route_name = "$route_strnames[0][0] - $route_strnames[-1][0]";
	}
	my $s = Route::as_strassen($tmpfile,
				   name => $route_name,
				   cat => "X",
				   fuzzy => 0,
				  );
	if (!$s) {
	    status_message("Fataler Fehler: $tmpfile lässt sich nicht konvertieren", "die");
	}
	my $s_kml = Strassen::KML->new($s);
	my $out = $s_kml->bbd2kml(%args);

	open(FH, "> $file") or status_message("Can't write to $file: $!", "die");
	binmode FH;
	print FH $out;
	close FH;

	unlink $tmpfile;
    }
}

sub BBBikeHeavy::restart_bbbike_hint {
    my(%args) = @_;
    my $bag = $args{bag} || {};
    return if $bag->{restart_bbbike_hint_seen};
    status_message(M"Einige der geänderten Optionen benötigen einen Neustart von BBBike, um effektiv zu werden.", 'infodlg');
    $bag->{restart_bbbike_hint_seen} = 1;
}

1;

__END__
