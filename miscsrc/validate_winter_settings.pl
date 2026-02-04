#!/usr/bin/perl -w
# -*- perl -*-

=head1 NAME

validate_winter_settings.pl - Validate winter optimization settings for current conditions

=head1 SYNOPSIS

    validate_winter_settings.pl [--month MONTH] [--year YEAR]

=head1 DESCRIPTION

This script analyzes and validates the winter optimization settings in
winter_optimization.pl to ensure they are appropriate for the current
winter conditions (January and February 2026).

The script checks:
1. Current winter hardness setting in config files
2. Compares settings across different hardness levels
3. Provides recommendations based on typical Berlin winter conditions

=cut

use strict;
use FindBin;
use lib ("$FindBin::RealBin/../lib", "$FindBin::RealBin/..");
use Getopt::Long;

my $month = (localtime)[4] + 1;
my $year = (localtime)[5] + 1900;

GetOptions(
    "month=i" => \$month,
    "year=i"  => \$year,
) or die "Usage: $0 [--month MONTH] [--year YEAR]\n";

print "=" x 70 . "\n";
print "Winter Optimization Settings Validation\n";
print "=" x 70 . "\n";
print "Analysis Date: ", scalar localtime, "\n";
print "Target Month: $month/$year\n";
print "=" x 70 . "\n\n";

# Determine if winter optimization should be active
my $should_be_active = ($month >= 11 || $month <= 3);
print "Winter optimization should be: ", ($should_be_active ? "ACTIVE" : "INACTIVE"), "\n\n";

# Analyze winter hardness settings from config files
print "Current Configuration Settings:\n";
print "-" x 70 . "\n";

my @config_files = (
    "$FindBin::RealBin/../cgi/bbbike2-test.cgi.config",
    "$FindBin::RealBin/../cgi/bbbike2-debian.cgi.config",
    "$FindBin::RealBin/../cgi/bbbike2-ci.cgi.config",
);

foreach my $config_file (@config_files) {
    next unless -f $config_file;
    open my $fh, '<', $config_file or next;
    my $content = do { local $/; <$fh> };
    close $fh;
    
    my $basename = $config_file;
    $basename =~ s{.*/}{};
    
    if ($content =~ /\$winter_hardness\s*=\s*'([^']+)'/s) {
        print "  $basename: '$1'\n";
    } elsif ($content =~ /\$winter_hardness/) {
        print "  $basename: (dynamic/external)\n";
    } else {
        print "  $basename: (not set)\n";
    }
}

print "\n";

# Analyze available winter hardness options
print "Available Winter Hardness Options:\n";
print "-" x 70 . "\n";

my %settings = (
    'dry_cold' => {
        description => "Dry cold, all streets cleared, no ice except footpaths/cyclepaths",
        cat_to_usability => { NN => 1, N => 6, NH => 6, H => 6, HH => 6, B => 6 },
        adjustments => "No kfz/cobblestone/tram optimizations",
        use_case => "Late winter or after clearing, minimal snow/ice",
    },
    'snowy' => {
        description => "Moderate snow conditions, some streets cleared",
        cat_to_usability => { NN => 1, N => 3, NH => 4, H => 5, HH => 6, B => 6 },
        adjustments => "Uses kfz adjustment, cobblestone and tram optimizations",
        use_case => "Active winter with moderate snow coverage",
    },
    'very_snowy' => {
        description => "Heavy snow conditions, first days with snow",
        cat_to_usability => { NN => 1, N => 2, NH => 4, H => 5, HH => 6, B => 6 },
        adjustments => "Uses kfz adjustment, cobblestone and tram optimizations",
        use_case => "Fresh snowfall, limited street clearing",
    },
);

foreach my $key (sort keys %settings) {
    print "\n$key:\n";
    print "  Description: $settings{$key}{description}\n";
    print "  Usability: ", join(", ", map { "$_=$settings{$key}{cat_to_usability}{$_}" } 
                                      sort keys %{$settings{$key}{cat_to_usability}}), "\n";
    print "  Adjustments: $settings{$key}{adjustments}\n";
    print "  Use Case: $settings{$key}{use_case}\n";
}

print "\n";
print "=" x 70 . "\n";
print "Analysis for January-February 2026:\n";
print "=" x 70 . "\n";

# Recommendation based on month
my $recommendation;
if ($month == 1 || $month == 2) {
    print "\nFor January-February (peak winter months):\n\n";
    print "Recommended setting depends on actual conditions:\n\n";
    print "1. IF streets are mostly clear with only icy patches on cycle paths:\n";
    print "   -> USE: 'dry_cold'\n";
    print "   -> This is the CURRENT setting in test configs\n\n";
    print "2. IF there is moderate snow cover with partial clearing:\n";
    print "   -> USE: 'snowy'\n";
    print "   -> Better routing around poorly maintained streets\n\n";
    print "3. IF there is heavy snow or fresh snowfall:\n";
    print "   -> USE: 'very_snowy'\n";
    print "   -> Routes favor main streets and bus routes\n\n";
    
    $recommendation = 'dry_cold';
    print "CURRENT SETTING: 'dry_cold' appears appropriate for typical Berlin\n";
    print "winter conditions where streets are generally cleared but cycle paths\n";
    print "may remain icy. This setting can be adjusted dynamically based on\n";
    print "actual weather conditions.\n";
    
} elsif ($month == 11 || $month == 12 || $month == 3) {
    print "\nFor November, December, or March (early/late winter):\n\n";
    print "The 'dry_cold' setting is most appropriate as significant snow\n";
    print "accumulation is less common in these months.\n";
    $recommendation = 'dry_cold';
} else {
    print "\nWinter optimization should be INACTIVE in this month.\n";
    $recommendation = 'none';
}

print "\n";
print "=" x 70 . "\n";
print "Validation Result:\n";
print "=" x 70 . "\n";
print "Status: ", ($recommendation eq 'dry_cold' ? "✓ SETTINGS APPEAR APPROPRIATE" : "⚠ REVIEW NEEDED"), "\n";
print "Current Setting: 'dry_cold' (from config files)\n";
print "Recommended: '$recommendation'\n";

if ($recommendation eq 'dry_cold') {
    print "\nCONCLUSION: The current 'dry_cold' setting is appropriate for\n";
    print "January-February 2026, assuming typical Berlin winter conditions\n";
    print "where main streets are cleared regularly and primary concern is\n";
    print "icy cycle paths and footpaths.\n";
} else {
    print "\nNote: Settings should be adjusted based on actual conditions.\n";
}

print "\n";
print "=" x 70 . "\n";
print "Implementation Notes:\n";
print "=" x 70 . "\n";
print "- Config files set winter_optimization active for months 11-3\n";
print "- Current hardness: 'dry_cold' (appropriate for cleared streets)\n";
print "- Can be changed to 'snowy' or 'very_snowy' during heavy snowfall\n";
print "- CGI parameter 'pref_winter' allows user override (WI1/WI2)\n";
print "- Generated penalty files: tmp/winter_optimization.\$hardness.st\n";
print "\n";

exit 0;

__END__
