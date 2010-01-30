#!/usr/bin/perl

use strict;
use CGI::Carp qw(fatalsToBrowser);

use Archive::Zip qw(:ERROR_CODES);
use Cwd qw(realpath);
use CGI qw(:standard);
use ExtUtils::Manifest qw(maniread);
use File::Basename qw(dirname);
use File::Temp qw(tempfile);

my $do_snapshot = $0 =~ /bbbike-snapshot\.cgi/;

my @l = localtime;
my $date = sprintf '%04d%02d%02d', $l[5]+1900, $l[4]+1, $l[3];

# Do not use FindBin, because it does not work with Apache::Registry
my $rootdir = dirname(dirname(realpath($0)));
chdir $rootdir or die "Can't chdir to bbbike root dir <$rootdir>: $!";
my $manifest = maniread('MANIFEST');

my @files;
for my $file (sort keys %$manifest) {
    push @files, $file if $file =~ m{^data} || $do_snapshot;
}

my $zip = Archive::Zip->new;
for my $file (@files) {
    $zip->addFile($file, ($do_snapshot ? "BBBike-snapshot-$date/$file" : ()));
}
my(undef, $filename) = tempfile(SUFFIX => "-bbbike-" . ($do_snapshot ? "snapshot" : "data") .  ".zip",
				UNLINK => 1);
# I can use writeToFileNamed and have Content-Length set,
# but the transfer starts some seconds later, or I
# can use writeToFileHandle and have NOT Content-Length
# set, but the transfer starts probably somewhat faster.
#
# I chose the former.
if ($zip->writeToFileNamed($filename) != AZ_OK) {
    die q{Can't write zip file $filename};
}

print header(-Content_Type => 'application/zip',
	     -Content_Disposition => "attachment; filename=bbbike_" . ($do_snapshot ? "snapshot" : "data") . "_$date.zip",
	     -Content_Length => -s $filename,
	    );
open my $fh, $filename or die "Can't open $filename: $!";
binmode $fh;
seek $fh, 0, 0;
local $/ = \8192;
print <$fh>;

unlink $filename;

__END__

=pod

Note that almost the same archive may be created using git:

    git archive --format=zip HEAD -- `grep "^data" MANIFEST`

Only data/.modified is missing and has to be added afterwards.

=cut
