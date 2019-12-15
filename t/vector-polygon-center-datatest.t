#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use warnings;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use Time::HiRes qw(time);
use Test::More 'no_plan';

use Strassen::Core;
use VectorUtil qw(get_polygon_center bbox_of_polygon);

my @test_files = qw(flaechen wasserstrassen wasserumland wasserumland2 sehenswuerdigkeit); # files which usually have F:... records

my $count = 0;
my $sumtime = 0;
for my $test_file (@test_files) {
    my $path = "$FindBin::RealBin/../data/$test_file";
    my $s = Strassen->new_stream($path);
    $s->read_stream
	(sub {
	     my($r) = @_;
	     if ($r->[Strassen::CAT] =~ m{^F:}) {
		 my @coords = map { split /,/, $_ } @{ $r->[Strassen::COORDS] };
		 my $t0 = time;
		 my($cx,$cy) = get_polygon_center(@coords);
		 $sumtime += (time - $t0); $count++;
		 my $common_testname = "for $test_file, $r->[Strassen::NAME]";
		 ok $cx, "x center $common_testname ok";
		 ok $cy, "y center $common_testname ok";
		 my $bbox = get_bbox(\@coords);
		 within_bbox($cx,$cy,$bbox,"bbox check $common_testname ok");
	     }
	 });
}

diag sprintf "Average speed of get_polygon_center() call: %.2fms", 1000*($sumtime/$count);

sub get_bbox {
    my($coords_ref) = @_;
    my @coords2;
    for(my $i=0; $i<$#$coords_ref; $i+=2) {
	push @coords2, [@{$coords_ref}[$i,$i+1]];
    }
    bbox_of_polygon(\@coords2);
}

sub within_bbox {
    my($x,$y,$bbox,$testname) = @_;
    $testname = defined $testname ? "$testname: " : "";
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    cmp_ok $x, ">=", $bbox->[0], "${testname}left bbox check";
    cmp_ok $x, "<=", $bbox->[2], "${testname}right bbox check";
    cmp_ok $y, ">=", $bbox->[1], "${testname}upper bbox check";
    cmp_ok $y, "<=", $bbox->[3], "${testname}lower bbox check";
    
}

__END__
