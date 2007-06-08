#!/usr/bin/perl

use strict;
use CGI::Carp qw(fatalsToBrowser);

use FindBin;
use Archive::Zip qw(:ERROR_CODES);
use CGI qw(:standard);
use ExtUtils::Manifest qw(maniread);
use File::Temp qw(tempfile);

my @l = localtime;
my $date = sprintf '%04d%02d%02d', $l[5]+1900, $l[4]+1, $l[3];

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
my(undef, $filename) = tempfile(SUFFIX => ".zip",
				UNLINK => 1);
if ($zip->writeToFileNamed($filename) != AZ_OK) {
    die q{Can't write zip file $filename};
}

print header(-Content_Type => 'application/zip',
	     -Content_Disposition => "attachment; filename=bbbike_data_$date.zip",
	     -Content_Length => -s $filename,
	    );
open my $fh, $filename or die "Can't open $filename: $!";
binmode $fh;
seek $fh, 0, 0;
local $/ = \8192;
print <$fh>;

unlink $filename;
