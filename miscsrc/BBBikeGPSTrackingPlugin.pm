# -*- perl -*-

#
# $Id: BBBikeGPSTrackingPlugin.pm,v 1.3 2009/03/06 20:53:32 eserte Exp $
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
$VERSION = 0.01;

$DEBUG = 0;

use GPS::NMEA 1.12;

use Karte::Polar;
use Karte::Standard;

use vars qw($gps_track_mode $gps $gps_fh $replay_speed_conf @gps_track $gpspipe_pid $dont_auto_center $dont_auto_track);
$replay_speed_conf = 1 if !defined $replay_speed_conf;

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
    my %check_args =
	(-variable => \$gps_track_mode,
	 -command  => sub {
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
	 },
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
	      [Button => "Satellite view",
	       -command => sub { die "NYI" },
	      ],
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

sub activate_tracking {
    # XXX decide whether to use GPS::NMEA or gpsd
    activate_gpsd_tracking();
}

sub activate_nmea_tracking {
    $gps = GPS::NMEA->new(Port => "/dev/ttyS0", Baud=>4800) # make configurable!!!
	or main::status_message("Cannot open GPS device: $!", "die");
    _setup_fileevent($gps);
}

sub activate_gpsd_tracking {
    kill_gpspipe();
    $gpspipe_pid = open my $fh, "-|", "gpspipe", "-r"
	or die "Cannot execute gpspipe: $!";
    # just a dummy, for parsing and so
    $gps = GPS::NMEA->new(Port => "/dev/ttyS0", Baud=>4800, do_not_init => 1) # make configurable!!!
	or main::status_message("Cannot create GPS::NMEA object: $!", "die");
    _setup_fileevent($gps, $fh);
}

sub activate_dummy_tracking {
    my $file = shift;
    $gps = GPS::NMEA->new(Port => "/dev/ttyS0", Baud=>4800, do_not_init => 1) # make configurable!!!
	or main::status_message("Cannot create GPS::NMEA object: $!", "die");
    open my $fh, "<", $file
	or main::status_message("Cannot open $file: $!", "die");
    _setup_fileevent($gps, $fh, $replay_speed_conf);
}

sub _setup_fileevent {
    my($gps, $fh, $replay_speed) = @_;
    my $line;
    my $last_seconds;
    $fh = $gps->serial if !$fh;
    $gps_fh = $fh;
    my $callback;
    $callback = sub {
	if ($fh->eof) {
	    warn "End of file.\n" if $DEBUG;
	    deactivate_tracking();
	    return;
	}
	$line .= $fh->getline;
	if ($line =~ /\n/) {
	    my $short_cmd = $gps->parse_line($line);
	    if (defined $short_cmd && $short_cmd eq "GPRMC") {
		my $d = $gps->{NMEADATA};
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
		}
	    }
	    $line = '';
	}
    };
    $main::top->fileevent($fh, 'readable', $callback);
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
	$main::c->createLine($x,$y,$x,$y, -width => 5, -fill => 'red',
			     -capstyle => $main::capstyle_round,
			     -tags => ['gps_track', 'gps_track_head'],
			    );
    }

    # Track
    if (!$dont_auto_track) {
	if (!@gps_track || $gps_track[-1] ne "$sx,$sy") {
	    if (@gps_track) {
		$main::c->createLine(main::transpose(split /,/, $gps_track[-1]), $x, $y,
				     -tags => ['gps_track']);
	    }
	    push @gps_track, "$sx,$sy";
	}
    }
}

sub deactivate_tracking {
    return if !$gps_fh;
    $main::top->fileevent($gps_fh, 'readable', '');
    undef $gps_fh;
    $gps_track_mode = 0;
    kill_gpspipe();
}

sub kill_gpspipe {
    if ($gpspipe_pid && kill 0 => $gpspipe_pid) {
	kill 9 => $gpspipe_pid;
	undef $gpspipe_pid;
    }
}

return 1 if caller;

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

TODO - does not work yet!

Needs perl-GPS which is not yet on CPAN (because of GPS::NMEA changes)

=cut
