# -*- perl -*-

#
# $Id: BBBikeGPS.pm,v 1.2 2003/06/01 22:14:02 eserte Exp eserte $
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
			       speed alt grade coord))
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
		$show_track_graph $show_statistics);
    $draw_gpsman_data_s = 1 if !defined $draw_gpsman_data_s;
    $draw_gpsman_data_p = 1 if !defined $draw_gpsman_data_p;
    $show_track_graph = 0   if !defined $show_track_graph;
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
	$ff->Button(-text => M"Gpsman-Datenverzeichnis",
		    -command => sub { $file = $gpsman_data_dir }
		   )->grid(-row => $row, -column => 0, -sticky => "ew",
			   -columnspan => 2);
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
    $f2->Checkbutton(-text => M"Graphen zeichnen",
		     -variable => \$show_track_graph)->pack(-anchor => "w");
    $f2->Checkbutton(-text => M"Statistik zeigen",
		     -variable => \$show_statistics)->pack(-anchor => "w");


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
	undef $alt if $alt =~ /^~/; # marked as inexact point
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
		    my($last_x,$last_y,$last_x0,$last_y0,$last_time,$last_alt) = @$last_wpt;
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
			    if (!defined $max_speed || $max_speed < $speed) {
				$max_speed = $speed;
			    }
			}
			my $grade;
			if ($dist != 0 && defined $alt) {
			    $grade = 100*(($alt-$last_alt)/$dist);
			    if (abs($grade) > 10) { # XXX too many wrong values... XXX more intelligent solution
				undef $grade;
			    }
			}

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
			push @add_wpt_prop, $path_graph_elem;

 			my $color = "#000000";
			if (defined $speed && !$solid_coloring) {
			    $color = $cfc_mapping->{int($speed)};
			}
			if (!defined $color) {
			    my(@sorted) = sort { $a <=> $b } keys %$cfc_mapping;
			    if ($speed <= $sorted[0]) {
				$color = $cfc_mapping->{$sorted[0]};
			    } else {
				$color = $cfc_mapping->{$sorted[-1]};
			    }
			}
			{
			    my $name = "";
			    if (defined $speed) {
				$name .= int($speed) . " km/h ";
			    }
			    $name .= "[dist=" . BBBikeUtil::m2km($whole_dist,2) . ",time=" . BBBikeUtil::s2ms($whole_time) . "min" . sprintf(", abstime=%02d:%02d:%02d", @l[2,1,0]) . (defined $grade ? ", grade=" . sprintf("%.1f%%", $grade) : "") . "]";
			    $s_speed->push([$name, ["$last_x,$last_y", "$x,$y"], $color]);
			}
		    }
		}
		$last_wpt = [$x,$y,$x0,$y0,$time,$alt];
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

    BBBikeGPS::draw_track_graph($top, \@add_wpt_prop) if $show_track_graph;
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
    my($top, $add_wpt_prop_ref, $limit_ref, $peak_ref, $smooth_ref) = @_;
    return if !@$add_wpt_prop_ref;

    my $add_wpt_prop_ref_orig = $add_wpt_prop_ref;
    my($limit_speed_min, $limit_speed_max, $limit_alt_min, $limit_alt_max);
    my($peak_speed_neg, $peak_speed_pos, $peak_alt_neg, $peak_alt_pos);
    if ($limit_ref || $peak_ref) {
	if ($limit_ref) {
	    ($limit_speed_min, $limit_speed_max) = @{$limit_ref->{'speed'}};
	    undef $limit_speed_min if $limit_speed_min =~ /^\s*$/;
	    undef $limit_speed_max if $limit_speed_max =~ /^\s*$/;
	    ($limit_alt_min,   $limit_alt_max)   = @{$limit_ref->{'alt'}};
	    undef $limit_alt_min if $limit_alt_min =~ /^\s*$/;
	    undef $limit_alt_max if $limit_alt_max =~ /^\s*$/;
	}
	if ($peak_ref) {
	    ($peak_speed_neg, $peak_speed_pos) = @{$peak_ref->{'speed'}};
	    undef $peak_speed_neg if $peak_alt_neg =~ /^\s*$/;
	    undef $peak_speed_pos if $peak_speed_pos =~ /^\s*$/;
	    ($peak_alt_neg,   $peak_alt_pos) = @{$peak_ref->{'alt'}};
	    undef $peak_alt_neg if $peak_alt_neg =~ /^\s*$/;
	    undef $peak_alt_pos if $peak_alt_pos =~ /^\s*$/;
	}
	require Storable;
	$add_wpt_prop_ref = Storable::dclone($add_wpt_prop_ref_orig);
    }
    if (!$smooth_ref) { $smooth_ref = {} }
    foreach my $type (qw(alt grade speed)) {
	if (!$smooth_ref->{$type}) { $smooth_ref->{$type} = 5 }
    }

    my($max_alt, $min_alt, $max_grade, $min_grade, $max_speed, $min_speed);
    my $inx = 0;
    foreach (@$add_wpt_prop_ref) {
	my($speed, $alt, $grade) = ($_->speed, $_->alt, $_->grade);
	if (defined $limit_alt_min && $alt < $limit_alt_min) {
	    $_->alt(undef);
	} elsif (defined $limit_alt_max && $alt > $limit_alt_max) {
	    $_->alt(undef);
	} else {
	    if (defined $peak_alt_neg && $inx > 0 && $inx < $#$add_wpt_prop_ref
		&& $alt < $add_wpt_prop_ref->[$inx-1]->alt-$peak_alt_neg
		&& $alt < $add_wpt_prop_ref->[$inx+1]->alt-$peak_alt_neg) {
		$_->alt(undef);
	    } elsif (defined $peak_alt_pos && $inx > 0 && $inx < $#$add_wpt_prop_ref
		&& $alt > $add_wpt_prop_ref->[$inx-1]->alt+$peak_alt_pos
		&& $alt > $add_wpt_prop_ref->[$inx+1]->alt+$peak_alt_pos) {
		$_->alt(undef);
	    } else {
		$max_alt = $alt if !defined $max_alt || $alt > $max_alt;
		$min_alt = $alt if !defined $min_alt || $alt < $min_alt;
		$max_grade = $grade if defined $grade && (!defined $max_grade || $grade > $max_grade);
		$min_grade = $grade if defined $grade && (!defined $min_grade || $grade < $min_grade);
	    }
	}
	if (defined $limit_speed_min && $speed < $limit_speed_min) {
	    $_->speed(undef);
	} elsif (defined $limit_speed_max && $speed > $limit_speed_max) {
	    $_->speed(undef);
	} else {
	    if (defined $peak_speed_neg && $inx > 0 && $inx < $#$add_wpt_prop_ref
		&& $speed < $add_wpt_prop_ref->[$inx-1]->speed-$peak_speed_neg
		&& $speed < $add_wpt_prop_ref->[$inx+1]->speed-$peak_speed_neg) {
		$_->speed(undef);
	    } elsif (defined $peak_speed_pos && $inx > 0 && $inx < $#$add_wpt_prop_ref
		&& $speed > $add_wpt_prop_ref->[$inx-1]->speed+$peak_speed_pos
		&& $speed > $add_wpt_prop_ref->[$inx+1]->speed+$peak_speed_pos) {
		$_->speed(undef);
	    } else {
		$max_speed = $speed if !defined $max_speed || $speed > $max_speed;
		$min_speed = $speed if !defined $min_speed || $speed < $min_speed;
	    }
	}
    } continue { $inx++ }

    my $max_dist = $add_wpt_prop_ref->[-1]->wholedist;
    my $max_time = $add_wpt_prop_ref->[-1]->wholetime;

    if (defined $limit_alt_min || defined $limit_alt_max) {
	for my $i (1 .. $#$add_wpt_prop_ref) {
	    if (!defined $add_wpt_prop_ref->[$i]->alt) {
		$add_wpt_prop_ref->[$i]->grade(undef);
		if ($i < $#$add_wpt_prop_ref) {
		    $add_wpt_prop_ref->[$i+1]->grade(undef);
		}
	    }
	}
    }

    my $alt_delta = $max_alt-$min_alt;
    my $grade_delta = $max_grade-$min_grade;
    my $speed_delta = $max_speed-$min_speed;

    my $def_c_h = 300;
    my $def_c_w = 488;
    my $c_y = 5;
    my $def_c_x = 26;

    my(%graph_t, %graph_c, %c_x, %c_h, %c_w);

    foreach my $type (qw(speed alt grade)) {
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
	    $c_w{$type} = $def_c_w;
	    $c_h{$type} = $def_c_h;
	    $graph_c{$type} = $tl->Canvas(-height => $c_h{$type}+$c_y*2, -width => $c_w{$type}+$def_c_x*2)->pack(-fill => "both");

	    $tl->{Graph} = $graph_c{$type};
	    if ($type ne 'grade') {
		my $f = $tl->Frame->pack(-fill => 'x');
		my($min,$max);
		my($peak_neg, $peak_pos);
		if ($limit_ref && $limit_ref->{$type}) {
		    ($min, $max) = @{ $limit_ref->{$type} };
		}
		if (!$limit_ref) {
		    $limit_ref = {speed => [], alt => []};
		}
		if ($peak_ref && $peak_ref->{$type}) {
		    ($peak_neg, $peak_pos) = @{ $peak_ref->{$type} };
		}
		if (!$peak_ref) {
		    $peak_ref = {speed => [], alt => []};
		}
		$f->Label(-text => M"Min")->pack(-side => "left");
		$f->Entry(-textvariable => \$min, -width => 4)->pack(-side => "left");
		$f->Label(-text => M"Max")->pack(-side => "left");
		$f->Entry(-textvariable => \$max, -width => 4)->pack(-side => "left");
		$f->Label(-text => M"untere Spitzen")->pack(-side => "left");
		$f->Entry(-textvariable => \$peak_neg, -width => 4)->pack(-side => "left");
		$f->Label(-text => M"obere Spitzen")->pack(-side => "left");
		$f->Entry(-textvariable => \$peak_pos, -width => 4)->pack(-side => "left");
		my $redraw_cb = [sub {
				     my $type = shift;
				     $limit_ref->{$type} = [$min,$max];
				     $peak_ref->{$type} = [$peak_neg,$peak_pos];
				     BBBikeGPS::draw_track_graph($top, $add_wpt_prop_ref_orig,
								 $limit_ref, $peak_ref, $smooth_ref);
				 }, $type];
		$f->Button(-text => M"Neu zeichnen",
			   -command => $redraw_cb,
			  )->pack(-side => "left");
#XXX not yet $graph_c{$type}->bind("<Configure>" => $redraw_cb);
	    }

	    if ($type eq 'speed') {
		my $f = $tl->Frame->pack(-fill => 'x');
		$f->Label(-text => M"Glätten")->pack(-side => "left");
		my $smooth = $smooth_ref->{$type};
		$f->Entry(-textvariable => \$smooth, -width => 4)->pack(-side => "left");
		$f->Button(-text => M"Neu zeichnen",
			   -command => [sub {
					    my $type = shift;
					    $smooth_ref->{$type} = $smooth;
					    BBBikeGPS::draw_track_graph($top, $add_wpt_prop_ref_orig,
									$limit_ref, $peak_ref, $smooth_ref);
					}, $type]
			  )->pack(-side => "left");
		$f->Button(-text => M"Geglättete oben",
			   -command => [sub {
					    $graph_c{$type}->raise("$type-smooth");
					}, $type]
			  )->pack(-side => "left");
		$f->Button(-text => M"Geglättete unten",
			   -command => [sub {
					    $graph_c{$type}->lower("$type-smooth");
					}, $type]
			  )->pack(-side => "left");
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

    for my $type (qw(speed alt grade)) {
	# first the scales
	no strict 'refs';
	my $min   = eval '$min_'.$type;
	my $max   = eval '$max_'.$type;
	my $delta = eval "\$".$type."_delta";
	my $c_x = $c_x{$type};
	my $c_w = $c_w{$type};
	my $c_h = $c_h{$type};

	for (my $val = $min%5*5; $val < $max; $val+=5) {
	    my $y = $c_y + $c_h-( ($c_h/$delta)*($val-$min));
	    $graph_c{$type}->createLine($c_x-2, $y, $c_x+2, $y);
	    $graph_c{$type}->createLine($c_x+2, $y, $c_x+$c_w, $y, -dash => '. ');
	    $graph_c{$type}->createText($c_x-2, $y, -text => $val, -anchor => "e");
	}
    }

    {
	# now the graphs
	my($last_speed_y, $last_alt_y, $last_grade_y,
	   $last_speed_x, $last_alt_x, $last_grade_x);
	foreach (@$add_wpt_prop_ref) {
	    my($whole_dist, $speed, $alt, $grade, $coord) = ($_->wholedist, $_->speed, $_->alt, $_->grade, $_->coord);
	    my $speed_x = $c_x{"speed"} + ($c_w{"speed"}/$max_dist)*$whole_dist;
	    my $alt_x   = $c_x{"alt"} + ($c_w{"speed"}/$max_dist)*$whole_dist;
	    my $grade_x = $c_x{"grade"} + ($c_w{"speed"}/$max_dist)*$whole_dist;

	    if (defined $last_speed_x) {
		if (defined $speed) {
		    my $y = $c_y + $c_h{"speed"}-( ($c_h{"speed"}/$speed_delta)*($speed-$min_speed));
		    if (defined $last_speed_y) {
			$graph_c{'speed'}->createLine
			    ($last_speed_x, $last_speed_y, $speed_x, $y,
			     -tags => ["speed", "speed-$coord"]);
		    }
		    $last_speed_y = $y;
		}

		if (defined $alt) {
		    my $y = $c_y + $c_h{"speed"}-( ($c_h{"speed"}/$alt_delta)*($alt-$min_alt));
		    if (defined $last_alt_y) {
			$graph_c{'alt'}->createLine
			    ($last_alt_x, $last_alt_y, $alt_x, $y,
			     -tags => ["alt", "alt-$coord"]);
		    }
		    $last_alt_y = $y;
		}

		if (defined $grade) {
		    my $y = $c_y + $c_h{"speed"}-( ($c_h{"speed"}/$grade_delta)*($grade-$min_grade));
		    if (defined $last_grade_y) {
			$graph_c{'grade'}->createLine
			    ($last_grade_x, $last_grade_y, $grade_x, $y,
			     -tags => ["grade", "grade-$coord"]);
		    }
		    $last_grade_y = $y;
		}
	    }

	    $last_speed_x = $speed_x;
	    $last_alt_x   = $alt_x;
	    $last_grade_x = $grade_x;
	}
    }

    {
	# smooth graphs
# XXX use dist and legtime instead!!!
	my($last_speed, $last_x_speed);
	my $smooth_i = $smooth_ref->{speed};
	my($sum_speed, $sum_dist, $count) = (0, 0, 0);
	for my $i (0 .. $smooth_i-1) {
	    my $speed = $add_wpt_prop_ref->[$i]->speed;
	    my $dist  = $add_wpt_prop_ref->[$i]->dist;
	    if (defined $speed) {
		$sum_speed+=$speed;
		$sum_dist+=$dist;
		$count++;
	    }
	}

	for my $inx (0 .. $#$add_wpt_prop_ref-$smooth_i) {
	    if ($inx > 0) {
		my $first_old_speed = $add_wpt_prop_ref->[$inx-1]->speed;
		if (defined $first_old_speed) {
		    $sum_speed-=$first_old_speed;
		    $count--;
		}
		my $new_speed = $add_wpt_prop_ref->[$inx+$smooth_i-1]->speed;
		if (defined $new_speed) {
		    $sum_speed+=$new_speed;
		    $count++;
		}
	    }
	    my $whole_dist = $add_wpt_prop_ref->[$inx+$smooth_i/2]->wholedist;
	    if ($count) {
		my $speed = $sum_speed/$count;
		my $x = $c_x{'speed'} + ($c_w{"speed"}/$max_dist)*$whole_dist;
		if (defined $last_x_speed) {
		    my $y = $c_y + $c_h{"speed"}-( ($c_h{"speed"}/$speed_delta)*($speed-$min_speed));
		    if (defined $last_speed) {
			$graph_c{'speed'}->createLine($last_x_speed, $last_speed, $x, $y, -fill => 'red', -tags => 'speed-smooth');
		    }
		    $last_speed = $y;
		}
		$last_x_speed = $x;
	    }
	}
    }

    # bind <1> to mark point
    foreach (qw(speed alt grade)) {
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

1;

__END__
