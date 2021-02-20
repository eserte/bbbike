#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;

use Fcntl qw(SEEK_SET);
use File::Temp qw(tempfile);
use Getopt::Long;
use Test::More;

GetOptions(
	   "doit!" => \my $doit,
	   'url=s@' => \my @urls,
	  )
    or die "usage: $0 [--doit] [--url ...]\n";

plan skip_all => "Run tests only with --doit option" if !$doit;
plan 'no_plan';

if (!@urls) {
    push @urls, 'http://bbbike.de';
}

my($tmpfh,$tmpfile) = tempfile(SUFFIX => "_url_checker.bbd", UNLINK => 1);
print $tmpfh "#: map: polar\n";
print $tmpfh "#: note: just a test file for url_checker.t\n";
print $tmpfh "#: \n";
for my $url (@urls) {
    print $tmpfh "#: url: $url\n";
}
print $tmpfh "Cern street\tX 6.04541,46.23420\n";

my($logfh,$logfile) = tempfile(SUFFIX => "_url_checker.log", UNLINK => 1);
my @cmd = ($^X, "$FindBin::RealBin/../miscsrc/url_checker.pl", "--frequency", 0, "--log", $logfile, $tmpfile);
my $start_epoch = time;
system @cmd;
my $end_epoch = time;
is $?, 0, "'@cmd' run ok";

my %tested_urls;
open $logfh, "<", $logfile or die "Can't open $logfile: $!"; # cannot reused $logfh here
while(<$logfh>) {
    chomp;
    my($url, $epoch, $code) = split /\t/, $_;
    $tested_urls{$url}++;
    cmp_ok $epoch, ">=", $start_epoch, "Timestamp for $url, lower end";
    cmp_ok $epoch, "<=", $end_epoch,   "Timestamp for $url, upper end";
    is $code, 200, "Status for $url is OK";
}

for my $url (@urls) {
    ok $tested_urls{$url}, "$url found in log";
}

__END__
