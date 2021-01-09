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

use GPS::BBBikeGPS::MTP;

GetOptions("with-device" => \my $with_device)
    or die "usage: $0 [--with_device]\n";

{
    my $mtp_folder_sample = <<'EOF';
Attempting to connect device(s)
mtp-folders: Successfully connected
Friendly name: fenix 5 Plus
Storage: Primary
MTP extended association type 0x00000001 encountered
MTP extended association type 0x00000001 encountered (more of these)
16777216        GARMIN
16777222          RemoteSW
16777226          Apps
16777286            TEMP
16777287            LOGS
16777288            DATA
16777526              AUXFILE
16777533                ABCD1234
16777534                ABDC4321
16777289            SETTINGS
16777290            MAIL
16777228          HMD
16777264          NewFiles
16777247          Activity
16777248          Workouts
OK.
EOF
    {
	open my $fh, '<', \$mtp_folder_sample or die $!;
	is GPS::BBBikeGPS::MTP::_mtp_get_folder_id_parse("garmin/newfiles", $fh), 16777264, 'got folder id (lower case given)';
    }

    {
	open my $fh, '<', \$mtp_folder_sample or die $!;
	is GPS::BBBikeGPS::MTP::_mtp_get_folder_id_parse("GARMIN/NewFiles", $fh), 16777264, 'got folder id (upper case given)';
    }

    {
	open my $fh, '<', \$mtp_folder_sample or die $!;
	is GPS::BBBikeGPS::MTP::_mtp_get_folder_id_parse("GARMIN", $fh), 16777216, 'got root dir';
    }

    {
	open my $fh, '<', \$mtp_folder_sample or die $!;
	is GPS::BBBikeGPS::MTP::_mtp_get_folder_id_parse("garmin/apps/data/auxfile/abdc4321", $fh), 16777534, 'a deep one';
    }

    {
	open my $fh, '<', \$mtp_folder_sample or die $!;
	ok(!eval { GPS::BBBikeGPS::MTP::_mtp_get_folder_id_parse("File/Not/Found", $fh) }, 'file not found');
	like $@, qr{Cannot find folder 'file/not/found'}i, 'expected exception message';
    }

    {
	open my $fh, '<', \$mtp_folder_sample or die $!;
	ok(!eval { GPS::BBBikeGPS::MTP::_mtp_get_folder_id_parse("garmin/apps/data/auxfile/abdc4321XXX", $fh) }, 'another file not found');
	like $@, qr{Cannot find folder 'garmin/apps/data/auxfile/abdc4321XXX'}i, 'expected exception message';
    }
}

SKIP: {
    skip "device checks skipped, use --with-device", 1
	if !$with_device;

    is GPS::BBBikeGPS::MTP::_mtp_get_folder_id("garmin/newfiles"), 16777264, 'got folder id one real device';

    {
	ok(!eval { GPS::BBBikeGPS::MTP::_mtp_get_folder_id("File/Not/Found") }, 'file not found on real device');
	like $@, qr{Cannot find folder 'file/not/found'}i, 'expected exception message';
    }
}
