#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib "$FindBin::RealBin/..";

use Getopt::Long;
use Test::More 'no_plan';

use GPS::BBBikeGPS::MountedDevice;

GetOptions("debug" => \my $debug)
    or die "usage: $0 [--debug]\n";

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
    skip "no udisksctl available", 1
	if !-x "/usr/bin/udisksctl";
    my $disks = GPS::BBBikeGPS::MountedDevice::_parse_udisksctl_status2();
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

{
    my $disks = GPS::BBBikeGPS::MountedDevice::_parse_udisksctl_status2(infostring => _sample_udiskctl_status_output());
    is_deeply $disks->{"Garmin GARMIN Card"},
	{
	 "DEVICE" => "-",
	 "MODEL" => "Garmin GARMIN Card",
	 "REVISION" => "1.00",
	 "SERIAL" => "0000e709ffff"
	};
    is_deeply $disks->{"Garmin GARMIN Flash"},
	{
	 "DEVICE" => "-",
	 "MODEL" => "Garmin GARMIN Flash",
	 "REVISION" => "1.00",
	 "SERIAL" => "0000e709ffff"
	};
    is_deeply $disks->{"Microsoft SDMMC"},
	{
	 "DEVICE" => "sdd",
	 "MODEL" => "Microsoft SDMMC",
	 "REVISION" => "0000",
	 "SERIAL" => "1000000000386CF84D4FFFFFFFFFFFFF"
	};
    is_deeply $disks->{"TOSHIBA DT01ACA200"},
	{
	 "DEVICE" => "sda",
	 "MODEL" => "TOSHIBA DT01ACA200",
	 "REVISION" => "MX4OABB0",
	 "SERIAL" => "95LZ9RXXX"
	};
}

SKIP: {
    skip "no udisksctl available", 1
	if !-x "/usr/bin/udisksctl";
    my $disks = GPS::BBBikeGPS::MountedDevice::_parse_udisksctl_dump();
    is ref $disks, ref {}, 'it has to be a hash, but it may be empty --- not everything has a label';
    if (keys %$disks) {
	my $first_disk = (keys(%$disks))[0];
	my $first_disk_info = $disks->{$first_disk};
	is $first_disk_info->{IdLabel}, $first_disk;
	ok $first_disk_info->{Device}, 'Device should be defined';
	if ($debug) {
	    require Data::Dumper;
	    diag(Data::Dumper->new([$disks],[qw()])->Indent(1)->Useqq(1)->Sortkeys(1)->Terse(1)->Dump);
	}
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

sub _sample_udiskctl_status_output {
    # serials scrambled
    <<'EOF';
MODEL                     REVISION  SERIAL               DEVICE
--------------------------------------------------------------------------
TOSHIBA DT01ACA200        MX4OABB0  95LZ9RXXX            sda     
WDC WD20EZRZ-00Z5HB0      80.00A80  WD-WCC4M2EXX9XX      sdb     
Garmin GARMIN Flash       1.00      0000e709ffff         -       
Garmin GARMIN Card        1.00      0000e709ffff         -       
-                                                        -       
Hama Card Reader   CF     1.9C      ABCD1234XXXX         sde     
Hama Card Reader   MS     1.9C      ABCD1234XXXX         sdf     
Hama Card Reader   SM     1.9C      ABCD1234XXXX         sdh     
Hama CardReaderMMC/SD     1.9C      ABCD1234XXXX         sdg     
Microsoft Flash ROM       0000      1000000000386CF84D4FFFFFFFFFFFFF sdc     
Microsoft SDMMC           0000      1000000000386CF84D4FFFFFFFFFFFFF sdd     
EOF
}
__END__
