#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

my @dists = qw(100 200 400 600 1000 2000 3000 5000
	       10000 15000 20000 40000 60000 120000
	       250000);
my @dists_region = grep { $_ <= 40000 } @dists;
my @dists_max = (undef);
my @custom_dists;

use Getopt::Long;
my $doit = !!$ENV{BBBIKE_LONG_TESTS};
my %skip;
my $custom_center;
GetOptions("doit" => \$doit,
	   'skip=s' => sub { %skip = map {($_,1)} split /,/, $_[1] },
	   'dists=s' => sub { my @val = split /,/, $_[1];
			      @custom_dists = @val;
			  },
	   'center=s' => \$custom_center,
	  ) or die $!;

my $tests = (@custom_dists  ? @custom_dists :
	     $custom_center ? @dists :
	     @dists + @dists_region + @dists_max);

if (!$doit) {
    plan skip_all => "Neither -doit cmdline option specified nor is the env var BBBIKE_LONG_TESTS set";
    exit 0;
}

if ($ENV{BBBIKE_TEST_SKIP_MAPSERVER}) {
    plan skip_all => "Mapserver tests explicitly skipped";
    exit 0;
}

my $bbbikedraw = "$FindBin::RealBin/../miscsrc/bbbikedraw.pl";
if (!-e $bbbikedraw) {
    plan skip_all => "The executable $bbbikedraw is not available";
    exit 0;
}
plan tests => $tests;

{
    my $center = "9331,9668"; # Kreuzberg 61
    my $center_region = "53519,102604"; # Uckermark
    my $width = 550;
    my $dpi = 72;
    my $cm_per_in = 2.54;

    my $width_in_m = $width/$dpi*$cm_per_in*0.01;

    my $a_scope_loop = sub {
	my($centerx,$centery,$dist_ref,$scopelabel) = @_;

	for my $dist (@$dist_ref) {
	    my(@bbox, $scale_text, $file_scale_label);
	    if (defined $dist) {
		@bbox = ($centerx-$dist/2, $centery-$dist/2,
			 $centerx+$dist/2, $centery+$dist/2);
		my $scale = int($dist/$width_in_m);
		$file_scale_label = sprintf "%08d", $scale;
		$scale_text = "1:$scale";
	    } else {
		$file_scale_label = 'unspecified';
		$scale_text = 'unspecified';
	    }
	    my $o_file = sprintf "/tmp/bbbikedraw-mapserver-%s-%s.png", $scopelabel, $file_scale_label;
	    my @cmd = ($^X,
		       $bbbikedraw,
		       "-mapserver",
		       "-outline",
		       "-drawtypes", "ampel,berlin,wasser,faehren,flaechen,ubahn,sbahn,rbahn,str,ort,strname,ubahnname,sbahnname,blocked,radwege",
		       "-geometry" => $width."x".$width,
		       (@bbox ? ("-bbox", join(",",@bbox)) : ()),
		       "-o", $o_file,
		       "-q",
		      );
	    system(@cmd) == 0 or die "Died with status code=$? while executing: @cmd";
	    pass("scale $scale_text -> $o_file");
	}
    };

    if (@custom_dists) {
	$a_scope_loop->(split(/,/, $custom_center || $center), \@custom_dists, "custom")
    } elsif (defined $custom_center) {
	$a_scope_loop->(split(/,/, $custom_center), \@dists, $custom_center)
    } else {
	$a_scope_loop->(split(/,/, $center_region), \@dists_region, "region")
	    unless $skip{"region"};
	$a_scope_loop->(split(/,/, $center), \@dists, "city")
	    unless $skip{"city"};
	$a_scope_loop->(split(/,/, $center), \@dists_max, "max")
	    unless $skip{"max"};
    }
}

__END__
