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
    { my $err; skip $err, 1 if !udisksctl_usable(\$err) }
    for my $def (
		 ['_parse_udisksctl_status',  'parsing may fail on long serials'],
		 ['_parse_udisksctl_status2', 'parsing may fail on long model names'],
		 ['_parse_udisksctl_status3', undef],
		) {
	my($parser_func, $todo) = @$def;
	local $TODO = $todo;
	my $disks = eval 'GPS::BBBikeGPS::MountedDevice::'.$parser_func.'()';
	is $@, '', "no error calling $parser_func";
	cmp_ok keys(%$disks), ">", 0, "disks detected by udisksctl and $parser_func";
	my $first_disk = (keys(%$disks))[0];
	if (defined $first_disk) {
	    my $first_disk_info = $disks->{$first_disk};
	    is $first_disk_info->{MODEL}, $first_disk, "Model of first found disk '$first_disk' (using $parser_func)";
	    ok $first_disk_info->{DEVICE}, "DEVICE should be defined (using $parser_func)";
	    # SERIAL may be missing, seen with 'QEMU QEMU HARDDISK'
	}

	my @mountables;
	while(my($disk, $disk_info) = each %$disks) {
	    my $mountable = GPS::BBBikeGPS::MountedDevice::_udisksctl_find_mountable('/dev/' . $disk_info->{DEVICE});
	    push @mountables, "$mountable (from $disk)" if defined $mountable;
	}
	if (@mountables) {
	    diag "Found mountables with $parser_func:" . join "", map { "\n\t$_" } @mountables;
	} else {
	    diag "Possible problem: no mountables found with $parser_func; returned disks structure is: " . explain($disks);
	}
    }
}

for my $parser_func (
		     '_parse_udisksctl_status',
		     '_parse_udisksctl_status2',
		     '_parse_udisksctl_status3',
		    ) {

    my $func = do {
	no strict 'refs';
	\&{"GPS::BBBikeGPS::MountedDevice::" . $parser_func};
    };

    {
	my $disks = $func->(infostring => _sample_udiskctl_status_output());
	is_deeply $disks->{"Garmin GARMIN Card"},
	    {
	     "DEVICE" => "-",
	     "MODEL" => "Garmin GARMIN Card",
	     "REVISION" => "1.00",
	     "SERIAL" => "0000e709ffff"
	    }, "parsing sample udisksctl status output with $parser_func -> Garmin Card";
	is_deeply $disks->{"Garmin GARMIN Flash"},
	    {
	     "DEVICE" => "-",
	     "MODEL" => "Garmin GARMIN Flash",
	     "REVISION" => "1.00",
	     "SERIAL" => "0000e709ffff"
	    }, "parsing sample udisksctl status output with $parser_func -> Garmin Flash";
	{
	    local $TODO;
	    $TODO = 'parser cannot handle overflow serials' if $parser_func eq '_parse_udisksctl_status';
	    is_deeply $disks->{"Microsoft SDMMC"},
		{
		 "DEVICE" => "sdd",
		 "MODEL" => "Microsoft SDMMC",
		 "REVISION" => "0000",
		 "SERIAL" => "1000000000386CF84D4FFFFFFFFFFFFF"
		}, "parsing sample udisksctl status output with $parser_func -> Microsoft SDMMC";
	}
	is_deeply $disks->{"TOSHIBA DT01ACA200"},
	    {
	     "DEVICE" => "sda",
	     "MODEL" => "TOSHIBA DT01ACA200",
	     "REVISION" => "MX4OABB0",
	     "SERIAL" => "95LZ9RXXX"
	    }, "parsing sample udisksctl status output with $parser_func -> Toshiba ...";
    }

    {
	local $TODO; # TODO is deliberately "cumulative" here
	my $disks = eval { $func->(infostring => _sample_udiskctl_status_output_with_overflow()) };
	$TODO = 'parser is known to fail' if $parser_func eq '_parse_udisksctl_status2';
	is $@, '', "no error parsing with $parser_func";
	$TODO = 'parser cannot handle overflow model names' if $parser_func eq '_parse_udisksctl_status' || $parser_func eq '_parse_udisksctl_status2';
	is_deeply $disks->{"SAMSUNG MZVLB512HBJQ-000L7"},
	    {
	     "DEVICE" => "nvme0n1",
	     "MODEL" => "SAMSUNG MZVLB512HBJQ-000L7",
	     "REVISION" => "5M2QEXF7",
	     "SERIAL" => "S4ENNX0RXXXXXX"
	    }, "parsing sample udisksctl status output with $parser_func -> device with overflow model name";
	$TODO = undef if $parser_func eq '_parse_udisksctl_status';
	is_deeply $disks->{"TOSHIBA DT01ACA200"},
	    {
	     "DEVICE" => "sda",
	     "MODEL" => "TOSHIBA DT01ACA200",
	     "REVISION" => "MX4OABB0",
	     "SERIAL" => "95LZ9RXXX"
	    }, "parsing sample udisksctl status output with $parser_func -> Toshiba ...";
    }

    {
	my $disks = $func->(infostring => _sample_udiskctl_status_output_vm());
	is_deeply $disks->{"QEMU QEMU HARDDISK"},
	    {
	     "DEVICE" => "sda",
	     "MODEL" => "QEMU QEMU HARDDISK",
	     "REVISION" => "2.5+",
	     "SERIAL" => "12345678"
	    }, "parsing sample udisksctl status output with $parser_func -> qemu harddisk";
	is_deeply $disks->{"QEMU DVD-ROM"},
	    {
	     "DEVICE" => "sr0",
	     "MODEL" => "QEMU DVD-ROM",
	     "REVISION" => "2.5+",
	     "SERIAL" => "QEMU_DVD-ROM_QM00001"
	    }, "parsing sample udisksctl status output with $parser_func -> qemu dvd-rom";
    }
}

SKIP: {
    { my $err; skip $err, 1 if !udisksctl_usable(\$err) }
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

{
    my $udisksctl_usable;

    sub udisksctl_usable {
	my($errref) = @_;
	if (defined $udisksctl_usable) {
	    if (!$udisksctl_usable) {
		$$errref = 'udisksctl unusable (cached information)' if $errref;
	    }
	    return $udisksctl_usable;
	}

    CHECKS: {
	    my $udisksctl_path = '/usr/bin/udisksctl';

	    if (!-x $udisksctl_path) {
		$$errref = "no $udisksctl_path available" if $errref;
		$udisksctl_usable = 0;
		last CHECKS;
	    }

	    my $udisksctl_output;
	    open my $fh, '-|', $udisksctl_path, 'status';
	    {
		local $/;
		$udisksctl_output = <$fh>;
	    }
	    close $fh;
	    if ($? != 0) {
		my $exitcode = $? >> 8;
		$$errref = "cannot run 'udisksctl status' successfully (exit code $exitcode)" if $errref;
		$udisksctl_usable = 0;
		last CHECKS;
	    }

	    my(@udisksctl_lines) = split /\n/, $udisksctl_output;
	    if (@udisksctl_lines == 2 && $udisksctl_lines[0] =~ /^MODEL/ && $udisksctl_lines[1] =~ /^-+/) {
		$$errref = "'udisksctl status' works, but no devices are returned" if $errref;
		$udisksctl_usable = 0;
		last CHECKS;
	    }

	    $udisksctl_usable = 1;
	}

	$udisksctl_usable;
    }
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

sub _sample_udiskctl_status_output_with_overflow {
    # Unfortunately there's no guarantee that the model name
    # aligns with the header. See also
    # https://github.com/storaged-project/udisks/blob/a76eda89a4c747f12dc05670f376d95d8ec4cd45/tools/udisksctl.c#L3157
    #
    # serials scrambled
    <<'EOF';
MODEL                     REVISION  SERIAL               DEVICE
--------------------------------------------------------------------------
SAMSUNG MZVLB512HBJQ-000L7 5M2QEXF7  S4ENNX0RXXXXXX       nvme0n1 
TOSHIBA DT01ACA200        MX4OABB0  95LZ9RXXX            sda     
EOF
}

sub _sample_udiskctl_status_output_vm {
    <<'EOF';
MODEL                     REVISION  SERIAL               DEVICE
--------------------------------------------------------------------------
QEMU QEMU HARDDISK        2.5+      12345678             sda     
QEMU DVD-ROM              2.5+      QEMU_DVD-ROM_QM00001 sr0     
EOF
}
__END__
