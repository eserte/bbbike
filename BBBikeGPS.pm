# -*- perl -*-

#
# $Id: BBBikeGPS.pm,v 1.8 2003/11/16 21:14:22 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
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

sub BBBikeGPS::gps_interface {
    my($label, $mod) = @_;

    $mod = 'GPS::' . $mod;
    my %extra_args;
    if ($mod =~ s/_Test$//) {
	$extra_args{"-test"} = 1;
    }

    my $modobj;
    eval qq{
	require $mod;
    } . q{
	$modobj = $mod->new;
    };
    if ($@ || !$modobj) {
	if (!$@) {
	    $@ = "\$modobj undefined";
	}
	my $err = $@;
	status_message(Mfmt("Das Modul %s konnte nicht geladen werden. Grund: %s", $mod, $err), "error");
	warn $err;
	return;
    }
    my $file;
    my $gps_route_info = {};
    if ($modobj->transfer_to_file()) {
	$file = $top->getSaveFile(-defaultextension => '.txt');
	return unless defined $file;
    } elsif ($modobj->can("tk_interface")) {
	return if !$modobj->tk_interface(-top => $top,
					 -gpsrouteinfo => $gps_route_info,
					 -test => $extra_args{-test});
    }

    if ($export_txt_mode == EXPORT_TXT_FULL) {
	status_message("Export mode: full", "info");
    } elsif ($export_txt_mode == EXPORT_TXT_SIMPLIFY_NAME) {
	$extra_args{"-routetoname"} = get_act_search_route();
	status_message("Export mode: simplify name", "info");
    } elsif ($export_txt_mode == EXPORT_TXT_SIMPLIFY_ANGLE) {
	# XXX vielleicht einen Mode EXPORT_TXT_SIMPLIFY_AUTO_ANGLE
	# (Kombination aus EXPORT_TXT_SIMPLIFY_ANGLE und
	# EXPORT_TXT_SIMPLIFY_AUTO) einführen
	$extra_args{"-routetoname"} = [StrassenNetz::simplify_route_to_name(get_act_search_route(), -minangle => $export_txt_min_angle)];
	status_message("Export mode: simplify with angle $export_txt_min_angle°", "info");
    } elsif ($export_txt_mode == EXPORT_TXT_SIMPLIFY_NAME_OR_ANGLE) {
	$extra_args{"-routetoname"} =
	    [StrassenNetz::simplify_route_to_name
	     ([$net->route_to_name([@realcoords],-startindex=>0,-combinestreet=>0)],
	      -minangle => $export_txt_min_angle, -samestreet => 1)];
	status_message("Export mode: simplify with angle $export_txt_min_angle° or name", "info");
    } elsif ($export_txt_mode == EXPORT_TXT_SIMPLIFY_AUTO) {
	# XXX besser binäre Suche statt inkrementell
	my $routetoname;
	my $step = 5;
	for(my $tryangle = 5; $tryangle <= 90; $tryangle+=$step) {
	    $routetoname = [StrassenNetz::simplify_route_to_name
			    ([$net->route_to_name([@realcoords],-startindex=>0,-combinestreet=>0)],
			     -minangle => $tryangle, -samestreet => 1)];
	    if (@$routetoname <= $gps_waypoints) {
		status_message("Export simplify mode: auto; using $tryangle° as minimum angle", "info");
		last;
	    }
	    if ($tryangle+$step > $export_txt_min_angle) {
		$step = 15;
	    }
	}
	$extra_args{"-routetoname"} = $routetoname;
    }
    eval {
	my $res = $modobj->convert_from_route
	    (Route->new_from_realcoords(\@realcoords),
	     -streetobj   => $multistrassen || $str_obj{'s'},
	     -netobj      => $net,
	     -routename   => $gps_route_info->{Name},
	     -routenumber => $gps_route_info->{Number},
	     -wptsuffix   => $gps_route_info->{WptSuffix},
	     -wptsuffixexisting => $gps_route_info->{WptSuffixExisting},
	     -gpsdevice   => $gps_device,
	     %extra_args,
	    );
	$modobj->transfer(-file => $file,
			  -res => $res,
			  -test => $extra_args{-test},
			  -top => $top);
    };
    if ($@) {
	status_message
	    (Mfmt("Schreiben auf <%s> nicht möglich: %s", $file, $@), 'err');
    }
}

use vars qw($gpsman_last_dir $gpsman_data_dir);
$gpsman_data_dir = "$FindBin::RealBin/misc/gps_data"
    if !defined $gpsman_data_dir;

use Class::Struct;
struct('PathGraphElem' => [map { ($_ => "\$") }
			   (qw(wholedist wholetime dist time legtime
			       speed alt grade coord accuracy))
			  ]);

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

    my $cfc_top = $top->Toplevel(-title => M"Gpsman-Daten zeichnen");
    $cfc_top->transient($top) if $main::transient;

    use vars qw($draw_gpsman_data_s $draw_gpsman_data_p
		$show_track_graph
		$show_track_graph_speed
		$show_track_graph_alt
		$show_track_graph_grade
		$show_statistics);
    $draw_gpsman_data_s = 1 if !defined $draw_gpsman_data_s;
    $draw_gpsman_data_p = 1 if !defined $draw_gpsman_data_p;
    $show_track_graph = 0   if !defined $show_track_graph;
    $show_track_graph_speed = 1 if !defined $show_track_graph_speed;
    $show_track_graph_alt = 0 if !defined $show_track_graph_alt;
    $show_track_graph_grade = 0 if !defined $show_track_graph_grade;
    $show_statistics = 0    if !defined $show_statistics;

    my $file = $gpsman_last_dir || Cwd::cwd();
    my $weiter = 0;
    $cfc_top->Label(-text => M("Gpsman-Datei").":")->pack(-anchor => "w");
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
	    if (eval { require Tk::DateEntry; 1 }) {
		$can_dateentry = 1;
	    } else {
		$columnspan = 2;
	    }
	    $ff->Button(-text => M"Gpsman-Datenverzeichnis",
			-command => sub { $file = $gpsman_data_dir }
		       )->grid(-row => $row, -column => 0, -sticky => "ew",
			       (defined $columnspan ? (-columnspan => $columnspan) : ()),
			      );
	    if ($can_dateentry) {
		my $date;
		my $de = $ff->DateEntry
		    (-dateformat => 2,
		     -todaybackground => "yellow",
		     -weekstart => 1,
		     -textvariable => \$date,
		     -formatcmd => sub {
			 my($year,$month,$day) = @_;
			 $file = "$gpsman_data_dir/" . sprintf("%04d%02d%02d", $year, $month, $day) . ".trk";
			 "$year/$month/$day";
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
	$ff->Button(-text => M"Track heute",
		    (!-r "$heute.trk" ? (-state => "disabled") : ()),
		    -command => sub { $file = "$heute.trk";
				      $draw_gpsman_data_s = 1;
				      $draw_gpsman_data_p = 0;
				  }
		   )->grid(-row => $row, -column => 0, -sticky => "ew");
	$ff->Button(-text => M"Track gestern",
		    (!-r "$gestern.trk" ? (-state => "disabled") : ()),
		    -command => sub { $file = "$gestern.trk";
				      $draw_gpsman_data_s = 1;
				      $draw_gpsman_data_p = 0;
				  }
		   )->grid(-row => $row, -column => 1, -sticky => "ew");
	$row++;
	$ff->Button(-text => M"Waypoints heute",
		    (!-r "$heute.wpt" ? (-state => "disabled") : ()),
		    -command => sub { $file = "$heute.wpt";
				      $draw_gpsman_data_s = 0;
				      $draw_gpsman_data_p = 1;
				  }
		   )->grid(-row => $row, -column => 0, -sticky => "ew");
	$ff->Button(-text => M"Waypoints gestern",
		    (!-r "$gestern.wpt" ? (-state => "disabled") : ()),
		    -command => sub { $file = "$gestern.wpt";
				      $draw_gpsman_data_s = 0;
				      $draw_gpsman_data_p = 1;
				  }
		   )->grid(-row => $row, -column => 1, -sticky => "ew");
	$row++;
    }
    $f->Button(Name => "ok",
	       -command => sub { $weiter = 1 })->pack(-side => "left");
    $f->Button(-text => "?",
	       -command => sub {
		   my $ht = $f->Toplevel(-title => M("Hilfe"));
		   $ht->transient($f->toplevel);
		   my $msg =
		       $ht->Message(-text => <<EOF)->pack(-fill => "both");
Mit der <TAB>-Taste kann der Dateiname automatisch vervollständigt werden. Gibt es mehrere Vervollständigungen, wird eine klickbare Liste angezeigt. Wenn mehr als zehn Treffer vorhanden sind, werden mit weiteren Druck auf die <TAB>-Taste die nächsten Treffer der Liste angezeigt.
EOF
                   my $okb =
		       $ht->Button(Name => "ok",
				   -command => sub { $ht->destroy })->pack;
		   $okb->focus;
	       })->pack(-side => "left");

    my $f2 = $cfc_top->Frame->pack(-fill => "x", -expand => 1);
    $f2->Checkbutton(-text => M"Strecken zeichnen",
		     -variable => \$draw_gpsman_data_s)->pack(-anchor => "w");
    $f2->Checkbutton(-text => M"Punkte zeichnen",
		     -variable => \$draw_gpsman_data_p)->pack(-anchor => "w");
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
		 $dep[1] = $f3->Checkbutton(-text => M"Höhe",
					    -variable => \$show_track_graph_alt),
		 -sticky => "w");
	Tk::grid($f3->Label,
		 $dep[2] = $f3->Checkbutton(-text => M"Steigung",
					    -variable => \$show_track_graph_grade),
		 -sticky => "w");
	$update_dep->();
    }
    $f2->Checkbutton(-text => M"Statistik zeigen",
		     -variable => \$show_statistics)->pack(-anchor => "w");
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

    my $cfc_file = "$main::bbbike_configdir/speed_color_mapping.cfc";
    my $safe = Safe->new;
    use vars qw($cfc_mapping);
    undef $cfc_mapping;
    $safe->share(qw($cfc_mapping));
    $safe->rdo($cfc_file);
    if (defined $cfc_mapping) {
	$cfc->set_mapping($cfc_mapping);
    }

    $cfc_top->OnDestroy(sub { $weiter = -1 });
    $pe->waitVariable(\$weiter);
    if ($weiter != 1) {
	$cfc_top->destroy if Tk::Exists($cfc_top);
	return;
    }
    $gpsman_last_dir = $file;
    $cfc_mapping = $cfc->get_mapping;
    if (open(D, ">$cfc_file")) {
	print D Data::Dumper->Dumpxs([$cfc_mapping], ['cfc_mapping']);
	close D;
    }
    $cfc_top->destroy;
    $top->update;

    BBBikeGPS::do_draw_gpsman_data($top, $file,
				   -gap => $max_gap,
				   -solidcoloring => $solid_coloring,
				   -drawstreets => $draw_gpsman_data_s,
				   -drawpoints  => $draw_gpsman_data_p,
				   -accuracylevel => $accuracy_level,
				  );

    $file;
}

use vars qw($global_draw_gpsman_data_s $global_draw_gpsman_data_p);
$global_draw_gpsman_data_s = 1 if !defined $global_draw_gpsman_data_s;
$global_draw_gpsman_data_p = 1 if !defined $global_draw_gpsman_data_p;

sub BBBikeGPS::do_draw_gpsman_data {
    my($top, $file, %args) = @_;
    my $max_gap = exists $args{-gap} ? $args{-gap} : DEFAULT_MAX_GAP;
    my $solid_coloring = $args{-solidcoloring};
    my $draw_gpsman_data_s = exists $args{-drawstreets} ? $args{-drawstreets} : $global_draw_gpsman_data_s;
    my $draw_gpsman_data_p = exists $args{-drawpoints} ? $args{-drawpoints} : $global_draw_gpsman_data_p;
    my $accuracy_level = exists $args{-accuracylevel} ? $args{-accuracylevel} : 3;

    my $base;
    my $s;

    require GPS::GpsmanData;

    main::IncBusy($top);
    eval {
    my $gps = GPS::GpsmanData->new;
    $gps->load($file);
    $gps->convert_all("DDD");
    require Karte;
    Karte::preload(qw(Polar));
    require Strassen;
    $s = Strassen->new;
    my $s_speed;
    if ($gps->Type eq GPS::GpsmanData::TYPE_TRACK() && $draw_gpsman_data_s) {
	$s_speed = Strassen->new;
    }
    my $whole_dist = 0;
    my $whole_time = 0;
    my $max_speed = 0;
    my @add_wpt_prop;
    require File::Basename;
    $base = File::Basename::basename($file);
    my $last_wpt;
    foreach my $wpt (@{ $gps->Points }) {
	my($x,$y) = map { int } $Karte::map{"polar"}->map2map($main::coord_system_obj, $wpt->Longitude, $wpt->Latitude);
	my($x0,$y0) = ($main::coord_system eq 'standard' ? ($x,$y) : map { int } $Karte::map{"polar"}->map2standard($wpt->Longitude, $wpt->Latitude));
	my $alt = $wpt->Altitude;
	my $acc = $wpt->Accuracy;
	my $l = [$base . "/" . $wpt->Ident . "/" . $wpt->Comment .
		 (defined $alt ? " alt=".sprintf("%.1fm",$alt) : "") .
		 " long=" . Karte::Polar::dms_human_readable("long", Karte::Polar::ddd2dms($wpt->Longitude)) .
		 " lat=" . Karte::Polar::dms_human_readable("lat", Karte::Polar::ddd2dms($wpt->Latitude)),
		 ["$x,$y"], "#0000a0"];
	$s->push($l);
	if ($s_speed) {
	    my $time = $wpt->Comment_to_unixtime;
	    if (defined $time) {
		if ($last_wpt) {
		    my($last_x,$last_y,$last_x0,$last_y0,$last_time,$last_alt,$last_acc) = @$last_wpt;
		    my $legtime = $time-$last_time;
		    # Do not check for $legtime==0 --- saved tracks do not
		    # have any time at all!
		    if (abs($legtime) < 60*$max_gap) {
			my $dist = sqrt(($x0-$last_x0)**2 + ($y0-$last_y0)**2);
			$whole_dist += $dist;
			$whole_time += $legtime;
			my @l = localtime $time;
			my $speed;
			if ($legtime) {
			    $speed = $dist/($legtime)*3.6;
			}
			my $grade;
			if ($dist != 0 && defined $alt) {
			    $grade = 100*(($alt-$last_alt)/$dist);
			    if (abs($grade) > 10) { # XXX too many wrong values... XXX more intelligent solution
				undef $grade;
			    }
			}

			my $max_acc = max($acc, $last_acc);
			my $path_graph_elem = new PathGraphElem;
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

 			my $color = "#000000";
			if ($max_acc <= $accuracy_level) {
			    if (defined $speed) {
				if (!defined $max_speed || $max_speed < $speed) {
				    $max_speed = $speed;
				}
				if (!$solid_coloring) {
				    $color = $cfc_mapping->{int($speed)};
				}
			    }
			    if (!defined $color) {
				my(@sorted) = sort { $a <=> $b } keys %$cfc_mapping;
				if (defined $speed && $speed <= $sorted[0]) {
				    $color = $cfc_mapping->{$sorted[0]};
				} else {
				    $color = $cfc_mapping->{$sorted[-1]};
				}
			    }
			} elsif ($max_acc >= 2) {
			    #$color = "#e4c8e4"; # GPSs~~ from bbbike
			    $color = "#e2e2e2";
			} else {
			    #$color = "#f4c0f4"; # GPSs~
			    $color = "#eeeeee"; # GPSs~
			}

			{
			    my $name = "";
			    if (defined $speed) {
				$name .= int($speed) . " km/h ";
			    }
			    $name .= "[dist=" . BBBikeUtil::m2km($whole_dist,2) . ",time=" . BBBikeUtil::s2ms($whole_time) . "min" . sprintf(", abstime=%02d:%02d:%02d", @l[2,1,0]) . (defined $grade ? ", grade=" . sprintf("%.1f%%", $grade) : "") . "]";
			    my $c1 = "$last_x,$last_y";
			    my $c2 = "$x,$y";
			    if ($main::coord_prefix) {
				$c1 =  $main::coord_system_obj->coordsys . $c1;
				$c2 =  $main::coord_system_obj->coordsys . $c2;
			    }
			    $s_speed->push([$name, [$c1, $c2], $color]);
			}
		    }
		}
		$last_wpt = [$x,$y,$x0,$y0,$time,$alt,$acc];
	    }
	}
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

	if ($main::edit_mode) {
	    $real_speed_outfile = $speed_outfile . "-orig";
	}
	$s_speed->write($real_speed_outfile);
	main::plot_layer('str',$speed_outfile,-fallbackxxx=>1);
	Hooks::get_hooks("after_new_layer")->execute;
    }

    BBBikeGPS::draw_track_graph({-top => $top,
				 -wpt => \@add_wpt_prop,
				 -accuracylevel => $accuracy_level,
				})
	    if $show_track_graph;
    };
    my $err = $@;
    main::DecBusy($top);
    if ($err) {
	main::status_message($err,'error');
	return;
    }

    if ($draw_gpsman_data_p) {
	my $real_outfile = my $outfile = "$tmpdir/$base-gpspoints.bbd";
	if ($main::edit_mode) {
	    $real_outfile = $outfile . "-orig";
	}
	$s->write($real_outfile);
	main::plot_layer('p',$outfile,-fallbackxxx=>1);
    }
}

sub BBBikeGPS::draw_track_graph {
    my($o) = @_;
    my $top = $o->{-top} || die "-top missing";
    my $add_wpt_prop_ref = $o->{-wpt};
    return if !@$add_wpt_prop_ref;

    my $limit_ref = $o->{-limitref};
    my $peak_ref  = $o->{-peakref};
    my $smooth_ref = $o->{-smoothref};
    my $accuracy_level = $o->{-accuracylevel};
    my $against = $o->{-against} || "dist";

    my %unit = (speed => "km/h",
		grade => "%",
		alt => "m",
		dist => "km",
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

    my $whole_what = "whole" . $against;
    my $max_x = $add_wpt_prop_ref->[-1]->$whole_what();

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
    my $c_y = 5;
    my $def_c_x = 26;

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
	    $c_h{$type} = $graph_c{$type}->height - $c_y*2;
	} else {
	    my $tl = $graph_t{$type} = $top->Toplevel(-title => "Graph $type");
	    $tl->transient($top)
		unless defined $main::transient && !$main::transient;
	    $main::toplevel{$tl_name} = $tl;

	    my $f = $tl->Frame->pack(-fill => 'x', -side => "bottom");

	    $c_w{$type} = $def_c_w;
	    $c_h{$type} = $def_c_h;
	    $graph_c{$type} = $tl->Canvas(-height => $c_h{$type}+$c_y*2, -width => $c_w{$type}+$def_c_x*2)->pack(-fill => "both", -expand => 1);
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
		$o->{-limitref} = $limit_ref;
		$o->{-peakref} = $peak_ref;
		$o->{-smoothref} = $smooth_ref;
		$o->{-type} = $type;
		BBBikeGPS::draw_track_graph($o);
	    };
	    $f->Button(-text => M"Neu zeichnen",
		       -command => $redraw_cb{$type},
		      )->pack(-side => "left");

	    my $fg = $tl->Frame->pack(-fill => 'x', -side => "bottom");
	    $fg->Label(-text => M"Glätten")->pack(-side => "left");
	    $fg->Entry(-textvariable => \$smooth_ref->{$type}, -width => 4)->pack(-side => "left");
	    $fg->Button(-text => M"Geglättete oben",
			-command => sub {
			    $graph_c{$type}->raise("$type-smooth");
			}
		       )->pack(-side => "left");
	    $fg->Button(-text => M"Geglättete unten",
			-command => sub {
			    $graph_c{$type}->lower("$type-smooth");
			}
		       )->pack(-side => "left");
	    {
		my($against_b, @conf_time, @conf_dist);
		$against_b = $fg->Button->pack(-side => "left");
		@conf_time = (-text => M"Nach Zeit plotten",
			      -command => sub {
				  $against_b->configure(@conf_dist);
				  $o->{-against} = "time";
				  $redraw_cb{$type}->();
			      });
		@conf_dist = (-text => M"Nach Strecke plotten",
			      -command => sub {
				  $against_b->configure(@conf_time);
				  $o->{-against} = "dist";
				  $redraw_cb{$type}->();
			      });
		$against_b->configure
		    ($against eq 'dist' ? @conf_time : @conf_dist);
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

##XXX Geht nicht (zuverlässig?)
#      for my $_type (@types) {
#  	my $type = $_type;
#  	$graph_t{$type}->after
#  	    (1000, sub {
#  		 $graph_t{$type}->bind
#  		     ("<Configure>" => sub {
#  			  $graph_t{$type}->bind("<Configure>", "");
#  			  $redraw_cb{$type}->();
#  		      }
#  		     );
#  	     });
#      }


    for my $type (@types) {
	# first the scales
	my $min   = $min{$type};
	my $max   = $max{$type};
	my $delta = $delta{$type};
	my $c_x = $c_x{$type};
	my $c_w = $c_w{$type};
	my $c_h = $c_h{$type};

	# Y axis ##################################################
	my $tic = BBBikeGPS::make_tics($min, $max);
	my @tics;
	for (my $val = 0; $val <= $max; $val+=$tic) { push @tics, $val }
	if ($min < 0) {
	    for (my $val = -$tic; $val >= $min; $val-=$tic) { unshift @tics, $val }
	}

	for my $val (@tics) {
	    my $y = $c_y + $c_h-( ($c_h/$delta)*($val-$min));
	    $graph_c{$type}->createLine($c_x-2, $y, $c_x+2, $y, -fill => "blue");
	    $graph_c{$type}->createLine($c_x+2, $y, $c_x+$c_w, $y, -dash => '. ', -fill => "blue");
	    $graph_c{$type}->createText($c_x-2, $y, -text => $val, -anchor => "e", -fill => "blue");
	}

	$graph_c{$type}->createText(0, 0, -anchor => "nw", -text => $unit{$type}, -fill => "blue");

	# X axis ##################################################
	my $max_x_cooked;
	my $x_unit;
	if ($against eq 'dist') {
	    $max_x_cooked = $max_x/1000;
	    $x_unit = "km";
	} else {
	    if ($max_x < 2*60*60) {
		$max_x_cooked = $max_x/60;
		$x_unit = "min";
	    } else {
		$max_x_cooked = $max_x/3600;
		$x_unit = "h";
	    }
	}
	my $xtic = BBBikeGPS::make_tics(0, $max_x_cooked);
	my @xtics;
	for (my $val = 0; $val <= $max_x_cooked; $val+=$xtic) {
	    push @xtics, $val;
	}

	for my $val (@xtics) {
	    my $x = $c_x + ($c_w/($max_x_cooked))*$val;
	    $graph_c{$type}->createText($x, $c_h, -text => $val, -fill => "blue");

	}

	$graph_c{$type}->createText($c_w, $c_h, -anchor => "e", -text => $x_unit, -fill => "blue");
    }


    if ($against eq 'dist') { # XXX warum geht es mit "time" nicht?
	# XXX comment missing
	my(%last_x, %last_y);
	my $type = "speed";
	foreach (@$add_wpt_prop_ref) {
	    next if !defined $_->$type(); # below accuracy level
	    my $time = $_->wholetime;
	    if ($time) {
		my $whole = $_->wholedist;
		my $val = $whole/$time*3.6; # speed
		my $x = $c_x{$type} + ($c_w{$type}/$max_x)*$whole;

		if (defined $last_x{$type}) {
		    if (defined $val) {
			my $y = $c_y + $c_h{$type}-( ($c_h{$type}/$delta{$type})*($val-$min{$type}));
			if (defined $last_y{$type}) {
			    $graph_c{$type}->createLine
				($last_x{$type}, $last_y{$type}, $x, $y,
				 -fill => "green3",
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
	    my $whole = $_->$whole_what();
	    my $coord = $_->coord;
	    for my $type (@types) {
		my $val = $_->$type();
		my $x = $c_x{$type} + ($c_w{$type}/$max_x)*$whole;

		if (defined $last_x{$type}) {
		    if (defined $val) {
			my $y = $c_y + $c_h{$type}-( ($c_h{$type}/$delta{$type})*($val-$min{$type}));
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
		    my $x = $c_x{$type} + ($c_w{$type}/$max_x)*$whole;
		    if (defined $last_x) {
			my $y = $c_y + $c_h{$type}-( ($c_h{$type}/$delta{$type})*($val-$min{$type}));
			if (defined $last) {
			    $graph_c{$type}->createLine($last_x, $last, $x, $y, -fill => 'red', -tags => "$type-smooth");
			}
			$last = $y;
		    }
		    $last_x = $x;
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

package BBBikeGPS;

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

1;

__END__
