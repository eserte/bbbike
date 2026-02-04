#!/usr/bin/perl -w
# -*- perl -*-

=head1 NAME

winter-optimization.t - Test winter optimization settings and validation

=cut

use strict;
use Test::More;

use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../lib");

plan tests => 13;

# Test 1: Check if winter_optimization.pl exists
ok(-f "$FindBin::RealBin/../miscsrc/winter_optimization.pl", 
   "winter_optimization.pl exists");

# Test 2: Check if validation script exists
ok(-f "$FindBin::RealBin/../miscsrc/validate_winter_settings.pl",
   "validate_winter_settings.pl exists");

# Test 3: Check if documentation exists
ok(-f "$FindBin::RealBin/../doc/winter_optimization_2026_analysis.md",
   "Winter optimization analysis document exists");

# Test 4: Verify winter_optimization.pl is executable
ok(-x "$FindBin::RealBin/../miscsrc/winter_optimization.pl",
   "winter_optimization.pl is executable");

# Test 5: Verify validate_winter_settings.pl is executable
ok(-x "$FindBin::RealBin/../miscsrc/validate_winter_settings.pl",
   "validate_winter_settings.pl is executable");

# Test 6-8: Check config files have winter settings
my @config_files = (
    "$FindBin::RealBin/../cgi/bbbike2-test.cgi.config",
    "$FindBin::RealBin/../cgi/bbbike2-debian.cgi.config",
);

foreach my $config_file (@config_files) {
    SKIP: {
        skip "Config file $config_file not found", 1 unless -f $config_file;
        
        open my $fh, '<', $config_file or skip "Cannot read $config_file", 1;
        my $content = do { local $/; <$fh> };
        close $fh;
        
        like($content, qr/use_winter_optimization|winter_hardness/,
             "Config file has winter optimization settings");
    }
}

# Test 9: Verify winter hardness options in winter_optimization.pl
{
    open my $fh, '<', "$FindBin::RealBin/../miscsrc/winter_optimization.pl" 
        or die "Cannot read winter_optimization.pl: $!";
    my $content = do { local $/; <$fh> };
    close $fh;
    
    like($content, qr/winter_hardness eq 'snowy'/,
         "winter_optimization.pl contains 'snowy' option");
    like($content, qr/winter_hardness eq 'very_snowy'/,
         "winter_optimization.pl contains 'very_snowy' option");
    like($content, qr/winter_hardness eq 'dry_cold'/,
         "winter_optimization.pl contains 'dry_cold' option");
}

# Test 10: Check validate_winter_settings.pl runs without errors
{
    my $output = `cd $FindBin::RealBin/../miscsrc && perl validate_winter_settings.pl 2>&1`;
    my $exit_code = $? >> 8;
    is($exit_code, 0, "validate_winter_settings.pl runs successfully");
}

# Test 11: Verify output contains validation results
{
    my $output = `cd $FindBin::RealBin/../miscsrc && perl validate_winter_settings.pl 2>&1`;
    like($output, qr/Validation Result/i, "Validation script produces validation results");
}

# Test 12: Check for appropriate settings for winter months
{
    my @l = localtime;
    my $m = $l[4] + 1;
    my $should_be_active = ($m >= 11 || $m <= 3);
    
    my $output = `cd $FindBin::RealBin/../miscsrc && perl validate_winter_settings.pl 2>&1`;
    
    if ($should_be_active) {
        like($output, qr/should be:\s+ACTIVE/i,
             "Winter optimization correctly identified as active in winter months");
    } else {
        like($output, qr/should be:\s+INACTIVE/i,
             "Winter optimization correctly identified as inactive in non-winter months");
    }
}

__END__

=head1 AUTHOR

Created for validating winter optimization settings for January/February 2026.

=cut
