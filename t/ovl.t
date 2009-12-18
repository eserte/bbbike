#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: ovl.t,v 1.9 2006/10/10 22:11:38 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);
use GPS::Ovl;
use File::Temp qw(tempfile);
use Data::Dumper qw(Dumper);
use File::Glob qw(bsd_glob);
use File::Basename qw(basename);
use Getopt::Long;

BEGIN {
    if (!eval q{
	use Test::More;
	use File::Temp qw(tempfile);
	use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
	1;
    }) {
	print "1..0 # skip no Test::More, File::Temp and/or Archive::Zip modules\n";
	exit;
    }
}

my $v;
my $ovl2dir = "$FindBin::RealBin/../misc/download_tracks";

GetOptions("v!" => \$v) or die "usage!";

my @ovl_files = bsd_glob("$ovl2dir/*.[oO][vV][lL]");
push @ovl_files, \"[Symbol 1]
Typ=3
Col=1
Zoom=2
Size=3
Art=1
Punkte=4
XKoord0=13.38671737
YKoord0=52.38241084
XKoord1=13.36620291
YKoord1=52.38408742
XKoord2=13.34522846
YKoord2=52.39484059
XKoord3=13.34522846
YKoord3=52.39484059
";
# XXX test with binary data missing

my $tests_per_file = 1;
my $simple_tests_per_file = 1;
my $total_file_tests = 4 * $tests_per_file;
my $tests = $total_file_tests + scalar(@ovl_files) * $simple_tests_per_file;
plan tests => $tests;
my $ovl_zip = "$ovl2dir/bahn_mv.zip";

SKIP: {
    skip("No ovl archive for testing available", $total_file_tests)
	if !-r $ovl_zip;

    my $zip = Archive::Zip->new;
    $zip->read($ovl_zip);

    for my $basename (qw(mv01 mv02 mv04 mv08)) {
	diag $basename if $v;

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
	    is($errors, 0, "Coord mismatches not found for $basename")
		or diag Dumper([$res_binary->[0]{Coords}, $res_ascii->[0]{Coords}]);
	}
    }
}

for my $ovl_file (@ovl_files) {
    my $test_label = basename $ovl_file;
    if (ref $ovl_file) {
	my($fh,$filename) = tempfile(SUFFIX => ".ovl",
				     UNLINK => 1);
	print $fh $$ovl_file;
	close $fh;
	$ovl_file = $filename;
	$test_label = "data in test script";
    }
    diag $test_label if $v;

    my $ovl = GPS::Ovl->new;
 SKIP: {
# 	skip("Can't handle $basename", $simple_tests_per_file)
# 	    if $basename =~ m{^(DorGS|ErlGS|mtbstrecke2003msymbol|RkRg-EPR|strfrankenfels2005tats).ovl$};

	eval { $ovl->check($ovl_file) };
	if ($@) {
	    chomp $@;
	    skip($@, $simple_tests_per_file);
	}

	$ovl->read;
	cmp_ok(scalar(@{$ovl->{Symbols}}), ">", 0, "Can read symbols from $test_label");
    }
}

__END__
