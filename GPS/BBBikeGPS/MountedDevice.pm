# -*- mode:perl; coding:iso-8859-1 -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2014,2015,2016,2017,2018,2020,2021,2023,2024 Slaven Rezic. All rights reserved.
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
    $VERSION = '0.26';

    sub has_gps_settings { 1 }

    sub transfer_to_file { 0 }

    sub ok_label { "Kopieren auf das Ger�t" } # M/Mfmt XXX
    sub ok_test_label { "Simulation" } # M/Mfmt XXX

    sub tk_interface {
	my($self, %args) = @_;
	BBBikeGPS::tk_interface($self, %args);
    }

    sub convert_from_route {
	my($self, $route, %args) = @_;

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

	return {
	    fh => $ofh,
	    file => $ofile,
	    route => $simplified_route,
	};
    }

    sub transfer {
	my($self, %args) = @_;

	my $res = $args{-res};
	my $ofile = $res->{file} || _status_message("FATAL ERROR: -res.file is missing", "die");
	my $route = $res->{route};

	local $ENV{BBBIKE_DEBUG_BBBIKEGPS_MOUNTEDDEVICE} = $ENV{BBBIKE_DEBUG_BBBIKEGPS_MOUNTEDDEVICE};
	if ($args{-test}) {
	    if (!$ENV{BBBIKE_DEBUG_BBBIKEGPS_MOUNTEDDEVICE}) {
		my $user_run_dir = "/run/user/$>"; # probably works only on contemporary Linux systems where this is a separate tmpfs mount
		if (!-d $user_run_dir) {
		    _status_message("Cannot simulate upload: no directory $user_run_dir available", "die");
		}
		my $gpx_dir = "$user_run_dir/Garmin/GPX";
		require File::Path;
		File::Path::make_path($gpx_dir);
		$ENV{BBBIKE_DEBUG_BBBIKEGPS_MOUNTEDDEVICE} = $user_run_dir;
		_status_message("Note: simulated GPX file will occur in $gpx_dir", 'infodlg');
	    } else {
		_status_message("Note: simulated GPX file will occur in $ENV{BBBIKE_DEBUG_BBBIKEGPS_MOUNTEDDEVICE}; maybe you have make sure that Garmin/GPX or a similar subdirectory exists.", 'infodlg');
	    }
	}

	$self->maybe_mount
	    (sub {
		 my($mount_point) = @_;

		 my $subdir;
		 my @try_subdirs = (
				    'Garmin/GPX', # e.g. Garmin etrex
				    'GPXImport',  # e.g. Falk Lux
				    'iGPSPORT/Courses', # e.g. iGPSPORT IGS630
				   );
		 for my $try_subdir (@try_subdirs) {
		     my $subdirpath = "$mount_point/$try_subdir";
		     if (-d $subdirpath) {
			 $subdir = $subdirpath;
			 last;
		     }
		 }
		 if (!defined $subdir) {
		     die "Cannot find a suitable directory in $mount_point, tried: @try_subdirs";
		 }

		 (my $safe_routename = $route->{routename}) =~ s{[^A-Za-z0-9_-]}{_}g;
		 require POSIX;
		 $safe_routename = POSIX::strftime("%Y%m%d_%H%M%S", localtime) . '_' . $safe_routename . '.gpx';

		 require File::Copy;
		 my $dest = "$subdir/$safe_routename";
		 File::Copy::cp($ofile, $dest)
			 or die "Failure while copying $ofile to $dest: $!";

		 unlink $ofile; # as soon as possible

		 +{ files => [$dest] };
	     },
	     with_tty => 0, # assume we're called always in a Tk-like environment
	    );

    }

    sub maybe_mount {
	my(undef, $cb, %opts) = @_;
	my $prefer_device = delete $opts{prefer_device};
	my $garmin_disk_type = delete $opts{garmin_disk_type} || 'flash';
	my $with_tty = exists $opts{with_tty} ? delete $opts{with_tty} : 1;
	die "Unhandled options: " . join(" ", %opts) if %opts;

	######################################################################
	# do the mount (maybe)

	my($mount_point, $mount_device, @mount_opts);
	my @mount_point_candidates;
	my $udisksctl; # will be set if Linux' DeviceKit is available
	if ($ENV{BBBIKE_DEBUG_BBBIKEGPS_MOUNTEDDEVICE}) { # set this to something like /run/user/$uid
	    $mount_point = $ENV{BBBIKE_DEBUG_BBBIKEGPS_MOUNTEDDEVICE};
	} elsif ($^O eq 'freebsd') { ##############################################
	    if ($garmin_disk_type ne 'flash') {
		die "NYI: only support for garmin_disk_type => flash available";
		# XXX actual problem is just the hardcoded $mount_point
	    }
	    $mount_point = '/mnt/garmin-internal'; # *** configuration ***
	    $mount_device = _guess_garmin_mount_device_via_hal($garmin_disk_type);
	    if (!defined $mount_device) {
		warn "Cannot get garmin $garmin_disk_type via hal, try fallback via log...\n";
		$mount_device = _guess_garmin_mount_device_freebsd_via_log($garmin_disk_type);
	    }
	    @mount_opts = (-t => 'msdosfs');
	} elsif ($^O eq 'MSWin32') { #########################################
	    if ($garmin_disk_type ne 'flash') {
		die "NYI: only support for garmin_disk_type => flash available";
		# XXX how to detect the SD card without a label?
	    }
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
	} elsif ($^O eq 'linux') { ###########################################
	    $udisksctl = _is_in_path('udisksctl');
	    my $func;
	    if (defined $udisksctl) {
		$func = {
			 parse_status   => \&_parse_udisksctl_status3,
			 find_mountable => \&_udisksctl_find_mountable,
			};
	    }
	    if ($func) {
		my $info_dialog_active;
		my $max_wait = 80; # full etrex 30 device boot until mass storage is available lasts 66-70 seconds
		my @check_mount_devices;
		if ($garmin_disk_type eq 'flash') {
		    @check_mount_devices = (
					    (defined $prefer_device ? '/dev/disk/by-label/'.$prefer_device : ()),
					    '/dev/disk/by-label/GARMIN', '/dev/disk/by-label/Falk', '/dev/disk/by-label/IGS630'
					   );
		} elsif ($garmin_disk_type eq 'card') {
		    my $disks = $func->{parse_status}->();
		    my @card_name_defs = ('Garmin GARMIN Card', 'Microsoft SDMMC');
		    my @errors;
		    my $seen_disks_diagnostics;
		CHECK_FOR_CARD: for my $card_name_def (@card_name_defs) {
			my $disk_info;
			if (ref $card_name_def eq 'Regexp') {
			    for my $check_card_name (sort keys %$disks) {
				if ($check_card_name =~ $card_name_def) {
				    $disk_info = $disks->{$check_card_name};
				    last;
				}
			    }
			} elsif ($disks->{$card_name_def}) {
			    $disk_info = $disks->{$card_name_def};
			} else {
			    my $msg = "Cannot find '$card_name_def'";
			    if (!$seen_disks_diagnostics++) {
				$msg .= ", only disks found: " . join(", ", keys %$disks);
			    }
			    push @errors, $msg;
			}

			if ($disk_info) {
			    my $check_mount_device = $func->{find_mountable}->('/dev/' . $disk_info->{DEVICE});
			    if (!defined $check_mount_device) {
				push @errors, "Cannot find a mountable filesystem on device '$disk_info->{DEVICE}'";
			    } else {
				push @check_mount_devices, $check_mount_device;
			    }
			}
		    }
		    if (!@check_mount_devices) {
			die "Error: " . join("\n", @errors) . "\n";
		    }
		} else {
		    die "Only support for garmin_disk_type 'flash' or 'card' available, not '$garmin_disk_type'";
		}
	    WAIT_FOR_DEVICE: for (1..$max_wait) {
		    for my $check_mount_device (@check_mount_devices) {
			if (-e $check_mount_device) {
			    $mount_device = $check_mount_device;
			    last WAIT_FOR_DEVICE;
			}
		    }
		    ## old, more complicated code
		    #require IPC::Open3;
		    #my($stdinfh,$stdoutfh,$stderrfh);
		    #my $pid = IPC::Open3::open3(
		    #				$stdinfh, $stdoutfh, $stderrfh,
		    #				$udisksctl, 'info', '-b', $check_mount_device,
		    #			       );
		    #waitpid $pid, 0;
		    #if ($? == 0) {
		    #	$mount_device = $check_mount_device;
		    #	last;
		    #}
		    if (!$info_dialog_active) {
			_status_message("Wait for GPS device (Garmin, Falk or iGPSPORT) (max $max_wait seconds)...", "infoauto");
			$info_dialog_active = 1;
		    }
		    sleep 1;
		}
		if ($info_dialog_active) {
		    _info_auto_popdown();
		}
		if (!$mount_device) {
		    die "No GPS device (Garmin or Falk) appeared in $max_wait seconds";
		}
	    } else {
		_status_message("udisksctl (from packages udisks2) not available, assume that device is already mounted", "info");
		my @device_names = qw(GARMIN Falk);
		@mount_point_candidates =
		    map {
			my $device_name = $_;
			map {
			    my $mnt_prefix = $_;
			    "$mnt_prefix/$device_name";
			} (
			   '/media/' . eval { scalar getpwuid $< },     # e.g. Ubuntu 13.10, Mint 17, Debian/jessie
			   '/media',                                    # e.g. Mint 13
			   '/run/media/' . eval { scalar getpwuid $< }, # e.g. Fedora 20
			  );
		    } @device_names;
		# try mounting later
	    }
	} elsif ($^O eq 'darwin') { ##########################################
	    if ($garmin_disk_type eq 'flash') {
		@mount_point_candidates = (
					   (defined $prefer_device ? '/Volumes/'.$prefer_device : ()),
					   '/Volumes/GARMIN',
					   '/Volumes/Falk', # XXX not tested
					   '/Volumes/IGS630',
					  );
	    } elsif ($garmin_disk_type eq 'card') {
		my $diskutil_list = _diskutil_list();

		my @disk_candidates;
		for my $disk (@{ $diskutil_list->{AllDisksAndPartitions} || [] }) {
		    if (exists $disk->{MountPoint} && $disk->{MountPoint} =~ m{^(/|/Volumes/GARMIN)$}) {
			# skip
		    } else {
			push @disk_candidates, $disk->{DeviceIdentifier};
		    }
		}

		my $garmin_card_disk;
		for my $disk_candidate (@disk_candidates) {
		    my $diskutil_info_disk = _diskutil_info($disk_candidate);
		    my $media_name = $diskutil_info_disk->{MediaName};
		    if (
			$media_name eq 'GARMIN Card'    ||
			$media_name eq 'GARMIN SD Card'
		       ) {
			$garmin_card_disk = $disk_candidate;
			last;
		    }
		}
		if (!$garmin_card_disk) {
		    die "Cannot find 'GARMIN Card' or 'GARMIN SD Card'";
		}

	    FIND_DISK: for my $disk (@{ $diskutil_list->{AllDisksAndPartitions} || [] }) {
		    if ($disk->{DeviceIdentifier} eq $garmin_card_disk) {
			if (exists $disk->{MountPoint}) {
			    @mount_point_candidates = ($disk->{MountPoint});
			    last FIND_DISK;
			}
			for my $partition (@{ $disk->{Partitions} || [] }) {
			    if (exists $partition->{MountPoint}) {
				@mount_point_candidates = ($partition->{MountPoint});
				last FIND_DISK;
			    }
			}
		    }
		}
		if (!@mount_point_candidates) {
		    die "Found 'GARMIN Card', but no mountable file system";
		}

	    } else {
		die "Only support for garmin_disk_type 'flash' or 'card' available, not '$garmin_disk_type'";
	    }
	} else {
	    _status_message("Don't know how to handle GPS device (Garmin or Falk) under operating system '$^O'", "info");
	}

	# At this point we have either
	# * $udiskctl defined (and $mount_device)
	# * $mount_point defined
	# * @mount_point_candidates maybe defined

	if (!$mount_point && !$udisksctl) {
	    if (@mount_point_candidates) {
		for my $mount_point_candidate (@mount_point_candidates) {
		    if (_is_mounted($mount_point_candidate)) {
			$mount_point = $mount_point_candidate;
			last;
		    }
		}
		if (!$mount_point) {
		    _status_message("The GPS device (Garmin or Falk) is not mounted in the expected mount points (tried @mount_point_candidates)", 'error');
		    return;
		}
	    } else {
		_status_message("We don't have any mount point candidates to check, so we don't know if the GPS device (Garmin or Falk) is already mounted", 'error');
	    }
	}

	my $need_umount;
	if ($udisksctl) {
	    my @info_cmd = ($udisksctl, 'info', '-b', $mount_device);
	    open my $fh, '-|', @info_cmd
		or die "Command @info_cmd failed: $!";
	    while(<$fh>) {
		if (/^\s*MountPoints:\s+(.*)$/) {
		    if (length $1) {
			$mount_point = $1;
			last;
		    }
		}
	    }
	    close $fh;

	    if (!defined $mount_point) {
		my @mount_cmd = ($udisksctl, 'mount', '-b', $mount_device);
		if (!$with_tty) {
		    push @mount_cmd, '--no-user-interaction';
		}
		open my $fh, '-|', @mount_cmd
		    or die "Command @mount_cmd failed: $!";
		my $res = <$fh>;
		close $fh;
		if ($? != 0) {
		    die "Running '@mount_cmd' failed";
		}
		if ($res =~ m{^Mounted \S+ at (.*)\.$}) {
		    $mount_point = $1;
		    $need_umount = 1;
		} else {
		    die "Cannot parse result line '$res'";
		}
	    }

	    die "ASSERTION FAILED: no mount point" if !defined $mount_point;
	} elsif (!_is_mounted($mount_point)) {
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
		_status_message("Please mount the GPS device (Garmin or Falk) on $mount_point manually", 'error');
		return;
	    }
	}
	
	######################################################################
	# call the callback, but don't fail at this point (do umount first)

	my $die;
	my $info = eval { $cb->($mount_point) };
	if ($@) {
	    $die = $@;
	}

	######################################################################
	# do the unmount (maybe)

	if ($need_umount) {
	    require IPC::Open3;
	    require Symbol;
	    my $max_wait = 10;
	    my $wait_start     = time;
	    my $wait_invisible = time + 1;
	    my $wait_until     = time + $max_wait;
	    my $info_dialog_active;
	    while () {
		my($stdinfh,$stdoutfh,$stderrfh);
		$stderrfh = Symbol::gensym(); # we create a symbol for the errfh because open3 will not do that for us 
		my $pid = IPC::Open3::open3(
					    $stdinfh, $stdoutfh, $stderrfh,
					    'umount', $mount_point,
					   );
		my $stderr = join '', <$stderrfh>;
		waitpid $pid, 0;
		if ($? == 0) {
		    last;
		}
		if ($stderr =~ /target is busy/) {
		    if (time > $wait_until) {
			die "$mount_point is still busy, cannot unmount";
		    }
		    if (!$info_dialog_active && time > $wait_invisible) {
			_status_message("Target is busy while running 'umount $mount_point', wait max. $max_wait seconds...", "infoauto");
			$info_dialog_active = 1;
		    }
		    if (time - $wait_start <= 1) {
			select undef, undef, undef, 0.1;
		    } else {
			sleep 1;
		    }
		} else {
		    die $stderr;
		}
	    }
	    if ($info_dialog_active) {
		_info_auto_popdown();
	    }
	    if (_is_mounted($mount_point)) {
		die "$mount_point is still mounted, despite of umount call";
	    }

	    if (defined $die) {
		die $die;
	    }
	} else {
	    if (defined $die) { # die early, no need to fsync here
		die $die;
	    }

	    # Make sure generated file(s) are really written if possible
	    if (ref $info eq 'HASH' && $info->{files}) {
		my @sync_files = @{ $info->{files} || [] };
		if (eval { require File::Sync; 1 }) {
		    for my $sync_file (@sync_files) {
			if (open my $fh, $sync_file) {
			    File::Sync::fsync($fh);
			}
		    }
		} elsif (_is_in_path('fsync')) {
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

    ######################################################################
    # FreeBSD (hal)

    # no fallback, return undef if lshal operation not possible
    sub _guess_garmin_mount_device_via_hal {
	my($garmin_disk_type, $inforef) = @_;

	if (!_is_in_path('lshal')) {
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

    ######################################################################
    # FreeBSD (log fallback)

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

    ######################################################################
    # Linux (udisksctl)

    # Use in a one-liner:
    #
    #    perl -I. -MGPS::BBBikeGPS::MountedDevice -MData::Dumper -e 'warn Dumper GPS::BBBikeGPS::MountedDevice::_parse_udisksctl_status()'
    #
    sub _parse_udisksctl_status {
	my(%opts) = @_;
	my $infostring = delete $opts{infostring}; # used for testing
	die "Unhandled options: " . join(" ", %opts) if %opts;

	my %disks;

	my $fh;
	if (defined $infostring) {
	    open $fh, '<', \$infostring or die $!;
	} else {
	    my @cmd = ('/usr/bin/udisksctl', 'status');
	    open $fh, '-|', @cmd
		or die "Error starting '@cmd': $!";
	}

	chomp(my $header = <$fh>);
	my(@f) = split /(\s+)/, $header;
	my @field_names = do { my $i; grep { $i++ % 2 == 0 } @f };
	my @lengths;
	for(my $i=0; $i<$#f; $i+=2) {
	    push @lengths, length($f[$i])+length($f[$i+1]);
	}
	my $unpack = join(" ", map { "a$_" } @lengths) . " a*";
	scalar <$fh>; # dashed line
	while(<$fh>) {
	    chomp;
	    my %f;
	    @f{@field_names} = map { s/\s+$//; $_ } unpack $unpack, $_;
	    $disks{$f{MODEL}} = \%f;
	}
	close $fh
	    or die "Error while closing filehandle (probably failure of running udisksctl command): $!";

	\%disks;
    }

    # Different implementation: udiskctl status assumes that SERIAL
    # is max. 20 characters long, but this does not hold for
    # some Microsoft devices. So do a mixed approach of fixed and
    # non-fixed matching
    #
    # Use in a one-liner:
    #
    #    perl -I. -MGPS::BBBikeGPS::MountedDevice -MData::Dumper -e 'warn Dumper GPS::BBBikeGPS::MountedDevice::_parse_udisksctl_status2()'
    #
    sub _parse_udisksctl_status2 {
	my(%opts) = @_;
	my $infostring = delete $opts{infostring}; # used for testing
	die "Unhandled options: " . join(" ", %opts) if %opts;

	my %disks;

	my $fh;
	if (defined $infostring) {
	    open $fh, '<', \$infostring or die $!;
	} else {
	    my @cmd = ('/usr/bin/udisksctl', 'status');
	    open $fh, '-|', @cmd
		or die "Error starting '@cmd': $!";
	}

	chomp(my $header = <$fh>);
	my(@f) = split /(\s+)/, $header, 3; # only split MODEL and REVISION and rest
	my @field_names = do { my $i; grep { $i++ % 2 == 0 } @f };
	$field_names[-1] = 'rest';
	my @lengths;
	for(my $i=0; $i<$#f; $i+=2) {
	    push @lengths, length($f[$i])+length($f[$i+1]);
	}
	my $unpack = join(" ", map { "a$_" } @lengths) . " a*";
	scalar <$fh>; # dashed line
	while(<$fh>) {
	    chomp;
	    next if /^-($|\s)/;
	    my %f;
	    @f{@field_names} = map { s/\s+$//; $_ } unpack $unpack, $_;
	    my $rest = delete $f{'rest'};
	    if ($rest =~ m{^(\S+)\s+(\S+)$}) {
		$f{'SERIAL'} = $1;
		$f{'DEVICE'} = $2;
	    } else {
		die "Cannot parse rest '$rest'";
	    }
	    $disks{$f{MODEL}} = \%f;
	}
	close $fh
	    or die "Error while closing filehandle (probably failure of running udisksctl command): $!";

	\%disks;
    }

    sub _parse_udisksctl_status3 {
	my(%opts) = @_;
	my $infostring = delete $opts{infostring}; # used for testing
	die "Unhandled options: " . join(" ", %opts) if %opts;

	my %disks;

	my $fh;
	if (defined $infostring) {
	    open $fh, '<', \$infostring or die $!;
	} else {
	    my @cmd = ('/usr/bin/udisksctl', 'status');
	    open $fh, '-|', @cmd
		or die "Error starting '@cmd': $!";
	}
	chomp(my $header = <$fh>);
	my @field_names = split /\s+/, $header;
	if ($field_names[0] ne 'MODEL') {
	    die "Unexpected header in 'udisksctl status' command: first field is not MODEL, but '$field_names[0].";
	}
	if (@field_names != 4) {
	    die "Unexpected header in 'udisksctl status' command: expected four fields, got " . scalar(@field_names) . ".";
	}
	scalar <$fh>; # dashed line
	while(<$fh>) {
	    chomp;
	    next if /^-($|\s)/;
	    s/\s+$//;
	    if (my @v = $_ =~ /^(.+?)\s+(\S+)\s+(\S+)\s+(\S+)$/) {
		my %f;
		@f{@field_names} = @v;
		$disks{$f{MODEL}} = \%f;
	    } else {
		die "Cannot parse line '$_'";
	    }
	}
	close $fh
	    or die "Error while closing filehandle (probably failure of running udisksctl command): $!";

	\%disks;
    }

    # Use in a one-liner:
    #
    #    perl -I. -MGPS::BBBikeGPS::MountedDevice -e 'warn GPS::BBBikeGPS::MountedDevice::_udisksctl_find_mountable(shift)' /dev/sdc
    #
    sub _udisksctl_find_mountable {
	my $dev_prefix = shift;
	require File::Glob;
	my @candidates = File::Glob::bsd_glob($dev_prefix.'*');
	for my $candidate (@candidates) {
	    if (open my $fh, '-|', '/usr/bin/udisksctl', 'info', '-b', $candidate) {
		while(<$fh>) {
		    if (/^\s*IdUsage:\s+filesystem/) {
			return $candidate;
		    }
		}
	    }
	}
	undef;
    }

    # Currrently not in use.
    sub _parse_udisksctl_dump {
	my(%opts) = @_;
	my $infostring = delete $opts{infostring}; # used for testing
	die "Unhandled options: " . join(" ", %opts) if %opts;

	my %disks;

	my $fh;
	if (defined $infostring) {
	    open $fh, '<', \$infostring or die $!;
	} else {
	    my @cmd = ('/usr/bin/udisksctl', 'dump');
	    open $fh, '-|', @cmd
		or die "Error starting '@cmd': $!";
	}
	my $current_info = {};
	my $flush_current_info = sub {
	    if ($current_info->{IdLabel}) {
		$disks{$current_info->{IdLabel}} = $current_info;
	    }
	    $current_info = {};
	};
	while(<$fh>) {
	    if (m{^\s{2}\S}) {
		$flush_current_info->();
	    } elsif (m{^\s{4}(\S+?):\s+(.*)}) {
		$current_info->{$1} = $2;
	    }
	}
	$flush_current_info->();
	close $fh
	    or die "Error while closing filehandle (probably failure of running udisksctl command): $!";

	\%disks;
    }

    ######################################################################
    # Linux (udevadm)
    sub _get_linux_disks {
	my @disks;
	my $proc_file = '/proc/partitions';
	if (open my $fh, $proc_file) {
	    scalar <$fh>; # overread header
	    while(<$fh>) {
		chomp;
		next if /^\s*$/;
		s/^\s+//;
		my(@f) = split /\s+/;
		if ($f[3] !~ /\d$/) { # skip partitions
		    push @disks, $f[3];
		}
	    }
	} else {
	    warn "Cannot open $proc_file: $!, cannot get linux disks.\n";
	}
	@disks;
    }

    sub _parse_udevadm_info {
	my($disk, %opts) = @_;
	my $compat = delete $opts{compat};
	die "Unhandled options: " . join(" ", %opts) if %opts;

	$disk = "/dev/$disk" if $disk !~ m{^/};
	if (!_is_in_path('udevadm')) {
	    die "Cannot parse disk info using udevadm, utility is not installed.\n";
	}
	my @cmd = ('udevadm', 'info', $disk);
	open my $fh, '-|', @cmd
	    or die "Error running '@cmd': $!";
	my $info;
	while(<$fh>) {
	    chomp;
	    if (/^E:\s+(.*?)=(.*)/) {
		my($key, $val) = ($1, $2);
		if ($key =~ /_ENC$/) {
		    $val =~ s/\\x([0-9a-fA-F]{2})/pack("H*", $1)/eg;
		}
		$info->{$key} = $val;
	    }
	}

	if ($compat) {
	    if ($compat eq 'udisksctl-status') {
		(my $model = $info->{ID_MODEL_ENC}) =~ s/\s*$//;
		my $vendor = $info->{ID_VENDOR};
		my $vendor_model = (defined $vendor ? "$vendor " : "") . $model;
		my $short_disk = do {
		    require File::Basename;
		    File::Basename::basename($disk);
		};
		$info =
		    {
		     $vendor_model =>
		     {
		      SERIAL   => $info->{ID_SERIAL_SHORT},
		      MODEL    => $vendor_model,
		      REVISION => $info->{ID_REVISION},
		      DEVICE   => $short_disk,
		     },
		    };
	    } else {
		die "Unhandled compat value '$compat'";
	    }
	}

	$info;
    }

    # Use in a one-liner:
    #
    #    perl -I. -MGPS::BBBikeGPS::MountedDevice -MData::Dumper -e 'warn Dumper GPS::BBBikeGPS::MountedDevice::_parse_udevadm_as_udisksctl_status()'
    #
    sub _parse_udevadm_as_udisksctl_status {
	my $info = {};
	for my $disk (_get_linux_disks()) {
	    my $add_info = _parse_udevadm_info($disk, compat => 'udisksctl-status');
	    while(my($k,$v) = each %$add_info) {
		$info->{$k} = $v;
	    }
	}
	$info;
    }

    # Use in a one-liner:
    #
    #    perl -I. -MGPS::BBBikeGPS::MountedDevice -e 'warn GPS::BBBikeGPS::MountedDevice::_udevadm_find_mountable(shift)' /dev/sdc
    #
    sub _udevadm_find_mountable {
	my $dev_prefix = shift;
	require File::Glob;
	my @candidates = File::Glob::bsd_glob($dev_prefix.'*');
	for my $candidate (@candidates) {
	    my $info = _parse_udevadm_info($candidate);
	    if ($info->{ID_FS_USAGE} eq 'filesystem') {
		return $candidate;
	    }
	}
	undef;
    }

    ######################################################################
    # Mac
    sub _diskutil_list {
	require BBBikePlist;
	open my $fh, '-|', qw(diskutil list -plist) or die $!;
	BBBikePlist->load_plist(IO => $fh);
    }

    sub _diskutil_info {
	my $disk = shift;
	require BBBikePlist;
	open my $fh, '-|', qw(diskutil info -plist), $disk or die $!;
	BBBikePlist->load_plist(IO => $fh);
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

    sub _is_in_path {
	my $prog = shift;
	require BBBikeUtil;
	BBBikeUtil::is_in_path($prog);
    }
}

1;

__END__

=head1 NAME

GPS::BBBikeGPS::MountedDevice - handle gps uploads via a mounted device

=head1 DESCRIPTION

Currently support is only available for newer Garmin devices (e.g.
etrex 30) and (on Linux and Mac OS X systems only) for Falk and IGS630
devices.

See also the convenience script L<gps-mount.pl> (in subdirectory
F<miscsrc>), which is a wrapper around this module.

=head2 Linux desktops

If the C<udisks2> package is installed, then detection and mounting of
the Garmin and Falk flash card is done automatically.

Otherwise it is assumed that the device is manually mounted in a
directory like F</media/GARMIN> or F</run/media/$USER/GARMIN> or
F</media/$USER/Falk>.

=head2 Windows

It is assumed that the device is already mounted. The mounted drive is
detected automatically by inspecting the drive's volume name.

=head2 Mac OS X

It is assumed that the device is mounted in the directory
F</Volumes/GARMIN> or F</Volumes/Falk> or F</Volumes/IGS630>.

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
to an external SD card. This may be changed by setting the
C<garmin_disk_type> option to C<card> (use this option even for Falk
devices).

=head2 FUNCTIONS

The following functions may be used outside BBBike's GPS transfer
system:

=over

=item C<maybe_mount(I<coderef>, I<key> =E<gt> I<val> ...>)>

C<maybe_mount()> may also be called outside of the Perl/Tk application
for scripts which have to make sure that the GPS device is mounted,
e.g. to copy from or to the mounted gps device. Simple usage example
for the internal flash (current directory should be the bbbike source
directory):

    perl -w -I. -Ilib -MGPS::BBBikeGPS::MountedDevice -e 'GPS::BBBikeGPS::MountedDevice->maybe_mount(sub { my $dir = shift; system("ls", "-al", $dir); 1 })'

Or for the first partition on a card:

    perl -w -I. -Ilib -MGPS::BBBikeGPS::MountedDevice -e 'GPS::BBBikeGPS::MountedDevice->maybe_mount(sub { my $dir = shift; system("ls", "-al", $dir); 1 }, garmin_disk_type => "card")'

Or starting a shell in the mounted directory:

    perl -w -I. -Ilib -MGPS::BBBikeGPS::MountedDevice -e 'GPS::BBBikeGPS::MountedDevice->maybe_mount(sub { my $dir = shift; chdir $dir; system($ENV{SHELL}); chdir "/"; 1 })'

The mount rule is: if the device is already mounted, then don't
unmount at the end. If the device is not mounted, then unmount after
the callback.

It's made sure that an unmount (if required) is done even if the
callback dies.

Options are given as key-value pairs. Following options are available:

=over

=item C<prefer_device> => I<devicename>

Set the preferred device. By default the following order is used:
C<GARMIN>, C<Falk>, C<IGS30>. Note that on some systems (i.e. linux)
correct case needs to be used.

=item C<garmin_disk_type> => C<flash> | C<card>

For some Garmin devices, specify whether the internal flash memory or
an external card is mounted.

=item C<with_tty> => I<boolean>

Defaults to true; set to a false value if you want to avoid user
interaction like password input, which may happen in linux' udisks2
setup.

=back

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

    perl -w -I. -Ilib -MGPS::BBBikeGPS::MountedDevice -e 'while () { $status = GPS::BBBikeGPS::MountedDevice->get_gps_device_status("flash", \$info); if ($status eq "unknown") { die "We cannot detect the gps device status: $info" } exit if $status eq "attached"; sleep 1 }'

=back

=head1 BUGS

Currently it's not possible to specify which device should be mounted
if multiple supported ones are available. Currently, the order is
Garmin, then Falk, then IGS630. Workaround: unplug the unwanted
device(s).

=head1 AUTHOR

Slaven Rezic

=head1 SEE ALSO

L<udisks(8)> (linux), L<lshal(1)> (freebsd), L<gps-mount.pl>.

=cut
