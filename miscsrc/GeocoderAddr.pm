# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2014 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package GeocoderAddr;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

# experimental geocoder for "_addr" as created by osm2bbd

use BBBikeUtil qw(bbbike_root);
use Karte::Polar;
use Karte::Standard;
use Strassen::Core;

sub new {
    my($class, $file) = @_;
    if (!$file) {
	die "Missing file parameter";
    }
    bless { File => $file }, $class;
}

sub new_berlin_addr {
    my($class) = @_;
    $class->new(bbbike_root . "/data_berlin_osm_bbbike/_addr");
}

sub check_availability {
    my($self) = @_;
    -s $self->{File};
}

sub geocode {
    my($self, %opts) = @_;
    my $location = delete $opts{location} || die "location is missing";
    die "Unhandled options: " . join(" ", %opts) if %opts;
    my $search_regexp = $self->build_search_regexp($location);
    $search_regexp = qr{$search_regexp};
    my $glob_dir = Strassen->get_global_directives($self->{File});
    open my $fh, $self->{File}
	or die "Can't open $self->{File}: $!";
    if ($glob_dir->{encoding}) {
	binmode $fh, ':encoding('.$glob_dir->{encoding}[0].')';
    }
    while(<$fh>) {
	next if m{^#};
	if ($_ =~ $search_regexp) {
	    my $rec = Strassen::parse($_);
	    my($str,$hnr,$zip,$city) = split /\|/, $rec->[Strassen::NAME];
	    my $coord = $rec->[Strassen::COORDS]->[0];
	    my($lon,$lat);
	    if ($glob_dir->{map} && $glob_dir->{map}[0] eq 'polar') {
		($lon,$lat) = split /,/, $coord;
	    } else {
		($lon,$lat) = $Karte::Polar::obj->standard2map(split /,/, $coord);
	    }
	    return {
		    details => {
				street => $str,
				hnr    => $hnr,
				zip    => $zip,
				city   => $city,
			       },
		    display_name => "$str $hnr, $zip $city",
		    lon => $lon,
		    lat => $lat,
		   };
	}
    }
}

sub build_search_regexp {
    my($self, $location) = @_;

    my(@parts) = split /\s*,\s*/, $location;
    my $zip;
    for my $i (0 .. $#parts) {
	if ($parts[$i] =~ s{\b(\d{5})\b}{}) { # looks like German zip
	    $zip = $1;
	    $parts[$i] =~ s{^\s+}{}; $parts[$i] =~ s{\s+$}{}; # trim
	    if ($parts[$i] eq '') {
		splice @parts, $i, 1;
	    }
	    last;
	}
    }
    my $str = shift @parts;
    $str =~ s{(s)tr\.}{$1traﬂe};
    my $city = pop @parts;
    my $hnr;
    if (defined $str && $str =~ m{^(.*)\s+(\d\S*)$}) {
	$str = $1;
	$hnr = $2;
    }
    my $search_regexp;
    for my $val ($str, $hnr, $zip, $city) {
	if (!defined $search_regexp) {
	    $search_regexp = '^(?i:';
	} else {
	    $search_regexp .= '\|';
	}
	if (defined $val && length $val) {
	    $search_regexp .= quotemeta($val);
	} else {
	    $search_regexp .= '[^|]+';
	}
    }
    $search_regexp .= "\t)";
    $search_regexp;
}

1;

__END__
