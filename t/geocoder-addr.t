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
	 "$FindBin::RealBin/../miscsrc", 
	);

use Getopt::Long;
use Test::More 'no_plan';

sub check_geocoding ($$$;$);
sub check_parse_string ($$);
sub utf8 ($);

use_ok 'GeocoderAddr';

my $do_complete_file;
my $start_with;
GetOptions(
	   "complete-file" => \$do_complete_file,
	   "start-with=s" => \$start_with,
	  )
    or die "usage: $0 [--complete-file [--start-with=...]]\n";

my $geocoder = GeocoderAddr->new_berlin_addr;
isa_ok $geocoder, 'GeocoderAddr';

SKIP: {
    skip "_addr file is not available", 1
	if !$geocoder->check_availability;

    if ($geocoder->{GeocodeMethod} eq 'geocode_linear_scan') {
	diag 'geocode_linear_scan used, except slow test run';
    }

    if ($do_complete_file) {
	do_complete_file();
    }

    {
	my $regexp = $geocoder->build_search_regexp("Dudenstraße");
	ok $regexp;
    }

    # only street, titlecase and lowercase
    for my $str ('Dudenstraße', 'dudenstraße') {
	check_geocoding $str, qr{^Dudenstraße}, '13.370467,52.485352 13.386009,52.484715'
    }
    {
	my $dudenstr24_bbox = '13.381574,52.485224 13.382067,52.484818';
	check_geocoding "Dudenstraße 24", "Dudenstraße 24, 10965 Berlin", $dudenstr24_bbox;
	check_geocoding "Dudenstr. 24", "Dudenstraße 24, 10965 Berlin", $dudenstr24_bbox;
	check_geocoding "Dudenstraße 24, Berlin", "Dudenstraße 24, 10965 Berlin", $dudenstr24_bbox;
	check_geocoding "Dudenstraße 24, Berlin, 10965", "Dudenstraße 24, 10965 Berlin", $dudenstr24_bbox;
	check_geocoding "Dudenstraße 24, 10965 Berlin", "Dudenstraße 24, 10965 Berlin", $dudenstr24_bbox;
    }

    {
	# Beginning with umlaut
	my $uederseestr1_bbox = '13.520082,52.482163 13.519437,52.482601';
	check_geocoding 'Üderseestraße 1', 'Üderseestraße 1, 10318 Berlin', $uederseestr1_bbox, 'full name, without utf8 flag';
	check_geocoding 'Üderseestr. 1', 'Üderseestraße 1, 10318 Berlin', $uederseestr1_bbox, 'short name, without utf8 flag';
	check_geocoding 'üderseestraße 1', 'Üderseestraße 1, 10318 Berlin', $uederseestr1_bbox, 'full name, lowercase, without utf8 flag';
	check_geocoding 'üderseestr. 1', 'Üderseestraße 1, 10318 Berlin', $uederseestr1_bbox, 'short name, lowercase, without utf8 flag';
    }

    {
	# internal utf8 should also work
	my $uederseestr1_bbox = '13.520082,52.482163 13.519437,52.482601';
	check_geocoding utf8('Üderseestraße 1'), 'Üderseestraße 1, 10318 Berlin', $uederseestr1_bbox, 'full name, with utf8 flag';
	check_geocoding utf8('Üderseestr. 1'), 'Üderseestraße 1, 10318 Berlin', $uederseestr1_bbox, 'short name, without utf8 flag';
	check_geocoding utf8('üderseestraße 1'), 'Üderseestraße 1, 10318 Berlin', $uederseestr1_bbox, 'full name, lowercase, without utf8 flag';
	check_geocoding utf8('üderseestr. 1'), 'Üderseestraße 1, 10318 Berlin', $uederseestr1_bbox, 'short name, lowercase, without utf8 flag';
    }

    {
	# Another umlaut street
	my $aehrenweg10_bbox = '13.561505,52.514429 13.562112,52.514098';
	check_geocoding 'Ährenweg 10', 'Ährenweg 10, 12683 Berlin', $aehrenweg10_bbox;
	check_geocoding 'ährenweg 10', 'Ährenweg 10, 12683 Berlin', $aehrenweg10_bbox;
    }
}

check_parse_string "Dudenstraße 24", { str => "Dudenstraße", hnr => "24" };
check_parse_string "Dudenstr. 24", { str => "Dudenstraße", hnr => "24" };
check_parse_string "Dudenstraße 24, Berlin", { str => "Dudenstraße", hnr => "24", city => "Berlin" };
check_parse_string "Dudenstraße 24, Berlin, 10965", { str => "Dudenstraße", hnr => "24", city => "Berlin", zip => "10965" };
check_parse_string "Dudenstraße 24, 10965 Berlin", { str => "Dudenstraße", hnr => "24", city => "Berlin", zip => "10965" };

sub check_geocoding ($$$;$) {
    my($in_street, $expected_street, $bbox, $testname) = @_;
    $testname = defined $testname ? " ($testname)" : '';
    my $res = $geocoder->geocode(location => $in_street);
    ok $res, "got a result for <$in_street>" . $testname;
    if ($res) {
	if (ref $expected_street eq 'Regexp') {
	    like $res->{display_name}, $expected_street, "regexp check" . $testname;
	} else {
	    is $res->{display_name}, $expected_street, "equality check" . $testname;
	}
	my($x1,$y1,$x2,$y2) = split /[, ]/, $bbox;
	($x1,$x2) = ($x2,$y1) if $x1 > $x2;
	($y1,$y2) = ($y2,$y1) if $y1 > $y2;
	my($lon, $lat) = @{$res}{qw(lon lat)};
	ok $lon >= $x1 && $lon <= $x2 && $lat >= $y1 && $lat <= $y2, 'lon/lat within bounding box' . $testname
	    or diag "Got lon=$lon lat=$lat, not within $bbox" . $testname;
    } else {
	fail "No result - no further checks" . $testname for (1..2);
    }
}

sub check_parse_string ($$) {
    my($location, $expected_result) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $res = $geocoder->parse_search_string($location);
    for my $key (keys %$res) {
	delete $res->{$key} if !defined $res->{$key};
    }
    is delete($res->{location}), $location, "location check for '$location'";
    is_deeply $res, $expected_result, "parse_search_string check for '$location'";
}

sub utf8 ($) {
    my $s = shift;
    utf8::upgrade($s);
    $s;
}

sub do_complete_file {
    require Strassen::Core;
    my $s = Strassen->new($geocoder->{File});
    $s->init;
    my $logfile = '/tmp/geocoder-addr-errors.log';
    open my $ofh, ">", $logfile
	or die "Can't write to $logfile: $!";
    $ofh->autoflush(1);
    binmode $ofh, ':encoding(utf-8)';
    my $mismatches = 0;
    my $checks = 0;
    while() {
	my $r = $s->next;
	last if !@{ $r->[Strassen::COORDS()] };
	my $strname = $r->[Strassen::NAME()];
	if (defined $start_with) {
	    if ($start_with eq $strname) {
		undef $start_with;
	    } else {
		next;
	    }
	}
	my($str, $hnr, $plz, $city) = split /\|/, $strname;
	for my $location (
			  "$str $hnr, $plz $city",
			  lc("$str $hnr, $plz $city"),
			  lc("$str $hnr, $plz"),
			 ) {
	    my $res = $geocoder->geocode(location => $location);
	    if (!$res) {
		print $ofh "No result for '$location'\n";
		$mismatches++;
	    } else {
		my $res_string = join('|', @{$res->{details}}{qw(street hnr zip city)});
		if ($res_string ne $strname) {
		    print $ofh "Mismatch: '$res_string' - '$strname' (for '$location')\n";
		    $mismatches++;
		}
	    }
	    $checks++;
	    print STDERR "\rchecked: $checks; failed: $mismatches";
	}
    }
    if (defined $start_with) {
	fail "--start-with value '$start_with' not found in file";
    }
    is $mismatches, 0, 'no mismatches found'
	or diag "Please look into $logfile for errors";
}

__END__
