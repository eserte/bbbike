#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

if (!$ENV{BBBIKE_TEST_GUI}) {
    require Test::More;
    Test::More::plan(skip_all => 'Set BBBIKE_TEST_GUI to run test');
}

use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 $FindBin::RealBin,
	);
use ExtUtils::Manifest qw(manicopy maniread);
use File::Copy qw(cp);
use File::Temp qw(tempdir);

use BBBikeTest qw(check_cgi_testing $htmldir);
check_cgi_testing;

my $tmpdir = tempdir("bbbikeguiupdate-XXXXXXXX", TMPDIR => 1, CLEANUP => 1);

chdir "$FindBin::RealBin/.." or die $!;
manicopy(maniread(q{MANIFEST}), "$tmpdir/bbbike", 'cp');
my $t_dir = "$tmpdir/bbbike/t";
mkdir $t_dir if !-d $t_dir;
cp 't/BBBikeGUIUpdateTest.pm', $t_dir
    or die "Copy failed: $!";

$ENV{BBBIKE_GUI_TEST_MODULE} = 'BBBikeGUIUpdateTest';
$ENV{BBBIKE_TEST_HTMLDIR} = $htmldir;
chdir "$tmpdir/bbbike" or die $!;
system $^X, '-It', 'bbbike', '-public';
chdir "/"; # for File::Temp
exit 1 if $? != 0;
__END__
