#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2025 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# WWW:  https://github.com/eserte/bbbike
#

use strict;
use warnings;
use FindBin;
use v5.10.0; # defined-or

use JSON::PP;
use Math::Trig 'pi', 'sinh', 'atan';
use POSIX 'strftime';

my $miscdir = "$FindBin::RealBin/../misc";

# Helper: parse YYYYMMDD date format to comparable string
sub parse_date {
  my $datestr = shift;
  return unless defined $datestr;
  if ($datestr =~ /^(\d{4})(\d{2})(\d{2})$/) {
    return "$1-$2-$3";
  }
  die "Invalid date format, must be YYYYMMDD";
}

# Helper: extract zoom, tile_x, tile_y from filename
sub parse_filename {
  my $filename = shift;
  if ($filename =~ /tile_(\d+)_(\d+)_(\d+)\.mvt$/) {
    return ($1, $2, $3);
  }
  die "Filename must be tile_<zoom>_<x>_<y>.mvt";
}

# Helper: convert tile and geometry coords to lat/lon
sub tile_coord_to_latlon {
  my ($tile_x, $tile_y, $zoom, $geom_x, $geom_y) = @_;
  my $tile_size = 4096;
  my $n = 2 ** $zoom;

  my $flipped_y = $tile_size - $geom_y;
  my $pixel_x = $tile_x * $tile_size + $geom_x;
  my $pixel_y = $tile_y * $tile_size + $flipped_y;

  my $lon_deg = ($pixel_x / ($tile_size * $n)) * 360.0 - 180.0;
  my $merc_y = ($pixel_y / ($tile_size * $n));
  my $lat_rad = atan(sinh(pi * (1 - 2 * $merc_y)));
  my $lat_deg = $lat_rad * 180 / pi;

  return ($lat_deg, $lon_deg);
}

# Helper: recursively flatten nested geometry coordinates
sub flatten_coordinates {
  my $coords = shift;
  if (ref $coords->[0] ne 'ARRAY') { return [$coords]; }
  my @flat;
  for my $c (@$coords) { push @flat, @{flatten_coordinates($c)}; }
  return \@flat;
}

# Helper: convert captured_at timestamps from milliseconds
sub format_timestamp_ms {
  my $ts = shift;
  return "" if !defined $ts or $ts eq '';
  my $sec = int($ts / 1000);
  # Convert to ISO8601 UTC timestamp
  return strftime("%Y-%m-%dT%H:%M:%SZ", gmtime($sec));
}

use constant {
  CMD_MOVE_TO  => 1,
  CMD_LINE_TO  => 2,
  CMD_CLOSE_PATH => 7,
};

# ZigZag decode an integer
sub zigzag_decode {
  my $n = shift;
  use integer;
  return ($n >> 1) ^ ( -($n & 1) );
}

#sub zigzag_decode {
#  my $n = shift;
#use Devel::Peek; Dump $n;#XXX
#my $r = ($n >> 1) ^ ( -($n & 1) );
#warn $r;
#  # Perl integers are platform dependent, ensure proper signed conversion:
#  return ($n >> 1) ^ ( -($n & 1) );
#}

#sub zigzag_decode {
#    my ($z) = @_;
#    my $sign = $z & 1;             # 0 for positive, 1 for negative
#    my $value = $z >> 1;           # logical shift right
#    return $sign ? -($value + 1) : $value;
#}



# Decode geometry commands from array of integers
# Returns arrayref of parts, each part is arrayref of [x,y] points
sub decode_geometry {
  my($geom, $extent) = @_;
  my @geometry = @$geom;  # array of integers from protobuf
  my $i = 0;
  my $dx = 0;
  my $dy = 0;
  my @parts;

  while ($i < @geometry) {
    my $command_integer = $geometry[$i++];
    my $cmd = $command_integer & 0x7;
    my $count = $command_integer >> 3;
    die "Unknown command $cmd" unless $cmd == CMD_MOVE_TO || $cmd == CMD_LINE_TO || $cmd == CMD_CLOSE_PATH;

    if ($cmd == CMD_CLOSE_PATH) {
      # ClosePath has no params and count is usually 1
      # It means close the current ring (connect last point to first)
      # We don't need params, just mark last part closed
      # Optionally you may close the polygon ring explicitly in your usage
      next;
    }

    my @points;
    for (1..$count) {
      my $x = zigzag_decode($geometry[$i++]);
      my $y = zigzag_decode($geometry[$i++]);
      $x += $dx;
      $y += $dy;

      $dx = $x;
      $dy = $y;
      
      # if not y_coord_down:
      $y = $extent - $y;

      push @points, [$x, $y];
    }

    if ($cmd == CMD_MOVE_TO) {
      # MoveTo starts a new part
      push @parts, \@points;
    }
    elsif ($cmd == CMD_LINE_TO) {
      # LineTo appends points to the current part
      if (@parts) {
        push @{$parts[-1]}, @points;
      } else {
        # Usually should not happen, but in case no prior MoveTo, treat as new part
        push @parts, \@points;
      }
    }
  }

  return \@parts;
}

# Main processing logic
my ($zoom, $tile_x, $tile_y) = parse_filename($ARGV[0]);
my $date_from = $ARGV[1] ? parse_date($ARGV[1]) : undef;
my $date_to = $ARGV[2] ? parse_date($ARGV[2]) : undef;

open my $fh, "<:raw", $ARGV[0] or die $!;
my $data = do { local $/; <$fh> };

my $proto = do { open my $fh, "$miscdir/vector_tile.proto" or die "Can't load $miscdir/vector_tile.proto: $!"; local $/; <$fh> };

my $tile;
if (eval { require Google::ProtocolBuffers::Dynamic; 1 }) {
    #warn "Use Google::ProtocolBuffers::Dynamic.\n";
    my $pb = Google::ProtocolBuffers::Dynamic->new($FindBin::RealBin);
    $pb->load_string("vector_tile.proto", <<EOF . $proto);
syntax = "proto2";
EOF
    $pb->map({ package => 'vector_tile', prefix => 'VectorTile' });

    $tile = VectorTile::Tile->decode($data);
} else {
    require Google::ProtocolBuffers;
    #warn "Use Google::ProtocolBuffers.\n";
    Google::ProtocolBuffers->parse($proto);

    $tile = VectorTile::Tile->decode($data);
}
#require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([$tile],[qw()])->Indent(1)->Useqq(1)->Sortkeys(1)->Terse(1)->Dump; # XXX

my ($sequence_layer) = grep { $_->{name} eq 'sequence' } @{$tile->{layers}};
die "No 'sequence' layer found in tile." unless $sequence_layer;

my @sequences;

my($keys, $values) = ($sequence_layer->{keys}, $sequence_layer->{values});
my $extent = $sequence_layer->{extent} || die "extent missing in layer";

for my $feat (@{$sequence_layer->{features}}) {

  my $tags = $feat->{tags};
  my $props = {};
  for (my $i = 0; $i < @$tags; $i += 2) {
    my $key_idx = $tags->[$i];
    my $val_idx = $tags->[$i+1];

    my $key = $keys->[$key_idx];
    my $val_entry = $values->[$val_idx];

    # Values are typed, e.g., $val_entry->{string_value}, {int_value}, etc.
    # Extract the actual value depending on which field is set
    my $value;
    if (exists $val_entry->{string_value}) {
	$value = $val_entry->{string_value};
    }
    elsif (exists $val_entry->{int_value}) {
	$value = $val_entry->{int_value};
    }
    elsif (exists $val_entry->{double_value}) {
	$value = $val_entry->{double_value};
    }
    elsif (exists $val_entry->{bool_value}) {
	$value = $val_entry->{bool_value};
    }
    # ... handle other value types similarly

    $props->{$key} = $value;
  }

  my $seq_id = $props->{id} or next;

  my $geom_data = $feat->{geometry};
  my $coords = decode_geometry($geom_data, $extent);
  $coords or next;

  # Flatten and convert coordinates
  my $flat_coords = flatten_coordinates($coords);
#require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([$flat_coords],[qw()])->Indent(1)->Useqq(1)->Sortkeys(1)->Terse(1)->Dump; # XXX
  my @latlon;
  for my $coord (@$flat_coords) {
    my ($lat, $lon) = tile_coord_to_latlon($tile_x, $tile_y, $zoom, $coord->[0], $coord->[1]);
    push @latlon, [$lat, $lon];
  }

  my $start_captured_at = format_timestamp_ms($props->{captured_at} // $props->{start_captured_at});
  next unless $start_captured_at; # Filter no start date

  if ($date_from && $start_captured_at lt $date_from) { next; }
  if ($date_to && $start_captured_at gt $date_to) { next; }

  my $start_id = $props->{image_id} // $props->{start_id} // $seq_id;
  my $creator = defined $props->{creator_id} ? $props->{creator_id} : "";
  my $make = $props->{make} // "";
  my $end_captured_at = format_timestamp_ms($props->{end_captured_at} // "");

  my $url = sprintf("https://www.mapillary.com/app/user/%s?pKey=%s&focus=photo&dateFrom=%s&dateTo=%s&z=15&lat=%f&lng=%f",
                    $creator, $start_id, substr($start_captured_at,0,10), substr($start_captured_at,0,10),
                    $latlon[0][0], $latlon[0][1]);

  push @sequences, {
    url => $url,
    start_captured_at => $start_captured_at,
    end_captured_at => $end_captured_at,
    creator => $creator,
    make => $make,
    start_id => $start_id,
    sequence => $seq_id,
    coordinates => \@latlon,
  };
}

print encode_json(\@sequences);


__END__
