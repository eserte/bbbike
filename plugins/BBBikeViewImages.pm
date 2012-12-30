# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2005,2007,2008,2009,2011,2012 Slaven Rezic. All rights reserved.
#

# Description (en): View images in bbd files
# Description (de): Bilder in bbd-Dateien anschauen
package BBBikeViewImages;

use BBBikePlugin;
push @ISA, "BBBikePlugin";

use strict;
use vars qw($VERSION $viewer_cursor $viewer $original_image_viewer $geometry $viewer_menu $viewer_sizes_menu $exiftool_path);
$VERSION = 1.25;

use BBBikeUtil qw(file_name_is_absolute is_in_path);
use File::Basename qw(dirname);

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

my $iso_date_rx = qr{(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})};

$viewer = "_internal" if !defined $viewer;
$original_image_viewer = ($^O eq 'MSWin32' ? '_wwwbrowser' : 'xzgv') if !defined $original_image_viewer;
$geometry = "third" if !defined $geometry;

my $exif_viewer_toplevel_name = "BBBikeViewImages_ExifViewer";

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
    $main::balloon->attach($b, -msg => M"Bildbetrachter")
	if $main::balloon;

    my %prog_is_available;
    if ($^O ne 'MSWin32') {
	for my $prog (qw(xv display xzgv eog gimp)) {
	    $prog_is_available{$prog} = is_in_path($prog);
	}
    }

    $viewer_sizes_menu = $mmf->Menu
	(-menuitems =>
	 [
	  [Radiobutton => M"Ca. halbe Bildschirmgröße",
	   -variable => \$geometry,
	   -value => "half",
	  ],
	  [Radiobutton => M"Ca. 1/3 der Bildschirmgröße",
	   -variable => \$geometry,
	   -value => "third",
	  ],
	  [Radiobutton => M"Halbe Bildgröße",
	   -variable => \$geometry,
	   -value => "image-half",
	  ],
	  [Radiobutton => M"1/3 der Bildgröße",
	   -variable => \$geometry,
	   -value => "image-third",
	  ],
	  [Radiobutton => M"Maximale Größe",
	   -variable => \$geometry,
	   -value => "max",
	  ],
	 ]
	);

    BBBikePlugin::place_menu_button
	    ($mmf,
	     [[Radiobutton => M"Internen Viewer verwenden",
	       -variable => \$viewer,
	       -value => "_internal",
	       -command => sub { viewer_change() },
	      ],
	      # Some viewers might be available, but forking (see below) does not work on MSWin32...
	      ($^O eq 'MSWin32' ? () :
	       (# xv is not surely not available ...
		[Radiobutton => M"Bester externer Viewer",
		 -variable => \$viewer,
		 -value => '_external',
		 -command => sub { viewer_change() },
		],
		($prog_is_available{"xv"}
		 ? [Radiobutton => "xv",
		    -variable => \$viewer,
		    -value => "xv",
		    -command => sub { viewer_change() },
		   ]
		 : ()
		),
		($prog_is_available{"display"}
		 ? [Radiobutton => "ImageMagick (display)",
		    -variable => \$viewer,
		    -value => "display",
		    -command => sub { viewer_change() },
		   ]
		 : ()
		),
		($prog_is_available{"xzgv"}
		 ? [Radiobutton => "xzgv",
		    -variable => \$viewer,
		    -value => "xzgv",
		    -command => sub { viewer_change() },
		   ]
		 : ()
		),
		($prog_is_available{"eog"}
		 ? [Radiobutton => "Eye of GNOME (eog)",
		    -variable => \$viewer,
		    -value => "eog",
		    -command => sub { viewer_change() },
		   ]
		 : ()
		),
		($prog_is_available{"gimp"}
		 ? [Radiobutton => "GIMP",
		    -variable => \$viewer,
		    -value => "gimp",
		    -command => sub { viewer_change() },
		   ]
		 : ()
		),
	       )
	      ),
	      [Radiobutton => M"WWW-Browser",
	       -variable => \$viewer,
	       -value => "_wwwbrowser",
	       -command => sub { viewer_change() },
	      ],
	      "-",
	      [Cascade => M"Bildgröße",
	       -menu => $viewer_sizes_menu,
	      ],
	      [Cascade => M"Viewer für Originalbild",
	       -menuitems =>
	       [
		($^O eq 'MSWin32' ? () :
		 [Radiobutton => M"Bester externer Viewer",
		  -variable => \$original_image_viewer,
		  -value => '_external',
		 ],
		 ($prog_is_available{'xv'}
		  ? [Radiobutton => 'xv',
		     -variable => \$original_image_viewer,
		     -value => 'xv',
		    ]
		  : ()
		 ),
		 ($prog_is_available{'display'}
		  ? [Radiobutton => 'ImageMagick (display)',
		     -variable => \$original_image_viewer,
		     -value => 'display',
		    ]
		  : ()
		 ),
		 ($prog_is_available{'xzgv'}
		  ? [Radiobutton => 'xzgv',
		     -variable => \$original_image_viewer,
		     -value => 'xzgv',
		    ]
		  : ()
		 ),
		 ($prog_is_available{'eog'}
		  ? [Radiobutton => 'Eye of GNOME (eog)',
		     -variable => \$original_image_viewer,
		     -value => 'eog',
		    ]
		  : ()
		 ),
		 ($prog_is_available{'gimp'}
		  ? [Radiobutton => 'GIMP',
		     -variable => \$original_image_viewer,
		     -value => 'gimp',
		    ]
		  : ()
		 ),
		),
		[Radiobutton => M"WWW-Browser",
		 -variable => \$original_image_viewer,
		 -value => '_wwwbrowser',
		],
	       ],
	      ],
	      "-",
	      [Button => M"Dieses Menü löschen",
	       -command => sub {
		   $mmf->after(100, sub {
				   unregister();
			       });
	       }],
	     ],
	     $b,
	     __PACKAGE__."_menu",
	     -title => M"Bildbetrachter",
	     -topmenu => [Radiobutton => M"Bildbetrachtermodus",
			  %radio_args,
			 ],
	    );

    $viewer_menu = $mmf->Subwidget(__PACKAGE__."_menu")->menu;
}

sub viewer_change {
    my $enable_image_sizes;
    if ($viewer eq '_wwwbrowser' || $viewer eq 'gimp') {
	$enable_image_sizes = 0;
    } else {
	$enable_image_sizes = 1;
    }
    for my $inx (0 .. $viewer_sizes_menu->index("end")) {
	my $varref = eval { $viewer_sizes_menu->entrycget($inx, -variable) };
	if ($varref && $varref == \$geometry) {
	    $viewer_sizes_menu->entryconfigure($inx, -state => $enable_image_sizes ? "normal" : "disabled");
	}
    }
}

sub activate {
    $main::map_mode = 'BBBikeViewImages';
    main::set_cursor_data($viewer_cursor, "BBBikeViewImages");
    main::status_message(M"Auf Thumbnails klicken", "info");
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
		main::status_message(Mfmt("Kann die URL %s nicht herunterladen: %s", $url, $resp->status_line), 'die');
	    }
	    $abs_file = $file; # XXX suffix? aufräumen?
	}
	last if (defined $abs_file)
    }
    if (defined $abs_file) {
	if (!-e $abs_file) {
	    main::status_message(Mfmt("Kann die Datei %s nicht finden", $abs_file), "die");
	}

	my $use_viewer = $viewer;
	if ($viewer eq '_external') {
	    $use_viewer = find_best_external_viewer();
	    $use_viewer = "_internal" if !$use_viewer;
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

		    my $first_button = $f->Button(-class => "SmallBut", -text => "|<", -state => 'disabled')->pack(-side => "left");
		    $image_viewer_toplevel->Advertise(FirstButton => $first_button);
		    $main::balloon->attach($first_button, -msg => M"Erstes Bild") if ($main::balloon);
		    $image_viewer_toplevel->bind("<Home>" => sub { $first_button->invoke });

		    my $prev_button = $f->Button(-class => "SmallBut", -text => "<<", -state => 'disabled')->pack(-side => "left");
		    $image_viewer_toplevel->Advertise(PrevButton => $prev_button);
		    $main::balloon->attach($prev_button, -msg => M"Vorheriges Bild") if ($main::balloon);
		    for my $key ('BackSpace', 'b', 'Left') {
			$image_viewer_toplevel->bind("<$key>" => sub { $prev_button->invoke });
		    }

		    my $next_button = $f->Button(-class => "SmallBut", -text => ">>", -state => 'disabled')->pack(-side => "left");
		    $image_viewer_toplevel->Advertise(NextButton => $next_button);
		    $main::balloon->attach($next_button, -msg => M"Nächstes Bild") if ($main::balloon);
		    for my $key ('space', 'Right') {
			$image_viewer_toplevel->bind("<$key>" => sub { $next_button->invoke });
		    }

		    my $last_button = $f->Button(-class => "SmallBut", -text => ">|", -state => 'disabled')->pack(-side => "left");
		    $image_viewer_toplevel->Advertise(LastButton => $last_button);
		    $main::balloon->attach($last_button, -msg => M"Letztes Bild") if ($main::balloon);
		    $image_viewer_toplevel->bind("<End>" => sub { $last_button->invoke });

		    my $n_of_m_label = $f->Label->pack(-side => "left");
		    $image_viewer_toplevel->Advertise(NOfMLabel => $n_of_m_label);

		    my $date_label = $f->Label->pack(-side => "left", -padx => 2);
		    $image_viewer_toplevel->Advertise(DateLabel => $date_label);
		    $main::balloon->attach($date_label, -msg => M"Datum aus dem EXIF") if ($main::balloon);

		    my $delta_label = $f->Label->pack(-side => "left");
		    $image_viewer_toplevel->Advertise(DeltaLabel => $delta_label);
		    $main::balloon->attach($delta_label, -msg => M"Abstand zur Geolocation (hh:mm)") if ($main::balloon);

		    my $close_button = $f->Button(Name => "close",
						  -class => "SmallBut",
						  -command => sub { $image_viewer_toplevel->destroy },
						 )->pack(-side => "right", -anchor => "e");
		    $main::balloon->attach($close_button, -msg => M"Viewer schließen") if ($main::balloon);
		    for my $key (qw(Escape q)) {
			$image_viewer_toplevel->bind("<$key>" => sub { $close_button->invoke });
		    }

		    my $orig_button = $f->Button(-class => "SmallBut",
						 -text => "Orig",
						)->pack(-side => "right", -anchor => "e");
		    $image_viewer_toplevel->Advertise(OrigButton => $orig_button);
		    $main::balloon->attach($orig_button, -msg => M"Originalbild mit externen Viewer zeigen") if ($main::balloon);
		    # o=orig, z=zoom (latter matches the binding in xzgv), v=view (like in mapivi)
		    $image_viewer_toplevel->bind("<$_>" => sub { $orig_button->invoke }) for ('o', 'v', 'z');

		    my $info_button = $f->Button(-class => "SmallBut",
						 -text => 'i',
						)->pack(-side => "right", -anchor => "e");
		    $image_viewer_toplevel->Advertise(InfoButton => $info_button);
		    $main::balloon->attach($info_button, -msg => M"Bildinformation zeigen") if ($main::balloon);
		    $image_viewer_toplevel->bind('<i>' => sub { $info_button->invoke });

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

		######################################################################
		# next/prev/... button handling

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
		{
		    my $b = $image_viewer_toplevel->Subwidget("FirstButton");
		    if (@$all_image_inx > 1 && defined $prev_inx) {
			$b->configure(-command => [@cmd_args, $all_image_inx->[0]],
				      -state => "normal");
		    } else {
			$b->configure(-state => "disabled");
		    }
		}
		# Prev
		{
		    my $b = $image_viewer_toplevel->Subwidget("PrevButton");
		    if (defined $prev_inx) {
			$b->configure(-command => [@cmd_args, $prev_inx],
				      -state => "normal");
		    } else {
			$b->configure(-state => "disabled");
		    }
		}
		# Next
		{
		    my $b = $image_viewer_toplevel->Subwidget("NextButton");
		    if (defined $next_inx) {
			$b->configure(-command => [@cmd_args, $next_inx],
				       -state => "normal");
		    } else {
			$b->configure(-state => "disabled");
		    }
		}
		# Last
		{
		    my $b = $image_viewer_toplevel->Subwidget("LastButton");
		    if (@$all_image_inx > 1 && defined $next_inx) {
			$b->configure(-command => [@cmd_args, $all_image_inx->[-1]],
				       -state => "normal");
		    } else {
			$b->configure(-state => "disabled");
		    }
		}

		# XXX It would be nice if we would show here not only
		# the current image, but all files at this point, the
		# current image being first in list. Unfortunately,
		# look how complicated it is to get to $abs_file :-(
		$image_viewer_toplevel->Subwidget("OrigButton")->configure(-command => [\&orig_viewer, $abs_file]);

		$image_viewer_toplevel->Subwidget("InfoButton")->configure(-command => [\&exif_viewer, $abs_file]);

		$image_viewer_toplevel->Subwidget("NOfMLabel")->configure(-text => $this_index_in_array->() . "/" . @$all_image_inx);

		$image_viewer_toplevel->Subwidget("DateLabel")->configure(-text => $date);

		$image_viewer_toplevel->Subwidget("DeltaLabel")->configure(-text => chr(0x0394)."=".$delta);

		######################################################################
		# Photo handling
		my $image_label_widget = $image_viewer_toplevel->Subwidget("ImageLabel");
		my $p = $image_viewer_toplevel->{"photo"};
		if ($p) {
		    $p->delete;
		    $image_viewer_toplevel->{"photo"} = undef;
		}
		$p = eval {
		    main::image_from_file($main::top, $abs_file);
		};
		if (!$p) {
		    my $msg = Mfmt("Kann die Datei %s nicht als Bild interpretieren", $abs_file);
		    $image_label_widget->configure(-text => $msg, -image => undef);
		} else {
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
		    # XXX Should check via exif if image is about to be
		    # rotated. If so, then use Tk::PhotoRotate or
		    # something similar
		    $image_label_widget->configure(-text => undef, -image => $p);
		    # Force quadratic toplevel
		    if ($p->width > $p->height) {
			$image_label_widget->packConfigure(-pady => ($p->width - $p->height)/2, -padx => 0);
		    } else {
			$image_label_widget->packConfigure(-padx => ($p->height - $p->width)/2, -pady => 0);
		    }


		    $image_viewer_toplevel->{"photo"} = $p;
		}

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
	} elsif ($use_viewer eq 'eog') {
	    viewer_eog('--disable-image-collection', $abs_file);
	} elsif ($use_viewer eq '_wwwbrowser') {
	    viewer_browser($abs_file);
	} else {
	    my $cmd = "$use_viewer $abs_file";
	    warn "Try $cmd...\n";
	    system("$cmd&");
	}

	fill_exif_viewer_if_active($abs_file);

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
    my @cmd = ("xzgv", "--exif-orient", @args);
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

sub viewer_eog {
    my(@args) = @_;
    my @cmd = ("eog", @args);
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
    my $use_original_image_viewer = $original_image_viewer;
    if ($use_original_image_viewer eq '_external') {
	$use_original_image_viewer = find_best_external_viewer();
	$use_original_image_viewer = '_wwwbrowser' if !$use_original_image_viewer;
    }
    if ($^O eq 'MSWin32' || $use_original_image_viewer eq '_wwwbrowser') {
	viewer_browser(@_);
    } elsif ($use_original_image_viewer eq 'xzgv') {
	viewer_xzgv('--zoom', '--zoom-reduce-only', '--fullscreen', @_);
    } elsif ($use_original_image_viewer eq 'display') {
	viewer_display(imagemagick_maxpect_args(), @_);
    } elsif ($use_original_image_viewer eq 'xv') {
	viewer_xv('-maxpect', @_);
    } else {
	my $cmd = "$use_original_image_viewer @_";
	warn "Try $cmd...\n";
	system("$cmd&");
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
    } elsif (is_in_path("eog")) {
	"eog";
    } else {
	undef;
    }
}

sub exif_viewer {
    my($image_path) = @_;

    _check_exiftool() or return;

    my $exif_toplevel = main::redisplay_top($main::top,
					    $exif_viewer_toplevel_name,
					    -raise => 1,
					    -transient => 0,
					    -title => M"Bildinformation",
					   );
    if (!defined $exif_toplevel) {
	$exif_toplevel = $main::toplevel{$exif_viewer_toplevel_name};
    } else {
	my $pager = $exif_toplevel->Scrolled('ROText',
					     -scrollbars => 'oe',
					     -font => $main::font{'fixed'},
					    )->pack(qw(-fill both -expand 1));
	$pager->focus;
	$exif_toplevel->Advertise(Pager => $pager);

	for my $key (qw(Escape q)) {
	    $exif_toplevel->bind("<$key>" => sub { $exif_toplevel->destroy });
	}
    }

    _fill_exif_viewer($exif_toplevel, $image_path);
}

sub _check_exiftool {
    if (!defined $exiftool_path) {
	$exiftool_path = is_in_path('exiftool');
	if (!$exiftool_path) {
	    $exiftool_path = 0; # remember failure
	    main::perlmod_install_advice('Image::ExifTool');
	    return;
	}
    }
    if (!$exiftool_path) {
	return;
    }

    1;
}

sub _fill_exif_viewer {
    my($exif_toplevel, $image_path) = @_;

    _check_exiftool() or return;

    my $pager = $exif_toplevel->Subwidget('Pager');
    $pager->delete('1.0', 'end');

    my @exif_lines;
    my %line_seen;
    open my $fh, "-|", $exiftool_path, $image_path
	or main::status_message($!, "die");
    while(<$fh>) {
	chomp;
	next if $line_seen{$_}++; # no duplicates, please
	if (my($key,$rest) = $_ =~ m{^(.*?)(:.*)$}) {
	    if ($key =~ s{(\s+)$}{}) {
		$rest = (" "x length $1) . $rest;
	    }
	    push @exif_lines, [$key, $rest];
	} else {
	    push @exif_lines, ["", $_];
	}
    }
    close $fh
	or main::status_message($!, "die");

    my %exif_key_priority = do {
	my $i = 1;
	map { ($_ => $i++) }
	    (
	     'Make',
	     'Camera Model Name',
	     'Exposure Time',
	     'F Number',
	     'ISO',
	     'Focal Length',
	     'Flash',
	     'Exposure Difference',
	     'Active D-Lighting',
	     'White Balance',
	     'Focus Mode',
	     'Lens',
	     'Keywords',
	     'Date/Time Original',
	     'File Size',
	    );
    };
require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([\@exif_lines, \%exif_key_priority],[qw()])->Indent(1)->Useqq(1)->Dump; # XXX

    @exif_lines = sort { ($exif_key_priority{$a->[0]}||9_999_999) <=> ($exif_key_priority{$b->[0]}||9_999_999) } @exif_lines;     

    $pager->insert('end', join("\n", map { join("",@$_) } @exif_lines));
}

sub fill_exif_viewer_if_active {
    my($image_path) = @_;

    my $exif_toplevel = $main::toplevel{$exif_viewer_toplevel_name};
    if ($exif_toplevel && Tk::Exists($exif_toplevel)) {
	_fill_exif_viewer($exif_toplevel, $image_path);
    }
}

1;
