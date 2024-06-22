#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 $FindBin::RealBin,
	);

use Test::More;
use POSIX 'strftime';

use BBBikeTest qw(check_network_testing);

plan skip_all => "Skipped without BBBIKE_LONG_TESTS set" if !$ENV{BBBIKE_LONG_TESTS};
plan skip_all => "IPC::Run needed" if !eval { require IPC::Run; 1 };
plan skip_all => "Date::Calc needed" if !eval { require Date::Calc; 1 };
plan 'no_plan';

my $script = "$FindBin::RealBin/../miscsrc/dwd-soil-update.pl";

my $success = IPC::Run::run([$script], '>', \my $stdout, '2>', \my $stderr);
ok $success, "$script runs ok"
    or diag "stderr: $stderr";
like $stderr, qr{INFO: update station \d+}, 'found update of recent file in stderr';
like $stderr, qr{INFO: check for historical data from station \d+}, 'found update of historical file in stderr';

my $count_stations = 0;
my $min_date;
my $max_date;
for my $line (split /\n/, $stdout) {
    if (my($station, $date, $value) = $line =~ /^(.*?)\s+:\s+(\d{8})\s+(\d+)$/) {
	$count_stations++;
	if (!defined $min_date || $min_date lt $date) { $min_date = $date }
	if (!defined $max_date || $max_date gt $date) { $max_date = $date }
    } else {
	fail "Cannot parse line '$line'";
    }
}
cmp_ok $count_stations, '>=', 5, 'expected minimum number of stations';
my $today = strftime "%Y%m%d", localtime;
my $delta_min_date = Date::Calc::Delta_Days(date2ymd($min_date), date2ymd($today));
my $delta_max_date = Date::Calc::Delta_Days(date2ymd($max_date), date2ymd($today));
cmp_ok $delta_min_date, '<=', 2, "oldest date $min_date is ok (delta $delta_min_date)";
cmp_ok $delta_max_date, '>=', 0, "newest date $max_date is ok (delta $delta_max_date, not in future)";

sub date2ymd {
    my $date = shift;
    if (my($y,$m,$d) = $date =~ /^(\d{4})(\d{2})(\d{2})$/) {
	($y,$m,$d);
    } else {
	die "Can't parse '$date'";
    }
}

__END__
