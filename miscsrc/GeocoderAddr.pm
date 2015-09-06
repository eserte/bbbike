# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2014,2015 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package GeocoderAddr;

use strict;
use vars qw($VERSION);
$VERSION = '0.03';

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
    my $geocode_method = eval {
	require Tie::Handle::Offset;
	require Search::Dict;
	Search::Dict->VERSION(1.07); # because of stat() problems together with tied fhs
	require Unicode::Collate;
	Unicode::Collate->VERSION(0.60); # 0.52 and 0.52_01 have problems with some lookup tests --- at least 0.72 seems to be OK
	1;
    } ? 'geocode_fast_lookup' : 'geocode_linear_scan';
    bless {
	   File          => $file,
	   GeocodeMethod => $geocode_method,
	  }, $class;
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
    my $self = shift;
    my $geocode_method = $self->{GeocodeMethod};
    $self->$geocode_method(@_);
}

sub geocode_fast_lookup {
    my($self, %opts) = @_;
    my $location = delete $opts{location} || die "location is missing";
    my $limit = delete $opts{limit} || 1;
    my $incomplete = delete $opts{incomplete};
    die "Unhandled options: " . join(" ", %opts) if %opts;

    my $search_def = $self->parse_search_string($location);
    my @fields = qw(street hnr zip city);
    my $search_string;
    my $search_string_delimited;
    for my $i (0 .. $#fields) {
	my $val = $search_def->{$fields[$i]};
	if (defined $val && length $val) {
	    $search_string .= $val;
	    if ($i != $#fields) {
		if ($incomplete && join('',map { defined $_ ? $_ : '' } @{$search_def}{@fields[$i+1..$#fields]}) eq '') {
		    # we're done, and no separator to be set
		    last;
		}
		$search_string .= '|';
	    } else {
		$search_string_delimited = 1;
	    }
	} else {
	    last;
	}
    }
    if (!defined $search_string || !length $search_string) {
	die "Empty search string";
    }

    my $s = $self->get_lookup_object;
    if (wantarray) {
	my @rec;
	my $first_result = $s->search_first($search_string, $search_string_delimited);
	if ($first_result) {
	    push @rec, $first_result;
	    while (@rec < $limit) {
		my $result = $s->search_next;
		last if !$result;
		push @rec, $result;
	    }
	}
	if (@rec) {
	    my $glob_dir = Strassen->get_global_directives($self->{File});
	    return $self->_prepare_results(\@rec, $glob_dir);
	} else {
	    return ();
	}
    } else {
	my $rec = $s->search_first($search_string, $search_string_delimited);
	if ($rec) {
	    my $glob_dir = Strassen->get_global_directives($self->{File});
	    return $self->_prepare_result($rec, $glob_dir);
	}
    }
}

sub geocode_linear_scan {
    my($self, %opts) = @_;
    my $location = delete $opts{location} || die "location is missing";
    my $limit = delete $opts{limit} || 1;
    my $incomplete = delete $opts{incomplete};
    die "Unhandled options: " . join(" ", %opts) if %opts;

    my $search_regexp = $self->build_search_regexp($location, $incomplete);
    $search_regexp = qr{$search_regexp};
    my $glob_dir = Strassen->get_global_directives($self->{File});
    open my $fh, $self->{File}
	or die "Can't open $self->{File}: $!";
    if ($glob_dir->{encoding}) {
	binmode $fh, ':encoding('.$glob_dir->{encoding}[0].')';
    }
    my @recs;
    while(<$fh>) {
	next if m{^#};
	if ($_ =~ $search_regexp) {
	    my $rec = Strassen::parse($_);
	    push @recs, $rec;
	    last if @recs >= $limit;
	}
    }
    if (wantarray) {
	$self->_prepare_results(\@recs, $glob_dir);
    } elsif (@recs) {
	$self->_prepare_result($recs[0], $glob_dir);
    } else {
	undef;
    }
}

sub _prepare_results {
    my($class, $recref, $glob_dir) = @_;
    my @results;
    for my $rec (@$recref) {
	push @results, $class->_prepare_result($rec, $glob_dir);
    }

    # Sort house number numerically
    @results = map {
	$_->[0];
    } sort {
	my $cmp = $a->[1] cmp $b->[1];
	if ($cmp == 0) {
	    no warnings 'numeric';
	    $cmp = $a->[2] <=> $b->[2];
	}
	$cmp;
    } map {
	my $details = $_->{details};
	[$_, $details->{street}, defined $details->{hnr} && length $details->{hnr} ? $details->{hnr} : ''];
    } @results;

    @results;
}

sub _prepare_result {
    my(undef, $rec, $glob_dir) = @_;
    my($street,$hnr,$zip,$city) = split /\|/, $rec->[Strassen::NAME];
    my $coord = $rec->[Strassen::COORDS]->[0];
    my($lon,$lat);
    my $coordsystem = $glob_dir->{map} && $glob_dir->{map}[0] ? $glob_dir->{map}[0] : 'standard';
    if ($coordsystem eq 'polar') {
	($lon,$lat) = split /,/, $coord;
    } else {
	($lon,$lat) = $Karte::Polar::obj->standard2map(split /,/, $coord);
    }
    return {
	    details => {
			street => $street,
			hnr    => $hnr,
			zip    => $zip,
			city   => $city,
		       },
	    display_name => "$street $hnr, $zip $city",
	    lon => $lon,
	    lat => $lat,
	   };
}

sub parse_search_string {
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
    my $street = shift @parts;
    $street =~ s{(s)tr\.}{$1traße};
    my $city = pop @parts;
    my $hnr;
    if (defined $street && $street =~ m{^(.*)\s+(\d\S*)$}) {
	$street = $1;
	$hnr = $2;
    }
    return {
	    location => $location,
	    street   => $street,
	    hnr      => $hnr,
	    zip      => $zip,
	    city     => $city,
	   };
}

sub build_search_regexp {
    my($self, $location, $incomplete) = @_;

    my $search_def = $self->parse_search_string($location);
    my @fields = qw(street hnr zip city);

    my $search_regexp;
    for my $i (0 .. $#fields) {
	my $val = $search_def->{$fields[$i]};
	if (!defined $search_regexp) {
	    $search_regexp = '^(?i:';
	} else {
	    $search_regexp .= '\|';
	}
	if (defined $val && length $val) {
	    $search_regexp .= quotemeta($val);
	    if ($incomplete && join('',map { defined $_ ? $_ : '' } @{$search_def}{@fields[$i+1..$#fields]}) eq '') {
		$search_regexp .= '[^|]+';
	    }
	} else {
	    $search_regexp .= '[^|]+';
	}
    }
    $search_regexp .= "\t)";
    $search_regexp;
}

sub convert_for_lookup {
    my($self, $dest) = @_;
    my $lookup = $self->get_lookup_object;
    $lookup->convert_for_lookup($dest);
}

sub get_lookup_object {
    my($self) = @_;
    require Strassen::Lookup;
    Strassen::Lookup->new($self->{File}, SubSeparator => '|');
}

1;

__END__

=head1 NAME

GeocoderAddr - Geo::Coder::* compatible handling of _addr files

=head1 SYNOPSIS

    use GeocoderAddr;
    my $gc = GeocoderAddr->new_berlin_addr;
    my $location = $gc->geocode(location => ...);
    my @locations = $gc->geocode(location => ..., limit => ...);

=head1 DESCRIPTION

Implements geocoding similar to other CPAN modules like
L<Geo::Coder::Google> for a L<osm2bbd-postprocess>-created file
C<_addr>. Normally such files are created during the
L<osm2bbd>+L<osm2bbd-postprocess> conversion process.

=head2 CONSTRUCTORS

=head3 C<< new(file => ...) >>

Create a C<GeocoderAddr> object. The C<file> parameter is mandatory
and should point to a C<_addr> file.

=head3 C<< new_berlin_addr() >>

Create a C<GeocoderAddr> object for Berlin OSM data.

=head2 METHODS

=head3 C<< check_availability() >>

Return true if an C<_addr> file for the constructed object is really
available.

=head3 C<< geocode(location => ..., limit => ..., incomplete => ...) >>

Geocode the given location. The C<location> argument is mandatory and
should be a string consisting of a street name, and optionally house
number, zip code, and city name. Parsing is done using the
L</parse_search_string> method.

In scalar context, return a hash element with the following elements:

=over

=item lat

=item lon

=item display_name

=item details

A hash with the following keys: street, hnr, zip, and city.

=back

In list context, a list of such hash elements is returned.

C<limit> limits the number of result elements in list context. If not
given, defaults to 1.

If C<incomplete> is set to a true value, then it's assumed that
C<location> contains an incomplete string, which may be suitable for a
suggestion functionality.

Internally, C<geocode> is implemented either with the
C<geocode_fast_lookup> method using a fast binary search, or with
C<geocode_linear_scan> method using a slow linear search. The binary
search is picked if all prerequisites are met (i.e.
L<Tie::Handle::Offset>, L<Search::Dict> in version 1.07 or higher, and
L<Unicode::Collate> in version 0.60 or higher).

=head3 C<< parse_search_string(I<$location>) >>

Do some heuristics and parse the given location string into a hash
suitable for further processing.

=head3 C<< convert_for_lookup(I<$dest>) >>

Create a sorted version of the C<_addr> file specified in the
constructor, and write it to the given destination. Used by
L<osm2bbd-postprocess> internally.

=head1 EXAMPLES

Quick geocoding on the commandline. Somewhat complicated because of
dealing with command line arguments encoding:

    perl -MI18N::Langinfo=langinfo,CODESET -MData::Dumper -MEncode=decode -Ilib -Imiscsrc -MGeocoderAddr -e '@ARGV = map { $_ = decode(langinfo(CODESET),$_) } @ARGV; warn Dumper(GeocoderAddr->new_berlin_addr->geocode(location => shift))' "Main street 1"

=head1 AUTHOR

Slaven Rezic

=head1 SEE ALSO

L<Strassen::Lookup>, L<Geo::Coder::Google>, L<Geo::Coder::Googlev3>,
L<Search::Dict>.

=cut
