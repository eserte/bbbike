# -*- perl -*-

#
# $Id: BBBikeGPSTrackingPlugin.pm,v 1.1 2009/03/06 20:52:49 eserte Exp $
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
use vars qw($VERSION);
$VERSION = 0.01;

use GPS::NMEA 1.12;

use Karte::Polar;
use Karte::Standard;

use vars qw($gps_track_mode $gps $gps_fh $replay_speed);

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
    my $Radiobutton = $main::Radiobutton;
    my %radio_args =
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
    my $b = $mf->$Radiobutton
	(-text => "GPS",
	 %radio_args,
	);
    BBBikePlugin::replace_plugin_widget($mf, $b, __PACKAGE__.'_on');
    $main::balloon->attach($b, -msg => "GPS Tracking")
	if $main::balloon;

    BBBikePlugin::place_menu_button
	    ($mmf,
	     # XXX Msg.pm
	     [[Button => "Satellite view",
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
	     -topmenu => [Radiobutton => 'GPS Tracking',
			  %radio_args,
			 ],
	    );

    $mmf->Subwidget(__PACKAGE__."_menu")->menu;
}

sub activate_tracking {
    $gps = GPS::NMEA->new(Port => "/dev/ttyS0", Baud=>4800) # make configurable!!!
	or main::status_message("Cannot open GPS device: $!", "die");
    $replay_speed = undef;
    _setup_fileevent($gps);
}

sub activate_dummy_tracking {
    my $file = shift;
    $gps = GPS::NMEA->new(Port => "/dev/ttyS0", Baud=>4800, do_not_init => 1) # make configurable!!!
	or main::status_message("Cannot create GPS::NMEA object: $!", "die");
    open my $fh, "<", $file
	or main::status_message("Cannot open $file: $!", "die");
    $replay_speed = 1; # XXX configurable
    _setup_fileevent($gps, $fh);
}

sub _setup_fileevent {
    my($gps, $fh) = @_;
    my $line;
    my $last_seconds;
    $fh = $gps->serial if !$fh;
    $gps_fh = $fh;
    my $callback;
    $callback = sub {
	if ($fh->eof) {
	    deactivate_tracking();
	    return;
	}
	$line .= $fh->getline;
	if ($line =~ /\n/) {
	    my $short_cmd = $gps->parse_line($line);
	    if ($short_cmd eq "GPRMC") {
		my $d = $gps->{NMEADATA};
		if ($d->{lat_ddmm} ne '') {
		    my $lat = $gps->parse_ddmm_coords($d->{lat_ddmm});
		    if ($d->{lat_NS} eq 'S') { $lat *= -1 }
		    my $lon = $gps->parse_ddmm_coords($d->{lon_ddmm});
		    if ($d->{lon_EW} eq 'W') { $lon *= -1 }
		    if ($replay_speed) {
			my($H,$M,$S) = $d->{time_utc} =~ m{^(\d\d)(\d\d)(\d\d)};
			my $this_seconds = $S+$M*60+$H*3600;
			if (defined $last_seconds) {
			    if ($last_seconds > $this_seconds) {
				# day rotation
				$last_seconds -= 86400;
			    }
			    my $sleep_time = ($this_seconds - $last_seconds)/$replay_speed;
			    die "should never happen: $sleep_time" if $sleep_time < 0;
			    $last_seconds = $this_seconds;
			    $main::top->fileevent($fh, 'readable', ''); # suspend
			    $main::top->after($sleep_time, sub {
						  set_position($lon, $lat);
						  $main::top->fileevent($fh, 'readable', $callback);
					      });
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

sub set_position {
    my($lon, $lat) = @_;
    my($x,$y) = main::transpose($Karte::Polar::obj->map2standard($lon,$lat));
    main::mark_point(-x => $x, -y => $y);		     
}

sub deactivate_tracking {
    return if !$gps_fh;
    $main::top->fileevent($gps_fh, 'readable', '');
    undef $gps_fh;
    $gps_track_mode = 0;
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
