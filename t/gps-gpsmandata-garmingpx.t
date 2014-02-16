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
	);
use Getopt::Long;
use Test::More 'no_plan';

use_ok('GPS::GpsmanData::GarminGPX');

sub usage () {
    die <<EOF;
usage: $0 [--gpx-symbols=file]

--gpx-symbols=file: a utf-8 encoded file containing GPX <sym> names, one per line
EOF
}

my $gpx_symbol_file;
GetOptions("gpx-symbols=s" => \$gpx_symbol_file)
    or usage;
!@ARGV
    or usage;

is GPS::GpsmanData::GarminGPX::garmin_symbol_name_to_gpsman_symbol_name('Kopfsteinpflaster'), 'user:7684';
is GPS::GpsmanData::GarminGPX::gpsman_symbol_to_garmin_symbol_name('user:7684'), 'Kopfsteinpflaster';

is GPS::GpsmanData::GarminGPX::garmin_symbol_name_to_gpsman_symbol_name('Bridge'), 'bridge';
is GPS::GpsmanData::GarminGPX::gpsman_symbol_to_garmin_symbol_name('bridge'), 'Bridge';

is GPS::GpsmanData::GarminGPX::garmin_symbol_name_to_gpsman_symbol_name('City (Medium)'), 'medium_city';
is GPS::GpsmanData::GarminGPX::gpsman_symbol_to_garmin_symbol_name('medium_city'), 'City (Medium)';

if ($gpx_symbol_file) {
    my @missing_translations;
    my @successful_translations;
    open my $fh, "<:encoding(utf-8)", $gpx_symbol_file or die "Can't open $gpx_symbol_file: $!";
    while (<$fh>) {
	chomp;
	my $gpx_sym = $_;
	my $gpsman_symbol_name = GPS::GpsmanData::GarminGPX::garmin_symbol_name_to_gpsman_symbol_name($gpx_sym);
	if (!defined $gpsman_symbol_name) {
	    push @missing_translations, "No translation for $gpx_sym";
	} else {
	    push @successful_translations, "$gpx_sym -> $gpsman_symbol_name";
	}
    }
    diag "Successful translations:\n" . join("\n", @successful_translations) . "\n" . "Missing translations:\n" . join("\n", @missing_translations);
}

__END__
