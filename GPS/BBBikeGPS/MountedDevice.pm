# -*- mode:perl; coding:iso-8859-1 -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2014 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

{
    package GPS::BBBikeGPS::MountedDevice;
    require GPS;
    push @GPS::BBBikeGPS::MountedDevice::ISA, 'GPS';

    use vars qw($VERSION);
    $VERSION = '0.02';

    sub has_gps_settings { 1 }

    sub transfer_to_file { 0 }

    sub ok_label { "Kopieren auf das Gerät" } # M/Mfmt XXX

    sub tk_interface {
	my($self, %args) = @_;
	BBBikeGPS::tk_interface($self, %args, -uniquewpts => 0);
    }

    sub convert_from_route {
	my($self, $route, %args) = @_;

	# do not delete the following, needed also in simplify_for_gps
	my $waypointlength = $args{-waypointlength};
	my $waypointcharset = $args{-waypointcharset};

	require File::Temp;
	require Route::Simplify;
	require Strassen::Core;
	require Strassen::GPX;
	my $simplified_route = $route->simplify_for_gps(%args, -uniquewpts => 0,
							-leftrightpair  => ['<- ', ' ->'],
							-leftrightpair2 => ['<\\ ',' />'],
						       );
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

	my($mount_point, $mount_device, @mount_opts);
	# XXX configuration stuff vvv
	if ($^O eq 'freebsd') {
	    $mount_point = '/mnt/garmin-internal';
	    # XXX unfortunately "camcontrol devlist" is restricted to root on FreeBSD; one could fine the information here!
	    # XXX as a workaround, look into /var/log/messages
	    require Tie::File;
	    require Fcntl;
	    if (tie my @log, 'Tie::File', '/var/log/messages', mode => Fcntl::O_RDONLY()) {
		for(my $log_i = $#log; $log_i>=0; $log_i--) {
		    if ($log[$log_i] =~ m{kernel: ([^:]+): <Garmin GARMIN Flash}) {
			$mount_device = "/dev/$1";
			warn "Guess garmin internal card to be '$mount_device'...\n";
			last;
		    }
		}
	    }
	    if (!defined $mount_device) {
		$mount_device = '/dev/da0';
		warn "Cannot find garmin internal card in /var/log/messages, use a '$mount_device' as fallback...\n";
	    }
	    @mount_opts = (-t => 'msdosfs');
	} elsif ($^O eq 'MSWin32') {
	    require Win32Util;
	    for my $drive (Win32Util::get_drives()) {
		my $vol_name = Win32Util::get_volume_name("$drive\\");
		if (defined $vol_name && $vol_name =~ m{garmin}i) {
		    $mount_point = $drive;
		    last;
		}
	    }
	    if (!$mount_point) {
		main::status_message("The Garmin device is not mounted --- is the device in USB mass storage mode?", 'error');
		return;
	    }
	} else { # e.g. linux, assume device is already mounted
	    my @mount_point_candidates = (
					  '/media/' . eval { scalar getpwuid $< } . '/GARMIN',     # e.g. Ubuntu 13.10
					  '/media/GARMIN',                                         # e.g. Mint 13
					  '/run/media/' . eval { scalar getpwuid $< } . '/GARMIN', # e.g. Fedora 20
					 );
	    for my $mount_point_candidate (@mount_point_candidates) {
		if (_is_mounted($mount_point_candidate)) {
		    $mount_point = $mount_point_candidate;
		    last;
		}
	    }
	    if (!$mount_point) {
		main::status_message("The Garmin device is not mounted in the expected mount points (tried @mount_point_candidates)", 'error');
		return;
	    }
	}
	# XXX configuration stuff ^^^
	my $subdir = 'Garmin/GPX'; # XXX configuration parameter, default for Garmin

	my $need_umount;
	if (!_is_mounted($mount_point)) {
	    if ($mount_device) {
		my @mount_cmd = ('mount', @mount_opts, $mount_device, $mount_point);
		system @mount_cmd;
		if ($? != 0) {
		    die "Command <@mount_cmd> failed";
		}
		if (!_is_mounted($mount_point)) {
		    # This seems to be slow, so loop for a while
		    main::status_message("Mounting is slow, wait for a while...", "infoauto");
		    my $success;
		    eval {
			for (1..20) {
			    sleep 1;
			    if (_is_mounted($mount_point)) {
				$success = 1;
				last;
			    }
			}
		    };
		    warn $@ if $@;
		    main::info_auto_popdown();
		    if (!$success) {
			die "Mounting using <@mount_cmd> was not successful";
		    }
		}
		$need_umount = 1;
	    } else {
		main::status_message("Please mount the Garmin device on $mount_point manually", 'error');
		return;
	    }
	}

	(my $safe_routename = $simplified_route->{routename}) =~ s{[^A-Za-z0-9_-]}{_}g;
	require POSIX;
	$safe_routename = POSIX::strftime("%Y%m%d_%H%M%S", localtime) . '_' . $safe_routename . '.gpx';

	require File::Copy;
	my $dest = "$mount_point/$subdir/$safe_routename";
	File::Copy::cp($ofile, $dest)
		or die "Failure while copying $ofile to $dest: $!";

	unlink $ofile; # as soon as possible

	if ($need_umount) {
	    system("umount", $mount_point);
	    if ($? != 0) {
		die "Umounting $mount_point failed";
	    }
	    if (_is_mounted($mount_point)) {
		die "$mount_point is still mounted, despite of umount call";
	    }
	} else {
	    # Make sure file is really written if possible
	    if (eval { require File::Sync; 1 }) {
		if (open my $fh, $dest) {
		    File::Sync::fsync($fh);
		}
	    } elsif (eval { require BBBikeUtil; 1 } && BBBikeUtil::is_in_path('fsync')) {
		system('fsync', $dest);
	    }
	}
    }

    sub transfer { } # NOP

    sub _is_mounted { # XXX use a module?
	if ($^O eq 'MSWin32') {
	    # at this point we assume that the device is already ready
	    return 1;
	} else {
	    my $directory = shift;
	    open my $fh, "-|", "mount" or die "Can't call mount: $!";
	    while(<$fh>) {
		if (m{ \Q$directory\E }) {
		    return 1;
		}
	    }
	    0;
	}
    }

}

1;

__END__
