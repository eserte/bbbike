#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib "$FindBin::RealBin/..";

use Test::More 'no_plan';

use GPS::BBBikeGPS::MountedDevice;

SKIP: {
    skip "no udisksctl available", 1
	if !-x "/usr/bin/udisksctl";
    my $disks = GPS::BBBikeGPS::MountedDevice::_parse_udisksctl_status();
    cmp_ok keys(%$disks), ">", 0, 'disks detected by udisksctl';
    my $first_disk = (keys(%$disks))[0];
    my $first_disk_info = $disks->{$first_disk};
    is $first_disk_info->{MODEL}, $first_disk;
    ok $first_disk_info->{DEVICE}, 'DEVICE should be defined';
    # SERIAL may be missing, seen with 'QEMU QEMU HARDDISK'

    my @mountables;
    while(my($disk, $disk_info) = each %$disks) {
	my $mountable = GPS::BBBikeGPS::MountedDevice::_udisksctl_find_mountable('/dev/' . $disk_info->{DEVICE});
	push @mountables, "$mountable (from $disk)" if defined $mountable;
    }
    if (@mountables) {
	diag "Found mountables:" . join "", map { "\n\t$_" } @mountables;
    }
}

SKIP: {
    skip "works only on freebsd", 1
	if $^O ne 'freebsd';

    my $status = GPS::BBBikeGPS::MountedDevice->get_gps_device_status('flash', \my $info);
    like $status, qr{^(unattached|unknown|attached)$}, "status is $status";
    if ($status eq 'unattached') {
	like $info, qr{^disk not found};
    } else {
	diag "additional info: $info";
    }
}

SKIP: {
    skip "works only on darwin", 1
	if $^O ne 'darwin';

    my $diskutil_list = GPS::BBBikeGPS::MountedDevice::_diskutil_list();
    is ref $diskutil_list->{AllDisksAndPartitions}, 'ARRAY', 'output of diskutil list';

    my $first_disk = $diskutil_list->{WholeDisks}->[0];
    my $diskutil_info = GPS::BBBikeGPS::MountedDevice::_diskutil_info($first_disk);
    is ref $diskutil_info, 'HASH', 'output of diskutil info';
    is $diskutil_info->{DeviceIdentifier}, $first_disk;
}

__END__
