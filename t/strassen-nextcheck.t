#!/usr/bin/perl -w
# -*- perl -*-

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../lib", "$FindBin::RealBin/../miscsrc");

use Test::More;

if (!eval { require Date::Calc; 1 }) {
    plan skip_all => "Date::Calc needed";
}

eval { require StrassenNextCheck; 1 } or plan skip_all => "StrassenNextCheck (and dependencies) needed: $@";

plan tests => 22;

my $s = bless { file => 'test.bbd' }, 'StrassenNextCheck';

{
    # No directives
    my $dir = {};
    $s->process_nextcheck_record(undef, $dir, check_frequency_days => 30);
    ok(!exists $dir->{_nextcheck_date}, "No _nextcheck_date set when no directives present");
    ok(!exists $dir->{_begincheck_date}, "No _begincheck_date set when no directives present");
}

{
    # next_check only (YYYY-MM-DD)
    my $dir = { next_check => ["2026-12-31"] };
    $s->process_nextcheck_record(undef, $dir, check_frequency_days => 30);
    is($dir->{_nextcheck_date}[0], "2026-12-31", "next_check (YYYY-MM-DD) set correctly");
    is($dir->{_begincheck_date}[0], "2026-12-31", "begin_check_date matches next_check when no other info");
}

{
    # next_check only (YYYY-MM)
    my $dir = { next_check => ["2026-05"] };
    $s->process_nextcheck_record(undef, $dir, check_frequency_days => 30);
    is($dir->{_nextcheck_date}[0], "2026-05-01", "next_check (YYYY-MM) defaults to 1st of month");
}

{
    # last_checked only (without check_frequency)
    my $dir = { last_checked => ["2026-01-01"] };
    $s->process_nextcheck_record(undef, $dir, check_frequency_days => 30);
    is($dir->{_nextcheck_date}[0], "2026-01-31", "last_checked + 30 days default");
    is($dir->{_begincheck_date}[0], "2026-01-02", "begin_check_date is last_checked + 1 day");
}

{
    # last_checked with check_frequency
    my $dir = { last_checked => ["2026-01-01"], check_frequency => ["100d"] };
    $s->process_nextcheck_record(undef, $dir, check_frequency_days => 30);
    is($dir->{_nextcheck_date}[0], "2026-04-11", "last_checked + 100 days");
}

{
    # Both next_check and last_checked
    my $dir = { next_check => ["2026-02-01"], last_checked => ["2026-01-01"], check_frequency => ["10d"] };
    $s->process_nextcheck_record(undef, $dir, check_frequency_days => 30);
    is($dir->{_nextcheck_date}[0], "2026-01-11", "next_check is min of next_check and last_checked+freq");
}

{
    # begin_check directive
    my $dir = { begin_check => ["2026-06-01"] };
    $s->process_nextcheck_record(undef, $dir, check_frequency_days => 30);
    is($dir->{_begincheck_date}[0], "2026-06-01", "begin_check used for _begincheck_date");
}

{
    # Priority of _begincheck_date
    my $dir = { last_checked => ["2026-01-01"], begin_check => ["2026-06-01"] };
    $s->process_nextcheck_record(undef, $dir, check_frequency_days => 30);
    is($dir->{_begincheck_date}[0], "2026-01-02", "last_checked + 1 takes precedence over begin_check");
}

{
    # Malformed date
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, @_ };
    my $dir = { next_check => ["not-a-date"] };
    $s->process_nextcheck_record(undef, $dir, check_frequency_days => 30);
    ok(!exists $dir->{_nextcheck_date}, "Malformed date doesn't set _nextcheck_date");
    my @malformed_warnings = grep { /Malformed next_check directive/ } @warnings;
    like($malformed_warnings[0], qr/Malformed next_check directive 'not-a-date'/, "Warning emitted for malformed date");
}

{
    # Invalid check_frequency
    my $dir = { last_checked => ["2026-01-01"], check_frequency => ["30"] };
    eval {
        $s->process_nextcheck_record(undef, $dir, check_frequency_days => 30);
    };
    like($@, qr/Invalid specification for check_frequency/, "Invalid frequency causes die");
}

{
    # label checks
    my $dir = { last_checked => ["2026-01-01"], check_frequency => ["10d"] };
    $s->process_nextcheck_record(undef, $dir, check_frequency_days => 30);
    is($dir->{_nextcheck_label}[0], "last checked: 2026-01-01, check frequency: 10d", "Label correct for last_checked+freq");

    $dir = { next_check => ["2026-12-31"] };
    $s->process_nextcheck_record(undef, $dir, check_frequency_days => 30);
    is($dir->{_nextcheck_label}[0], "next check: 2026-12-31", "Label correct for next_check");
}

{
    # Frequency from arguments
    my $dir = { last_checked => ["2026-01-01"] };
    $s->process_nextcheck_record(undef, $dir, check_frequency_days => 7);
    is($dir->{_nextcheck_date}[0], "2026-01-08", "last_checked + 7 days from args");
}

{
    # read_stream_nextcheck_records with inline data
    use File::Temp qw(tempfile);
    my($fh, $filename) = tempfile(UNLINK => 1);
    print $fh <<EOF;
#: title: test
#:
#: next_check: 2026-12-31 (something)
Street1	X 1,1 2,2
Street2	X 3,3 4,4
#: last_checked: 2026-01-01 (mapillary)
Street3	X 5,5 6,6
EOF
    close $fh;

    my $s2 = StrassenNextCheck->new_stream($filename);
    my @results;
    $s2->read_stream_nextcheck_records(sub {
        my($r, $dir) = @_;
        push @results, { name => $r->[0], nextcheck => $dir->{_nextcheck_date}[0] };
    });

    is(scalar @results, 2, "Two records with nextcheck found");
    is($results[0]->{name}, "Street1", "First street found");
    is($results[0]->{nextcheck}, "2026-12-31", "First nextcheck correct");
    is($results[1]->{name}, "Street3", "Third street found (Street2 skipped because no nextcheck)");
    is($results[1]->{nextcheck}, "2026-01-31", "Third nextcheck correct (default 30 days)");
}
