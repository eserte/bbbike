#!/usr/bin/perl
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use warnings;
use FindBin;
use Test::More;
use Getopt::Long;
use POSIX qw(strftime);

GetOptions("doit" => \my $doit)
    or die "usage: $0 [--doit]\n";

plan skip_all => 'Please specify --doit for running tests'
    if !$doit;
plan 'no_plan';

my $script = "$FindBin::RealBin/../miscsrc/icao_metar.pl";
ok -x $script, 'script exists and is executable';

open my $fh, '-|', $script, '-auto-fallback', '-timeout', 5, '-retry-def', '1,2', '-sitecode', 'EDDB', '-wettermeldung'
    or die "Can't run $script: $!";
chomp(my $line = <$fh>);
close $fh
    or die "Error while running $script: $!";

my $today     = strftime "%d.%m.%Y", localtime;
my $yesterday = strftime "%d.%m.%Y", localtime(time()-86400); # may be wrong during DST switches
s/\b0(?=\d)// for $today, $yesterday; # traditionally no leading zeroes in wetter files
my @fields = split /\|/, $line;
cmp_ok scalar(@fields), '>=', 10, 'expected at least 10 fields';
like $fields[0], qr{^(\Q$today\E|\Q$yesterday\E)$}, "date: expected $today or $yesterday";
like $fields[1], qr{^\d{1,2}\.\d{2}$}, "time: expected H.MM or HH.MM";
like $fields[2], qr{^[+-]?\d+(?:\.\d+)?$}, 'temperature field';

__END__
