#!/usr/bin/perl

use strict;
use FindBin;
use Archive::Zip qw(:ERROR_CODES);
use CGI qw(:standard);
use ExtUtils::Manifest qw(maniread);

my @l = localtime;
my $date = sprintf '%04d%02d%02d', $l[5]+1900, $l[4]+1, $l[3];

print header(-Content_Type => 'application/zip',
	     -Content_Disposition => "attachment; filename=bbbike_data_$date.zip",
	    );
binmode STDOUT;

chdir "$FindBin::RealBin/.." or die "Can't chdir to bbbike root dir: $!";
my $manifest = maniread('MANIFEST');

my @datafiles;
for my $file (sort keys %$manifest) {
    push @datafiles, $file if $file =~ m{^data};
}

my $zip = Archive::Zip->new;
for my $datafile (@datafiles) {
    $zip->addFile($datafile);
}
if ($zip->writeToFileHandle(\*STDOUT) != AZ_OK) {
    die q{Can't write zip file};
}

