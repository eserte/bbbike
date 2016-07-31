package Gonzo;

use strict;
use warnings;

sub random_point {

	my $xmin = -10000;
	my $xmax =  30000;
	my $ymin =  0;
	my $ymax =  26000;

	#print "$xmin $xmax $ymin $ymax\n";

	my $x = int(rand($xmax - $xmin)) + $xmin;
	my $y = int(rand($ymax - $ymin)) + $ymin;

	my $point = $x . "," . $y;
	#print "$point\n";

	return $point;
}

sub random_points {
	for (0..0) {
		my $point = random_point();
		print "$point\n";
	}
}

1;

