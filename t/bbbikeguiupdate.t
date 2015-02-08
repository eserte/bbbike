#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 $FindBin::RealBin,
	);

use BBBikeTest qw(check_cgi_testing check_gui_testing $htmldir);
check_gui_testing;
check_cgi_testing;

use ExtUtils::Manifest qw(manicopy maniread);
use File::Copy qw(cp);
use File::Temp qw(tempdir);
use Tie::File ();

use BBBikeUtil qw(bbbike_root);

my $tmpdir = tempdir("bbbikeguiupdate-XXXXXXXX", TMPDIR => 1, CLEANUP => 1);

chdir "$FindBin::RealBin/.." or die $!;
manicopy(maniread(q{MANIFEST}), "$tmpdir/bbbike", 'cp');
my $t_dir = "$tmpdir/bbbike/t";
mkdir $t_dir if !-d $t_dir;
cp 't/BBBikeGUIUpdateTest.pm', $t_dir
    or die "Copy failed: $!";

my $sample_data_file = "$tmpdir/bbbike/data/ampeln";

my $sample_coord;
chmod 0644, $sample_data_file;
tie my @ampeln, 'Tie::File', $sample_data_file
    or die "Can't tie $sample_data_file: $!";
for my $i (0..$#ampeln) {
    if ($ampeln[$i] =~ m{\tX\s+(\S+)}) {
	$sample_coord = $1;
	splice @ampeln, $i, 1;
	last;
    }
}
if (!$sample_coord) {
    die "Strange: could not find a coordinate in $sample_data_file (maybe category/format changed?)\n";
}
$ENV{BBBIKE_TEST_SAMPLE_COORD} = $sample_coord;
utime 0, 0, $sample_data_file
    or die "Can't change mtime of $sample_data_file: $!";
$ENV{BBBIKE_TEST_ORIG_FILE} = bbbike_root . '/data/ampeln';

$ENV{BBBIKE_GUI_TEST_MODULE} = 'BBBikeGUIUpdateTest';
$ENV{BBBIKE_TEST_HTMLDIR} = $htmldir;
chdir "$tmpdir/bbbike" or die $!;
system $^X, '-It', 'bbbike', '-public';
chdir "/"; # for File::Temp
exit 1 if $? != 0;
__END__
