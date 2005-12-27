#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: ovl.t,v 1.1 2005/12/26 13:10:24 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);
use GPS::Ovl;
use File::Temp qw(tempfile);

BEGIN {
    if (!eval q{
	use Test::More;
	use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
	1;
    }) {
	print "1..0 # skip: no Test::More module\n";
	exit;
    }
}

my $ovlresdir = "$FindBin::RealBin/../misc/ovl_resources";
my $ovl2dir = "$ovlresdir/various_from_net";

my $tests_per_file = 1;
plan tests => 4 * $tests_per_file;

my $zip = Archive::Zip->new;
$zip->read("$ovl2dir/bahn_mv.zip");

for my $basename (qw(mv01 mv02 mv04 mv08)) {
 SKIP: {
	skip("mv08 not the same file?", $tests_per_file)
	    if ($basename eq 'mv08');

	my($tmpfh,$tmpfilename) = tempfile(SUFFIX => "_a_${basename}.ovl",
					   UNLINK => 1);
	$zip->extractMember("a_${basename}.ovl", $tmpfilename) == AZ_OK or die $!;

	my $ovl_ascii = GPS::Ovl->new;
	$ovl_ascii->check($tmpfilename);
	my $res_ascii = $ovl_ascii->read;
	
	my $ovl_binary = GPS::Ovl->new;
	$ovl_binary->check("$ovl2dir/${basename}.ovl");
	my $res_binary = $ovl_binary->read;

	my $errors = 0;
	for my $i (0 .. $#{$res_binary->[0]{Coords}}) {
	    my $c_binary = $res_binary->[0]{Coords}[$i];
	    my $c_ascii  = $res_ascii->[0]{Coords}[$i];
	    my($x1,$y1) = @$c_binary;
	    my($x2,$y2) = @$c_ascii;
	    if (abs($x1-$x2) > 0.00000001 ||
		abs($y1-$y2) > 0.00000001) {
		diag "$x1/$y1 <-> $x2/$y2" if $errors ==  0;
		$errors++;
	    }
	}
	is($errors, 0, "Coord mismatches found for $basename");
    }
}

__END__
