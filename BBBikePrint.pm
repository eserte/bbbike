# -*- perl -*-

#
# $Id: BBBikePrint.pm,v 1.18 2003/01/08 19:59:50 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998-2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

use strict;
use vars qw($use_font_rot %str_name_draw $orientation
	    $tmpdir $progname %tmpfiles 
	    $top $balloon %toplevel $c $print_cmd $gv_reuse @gv_old_args
	    $gv_pid $os $verbose %str_color %p_color
	    %str_draw %p_draw %str_attrib %p_attrib %category_attrib
	    %str_outline %category_color %font %line_dash $show_legend);
#$ps_rotate

BEGIN {
    if (!defined &main::M) {
	eval 'sub main::M ($) { @_ }'; warn $@ if $@;
    }
}

sub create_postscript {
    my($c, %args) = @_;
    if ($use_font_rot) {
	foreach (keys %str_name_draw) {
	    # XXX w evtl. auch hereinnehmen
	    if ($_ =~ /^[sl]$/ && $str_name_draw{$_}) {
		# XXX geht mit gepatchtem tk4.2
		status_message(<<EOF, "die");
Karten mit rotierten Zeichensätzen können nicht gedruckt werden.
EOF
            }
	}
    }
    if ($args{-legend}) {
	draw_legend($c, -anchor => ($args{-legend} eq 'right' ? 'ne' : 'nw'));
    }
    $c->update;
    my $tmpfile = "$tmpdir/$progname" . "_$$.ps";
    $tmpfiles{$tmpfile}++;

    my @scaleargs;
    my $dina4_width  = 21.0-2; # 1cm Rand auf jeder Seite lassen
    my $dina4_height = 29.7-2;
    if ($args{-scale_a4}) {
	my $aspect_dina4  = $dina4_width/$dina4_height;
	if ($args{-rotate}) {
	    my $aspect_canvas = $c->Height/$c->Width;
	    if ($aspect_canvas < $aspect_dina4) {
		@scaleargs = (-pagewidth  => $dina4_height . "c");
	    } else {
		@scaleargs = (-pageheight => $dina4_width ."c");
	    }
	} else {
	    my $aspect_canvas = $c->Width/$c->Height;
	    if ($aspect_canvas > $aspect_dina4) {
		@scaleargs = (-pagewidth  => $dina4_width . "c");
	    } else {
		@scaleargs = (-pageheight => $dina4_height . "c");
	    }
	}
    }

    my @ps_args;
    my $write_needed;
    if (!fix_ps_needed()) {
	@ps_args = (-file => $tmpfile);
    } else {
	$write_needed = 1;
    }

    my $is_outline = 0;
 CHECK_OUTLINE: {
	if ($str_draw{'s'}) { last if !$str_outline{'s'} }
	if ($str_draw{'l'}) { last if !$str_outline{'l'} }
	$is_outline = 1;
    }

    my $ps_str = $c->postscript
      (@ps_args,
       # weiß nach hellgrau ummappen (außer, wenn alle Straßen outlined sind)
       ($args{-no_color_map}
	? ()
	: (-colormap => {'grey99' => ($is_outline ? '1 1 1 setrgbcolor' : '0.9 0.9 0.9 setrgbcolor'),
			 'grey85' => '1 1 1 setrgbcolor', # Inseln etc.
			})),
       # XXX rotierte Fonts können nicht umgemapt werden
       # XXX Fontmap für Arial?
       -fontmap =>
       {'-*-nimbus sans-medium-r-condensed--0-120-0-0-p-0-iso8859-1'
	=> ['Helvetica-Narrow', 12],
	'-*-nimbus sans-medium-r-condensed--0-100-0-0-p-0-iso8859-1'
	=> ['Helvetica-Narrow', 10],
	'-*-nimbus sans-medium-r-condensed--0-80-0-0-p-0-iso8859-1'
	=> ['Helvetica-Narrow', 8],
	'-*-nimbus sans-medium-r-condensed--0-70-0-0-p-0-iso8859-1'
	=> ['Helvetica-Narrow', 7],
	'-*-nimbus sans-bold-r-condensed--0-120-0-0-p-0-iso8859-1'
	=> ['Helvetica-Narrow-Bold', 12],
	'-*-nimbus sans-bold-r-condensed--0-100-0-0-p-0-iso8859-1'
	=> ['Helvetica-Narrow-Bold', 10],
	'-*-nimbus sans-bold-r-condensed--0-90-0-0-p-0-iso8859-1'
	=> ['Helvetica-Narrow-Bold', 9],
	'-*-nimbus sans-bold-r-condensed--0-80-0-0-p-0-iso8859-1'
	=> ['Helvetica-Narrow-Bold', 8],
	'6x13bold' => ['Helvetica-Narrow', 7],
	'5x7'      => ['Helvetica-Narrow', 6],
       },
       (defined $args{-colormode} ? (-colormode => $args{-colormode}) : ()),
       (defined $args{-rotate}    ? (-rotate    => $args{-rotate})    : ()),
       @scaleargs,
      );

    if ($write_needed) {
	$ps_str = fix_ps_file($ps_str);
	open(PS, ">$tmpfile") or status_message(Mfmt("Kann %s nicht schreiben: %s", $tmpfile, $!), "die");
	binmode PS;
	print PS $ps_str;
	close PS;
    }

    if ($args{-legend}) {
	clear_legend($c);
    }
    $tmpfile;
}

# Bug mit ->postscript und locale:
#  alle Werte, die mit sprintf "%x.yf" erzeugt wurden, haben mit europäischen
#  Locales ein Komma statt des Dezimalpunktes!
sub fix_ps_needed {
    if ($os eq 'win' && $Tk::VERSION >= 800) {
	# XXX check for LANG/locale???
	1;
    } else {
	# XXX der gleiche Fehler mit Linux?
	0;
    }
}

sub fix_ps_file {
    my $s = shift;
    $s =~ s/(?<=\d),(?=\d)/./gs;
    $s;
}

sub do_print_cmd {
    my $file = shift;
    my $t = $top->Toplevel(-title => 'Drucken');
    require Tk::LabEntry;
    if (!defined $print_cmd or $print_cmd eq '') {
	if ($os eq 'win') {
	    status_messagea("Drucken unter Windows nicht möglich, da kein Ghostscript installiert ist.", "err");
	    return;
	} else {
	    $print_cmd = "lpr";
	}
    }
    my $print_cmd_file = "$print_cmd $file";
    $t->LabEntry(-label => "Druckkommando:",
		 -labelPack => [ -side => 'left' ],
		 -textvariable => \$print_cmd,
		)->pack;
    my $bf = $t->Frame->pack;
    $bf->Button(Name => 'ok',
		-command => sub { system("$print_cmd&");
				  $t->destroy;
			      })->pack(-side => 'left');
    $bf->Button(Name => 'cancel',
		-command => sub { $t->destroy })->pack(-side => 'left');
}

sub print_postscript {
    my($file, %args) = @_;
    return if !defined $file;
    my $quiet = $args{-quiet};
    if (defined $print_cmd and $print_cmd ne '') {
	do_print_cmd($file);
    } elsif (is_in_path("gv") && $os eq 'unix') {
	my @print_args;
	if ($args{'-media'}) {
	    push @print_args, -media => $args{'-media'};
	}
	push @print_args, $file;
	if ($gv_reuse and join(" ", @gv_old_args) eq join(" ", @print_args)) {
	    if (kill 0 => $gv_pid) {
		kill 'HUP' => $gv_pid;
		return;
	    }
	}
	@gv_old_args = @print_args;
	$gv_pid = fork;
	if ($gv_pid == 0) {
	    exec "gv", @print_args;
	    CORE::exit(0);
	}
    } elsif (is_in_path("ghostview")) {
	system("ghostview $file&");
    } elsif (is_in_path("ggv")) {
	system("ggv $file&");
    } elsif ($os eq 'unix') {
	# XXX Tk::Ghostscript funktioniert noch nicht so
	# toll... besser mit gs-5.10 als mit gs-3.53
	# Tk::Ghostview ist in 800.004 nicht mehr vorhanden
	eval {
	    require Tk::Ghostview;
	    my $t = $top->Toplevel;
	    $t->Ghostview(-file => $file)->pack;
	    last TRY;
	};
	if ($@) {
	    if ($quiet) {
		warn $@;
	    } else {
		status_message($@, "err");
	    }
	}
    } elsif ($os eq 'win') {
        require Win32Util;
        if (!Win32Util::start_ps_viewer($file)) {
	    my $msg = "Es wurde kein Postscript-Viewer gefunden.";
	    if ($quiet) {
		warn $msg;
	    } else {
		status_message($msg, "err");
	    }
	    return 0;
        }
	return 1;
    } else {
	do_print_cmd($file);
    }
}

sub print_text_postscript {
    my($text, %args) = @_;
    require Tk::Enscript;
    my $tmpfile = "$tmpdir/$progname" . "_$$.ps";
    unlink $tmpfile;
    $tmpfiles{$tmpfile}++;
    my($out) = Tk::Enscript::enscript
      ($top,
       -external => 'best',
       %args,
       -output => $tmpfile,
       -text => $text,
       -verbose => $verbose);
    print_postscript($out, -quiet => $args{-quiet});
}

######################################################################
# Legende

use vars qw(%legend_photo);

sub draw_legend {
    my $c = shift;
    my %args = @_;

    my $mw = $top;

    require Radwege;

    my $anchor = delete $args{-anchor};
    $anchor = 'nw'    unless defined $anchor;
    my $fill   = delete $args{-fill};
    $fill   = 'white' unless defined $fill;
    my $realcanvas = delete $args{-realcanvas};

    clear_legend($c);
    my($width, $height) = (150, 0); # sane minimum
    my $bg = $c->createRectangle(0, 0, 0, 0,
				 -fill => $fill, -outline => 'blue',
				 -tags => 'legend');
    my $baselineskip = 14;
    eval {
	my $ci = $c->createText(0,0, -text => "");
	my $cf = $c->itemcget($ci, -font);
	$baselineskip = $c->fontMetrics($cf, -linespace);
	$baselineskip *= 1.15; # be nice
	$c->delete($ci);
    }; warn $@ if $@;
    my $start_symbol = 25;
    my $line_length  = 35;
    my $start_text   = $start_symbol + $line_length + 4;
    my $top  = $c->canvasy(10); # XXX handle south
    my($start_width, $left);
    if ($anchor =~ /w$/) {
	$left = $c->canvasx(10);
    } else {
	$start_width = $width;
	$left = $c->canvasx($c->width-10-$start_width);
    }
    my %str_category = ('u' => [qw(UA UB)],
			's' => [qw(HH H N NN)], # XXX BAB
			'r' => [qw(RA RB RC R)],
			'b' => [qw(SA SB SC)],
			'l' => [qw(B HH H N NN)], # XXX BAB
			'w' => 'W',
			'f' => [qw(P F)],
			'v' => 'F', # XXX ???
			'qs' => [qw(Q0 Q1 Q2 Q3)],
			'ql' => [qw(Q0 Q1 Q2 Q3)],
			'hs' => [qw(q0 q1 q2 q3 q4)],
			'hl' => [qw(q0 q1 q2 q3 q4)],
			'rw' => [grep { $_ ne "" } @Radwege::bbbike_category_order],
		       );
    my %attrib = ('str' => \%str_attrib,
		  'p'   => \%p_attrib);

    # adjust value of $width and return an argument list for the canvas
    my $adjust_width = sub {
	my $text = shift;
	my $font = shift;
	my $new_width = $c->fontMeasure($font, $text) + $start_text;
	if ($new_width > $width) {
	    $width = $new_width;
	}
	(-text => $text, -font => $font);
    };

    my $add_binding = sub {
	return unless $realcanvas;
	my $item = shift;
	my $type = shift;
	my $abk = shift;
	my $cat = shift;
	$c->bind($item, "<1>" => sub {
		     my $tag = $abk;
		     if (defined $cat) {
			 $tag .= "-$cat";
		     }
		     my(@items) = $realcanvas->find("withtag", $tag);
		     if (@items) {
			 my @mark_coords;
			 ## alle sind netter, aber auch ressourcenhungriger
			 #foreach my $item (@items) {
			 ## deshalb Beschränkung auf die ersten 10
			 ## XXX besser: nur die Straßen, die gerade sichtbar
			 ## sind, anzeigen lassen XXX
			 my $max_items = ($#items > 10 ? 10 : $#items);
			 foreach my $item (@items[0 .. $max_items]) {
			     my @item_coords;
			     my @coords = $realcanvas->coords($item);
			     for(my $i=0; $i<=$#coords; $i+=2) {
				 push @item_coords,
				      [$coords[$i], $coords[$i+1]];
			     }
			     push @mark_coords, \@item_coords;
			 }
			 if ($type eq 'str') {
			     mark_street(-coords => [@mark_coords]);
			 } else {
			     mark_point(-coords => [@mark_coords]);
			 }
		     } else {
			 status_message(Mfmt("Keine Beispiele für %s gefunden", $tag), "warn");
		     }
		 }
		);
	$c->bind($item, "<Enter>" => sub {
		     $c->configure(-cursor => "hand2");
		 });
	$c->bind($item, "<Leave>" => sub {
		     $c->configure(-cursor => undef);
		 });
	$c->addtag("balloon", "withtag", $item);
    };

    my $lower_symbol = 7;

    my %str_coords;
    foreach my $abk (reverse real_type_stack_order()) {
	next unless $str_draw{$abk};
	# Qualität/Handicap: nur eins von beiden (Landstr/Str.) zeichnen:
	next if (($abk eq 'ql' && $str_draw{'qs'}) ||
		 ($abk eq 'hl' && $str_draw{'hs'}));

	my @dash = ($Tk::VERSION >= 800.016 && exists $line_dash{$abk}
		    ? (-dash => $line_dash{$abk}) : ());

	if (ref $str_category{$abk} eq 'ARRAY') {

	    $height += 3; # Platz über Überschriften lassen

	    $c->createText
		($left+$start_text,
		 $top+$height+8,
		 $adjust_width->($str_attrib{$abk}[1], $font{'bold'}),
		 -anchor => 'w',
		 -tags => 'legend');
	    $height += $baselineskip;

	    foreach my $cat (@{ $str_category{$abk} }) {
		my $width = ($abk eq 'rw' ? 7 : 5); # Sonderregelung für Radwege
		my $item =
		    $c->createLine($left+$start_symbol, $top+$height+$lower_symbol,
				   $left+$start_symbol+$line_length, $top+$height+$lower_symbol,
				   -fill => $category_color{$cat},
				   -width => $width,
				   @dash,
				   -tags => 'legend');
		$add_binding->($item, "str", $abk, $cat);

		if ($abk eq 'rw') {
		    # besondere Darstellung der Radwege
		    my $item =
			$c->createLine($left+$start_symbol, $top+$height+$lower_symbol,
				       $left+$start_symbol+$line_length, $top+$height+$lower_symbol,
				       -fill => "white",
				       -width => $width-4,
				       @dash,
				       -tags => 'legend');
		    $add_binding->($item, "str", $abk, $cat);
		}

		push @{ $str_coords{$abk} },
		    [$left+$start_symbol+$line_length/2, $top+$height+$lower_symbol];

		$c->createText
		    ($left+$start_text, $top+$height+8,
		     $adjust_width->($category_attrib{$cat}[0], $font{'normal'}),
		     -anchor => 'w',
		     -tags => 'legend');
		$height += $baselineskip;
	    }
	} else {

	    # etwas Platz lassen, aber nicht ganz so viel wie bei
	    # echten Überschriften
	    $height += 2;

	    my $color = (defined $category_color{$str_category{$abk}}
			 ? $category_color{$str_category{$abk}}
			 : $str_color{$abk});
	    my $item =
		$c->createLine($left+$start_symbol, $top+$height+$lower_symbol,
			       $left+$start_symbol+$line_length, $top+$height+$lower_symbol,
			       -fill => $color,
			       -width => 5,
			       @dash,
			       -tags => 'legend');
	    $add_binding->($item, "str", $abk);

	    push @{ $str_coords{$abk} },
		[$left+$start_symbol+$line_length/2, $top+$height+$lower_symbol];

	    $c->createText
		($left+$start_text, $top+$height+8,
		 $adjust_width->($str_attrib{$abk}[0], $font{'bold'}),
		 -anchor => 'w',
		 -tags => 'legend');
	    $height += $baselineskip;
	}
    }

    my %p_category = ('u'  => 'U',
		      'r'  => 'R',
		      'b'  => 'S',
		      'p'  => 'U', # XXX falsche Farbe
		      'o'  => 'U', # XXX "
		      'pp' => 'S', # XXX "
		     );
    foreach my $abk (keys %p_draw) {
	next unless $p_draw{$abk};
	my $skip_height_add;
	my($x, $y);
	if ($abk =~ /^[ubr]$/) {
	    my $ubahn_length = ($abk eq 'u'
				? do { my(%a) = get_symbol_scale('u');
				       $a{-width}/2 }
				: 0);
	    my @str_coords;
	    if (exists $str_coords{$abk}) {
		push @str_coords, @{ $str_coords{$abk} };
		$skip_height_add = 1;
	    } else {
		push @str_coords, [$left+$start_symbol, $top+$height];
	    }

	    foreach my $str_coords (@str_coords) {
		($x, $y) = @$str_coords;

		my $item_bg = $c->createLine
		    ($x+4-$ubahn_length, $y+3,
		     $x+4+$ubahn_length, $y+3,
		     -tags => 'legend');
		my $item_fg = $c->createText($x+4, $y+3,
					     -tags => 'legend');
		$add_binding->($item_fg, "p", $abk);

		plot_symbol($c, $abk,
			    -tag_bg => $item_bg, -tag_fg => $item_fg,
			   );
	    }

	} elsif ($abk =~ /^(vf|kn|rest|ki)$/) {
	    # XXX abk xxx und pl fehlen...
	    my $item_fg = $c->createImage($left+$start_symbol, $top+$height+2,
					  -anchor => 'nw',
					  -tags => 'legend');
	    my $bg_or_fg = ($abk eq 'vf' ? "bg" : "fg");
	    $add_binding->($item_fg, "p", $abk, $bg_or_fg);
	    plot_symbol($c, $abk, -tag_fg => $item_fg);
	} elsif ($abk =~ /^lsa$/) {
	    my $ampel_photo = get_symbol_scale('lsa-X');
	    my $item = $c->createImage($left+$start_symbol, $top+$height+2,
				       -anchor => 'nw',
				       -image => $ampel_photo,
				       -tags => 'legend');
	    $add_binding->($item, "p", $abk, "bg");
	    # XXX Bahnübergang
	} elsif ($abk =~ /^hoehe$/) {
	    $c->createLine($left+$start_symbol, $top+$height+2,
			   $left+$start_symbol+1, $top+$height+2+1,
			   -fill => 'red',
			   -tags => 'legend',
			  );
	    $c->createText($left+$start_symbol+1, $top+$height+2+1,
			   -anchor => 'nw',
			   -font => $font{'small'},
			   -text => "35.0",
			   -tags => 'legend',
			  );
	} elsif ($abk =~ /^sperre$/) {

	    $height += 2;
	    # XXX don't hardcode names!
	    my $text = M"gesperrte Straßen";
	    $c->createText
		($left+$start_text, $top+$height+8,
		 $adjust_width->($text, $font{'bold'}),
		 -anchor => 'w',
		 -tags => 'legend');
	    $height += $baselineskip;

	    foreach my $def ([blocked => M"gesperrte Straße"],
			     [oneway => M"Einbahnstraße"],
			     [carry => M"tragen"],
			     [narrowpassage => M"Drängelgitter"]
			    ) {
		my($f, $text) = @$def;
		$legend_photo{$f} = load_photo($mw, "legend_$f.gif") # XXX use $default_img_fmt
		    if !$legend_photo{$f};
		if ($legend_photo{$f}) {
		    $c->createImage($left+$start_symbol, $top+$height,
				    -anchor => "nw",
				    -image => $legend_photo{$f},
				    -tags => 'legend');
		    $c->createText
			($left+$start_text, $top+$height+8,
			 $adjust_width->($text, $font{'normal'}),
			 -anchor => "w",
			 -tags => 'legend');
		    $height += $baselineskip;
		}
	    }
	    $skip_height_add = 1;
	} elsif ($abk =~ /^pp-/) {
	    next;
	} else {
	    my $color = (defined $category_color{$p_category{$abk}}
			 ? $category_color{$p_category{$abk}}
			 : $p_color{$abk});
	    ($x, $y) = ($left+$start_symbol, $top+$height);
	    my $item = $c->createLine($x+4, $y+3,
				      $x+4, $y+3,
				      -fill => $color,
				      -width => 6,
				      -capstyle => 'round',
				      -tags => 'legend');
	    $add_binding->($item, "p", $abk);
	}
	unless ($skip_height_add) {
	    $c->createText
		($left+$start_text, $top+$height+8,
		 $adjust_width->($p_attrib{$abk}[0], $font{'bold'}),
		 -anchor => 'w',
		 -tags => 'legend');
	    $height += $baselineskip;
	}
    }

 DRAW_SCALA: {
	# Skala
	my $y_margin = 30;
	my $color = "black";
	my $bar_width = 4;
	my($x0,$y0) = transpose(0, 0);
	my($x1,$y1, $strecke, $strecke_label);
	for $strecke (100, 500, 1000, 2000, 5000, 10000, 20000, 50000, 100000) {
	    ($x1,$y1) = transpose($strecke, 0);
	    if ($x1-$x0 > 45 && $x1-$x0 < $width) {
		if ($strecke < 1000) {
		    $strecke_label = $strecke . "m";
		} else {
		    $strecke_label = $strecke/1000 . "km";
		}
		last;
	    }
	}
	last DRAW_SCALA if !$strecke_label;

	my $delta_x = $x1-$x0;
	my $begin_x = $left + ($width-$delta_x)/2;
	my $end_x   = $begin_x + $delta_x;

	$c->createRectangle($begin_x,
			    $top+$height+$y_margin,
			    $end_x,
			    $top+$height+$y_margin+$bar_width,
			    -outline => $color,
			    -tags => 'legend');
	$c->createRectangle($begin_x + $delta_x/2,
			    $top+$height+$y_margin,
			    $end_x,
			    $top+$height+$y_margin+$bar_width,
			    -outline => $color,
			    -fill => $color,
			    -tags => 'legend');
	for my $x ($begin_x, $end_x) {
	    $c->createLine($x, $top+$height+$y_margin-2,
			   $x, $top+$height+$y_margin+$bar_width+3,
			   -fill => $color,
			   -tags => 'legend');
	}
	$c->createText($begin_x, $top+$height+$y_margin-2,
		       -anchor => "s",
		       -font => $font{'normal'},
		       -text => "0",
		       -tags => 'legend');
	$c->createText($end_x, $top+$height+$y_margin-2,
		       -anchor => "s",
		       -font => $font{'normal'},
		       -text => $strecke_label,
		       -tags => 'legend');
	$height += $bar_width + $y_margin + 4;
    }

    # Nordpfeil
    $height += 3; # Platz für Unterlängen
    $height = 50 if $height < 50;
    $width += 5;
    $c->coords($bg, $left, $top, $left+$width, $top+$height);
    if ($orientation eq 'landscape') {
	$c->createText($left+2, $top+2,
		       -text => 'N',
		       -anchor => 'nw',
		       -tags => 'legend',
		       -fill => 'blue',
		       -font => $font{'large'},
		       );
	my $arrow_height = 30;
	my $start_arrow_y = 18;
	$c->createPolygon($left+8,  $top+$start_arrow_y,
			  $left+3,  $top+$start_arrow_y+$arrow_height,
			  $left+13, $top+$start_arrow_y+$arrow_height,
			  -fill => 'blue',
			  -outline => 'blue4',
			  -tags => 'legend');
    } else {
	# XXX noch nicht angepasst
	$c->createText($left+7, $top+7,
		       -text => 'N',
		       -tags => 'legend',
		       -fill => 'blue',
		       -font => $font{'large'},
		       );
	$c->createPolygon($left+1, $top+18,
			  $left+13, $top+13, 
			  $left+13, $top+18+18-13,
			  -fill => 'blue',
			  -outline => 'blue4',
			  -tags => 'legend');
    }
    $c->raise('legend');

    if (defined $start_width && $width > $start_width) {
	# adjust position of legend
	$c->move("legend", $start_width-$width, 0);
    }

    ($left, $top, $width, $height); # XXX not clearly specified
}

### AutoLoad Sub
sub clear_legend {
    my $c = shift;
    $c->delete('legend');
}

### AutoLoad Sub
sub show_legend {
    my $parent = shift;
    my %args = @_;
    my $t = redisplay_top($parent, "legend", -title => M"Legende");
    $t = $toplevel{"legend"} if (!defined $t);
    $t->bind("<F1>" => sub { $t->destroy });
    my $c = $t->{Canvas};
    if ($c) {
	clear_legend($c);
    } else {
	# 290: $broadest_line + 100 (ca.)
	$c = $t->Canvas(-height => 550, -width => 290)->pack(-expand => 1,
							     -fill => "both");
	if ($balloon) {
	    $balloon->attach($c, -msg => {"balloon" => "Beispiel mit Klick"});
	}
	$t->{Canvas} = $c;

	# Hook handling
	my $on_hook  = sub { show_legend($parent, %args) };
	my $off_hook = sub {
	    $show_legend = 0;
	    Hooks::get_hooks($_[0])->del("legend");
	};
	foreach my $hook_label (qw(after_plot after_resize)) {
	    Hooks::get_hooks($hook_label)->add($on_hook, "legend");
	    $t->OnDestroy(sub { $off_hook->($hook_label) });
	}
    }
    my($left, $top, $width, $height) =
	draw_legend($c, -fill => 'grey90', %args);
    $t->geometry(int($width+$left*2) . "x" . int($height+$top*2));

}

### AutoLoad Sub
sub toggle_legend {
    if (defined $toplevel{"legend"} and
	Tk::Exists($toplevel{"legend"})) {
	$toplevel{"legend"}->destroy;
    } else {
	show_legend(@_);
    }
}

1;
