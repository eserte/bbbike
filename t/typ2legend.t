#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/../",
	 "$FindBin::RealBin/../lib",
	 $FindBin::RealBin,
	);

use File::Temp qw(tempdir);
use IO::File ();
use Test::More;

if (!eval { require IPC::Run; 1 }) {
    plan skip_all => "IPC::Run needed for typ2legend testing";
    exit;
}

use BBBikeUtil qw(bbbike_root is_in_path);
use BBBikeTest qw(tidy_check);

if (!is_in_path('convert')) {
    plan skip_all => 'convert (from ImageMagick) needed as a prereq for typ2legend';
    exit;
}

plan 'no_plan';

my $dir = tempdir("typ2legend_XXXXXXXX", CLEANUP => 1, TMPDIR => 1);
my $bbbike_root = bbbike_root;

my @cmd = ($^X, "$bbbike_root/miscsrc/typ2legend.pl", "-f", "-o", $dir, "-title", "Legende für die OSM-Garmin-Karte");
ok IPC::Run::run(\@cmd, "<", "$bbbike_root/misc/mkgmap/typ/M000002a.TXT");
my $index_file = "$dir/index.html";
ok -s $index_file, "Index file $index_file created";
my $index_content = slurp($index_file);
tidy_check $index_content, "HTML check of $index_file";

sub slurp { join '', IO::File->new(shift)->getlines }

__END__
