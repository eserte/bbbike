# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2013 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package GPS::GpsmanData::VehicleInfo;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

my %vehicle_to_color = (
			# get all vehicles with:
			# cd .../misc/gps_data
			# perl -nle 'm{srt:vehicle=(\S+)} and print $1' *.trk | sort | uniq -c
			'bike'   => 'darkblue',
			'boat'   => 'lightblue',
			'bus'    => 'violet',
			'car'    => 'darkgrey',
			'ferry'  => 'lightblue',
			'funicular' => 'red',
			'kayak'  => 'lightblue',
			'pedes'  => 'orange',
			'plane'  => 'black',
			's-bahn' => 'green',
			'ship'   => 'lightblue',
			'sleigh' => 'white',
			'train'  => 'darkgreen',
			'tram'   => 'red',
			'u-bahn' => 'blue',
		       );

sub get_vehicle_color { 
    my $vehicle = shift;
    my $color = $vehicle_to_color{$vehicle};
    $color;
}

sub all_vehicles {
    sort keys %vehicle_to_color;
}

1;

__END__
