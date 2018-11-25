#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2018 Slaven Rezic. All rights reserved.
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
use autouse 'File::Copy' => qw(cp);
use autouse 'File::Glob' => qw(bsd_glob);
use if $] >= 5.010, feature => 'say';

use Getopt::Long;

use GPS::BBBikeGPS::MountedDevice;

my $perl_code;
my $shell_code;
my $garmin_disk_type;
my $cd;
my $debug;

GetOptions
    (
     'perl=s'             => \$perl_code,
     'shell=s'            => \$shell_code,
     'garmin-disk-type=s' => \$garmin_disk_type,
     'cd'                 => \$cd,
     'debug'              => \$debug,
    )
    or die "usage?\n";

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
    $perl_code = 'sub { my $gps = shift; local $ENV{GPS} = $gps; local $ENV{MOUNTKEEPER_DIR} = $gps; if ($cd) { chdir $gps or die $! } system $shell_code; chdir "/"; 1 }';
} else {
    $perl_code = 'sub { my $gps = shift; if ($cd) { chdir $gps or die $! } eval { ' . $perl_code . '}; my $err = $@; chdir "/"; die $err if $err; 1 }';
}

my $sub = eval $perl_code;
if (!$sub) {
    die "Cannot evaluate '$perl_code': $@";
}

if ($debug) {
    warn "DEBUG: perl code to execute: '$perl_code'\n";
}

GPS::BBBikeGPS::MountedDevice->maybe_mount($sub, ($garmin_disk_type ? (garmin_disk_type => $garmin_disk_type) : ()));

__END__

=head1 NAME

gps-mount.pl - mount GPS device

=head1 SYNOPSIS

    gps-mount.pl [--perl 'perl code' | --shell 'shell code'] [--garmin-disk-type flash|card] [--cd] [--debug]

=head1 DESCRIPTION

Mount a GPS device and execute perl or shell code with the mount being
active, or just start the user's C<$SHELL> (if neither C<--perl> nor
C<--shell> are specified).

If the GPS device is already mounted, then don't do any mounts or
unmounts, but still provide the information about the mount directory.

=head2 OPTIONS

=over

=item C<--perl I<perl code fragment>>

Execute some perl code with the GPS device being mounted. The variable
C<$gps> is set to the path of the GPS device (but see below for the
L</--cd> option.

For additional convenience, some additional perl functions are
available without the need to be imported: L<File::Copy/cp>,
L<File::Glob/bsd_glob>, L<Cwd/getcwd>, L<Cwd/cwd>, and L<say>.

Example:

    gps-mount.pl --cd --perl 'say cwd';

=item C<--shell I<shell code fragment>>

Execute some shell code with the GPS device being mounted. The
environment variable C<$GPS> is set to the path of the GPS device (but
see below for the L</--cd> option.

Example:

   gps-mount.pl --cd --shell 'echo $GPS'

=item C<--cd>

Change current directory to the GPS device directory before executing
perl or shell code.

=item C<--garmin-disk-type flash|card>

Specify what to mount for Garmin devices: either the internal flash
memory (C<flash>, the default), or the external SD card (C<card>).

=item C<--debug>

Additional debugging.

=back

=head2 TODO

* Document MOUNTKEEPER_DIR environment variable, or find another
  solution for this problem (show user that the current shell has
  something mounted)?

=head1 SEE ALSO

L<GPS::BBBikeGPS::MountedDevice>.

=head1 AUTHOR

Slaven Rezic

=cut
