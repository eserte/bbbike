# -*- perl -*-

#
# $Id: BBBikeViewImages.pm,v 1.24 2009/03/08 21:49:21 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2005,2007,2008,2009 Slaven Rezic. All rights reserved.
#

# Description (en): View images in bbd files
# Description (de): Bilder in bbd-Dateien anschauen
package BBBikeViewImages;

use BBBikePlugin;
push @ISA, "BBBikePlugin";

use strict;
use vars qw($VERSION $viewer_cursor $viewer $geometry $viewer_menu);
$VERSION = sprintf("%d.%02d", q$Revision: 1.24 $ =~ /(\d+)\.(\d+)/);

use BBBikeUtil qw(file_name_is_absolute is_in_path);
use File::Basename qw(dirname);

my $iso_date_rx = qr{(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})};

$viewer = "_internal" if !defined $viewer;
$geometry = "third" if !defined $geometry;

sub register {
    my $pkg = __PACKAGE__;

    $BBBikePlugin::plugins{$pkg} = $pkg;

    define_cursor();

    add_button();
}

sub define_cursor {
    if (!defined $viewer_cursor) {
	$viewer_cursor = <<EOF;
#define img_ptr_width 40
#define img_ptr_height 16
#define img_ptr_x_hot 3
#define img_ptr_y_hot 1
static unsigned char img_ptr_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00, 0x00, 0x18, 0x00,
   0x00, 0x00, 0x00, 0x38, 0x00, 0x00, 0x00, 0x00, 0x78, 0x80, 0x00, 0x00,
   0x00, 0xf8, 0x80, 0x00, 0x00, 0x00, 0xf8, 0x81, 0x00, 0x00, 0x00, 0xf8,
   0x83, 0x00, 0x00, 0x00, 0xf8, 0x87, 0xb4, 0x38, 0x00, 0xf8, 0x80, 0x6c,
   0x25, 0x00, 0xd8, 0x80, 0x24, 0x25, 0x00, 0x88, 0x81, 0x24, 0x25, 0x00,
   0x80, 0x81, 0x24, 0x39, 0x00, 0x00, 0x03, 0x00, 0x20, 0x00, 0x00, 0x03,
   0x00, 0x24, 0x00, 0x00, 0x00, 0x00, 0x18, 0x00};
EOF
    }
}

sub unregister {
    my $pkg = __PACKAGE__;
    return unless $BBBikePlugin::plugins{$pkg};
    if ($main::map_mode eq $pkg) {
	deactivate();
    }

    my $mf = $main::top->Subwidget("ModePluginFrame");
    my $subw = $mf->Subwidget($pkg . '_on');
    if (Tk::Exists($subw)) { $subw->destroy }

    BBBikePlugin::remove_menu_button($pkg."_menu");

    delete $BBBikePlugin::plugins{$pkg};
}

sub add_button {
    my $mf  = $main::top->Subwidget("ModePluginFrame");
    my $mmf = $main::top->Subwidget("ModeMenuPluginFrame");
    return unless defined $mf;
    my $Radiobutton = $main::Radiobutton;
    my %radio_args =
	(-variable => \$main::map_mode,
	 -value    => 'BBBikeViewImages',
	 -command  => sub {
	     $main::map_mode_deactivate->() if $main::map_mode_deactivate;
	     activate();
	     $main::map_mode_deactivate = \&deactivate;
	 },
	);
    my $b = $mf->$Radiobutton
	(#main::image_or_text($button_image, 'Thunder'),
	 -text => "Img",
	 %radio_args,
	);
    BBBikePlugin::replace_plugin_widget($mf, $b, __PACKAGE__.'_on');
    $main::balloon->attach($b, -msg => "Image Viewer")
	if $main::balloon;

    BBBikePlugin::place_menu_button
	    ($mmf,
	     # XXX Msg.pm
	     [[Radiobutton => "Internen Viewer verwenden",
	       -variable => \$viewer,
	       -value => "_internal",
	       -command => sub { viewer_change() },
	      ],
	      ($^O eq 'MSWin32' ? () :
	       (# xv is not surely not available ...
		[Radiobutton => 'Bester externer Viewer',
		 -variable => \$viewer,
		 -value => '_external',
		 -command => sub { viewer_change() },
		],
		(is_in_path("xv")
		 ? [Radiobutton => "xv",
		    -variable => \$viewer,
		    -value => "xv",
		    -command => sub { viewer_change() },
		   ]
		 : ()
		),
		# ... display might be available, but forking (see below) does not work
		(is_in_path("display")
		 ? [Radiobutton => "ImageMagick (display)",
		    -variable => \$viewer,
		    -value => "display",
		    -command => sub { viewer_change() },
		   ]
		 : ()
		),
		# also usually not available on MSWin32
		(is_in_path("xzgv")
		 ? [Radiobutton => "xzgv",
		    -variable => \$viewer,
		    -value => "xzgv",
		    -command => sub { viewer_change() },
		   ]
		 : ()
		),
	       )
	      ),
	      [Radiobutton => "WWW-Browser",
	       -variable => \$viewer,
	       -value => "_wwwbrowser",
	       -command => sub { viewer_change() },
	      ],
	      "-",
	      [Radiobutton => "Maximale Größe",
	       -variable => \$geometry,
	       -value => "max",
	      ],
	      [Radiobutton => "Ca. halbe Bildschirmgröße",
	       -variable => \$geometry,
	       -value => "half",
	      ],
	      [Radiobutton => "Ca. 1/3 der Bildschirmgröße",
	       -variable => \$geometry,
	       -value => "third",
	      ],
	      [Radiobutton => "Halbe Bildgröße",
	       -variable => \$geometry,
	       -value => "image-half",
	      ],
	      [Radiobutton => "1/3 der Bildgröße",
	       -variable => \$geometry,
	       -value => "image-third",
	      ],
	      "-",
	      [Button => "Dieses Menü löschen",
	       -command => sub {
		   $mmf->after(100, sub {
				   unregister();
			       });
	       }],
	     ],
	     $b,
	     __PACKAGE__."_menu",
	     -title => "View Images",
	     -topmenu => [Radiobutton => 'View Images mode',
			  %radio_args,
			 ],
	    );

    $viewer_menu = $mmf->Subwidget(__PACKAGE__."_menu")->menu;
}

sub viewer_change {
    my $enable;
    if ($viewer eq '_wwwbrowser') {
	$enable = 0;
    } else {
	$enable = 1;
    }
    for my $inx (0 .. $viewer_menu->index("end")) {
	my $varref = eval { $viewer_menu->entrycget($inx, -variable) };
	if ($varref && $varref == \$geometry) {
	    $viewer_menu->entryconfigure($inx, -state => $enable ? "normal" : "disabled");
	}
    }
}

sub activate {
    $main::map_mode = 'BBBikeViewImages';
    main::set_cursor_data($viewer_cursor, "BBBikeViewImages");
    main::status_message("Auf Thumbnails klicken", "info");
}

sub deactivate {
}

sub button {
    my($c, $e) = @_;
    my($current_inx) = $c->find(withtag => "current");
    return 0 if !defined $current_inx;
    my($img_x, $img_y) = $c->coords($current_inx);
    my @all_image_inx = map {
	$_->[1];
    } sort {
	$a->[0] cmp $b->[0];
    } map {
	my(@tags) = $c->gettags($_);
	my($date) = "@tags" =~ $iso_date_rx;
	[$date, $_];
    } grep {
	my(@tags) = $c->gettags($_);
	# Could be tag inx 1 or 2
	grep { /^Image(URL)?:/ } @tags;
	#my $name = $tags[1];
	#$name =~ /^Image:/;
    } $c->find("overlapping",
	       $img_x-10, $img_y-10,
	       $img_x+10, $img_y+10);
    return show_image_viewer(-canvas    => $c,
			     -allimages => \@all_image_inx,
			     -current   => $current_inx,
			    );
}

sub show_image_viewer {
    my(%args) = @_;
    my($c, $all_image_inx, $current_inx) = @args{qw(-canvas
						    -allimages
						    -current)};

    my($name, $abs_file);

    my(@tags) = $c->gettags($current_inx);
    for my $tag_index (1, 2) {
	$name = $tags[$tag_index];
	if ($name =~ /^Image:\s*\"([^\"]+)\"/) {
	    $abs_file = $1;
	    # Hack XXX: force result into bytes for later use:
	    if ($^O ne 'MSWin32' && eval { require Encode; 1 }) {
		$abs_file = Encode::encode("iso-8859-1", $abs_file);
	    }
	    if (!file_name_is_absolute($abs_file)) {
	    SEARCH_FOR_ABS_FILE: {
		    for my $hash (\%main::str_file, \%main::p_file) {
			for my $tag (@tags) {
			    my $str_p_file;
			    if (exists $hash->{$tag}) {
				$str_p_file = $hash->{$tag};
			    } else {
				$tag =~ s{-img}{};
				if (exists $hash->{$tag}) {
				    $str_p_file = $hash->{$tag};
				}
			    }
			    if ($str_p_file) {
				my $try_file = dirname($str_p_file) . "/" . $abs_file;
				if (-r $try_file) {
				    $abs_file = $try_file;
				    last SEARCH_FOR_ABS_FILE;
				}
			    }
			}
		    }
		}
	    }
	} elsif ($name =~ /^ImageURL:\s*(.*)$/) {
	    my $url = $1;
	    require File::Temp;
	    require LWP::UserAgent;
	    my $ua = LWP::UserAgent->new;
	    $ua->agent("BBBike/$main::VERSION (BBBikeViewImages/$VERSION LWP/$LWP::VERSION)");
	    my(undef, $file) = File::Temp::tempfile(UNLINK => 1, SUFFIX => "_BBBikeViewImages");
	    my $resp = $ua->get($url, ':content_file' => $file);
	    if (!$resp->is_success) {
		main::status_message("Kann die URL $url nicht herunterladen: " . $resp->status_line, 'die');
	    }
	    $abs_file = $file; # XXX suffix? aufräumen?
	}
	last if (defined $abs_file)
    }
    if (defined $abs_file) {
	if (!-e $abs_file) {
	    main::status_message("Kann die Datei $abs_file nicht finden", "die");
	}

	my $use_viewer = $viewer;
	if ($viewer eq '_external') {
	    $use_viewer = find_best_external_viewer();
	}

	if ($use_viewer eq '_internal') {
	    main::IncBusy($main::top);
	    eval {
		my($date) = $name =~ $iso_date_rx;
		my($delta) = $name =~ m{\(delta=(\d+:\d+)\)};
		my $image_viewer_toplevel = main::redisplay_top($main::top,
								"BBBikeViewImages_Viewer",
								-raise => 1,
								-transient => 0,
								-title => "Image viewer",
							       );
		if (!defined $image_viewer_toplevel) {
		    $image_viewer_toplevel = $main::toplevel{"BBBikeViewImages_Viewer"};
		} else {
		    # Button bar is unusually at the top. This is to
		    # have the button controls always in the same
		    # place.
		    my $f = $image_viewer_toplevel->Frame->pack(-fill => "x", -side => "top");

		    my $first_button = $f->Button(-class => "SmallBut", -text => "|<")->pack(-side => "left");
		    $image_viewer_toplevel->Advertise(FirstButton => $first_button);
		    $main::balloon->attach($first_button, -msg => "Erstes Bild") if ($main::balloon);

		    my $prev_button = $f->Button(-class => "SmallBut", -text => "<<")->pack(-side => "left");
		    $image_viewer_toplevel->Advertise(PrevButton => $prev_button);
		    $main::balloon->attach($prev_button, -msg => "Vorheriges Bild") if ($main::balloon);

		    my $next_button = $f->Button(-class => "SmallBut", -text => ">>")->pack(-side => "left");
		    $image_viewer_toplevel->Advertise(NextButton => $next_button);
		    $main::balloon->attach($next_button, -msg => "Nächstes Bild") if ($main::balloon);

		    my $last_button = $f->Button(-class => "SmallBut", -text => ">|")->pack(-side => "left");
		    $image_viewer_toplevel->Advertise(LastButton => $last_button);
		    $main::balloon->attach($last_button, -msg => "Letztes Bild") if ($main::balloon);

		    my $n_of_m_label = $f->Label->pack(-side => "left");
		    $image_viewer_toplevel->Advertise(NOfMLabel => $n_of_m_label);

		    my $date_label = $f->Label->pack(-side => "left", -padx => 2);
		    $image_viewer_toplevel->Advertise(DateLabel => $date_label);
		    $main::balloon->attach($date_label, -msg => "Datum aus dem EXIF") if ($main::balloon);

		    my $delta_label = $f->Label->pack(-side => "left");
		    $image_viewer_toplevel->Advertise(DeltaLabel => $delta_label);
		    $main::balloon->attach($delta_label, -msg => "Abstand zur Geolocation (hh:mm)") if ($main::balloon);

		    my $close_button = $f->Button(Name => "close",
						  -class => "SmallBut",
						  -command => sub { $image_viewer_toplevel->destroy },
						 )->pack(-side => "right", -anchor => "e");
		    $main::balloon->attach($close_button, -msg => "Viewer schließen") if ($main::balloon);
		    for my $key (qw(Escape q)) {
			$image_viewer_toplevel->bind("<$key>" => sub { $image_viewer_toplevel->destroy });
		    }

		    my $orig_button = $f->Button(-class => "SmallBut",
						 -text => "Orig",
						)->pack(-side => "right", -anchor => "e");
		    $image_viewer_toplevel->Advertise(OrigButton => $orig_button);
		    $main::balloon->attach($orig_button, -msg => "Originalbild mit ImageMagick zeigen") if ($main::balloon);

		    my $image_viewer_label = $image_viewer_toplevel->Label->pack(-fill => "both", -expand => 1,
										 -side => "bottom");
		    $image_viewer_toplevel->Advertise(ImageLabel => $image_viewer_label);

		    $image_viewer_toplevel->OnDestroy
			(sub {
			     my $p = $image_viewer_toplevel->{"photo"};
			     if ($p) {
				 $p->delete;
			     }
			 });
		}
		my $p = $image_viewer_toplevel->{"photo"};
		if ($p) {
		    $p->delete;
		    $image_viewer_toplevel->{"photo"} = undef;
		}
		$p = main::image_from_file($main::top, $abs_file);
		if (!$p) {
		    die "Kann die Datei $abs_file nicht als Bild interpretieren";
		}
		my $rel_w = $p->width/$main::top->screenwidth;
		my $rel_h = $p->height/$main::top->screenheight;
		my $screen_frac;
		my $subsample;
		if ($geometry eq 'half' && ($rel_w > 0.5 || $rel_h > 0.5)) {
		    $screen_frac = 2;
		} elsif ($geometry eq 'third' && ($rel_w > 0.333 || $rel_h > 0.333)) {
		    $screen_frac = 3;
		} elsif ($geometry eq 'image-half') {
		    $subsample = 2;
		} elsif ($geometry eq 'image-third') {
		    $subsample = 3;
		}
		if ($screen_frac) {
		    my $multi_w = $p->width/($main::top->screenwidth/$screen_frac);
		    my $multi_h = $p->height/($main::top->screenheight/$screen_frac);
		    my $multi = $multi_w > $multi_h ? $multi_w : $multi_h;
		    if ($multi != int($multi)) {
			$multi = int($multi)+1;
		    }
		    $subsample = $multi;
		}
		if ($subsample) {
		    my $new_p = $image_viewer_toplevel->Photo(-width => $p->width/$subsample, -height => $p->height/$subsample);
		    $new_p->copy($p, -subsample => $subsample);
		    $p->delete;
		    $p = $new_p;
		}
		my $image_label_widget = $image_viewer_toplevel->Subwidget("ImageLabel");
		$image_label_widget->configure(-image => $p);
		# Force quadratic toplevel
		if ($p->width > $p->height) {
		    $image_label_widget->packConfigure(-pady => ($p->width - $p->height)/2, -padx => 0);
		} else {
		    $image_label_widget->packConfigure(-padx => ($p->height - $p->width)/2, -pady => 0);
		}

		my $next_image_index = sub {
		    my($dir) = @_;
		    my $new_inx;
		    my $i = -1;
		    for my $inx (@$all_image_inx) {
			$i++;
			if ($inx == $current_inx) {
			    my $ii = $i+$dir;
			    if ($ii >= 0) {
				$new_inx = $all_image_inx->[$ii];
				last;
			    }
			}
		    }
		    $new_inx;
		};

		# Returns 1 .. @$all_image_inx
		my $this_index_in_array = sub {
		    my $i = 0;
		    for my $inx (@$all_image_inx) {
			$i++;
			if ($inx == $current_inx) {
			    return $i;
			}
		    }
		    undef;
		};

		my $prev_inx = $next_image_index->(-1);
		my $next_inx = $next_image_index->(+1);

		my @args     = (-canvas => $c, -allimages => $all_image_inx, '-current');
		my @cmd_args = (\&show_image_viewer, @args);
		# First
		if (@$all_image_inx > 1 && defined $prev_inx) {
		    $image_viewer_toplevel->Subwidget("FirstButton")->configure(-command => [@cmd_args, $all_image_inx->[0]],
										-state => "normal");
		    $image_viewer_toplevel->bind("<Home>" => sub { show_image_viewer(@args, $all_image_inx->[0]) });
		} else {
		    $image_viewer_toplevel->Subwidget("FirstButton")->configure(-state => "disabled");
		    $image_viewer_toplevel->bind("<Home>" => \&Tk::NoOp);
		}
		# Prev
		if (defined $prev_inx) {
		    $image_viewer_toplevel->Subwidget("PrevButton")->configure(-command => [@cmd_args, $prev_inx],
									       -state => "normal");
		    for my $key ('BackSpace', 'b', 'Left') {
			$image_viewer_toplevel->bind("<$key>" => sub { show_image_viewer(@args, $prev_inx) });
		    }
		} else {
		    $image_viewer_toplevel->Subwidget("PrevButton")->configure(-state => "disabled");
		    for my $key ('BackSpace', 'b', 'Left') {
			$image_viewer_toplevel->bind("<$key>" => \&Tk::NoOp);
		    }
		}
		# Next
		if (defined $next_inx) {
		    $image_viewer_toplevel->Subwidget("NextButton")->configure(-command => [@cmd_args, $next_inx],
									       -state => "normal");
		    for my $key ('space', 'Right') {
			$image_viewer_toplevel->bind("<$key>" => sub { show_image_viewer(@args, $next_inx) });
		    }
		} else {
		    $image_viewer_toplevel->Subwidget("NextButton")->configure(-state => "disabled");
		    for my $key ('space', 'Right') {
			$image_viewer_toplevel->bind("<$key>" => \&Tk::NoOp);
		    }
		}
		# Last
		if (@$all_image_inx > 1 && defined $next_inx) {
		    $image_viewer_toplevel->Subwidget("LastButton")->configure(-command => [@cmd_args, $all_image_inx->[-1]],
									       -state => "normal");
		    $image_viewer_toplevel->bind("<End>" => sub { show_image_viewer(@args, $all_image_inx->[-1]) });
		} else {
		    $image_viewer_toplevel->Subwidget("LastButton")->configure(-state => "disabled");
		    $image_viewer_toplevel->bind("<End>" => \&Tk::NoOp);
		}

		# XXX It would be nice if we would show here not only
		# the current image, but all files at this point, the
		# current image being first in list. Unfortunately,
		# look how complicated it is to get to $abs_file :-(
		$image_viewer_toplevel->Subwidget("OrigButton")->configure(-command => [\&orig_viewer, $abs_file]);
		# o=orig, z=zoom (latter matches the binding in xzgv)
		$image_viewer_toplevel->bind("<$_>" => sub { orig_viewer($abs_file) }) for ('o', 'z');

		$image_viewer_toplevel->Subwidget("NOfMLabel")->configure(-text => $this_index_in_array->() . "/" . @$all_image_inx);

		$image_viewer_toplevel->Subwidget("DateLabel")->configure(-text => $date);

		$image_viewer_toplevel->Subwidget("DeltaLabel")->configure(-text => chr(0x0394)."=".$delta);

		$image_viewer_toplevel->{"photo"} = $p;
		$image_viewer_toplevel->deiconify;
		$image_viewer_toplevel->raise;
	    };
	    my $err = $@;
	    main::DecBusy($main::top);
	    if ($err) {
		main::status_message($err, "die");
	    }
	} elsif ($use_viewer eq 'xv') {
	    my @xv_args;
	    if ($geometry eq 'maxpect') {
		push @xv_args, "-maxpect";
	    } elsif ($geometry eq 'half') { # XXX this is really image-half, need impl. for half!
		push @xv_args, "-expand", 0.5;
	    } elsif ($geometry eq 'third') { # XXX this is really image-third, need impl. for third!
		push @xv_args, "-expand", 0.33;
	    } # XXX
	    viewer_xv(@xv_args, $abs_file);
	} elsif ($use_viewer eq 'display') {
	    my @display_args;
	    if ($geometry eq 'maxpect') {
		push @display_args, imagemagick_maxpect_args();
	    } elsif ($geometry eq 'half') {
		push @display_args, "-resize", "50%"; # XXX is this half or image-half?
	    } elsif ($geometry eq 'third') {
		push @display_args, "-resize", "33%"; # XXX is this third or image-third?
	    }
	    viewer_display(@display_args, $abs_file);
	} elsif ($use_viewer eq 'xzgv') {
	    my @xzgv_args;
	    if ($geometry eq 'maxpect') {
		push @xzgv_args, '--zoom', '--zoom-reduce-only', '--fullscreen'; # note that --zoom-reduce-only may not work for some versions of xzgv
	    } elsif ($geometry eq 'half') {
		push @xzgv_args, '--zoom', '--zoom-reduce-only', '--geometry', '50%x50%';
	    } elsif ($geometry eq 'third') {
		push @xzgv_args, '--zoom', '--zoom-reduce-only', '--geometry', '33%x33%';
	    } # XXX need impl. for image-half and image-third
	    viewer_xzgv(@xzgv_args, $abs_file);
	} elsif ($use_viewer eq '_wwwbrowser') {
	    viewer_browser($abs_file);
	} else {
	    my $cmd = "$use_viewer $abs_file";
	    warn "Try $cmd...\n";
	    system("$cmd&");
	}
	return 1;
    } else {
	#require Data::Dumper;
	#main::status_message("Kann kein Bild in <" . Data::Dumper::Dumper(\@tags) . "> finden", "warn");
	return 0;
    }
}

sub viewer_xv {
    my(@args) = @_;
    my @cmd = ("xv", @args);
    main::status_message("@cmd", "info");
    my $pid = fork;
    die if !defined $pid;
    if ($pid == 0) {
	exec @cmd;
	warn $!;
	CORE::exit(1);
    }
}

sub viewer_xzgv {
    my(@args) = @_;
    my @cmd = ("xzgv", @args);
    main::status_message("@cmd", "info");
    my $pid = fork;
    die if !defined $pid;
    if ($pid == 0) {
	exec @cmd;
	warn $!;
	CORE::exit(1);
    }
}

sub viewer_display {
    my(@args) = @_;
    my @cmd = ("display", @args);
    main::status_message("@cmd", "info");
    my $pid = fork;
    die if !defined $pid;
    if ($pid == 0) {
	exec @cmd;
	warn $!;
	CORE::exit(1);
    }
}

sub viewer_browser {
    my($abs_file) = @_;
    require WWWBrowser;
    WWWBrowser::start_browser("file://$abs_file", -oldwindow => 1);
}

sub orig_viewer {
    if ($^O eq 'MSWin32') {
	viewer_browser(@_);
    } elsif (is_in_path("xzgv")) {
	viewer_xzgv('--zoom', '--zoom-reduce-only', '--fullscreen', @_);
    } else {
	viewer_display(imagemagick_maxpect_args(), @_);
    }
}

sub imagemagick_maxpect_args {
    ("-resize", $main::top->screenwidth . "x" . $main::top->screenheight);
}

sub find_best_external_viewer {
    if (is_in_path("xzgv")) { # faster than ImageMagick, free
	"xzgv";
    } elsif (is_in_path("xv")) { # also faster than ImageMagick
	"xv";
    } elsif (is_in_path("display")) {
	"display";
    } else {
	"_internal";
    }
}

1;
