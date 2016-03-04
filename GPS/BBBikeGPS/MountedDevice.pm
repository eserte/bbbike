# -*- mode:perl; coding:iso-8859-1 -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2014,2015,2016 Slaven Rezic. All rights reserved.
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

    use strict;
    use vars qw($VERSION);
    $VERSION = '0.04';

    sub has_gps_settings { 1 }

    sub transfer_to_file { 0 }

    sub ok_label { "Kopieren auf das Gerät" } # M/Mfmt XXX

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
	_status_message("Could not create temporary file: $!", "die") if !$ofh;
	print $ofh $s->bbd2gpx(-as => "route",
			       -name => $simplified_route->{routename},
			       -number => $args{-routenumber},
			       #-withtripext => 1,
			      );
	close $ofh;

	$self->maybe_mount
	    (sub {
		 my($mount_point) = @_;

		 my $subdir = 'Garmin/GPX'; # XXX configuration parameter, default for Garmin

		 (my $safe_routename = $simplified_route->{routename}) =~ s{[^A-Za-z0-9_-]}{_}g;
		 require POSIX;
		 $safe_routename = POSIX::strftime("%Y%m%d_%H%M%S", localtime) . '_' . $safe_routename . '.gpx';

		 require File::Copy;
		 my $dest = "$mount_point/$subdir/$safe_routename";
		 File::Copy::cp($ofile, $dest)
			 or die "Failure while copying $ofile to $dest: $!";

		 unlink $ofile; # as soon as possible

		 +{ files => [$dest] };
	     });

    }

    sub transfer { } # NOP

    sub maybe_mount {
	my(undef, $cb, %opts) = @_;

	######################################################################
	# do the mount (maybe)

	my($mount_point, $mount_device, @mount_opts);
	# XXX configuration stuff vvv
	if ($^O eq 'freebsd') {
	    my $garmin_disk_type = 'flash';
	    $mount_point = '/mnt/garmin-internal';
	    $mount_device = _guess_garmin_mount_device_via_hal($garmin_disk_type);
	    if (!defined $mount_device) {
		warn "Cannot get garmin $garmin_disk_type via hal, try fallback via log...\n";
		$mount_device = _guess_garmin_mount_device_freebsd_via_log($garmin_disk_type);
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
		_status_message("The Garmin device is not mounted --- is the device in USB mass storage mode?", 'error');
		return;
	    }
	} else { # e.g. linux, assume device is already mounted
	    my @mount_point_candidates = (
					  '/media/' . eval { scalar getpwuid $< } . '/GARMIN',     # e.g. Ubuntu 13.10, Mint 17
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
		_status_message("The Garmin device is not mounted in the expected mount points (tried @mount_point_candidates)", 'error');
		return;
	    }
	}
	# XXX configuration stuff ^^^

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
		    _status_message("Mounting is slow, wait for a while...", "infoauto");
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
		    _info_auto_popdown();
		    if (!$success) {
			die "Mounting using <@mount_cmd> was not successful";
		    }
		}
		$need_umount = 1;
	    } else {
		_status_message("Please mount the Garmin device on $mount_point manually", 'error');
		return;
	    }
	}

	######################################################################
	# call the callback

	my $info = $cb->($mount_point);

	######################################################################
	# do the unmount (maybe)

	if ($need_umount) {
	    system("umount", $mount_point);
	    if ($? != 0) {
		die "Umounting $mount_point failed";
	    }
	    if (_is_mounted($mount_point)) {
		die "$mount_point is still mounted, despite of umount call";
	    }
	} else {
	    # Make sure generated file(s) are really written if possible
	    if (ref $info eq 'HASH' && $info->{files}) {
		my @sync_files = @{ $info->{files} || [] };
		if (eval { require File::Sync; 1 }) {
		    for my $sync_file (@sync_files) {
			if (open my $fh, $sync_file) {
			    File::Sync::fsync($fh);
			}
		    }
		} elsif (eval { require BBBikeUtil; 1 } && BBBikeUtil::is_in_path('fsync')) {
		    system('fsync', @sync_files);
		}
	    }
	}

    }

    sub get_gps_device_status {
	my(undef, $disk_type, $inforef) = @_;
	if ($^O eq 'freebsd') {
	    my $halinfo;
	    my $mount_device = _guess_garmin_mount_device_via_hal($disk_type, \$halinfo);
	    if (!$mount_device) {
		if ($halinfo =~ m{^disk not found}) {
		    $$inforef = $halinfo if $inforef;
		    return 'unattached';
		} else {
		    $$inforef = $halinfo if $inforef;
		    return 'unknown';
		}
	    } else {
		$$inforef = "device is $mount_device" if $inforef;
		return 'attached';
	    }
	} else {
	    die "NYI for OS $^O";
	}
    }

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

    # no fallback, return undef if lshal operation not possible
    sub _guess_garmin_mount_device_via_hal {
	my($garmin_disk_type, $inforef) = @_;

	if (!eval { require BBBikeUtil; 1 } && BBBikeUtil::is_in_path('lshal')) {
	    $$inforef = 'cannot detect: lshal unavailable' if $inforef;
	    return;
	}

	# XXX Is this true for all garmin devices? What about other
	# GPS devices?
	my $uid_suffix = ($garmin_disk_type eq 'flash' ? 'GARMIN_Flash' :
			  $garmin_disk_type eq 'card'  ? 'GARMIN_Card' :
			  die "Only 'flash' and 'card' supported for garmin disk type"
			 );
	my $uid = '/org/freedesktop/Hal/devices/storage_model_' . $uid_suffix;
	my @cmd = ('lshal', '-u', $uid);
	open my $fh, '-|', @cmd
	    or do {
		warn "Error running @cmd: $!";
		$$inforef = "cannot detect: error running lshal: $!" if $inforef;
		return;
	    };
	while(<$fh>) {
	    if (/^\s+block\.device\s*=\s*'(.*?)'/) {
		return $1;
	    }
	}

	$$inforef = 'disk not found' if $inforef;
	return;
    }

    # with fallback (/dev/da0 or /dev/da1)
    sub _guess_garmin_mount_device_freebsd_via_log {
	my($garmin_disk_type) = @_;

	# XXX Is this true for all garmin devices? What about other
	# GPS devices?
	my $search_string = ($garmin_disk_type eq 'flash' ? '<Garmin GARMIN Flash' :
			     $garmin_disk_type eq 'card'  ? '<Garmin GARMIN Card' :
			     die "Only 'flash' and 'card' supported for garmin disk type"
			    );

	# XXX unfortunately "camcontrol devlist" is restricted to root on FreeBSD; one could fine the information here!
	# XXX as a workaround, look into /var/log/messages
	require Tie::File;
	require Fcntl;
	if (tie my @log, 'Tie::File', '/var/log/messages', mode => Fcntl::O_RDONLY()) {
	    for(my $log_i = $#log; $log_i>=0; $log_i--) {
		if ($log[$log_i] =~ m{kernel: ([^:]+): \Q$search_string}) {
		    my $mount_device = "/dev/$1";
		    warn "Guess garmin $garmin_disk_type to be '$mount_device'...\n";
		    return $mount_device;
		}
	    }
	}

	# XXX configuration stuff vvv
	my $mount_device = $garmin_disk_type eq 'flash' ? '/dev/da0' : '/dev/da1';
	# XXX configuration stuff ^^^
	warn "Cannot find garmin $garmin_disk_type /var/log/messages, use '$mount_device' as fallback...\n";
	$mount_device;
    }

    # Logging, should work within Perl/Tk app and outside
    sub _status_message {
	if (defined &main::status_message) {
	    main::status_message(@_);
	} else {
	    print STDERR "$_[0]\n";
	}
    }
    sub _info_auto_popdown {
	if (defined &main::info_auto_popdown) {
	    main::info_auto_popdown();
	} # no else
    }

}

1;

__END__

=head1 NAME

GPS::BBBikeGPS::MountedDevice - handle gps uploads via a mounted device

=head1 DESCRIPTION

Currently support is only available for newer Garmin devices (e.g.
etrex 30).

=head2 Linux desktops

It is assumed that the device is mounted in a directory like
F</media/GARMIN> or F</run/media/$USER/GARMIN>.

=head2 Windows

It is assumed that the device is already mounted. The mounted drive is
detected automatically by inspecting the drive's volume name.

=head2 FreeBSD

On FreeBSD systems without desktop support GPS devices are not
automatically mounted. Therefore some conventions have to be followed:

=over

=item * Add the following lines to F</etc/fstab>. Make sure to replace
I<$USER> by the user normally logged in:

    /dev/da1        /mnt/garmin     msdosfs rw,noauto,-l,-u=$USER  0       0
    /dev/da0        /mnt/garmin-internal    msdosfs rw,noauto,-l,-u=$USER  0       0

=item * Create the referened directories F</mnt/garmin> and
F</mnt/garmin-internal> and chown it to the same I<$USER>:

    for i in /mnt/garmin /mnt/garmin-internal; do mkdir $i; chown $USER $i; done

=item * Install the C<hal> package (port: C<sysutils/hal>). This is
optional, but otherwise a fallback to a less secure log parsing
routine is done.

=item * (Maybe, not verified) Make sure that user mounts are possible by adding

    vfs.usermount=1

to F</etc/sysctl.conf>. Reload the settings:

    sudo service sysctl reload

=back

Currently by default route uploads happen to the internal flash, not
to an external SD card. This is hardcoded in the source code (search
for C<< my $garmin_disk_type = 'flash'; >>).

=head2 FUNCTIONS

The following functions may be used outside BBBike's GPS transfer
system:

=over

=item C<maybe_mount(I<coderef>)>

C<maybe_mount()> may also be called outside of the Perl/Tk application
for scripts which have to make sure that the Garmin device is mounted,
e.g. to copy from or to the mounted gps device. Simple usage example:

    perl -w -Ilib -MGPS::BBBikeGPS::MountedDevice -e 'GPS::BBBikeGPS::MountedDevice->maybe_mount(sub { my $dir = shift; system("ls -al $dir"); 1 })'

Currently only the internal flash card is supported, but in future
this can be controlled with options.

=item C<get_gps_device_status(I<disk_type>, I<inforef>)>

Return an availability status about the given gps device. Currently
only Garmin devices are supported, and there's only detection support
for FreeBSD systems.

The I<disk_type> parameter may be C<flash> (the internal GPS memory)
or C<card> (the optional SD card). The optional parameter I<inforef>
should be a reference to a scalar and will hold more textual
information (error messages, device information).

Possible return values are:

=over

=item * attached

The device is already attached and is ready for mounting.

=item * unattached

The device is not attached.

=item * unknown

We cannot get the device status, probably because of missing
prerequisites (e.g. L<lshal(1)> is missing).

=back

The following sample oneliner waits until the device is available:

    perl -w -Ilib -MGPS::BBBikeGPS::MountedDevice -e 'while () { $status = GPS::BBBikeGPS::MountedDevice->get_gps_device_status("flash", \$info); if ($status eq "unknown") { die "We cannot detect the gps device status: $info" } exit if $status eq "attached"; sleep 1 }'

=back

=cut
