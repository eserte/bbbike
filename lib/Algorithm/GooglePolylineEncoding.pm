# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2009,2010 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Algorithm::GooglePolylineEncoding;

use 5.006; # sprintf("%b")

use strict;
use vars qw($VERSION);
$VERSION = '0.02';

sub encode_number {
#   1. Take the initial signed value:
#      -179.9832104
    my $number = shift;
#   2. Take the decimal value and multiply it by 1e5, rounding the result:
#      -17998321
    $number = int($number * 1e5 + ($number < 0 ? -0.5 : 0.5));
    # Don't do this before rounding. Negativeness may change if for example
    # using very small negative numbers.
    my $is_negative = $number < 0;
#   3. Convert the decimal value to binary. Note that a negative value must be calculated using its two's complement by inverting the binary value and adding one to the result:
#      00000001 00010010 10100001 11110001
#      11111110 11101101 01011110 00001110
#      11111110 11101101 01011110 00001111
    # nothing to do here, we don't calculate with binary strings...
#   4. Left-shift the binary value one bit:
#      11111101 11011010 10111100 00011110
    $number <<= 1;
    $number &= 0xffffffff; # to assure 32 bit
#   5. If the original decimal value is negative, invert this encoding:
#      00000010 00100101 01000011 11100001
    if ($is_negative) {
        $number = (~$number);
        $number &= 0xffffffff;
    }
#   6. Break the binary value out into 5-bit chunks (starting from the right hand side):
#      00001 00010 01010 10000 11111 00001
    my $bin = sprintf '%b', $number;
    $bin = '0'x(5-length($bin)%5) . $bin if length($bin)%5 != 0; # pad
    my @chunks;
    my $revbin = reverse $bin;
    push @chunks, scalar reverse($1) while $revbin =~ m{(.....)}g;
#   7. Place the 5-bit chunks into reverse order:
#      00001 11111 10000 01010 00010 00001
    # It's already reversed
#   8. OR each value with 0x20 if another bit chunk follows:
#      100001 111111 110000 101010 100010 000001
    @chunks = ((map { oct("0b$_") | 0x20 } @chunks[0 .. $#chunks-1]), oct("0b".$chunks[-1])); # and also decode to decimal on the fly
#   9. Convert each value to decimal:
#      33 63 48 42 34 1
    # Done above
#  10. Add 63 to each value:
#      96 126 111 105 97 64
    @chunks = map { $_+63 } @chunks;
#  11. Convert each value to its ASCII equivalent:
#      `~oia@
    @chunks = map { chr } @chunks;
    join '', @chunks;
}

sub encode_polyline {
    my(@path) = @_;
    my @res;
    my($curr_lat,$curr_lon) = do { my $first = shift @path; ($first->{lat}, $first->{lon}) };
    push @res, encode_number($curr_lat), encode_number($curr_lon);
    for my $lat_lon (@path) {
        my($lat,$lon) = ($lat_lon->{lat}, $lat_lon->{lon});
        my $deltay = $lat - $curr_lat;
        my $deltax = $lon - $curr_lon;
        push @res, encode_number($deltay), encode_number($deltax);
        ($curr_lat,$curr_lon) = ($lat,$lon);
    }
    join '', @res;
}

sub encode_level {
#   1. Take the initial unsigned value:
#      174
    my $number = shift;
#   2. Convert the decimal value to a binary value:
#      10101110
    my $bin = sprintf '%b', $number;
#   3. Break the binary value out into 5-bit chunks (starting from the right hand side):
#      101 01110
    $bin = '0'x(5-length($bin)%5) . $bin if length($bin)%5 != 0; # pad
    my @chunks;
    my $revbin = reverse $bin;
    push @chunks, scalar reverse($1) while $revbin =~ m{(.....)}g;
#   4. Place the 5-bit chunks into reverse order:
#      01110 101
    # It's already reversed
#   5. OR each value with 0x20 if another bit chunk follows:
#      101110 00101
    @chunks = ((map { oct("0b$_") | 0x20 } @chunks[0 .. $#chunks-1]), oct("0b".$chunks[-1])); # and also decode to decimal on the fly
#   6. Convert each value to decimal:
#      46 5
    # Done above
#   7. Add 63 to each value:
#      109 68
    @chunks = map { $_+63 } @chunks;
#   8. Convert each value to its ASCII equivalent:
#      mD
    @chunks = map { chr } @chunks;
    join '', @chunks;
}

# Translated this php script
# <http://unitstep.net/blog/2008/08/02/decoding-google-maps-encoded-polylines-using-php/>
# to perl
sub decode_polyline {
    my($encoded) = @_;

    my $length = length $encoded;
    my $index = 0;
    my @points;
    my $lat = 0;
    my $lng = 0;

    while ($index < $length) {
	# The encoded polyline consists of a latitude value followed
	# by a longitude value. They should always come in pairs. Read
	# the latitude value first.
	for my $val (\$lat, \$lng) {
	    my $shift = 0;
	    my $result = 0;
	    # Temporary variable to hold each ASCII byte.
	    my $b;
	    do {
		# The `ord(substr($encoded, $index++))` statement returns
		# the ASCII code for the character at $index. Subtract 63
		# to get the original value. (63 was added to ensure
		# proper ASCII characters are displayed in the encoded
		# polyline string, which is `human` readable)
		$b = ord(substr($encoded, $index++, 1)) - 63;

		# AND the bits of the byte with 0x1f to get the original
		# 5-bit `chunk. Then left shift the bits by the required
		# amount, which increases by 5 bits each time. OR the
		# value into $results, which sums up the individual 5-bit
		# chunks into the original value. Since the 5-bit chunks
		# were reversed in order during encoding, reading them in
		# this way ensures proper summation.
		$result |= ($b & 0x1f) << $shift;
		$shift += 5;
	    }
		# Continue while the read byte is >= 0x20 since the last
		# `chunk` was not OR'd with 0x20 during the conversion
		# process. (Signals the end)
		while ($b >= 0x20);

	    use integer; # see last paragraph of "Integer Arithmetic" in perlop.pod

	    # Check if negative, and convert. (All negative values have the last bit
	    # set)
	    my $dtmp = (($result & 1) ? ~($result >> 1) : ($result >> 1));

	    # Compute actual latitude (resp. longitude) since value is
	    # offset from previous value.
	    $$val += $dtmp;
	}

	# The actual latitude and longitude values were multiplied by
	# 1e5 before encoding so that they could be converted to a 32-bit
	# integer representation. (With a decimal accuracy of 5 places)
	# Convert back to original values.
	push @points, {lat => $lat * 1e-5, lon => $lng * 1e-5};
    }

    @points;
}

1;

__END__

=head1 NAME

Algorithm::GooglePolylineEncoding - Google's Encoded Polyline Algorithm Format

=head1 SYNOPSIS

    use Algorithm::GooglePolylineEncoding;
    @polyline = ({lat => 52.5, lon => 13.4}, ...);
    $encoded_polyline = Algorithm::GooglePolylineEncoding::encode_polyline(@polyline);

=head1 DESCRIPTION

B<Algorithm::GooglePolylineEncoding> implements the encoded polyline
algorithm format which is used in some parts of the Google Maps API.
The algorithm is described in
L<http://code.google.com/intl/en/apis/maps/documentation/polylinealgorithm.html>.

This module is a light-weight version of
L<Geo::Google::PolylineEncoder>, essentially just doing the encoding
part without any line simplification, and implemented without any CPAN
dependencies.

=head2 FUNCTIONS

=over

=item encode_polyline(@polyline)

Take an array of C<< {lat => ..., lon => ...} >> hashrefs and return
an encoded polyline string. Latitudes and longitudes should be
expressed as decimal degrees (DD;
L<http://en.wikipedia.org/wiki/Decimal_degrees>).

=item encode_level($level)

Return an encoded level.

=item encode_number($number)

Return just an encoded number (which may be a single longitude, or
latitude, or delta).

=item decode_polyline($encoded)

Take an encoded polyline string and return a list of C<< {lat => ...,
lon => ...} >> hashrefs.

=back

=head1 AUTHOR

Slaven Rezic <srezic@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2009,2010 Slaven Rezic. All rights reserved.
This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Geo::Google::PolylineEncoder>

=cut
