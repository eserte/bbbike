# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2003,2008,2013,2014,2015,2016,2017,2021,2023,2024 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeGPS;

package main;
use strict;
use BBBikeGlobalVars;

# i18n functions M and Mfmt
BEGIN {
    if (!eval '
use Msg; # This call has to be in bbbike!
1;
') {
	warn $@ if $@;
	eval 'sub M ($) { $_[0] }';
	eval 'sub Mfmt { sprintf(shift, @_) }';
    }
}

use BBBikeUtil qw();

sub BBBikeGPS::gps_interface {
    my($mod, %args) = @_;

    my $noloading = delete $args{-noloading};

    die "Unhandled args: " . join(" ", %args) if %args;

    if (!@realcoords) {
	status_message(M('Keine Route'), 'error');
	return;
    }

    $mod = 'GPS::' . $mod;
    my %extra_args;
    if ($mod =~ s/_Test$//) {
	$extra_args{"-test"} = 1;
    }

    if (!$noloading) {
	eval qq{
	    require $mod;
        };
	if ($@) {
	    my $err = $@;
	    status_message(Mfmt("Das Modul %s konnte nicht geladen werden. Grund: %s", $mod, $err), "error");
	    warn $err;
	    return;
	}
    }
    my $modobj = eval { $mod->new };
    if ($@ || !$modobj) {
	if (!$@) {
	    $@ = "\$modobj undefined";
	}
	my $err = $@;
	status_message(Mfmt("Das Modul %s konnte nicht initialisiert werden. Grund: %s", $mod, $err), "error");
	warn $err;
	return;
    }
    my $file;
    my $gps_route_info = {};

    # XXX just an experiment, needs more thoughts!
    # XXX prepopulate route name with my own schema
    if (defined &SRTShortcuts::generate_gps_route_name) {
	$gps_route_info->{Name} = SRTShortcuts::generate_gps_route_name();
    }

    if ($modobj->transfer_to_file()) {
	my $default_extension = $modobj->default_extension;
	$file = $top->getSaveFile(-defaultextension => $default_extension);
	return unless defined $file;
    }
    if ($modobj->can("tk_interface")) {
	return if !$modobj->tk_interface(-top => $top,
					 -gpsrouteinfo => $gps_route_info,
					 -test => $extra_args{-test},
					 -file => $file,
					);
    }

    my $routetoname = get_route_simplification_mapping(verbose => 1);
    $extra_args{-routetoname} = $routetoname if $routetoname;
    
    eval {
	my $route_obj = Route->new_from_realcoords(\@realcoords, -searchroutepoints => \@search_route_points);
	my $res = $modobj->convert_from_route
	    ($route_obj,
	     -streetobj   => $multistrassen || $str_obj{'s'},
	     -netobj      => $net,
	     -routename   => $gps_route_info->{Name},
	     -routenumber => $gps_route_info->{Number},
	     -wptsuffix   => $gps_route_info->{WptSuffix},
	     -wptsuffixexisting => $gps_route_info->{WptSuffixExisting},
	     -waypointlength => $gps_waypointlength,
	     -waypointsymbol => $gps_waypointsymbol,
	     -waypointcharset => $gps_waypointcharset,
	     -showcrossings => 0, # XXX yes? no?
	     -gpsdevice   => $gps_device,
	     %extra_args,
	    );
	$modobj->transfer(-file => $file,
			  -res => $res,
			  -test => $extra_args{-test},
			  -top => $top);
	if ($do_gps_upload_hist) {
	    BBBikeGPS::gps_upload_history($route_obj, -gpsrouteinfo => $gps_route_info);
	}
    };
    if ($@) {
	if (defined $file) {
	    status_message
		(Mfmt("Schreiben auf <%s> nicht m�glich: %s", $file, $@), 'err');
	} else {
	    status_message
		(Mfmt("Transfer auf GPS-Ger�t nicht m�glich: %s", $@), 'err');
	}
    }
}

sub BBBikeGPS::gps_upload_history {
    my($route_obj, %opts) = @_;
    my $gps_route_info = delete $opts{'-gpsrouteinfo'};
    die "Unhandled arguments: " . join(" ", %opts) if %opts;
    if (!-d $gps_upload_dir) {
	mkdir $gps_upload_dir, 0700;
	if (!-d $gps_upload_dir) {
	    main::status_message(Mfmt("Das Verzeichnis %s konnte nicht erzeugt werden. Grund: %s", $gps_upload_dir, $!), "error");
	    return;
	}
    }
    my $route_name = $gps_route_info->{Name};
    $route_name =~ s{[^A-Za-z0-9_-]}{_}g;
    require POSIX;
    my $path = "$gps_upload_dir/" . POSIX::strftime("%Y%m%d_%H%M%S", localtime) . "_" . $route_name. ".bbr";
    $route_obj->save_object($path);
}

sub get_route_simplification_mapping {
    my(%args) = @_;
    my $v = delete $args{verbose} || 0;
    my $routetoname;

    if ($export_txt_mode == EXPORT_TXT_FULL) {
	status_message("Export mode: full", "info") if $v;
    } elsif ($export_txt_mode == EXPORT_TXT_SIMPLIFY_NAME) {
	$routetoname = get_act_search_route();
	status_message("Export mode: simplify name", "info") if $v;
    } elsif ($export_txt_mode == EXPORT_TXT_SIMPLIFY_ANGLE) {
	# XXX vielleicht einen Mode EXPORT_TXT_SIMPLIFY_AUTO_ANGLE
	# (Kombination aus EXPORT_TXT_SIMPLIFY_ANGLE und
	# EXPORT_TXT_SIMPLIFY_AUTO) einf�hren
	$routetoname = [StrassenNetz::simplify_route_to_name(get_act_search_route(), -minangle => $export_txt_min_angle)];
	status_message("Export mode: simplify with angle $export_txt_min_angle�", "info") if $v;
    } elsif ($export_txt_mode == EXPORT_TXT_SIMPLIFY_NAME_OR_ANGLE) {
	$routetoname =
	    [StrassenNetz::simplify_route_to_name
	     ([$net->route_to_name([@realcoords],-startindex=>0,-combinestreet=>0)],
	      -minangle => $export_txt_min_angle, -samestreet => 1)];
	status_message("Export mode: simplify with angle $export_txt_min_angle� or name", "info") if $v;
    } elsif ($export_txt_mode == EXPORT_TXT_SIMPLIFY_AUTO) {
	# XXX besser bin�re Suche statt inkrementell
	my $step = 5;
    TRY: {
	    last TRY if !defined $gps_waypoints; # no simplification necessary
	    for(my $tryangle = 5; $tryangle <= 90; $tryangle+=$step) {
		$routetoname = [StrassenNetz::simplify_route_to_name
				([$net->route_to_name([@realcoords],-startindex=>0,-combinestreet=>0)],
				 -minangle => $tryangle, -samestreet => 1)];
		if (@$routetoname <= $gps_waypoints) {
		    status_message("Export simplify mode: auto; using $tryangle� as minimum angle", "info");
		    last TRY;
		}
		if ($tryangle+$step > $export_txt_min_angle) {
		    $step = 15;
		}
	    }
	    status_message("Export simplify mode: auto; using 90� as minimum angle --- maybe split the route?", "info") if $v;
	}
    }

    $routetoname;
}

use vars qw($gpsman_last_dir $gpsman_data_dir);
if (!defined $gpsman_data_dir) {
    if (!-d BBBikeUtil::bbbike_root()."/misc/gps_data" &&
	-d BBBikeUtil::bbbike_root()."/misc/gps_data_local") {
	# convention for laptop usage
	$gpsman_data_dir = BBBikeUtil::bbbike_root()."/misc/gps_data_local";
    } else {
	# regardless whether it exists or not
	$gpsman_data_dir = BBBikeUtil::bbbike_root()."/misc/gps_data"
    }
}    

use vars qw($cfc_mapping);

{
    package BBBikeGPS::PathGraphElem;
    use myclassstruct qw(wholedist wholetime dist time legtime
			 speed alt grade coord accuracy);
}

use constant DEFAULT_MAX_GAP => 2; # minutes

# Return file to draw
sub BBBikeGPS::draw_gpsman_data {
    my($top) = @_;

    require Tk::ColorFlowChooser;
    require Tk::PathEntry;
    Tk::PathEntry->VERSION(2.18);
    require Safe;
    require Cwd;
    require Data::Dumper;
    require BBBikeUtil;
    require Tk::Ruler;

    my $max_gap = DEFAULT_MAX_GAP;
    # continuous colors
    my @colordef = ('#ffff00', {len => 80},
		    '#ff0000', {len => 80},
		    '#a0a000', {len => 80},
		    '#00ff00', {len => 80},
		    '#00c0c0', {len => 80},
		    '#0000ff', {len => 80},
		    '#ff00ff',
		   );
    {
	# discrete colors
	my $l = 80;
	@colordef = ('#ff0000', {len => $l}, '#ff0000', {len => 1},
		     '#d0d000', {len => $l}, '#d0d000', {len => 1},
		     '#00c000', {len => $l}, '#00c000', {len => 1},
		     '#0000ff', {len => $l}, '#0000ff', {len => 1},
		     '#c000c0', {len => $l}, '#c000c0', #{len => 1},
		    );
    }

    #my @colordef = ('#000000', {len => 320}, '#ffffff');

    my $cfc_top = $top->Toplevel(-title => M"GPS-Daten zeichnen");
    $cfc_top->transient($top) if $main::transient;
    $main::toplevel{'BBBikeGPS.pm'} = $cfc_top;

    use vars qw($gui_draw_gpsman_data_auto $gui_draw_gpsman_data_s $gui_draw_gpsman_data_p
		$show_track_graph
		$show_track_graph_speed
		$show_track_graph_alt
		$show_track_graph_grade
		$show_track_graph_dist_time
		$show_statistics
		$do_center_begin
		$draw_point_names);
    $gui_draw_gpsman_data_auto = 1 if !defined $gui_draw_gpsman_data_auto;
    $gui_draw_gpsman_data_s = 0 if !defined $gui_draw_gpsman_data_s;
    $gui_draw_gpsman_data_p = 0 if !defined $gui_draw_gpsman_data_p;
    $show_track_graph = 0   if !defined $show_track_graph;
    $show_track_graph_speed = 1 if !defined $show_track_graph_speed;
    $show_track_graph_alt = 0 if !defined $show_track_graph_alt;
    $show_track_graph_grade = 0 if !defined $show_track_graph_grade;
    $show_track_graph_dist_time = 0 if !defined $show_track_graph_dist_time;
    $show_statistics = 0    if !defined $show_statistics;
    $do_center_begin = 0    if !defined $do_center_begin;
    $draw_point_names = 0   if !defined $draw_point_names;

    my $file = $gpsman_last_dir || Cwd::getcwd();
    my $weiter = 0;

    $cfc_top->Label(-text => M("GPX/GPSMan-Datei").":")->pack(-anchor => "w");
    my $f = $cfc_top->Frame->pack(-fill => "x", -expand => 1);
    my $pe = $f->PathEntry
	(-textvariable => \$file,
	 -selectcmd => sub { $weiter = 1 },
	 -cancelcmd => sub { $weiter = -1 },
	 -width => BBBikeUtil::max(length($file), 40),
	)->pack(-fill => "x", -expand => 1, -side => "left");
    $pe->focus;
    $pe->icursor("end");
    if (-d $gpsman_data_dir) {
	my @l = localtime;
	my @l_gestern = localtime(time-86400); # good approx...
	my $heute = sprintf("$gpsman_data_dir/%04d%02d%02d", $l[5]+1900,$l[4]+1,$l[3]);
	my $gestern = sprintf("$gpsman_data_dir/%04d%02d%02d", $l_gestern[5]+1900,$l_gestern[4]+1,$l_gestern[3]);
	my $ff = $cfc_top->Frame->pack(-fill => "x", -expand => 1);
	my $row = 0;
	{
	    my $columnspan;
	    my $can_dateentry = 0;
	    if (eval { require Tk::DateEntry; Tk::DateEntry->VERSION("1.38"); }) {
		$can_dateentry = 1;
	    } else {
		$columnspan = 2;
	    }
	    $ff->Button(-text => M"GPX/GPSMan-Datenverzeichnis",
			-command => sub { $file = $gpsman_data_dir }
		       )->grid(-row => $row, -column => 0, -sticky => "ew",
			       (defined $columnspan ? (-columnspan => $columnspan) : ()),
			      );
	    if ($can_dateentry) {
		my $dmy2file = sub {
		    my($day,$month,$year) = @_;
		    "$gpsman_data_dir/" . sprintf("%04d%02d%02d", $year, $month, $day) . ".trk";
		};
		my $dmy2file_gpx = sub {
		    my($day,$month,$year) = @_;
		    "$gpsman_data_dir/" . sprintf("%04d%02d%02d", $year, $month, $day) . ".gpx";
		};
		my $file2ymd = sub {
		    my($file) = @_;
		    $file =~ s{\Q$gpsman_data_dir/}{};
		    if (my($year,$month,$day) = $file =~ m{(\d{4})(\d{2})(\d{2})}) {
			($year,$month,$day);
		    } else {
			my @l = localtime;
			$l[4]++;
			$l[5]+=1900;
			($l[5], $l[4], $l[3]);
		    }
		};
		my $date = join("/", $file2ymd->($file));
		my $de = $ff->DateEntry
		    (-dateformat => 2,
		     -todaybackground => "yellow",
		     -weekstart => 1,
		     -daynames => 'locale',
		     -textvariable => \$date,
		     -formatcmd => sub {
			 my($year,$month,$day) = @_;
			 $file = $dmy2file->($day,$month,$year);
			 if (!-r $file) {
			     $file = $dmy2file_gpx->($day,$month,$year);
			     if (!-r $file) {
				 $file = undef;
			     }
			 }
			 "$year/$month/$day";
		     },
		     -configcmd => sub {
			 my(%args) = @_;
			 if (defined $args{-date}) {
			     my($d,$m,$y) = @{ $args{-date} };
			     my $file = $dmy2file->($d,$m,$y);
			     if (-r $file) {
				 $args{-datewidget}->configure(-bg => "red");
			     } else {
				 $file = $dmy2file_gpx->($d,$m,$y);
				 if (-r $file) {
				     $args{-datewidget}->configure(-bg => "red");
				 }
			     }
			 }
		     },
		    )->grid(-row => $row, -column => 1, -sticky => "ew");
		my $dee = $de->Subwidget("entry"); # XXX hackery
		$dee->configure(-relief => "flat",
				-highlightthickness => 0,
				-bd => 0);
		$dee->Label(-text => "Datum:",
			    -anchor => "e")->place(-x => 0, -y => 0,
						   -relwidth => 1,
						   -relheight => 1);
	    }
	}
	$row++;
	my $get_heute_track = sub {
	    for my $suffix (qw(trk gpx)) {
		return "$heute.$suffix" if -r "$heute.$suffix";
	    }
	    # private SRT hack
	    my $f = "$ENV{HOME}/trash/Current.gpx";
	    my @s = stat($f);
	    if ($s[9]) {
		my @l_then = localtime $s[9];
		my @l_now  = localtime;
		if ($l_then[3] == $l_now[3] &&
		    $l_then[4] == $l_now[4] &&
		    $l_then[5] == $l_now[5]) {
		    # Current.gpx is from today
		    return $f;
		}
	    }
	    undef;
	};
	my $get_gestern_track = sub {
	    for my $suffix (qw(trk gpx)) {
		return "$gestern.$suffix" if -r "$gestern.$suffix";
	    }
	    # private SRT hack
	    require Time::Piece;
	    my $f = "$ENV{HOME}/trash/Current.gpx";
	    my @s = stat($f);
	    if ($s[9]) {
		my $yesterday = Time::Piece->new(time-86400)->ymd; # XXX may be wrong during DST switches!
		my $filemtime = Time::Piece->new($s[9])->ymd;
		return $f if $yesterday eq $filemtime;
	    }
	    undef;
	};
	$ff->Button(-text => M"Track heute",
		    (!$get_heute_track->() ? (-state => "disabled") : ()),
		    -command => sub { $file = $get_heute_track->();  
				      $gui_draw_gpsman_data_s = 1;
				      $gui_draw_gpsman_data_p = 0;
				  }
		   )->grid(-row => $row, -column => 0, -sticky => "ew");
	$ff->Button(-text => M"Track gestern",
		    (!$get_gestern_track->() ? (-state => "disabled") : ()),
		    -command => sub { $file = $get_gestern_track->();
				      $gui_draw_gpsman_data_s = 1;
				      $gui_draw_gpsman_data_p = 0;
				  }
		   )->grid(-row => $row, -column => 1, -sticky => "ew");
	$row++;
	$ff->Button(-text => M"Waypoints heute",
		    (!-r "$heute.wpt" ? (-state => "disabled") : ()),
		    -command => sub { $file = "$heute.wpt";
				      $gui_draw_gpsman_data_s = 0;
				      $gui_draw_gpsman_data_p = 1;
				  }
		   )->grid(-row => $row, -column => 0, -sticky => "ew");
	$ff->Button(-text => M"Waypoints gestern",
		    (!-r "$gestern.wpt" ? (-state => "disabled") : ()),
		    -command => sub { $file = "$gestern.wpt";
				      $gui_draw_gpsman_data_s = 0;
				      $gui_draw_gpsman_data_p = 1;
				  }
		   )->grid(-row => $row, -column => 1, -sticky => "ew");
	$row++;
    }
    $f->Button(-text => "?",
	       -command => sub {
		   my $ht = $f->Toplevel(-title => M("Hilfe"));
		   $ht->transient($f->toplevel);
		   my $msg =
		       $ht->Message(-text => <<EOF)->pack(-fill => "both");
Mit der <TAB>-Taste kann der Dateiname automatisch vervollst�ndigt werden. Gibt es mehrere Vervollst�ndigungen, wird eine klickbare Liste angezeigt. Wenn mehr als zehn Treffer vorhanden sind, werden mit weiteren Druck auf die <TAB>-Taste die n�chsten Treffer der Liste angezeigt.
EOF
                   my $okb =
		       $ht->Button(Name => "ok",
				   -command => sub { $ht->destroy })->pack;
		   $okb->focus;
	       })->pack(-side => "left");

    my $f2 = $cfc_top->Frame->pack(-fill => "x", -expand => 1);

    {
	my($draw_gpsman_data_s_check, $draw_gpsman_data_p_check);
	my $fix_draw_gpsman_data_check_visibility = sub {
	    if ($gui_draw_gpsman_data_auto) {
		$_->configure(-state => 'disabled')
		    for ($draw_gpsman_data_s_check, $draw_gpsman_data_p_check);
	    } else {
		$_->configure(-state => 'normal')
		    for ($draw_gpsman_data_s_check, $draw_gpsman_data_p_check);
	    }
	};
	$f2->Checkbutton(-text => M"Auto",
			 -variable => \$gui_draw_gpsman_data_auto,
			 -command => $fix_draw_gpsman_data_check_visibility,
			)->pack(-anchor => "w");
	$draw_gpsman_data_s_check = $f2->Checkbutton(-text => M"Strecken zeichnen",
						     -variable => \$gui_draw_gpsman_data_s)->pack(-anchor => "w");
	$draw_gpsman_data_p_check = $f2->Checkbutton(-text => M"Punkte zeichnen",
						     -variable => \$gui_draw_gpsman_data_p)->pack(-anchor => "w");
	$fix_draw_gpsman_data_check_visibility->();
    }

    {
	my $f3 = $f2->Frame->pack(-fill => "x", -anchor => "w");
	$f3->gridColumnconfigure($_, -weight => 1) for (0 .. 1);
	my @dep;
	my $update_dep = sub {
	    for (@dep) {
		$_->configure(-state => $show_track_graph ? "normal" : "disabled");
	    }
	};
	Tk::grid($f3->Checkbutton
		 (-text => M"Graphen zeichnen",
		  -variable => \$show_track_graph,
		  -command => $update_dep,
		 ),
		 $dep[0] = $f3->Checkbutton(-text => M"Geschwindigkeit",
					    -variable => \$show_track_graph_speed),
		 -sticky => "w");
	Tk::grid($f3->Label,
		 $dep[1] = $f3->Checkbutton(-text => M"H�he",
					    -variable => \$show_track_graph_alt),
		 -sticky => "w");
	Tk::grid($f3->Label,
		 $dep[2] = $f3->Checkbutton(-text => M"Steigung",
					    -variable => \$show_track_graph_grade),
		 -sticky => "w");
	Tk::grid($f3->Label,
		 $dep[3] = $f3->Checkbutton(-text => M"Weg-Zeit",
					    -variable => \$show_track_graph_dist_time),
		 -sticky => "w");
	$update_dep->();
    }
    $f2->Checkbutton(-text => M"Punktnamen zeichnen",
		     -variable => \$draw_point_names)->pack(-anchor => "w");
    $f2->Checkbutton(-text => M"Statistik zeigen",
		     -variable => \$show_statistics)->pack(-anchor => "w");
    $f2->Checkbutton(-text => M"Auf Anfang zentrieren",
		     -variable => \$do_center_begin)->pack(-anchor => "w");
    my $accuracy_level = 2;
    my $acc_opt = [[M("Nur genaue Punkte auswerten") => 0],
		   [M("Leicht ungenaue Punkte auch auswerten") => 1],
		   [M("Alle Punkte auswerten") => 2],
		  ];
    my $acc_om =
	$f2->Optionmenu
	    (-options => $acc_opt,
	     -variable => \$accuracy_level,
	    )->pack(-anchor => "w");
    $acc_om->setOption(@{$acc_opt->[$accuracy_level]});

    $cfc_top->Ruler->rulerPack;

    $cfc_top->Label(-text => M("Geschwindigkeit => Farbe").":")->pack;
    my $cfc = $cfc_top->ColorFlowChooser(-startx => 5,
					 -starty => 2,
					 -movecarry => 1,
					 -colordef => \@colordef,
					 # 0 .. 130
					 -scaledef => [map { $_*5 } (0 .. 26)],
					)->pack;
    my $solid_coloring;
    $cfc_top->Checkbutton(-text => M("Einheitliche Farbe"),
			  -variable => \$solid_coloring)->pack;

    BBBikeGPS::load_cfc_mapping();
    if (defined $cfc_mapping) {
	$cfc->set_mapping($cfc_mapping);
    }

    $cfc_top->Ruler->rulerPack;
    {
	my $f = $cfc_top->Frame->pack(-anchor => "e");
	my @bfb;
	push @bfb, $f->Button(Name => "ok",
			      -command => sub { $weiter = 1 });
	my $cb = $f->Button(Name => "close",
			    -command => sub { $weiter = -1 });
	push @bfb, $cb;
	pack_buttonframe($f, \@bfb);
	$cfc_top->bind('<<CloseWin>>' => sub { $cb->invoke });
    }

    $cfc_top->OnDestroy(sub { $weiter = -1 });
    $pe->waitVariable(\$weiter);
    if ($weiter != 1) {
	$cfc_top->destroy if Tk::Exists($cfc_top);
	return;
    }

    $gpsman_last_dir = $file;
    my $encoded_file = $file;
    # Hack XXX: force result into bytes for later use:
    if ($^O ne 'MSWin32' && eval { require Encode; 1 }) {
	$encoded_file = Encode::encode("iso-8859-1", $file);
    }

    $cfc_mapping = $cfc->get_mapping;
    if (open(D, "> " . BBBikeGPS::get_cfc_file())) {
	print D Data::Dumper->Dumpxs([$cfc_mapping], ['cfc_mapping']);
	close D;
    }
    $cfc_top->destroy;
    $top->update;

    my %draw_args =
	(-gap => $max_gap,
	 -solidcoloring => $solid_coloring,
	 -drawtypeauto => $gui_draw_gpsman_data_auto,
	 -drawstreets => $gui_draw_gpsman_data_s,
	 -drawpoints  => $gui_draw_gpsman_data_p,
	 -accuracylevel => $accuracy_level,
	 -centerbegin => $do_center_begin,
	);

    if (eval {
	require Storable;
	require MIME::Base64;
	1;
    }) {
	my $serialized = MIME::Base64::encode_base64(Storable::nfreeze(\%draw_args));
	$serialized =~ s{\n}{}g;
	my $add_def = "\t" . join("\t", -serialized => $serialized);
	main::add_last_loaded($encoded_file, $main::last_loaded_tracks_obj, $add_def);
	main::save_last_loaded($main::last_loaded_tracks_obj);
    } else {
	warn "Cannot store draw args: $@";
    }

    BBBikeGPS::do_draw_gpsman_data($top, $encoded_file, %draw_args);

    $file;
}

sub BBBikeGPS::load_cfc_mapping {
    my $safe = Safe->new;
    undef $cfc_mapping;
    $safe->share(qw($cfc_mapping));
    $safe->rdo(BBBikeGPS::get_cfc_file());
}

sub BBBikeGPS::get_cfc_file {
    "$main::bbbike_configdir/speed_color_mapping.cfc";
}

use vars qw($global_draw_gpsman_data_s $global_draw_gpsman_data_p);
$global_draw_gpsman_data_s = 1 if !defined $global_draw_gpsman_data_s;
$global_draw_gpsman_data_p = 1 if !defined $global_draw_gpsman_data_p;

sub BBBikeGPS::do_draw_gpsman_data {
    my($top, $file, %args) = @_;
    my $max_gap = exists $args{-gap} ? $args{-gap} : DEFAULT_MAX_GAP;
    my $solid_coloring = $args{-solidcoloring};
    my $draw_gpsman_data_auto = $args{-drawtypeauto};
    # maybe, because auto may take precedence
    my $maybe_draw_gpsman_data_s = exists $args{-drawstreets} ? $args{-drawstreets} : $global_draw_gpsman_data_s;
    my $maybe_draw_gpsman_data_p = exists $args{-drawpoints} ? $args{-drawpoints} : $global_draw_gpsman_data_p;
    my $accuracy_level = exists $args{-accuracylevel} ? $args{-accuracylevel} : 3;
    my $do_center_begin = $args{-centerbegin} || 0;
    my $plotted_layer_info = $args{-plottedlayerinfo} || {};

    my $base;
    my $s;
    my $draw_gpsman_data_s;
    my $draw_gpsman_data_p;

    if (!$cfc_mapping) { # may happen if loading from "last loaded
                         # tracks" menu
	BBBikeGPS::load_cfc_mapping();
    }

    require GPS::Symbols::Garmin;
    my $symbol_to_img = GPS::Symbols::Garmin::get_cached_symbol_to_img();

    require GPS::GpsmanData;

    main::IncBusy($top);
    eval {

    require GPS::GpsmanData::Any;
    my $gps = GPS::GpsmanData::Any->load($file);

    # streets or points or both?
    # $draw_gpsman_data_auto needs the gps file already loaded
    if ($draw_gpsman_data_auto) {
	if ($gps->has_track || $gps->has_route) {
	    $draw_gpsman_data_s = 1;
	    $draw_gpsman_data_p = 0;
	} else {
	    $draw_gpsman_data_s = 0;
	    $draw_gpsman_data_p = 1;
	}
    } else {
	$draw_gpsman_data_s = $maybe_draw_gpsman_data_s;
	$draw_gpsman_data_p = $maybe_draw_gpsman_data_p;
    }

    require Karte;
    Karte::preload(qw(Polar));
    require Strassen;
    $s = Strassen->new;
    my $s_speed = $draw_gpsman_data_s ? Strassen->new : undef;
    my $whole_dist = 0;
    my $whole_time = 0;
    my $max_speed = 0;
    my @add_wpt_prop;
    require File::Basename;
    $base = File::Basename::basename($file);

    my $last_wpt;
    my $last_accurate_wpt;
    my $is_new_chunk;
    my $vehicle;
    my $last_vehicle;
    my @pos2vehicle;
    my $brand;
    my %brand; # per vehicle
    my $device;
    my $first_date;
    foreach my $chunk (@{ $gps->Chunks }) {
	my $is_route = $chunk->Type == GPS::GpsmanData::TYPE_ROUTE();
	if (!$is_route) {
	    # is it a time-less track?
	SEARCH_TIME_POINT: {
		for my $wpt (@{ $chunk->Points }) {
		    if ((defined $wpt->DateTime && $wpt->DateTime ne '') || defined $wpt->Comment_to_unixtime($chunk)) {
			last SEARCH_TIME_POINT;
		    }
		}
		$is_route = 1;
	    }
	}

	# Code taken from gpsman2bbd.pl:
	my $trackattrs = $chunk->TrackAttrs ? $chunk->TrackAttrs : {};
	if ($trackattrs->{"srt:vehicle"}) {
	    $vehicle = $trackattrs->{"srt:vehicle"};
	}

	$brand = $trackattrs->{"srt:brand"};
	if (!$brand) {
	    if (defined $vehicle && $brand{$vehicle}) {
		$brand = $brand{$vehicle}; # remember from last
	    }
	} else {
	    if (defined $vehicle and defined $brand) {
		$brand{$vehicle} = $brand;
	    }
	}

	if ($trackattrs->{"srt:device"}) {
	    $device = $trackattrs->{"srt:device"};
	}

	$is_new_chunk = 1;
	foreach my $wpt (@{ $chunk->Points }) {
	    my($x,$y) = map { int } $Karte::map{"polar"}->map2map($main::coord_system_obj, $wpt->Longitude, $wpt->Latitude);
	    my($x0,$y0) = ($main::coord_system eq 'standard' ? ($x,$y) : map { int } $Karte::map{"polar"}->map2standard($wpt->Longitude, $wpt->Latitude));
	    my $alt = $wpt->Altitude;
	    $alt =~ s{^\?}{} if defined $alt; # XXX remove the "question mark" hack from altitudes, should really be done in GPS::GpsmanData!
	    my $acc = $wpt->Accuracy;
	    my $pointname;
	    my $comment_add = (defined $wpt->Comment && $wpt->Comment ne ""
			       ? "/" . $wpt->Comment
			       : ''
			      );
	    if ($draw_point_names) {
		$pointname = $wpt->Ident . $comment_add;
	    } else {
		$pointname =
		    $base . "/" . $wpt->Ident . $comment_add .
			(defined $alt && length $alt ? " alt=".sprintf("%.1fm",$alt) : "") .
			    " long=" . Karte::Polar::dms_human_readable("long", Karte::Polar::ddd2dms($wpt->Longitude)) .
				" lat=" . Karte::Polar::dms_human_readable("lat", Karte::Polar::ddd2dms($wpt->Latitude));
	    }
	    my $p_cat = "#0000a0";
	    if ($symbol_to_img && $wpt->Symbol && exists $symbol_to_img->{$wpt->Symbol}) {
		$p_cat = "IMG:$symbol_to_img->{$wpt->Symbol}";
	    }
	    my $l = [$pointname, ["$x,$y"], $p_cat];
	    $s->push($l);
	    if ($s_speed) {
		my $time = $wpt->Comment_to_unixtime($chunk);
		$time = 0 if !defined $time && $is_route; # set pseudo time for routes, to force display
		if (defined $time) {
		    if ($last_wpt) {
			my($last_x,$last_y,$last_x0,$last_y0,$last_time,$last_alt,$last_acc) = @$last_wpt;
			my $legtime = $time-$last_time;
			# Do not check for $legtime==0 --- saved tracks do not
			# have any time at all! Also routes do not have.
			if ($is_route || (abs($legtime) < 60*$max_gap && !$is_new_chunk)) {
			    my $dist = sqrt(($x0-$last_x0)**2 + ($y0-$last_y0)**2);
			    if ($last_accurate_wpt && $acc <= $accuracy_level) {
				my(undef,undef,$last_acc_x0,$last_acc_y0) = @$last_wpt;
				my $acc_dist = sqrt(($x0-$last_acc_x0)**2 + ($y0-$last_acc_y0)**2);
				$whole_dist += $acc_dist;
			    }
			    #$whole_dist += $dist;
			    $whole_time += $legtime;
			    my @l = localtime $time;
			    my $speed;
			    if ($legtime) {
				$speed = $dist/($legtime)*3.6;
			    }
			    my $grade;
			    if ($dist != 0 && defined $alt && length $alt) {
				$grade = 100*(($alt-$last_alt)/$dist);
				if (abs($grade) > 10) {	# XXX too many wrong values... XXX more intelligent solution
				    undef $grade;
				}
			    }

			    my $max_acc = max($acc, $last_acc);
			    my $path_graph_elem = BBBikeGPS::PathGraphElem->new;
			    $path_graph_elem->wholedist($whole_dist);
			    $path_graph_elem->wholetime($whole_time);
			    $path_graph_elem->dist($dist);
			    $path_graph_elem->time($time);
			    $path_graph_elem->legtime($legtime);
			    $path_graph_elem->speed($speed)
				if defined $speed;
			    $path_graph_elem->alt($alt);
			    $path_graph_elem->grade($grade);
			    $path_graph_elem->coord("$x,$y");
			    $path_graph_elem->accuracy($max_acc);
			    push @add_wpt_prop, $path_graph_elem;

			    if ($show_track_graph && defined $vehicle) {
				if (!defined $last_vehicle || $vehicle ne $last_vehicle) {
				    push @pos2vehicle, {wholedist => $whole_dist, wholetime => $whole_time, vehicle => $vehicle};
				    $last_vehicle = $vehicle;
				}
			    }

			    my $s_cat = "#000000";
			    if ($is_route) {
				$s_cat = 'Rte';
			    } elsif ($max_acc <= $accuracy_level) {
				if (defined $speed) {
				    if (!defined $max_speed || $max_speed < $speed) {
					$max_speed = $speed;
				    }
				    if (!$solid_coloring) {
					$s_cat = $cfc_mapping->{int($speed)};
				    }
				}
				if (!defined $s_cat) {
				    my(@sorted) = sort { $a <=> $b } keys %$cfc_mapping;
				    if (defined $speed && $speed <= $sorted[0]) {
					$s_cat = $cfc_mapping->{$sorted[0]};
				    } else {
					$s_cat = $cfc_mapping->{$sorted[-1]};
				    }
				}
			    } elsif ($max_acc >= 2) {
				#$s_cat = "#e4c8e4"; # GPSs~~ from bbbike
				$s_cat = "#e2e2e2";
			    } else {
				#$s_cat = "#f4c0f4"; # GPSs~
				$s_cat = "#eeeeee"; # GPSs~
			    }

			    {
				my $name = "";
				if (defined $speed) {
				    $name .= int($speed) . " km/h ";
				}
				my $date = sprintf "%04d-%02d-%02d", $l[5]+1900,$l[4]+1,$l[3];
				$name .= "[dist=" . BBBikeUtil::m2km($whole_dist,2) .
				    ", time=" . BBBikeUtil::s2ms($whole_time) . "min" .
				    ", abstime=" .
				    (defined $first_date && $date ne $first_date ? "$date " : "") .
				    sprintf("%02d:%02d:%02d", @l[2,1,0]) .
				    (defined $grade ? ", grade=" . sprintf("%.1f%%", $grade) : "") .
				    (defined $alt ? ", alt=" . sprintf("%.1fm", $alt) : "") .
				    (defined $vehicle ? ", vehicle=$vehicle" . (defined $brand ? "/$brand" : "") : "") .
				    (defined $device ? ", device=$device" : "") .
				    "]";
				$first_date = $date if !defined $first_date;
				my $c1 = "$last_x,$last_y";
				my $c2 = "$x,$y";
				if ($main::use_current_coord_prefix) {
				    $c1 =  $main::coord_system_obj->coordsys . $c1;
				    $c2 =  $main::coord_system_obj->coordsys . $c2;
				}
				$s_speed->push([$name, [$c1, $c2], $s_cat]);
			    }
			}
		    }
		    $last_wpt = [$x,$y,$x0,$y0,$time,$alt,$acc];
		    if ($acc <= $accuracy_level) {
			$last_accurate_wpt = [@$last_wpt];
		    }
		}
	    }
	} continue {
	    $is_new_chunk = 0;
	}
    }

    if (@pos2vehicle) {
	# finalize; vehicle here not necessary
	push @pos2vehicle, {wholedist => $whole_dist, wholetime => $whole_time};
    }

    if ($s_speed) {
	my $msg = "";
	$msg .= "Total distance = " . BBBikeUtil::m2km($whole_dist, 2) . "\n";
	if ($whole_time) {
	    $msg .= "Total time =     " . BBBikeUtil::s2ms($whole_time) . " min\n";
	    $msg .= "Average speed =  " . sprintf("%.1f km/h", $whole_dist/$whole_time*3.6) . "\n";
	}
	if ($max_speed) {
	    $msg .= "Maximum speed =  " . sprintf("%.1f km/h", $max_speed) . "\n";
	}
	my $real_speed_outfile = my $speed_outfile = "$tmpdir/$base-gpsspeed.bbd";

	warn $msg;
	if ($show_statistics) {
	    my $t_name = "gpsman-data-statistics";
	    my $t = main::redisplay_top($top, $t_name,
					-title => M"Statistik");
	    if (defined $t) {
		$t->Component(Label => "Msg",
			      -justify => "left",
			      -text => $msg)->pack(-fill => "both", -expand => 1);
	    } else {
		$main::toplevel{$t_name}->Subwidget("Msg")->configure(-text => $msg);
	    }
	}

	if ($main::edit_mode || $main::edit_normal_mode) {
	    # This is somewhat hacky --- in edit mode all files should have
	    # the -orig suffix
	    $real_speed_outfile = $speed_outfile . "-orig";
	}
	$s_speed->set_global_directives({ 'line_dash.Rte' => ["5, 5"],
					  'category_color.Rte' => ['#000000'],
					  'listing_sort' => ['unsorted'],
					});
	$s_speed->write($real_speed_outfile);
	my $abk = main::plot_layer('str',$speed_outfile,
				   #stack_order=>[below=>'s-NN'],
				   stack_order=>[above=>'sBAB-fg'],
				  );
	$plotted_layer_info->{"str-$abk"}++ if defined $abk;
	Hooks::get_hooks("after_new_layer")->execute;
    }

    BBBikeGPS::draw_track_graph({-top => $top,
				 -wpt => \@add_wpt_prop,
				 -accuracylevel => $accuracy_level,
				 -pos2vehicle => \@pos2vehicle,
				})
	    if $show_track_graph;

    if ($do_center_begin && $gps->Chunks && @{ $gps->Chunks }) {
	my $wpt = sub {
	    # Common case: first point exists and it accurate enough
	    if (@{ $gps->Chunks->[0]->Points } && $gps->Chunks->[0]->Points->[0]->Accuracy <= $accuracy_level) {
		return $gps->Chunks->[0]->Points->[0];
	    }
	    # Expensive case: search for a suitable point
	    for my $wpt_candidate ($gps->flat_track) {
		if ($wpt_candidate->Accuracy <= $accuracy_level) {
		    return $wpt_candidate;
		}
	    }
	    undef;
	}->();
	if ($wpt) {
	    my($x,$y) = map { int } $Karte::map{"polar"}->map2map($main::coord_system_obj, $wpt->Longitude, $wpt->Latitude);
	    my($x0,$y0) = ($main::coord_system eq 'standard' ? ($x,$y) : map { int } $Karte::map{"polar"}->map2standard($wpt->Longitude, $wpt->Latitude));
	    my $tcoords = [[]];
	    $tcoords->[0][0] = [ transpose($x0, $y0) ];
	    main::mark_point(-coords => $tcoords,
			     -clever_center => 1);
	}
    }

    };
    my $err = $@;
    main::DecBusy($top);
    if ($err) {
	main::status_message($err,'error');
	return;
    }

    if ($draw_gpsman_data_p) {
	my $real_outfile = my $outfile = "$tmpdir/$base-gpspoints.bbd";
	if ($main::edit_mode || $main::edit_normal_mode) {
	    # See above
	    $real_outfile = $outfile . "-orig";
	}
	$s->set_global_directives({
				   'listing_sort' => ['unsorted'],
				  });
	$s->write($real_outfile);
	my %args;
	if ($draw_point_names) {
	    $args{NameDraw} = 1;
	}
	$args{Width} = [7, 8, 10, 14, 18, 25]->[main::get_index_by_scale($main::scale)]; # XXX width is fixed and does not change on zooming XXX
	my $abk = main::plot_layer('p',$outfile, %args);
	$plotted_layer_info->{"p-$abk"}++ if defined $abk;
    }
}

# XXX should be rewritten to just draw ONE graph/toplevel
# XXX draw_track_all_graphs should just iterate over all types to draw
sub BBBikeGPS::draw_track_graph {
    my($o) = @_;
    my $top = $o->{-top} || die "-top missing";
    my $add_wpt_prop_ref = $o->{-wpt};
    return if !@$add_wpt_prop_ref;

    my $limit_ref = $o->{-limitref};
    my $peak_ref  = $o->{-peakref};
    my $smooth_ref = $o->{-smoothref};
    my $accuracy_level = $o->{-accuracylevel};
    my $against = $o->{-against}; # XXX only to be used if also -type is set!
    my $pos2vehicle = $o->{-pos2vehicle};

    my %unit = (speed => "km/h",
		grade => "%",
		alt => "m",
		dist => "km",
		wholedist => "km",
		time => "h",
	       );

    my %types;
    if ($o->{-type}) {
	if (ref $o->{-type} eq 'ARRAY') {
	    %types = map { ($_ => 1) } @{ $o->{-type} };
	} else {
	    $types{$o->{-type}} = 1;
	}
	delete $o->{-type};
    } else {
	if ($show_track_graph_speed) { $types{"speed"} = 1 }
	if ($show_track_graph_alt)   { $types{"alt"}   = 1 }
	if ($show_track_graph_grade) { $types{"grade"} = 1 }
	if ($show_track_graph_dist_time) { $types{"wholedist"} = 1 }
    }
    my @types = keys %types;
    if (!@types) {
	warn "No graphs to draw!";
	return;
    }

    my $add_wpt_prop_ref_orig = $add_wpt_prop_ref;
    my(%limit_min, %limit_max);
    my(%peak_neg, %peak_pos);
    if ($limit_ref || $peak_ref) {
	if ($limit_ref) {
	    for my $type (@types) {
		($limit_min{$type}, $limit_max{$type}) = @{$limit_ref->{$type}};
		undef $limit_min{$type}
		    if defined $limit_min{$type} && $limit_min{$type} =~ /^\s*$/;
		undef $limit_max{$type}
		    if defined $limit_max{$type} && $limit_max{$type} =~ /^\s*$/;
	    }
	}
	if ($peak_ref) {
	    for my $type (@types) {
		($peak_neg{$type}, $peak_pos{$type}) = @{$peak_ref->{$type}};
		undef $peak_neg{$type}
		    if defined $peak_neg{$type} && $peak_neg{$type} =~ /^\s*$/;
		undef $peak_pos{$type}
		    if defined $peak_pos{$type} && $peak_pos{$type} =~ /^\s*$/;
	    }
	}
	require Storable;
	$add_wpt_prop_ref = Storable::dclone($add_wpt_prop_ref_orig);
    }
    if (!$smooth_ref) { $smooth_ref = {} }
    foreach my $type (@types) {
	if (!$smooth_ref->{$type}) { $smooth_ref->{$type} = 5 }
    }

    my(%max, %min);
    my $inx = 0;
    foreach (@$add_wpt_prop_ref) {
	for my $type (@types) {
	    my $val = $_->$type();
	    if (defined $accuracy_level && $_->accuracy > $accuracy_level) {
		$_->$type(undef);
	    } elsif (defined $limit_min{$type} && $val < $limit_min{$type}) {
		$_->$type(undef);
	    } elsif (defined $limit_max{$type} && $val > $limit_max{$type}) {
		$_->$type(undef);
	    } else {
		if (defined $peak_neg{$type} && $inx > 0 && $inx < $#$add_wpt_prop_ref
		    && $val < $add_wpt_prop_ref->[$inx-1]->$type()-$peak_neg{$type}
		    && $val < $add_wpt_prop_ref->[$inx+1]->$type()-$peak_neg{$type}) {
		    $_->$type(undef);
		} elsif (defined $peak_pos{$type} && $inx > 0 && $inx < $#$add_wpt_prop_ref
			 && $val > $add_wpt_prop_ref->[$inx-1]->$type()+$peak_pos{$type}
			 && $val > $add_wpt_prop_ref->[$inx+1]->$type()+$peak_pos{$type}) {
		    $_->$type(undef);
		} elsif (defined $val) {
		    $max{$type} = $val if !defined $max{$type} || $val > $max{$type};
		    $min{$type} = $val if !defined $min{$type} || $val < $min{$type};
		    if ($type eq 'alt') {
			$max{'grade'} = $_->grade if defined $_->grade && (!defined $max{'grade'} || $_->grade > $max{'grade'});
			$min{'grade'} = $_->grade if defined $_->grade && (!defined $min{'grade'} || $_->grade < $min{'grade'});
		    }
		}
	    }
	}
    } continue { $inx++ }

    @types = grep {
	if (defined $min{$_} and defined $max{$_}) {
	    1;
	} else {
	    warn "Cannot draw graph type $_, no suitable data (e.g. gps time was not recorded)";
	    0;
	}
    } @types;
    return if !@types;

    my %against;

    for my $type (@types) {
	if ($against) {
	    $against{$type} = $against;
	} else {
	    my $tl_name = "trackgraph-$type";
	    if ($type eq 'wholedist') {
		$against{$type} = 'time'; # dist is meaningless here
	    } elsif (Tk::Exists($main::toplevel{$tl_name})) {
		my $tl = $main::toplevel{$tl_name};
		$against{$type} = $tl->{against};
	    } else {
		$against{$type} = "dist";
	    }
	}
    }

    my %whole_what;
    my %max_x;

    for my $type (@types) {
        $whole_what{$type} = "whole" . $against{$type};
	my $whole_what = $whole_what{$type};
	# Find maximum x, but ignore undefined (=inaccurate) points at
	# the end
	for(my $i=$#$add_wpt_prop_ref; $i>=0; $i--) {
	    my $max_x = $add_wpt_prop_ref->[$i]->$whole_what();
	    if (defined $max_x) {
		$max_x{$type} = $max_x;
		last;
	    }
	}
	if (!defined $max_x{$type}) {
	    warn "WARN: undefined \$max_x for '$type', things will probably break..."; # XXX
	}
    }

    if (defined $limit_min{'alt'} || defined $limit_max{'alt'}) {
	for my $i (1 .. $#$add_wpt_prop_ref) {
	    if (!defined $add_wpt_prop_ref->[$i]->alt) {
		$add_wpt_prop_ref->[$i]->grade(undef);
		if ($i < $#$add_wpt_prop_ref) {
		    $add_wpt_prop_ref->[$i+1]->grade(undef);
		}
	    }
	}
    }

    my %delta;
    for my $type (@types) {
	$delta{$type} = $max{$type}-$min{$type};
    }

    my $def_c_h = 300;
    my $def_c_w = 488;
    my $def_c_x = 26;
    my $def_c_top = 5;
    my $def_c_bottom = 13;

    my(%graph_t, %graph_c, %c_x, %c_h, %c_w, %redraw_cb);

    foreach my $_type (@types) {
	my $type = $_type;
	my $tl_name = "trackgraph-$type";
	if (Tk::Exists($main::toplevel{$tl_name})) {
	    my $tl = $graph_t{$type} = $main::toplevel{$tl_name};
	    $graph_c{$type} = $tl->{Graph};
	    $graph_c{$type}->delete("all");
	    $tl->deiconify;
	    $tl->raise;

	    $c_w{$type} = $graph_c{$type}->width - $def_c_x*2;
	    $c_h{$type} = $graph_c{$type}->height - $def_c_top - $def_c_bottom;

	    $tl->{o} = $o;
	    $tl->{against} = $against{$type};
	} else {
	    my $tl = $graph_t{$type} = $top->Toplevel(-title => "Graph $type");
	    $tl->transient($top)
		unless defined $main::transient && !$main::transient;
	    $main::toplevel{$tl_name} = $tl;

	    $tl->{o} = $o;
	    $tl->{against} = $against{$type};

	    my $f = $tl->Frame->pack(-fill => 'x', -side => "bottom");
	    my $fg = $tl->Frame->pack(-fill => 'x', -side => "bottom");

	    $c_w{$type} = $def_c_w;
	    $c_h{$type} = $def_c_h;
	    $graph_c{$type} = $tl->Canvas(-height => $c_h{$type}+$def_c_top+$def_c_bottom, -width => $c_w{$type}+$def_c_x*2)->pack(-fill => "both", -expand => 1);
	    if ($main::balloon) {
		$main::balloon->attach($graph_c{$type}, -balloonposition => 'mouse',
				       -msg => { "$type-average" => M"Durchschnitt",
						 "$type-smooth"  => M"gegl�ttete Linie",
					       });
	    }
	    $tl->{Graph} = $graph_c{$type};

	    my($min,$max);
	    my($peak_neg, $peak_pos);

	    if ($limit_ref && $limit_ref->{$type}) {
		($min, $max) = @{ $limit_ref->{$type} };
	    }
	    if (!$limit_ref) {
		$limit_ref = {};
	    }
	    if (!$limit_ref->{$type}) {
		$limit_ref->{$type} = [];
	    }

	    if ($peak_ref && $peak_ref->{$type}) {
		($peak_neg, $peak_pos) = @{ $peak_ref->{$type} };
	    }
	    if (!$peak_ref) {
		$peak_ref = {};
	    }
	    if (!$peak_ref->{$type}) {
		$peak_ref->{$type} = [];
	    }

	    $f->Label(-text => M"Min")->pack(-side => "left");
	    $f->Entry(-textvariable => \$min, -width => 4)->pack(-side => "left");
	    $f->Label(-text => M"Max")->pack(-side => "left");
	    $f->Entry(-textvariable => \$max, -width => 4)->pack(-side => "left");
	    $f->Label(-text => M"untere Spitzen")->pack(-side => "left");
	    $f->Entry(-textvariable => \$peak_neg, -width => 4)->pack(-side => "left");
	    $f->Label(-text => M"obere Spitzen")->pack(-side => "left");
	    $f->Entry(-textvariable => \$peak_pos, -width => 4)->pack(-side => "left");
	    $redraw_cb{$type} = sub {
		$limit_ref->{$type} = [$min,$max];
		$peak_ref->{$type} = [$peak_neg,$peak_pos];
		$tl->{o}->{-limitref} = $limit_ref;
		$tl->{o}->{-peakref} = $peak_ref;
		$tl->{o}->{-smoothref} = $smooth_ref;
		$tl->{o}->{-type} = $type;
		# Cannot use $o here, probably because of lexical binding issues
		BBBikeGPS::draw_track_graph($tl->{o});
	    };
	    $f->Button(-text => M"Neu zeichnen",
		       -command => $redraw_cb{$type},
		      )->pack(-side => "left");

	    $fg->Label(-text => M"Gl�tten")->pack(-side => "left");
	    $fg->Entry(-textvariable => \$smooth_ref->{$type}, -width => 4)->pack(-side => "left");
#XXX del not needed anymore with the discovery of -state=>"disabled"
# 	    $fg->Button(-text => M"Gegl�ttete oben",
# 			-command => sub {
# 			    $graph_c{$type}->raise("$type-smooth");
# 			}
# 		       )->pack(-side => "left");
# 	    $fg->Button(-text => M"Gegl�ttete unten",
# 			-command => sub {
# 			    $graph_c{$type}->lower("$type-smooth");
# 			}
# 		       )->pack(-side => "left");
	    if ($type ne 'wholedist') { # "Nach Strecke plotten" is meaningless for wholedist
		my($against_b, @conf_time, @conf_dist);
		$against_b = $fg->Button->pack(-side => "left");
		@conf_time = (-text => M"Nach Zeit plotten",
			      -command => sub {
				  $against_b->configure(@conf_dist);
				  $tl->{o}->{-against} = "time";
				  $redraw_cb{$type}->();
			      });
		@conf_dist = (-text => M"Nach Strecke plotten",
			      -command => sub {
				  $against_b->configure(@conf_time);
				  $tl->{o}->{-against} = "dist";
				  $redraw_cb{$type}->();
			      });
		$against_b->configure
		    ($against{$type} eq 'dist' ? @conf_time : @conf_dist);
	    }

	    # Redraw automatically on resize
	    # Be careful, because <Configure> is fired multiple times on
	    # a resize, and also on other toplevel-related events like
	    # repositions or raise/lower events.
	    {
		$tl->update; # fix geometry
		my($tl_w, $tl_h)         = ($tl->width, $tl->height);
		my($new_tl_w, $new_tl_h) = ($tl_w, $tl_h);
		my $while_resizing_after;
		$tl->bind("<Configure>" => sub {
			      ($new_tl_w, $new_tl_h) = ($tl->width, $tl->height);
			      return if $while_resizing_after;
			      $while_resizing_after = $tl->after
				  (500, sub {
				       if ($new_tl_w != $tl_w ||
					   $new_tl_h != $tl_h) {
					   #warn " geometry changed ... should redraw";
					   $redraw_cb{$type}->();
					   $tl->update;
					   ($tl_w, $tl_h) = ($tl->width, $tl->height);
				       }
				       undef $while_resizing_after;
				   });
			  });
	    }
	}

	# fix room for y scale labels
	$c_x{$type} = $def_c_x;
	if ($limit_ref && $limit_ref->{$type}) {
	    my $test_item = $graph_c{$type}->createText(0,0,-text => $limit_ref->{$type}->[1]);
	    my(@bbox) = $graph_c{$type}->bbox($test_item);
	    if ($bbox[2]-$bbox[0] > $def_c_x) {
		$c_x{$type} = $bbox[2]-$bbox[0];
		$graph_c{$type}->configure(-width => $c_w{$type}+$c_x{$type}*2);
	    }
	    $graph_c{$type}->delete($test_item);
	}
    }

    for my $type (@types) {
	# first the scales
	my $min   = $min{$type};
	my $max   = $max{$type};
	my $delta = $delta{$type};
	my $c_x = $c_x{$type};
	my $c_w = $c_w{$type};
	my $c_h = $c_h{$type};

	# Y axis ##################################################
	my $min_y_cooked;
	my $max_y_cooked;
	if ($unit{$type} eq 'km') {
	    $min_y_cooked = $min/1000;
	    $max_y_cooked = $max/1000;
	} else {
	    $min_y_cooked = $min;
	    $max_y_cooked = $max;
	}
	my $delta_cooked = $max_y_cooked - $min_y_cooked;
	my $tic = BBBikeGPS::make_tics($min_y_cooked, $max_y_cooked);
	my @tics;
	for (my $val = 0; $val <= $max_y_cooked; $val+=$tic) { push @tics, $val }
	if ($min < 0) {
	    for (my $val = -$tic; $val >= $min_y_cooked; $val-=$tic) { unshift @tics, $val }
	}

	for my $val (@tics) {
	    my $y = $def_c_top + $c_h-( ($c_h/$delta_cooked)*($val-$min_y_cooked));
	    $graph_c{$type}->createLine($c_x-2, $y, $c_x+2, $y, -fill => "blue");
	    $graph_c{$type}->createLine($c_x+2, $y, $c_x+$c_w, $y, -dash => '. ', -fill => "blue");
	    $graph_c{$type}->createText($c_x-2, $y, -text => $val, -anchor => "e", -fill => "blue");
	}

	$graph_c{$type}->createText(0, 0, -anchor => "nw", -text => $unit{$type}, -fill => "blue");

	# X axis ##################################################
	my $max_x_cooked;
	my $x_unit;
	if ($against{$type} eq 'dist') {
	    $max_x_cooked = $max_x{$type}/1000;
	    $x_unit = "km";
	} else {
	    if ($max_x{$type} < 2*60*60) {
		$max_x_cooked = $max_x{$type}/60;
		$x_unit = "min";
	    } else {
		$max_x_cooked = $max_x{$type}/3600;
		$x_unit = "h";
	    }
	}
	my $xtic = BBBikeGPS::make_tics(0, $max_x_cooked);
	my @xtics;
	for (my $val = 0; $val <= $max_x_cooked; $val+=$xtic) {
	    push @xtics, $val;
	}

	$graph_c{$type}->createText($c_w+$def_c_x, $c_h+$def_c_top, -anchor => "ne", -text => $x_unit, -fill => "blue");

	for my $val (@xtics) {
	    my $x = $c_x + ($c_w/($max_x_cooked))*$val;
	    last if $x+25 >= $c_w+$def_c_x; # do not overwrite unit label (25 pixels should fit for at least two digits)
	    $graph_c{$type}->createText($x, $c_h+$def_c_top, -anchor => "n", -text => $val, -fill => "blue");
	}
    }

    for my $type (@types) {
	next if $type ne "speed";
	# Draw average line
	my(%last_x, %last_y);
	foreach (@$add_wpt_prop_ref) {
	    next if !defined $_->$type(); # below accuracy level
	    my $time = $_->wholetime;
	    if ($time) {
		my $whole_dist = $_->wholedist;
		my $whole = ($against{$type} eq 'dist' ? $whole_dist : $time); # plot against dist or time
		my $val = $whole_dist/$time*3.6; # speed
		next if !$max_x{$type};
		my $x = $c_x{$type} + ($c_w{$type}/$max_x{$type})*$whole;
		if (defined $last_x{$type}) {
		    if (defined $val && $delta{$type}) {
			my $y = $def_c_top + $c_h{$type}-( ($c_h{$type}/$delta{$type})*($val-$min{$type}));
			if (defined $last_y{$type}) {
			    $graph_c{$type}->createLine
				($last_x{$type}, $last_y{$type}, $x, $y,
				 -fill => "green3",
				 -state => "disabled",
				 -tags => "$type-average");
			}
			$last_y{$type} = $y;
		    }
		}
		$last_x{$type} = $x;
	    }
	}
    }

    {
	# now the graphs
	my(%last_y, %last_x);
	foreach (@$add_wpt_prop_ref) {
	    my $coord = $_->coord;
	    for my $type (@types) {
		my $whole_what = $whole_what{$type};
		my $whole = $_->$whole_what();
		my $val = $_->$type();
		my $x = defined $whole ? $c_x{$type} + ($c_w{$type}/$max_x{$type})*$whole : undef;

		if (defined $last_x{$type}) {
		    if (defined $val) {
			my $y = $def_c_top + $c_h{$type}-( ($c_h{$type}/$delta{$type})*($val-$min{$type}));
			if (defined $last_y{$type}) {
			    $graph_c{$type}->createLine
				($last_x{$type}, $last_y{$type}, $x, $y,
				 -activefill => "blue",
				 -tags => [$type, "$type-$coord"]);
			}
			$last_y{$type} = $y;
		    }
		}
		$last_x{$type} = $x;
	    }
	}
    }

    {
	# smooth graphs
	# XXX use dist and legtime instead!!!
	for my $type (@types) {
	    my $whole_what = $whole_what{$type};
	    my $last;
	    my $last_x;
	    my $smooth_i = $smooth_ref->{$type};
	    my($sum, $sum_dist, $count) = (0, 0, 0);
	    for my $i (0 .. $smooth_i-1) {
		my $val = $add_wpt_prop_ref->[$i]->$type();
		my $dist  = $add_wpt_prop_ref->[$i]->dist;
		if (defined $val) {
		    $sum+=$val;
		    $sum_dist+=$dist;
		    $count++;
		}
	    }

	    for my $inx (0 .. $#$add_wpt_prop_ref-$smooth_i) {
		if ($inx > 0) {
		    my $first_old = $add_wpt_prop_ref->[$inx-1]->$type();
		    if (defined $first_old) {
			$sum-=$first_old;
			$count--;
		    }
		    my $new = $add_wpt_prop_ref->[$inx+$smooth_i-1]->$type();
		    if (defined $new) {
			$sum+=$new;
			$count++;
		    }
		}
		my $whole = $add_wpt_prop_ref->[$inx+$smooth_i/2]->$whole_what();
		if ($count) {
		    my $val = $sum/$count;
		    my $x = defined $whole? $c_x{$type} + ($c_w{$type}/$max_x{$type})*$whole : undef;
		    if (defined $last_x) {
			my $y = $def_c_top + $c_h{$type}-( ($c_h{$type}/$delta{$type})*($val-$min{$type}));
			if (defined $last && defined $x) {
			    $graph_c{$type}->createLine($last_x, $last, $x, $y,
							-fill => 'red',
							-state => "disabled",
							-tags => "$type-smooth",
						       );
			}
			$last = $y;
		    }
		    $last_x = $x;
		}
	    }
	}
    }

    {
	# vehicle boxes
	if ($pos2vehicle && @$pos2vehicle) {
	    require GPS::GpsmanData::VehicleInfo;
	    for my $type (@types) {
		my $whole_what = $whole_what{$type};
		for my $i (1 .. $#$pos2vehicle) {
		    my $def0 = $pos2vehicle->[$i-1];
		    my $def1 = $pos2vehicle->[$i];
		    my $whole0 = $def0->{$whole_what};
		    my $whole1 = $def1->{$whole_what};
		    if (defined $whole0 && defined $whole1) {
			my $vehicle = $def0->{vehicle};
			my $color = GPS::GpsmanData::VehicleInfo::get_vehicle_color($vehicle);
			if (defined $color) {
			    $color = BBBikeGPS::_make_lighter_color($color);
			    my $x0 = $c_x{$type} + ($c_w{$type}/$max_x{$type})*$whole0;
			    my $x1 = $c_x{$type} + ($c_w{$type}/$max_x{$type})*$whole1;
			    $graph_c{$type}->createRectangle($x0, $def_c_top, $x1, $def_c_top+$c_h{$type}, -fill => $color, -outline => $color, -tags => 'vehiclebox');
			    $graph_c{$type}->lower('vehiclebox');
			}
		    }
		}
	    }
	}
    }

    # bind <1> to mark point
    foreach (@types) {
	my $type = $_;
	$graph_c{$type}->bind
	    ($type, "<1>" => sub {
		 my(@tags) = $graph_c{$type}->gettags("current");
		 (my $coord = $tags[1]) =~ s/$type-//;
		 my($x,$y) = main::transpose(split /,/, $coord);
		 main::mark_point(-x => $x, -y => $y,
				  -clever_center => 1);
	     });
    }
}

# XXX Maybe should be moved to a utility module? Or use a CPAN module?
sub BBBikeGPS::_make_lighter_color {
    my $color = shift; # expected an X11 color
    my($r,$g,$b);
    if (eval { require Imager::Color; 1 }) {
	my $ic = Imager::Color->new($color);
	my($h,$s,$v) = $ic->hsv;
	$s = 0.2*$v; # make more 'greyish', # map [0 -> 0; 0 -> 0.2]
	$v = 0.2*$v+0.8; # make brighter: # map [0 -> 0.8; 1 -> 1]
	$ic = Imager::Color->new(hsv=>[$h,$s,$v]);
	($r,$g,$b) = $ic->rgba;
    } else {
	# Simple fallback
	my $tk = (Tk::MainWindow::Existing())[0]; # pick a random Tk window
	my($r,$g,$b) = $tk->rgb($color);
	my $by = 32*4;
	($r,$g,$b) = map { ( $_ + $by > 255) ? 255 : $_ + $by  } ($r, $g, $b);
    }
    sprintf '#%02x%02x%02x', $r, $g, $b;
}

package BBBikeGPS;

# i18n functions M and Mfmt
BEGIN {
    *M = \&main::M;
    *Mfmt = \&main::Mfmt;
}

use BBBikeTkUtil qw(pack_buttonframe);

# From Tk::Plot (mine)
sub make_tics {
    my($tmin, $tmax, $logscale, $base_log) = @_;

    require Math::Complex;

    my $xr = abs($tmin - $tmax);
    my $l10 = Math::Complex::log10($xr);

    my($tic, $tics);
    if ($logscale) {
	$tic = dbl_raise($base_log, ($l10 >= 0 ? int($l10) : int($l10)-1));
	if ($tic < 1.0) {
	    $tic = 1.0;
	}
    } else {
	my $xnorm = 10 ** ($l10 - ($l10 >= 0 ? int($l10) : int($l10)-1));
	if ($xnorm <= 2) {
	    $tics = 0.2;
	} elsif ($xnorm <= 5) {
	    $tics = 0.5;
	} else {
	    $tics = 1.0;
	}
	$tic = $tics * dbl_raise(10.0, ($l10 >= 0 ? int($l10) : int($l10)-1));
    }

    $tic;
}

sub dbl_raise {
    my($x, $y) = @_;

    my $val = 1;
    my $i;
    for($i = 0; $i < abs($y); $i++) {
	$val *= $x;
    }

    if ($y < 0) {
	1/$val;
    } else {
	$val;
    }
}

# Caches
use vars qw($old_route_info_name $old_route_info_number $old_route_info_wpt_suffix $old_route_info_wpt_suffix_existing);
$old_route_info_wpt_suffix_existing=1;

# $self is NOT a BBBikeGPS object here, but GPS::DirectGarmin or so...
sub tk_interface {
    my($self, %args) = @_;
#XXX    return 1 if $args{-test}; # comment out if also testing wptsuffix
    my $top = $args{-top} or die "-top arg is missing";
    my $gps_route_info = $args{-gpsrouteinfo} or die "-gpsrouteinfo arg is missing";
    my $oklabel = $args{-oklabel};
    my $file = delete $args{-file}; # only set if saving into a file
    my $uniquewpts = exists $args{-uniquewpts} ? delete $args{-uniquewpts} : 0;

    if (!defined $gps_route_info->{Name} || $gps_route_info->{Name} eq '') {
	# use filename, if existing
	if (defined $file && $file ne '') {
	    require File::Basename;
	    my $base = File::Basename::basename($file);
	    $base =~ s{\.[^.]+$}{}; # remove suffix, if any
	    $gps_route_info->{Name} = $base;
	} elsif ($old_route_info_name) {
	    $gps_route_info->{Name} = $old_route_info_name;
	}
    }
    $gps_route_info->{Name} = substr($gps_route_info->{Name}, 0, $main::gps_routenamelength)
	if length $gps_route_info->{Name} > $main::gps_routenamelength;

    $gps_route_info->{Number} ||= $old_route_info_number if defined $old_route_info_number;
    $gps_route_info->{WptSuffix} ||= $old_route_info_wpt_suffix if defined $old_route_info_wpt_suffix;
    $gps_route_info->{WptSuffixExisting} ||= $old_route_info_wpt_suffix_existing if defined $old_route_info_wpt_suffix_existing;
    my $t = $top->Toplevel(-title => "GPS");
    $t->transient($top) if $main::transient;
    Tk::grid($t->Label(-text => M"Name der Route"),
	     my $e = $t->Entry(-textvariable => \$gps_route_info->{Name},
			       -validate => 'all',
			       -vcmd => sub { length $_[0] <= $main::gps_routenamelength }),
	     -sticky => "w");
    $e->focus;
    my $NumEntry = 'Entry';
    my @NumEntryArgs = ();
    if (eval { require Tk::NumEntry }) {
	$NumEntry = "NumEntry";
	@NumEntryArgs = (-minvalue => 1, -maxvalue => 20);
    }
    if ($main::gps_needuniqueroutenumber) {
	Tk::grid($t->Label(-text => M"Routennummer"),
		 $t->$NumEntry(-textvariable => \$gps_route_info->{Number},
			       @NumEntryArgs,
			       -validate => 'all',
			       -vcmd => sub { $_[0] =~ /^\d*$/ }),
		 -sticky => "w");
    }
    if ($uniquewpts) {
	Tk::grid($t->Label(-text => M"Waypoint-Suffix"),
		 $t->Entry(-textvariable => \$gps_route_info->{WptSuffix}),
		 -sticky => "w");
	Tk::grid($t->Checkbutton(-text => M"Suffix nur bei vorhandenen Waypoints verwenden",
				 -variable => \$gps_route_info->{WptSuffixExisting}),
		 -sticky => "w", -columnspan => 2);
	if ($self->can('reset_waypoint_cache')) {
	    Tk::grid($t->Button(-text => M"Waypoints-Cache zur�cksetzen",
				-command => sub {
				    $self->reset_waypoint_cache;
				}),
		     -sticky => "w", -columnspan => 2);
	}
    } else {
	$gps_route_info->{WptSuffix} = '';
	$gps_route_info->{WptSuffixExisting} = 0;
    }
    if ($self->has_gps_settings && defined &main::optedit) {
	Tk::grid($t->Button(-text => M"GPS-Einstellungen",
			    -command => sub {
				main::optedit(-page => M"GPS");
			    }),
		 -sticky => "w", -columnspan => 2);
    }
    my $weiter = 0;
    {
	my $f = $t->Frame->grid(-columnspan => 2, -sticky => "ew");
	my $okb = $f->Button(-text => ($args{-test} ?
				       $self->ok_test_label :
				       $self->ok_label),
			     -command => sub { $weiter = 1 },
			     -default => 'active',
			    );
	my $cb = $f->Button(Name => "cancel",
			    -text => M"Abbruch",
			    -command => sub { $weiter = -1 });
	pack_buttonframe($f, [$okb, $cb]);
	$t->bind('<<CloseWin>>' => sub { $cb->invoke });
	$e->bind('<Return>' => sub { $okb->invoke });
    }
    $t->gridColumnconfigure($_, -weight => 1) for (0..1);
    $t->OnDestroy(sub { $weiter = -1 });
    $t->waitVariable(\$weiter);
    $t->afterIdle(sub { if (Tk::Exists($t)) { $t->destroy } });

    if ($weiter == 1) {
	$old_route_info_name = $gps_route_info->{Name};
	$old_route_info_number = $gps_route_info->{Number};
	$old_route_info_wpt_suffix = $gps_route_info->{WptSuffix};
	$old_route_info_wpt_suffix_existing = $gps_route_info->{WptSuffixExisting};
    }

    return undef if $weiter == -1;
    1;
}

{
    package GPS::BBBikeGPS::GpsmanRoute;
    require GPS;
    push @GPS::BBBikeGPS::GpsmanRoute::ISA, 'GPS';
    
    sub default_extension { ".rte" }

    sub has_gps_settings { 0 }

    sub ok_label { "Speichern der Route" } # XXX M/Mfmt

    sub tk_interface {
	my($self, %args) = @_;
	BBBikeGPS::tk_interface($self, %args);
    }

    sub convert_from_route {
	my($self, $route, %args) = @_;
	require GPS::GpsmanData;
	require Route::Simplify;
	my $simplified_route = $route->simplify_for_gps(
	    -uniquewpts => 1, # gpsman wants non-empty and unique waypoint names
	    %args
	);
	my $gd = GPS::GpsmanData->new;
	$gd->change_position_format("DDD");
	$gd->Type(GPS::GpsmanData::TYPE_ROUTE());
	$gd->Name($simplified_route->{routename});
	for my $wpt (@{ $simplified_route->{wpt} }) {
	    my $gpsman_wpt = GPS::Gpsman::Waypoint->new;
	    $gpsman_wpt->Ident($wpt->{ident});
	    $gpsman_wpt->Latitude($wpt->{lat});
	    $gpsman_wpt->Longitude($wpt->{lon});
	    # XXX void (null_2) und transient (null) wird vom etrex vista hcx nicht erkannt
	    my $symbol = ($wpt->{importance} > 0 ? 'flag_pin_blue' : # XXX or summit?
			  $wpt->{importance} < 0 ? 'small_city' :
			  'small_city'
			 );
	    $gpsman_wpt->Symbol($symbol);
	    $gpsman_wpt->HiddenAttributes({'GD110:class'=>'|C$'}); # XXX setting waypoint class to 0x80 (map point waypoint)
	    							   # XXX There should be better support in Gps::GpsmanData for this
	    $gd->push_waypoint($gpsman_wpt);
	}
	$gd->as_string;
    }

}

{
    package GPS::BBBikeGPS::GPXRoute;
    require GPS;
    push @GPS::BBBikeGPS::GPXRoute::ISA, 'GPS';
    
    sub default_extension { ".gpx" }

    sub has_gps_settings { 0 }

    sub ok_label { "Speichern der Route" } # XXX M/Mfmt

    sub tk_interface {
	my($self, %args) = @_;
	BBBikeGPS::tk_interface($self, %args);
    }

    sub convert_from_route {
	my($self, $route, %args) = @_;
	require Route::Simplify;
	require Strassen::Core;
	require Strassen::GPX;
	my $simplified_route = $route->simplify_for_gps(%args);
	my $s = Strassen::GPX->new;
	$s->set_global_directives({ map => ["polar"] });
	for my $wpt (@{ $simplified_route->{wpt} }) {
	    $s->push([$wpt->{ident}, [ join(",", $wpt->{lon}, $wpt->{lat}) ], "X" ]);
	}
	$s->bbd2gpx(-as => "route",
		    -name => $simplified_route->{routename},
		    -number => $args{-routenumber},
		   );
    }

}

{
    package GPS::BBBikeGPS::GpsbabelSend;
    require GPS;
    push @GPS::BBBikeGPS::GpsbabelSend::ISA, 'GPS';
    
    sub has_gps_settings { 1 }

    sub transfer_to_file { 0 }

    sub ok_label { "Upload zum Garmin" } # M/Mfmt XXX

    sub tk_interface {
	my($self, %args) = @_;
	BBBikeGPS::tk_interface($self, %args);
    }

    sub convert_from_route {
	my($self, $route, %args) = @_;

	# do not delete the following, needed also in simplify_for_gps
	my $waypointlength = $args{-waypointlength};
	my $waypointcharset = $args{-waypointcharset};

	require File::Temp;
	require GPS::Gpsbabel;
	require Route::Simplify;
	require Strassen::Core;
	require Strassen::GPX;
	my $simplified_route = $route->simplify_for_gps(%args, -uniquewpts => 0);
	my $s = Strassen::GPX->new;
	$s->set_global_directives({ map => ["polar"] });
	for my $wpt (@{ $simplified_route->{wpt} }) {
	    $s->push([$wpt->{ident}, [ join(",", $wpt->{lon}, $wpt->{lat}) ], "X" ]);
	}
	my($ofh,$ofile) = File::Temp::tempfile(SUFFIX => ".gpx",
					       UNLINK => 1);
	main::status_message("Could not create temporary file: $!", "die") if !$ofh;
	print $ofh $s->bbd2gpx(-as => "route",
			       -name => $simplified_route->{routename},
			       -number => $args{-routenumber},
			       #-withtripext => 1,
			      );
	close $ofh;
	my $gpsb = GPS::Gpsbabel->new;
	my $dev = !$args{'-gpsdevice'} || $args{'-gpsdevice'} =~ /usb/i ? "usb:" : $args{'-gpsdevice'};
	my $output_type = join(",", "garmin",
			       ($waypointlength ? "snlen=$waypointlength" : ()),
			       ($waypointcharset && $waypointcharset ne 'simpleascii' ? "snwhite=1" : ()),
			      );
	$gpsb->run_gpsbabel(["-r",
			     "-i", "gpx", "-f", $ofile,
			     "-o", $output_type, "-F", $dev,
			    ]);
    }

    sub transfer { } # NOP

}

{
    package GPS::BBBikeGPS::MapSourceSend;
    require GPS;
    push @GPS::BBBikeGPS::MapSourceSend::ISA, 'GPS';
    
    sub transfer_to_file { 0 }

    sub mapsource_path {
	# XXX Look into registry
	# (HKEY_LOCAL_MACHINE\SOFTWARE\Garmin\Applications\MapSource,
	# InstallDir)?
	'C:\Garmin\MapSource.exe'
    }

    sub has_mapsource {
	-e shift->mapsource_path;
    }

    sub convert_from_route {
	my($self, $route, %args) = @_;

	if (!$self->has_mapsource) {
	    main::status_message("Mapsource is not available on this system.", "error");
	    return;
	}

	require File::Temp;
	require Route::Simplify;
	require Strassen::Core;
	require Strassen::GPX;
	my $simplified_route = $route->simplify_for_gps(%args);
	my $s = Strassen::GPX->new;
	$s->set_global_directives({ map => ["polar"] });
	for my $wpt (@{ $simplified_route->{wpt} }) {
	    $s->push([$wpt->{ident}, [ join(",", $wpt->{lon}, $wpt->{lat}) ], "X" ]);
	}
	my($ofh,$ofile) = File::Temp::tempfile(SUFFIX => ".gpx",
					       UNLINK => 1);
	main::status_message("Could not create temporary file: $!", "die") if !$ofh;
	print $ofh $s->bbd2gpx(-as => "route"
			       -name => $simplified_route->{routename},
			       -number => $args{-routenumber},
			      );
	close $ofh;

	if ($^O eq 'MSWin32') {
	    system(1, $self->mapsource_path, $ofile);
	} else {
	    system($self->mapsource_path, $ofile);
	}
    }

    sub transfer {
	# nothing to do...
    }

}

1;

__END__
