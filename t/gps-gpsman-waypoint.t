#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 $FindBin::RealBin,
	);

use Test::More 'no_plan';

use GPS::GpsmanData;

{
    my $wpt = GPS::Gpsman::Waypoint->new;
    $wpt->unixtime_to_Comment(1_000_000_000);
    is $wpt->Comment, '09-Sep-2001 01:46:40';

    {
	my @warnings;
	local $SIG{__WARN__} = sub { push @warnings, @_ };
	is $wpt->Comment_to_unixtime, 1_000_000_000;
	like "@warnings", qr{Please specify container object in Comment_to_unixtime for correct timezone information};
    }

    {
	my @warnings;
	local $SIG{__WARN__} = sub { push @warnings, @_ };
	is $wpt->Comment_to_unixtime, 1_000_000_000;
	is "@warnings", '', 'no another warning';
    }

    $wpt->unixtime_to_DateTime(1_000_000_000);
    is $wpt->DateTime, '09-Sep-2001 01:46:40';
}

{
    my $container = GPS::GpsmanData->new;
    $container->TimeOffset(2);

    my $wpt = GPS::Gpsman::Waypoint->new;
    $wpt->unixtime_to_Comment(1_000_000_000, $container);
    is $wpt->Comment, '09-Sep-2001 03:46:40';
    $wpt->unixtime_to_DateTime(1_000_000_000, $container);
    is $wpt->DateTime, '09-Sep-2001 03:46:40';
}

{
    my $container = GPS::GpsmanData->new;
    $container->TimeOffset(-8);

    my $wpt = GPS::Gpsman::Waypoint->new;
    $wpt->unixtime_to_Comment(1_000_000_000, $container);
    is $wpt->Comment, '08-Sep-2001 17:46:40';
    $wpt->unixtime_to_DateTime(1_000_000_000, $container);
    is $wpt->DateTime, '08-Sep-2001 17:46:40';
}

{
    my $wpt = GPS::Gpsman::Waypoint->new;
    $wpt->unixtime_to_Comment(1_000_000_000, 2);
    is $wpt->Comment, '09-Sep-2001 03:46:40';
    $wpt->unixtime_to_DateTime(1_000_000_000, 2);
    is $wpt->DateTime, '09-Sep-2001 03:46:40';
}

{
    my $wpt = GPS::Gpsman::Waypoint->new;
    eval { $wpt->unixtime_to_Comment(1_000_000_000, "foobar") };
    like $@, qr{Invalid container.*foobar};
}

__END__
