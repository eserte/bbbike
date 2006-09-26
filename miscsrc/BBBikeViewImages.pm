# -*- perl -*-

#
# $Id: BBBikeViewImages.pm,v 1.12 2006/09/26 20:16:27 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2005 Slaven Rezic. All rights reserved.
#

# Description (en): View images in bbd files
# Description (de): Bilder in bbd-Dateien anschauen
package BBBikeViewImages;

use BBBikePlugin;
push @ISA, "BBBikePlugin";

use strict;
use vars qw($VERSION $viewer_cursor $viewer $geometry $viewer_menu);
$VERSION = sprintf("%d.%02d", q$Revision: 1.12 $ =~ /(\d+)\.(\d+)/);

use BBBikeUtil qw(file_name_is_absolute);
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
    my $b = $mf->$Radiobutton
	(#main::image_or_text($button_image, 'Thunder'),
	 -text => "Img",
	 -variable => \$main::map_mode,
	 -value => 'BBBikeViewImages',
	 -command => sub {
	     $main::map_mode_deactivate->() if $main::map_mode_deactivate;
	     activate();
	     $main::map_mode_deactivate = \&deactivate;
	 });
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
	      [Radiobutton => "xv",
	       -variable => \$viewer,
	       -value => "xv",
	       -command => sub { viewer_change() },
	      ],
	      [Radiobutton => "ImageMagick (display)",
	       -variable => \$viewer,
	       -value => "display",
	       -command => sub { viewer_change() },
	      ],
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
	      [Radiobutton => "Halbe Bildschirmgröße",
	       -variable => \$geometry,
	       -value => "half",
	      ],
	      [Radiobutton => "1/3 der Bildschirmgröße",
	       -variable => \$geometry,
	       -value => "third",
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
    main::set_cursor_data($viewer_cursor);
    main::status_message("Auf Thumbnails klicken", "info");
}

sub deactivate {
}

sub button {
    my($c, $e) = @_;
    my($current_inx) = $c->find(withtag => "current");
    my($img_x, $img_y) = $c->coords($current_inx);
    my @all_image_inx = map {
	$_->[1];
    } sort {
	$a cmp $b;
    } map {
	my(@tags) = $c->gettags($_);
	my($date) = "@tags" =~ $iso_date_rx;
	[$date, $_];
    } grep {
	my(@tags) = $c->gettags($_);
	# Could be tag inx 1 or 2
	grep { /^Image:/ } @tags;
	#my $name = $tags[1];
	#$name =~ /^Image:/;
    } $c->find("overlapping",
	       $img_x-10, $img_y-10,
	       $img_x+10, $img_y+10);
    show_image_viewer(-canvas    => $c,
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
	    if (!file_name_is_absolute($abs_file)) {
	    SEARCH_FOR_ABS_FILE: {
		    for my $hash (\%main::str_file, \%main::p_file) {
			for my $tag (@tags) {
			    if (exists $hash->{$tag}) {
				my $try_file = dirname($hash->{$tag}) . "/" . $abs_file;
				if (-r $try_file) {
				    $abs_file = $try_file;
				    last SEARCH_FOR_ABS_FILE;
				}
			    }
			}
		    }
		}
	    }
	}
	last if (defined $abs_file)
    }
    if (defined $abs_file) {
	if (!-e $abs_file) {
	    main::status_message("Kann die Datei $abs_file nicht finden", "die");
	}

	if ($viewer eq '_internal') {
	    main::IncBusy($main::top);
	    eval {
		my($date) = $name =~ $iso_date_rx;
		my $image_viewer_toplevel = main::redisplay_top($main::top,
								"BBBikeViewImages_Viewer",
								-raise => 1,
								-transient => 0,
								-title => "Image viewer",
							       );
		if (!defined $image_viewer_toplevel) {
		    $image_viewer_toplevel = $main::toplevel{"BBBikeViewImages_Viewer"};
		} else {
		    my $f = $image_viewer_toplevel->Frame->pack(-fill => "x", -side => "bottom");
		    my $prev_button = $f->Button(-text => "<<")->pack(-side => "left");
		    $image_viewer_toplevel->Advertise(PrevButton => $prev_button);
		    my $next_button = $f->Button(-text => ">>")->pack(-side => "left");
		    $image_viewer_toplevel->Advertise(NextButton => $next_button);
		    my $n_of_m_label = $f->Label->pack(-side => "left");
		    $image_viewer_toplevel->Advertise(NOfMLabel => $n_of_m_label);
		    my $date_label = $f->Label->pack(-side => "left", -padx => 4);
		    $image_viewer_toplevel->Advertise(DateLabel => $date_label);
		    $f->Button(Name => "close",
			       -command => sub { $image_viewer_toplevel->destroy },
			      )->pack(-side => "right", -anchor => "e");
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
		if ($geometry eq 'half') {
		    my $new_p = $image_viewer_toplevel->Photo(-width => $p->width/2, -height => $p->height/2);
		    $new_p->copy($p, -subsample => 2);
		    $p->delete;
		    $p = $new_p;
		} elsif ($geometry eq 'third') {
		    my $new_p = $image_viewer_toplevel->Photo(-width => $p->width/3, -height => $p->height/3);
		    $new_p->copy($p, -subsample => 3);
		    $p->delete;
		    $p = $new_p;
		}
		$image_viewer_toplevel->Subwidget("ImageLabel")->configure(-image => $p);

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

		my @args = (\&show_image_viewer, -canvas => $c, -allimages => $all_image_inx, '-current');
		if (defined $prev_inx) {
		    $image_viewer_toplevel->Subwidget("PrevButton")->configure(-command => [@args, $prev_inx],
									       -state => "normal");
		} else {
		    $image_viewer_toplevel->Subwidget("PrevButton")->configure(-state => "disabled");
		}
		if (defined $next_inx) {
		    $image_viewer_toplevel->Subwidget("NextButton")->configure(-command => [@args, $next_inx],
									       -state => "normal");
		} else {
		    $image_viewer_toplevel->Subwidget("NextButton")->configure(-state => "disabled");
		}

		$image_viewer_toplevel->Subwidget("NOfMLabel")->configure(-text => $this_index_in_array->() . "/" . @$all_image_inx);

		$image_viewer_toplevel->Subwidget("DateLabel")->configure(-text => $date);

		$image_viewer_toplevel->{"photo"} = $p;
		$image_viewer_toplevel->deiconify;
		$image_viewer_toplevel->raise;
	    };
	    my $err = $@;
	    main::DecBusy($main::top);
	    if ($err) {
		main::status_message($err, "die");
	    }
	} elsif ($viewer eq 'xv') {
	    my @xv_args;
	    if ($geometry eq 'maxpect') {
		push @xv_args, "-maxpect";
	    } elsif ($geometry eq 'half') {
		push @xv_args, "-expand", 0.5;
	    } elsif ($geometry eq 'third') {
		push @xv_args, "-expand", 0.33;
	    }
	    my @cmd = ("xv", @xv_args, $abs_file);
	    main::status_message("@cmd", "info");
	    my $pid = fork;
	    die if !defined $pid;
	    if ($pid == 0) {
		exec @cmd;
		warn $!;
		CORE::exit(1);
	    }
	} elsif ($viewer eq 'display') {
	    my @display_args;
	    if ($geometry eq 'maxpect') {
		# NYI
	    } elsif ($geometry eq 'half') {
		push @display_args, "-resize", "50%";
	    } elsif ($geometry eq 'third') {
		push @display_args, "-resize", "33%";
	    }
	    my @cmd = ("display", @display_args, $abs_file);
	    main::status_message("@cmd", "info");
	    my $pid = fork;
	    die if !defined $pid;
	    if ($pid == 0) {
		exec @cmd;
		warn $!;
		CORE::exit(1);
	    }
	} elsif ($viewer eq '_wwwbrowser') {
	    require WWWBrowser;
	    WWWBrowser::start_browser("file://$abs_file", -oldwindow => 1);
	} else {
	    my $cmd = "$viewer $abs_file";
	    warn "Try $cmd...\n";
	    system("$cmd&");
	}
    } else {
	require Data::Dumper;
	main::status_message("Kann kein Bild in <" . Data::Dumper::Dumper(\@tags) . "> finden", "warn");
    }
}


1;
