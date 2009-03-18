# -*- perl -*-

#
# $Id: BBBikeGPSTrackingPlugin.pm,v 1.28 2009/03/18 23:17:32 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2009 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Description (en): track position via GPS
# Description (de): GPS-Position verfolgen
package BBBikeGPSTrackingPlugin;

use BBBikePlugin;
push @ISA, "BBBikePlugin";

use strict;
use vars qw($VERSION $DEBUG);
$VERSION = 0.03;

$DEBUG = 0;

use Hash::Util qw(lock_keys);
use IPC::Run qw();

use BBBikeUtil qw(is_in_path s2hm);
use Karte::Polar;
use Karte::Standard;
use Strassen::Strasse;

use constant GPS_GRABBER => 'gpsd';  # determine dynamically?

use vars qw($SPEAK_PROG);
$SPEAK_PROG = 'espeak' if !defined $SPEAK_PROG; # determine dynamically?

use vars qw($MBROLA_LANG $MBROLA_BIN $MBROLA_LANG_FILE $mbrola_tmp);
# de6 seems to be best
$MBROLA_LANG = 'de6' if !defined $MBROLA_LANG;
$MBROLA_BIN = "$ENV{HOME}/Desktop/mbrola/mbrola-linux-i386" if !defined $MBROLA_BIN;
$MBROLA_LANG_FILE = "$ENV{HOME}/Desktop/mbrola/de1/de1" if !defined $MBROLA_LANG_FILE;

use vars qw($gps_track_mode $gps_fh $replay_speed_conf @gps_track $gpspipe_pid
	    $dont_auto_center $dont_auto_track $dont_link_to_nearest_street
	    $dont_auto_set_volume $dont_say_sat_info
	    $do_navigate @current_search_route $do_speech
	    %reported_point
	    $current_accuracy $current_accuracy_update_time
	    $current_speed $current_gps_mode $current_sat_used %seen_gps_mode
	    $gpsd_last_event_time $gpsd_checker $gpsd_state
	    $in_re_route $auto_re_route
	    $off_road_counter
	    $old_volume
	  );
$replay_speed_conf = 1 if !defined $replay_speed_conf;

use constant ACCURACY_NOTHING => 9999;

use your qw($main::gps_device $main::capstyle_round %main::str_obj $main::Checkbutton %main::font
	    @main::speed @main::power);

sub register {
    my $pkg = __PACKAGE__;

    $BBBikePlugin::plugins{$pkg} = $pkg;

    add_button();
}

sub unregister {
    my $pkg = __PACKAGE__;
    return unless $BBBikePlugin::plugins{$pkg};
    deactivate_tracking();

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
    my $Checkbutton = $main::Checkbutton;
    my $toggle_gps_track_mode = sub {
	my $want_gps_track_mode = $gps_track_mode;
	if ($want_gps_track_mode) {
	    eval {
		activate_tracking();
	    };
	    if ($@) {
		main::status_message("Cannot activate tracking: $@", "err");
		$gps_track_mode = 0;
	    }
	} else {
	    deactivate_tracking();
	}
    };
    my %check_args =
	(-variable => \$gps_track_mode,
	 -command  => $toggle_gps_track_mode,
	);
    my $b = $mf->$Checkbutton
	(-text => "GPS",
	 %check_args,
	);
    BBBikePlugin::replace_plugin_widget($mf, $b, __PACKAGE__.'_on');
    $main::balloon->attach($b, -msg => "GPS Tracking")
	if $main::balloon;

    BBBikePlugin::place_menu_button
	    ($mmf,
	     # XXX Msg.pm
	     [
	      [Checkbutton => 'GPS-Track-Modus',
	       %check_args,
	      ],
	      [Checkbutton => "Navigate",
	       -variable => \$do_navigate,
	       -command => sub {
		   if ($do_navigate) {
		       if ($dont_link_to_nearest_street) {
			   $dont_link_to_nearest_street = 0;
		       }
		       if (!$gps_track_mode) {
			   $gps_track_mode = 1;
			   $toggle_gps_track_mode->();
		       }
		       my $init = sub {
			   @current_search_route = @{ main::get_act_search_route() };
			   %reported_point = ();
		       };
		       Hooks::get_hooks("new_route")->add($init, __PACKAGE__ . "_navigate");
		       $init->();
		   } else {
		       Hooks::get_hooks("new_route")->del(__PACKAGE__ . "_navigate");
		   }
	       },
	      ],
	      [Checkbutton => 'Speech',
	       -variable => \$do_speech,
	       -command => sub {
		   if ($do_speech) {
		       init_speech();
		   } else {
		       Hooks::get_hooks("new_route")->del(__PACKAGE__ . "_speech");
		   }
	       },
	      ],
	      [Checkbutton => 'Auto re-route',
	       -variable => \$auto_re_route,
	      ],
	      '-',
	      [Button => "Delete track",
	       -command => sub {
		   @gps_track = ();
		   $main::c->delete("gps_track");
	       },
	      ],
	      [Checkbutton => "Do not autocenter",
	       -variable => \$dont_auto_center,
	      ],
	      [Checkbutton => "Do not autotrack",
	       -variable => \$dont_auto_track,
	      ],
	      [Checkbutton => "Do not link to nearest street",
	       -variable => \$dont_link_to_nearest_street,
	       -command => sub {
		   if (!$dont_link_to_nearest_street) {
		       $do_navigate = 0;
		   }
	       },
	      ],
	      [Button => 'Re-route from current point',
	       -command => sub { re_route_from_current_point() },
	      ],
	      '-',
	      [Checkbutton => "Do not automatically set volume",
	       -variable => \$dont_auto_set_volume,
	      ],
	      [Checkbutton => "Do not say satellite info",
	       -variable => \$dont_say_sat_info,
	      ],
	      [Button => 'Satellite view',
	       -command => sub {
		   # the cheap solution
		   if (!is_in_path("xgps")) {
		       main::status_message("xgps is not available. It is usually part of the gpsd distribution.", "err");
		       return;
		   }
		   system("xgps&");
		   if ($? != 0) {
		       main::status_message("Some problem while running xgps ($?)", "err");
		   }
	       },
	      ],
	      '-',
	      [Button => "Replay NMEA file",
	       -command => sub {
		   my $file = $main::top->getOpenFile;
		   return if !defined $file;
		   activate_dummy_tracking($file);
		   $gps_track_mode = 1;
	       },
	      ],
	      [Cascade => "Replay speed", -menuitems =>
	       [
		(map {
		    [Radiobutton => "$_",
		     -variable => \$replay_speed_conf,
		     -value => $_
		    ]
		} (1,2,10,100)
		)
	       ]
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
	     -title => "GPS Tracking",
	     -topmenu => [Checkbutton => 'GPS Tracking',
			  %check_args,
			 ],
	    );

    $mmf->Subwidget(__PACKAGE__."_menu")->menu;
}

sub init_speech {
    if (!$do_navigate) {
	saytext("Die Navigation ist nicht eingeschaltet.");
	return;
    }
    if (!$gps_track_mode) {
	saytext("Das GPS-Tracking ist ausgeschaltet.");
	return;
    }
    saytext("Die Audio-Navigation ist eingeschaltet.");
    saytext({power_info()}->{msg_de});
    saytext(gps_info_text_de());
    my $say_route_info = sub {
	return if $in_re_route;
	# XXX unfortunately we cannot assume that
	# @current_search_route is filled yet, hook execution order is
	# undefined!
	my @search_route = @{ main::get_act_search_route() };
	if (!@search_route) {
	    saytext("Es ist keine Route definiert.");
	} else {
	    saytext("Eine Route nach " . simplify_street($search_route[-1][StrassenNetz::ROUTE_NAME()]) . " ist definiert.");
	    my $journey_time = main::get_reference_journey_time();
	    my($h,$m,$s) = ((split /:/, s2hm($journey_time)), $journey_time % 60);
	    my($XXX, $value, $unit) = ($main::active_speed_power{Type} eq 'power'
				       ? ('Leistung', $main::power[$main::active_speed_power{Index}], 'Watt')
				       : ('Geschwindigkeit', $main::speed[$main::active_speed_power{Index}], 'km pro Stunde')
				      );
	    sayssml('Die voraussichtliche Fahrzeit beträgt ' . de_time_period($h,$m,$s,maybe=>'seconds') . ' bei <break/> einer '
		    . $XXX . ' von ' . $value . ' ' . $unit . '.');
	}
    };
    Hooks::get_hooks("new_route")->add($say_route_info, __PACKAGE__ . "_speech");
    $say_route_info->();
}

sub activate_tracking {
    undef $current_accuracy;
    undef $current_speed;
    undef $current_gps_mode;
    undef %seen_gps_mode;
    # XXX decide whether to use GPS::NMEA or gpsd
    if (GPS_GRABBER eq 'nmea') {
	activate_nmea_tracking();
    } else {
	activate_gpsd_tracking();
    }
}

sub activate_nmea_tracking {
    require GPS::NMEA;
    GPS::NMEA->VESION(1.12);
    my $gps = GPS::NMEA->new(Port => $main::gps_device||"/dev/ttyS0",
			     Baud=>4800)
	or main::status_message("Cannot open GPS device: $!", "die");
    _setup_fileevent({gps => $gps}, undef, 'nmea');
}

sub activate_gpsd_tracking {
    kill_gpspipe();
    $gpspipe_pid = open my $fh, "-|", "gpspipe", "-w"
	or die "Cannot execute gpspipe: $!";
    if ($fh->eof) {
	main::status_message('gpsd not running?', 'error');
	deactivate_tracking();
	return;
    }
    _setup_fileevent({fh => $fh}, undef, 'gpsd');
}

sub activate_dummy_tracking {
    my $file = shift;
    my $gps = GPS::NMEA->new(do_not_init => 1) # make configurable!!!
	or main::status_message("Cannot create GPS::NMEA object: $!", "die");
    open my $fh, "<", $file
	or main::status_message("Cannot open $file: $!", "die");
    _setup_fileevent({gps => $gps, fh => $fh}, $replay_speed_conf, 'nmea');
}

sub _setup_fileevent {
    my($info, $replay_speed, $prot) = @_;
    my $line;
    my $last_seconds;
    my($gps, $fh) = @{$info}{qw(gps fh)};
    $fh = $gps->serial if !$fh;
    $gps_fh = $fh;

    my $callback;

    my %parse;
    $parse{nmea} = sub {
	$line .= $fh->getline;
	if ($line =~ /\n/) {
	    my $short_cmd = $gps->parse_line($line);
	    if (defined $short_cmd) {
		my $d = $gps->{NMEADATA};
		if ($short_cmd eq "GPRMC") {
		    my($lon, $lat) = gpsnmea_data_to_ddd($d);
		    if (defined $lon) {
			if ($replay_speed) {
			    my($H,$M,$S) = $d->{time_utc} =~ m{^(\d\d):(\d\d):(\d\d)};
			    if (defined $H) {
				my $this_seconds = $S+$M*60+$H*3600;
				if (defined $last_seconds) {
				    if ($last_seconds > $this_seconds) {
					# day rotation
					$last_seconds -= 86400;
				    }
				    my $sleep_time = ($this_seconds - $last_seconds)/$replay_speed;
				    die "should never happen: $sleep_time" if $sleep_time < 0;
				    $main::top->fileevent($fh, 'readable', ''); # suspend
				    warn "Sleep for $sleep_time seconds...\n" if $DEBUG;
				    $main::top->after($sleep_time*1000, sub {
							  set_position($lon, $lat);
							  $main::top->fileevent($fh, 'readable', $callback);
						      });
				}
				$last_seconds = $this_seconds;
			    }
			} else {
			    set_position($lon, $lat);
			}
			$gpsd_last_event_time = time;
		    }
		} elsif ($short_cmd eq 'PGRME') { # XXX Is this Garmin-specific? I think so...
		    chomp $line; # XXX why is this not in the NMEADATA record, but has to be parsed?
		    $line=~s/\*..\r?$//;
		    my(@l)=split/,/,$line;
		    $current_accuracy = $l[1]; # XXX what's $l[3]? what about unit, always M?
		    $current_accuracy_update_time = time;
		}
	    }
	    $line = '';
	}
    };

    $parse{gpsd} = sub {
	$line .= $fh->getline;
	if ($line =~ /\n/) {
	    if ($line =~ /^GPSD,O=\?/) {
		# no info yet
		$current_accuracy = ACCURACY_NOTHING;
		$current_accuracy_update_time = time;
	    } elsif ($line =~ /^GPSD,O=/) {
		my(@l) = split /\s+/, $line;
		my($this_seconds) = $l[1];
		my($lon, $lat) = ($l[4], $l[3]);
		if ($l[6] ne '?') {
		    $current_accuracy = $l[6];
		    $current_accuracy_update_time = time;
		}
		if ($l[9] ne '?') {
		    $current_speed = $l[9];
		}
		if ($l[14] ne '?') {
		    if (($current_gps_mode||'') ne $l[14]) {
			gps_mode_change($l[14]);
			$current_gps_mode = $l[14];
		    }
		}
		set_position($lon, $lat);
		$gpsd_last_event_time = time;
	    } elsif ($line =~ /^GPSD,Y=/) {
		my(@sat) = split /:/, $line;
		shift @sat;
		my $sat_used = 0;
		for (@sat) {
		    my(@l) = split /\s+/;
		    if ($l[4]) { $sat_used++ }
		}
		$current_sat_used = $sat_used;
	    }
	    $line = '';
	}
    };

    $prot = 'nmea' if !$prot;
    my $parse = $parse{$prot};

    $callback = sub {
	if ($fh->eof) {
	    warn "End of file.\n" if $DEBUG;
	    deactivate_tracking();
	    return;
	}
	$parse->();
    };
    $main::top->fileevent($fh, 'readable', $callback);
    if ($gpsd_checker) {
	$gpsd_checker->cancel;
	undef $gpsd_checker;
    }
    $gpsd_checker = $main::top->repeat(10*1000, sub {
					   if ($gps_track_mode) {
					       if ($gpsd_last_event_time - time >= 60) {
						   if (!$gpsd_state || $gpsd_state eq 'alive') {
						       $gpsd_state = 'dead';
						       if ($do_speech) {
							   saytext('Der GPS-Empfang ist unterbrochen.');
							   $gpsd_state = 'dead_and_reported';
						       }
						   }
					       } else {
						   if ($gpsd_state && $gpsd_state eq 'dead_and_reported' && $do_speech) {
						       saytext('Es gibt wieder GPS-Empfang.');
						   }
						   $gpsd_state = 'alive';
					       }
					   }
				       });
}

sub gps_mode_change {
    my($new_mode) = @_;
    if ($do_speech && !$dont_say_sat_info) {# XXX need a better approach when flapping
	return if $seen_gps_mode{$new_mode};

	my $msg;
	if ($new_mode eq '1') {
	    $msg = 'Kein GPS-Fix.';
	} elsif ($new_mode eq '2') {
	    $msg = 'Es gibt einen 2D-Fix.';
	} elsif ($new_mode eq '3') {
	    $msg = 'Es gibt einen 3D-Fix.';
	} else {
	    $msg = "Unerwarteter GPS-Modus $new_mode";
	}

	if ($new_mode >= 2) {
	    if (defined $current_sat_used) {
		$msg .= " Es wurden $current_sat_used Satelliten zum Ermitteln der Position verwendet.";
	    }
	    if (defined $current_accuracy) {
		$msg .= " Die Genauigkeit beträgt $current_accuracy Meter.";
	    }
	}

	if ($msg) {
	    saytext($msg);
	    $seen_gps_mode{$new_mode} = 1;
	}
    }
}

# Sigh...
sub gpsnmea_data_to_ddd {
    my($d) = @_;
    return (undef, undef) if $d->{lat_ddmm} eq '';

    my(@lat_dmm) = $d->{lat_ddmm} =~ m{^(\d\d)([\d\.]+)};
    if ($d->{lat_NS} eq 'S') { $lat_dmm[0] *= -1 }

    my(@lon_dmm) = $d->{lon_ddmm} =~ m{^(\d\d\d)([\d\.]+)};
    if ($d->{lon_EW} eq 'W') { $lon_dmm[0] *= -1 }

    (Karte::Polar::dmm2ddd(@lon_dmm), Karte::Polar::dmm2ddd(@lat_dmm));
}

sub set_position {
    my($lon, $lat) = @_;
    my($sx,$sy) = $Karte::Polar::obj->map2standard($lon,$lat);
    my $sxy = "$sx,$sy";
    my($x,$y) = main::transpose($sx,$sy);
    warn "Set position ($lon/$lat) -> ($x,$y)\n" if $DEBUG;

    # Center
    if (!$dont_auto_center) {
	main::mark_point(-x => $x, -y => $y, -dont_mark => 1);
    }

    # Mark head
    my $head_item = $main::c->find(withtag => 'gps_track_head');
    if ($head_item) {
	$main::c->coords($head_item, $x, $y, $x, $y);
    } else {
	$main::c->createLine($x,$y,$x,$y, -width => 8, -fill => 'red',
			     -capstyle => $main::capstyle_round,
			     -tags => ['gps_track', 'gps_track_head'],
			    );
    }

    if (defined $current_accuracy) {
	if ($current_accuracy_update_time + 60 < time) {
	    undef $current_accuracy; # out-of-date
	}
    }
    if (defined $current_accuracy) {
	my $set_acc_text = sub {
	    my($cx,$cy,$text,%args) = @_;
	    my $tag = delete $args{'-tag'};
	    my $acc_text_item = $main::c->find(withtag => $tag);
	    if ($acc_text_item) {
		$main::c->coords($acc_text_item, $cx, $cy);
	    } else {
		$acc_text_item = $main::c->createText($cx, $cy,
						      -font => $main::font{'tiny'},
						      -justify => 'left',
						      -tags => ['gps_track', $tag],
						     );
	    }
	    $main::c->itemconfigure($acc_text_item, -text => $text, %args);
	};
	if ($current_accuracy == ACCURACY_NOTHING) {
	    my @coord = main::transpose($sx,$sy);
	    $main::c->delete('gps_track_acc', 'gps_track_acc_fix');
	    $set_acc_text->(@coord, "???", -anchor => 's', -tag => 'gps_track_acc_text'); # XXX use diameter for coord!
	} else {
	    my @coord = (main::transpose($sx-$current_accuracy,$sy-$current_accuracy),
			 main::transpose($sx+$current_accuracy,$sy+$current_accuracy));

	    my $acc_item = $main::c->find(withtag => 'gps_track_acc');
	    if ($acc_item) {
		$main::c->coords($acc_item, @coord);
	    } else {
		$main::c->createOval(@coord, -tags => ['gps_track', 'gps_track_acc']);
	    }

	    $set_acc_text->(@coord[2,3], int($current_accuracy), -anchor => 'c', -tag => 'gps_track_acc_text'); # XXX use diameter for coord!
	    $set_acc_text->(@coord[2,1], ($current_gps_mode eq '3'
					  ? '3D'
					  : ($current_gps_mode eq '2'
					     ? '2D'
					     : 'no fix'
					    )
					 ), -anchor => 'c', -tag => 'gps_track_acc_fix'); # XXX use diameter for coord!
	    
	}
    } else {
	$main::c->delete('gps_track_acc', 'gps_track_acc_text');
    }

    # Track
    # XXX Zusätzlich könnte ein "Schlauch" mit der Genauigkeit gezeichnet werden.
    if (!$dont_auto_track) {
	if (!@gps_track || $gps_track[-1] ne $sxy) {
	    if (@gps_track) {
		my($lastsx,$lastsy) = split /,/, $gps_track[-1];
		my $last_point_dist = Strassen::Util::strecke([$lastsx,$lastsy],[$sx,$sy]);
		my($lastx,$lasty);
		if ($last_point_dist < 100) {
		    ($lastx,$lasty) = main::transpose($lastsx,$lastsy);
		} else {
		    # a jump, don't connect
		    ($lastx,$lasty) = ($x,$y);
		}
		$main::c->createLine($lastx,$lasty, $x,$y,
				     -tags => ['gps_track']);
	    }
	    push @gps_track, $sxy;
	}
    }

    if (!$dont_link_to_nearest_street) {
	my $ret = get_nearest_coords($sxy);
	if ($ret) {
	    my @coords = (main::transpose($ret->{Coords}[0],$ret->{Coords}[1]),
			  $x, $y,
			  main::transpose($ret->{Coords}[2],$ret->{Coords}[3]),
			 );
	    my $link_item = $main::c->find(withtag => 'gps_track_link');
	    if ($link_item) {
		$main::c->coords($link_item, @coords);
	    } else {
		$main::c->createLine(@coords, -fill => 'red',
				     -tags => ['gps_track', 'gps_track_link'],
				    );
	    }
	    if ($auto_re_route) {
		my $c1 = "$ret->{Coords}[0],$ret->{Coords}[1]";
		my $c2 = "$ret->{Coords}[2],$ret->{Coords}[3]";
		my $matched_coord_i;
	    SEARCH_IN_ROUTE: {
		    for my $coord_i (0 .. $#main::realcoords) {
			my $coord = $main::realcoords[$coord_i];
			my $coord_s = join(",",@$coord);
			if ($coord_s eq $c1 || $coord_s eq $c2) {
			    $matched_coord_i = $coord_i;
			    last SEARCH_IN_ROUTE;
			}
		    }
		    re_route_from_current_point();
		}
		# calculate and plot the "off-road angle"
		# and if necessary, re-route
		if (defined $matched_coord_i && $matched_coord_i < $#main::realcoords) {
		    $main::c->delete('gps_track_angle');
		    if (Strassen::Util::strecke([$sx,$sy],$main::realcoords[$matched_coord_i+1]) < 40) {
			# near enough
			$off_road_counter = 0;
		    } else {
			my($angle,$dir) = BBBikeUtil::schnittwinkel(@{$main::realcoords[$matched_coord_i+1]},
								    @{$main::realcoords[$matched_coord_i]},
								    $sx, $sy);
			my $angle_deg = abs(180-BBBikeUtil::rad2deg($angle));
			if ($angle_deg < 45) {
			    $off_road_counter = 0;
			} else {
			    $off_road_counter++;
			    if ($off_road_counter >= 3) {
				$main::c->createText($x, $y,
						     -text => "  ".int($angle_deg)."°",
						     #-font => $main::font{'tiny'},
						     -anchor => 'w',
						     -tags => ['gps_track', 'gps_track_angle'],
						    );
				re_route_from_current_point();
			    }
			}
		    }
		}
	    }
	    if ($do_navigate) {
		match_position_with_route($ret, $sxy);
	    }
	}
    }
}

sub get_nearest_coords {
    my($sxy) = @_;
    my $s = $main::net && $main::net->{Strassen};
    $s = $main::str_obj{s} if !$s;
    if (!$s) {
	our $warn_str_obj_once;
	if (!$warn_str_obj_once++) {
	    main::status_message("Cannot get str_obj{s} object", "info");
	}
	undef;
    } else {
	$s->nearest_point($sxy, FullReturn => 1);
    }
}

sub match_position_with_route {
    my($nearest_object, $sxy) = @_;
    return if !@main::realcoords;
    my $pos_coords = $nearest_object->{Coords};
    $main::c->delete("XXX1");
    for my $i (0 .. $#main::realcoords) {
	if ($main::realcoords[$i][0] == $pos_coords->[0] &&
	    $main::realcoords[$i][1] == $pos_coords->[1]) {
	    my $from_index;
	    if ($i+1 <= $#main::realcoords &&
		$main::realcoords[$i+1][0] == $pos_coords->[2] &&
		$main::realcoords[$i+1][1] == $pos_coords->[3]) {
		$from_index = $i;
	    } elsif ($i-1 >= 0 &&
		     $main::realcoords[$i-1][0] == $pos_coords->[2] &&
		     $main::realcoords[$i-1][1] == $pos_coords->[3]) {
		$from_index = $i-1;
	    }
	    if (defined $from_index) {
		my $to_index = $from_index+1;
		my @coords_from = (main::transpose($main::realcoords[$from_index][0], $main::realcoords[$from_index][1]));
		my @coords_to   = (main::transpose($main::realcoords[$to_index  ][0], $main::realcoords[$to_index  ][1]));
		$main::c->createLine(@coords_from, @coords_to,
				     -fill => 'red',
				     -width => 5,
				     -arrow => 'last',
				     -tags => ['gps_track', 'XXX1']);
		if (@current_search_route) {
		    for my $j (0 .. $#current_search_route) {
			if ($to_index >= $current_search_route[$j]->[StrassenNetz::ROUTE_ARRAYINX()][0]+1 &&
			    $to_index <= $current_search_route[$j]->[StrassenNetz::ROUTE_ARRAYINX()][1]+1) {
			    if ($j == $#current_search_route) {
				my $live_dist = int Strassen::Util::strecke($main::realcoords[-1], [split /,/, $sxy]);
				my $text = "In $live_dist Metern ist das Ziel erreicht."; # don't need singular, I think
				if (#$live_dist <= 100 && # XXX The inability to do this condition is a bug!
				    !$reported_point{"Ziel"}) {
				    if ($do_speech) {
					set_volume_for_current_point($nearest_object);
					saytext($text);
					$reported_point{"Ziel"} = 1;
				    } else {
					warn "Would say: $text\n"; # XXX debug?
				    }
				}
				my(@coord) = main::transpose(@{ $main::realcoords[-1] });
				$main::c->createText(@coord, -text => "Ziel in $live_dist m", -tags => ['gps_track', 'XXX1']);
			    } else {
				my $next_street = $current_search_route[$j+1]->[StrassenNetz::ROUTE_NAME()];
				my $direction = uc $current_search_route[$j]->[StrassenNetz::ROUTE_DIR()];
				if ($current_search_route[$j]->[StrassenNetz::ROUTE_ANGLE()] < 45) {
				    my $important = $current_search_route[$j]->[StrassenNetz::ROUTE_EXTRA()]->{ImportantAngle};
				    if (!$important) {
					$direction = '';
				    } else {
					$direction = 'h' . $direction;
				    }
				}
				my $live_dist = int Strassen::Util::strecke
				    ($main::realcoords[$current_search_route[$j+1]->[StrassenNetz::ROUTE_ARRAYINX()][0]],
				     [split /,/, $sxy]);
				if ($live_dist <= 100 && !$reported_point{"$next_street $direction"}) {
				    my @saydirection_args = ($next_street, $direction, $live_dist);
				    if ($do_speech) {
					set_volume_for_current_point($nearest_object);
					saydirection(@saydirection_args);
					$reported_point{"$next_street $direction"} = 1;
				    } else {
					warn "Would say: " . make_german_direction(@saydirection_args) . "\n"; # XXX debug?
				    }
				}
				my(@coord) = main::transpose(@{ $main::realcoords[$current_search_route[$j+1]->[StrassenNetz::ROUTE_ARRAYINX()][0]] });
				$main::c->createText(@coord, -text => "$next_street $direction in $live_dist m", -tags => ['gps_track', 'XXX1']);
			    }
			    return;
			}
		    }
		}
	    }
	    return;
	}
    }
    $main::c->createText(main::transpose(split /,/, $sxy), -text => "?", -tags => ['gps_track', 'XXX1']);
}

sub re_route_from_current_point {
    if (!@main::search_route_points) {
	main::status_message('No old route exist', $auto_re_route ? 'info' : 'error');
	return;
    }
    my $ret = get_nearest_coords($gps_track[-1]);
    if ($ret) {
	my($sx,$sy) = split /,/, $gps_track[-1];
	my $new_start_coord;
	my $new_via_coord;
# 	if (@gps_track >= 2) {
# 	    my($sx_before,$sy_before) = split /,/, $gps_track[-2];
# 	    my($angle) = BBBikeUtil::schnittwinkel($sx_before,$sy_before,
# 						   $sx,$sy,
# 						   $ret->{Coords}[0],$ret->{Coords}[1]
# 						  );
# 	    if ($angle < BBBikeUtil::deg2rad(30)) {
# 		$new_start_coord = $ret->{Coords}[2].",".$ret->{Coords}[3];
# 		$new_via_coord   = $ret->{Coords}[0].",".$ret->{Coords}[1];
# 	    } else {
# 		my($angle) = BBBikeUtil::schnittwinkel($sx_before,$sy_before,
# 						       $sx,$sy,
# 						       $ret->{Coords}[2],$ret->{Coords}[3]
# 						      );
# 		if ($angle < BBBikeUtil::deg2rad(30)) {
# 		    $new_start_coord = $ret->{Coords}[0].",".$ret->{Coords}[1];
# 		    $new_via_coord   = $ret->{Coords}[2].",".$ret->{Coords}[3];
# 		}
# 	    }
# 	}
	if (!$new_start_coord) {
	    my $dist0 = Strassen::Util::strecke([$ret->{Coords}[0],$ret->{Coords}[1]],[$sx,$sy]);
	    my $dist1 = Strassen::Util::strecke([$ret->{Coords}[2],$ret->{Coords}[3]],[$sx,$sy]);
	    $new_start_coord = ($dist0 < $dist1
				? $ret->{Coords}[0].",".$ret->{Coords}[1]
				: $ret->{Coords}[2].",".$ret->{Coords}[3]
			       );
	}
	if ($main::search_route_points[0][main::SRP_COORD()] eq $new_start_coord) {
	    main::status_message('No re-routing necessary', 'info');
	    return;
	}
	$main::search_route_points[0][main::SRP_COORD()] = $new_start_coord;
# 	if ($new_via_coord) {
# 	    if (@main::search_route_points == 2) {
# 		# XXX need to move goal
# 		$main::search_route_points[2] = $main::search_route_points[1];
# 	    }
# 	    $main::search_route_points[1] = [];
# 	    $main::search_route_points[1][main::SRP_COORD()] = $new_via_coord;
# 	}
	local $in_re_route = 1;
	main::re_search();
    }
}

######################################################################
# Speech

# Say a direction ($next_street, $direction, $distance) with the
# default program
sub saydirection {
    my $sub = "saydirection_$SPEAK_PROG";
    no strict 'refs';
    &$sub;
}

# Say normal text ($text) with the default program
sub saytext {
    my $sub = "saytext_$SPEAK_PROG";
    no strict 'refs';
    &$sub;
}

# Say text with SSML ($ssml) with the default program
sub sayssml {
    my $sub = "sayssml_$SPEAK_PROG";
    no strict 'refs';
    &$sub;
}

######################################################################
# Auto-set volume
#
# An die Umgebungslautstärke anpassen. Das arbeitet zurzeit mit einer
# Heuristik: auf Hauptstraßen wird lauter gesprochen, auf Nebenstraßen
# leiser. XXX Die Heuristik könnte man verbessern, indem auch für
# comments_kfz>0 lauter und für NN+green leiser gesprochen wird. XXX
# Alternativ könnte eine Analyse der Umgebungslautstärke per Mikrofon
# durchführen.

sub set_volume_for_current_point {
    return if $dont_auto_set_volume;
    my $nearest_object = shift;
    my $cat = $nearest_object->{StreetObj}[Strassen::CAT()];
    if (defined $cat) {
	if ($cat =~ m{^(B|HH|H)\b}) {
	    set_volume('louder');
	} else {
	    set_volume('normal');
	}
    }
}

sub set_volume {
    return if $dont_auto_set_volume;
    my($value) = @_;
    if ($value eq 'normal') {
	$value = '65%';
    } elsif ($value eq 'louder') {
	$value = '85%';
    }
    return if (defined $old_volume && $value eq $old_volume); # no change
    warn "Change volumne from " . ($old_volume||"<unknown>") . " to $value...\n";
    system("amixer set Headphone $value on &");
    system("amixer set Master $value on &");
    $old_volume = $value;
}

######################################################################
# saydirection_...
#
# Say a direction ($next_street, $direction, $distance) with a
# specific program
#
sub saydirection_espeak   { saytext_espeak(make_german_direction(@_)) }
sub saydirection_mbrola   { saytext_mbrola(make_german_direction(@_)) }
sub saydirection_festival { saytext_festival(make_direction_for_english_festival(@_)) }

######################################################################
# sayssml_...
#
# Say text with SSML with a specific program
#
sub sayssml_festival {
    # no SSML support, just strip XML tags
    for (@_) {
	s{</?.*?>}{}g;
    }
    saytext_festival(@_);
}

sub sayssml_mbrola { _saytext_mbrola($_[0], ssml => 1) }

sub sayssml_espeak {
    my($say) = @_;
    warn "Will say '$say' (as SSML)\n";
    IPC::Run::run(["espeak", "-m", "-v", "de"], "<", \$say);
}

######################################################################
# saytext_...
#
# Say text with a specific program

# festival: optimized for English voice
sub saytext_festival {
    my $say = shift;
    warn "Will say '$say'\n";
    IPC::Run::run(["text2wave"], "<", \$say, "|", ["play", "-t", "wav", "-"]);
}

sub _fix_espeak {
    my $say = shift;
    $say =~ s{chaussee}{cho see}gi;
    $say =~ s{\bbellevue}{belle vü}gi;
    $say =~ s{ring\b}{rinngg}gi;
    $say;
}

# espeak: optimized for German voice
sub saytext_espeak {
    my($say) = @_;
    warn "Will say '$say'\n";
    $say = _fix_espeak($say);
    IPC::Run::run(["espeak", "-v", "de"], "<", \$say);
}

# mbrola: optimized for German voice
sub saytext_mbrola { _saytext_mbrola($_[0]) }

# Helper to handle normal and SSML (ssml => 1) text with mbrola:
sub _saytext_mbrola {
    my($say, %args) = @_;
    warn "Will say '$say'\n";
    require File::Temp;
    if (!$mbrola_tmp) {
	(undef, $mbrola_tmp) = File::Temp::tempfile(UNLINK => 1, SUFFIX => "_bbbike_mbrola.wav");
    }

    # otherwise there's no "sch" in "straße":
    #$say =~ s{(?<![ -])(straße)}{ $1}gi;
    $say =~ s{(?<![ -])s(traße)}{sch$1}gi;

    $say = _fix_espeak($say);

    IPC::Run::run(["espeak", ($args{ssml} ? "-m" : ()), "-v", "mb-$MBROLA_LANG"], "<", \$say, "|", [$MBROLA_BIN, "-e", $MBROLA_LANG_FILE, "-", $mbrola_tmp]);
    IPC::Run::run(["play", $mbrola_tmp]);
    unlink $mbrola_tmp;
}


######################################################################

# Remove cityparts
sub simplify_street {
    my $street = shift;
    $street = Strasse::strip_bezirk($street);
    $street = expand_de_abbrev($street);
    $street =~ s{\(}{}g;
    $street =~ s{\)}{}g;
    $street;
}

# expand "str." etc.
sub expand_de_abbrev {
    my $name = shift;
    $name =~ s{str\.}{straße}ig;
    $name =~ s{bhf\.}{bahnhof}ig;
    $name =~ s{\bwestl\.}{westlich}ig;
    $name =~ s{\böstl\.}{östlich}ig;
    $name =~ s{\bnördl\.}{nördlich}ig;
    $name =~ s{\bsüdl\.}{süddlich}ig;
    $name =~ s{\bdr\.}{doktor}ig;
    $name =~ s{\bst\.}{sankt}ig;
    $name =~ s{(zu[rm]\s+ehem)\.}{$1aligen}ig;
    $name =~ s{\behem\.}{ehemalig}ig;
    $name =~ s{\bkol\.}{kolonie}ig;
    $name =~ s{(\d+)-(\d+)}{$1 bis $2}ig;
    $name;
}

sub make_german_direction {
    my($next_street, $direction, $live_dist) = @_;
    $next_street = simplify_street($next_street);
    my $praeposition;
    my $say;
    if ($next_street =~ m{ - }) {
	$praeposition = "in Richtung";
	$next_street = Strasse::get_last_part($next_street);
    }
    if ($direction) {
	$say .= ($direction =~ /^h/ ? "halb" : "") . ($direction =~ /l$/i ? "links" : "rechts") . " abbiegen "; 
    }
    $praeposition = Strasse::de_artikel($next_street) if !$praeposition;
    $praeposition = "" if $praeposition eq '=>';
    $say .= "$praeposition $next_street";
    $say;
}

# This is a hack for festival with an English voice: say praepositions
# etc. in English, and mangle the street names to be pronounced like
# in German
sub make_direction_for_english_festival {
    my($next_street, $direction, $live_dist) = @_;
    $next_street = Strasse::strip_bezirk($next_street);
    $next_street =~ s{str\.}{shtrasse}ig;
    $next_street =~ s{allee\b}{ulleh}ig; # not nice
    $next_street =~ s{ufer\b}{oofer}ig; # not nice
    $next_street =~ s{w}{v}g;
    $next_street =~ s{z}{ts}g;
    $next_street =~ s{([blmnrvw])ein}{$1hein}g;
    $next_street =~ s{bundes}{boondehs}g;
    $next_street =~ s{[äÄ]}{ae}g;
    $next_street =~ s{[öÖ]}{oe}g;
    $next_street =~ s{[üÜ]}{y}g;
    $next_street =~ s{é}{e}g;
    $next_street =~ s{ß}{ss}g;
    $next_street =~ s{sch}{sh}g;
    $next_street =~ s{ch}{hh}g;
    $next_street =~ s{e\b}{eh}g;
    my $praeposition;
    my $say;
    if ($next_street =~ m{ - }) {
	$praeposition = "towards";
	$next_street = Strasse::get_last_part($next_street);
    }
    if ($direction) {
	$say .= "turn " . ($direction =~ /^h/ ? "half " : "") . ($direction =~ /l/i ? "left" : "right") . " ";
    }
    $praeposition = "into" if !$praeposition;
    $say .= "$praeposition $next_street";
    $say;
}

######################################################################
# Cleanups
sub deactivate_tracking {
    return if !$gps_fh;
    # Strange: I have to first kill and the close the fh. Otherwise
    # there's an implicite waitpid() call causing the process to hang
    # (?) (seen with strace).
    kill_gpspipe();
    $main::top->fileevent($gps_fh, 'readable', '');
    undef $gps_fh;
    $gpsd_checker->cancel if $gpsd_checker;
    undef $gpsd_checker;
    $gps_track_mode = 0;
}

sub kill_gpspipe {
    if ($gpspipe_pid) {
	if (kill 0 => $gpspipe_pid) {
	    #local $SIG{CHLD} = 'IGNORE';
	    kill 9 => $gpspipe_pid;
	} # else already killed?
	undef $gpspipe_pid;
    }
}

######################################################################
# Information to audible text
sub power_info {
    my %info = ( discharging_remaining => undef,
		 charging_remaining => undef,
		 state => "unknown",
		 msg_de => "Der Batterystatus ist unbekannt."
	       );
    lock_keys %info;
    if (is_in_path("acpi")) {
	my $battery_acpi_info;
	IPC::Run::run(["acpi", "-b"], ">", \$battery_acpi_info);
	my @batteries = split /\n/, $battery_acpi_info;
	# XXX How to calculate if there are multiple batteries?
	if (my($percent, $H, $M, $S) = $batteries[0] =~ m{discharging,\s+(\d+)%,\s+(\d+):(\d+):(\d+)\s+remaining}i) {
	    $info{state} = "discharging";
	    $info{discharging_remaining} = $H*3600+$M*60+$S;
	    $info{msg_de} = "Die Batterie hält noch " . de_time_period($H,$M) . ".";
	} elsif (($percent, $H, $M, $S) = $batteries[0] =~ m{\bcharging,\s+(\d+)%,\s+(\d+):(\d+):(\d+)\s+until charged}i) {
	    $info{state} = "charging";
	    $info{charging_remaining} = $H*3600+$M*60+$S;
	    $info{msg_de} = "Die Batterie wird in " . de_time_period($H,$M) . " aufgeladen sein.";
	} elsif ($batteries[0] =~ m{\bfull\b}i) {
	    $info{state} = "full";
	    $info{msg_de} = "Die Batterie ist voll aufgeladen.";
	} else {
	    $info{msg_de} = "Die ACPI-Ausgabe konnte nicht geparst werden. Die Ausabe lautet: $batteries[0].";
	}
    }
    %info;
}

sub gps_info_text_de {
    # assume current_accuracy etc. is already set
    my $msg = "";
    if ($current_accuracy == ACCURACY_NOTHING) { # XXX or check for gps mode?
	$msg .= "Es gibt zurzeit keinen GPS-Empfang. ";
    } elsif (!defined $current_accuracy) {
	$msg .= "Die GPS-Genauigkeit kann noch nicht ermittelt werden.";
    } else {
	my $int_acc = int $current_accuracy;
	$msg .= "Die GPS-Genauigkeit beträgt " . ($int_acc == 1 ? "einen " : "$int_acc ") . "Meter.";
    }
    $msg;
}

sub de_time_period {
    my($H,$M,$S,%args) = @_;
    $_+=0 for ($H,$M,$S); # avoid things like "02 Stunden"    
    my $msg = ($H >= 2 ? "$H Stunden " :
	       $H >= 1 ? "eine Stunde " :
	       ""
	      );
    if ($msg && $M) {
	$msg .= "und ";
    }
    $msg .= ($M >= 2 ? "$M Minuten " :
	     $M >= 1 ? "eine Minute " :
	     ""
	    );
    if ($S &&
	($msg eq '' || ($args{maybe}||'') ne 'seconds')
       ) {
	if ($msg) {
	    $msg .= "und ";
	}
	$msg .= ($S >= 2 ? "$S Sekunden" :
		 $S >= 1 ? "eine Sekunde" :
		 ""
		);
    }
    $msg =~ s{\s+$}{};
    if ($msg eq '') {
	$msg = 'eine unbekannte Zeitdauer';
    }
    $msg;
}

return 1 if caller;

######################################################################
# Just for quick testing with a sample NMEA file.
package main;
require Tk;
use vars qw($top);
my $file = shift
    or die "NMEA file?";
$top = MainWindow->new;
BBBikeGPSTrackingPlugin::activate_dummy_tracking($file);
Tk::MainLoop();

__END__

=pod

Needs gpsd installed and running, or altenatively perl-GPS which is
not yet on CPAN (because of some GPS::NMEA changes)

Speech check (using espeak, alternatively can use festival, but only
with English voice):

    grep -v '^#' data/strassen|tail -n +20 |perl -nle 'm{^([^\t]+)} and print $1' |uniq|perl -Ilib -Imiscsrc -MBBBikeGPSTrackingPlugin -nle 'package BBBikeGPSTrackingPlugin; saydirection($_)'

Some observations:

the accuracy as returned from the PGRME NMEA command is twice of what
the Garmin etrex Vista HCx is reporting.

More snippets:

  Say the current power information:

    perl -Ilib -Imiscsrc -MBBBikeGPSTrackingPlugin -e 'package BBBikeGPSTrackingPlugin; saytext({power_info()}->{msg_de})'

  Say something using mbrola (see source code for exact setup!)

    perl -Ilib -Imiscsrc -MBBBikeGPSTrackingPlugin -e 'package BBBikeGPSTrackingPlugin; $SPEAK_PROG="mbrola"; saytext("@ARGV")' irgendein Text

  Use female mbrola voice:

    perl -Ilib -Imiscsrc -MBBBikeGPSTrackingPlugin -e 'package BBBikeGPSTrackingPlugin; $SPEAK_PROG="mbrola"; $MBROLA_LANG = "de7"; saytext("@ARGV")' irgendein Text

  Say the current (faked) GPS information:

    perl -Ilib -Imiscsrc -MBBBikeGPSTrackingPlugin -e 'package BBBikeGPSTrackingPlugin; $current_accuracy = 9999; saytext(gps_info_text_de())'

    perl -Ilib -Imiscsrc -MBBBikeGPSTrackingPlugin -e 'package BBBikeGPSTrackingPlugin; $current_accuracy = 12; saytext(gps_info_text_de())'

  A GPS mode change:

    perl -Ilib -Imiscsrc -MBBBikeGPSTrackingPlugin -e 'package BBBikeGPSTrackingPlugin; $do_speech=1; $current_accuracy = 12; $current_sat_used = 2; gps_mode_change(shift)' 1

=head2 TODO

=head3 Navigation

 * Die aktuelle Richtung muss unbedingt in die Berechnung der Position
   und Richtung eingehen! Damit kann das Problem der kreuzenden
   Nebenstraßen behoben werden.

 * Je nachdem, wie genau der GPS-Empfang ist, sollte die Vorwarnung
   früher oder später kommen.

 * Vorwarnzeit sollte von der prognostizierten Zeit (bisherige
   Geschwindigkeit, zukünftige Geschwindigkeit, Entfernung) statt nur
   von der Entfernung abhängen.

 * Je nachdem, wie kompliziert die Wegführung ist (ggfs. frühzeitiges
   Einordnen!) sollte eine Vorwarnung früher oder später kommen. Z.B.
   Linksabbiegen auf einer Hauptstraße sehr früh, Linksabbiegen auf
   einer Nebenstraße etwas früher, Geradeausfahren oder
   Rechtsabbiegen: etwas später.

 * Die Information der Straßenbreiten in die Vorwarnungszeit mit
   aufnehmen.

 * Bug: manchmal wird "rechts" oder "links" nicht gesprochen,
   wahrscheinlich, weil es kein "ImportantAngle" ist. Den Algorithmus
   nochmals überprüfen! -> Hoffentlich gelöst!

 * Bei Abweichen von der Route sollte es zwei Modi geben:

   * Wenn nur ein Ziel angegeben wurde, dann sollte eine komplette
     Neuberechnung bis zum Ziel erfolgen. -> Implementiert!

   * Wenn eine Wunschroute angegeben wurde, dann sollte eine möglichst
     direkte Strecke zurück zur Wunschroute gefunden werden, aber
     möglichst ohne den Fahrer umdrehen zu lassen.

 * Allgemeine Vias angeben (Briefkasten, Geldautomat ...)

=head3 Speech

 * An die Umgebungslautstärke anpassen. Das könnte einerseits mit
   einem Mikrofon und der Analyse der Lautstärke passieren, oder man
   arbeitet mit einer Heuristik: auf Hauptstraßen und
   comments_kfz>0-Straßen wird lauter gesprochen, auf Nebenstraßen
   leiser. Evtl. sehr leise, wenn NN+green.

   Siehe auch "-a ..." (Amplitude) bei espeak. 100 ist normal, 200 ist
   etwas lauter. Oder mit dem Mixer (amixer set Master ...) arbeiten.

   amixer headphone 65%: reicht für Nebenstraßen, aber nicht für
   Hauptstraßen.

       amixer set Headphone 65% on

 * Das Programm soll per Audio warnen, wenn sich die GPS-Genauigkeit
   verschlechtert oder gar der Fix verloren geht. Es sollte auch einen
   Hinweis bei einer wieder aufgenommenen GPS-Verbindung geben, aber
   es sollte auch Flapping erkannt werden.

 * Falls kein GPS-Empfang mehr da ist, könnte das Programm trotzdem
   noch weiterhelfen, indem es die bisherige Geschwindigkeit annimmt
   und mit dieser Zeit weiter navigiert.

 * Komplizierte Wegführungen zusammenfassen, z.B. wenn innerhalb von
   wenigen Metern mehrfach abgebogen werden muss (Beispiel:
   Kreuzberg-, Methfesselstr. )

 * Verschiedene Quasselstufen: der Bereich fängt an bei den nur
   wichtigsten Sachen (Abbiegevorgänge) bis hin zu der Kommentierung
   jeder Kreuzung. Folgende Punkte könnten gesprochen werden:

   * Abbiegevorgänge

   * neuer Straßenname bei Geradeausfahrten

   * Vorfahrtsregelung (rechts-vor-links, Vorfahrt gewähren, nicht der
     abknickenden Vorfahrt folgen, bei höheren Quasselstufen auch
     Ampel und Vorfahrt)

   * Radwegeregelung (Benutzungspflicht, Radspur etc.)

   * interessante Qualitätsänderungen (Kopfsteinpflaster...)

   * interessante Handicapveränderungen

   * ausgeschilderte Radrouten

   * comments_danger

   * Steigungen, Gefälle (unterschiedliche Quasselstufen ->
     unterschiedliche Mindestprozentzahlen)

   * jede Nebenstraße kommentieren

   * bei langen Geradeausfahrten diese ankündigen (mit Zeit und
     Entfernung)

   * warnen, wenn die Batteriedauer nicht bis zur Ankunftszeit reichen
     würde (aber auch hier Flapping entdecken!)

   * Aktueller GPS-Status (falls lange nicht gesagt und schon lange
     nichts anderes gesagt wurde) (kurz: "2D-Fix", "3D-Fix", oder: "n
     Sateliten von m werden angezapft" ..., oder nur die horizontale
     Genauigkeit)

   * Aktueller Batterie-Status (falls lange nicht gesagt und schon
     lange nichts anderes gesagt wurde)

   * Aktuelle Geschwindigkeit und bisherige
     Durchschnittsgeschwindigkeit, vielleicht auch eine Prognose?

   * Ankunftszeit, relativ und absolut

   * Entfernung bis zum Ziel

   * "Sie haben Ihr Ziel erreicht"

   * Evtl. Empfehlungen zur optimalen Geschwindigkeit, zum Beispiel
     bei bekannten Ampelschaltungen und erkannter Wartezeit vor einer
     roten Ampel. Zumindest kann die Dauer einer Rot/Grünphase
     angesagt werden.

   Es sollte darauf geachtet werden, dass wichtige Ansagen nicht von
   unwichtigen überschattet werden. Vielleicht sollte man mit
   Minimalpausen zwischen Texten arbeiten.

   Sinnvoll ist wohl auch, die Wartezeit an roten Ampeln mit Angaben
   zu nutzen. Dann ist man am wenigsten abgelenkt.

 * Bessere Heursistik, um das Wiederholen von Straßennamen zu
   vermeiden (besser als der derzeitige seen-Hash)

 * saytext sollte nicht blockieren, sondern lieber einen Lock setzen.
   Es gibt Prioritäten für gesprochenen Text: falls ein höher
   priorisierter Text sofort gesprochen werden soll, dann kann er
   einen niedriger priorisierten unterbrechen, vielleicht mit einem
   Füllwort wie "sorry" oder so.

=head3 Internationalization

 * English texts

 * Other customs?

=cut
