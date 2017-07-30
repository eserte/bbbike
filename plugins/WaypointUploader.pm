# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2017 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Description (en): Create and upload waypoints to GPS device
# Description (de): Erzeugen und Hochladen von GPS-Waypoints zu einem Gerät
package WaypointUploader;

use BBBikePlugin;
push @ISA, 'BBBikePlugin';

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use Msg qw(frommain);

%main::info_plugins = %main::info_plugins if 0; # cease -w

sub register {
    $main::info_plugins{__PACKAGE__} =
	{ name => M"GPS-Waypoint hochladen",
	  callback => sub { upload_waypoint(@_) },
	};
}

use vars qw($last_wpt_name);

sub upload_waypoint {
    my(%args) = @_;
    my $px = $args{px};
    my $py = $args{py};

    require GPS::BBBikeGPS::MountedDevice;
    require Strassen::Core;
    require Strassen::GPX;

    my $tmp;
    my $t = $main::top->Toplevel(-title => M"GPS-Waypoint hochladen");
    $t->transient($main::top) if $main::transient;
    my $f1 = $t->Frame->pack;
    $f1->Label(-text => M("Waypoint-Name").":")->pack(-side => 'left');
    $f1->Entry(-textvariable => \$last_wpt_name)->pack(-side => 'left');
    my $cleanup = sub {
	$t->destroy;
	unlink $tmp if $tmp;
    };
    my $f2 = $t->Frame->pack;
    $f2->Button(-text => M"Hochladen",
		-command => sub {
		    require File::Temp;
		    $tmp = File::Temp->new(SUFFIX => '.gpx');
		    (my $normalized_name = $last_wpt_name) =~ s{[\n\t]}{ }g;
		    my $s0 = Strassen->new_from_data_string(<<EOF);
#: map: polar
#: 
$normalized_name\tX $px,$py
EOF
		    my $s = Strassen::GPX->new($s0);
		    print $tmp $s->Strassen::GPX::bbd2gpx;
		    close $tmp;

		    GPS::BBBikeGPS::MountedDevice->maybe_mount
			    (sub {
				 my($mount_point) = @_;
				 my $subdir = 'Garmin/GPX'; # XXX configuration parameter, default for Garmin

				 require POSIX;
				 my $wptfile = 'BBBike_Waypoints_' . POSIX::strftime("%Y%m%d_%H%M%S", localtime) . '.gpx';

				 require File::Copy;
				 my $dest = "$mount_point/$subdir/$wptfile";
				 File::Copy::cp("$tmp", $dest)
					 or main::status_message("Failure while copying $tmp to $dest: $!", 'error');
			     });

		    $cleanup->();
		})->pack(-side => 'left');
    $f2->Button(-text => M"Abbruch",
		-command => sub {
		    $cleanup->();
		},
	       )->pack(-side => 'left');
}


1;

__END__
