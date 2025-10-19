#!/usr/bin/env python3

import argparse
import sys
import mapbox_vector_tile
import json
import math
import re
from datetime import datetime

def parse_date(datestr):
    """Convert YYYYMMDD to YYYY-MM-DD if format matches."""
    if not datestr:
        return None
    m = re.match(r"^(\d{4})(\d{2})(\d{2})$", datestr)
    if not m:
        print("Invalid date format: {} (expected YYYYMMDD)".format(datestr), file=sys.stderr)
        sys.exit(1)
    return "{}-{}-{}".format(m.group(1), m.group(2), m.group(3))

def tile_coord_to_latlon(tile_x, tile_y, zoom, geom_x, geom_y):
    tile_size = 4096
    n = 2 ** zoom

    # Flip Y coordinate within tile to correct mirrored coordinates
    flipped_y = tile_size - geom_y

    pixel_x = tile_x * tile_size + geom_x
    pixel_y = tile_y * tile_size + flipped_y

    lon_deg = (pixel_x / (tile_size * n)) * 360.0 - 180.0
    merc_y = (pixel_y / (tile_size * n))
    lat_rad = math.atan(math.sinh(math.pi * (1 - 2 * merc_y)))
    lat_deg = math.degrees(lat_rad)

    return lat_deg, lon_deg

def parse_filename(filename):
    match = re.search(r'tile_(\d+)_(\d+)_(\d+)\.mvt$', filename)
    if not match:
        print("Error: Filename must be in format tile_<zoom>_<tile_x>_<tile_y>.mvt")
        sys.exit(1)
    zoom = int(match.group(1))
    tile_x = int(match.group(2))
    tile_y = int(match.group(3))
    return zoom, tile_x, tile_y

def flatten_coordinates(coords):
    if isinstance(coords[0], (int, float)):
        return [coords]
    else:
        result = []
        for c in coords:
            result.extend(flatten_coordinates(c))
        return result

def format_timestamp_ms(ts):
    try:
        # Convert milliseconds to integer seconds
        dt = datetime.utcfromtimestamp(round(ts / 1000.0))
        return dt.isoformat()
    except (ValueError, OSError):
        return ""

def main():
    parser = argparse.ArgumentParser(
        description="Process MVT tile files with optional date filtering."
    )
    parser.add_argument(
        "tile_file",
        help="Path to the tile file (.mvt)",
    )
    parser.add_argument(
        "date_from",
        nargs="?",
        help="Start date (format: YYYYMMDD)",
    )
    parser.add_argument(
        "date_to",
        nargs="?",
        help="End date (format: YYYYMMDD)",
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Enable debug mode (prints extra information)",
    )

    args = parser.parse_args()

    filter_date_from = parse_date(args.date_from)
    filter_date_to   = parse_date(args.date_to)

    if args.debug:
        print("date_from: {}".format(json.dumps(filter_date_from)), file=sys.stderr)
        print("date_to:   {}".format(json.dumps(filter_date_to)),   file=sys.stderr)

    tile_file = args.tile_file
    zoom, tile_x, tile_y = parse_filename(tile_file)

    with open(tile_file, "rb") as f:
        tile_bytes = f.read()

    tile = mapbox_vector_tile.decode(tile_bytes)
    sequence_layer = tile.get("sequence")
    if not sequence_layer:
        print("No 'sequence' layer found in tile.")
        sys.exit(0)

    features = sequence_layer.get("features", [])
    sequences = []

    for feat in features:
        if args.debug:
            print(json.dumps(feat, indent=2), file=sys.stderr)

        if not isinstance(feat, dict):
            continue

        props = feat.get("properties", {})
        geom = feat.get("geometry", {})
        coords = geom.get("coordinates", [])
        seq_id = props.get("id")

        if not coords or not seq_id:
            if args.debug:
                print("skipping feature, no coords/seq id...", file=sys.stderr)
            continue

        start_id = props.get("image_id") or props.get("start_id") or seq_id
        creator_id = props.get("creator_id")
        creator = str(creator_id) if creator_id is not None else ""
        make = props.get("make") or ""
        start_captured_at = props.get("captured_at") or props.get("start_captured_at") or ""
        end_captured_at = props.get("end_captured_at") or ""

        formatted_start = format_timestamp_ms(start_captured_at) if start_captured_at else ""

        # Filter sequences by hardcoded start date
        if formatted_start:
            if filter_date_from and formatted_start < filter_date_from:
                if args.debug:
                    print("skipping feature, before date_from...", file=sys.stderr)
                continue  # skip sequences before start date
            if filter_date_to and formatted_start > filter_date_to:
                if args.debug:
                    print("skipping feature, after date_to...", file=sys.stderr)
                continue  # skip sequences after start date
        else:
            if args.debug:
                print("skipping feature, no start date...", file=sys.stderr)
            continue  # skip if no start date

        flat_coords = flatten_coordinates(coords)
        print(json.dumps(flat_coords))
        latlon_points = []
        for coord in flat_coords:
            geom_x, geom_y = coord[0], coord[1]
            lat, lon = tile_coord_to_latlon(tile_x, tile_y, zoom, geom_x, geom_y)
            latlon_points.append([lat, lon])

        date_from = formatted_start[:10] if formatted_start else ""
        date_to = date_from
        formatted_end = format_timestamp_ms(end_captured_at) if end_captured_at else ""

        url = (
            "https://www.mapillary.com/app/user/{creator}"
            "?pKey={start_id}&focus=photo&dateFrom={date_from}&dateTo={date_to}"
            "&z=15&lat={lat}&lng={lon}"
        ).format(
            creator=creator,
            start_id=start_id,
            date_from=date_from,
            date_to=date_to,
            lat=latlon_points[0][0] if latlon_points else 0,
            lon=latlon_points[0][1] if latlon_points else 0,
        )

        sequences.append({
            "url": url,
            "start_captured_at": formatted_start,
            "end_captured_at": formatted_end,
            "creator": creator,
            "make": make,
            "start_id": start_id,
            "sequence": seq_id,
            "coordinates": latlon_points,
        })

    print(json.dumps(sequences, indent=2))

if __name__ == "__main__":
    main()
