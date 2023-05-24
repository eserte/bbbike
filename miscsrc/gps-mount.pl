#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2018,2019,2021,2023 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use warnings;
use FindBin;
use Cwd qw(realpath getcwd cwd);

my $bbbike_root; BEGIN { $bbbike_root = realpath "$FindBin::RealBin/.." }

use lib $bbbike_root, "$bbbike_root/lib";

# convenience for --perl code
use autouse 'File::Copy' => qw(cp mv);
use if $] >= 5.010, feature => 'say';

use Getopt::Long;

use GPS::BBBikeGPS::MountedDevice;

my $perl_code;
my $shell_code;
my $garmin_disk_type;
my $device;
my $cd;
my $do_gpx_copy;
my $debug;
my $without_tty;

sub usage ($) {
    my $exit_status = shift;
    require Pod::Usage;
    Pod::Usage::pod2usage($exit_status);
}

GetOptions
    (
     'perl=s'             => \$perl_code,
     'shell=s'            => \$shell_code,
     'garmin-disk-type=s' => \$garmin_disk_type,
     'device|prefer-device=s' => \$device,
     'cd:s'               => \$cd,
     'gpxcp|gpx-cp|gpx-copy' => \$do_gpx_copy,
     'debug'              => \$debug,
     'without-tty'        => \$without_tty,
     'help|?'             => sub { usage(1) },
    )
    or usage(2);

my @files;
if ($do_gpx_copy) {
    @files = @ARGV;
    if (!@files) {
	die "Please specify gpx files to copy!\n";
    }
    if (my @unreadable_files = grep { !-r $_ } @files) {
	die "The following files are unreadable: @unreadable_files\n";
    }
} else {
    @ARGV and usage(2);
}

my $sub;
if ($do_gpx_copy) {
    if (defined $perl_code || defined $shell_code) {
	die "Cannot specify --gpx-cp together with --perl or -shell.\n";
    }
    $sub = sub {
	my $gps = shift;
	my $dest = "$gps/Garmin/GPX";
	if (!-d $dest) {
	    die "Target directory $dest does not exist, cannot proceed.\n";
	}
	if ($^O eq 'MSWin32') {
	    for my $file (@files) {
		cp($file, $dest)
		    or die "Failed top copy '$file' to '$dest': $!";
	    }
	} else {
	    my @cmd = ('cp', '-i', @files, $dest);
	    system @cmd;
	    if ($? != 0) {
		die "Running '@cmd' failed";
	    }
	}
    };
} else {
    if (defined $perl_code && defined $shell_code) {
	die "Cannot specify --perl and --shell together.\n";
    }

    if (!defined $perl_code && !defined $shell_code) {
	if (!$ENV{SHELL}) {
	    die "SHELL environment variable not defined --- don't known which shell to start.\n";
	}
	$shell_code = q<echo '*** GPS device is mounted (see variable $GPS) --- to unmount just exit this shell'; > . $ENV{SHELL};
    }

    if (defined $shell_code) {
	$perl_code = 'sub { my $gps = shift; local $ENV{GPS} = $gps; local $ENV{MOUNTKEEPER_DIR} = $gps; if (defined $cd) { chdir "$gps/$cd" or die "Can\'t chdir to $gps/$cd: $!\n" } system $shell_code; chdir "/"; 1 }';
    } else {
	$perl_code = 'sub { my $gps = shift; if (defined $cd) { chdir "$gps/$cd" or die "Can\'t chdir to $gps/$cd: $!\n" } eval { ' . $perl_code . '}; my $err = $@; chdir "/"; die $err if $err; 1 }';
    }

    $sub = eval $perl_code;
    if (!$sub) {
	die "Cannot evaluate '$perl_code': $@";
    }

    if ($debug) {
	warn "DEBUG: perl code to execute: '$perl_code'\n";
    }
}

GPS::BBBikeGPS::MountedDevice->maybe_mount($sub,
					   ($garmin_disk_type ? (garmin_disk_type => $garmin_disk_type) : ()),
					   ($without_tty      ? (with_tty         => 0)                 : ()),
					   ($device           ? (prefer_device    => $device)           : ()),
					  );

__END__

=head1 NAME

gps-mount.pl - mount GPS device

=head1 SYNOPSIS

    gps-mount.pl [--perl 'perl code' | --shell 'shell code'] [--device GARMIN|Falk|IGS630|...] [--garmin-disk-type flash|card] [--cd | --cd reldir] [--gpx-cp | --gpx-copy file1 ...] [--debug]

=head1 DESCRIPTION

Mount a GPS device and execute perl or shell code with the mount being
active, or just start the user's C<$SHELL> (if neither C<--perl> nor
C<--shell> are specified).

If the GPS device is already mounted, then don't do any mounts or
unmounts, but still provide the information about the mount directory.

=head2 OPTIONS

=over

=item C<--perl> I<perl code fragment>

Execute some perl code with the GPS device being mounted. The variable
C<$gps> is set to the path of the GPS device (but see below for the
L</--cd> option.

For additional convenience, some additional perl functions are
available without the need to be imported: L<File::Copy/cp>,
L<File::Copy/mv>, L<Cwd/getcwd>, L<Cwd/cwd>, and L<say>.

Examples:

    gps-mount.pl --cd --perl 'say cwd';
    gps-mount.pl --cd --perl 'say join "\n", <*>'

=item C<--shell> I<shell code fragment>

Execute some shell code with the GPS device being mounted. The
environment variable C<$GPS> is set to the path of the GPS device (but
see below for the L</--cd> option.

Example:

   gps-mount.pl --cd --shell 'echo $GPS'

Copy a C<.gpx> file to the GPX directory on a Garmin device (but see
also L</--gpx-cp> for an easier option for this task):

   gps-mount.pl --shell 'cp -v file.gpx $GPS/Garmin/GPX/'

=item C<--cd>

Change current directory to the GPS device directory before executing
perl or shell code.

=item C<--cd I<reldir>>

Change current directory to the GPS device directory and then
additionally to the specified I<reldir> before executing perl or shell
code.

=item C<--gpx-cp I<file1> ...>

Copy one or more GPX files to the standard location (currently only
Garmin supported). Example:

   gps-mount.pl --gpx-cp file.gpx

Aliases: C<--gpx-copy> and C<--gpxcp>.

=item C<--device> I<devicename>

Set the preferred device. May be relevant if multiple devices are
plugged in at the same time.

=item C<--garmin-disk-type flash|card>

Specify what to mount for Garmin devices: either the internal flash
memory (C<flash>, the default), or the external SD card (C<card>).

=item C<--debug>

Additional debugging.

=back

=head2 ENVIRONMENT

=over

=item C<GPS>

Path of the GPS device (set only when using the C<--shell> option or
the default shell is started).

=item C<MOUNTKEEPER_DIR>

Just set when using the C<--shell> option or the default shell is
started. Use case is to define a shell prompt that checks for presence
of this environment variable, and displays a different prompt. An
example for F<.zshrc>:

    if [[ "$MOUNTKEEPER_DIR" != "" ]] ; then
       PROMPT='%B%T %n@%m (MOUNTED)%(!.#.:)%f %b'
    else
       PROMPT='%B%T %n@%m%(!.#.:)%f %b'
    fi

=back

=head1 SEE ALSO

L<GPS::BBBikeGPS::MountedDevice>.

=head1 AUTHOR

Slaven Rezic

=cut
