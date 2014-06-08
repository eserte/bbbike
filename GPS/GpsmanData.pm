# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2002,2005,2007,2010,2014 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

# read gpsman files

package GPS::GpsmanData;

BEGIN {
    require GPS;
    push @ISA, qw(GPS);
}
use strict;

BEGIN {
    # This used Class::Accessor, but unfortunately I don't want to
    # depend on a non-core module.
    no strict 'refs';
    for (qw(File DatumFormat PositionFormat Creation
	    Type Name
	    Waypoints WaypointsHash
	    Track CurrentConverter
	    TimeOffset TrackAttrs IsTrackSegment
	    LineInfo
	   )) {
	my $acc = $_;
	*{$acc} = sub {
	    my $self = shift;
	    if (@_) {
		$self->{$acc} = $_[0];
	    }
	    $self->{$acc};
	};
    }
}

use vars qw($VERSION @EXPORT_OK);
$VERSION = 1.71;

use constant TYPE_UNKNOWN  => -1;
use constant TYPE_WAYPOINT => 0;
use constant TYPE_TRACK    => 1;
use constant TYPE_ROUTE    => 2;
use constant TYPE_GROUP    => 3;

use base qw(Exporter);
@EXPORT_OK = qw(TYPE_WAYPOINT TYPE_TRACK TYPE_ROUTE TYPE_GROUP);

use GPS::Util; # for eliminate_umlauts

{
    package GPS::Gpsman::Waypoint;

    use myclassstruct qw(Ident Comment Latitude Longitude ParsedLatitude ParsedLongitude Altitude NewTrack Symbol Accuracy DisplayOpt DateTime HiddenAttributes);

    use vars qw($_container_warning);

    sub Comment_to_unixtime {
	my($wpt, $container) = @_;
	if (!defined $container && !$_container_warning) {
	    require Carp;
	    Carp::carp("*** Please specify container object in Comment_to_unixtime for correct timezone information");
	    $_container_warning++;
	}
	my $datetime = $wpt->DateTime;
	if (!defined $datetime || $datetime eq '') {
	    $datetime = $wpt->Comment;
	    if (!defined $datetime || $datetime eq '') {
		return undef;
	    }
	}
	my $epoch;
	if ($datetime =~ /^(\d{4})-(\d{2})-(\d{2})\s+(\d{1,2}):(\d{2}):(\d{2})/) {
	    my($y,$m,$d, $H,$M,$S) = ($1,$2,$3,$4,$5,$6);
	    require Time::Local;
	    $epoch = Time::Local::timegm($S,$M,$H,$d,$m-1,$y-1900);
	} elsif ($datetime =~ /^(\d{1,2})-([^-]{3})-(\d{2,4})\s+(\d{1,2}):(\d{2}):(\d{2})/) {
	    my($d,$m_name,$y, $H,$M,$S) = ($1,$2,$3,$4,$5,$6);
	    if ($y < 100) { # waypoint files seem to have two-digit years
		$y += 2000;
	    }
	    my $m = GPS::GpsmanData::monthabbrev_number($m_name);
	    return undef if !defined $m;
	    require Time::Local;
	    $epoch = Time::Local::timegm($S,$M,$H,$d,$m-1,$y-1900);
	}
	if (defined $epoch && defined $container) {
	    $epoch -= $container->TimeOffset*3600;
	}
	$epoch;
    }

    sub unixtime_to_Comment  { shift->_unixtime_to_member('Comment', @_) }
    sub unixtime_to_DateTime { shift->_unixtime_to_member('DateTime', @_) }

    sub _unixtime_to_member {
	my($wpt, $member, $epoch, $container_or_timeoffset) = @_;
	my $timeoffset = ($container_or_timeoffset
			  ? (UNIVERSAL::can($container_or_timeoffset, 'TimeOffset')
			     ? $container_or_timeoffset->TimeOffset
			     : ($container_or_timeoffset =~ m{^[-+]?\d+(?:\.\d+)?$}
				? $container_or_timeoffset
				: die "Invalid container or timeoffset specification '$container_or_timeoffset'"
			       )
			    )
			  : undef
			 );
	$wpt->$member(GPS::GpsmanData::_unixtime_to_gpsmantime($epoch, $timeoffset));
    }

    sub _coord_output {
	my($wpt, $container) = @_;
	if ($container->PositionFormat eq 'DDD') {
	    if (defined $wpt->Latitude) {
		my $lat_prefix = $wpt->Latitude  < 0 ? 'S' : 'N';
		my $lon_prefix = $wpt->Longitude < 0 ? 'W' : 'E';
		($lat_prefix . $wpt->Latitude, $lon_prefix . $wpt->Longitude);
	    } else {
		(undef, undef);
	    }
	} else {
	    if (defined $wpt->ParsedLatitude) { # XXX???
		($wpt->ParsedLatitude, $wpt->ParsedLongitude);
	    } else {
		if (defined $wpt->Latitude) {
		    GPS::GpsmanData::convert_lat_long_to_gpsman_DMS($wpt->Latitude, $wpt->Longitude)
		} else {
		    (undef, undef);
		}
	    }
	}
    }

    sub DumpHiddenAttributes {
	my($wpt) = @_;
	my $hidden_attributes = $wpt->HiddenAttributes;
	if ($hidden_attributes && ref $hidden_attributes) {
	    my @fields;
	    while(my($k,$v) = each %$hidden_attributes) {
		push @fields, $k.'='.$v;
	    }
	    if (@fields) {
		return join "\t", @fields;
	    } else {
		return;
	    }
	} else {
	    return;
	}
    }

    sub as_gpx {
	my($wpt, $xmlnode, $chunk, %args) = @_;

	my $garmin_userdef_symbols_set = delete $args{'garmin_userdef_symbols_set'};
	
	$xmlnode->setAttribute("lat", $wpt->Latitude);
	$xmlnode->setAttribute("lon", $wpt->Longitude);

	# Note: order of child elements is important for
	# schema validation

	my $altitude = $wpt->Altitude;
	if (defined $altitude and length $altitude) {
	    my $elexml = $xmlnode->addNewChild(undef, 'ele');
	    $elexml->appendText($altitude);
	}

	my $epoch = $wpt->Comment_to_unixtime($chunk);
	if (defined $epoch) {
	    require POSIX;
	    my $timexml = $xmlnode->addNewChild(undef, 'time');
	    $timexml->appendText(POSIX::strftime("%Y-%m-%dT%H:%M:%SZ", gmtime($epoch))); # %FT%T is not portable
	    if ($args{autoskipcmt}) { # if the comment was recognized as a datetime, then there's no need to dump it also as a comment
		$args{skipcmt} = 1;
	    }
	}

	my $ident = $wpt->Ident;
	if (defined $ident && length $ident) { # undefined for track waypoints
	    my $namexml = $xmlnode->addNewChild(undef, "name");
	    $namexml->appendText($ident);
	}

	# may be skipped, because often it's just the date/time
	if (!$args{skipcmt}) {
	    my $comment = $wpt->Comment;
	    if (defined $comment and length $comment) {
		my $commentxml = $xmlnode->addNewChild(undef, 'cmt');
		$commentxml->appendText($comment);
	    }
	}

	my $symbol = $wpt->Symbol;
	if (defined $symbol && length $symbol) {
	    $symbol = GPS::GpsmanData::GarminGPX::gpsman_symbol_to_garmin_symbol_name($symbol, $garmin_userdef_symbols_set);
	    if (defined $symbol) {
		if ($args{symtocmt}) {
		    my $commentxml = $xmlnode->addNewChild(undef, 'cmt');
		    $commentxml->appendText($symbol);
		}

		my $symbolxml = $xmlnode->addNewChild(undef, 'sym');
		$symbolxml->appendText($symbol);
	    }
	}
    }

}

# for GPS.pm
sub check {
    my($self, $file, %args) = @_;
    open my $F, $file
	or die "Can't open file $file: $!";
    my $max_lines = 10;
    my $check = 0;
    while(<$F>) {
	next if /^%/ || /^\s*$/;
	if (/!Format: (DMS|DDD) (-?\d+(?:\.\d+)?) (WGS 84)/) {
	    if (ref $self) {
		my($pos_format, $time_offset, $datum_format) = ($1, $2, $3);
		$self->change_position_format($pos_format);
		$self->TimeOffset($time_offset);
		$self->DatumFormat($datum_format);
	    }
	    $check = 1;
	    last;
	}
	$max_lines--;
	last if ($max_lines <= 0);
    }
    close $F;
    $check;
}

sub convert_to_route {
    my($self, $file, %args) = @_;

    $self = __PACKAGE__->new if !ref $self;
    $self->load($file);

    $self->do_convert_to_route(%args);
}

sub do_convert_to_route {
    my($self, %args) = @_;

    require Karte::Polar;
    require Karte::Standard;
    my $obj = $Karte::Polar::obj;
    my $to_obj = $Karte::Standard::obj = $Karte::Standard::obj; # peacify -w

    my @res;

    if (!$self->{Track} && $self->{Waypoints}) {
	die "Can convert only tracks to routes, no waypoint files";
    }
    foreach my $wpt (@{ $self->Track }) {
	my($x,$y) = $to_obj->trim_accuracy
	    ($obj->map2standard($wpt->Longitude, $wpt->Latitude)
	    );
	if (!@res || ($x != $res[-1]->[0] ||
		      $y != $res[-1]->[1])) {
	    push @res, [$x, $y];
	}
    }

    @res;
}

# XXX maybe better use a route instead of a tracklog
# If called as a static method: return the track as a string
# If called as an object method: fill the object with the route data
sub convert_from_route {
    my($self, $route, %args) = @_;

    $self = __PACKAGE__->new if !ref $self;
    $self->Type(TYPE_TRACK);
    $self->Name(sprintf("%-8s", $args{-routename} || "TRACBACK"));

    no locale; # for scalar localtime

    require Karte::Polar;
    require Strassen;
    require GPS::G7toWin_ASCII;

    my $obj = $Karte::Polar::obj;

    my $str       = $args{-streetobj};
    my $net       = $args{-netobj};
    my %crossings;
    if ($str) {
	%crossings = %{ $str->all_crossings(RetType => 'hash',
					    UseCache => 1) };
    }

    my $now = scalar localtime;
    my $point_counter = 0;
    my %point_counter;
    use constant MAX_COMMENT => 45;

    use constant DISPLAY_SYMBOL_BIG => 8196; # zwei kleine Füße
    use constant DISPLAY_SYMBOL_SMALL => 18; # viereckiger Punkt, also allgemeiner Wegepunkt
    use constant SHOW_SYMBOL => 1;
    use constant SHOW_SYMBOL_AND_NAME => 4; # XXX ? ja ?
    use constant SHOW_SYMBOL_AND_COMMENT => 5;

    my @data;
    my @path;
    my $obj_type;
    if ($args{-routetoname}) {
	@path = map
	         { $route->path->[$_->[&StrassenNetz::ROUTE_ARRAYINX][0]] }
		@{$args{-routetoname}};
	$obj_type = 'routetoname';
    } else {
	if ($net && $args{-simplify}) {
	    my $max_waypoints = $args{-maxwaypoints} || 50;
	    @path = $route->path_list_max($net, $max_waypoints);
	} else {
	    @path = $route->path_list;
	}
	$obj_type = 'route';
    }

    my $n = 0;
    foreach my $xy (@path) {
	my $xy_string = join ",", @$xy;
	my($polar_x, $polar_y) = $obj->standard2map(@$xy);
	my($lat,$long) = ($polar_y, $polar_x);
#XXX del: (after testing!)
#	my($lat,$long) = convert_lat_long_to_gpsman($polar_y, $polar_x);
#XXX del: (after testing!)
#  	my $NS = $polar_y > 0 ? "N" : do { $polar_y = -$polar_y; "S" };
#  	my $EW = $polar_x > 0 ? "E" : do { $polar_x = -$polar_x; "W" };
#  	my $ns_deg = int($polar_y);
#  	my $ew_deg = int($polar_x);
#  	my $ns_min = ($polar_y-$ns_deg)*60;
#  	my $ew_min = ($polar_x-$ew_deg)*60;
#  	my $ns_sec = ($ns_min-int($ns_min))*60;
#  	my $ew_sec = ($ew_min-int($ew_min))*60;
#  	$ns_min = int($ns_min);
#  	$ew_min = int($ew_min);

	# create comment and point number
	my $comment = "$now ";
	my $point_number;
	if ($str && exists $crossings{$xy_string}) {
	    my $short_crossing;

	    my @cross_streets = @{ $crossings{$xy_string} };

	    if ($obj_type eq 'routetoname') {
		my $main_street = $args{-routetoname}->[$n][&StrassenNetz::ROUTE_NAME];
		# test for simplify_route_to_name output:
		if (ref $main_street eq 'ARRAY') {
		    $main_street = $main_street->[0];
		}
		@cross_streets =
		    map  { $_->[0] }
		    sort { $b->[1] <=> $a->[1] }
		    map  { [$_, $_ eq $main_street ? 100 : 0 ] }
			@cross_streets;
	    }

	    # try to shorten street names
	    my $level = 0;
	    while($level <= 3) {
		$short_crossing = join(" ", map { s/\s+\(.*\)\s*$//; Strasse::short($_, $level) } @cross_streets);
		$short_crossing = eliminate_umlauts($short_crossing);
		last
		    if (length($short_crossing) + length($comment) <= MAX_COMMENT);
		$level++;
	    }

	    $comment .= $short_crossing;
	    my $short_name = substr($short_crossing, 0, 5);
	    $point_number = $short_name;
	    if (exists $point_counter{$short_name}) {
		$point_number .= $point_counter{$short_name};
		if ($point_counter{$short_name} ge "0" &&
		    $point_counter{$short_name} le "8") {
		    $point_counter{$short_name}++;
		} elsif ($point_counter{$short_name} eq "9") {
		    $point_counter{$short_name} = "A";
		} else {
		    $point_counter{$short_name} = chr(ord($point_counter{$short_name})+1);
		}
	    } else {
		$point_counter{$short_name} = 0;
	    }
	}
	if (length($comment) > MAX_COMMENT) {
	    $comment = substr($comment, 0, MAX_COMMENT);
	}
	if (!defined $point_number) {
	    $point_number = "T". ($point_counter++);
	}

	my $wpt = GPS::Gpsman::Waypoint->new;
	$wpt->Ident($point_number);
#	$wpt->Ident("");
	$wpt->Comment($comment);
#	$wpt->Comment("20-Jan-2002 14:20:16");
	$wpt->Latitude($lat);
	$wpt->Longitude($long);

	push @data, $wpt;

#  	$s .= sprintf
#  	    "%-3s%-6s          %s%02s %07.4f %s%03d %07.4f %-" . MAX_COMMENT . "s; %d;%d;0\015\012",
#  	    "W",
#  	    $point_number,
#  	    $NS, $ns_deg, $ns_min,
#  	    $EW, $ew_deg, $ew_min,
#  	    $comment,
#  	    DISPLAY_SYMBOL_SMALL,
#  	    SHOW_SYMBOL_AND_COMMENT,
#  	    ;
    } continue {
	$n++;
    }

    $self->Track(\@data);

    $self->as_string;
}

# GpsmanData interface

sub new {
    my $self = {};
    bless $self, shift;

    # some defaults:
    #$self->PositionFormat("DMS");
    $self->change_position_format("DDD");
    $self->TimeOffset(0);
    $self->DatumFormat("WGS 84");

    $self;
}

sub load {
    my($self, $file) = @_;
    open my $F, $file
	or die "Can't open $file: $!";
    local $/ = undef;
    my $buf = <$F>;
    close $F;
    $self->parse($buf);
    $self->File($file);
    1;
}

sub change_position_format {
    my($self, $pos_format) = @_;
    if ($pos_format eq 'UTM/UPS') {
	require Karte::UTM;
    }
    my $converter = _get_converter($pos_format, "DDD");
    $self->CurrentConverter($converter);
    $self->PositionFormat($pos_format);
}

sub parse_and_set_coordinate {
    my($self, $obj, $f_ref, $f_i_ref) = @_;

    my $position_format = $self->PositionFormat;
    my($parsed_lat, $parsed_long);
    my($lat, $long);
    if (defined $position_format && $position_format eq 'UTM/UPS') {
	# XXX no ParsedLongitude/Latitude support for UTM/UPS yet
	my($ze,$zn,$x,$y) = @{$f_ref}[$$f_i_ref .. $$f_i_ref+3];
	$$f_i_ref += 4;
	($lat, $long) = Karte::UTM::UTMToDegrees($ze,$zn,$x,$y,$self->DatumFormat);
	$lat  *= -1 if $lat < 0;
	$long *= -1 if $long < 0;
    } else {
	$parsed_lat = $lat  = $f_ref->[$$f_i_ref++];
	$parsed_long = $long = $f_ref->[$$f_i_ref++];
	my $converter = $self->CurrentConverter;
	$lat  = $converter->($lat);
	$long = $converter->($long);
    }
    $obj->Latitude($lat);
    $obj->Longitude($long);
    $obj->ParsedLatitude($parsed_lat);
    $obj->ParsedLongitude($parsed_long);
}

sub _is_datetime {
    my($self, $datetime) = @_;
    return 1 if $datetime =~ /^(\d{4})-(\d{2})-(\d{2})\s+(\d{1,2}):(\d{2}):(\d{2})/;
    return 1 if $datetime =~ /^(\d{1,2})-([^-]{3})-(\d{4})\s+(\d{1,2}):(\d{2}):(\d{2})/;
    return 0;
}

# argument: line in $_
# return value: Waypoint object
sub parse_waypoint_line {
    my $self = shift;
    my @f = split /\t/;
    my $wpt = GPS::Gpsman::Waypoint->new;
    my $f_i = 0;
    $wpt->Ident($f[$f_i++]);
    $wpt->Comment($f[$f_i++]);

    if ($self->_is_datetime($f[$f_i])) {
	$wpt->DateTime($f[$f_i++]);
    }

    $self->parse_and_set_coordinate($wpt, \@f, \$f_i);

    if ($#f >= $f_i) {
	for (@f[$f_i .. $#f]) {
	    if (/^alt=(.*)/) {
		$wpt->Altitude($1);
	    } elsif (/^symbol=(.*)/) {
		$wpt->Symbol($1);
	    } elsif (/^dispopt=(.*)/) {
		$wpt->DisplayOpt($1);
	    } else {
		# XXX maybe parse these into HiddenAttributes?
		if ($^W) {
		    if (/^GD108:(class|colour|attrs|depth|state|country)=/) {
			# no warning
		    } elsif (/^GD109:(dtyp|class|colour|attrs|depth|state|country|ete)=/) {
			# also no warning
		    } elsif (/^GD110:(attrs|cat|class|colour|country|depth|dtyp|ete|state|temp|time)=/) {
			# also no warning
		    } else {
			warn "Ignore $_";
		    }
		}
	    }
	}
    }
    $wpt;
}

# argument: line in $_
# return value: Waypoint object
sub parse_track_line {
    my $self = shift;
    my @f = split /\t/;
    my $wpt = GPS::Gpsman::Waypoint->new;
    $wpt->Ident($f[0]);
    $wpt->Comment($f[1]);

    my $f_i = 2;
    $self->parse_and_set_coordinate($wpt, \@f, \$f_i);

    # This are the only diffs to TYPE_WAYPOINT:
    # The "~" and "?" thingies are a private extension
    my($acc,$alt) = $f[4] =~ /^([~?]*)(.*)/;
    $wpt->Accuracy(length($acc)); # 0=accurate, 2=very inaccurate
    $wpt->Altitude($alt);
    $wpt;
}

sub parse_route_line {
    my $self = shift;
    my @f = split /\t/;
    my $wpt = GPS::Gpsman::Waypoint->new;
    $wpt->Ident($f[0]);
    $wpt->Comment($f[1]);

    my $f_i = 2;
    $self->parse_and_set_coordinate($wpt, \@f, \$f_i);

    # no altitude here
    $wpt;
}

sub parse_group_line {
    # nothing..., return empty list
}

my $current_track_name; # to be used in track segments
sub parse {
    my($self, $buf, %args) = @_;
    my $multiple = delete $args{-multiple};
    my $beginref = delete $args{-begin};
    if (keys %args) {
	die "Unhandled arguments: " . join " ", %args;
    }
    my $lineinfo = $self->LineInfo;
    my $type = TYPE_UNKNOWN;
    my $parse_method;
    my @lines = split /\n/, $buf;
    my $i = $beginref ? $$beginref : 0;

    my %parse =
	(TYPE_WAYPOINT() => 'parse_waypoint_line',
	 TYPE_TRACK()    => 'parse_track_line',
	 TYPE_ROUTE()    => 'parse_route_line',
	 TYPE_GROUP()    => 'parse_group_line',
	);

    my @data;

    while($i <= $#lines) {
	local $_ = $lines[$i];
	if (/^%!(.*?)=(.*)/) { # special directive in wpt files
	    my($key, $val) = ($1, $2);
	    if (!$self->TrackAttrs) { $self->TrackAttrs({}) }
	    $self->TrackAttrs->{$1} = $2;
	}
	next if /^%/; # comment
	next if /^\s*$/;
	if (defined $parse_method && !/^!/) {
	    push @data, $self->$parse_method();
	    if ($type == TYPE_TRACK && $lineinfo) { # XXX other types?
		$lineinfo->add_wpt_lineinfo($data[-1], $i); # XXX too much assumptions?
	    }
	} elsif (/^!Format:\s+(\S+)\s+(\S+)\s+(.*)$/) {
	    my($pos_format, $time_offset, $datum_format) = ($1, $2, $3);
	    $self->change_position_format($pos_format);
	    $self->TimeOffset($time_offset);
	    $self->DatumFormat($datum_format);
	} elsif (/^!Position:\s+(\S+)$/) {
	    my $pos_format = $1;
	    $self->change_position_format($pos_format);
	} elsif (/^!NB/) {
	    # overread text remarks
	    while($i <= $#lines) {
		last if $lines[$i] eq '';
		$i++;
	    }
	} elsif (/^!/) {
	    if (/^!RS:/) {
		# currently ignored
		next;
	    }
	    if ($multiple && @data) {
		# we already have data for one track/route/...
		if ($beginref) {
		    $$beginref = $i;
		}
		last;
	    }
	    if (/^!W:/) {
		$self->Type(TYPE_WAYPOINT);
		$type = TYPE_WAYPOINT; # performance
		$parse_method = $parse{$type};
	    } elsif (/^!(TS?:.*)/) {
		my @l = split /\t/, $1;
		if (/^!T:/) {
		    $current_track_name = $l[1];
		    $self->Name($l[1]);
		    if ($lineinfo) {
			$lineinfo->add_chunk_lineinfo($self, $i);
		    }
		    $self->IsTrackSegment(0);
		} else {
		    if (defined $l[1] && $l[1] ne "") {
			warn "Should not happen: TS with name";
		    }
		    $self->Name(undef);
		    $self->IsTrackSegment(1);
		}
		if (@l > 2) {
		    my %attr;
		    if (eval { require Tie::IxHash; 1 }) {
			tie %attr, 'Tie::IxHash';
		    }
		    for my $l_i (2 .. $#l) {
			my($key,$val) = split /=/, $l[$l_i], 2;
			$attr{$key} = $val;
		    }
		    $self->TrackAttrs(\%attr);
		} else {
		    $self->TrackAttrs({});
		}
		$self->Type(TYPE_TRACK);
		$type = TYPE_TRACK;
		$parse_method = $parse{$type};
	    } elsif (/^!(R:.*)/) {
		my @l = split /\t/, $1;
		$self->Name($l[1]);
		# XXX safe more attribs
		$self->Type(TYPE_ROUTE);
		$type = TYPE_ROUTE;
		$parse_method = $parse{$type};
	    } elsif (/^!G:/) {
		$self->Type(TYPE_GROUP);
		$type = TYPE_GROUP;
		$parse_method = $parse{$type};
	    } elsif (/^!GW/) {
		# ignore
	    } else {
		# ignore
	    }
	} else {
	    die "Unrecognized $_";
	}
    } continue {
	$i++;
    }

    if ($type == TYPE_WAYPOINT) {
	$self->Waypoints(\@data);
    } elsif ($type == TYPE_TRACK) {
	$self->Track(\@data);
    } elsif ($type == TYPE_ROUTE) {
	$self->Track(\@data); # XXX or Route???
    }
}

# XXX only waypoints and tracks
# XXX still necessary???
sub convert_all {
    warn "convert_all is deprecated...";
    return;

    my($self, $to_format) = @_;
    my $converter = _get_converter($self->PositionFormat, $to_format);
    foreach my $wpt (@{ $self->Points }) {
	$wpt->Longitude($converter->($wpt->Longitude));
	$wpt->Latitude($converter->($wpt->Latitude));
    }

    $self->PositionFormat($to_format);
}

sub _get_converter {
    my($from,$to) = @_;
    $from =~ s/[^A-Za-z]/_/g;
    $to   =~ s/[^A-Za-z]/_/g;
    my $sub = 'convert_' . $from . '_to_' . $to;
    #warn $sub;
    my $converter = eval '\&'.$sub;
    if (ref $converter ne 'CODE') {
	die "Subroutine $sub is not defined";
    }
    $converter;
}

sub convert_DMM_to_DDD {
    my($in) = @_;
    if ($in =~ /^([NESW]?)(\d+)\s(\d+\.?\d*)$/) {
	my($dir,$deg,$min) = ($1,$2,$3);
	if (defined $dir && $dir =~ /[SW]/) {
	    $deg *= -1;
	}
	$deg += $min/60;
	return $deg;
    } else {
	warn "Can't parse <$in>, should be in `N52 30.8' (DMM) format";
    }
}

sub convert_DMS_to_DDD {
    my($in) = @_;
    if ($in =~ /^([NESW]?)(\d+)\s(\d+)\s(\d+\.?\d*)$/) {
	my($dir,$deg,$min,$sec) = ($1,$2,$3,$4);
	if (defined $dir && $dir =~ /[SW]/) {
	    $deg *= -1;
	}
	$deg += $min/60 + $sec/3600;
	return $deg;
    } else {
	warn "Can't parse <$in>, should be in `N52 30 23.8' (DMS) format";
    }
}

# set sign for S and W
sub convert_DDD_to_DDD {
    my($in) = @_;
    if ($in =~ /^([NESW]?)(\d+\.?\d*)$/) {
	my($dir,$ddd) = ($1,$2);
	if (defined $dir && $dir =~ /[SW]/) {
	    $ddd *= -1;
	}
	return $ddd;
    } else {
	warn "Can't parse <$in>, should be in `N52.49857' (DDD) format";
    }
}

# This is a little bit hackish --- the conversion job was already done in parse_and_set_coordinate
sub convert_UTM_UPS_to_DDD {
    $_[0];
}

sub convert_lat_long_to_gpsman_DMS {
    my($polar_y, $polar_x) = @_;
    my $NS = $polar_y > 0 ? "N" : do { $polar_y = -$polar_y; "S" };
    my $EW = $polar_x > 0 ? "E" : do { $polar_x = -$polar_x; "W" };
    my $ns_deg = int($polar_y);
    my $ew_deg = int($polar_x);
    my $ns_min = ($polar_y-$ns_deg)*60;
    my $ew_min = ($polar_x-$ew_deg)*60;
    my $ns_sec = ($ns_min-int($ns_min))*60;
    my $ew_sec = ($ew_min-int($ew_min))*60;
    my $ns_csec = ($ns_sec-int($ns_sec))*10;
    my $ew_csec = ($ew_sec-int($ew_sec))*10;
    $ns_min = int($ns_min);
    $ew_min = int($ew_min);
    $ns_sec = int($ns_sec);
    $ew_sec = int($ew_sec);
    (sprintf("%s%d %02d %02d.%01d", $NS, $ns_deg, $ns_min, $ns_sec, $ns_csec), # latitude
     sprintf("%s%d %02d %02d.%01d", $EW, $ew_deg, $ew_min, $ew_sec, $ew_csec), # longitude
    );
}
*convert_lat_long_to_gpsman = \&convert_lat_long_to_gpsman_DMS; # for compat
*convert_lat_long_to_gpsman = *convert_lat_long_to_gpsman if 0; # cease -w

# XXX only waypoints --- tracks usually have no idents
sub create_cache {
    my $self = shift;
    require DB_File;
    require Fcntl;

    my $cache_file = $self->File . ".cache";
    if (-e $cache_file) {
	unlink $cache_file;
    }
    tie my %db, 'DB_File', $cache_file, Fcntl::O_RDWR()|Fcntl::O_CREAT(), 0644
	or die "Can't tie to $cache_file: $!";
    foreach my $wpt (@{ $self->Waypoints }) {
	my $coord = $wpt->Longitude.",".$wpt->Latitude;
	$db{$wpt->Ident} = $coord;
    }
    untie %db;
}

sub push_waypoint {
    my($self, $wpt) = @_;
    if (!$self->Track) {
	if (!defined $self->Type) {
	    $self->Type(TYPE_TRACK);
	}
	$self->Track([]);
    }
    push @{ $self->Track }, $wpt;
}

sub make_hash {
    my($self, $type) = @_;
    my %h;
    if ($type =~ /^waypoints$/i) {
	foreach my $wpt (@{ $self->Waypoints }) {
	    $h{$wpt->Ident} = $wpt;
	}
	$self->WaypointsHash(\%h);
    } else {
	die "$type NYI";
    }
    \%h;
}

sub sort_waypoints_by_time {
    my($self) = @_;
    @{ $self->Waypoints } = $self->get_sorted_waypoints_by_time;
}

sub get_sorted_waypoints_by_time {
    my($self) = @_;
    map {
	$_->[1]
    } sort {
	$a->[0] <=> $b->[0]
    } map {
	[$_->Comment_to_unixtime($self), $_]
    } @{ $self->Waypoints };
}

# XXX only waypoints/tracks, no ident clash check
sub merge {
    my($self, $another, %args) = @_;
    die "Types do not match"
	if ($self->Type ne $another->Type);
    die "PositionFormats do not match"
	if ($self->PositionFormat ne $another->PositionFormat);
    die "DatumFormats do not match"
	if ($self->DatumFormat ne $another->DatumFormat);
    if ($another->Type == TYPE_WAYPOINT || $another->Type == TYPE_TRACK || $another->Type == TYPE_ROUTE) {
	my $arrref = ($self->Type == TYPE_WAYPOINT ? $self->{Waypoints} : $self->{Track} );
	foreach my $wpt ($self->Type == TYPE_WAYPOINT
			 ? @{ $another->Waypoints }
			 : @{ $another->Track }) {
	    my $new_wpt = clone($wpt);
	    if (defined $args{-addtoken}) {
		$new_wpt->Ident($args{-addtoken} . $new_wpt->Ident);
	    }
	    push @$arrref, $new_wpt;
	}
    } else {
	die "NYI";
    }
}

sub write {
    my($self, $file) = @_;
    open my $F, "> $file"
	or die "Can't write to $file: $!";
    print $F $self->as_string;
    close $F
	or die "Error while writing to $file: $!";
}

sub header_as_string {
    my $self = shift;
    require POSIX;
    # deliberately not following the exact date/time format used in gpsman:
    # - use month number instead of abbreviated name
    # - use timezone offset instead of name
    my $datetime = POSIX::strftime("%Y-%m-%d %H:%M:%S %z", localtime);
    my $s = "% Written by $0 [" . __PACKAGE__ . "] $datetime\n\n";
    # XXX:
    $s .= "!Format: " . join(" ",
			     ($self->PositionFormat || 'DDD'),
			     $self->TimeOffset,
			     $self->DatumFormat) . "
!Creation: no

";
    $s;
}

sub _track_attrs_as_string {
    my($self) = @_;
    my $s = "";
    if ($self->TrackAttrs) {
	my $ta = $self->TrackAttrs;
	while(my($key, $val) = each %$ta) {
	    $s .= "\t$key=$val";
	}
    }
    $s;
}

sub _track_attrs_as_special_directives {
    my($self) = @_;
    my $s = "";
    if ($self->TrackAttrs) {
	my $ta = $self->TrackAttrs;
	while(my($key, $val) = each %$ta) {
	    $s .= "%!$key=$val\n";
	}
    }
    $s;
}

# XXX not complete, only waypoints/tracks
sub body_as_string {
    my $self = shift;
    my $s = "";
    if ($self->Type == TYPE_WAYPOINT) {
	my $track_attrs = $self->_track_attrs_as_special_directives;
	if (length $track_attrs) {
	    $s .= $track_attrs . "\n";
	}
	$s .= "!W:\n";
	foreach my $wpt (@{ $self->Waypoints }) {
	    $s .= join("\t",
		       $wpt->Ident,
		       (defined $wpt->Comment ? $wpt->Comment : ""),
		       $wpt->_coord_output($self),
		       (defined $wpt->Altitude ? "alt=".$wpt->Altitude : ()),
		       (defined $wpt->Symbol ? "symbol=".$wpt->Symbol : ()),
		       (defined $wpt->DisplayOpt ? "dispopt=".$wpt->DisplayOpt : ()),
		       (defined $wpt->HiddenAttributes ? $wpt->DumpHiddenAttributes : ()),
		      )
		. "\n";
	}
    } elsif ($self->Type == TYPE_TRACK) {
	if ($self->IsTrackSegment) {
	    $s .= "!TS:\n";
	} else {
	    $s .= "!T:";
	    if (defined $self->Name) {
		$s .= "\t" . $self->Name;
	    }
	    $s .= $self->_track_attrs_as_string . "\n";
	}
	foreach my $wpt (@{ $self->Track }) {
	    $s .= join("\t",
		       (defined $wpt->Ident ? $wpt->Ident : ""),
		       (defined $wpt->DateTime ? $wpt->DateTime :
			defined $wpt->Comment ? $wpt->Comment : ""),
		       $wpt->_coord_output($self),
		       (defined $wpt->Altitude ? ($wpt->Accuracy ? '~'x$wpt->Accuracy : '') . $wpt->Altitude : ""),
		       (defined $wpt->HiddenAttributes ? $wpt->DumpHiddenAttributes : ()),
		      )
		. "\n";
	}
    } elsif ($self->Type == TYPE_ROUTE) {
	$s .= "!R:";
	if (defined $self->Name) {
	    $s .= "\t" . $self->Name;
	}
	$s .= $self->_track_attrs_as_string . "\n";
	foreach my $wpt (@{ $self->Track }) {
	    $s .= join("\t",
		       $wpt->Ident,
		       (defined $wpt->Comment ? $wpt->Comment : ""),
		       $wpt->_coord_output($self),
		       (defined $wpt->Symbol ? "symbol=".$wpt->Symbol : ()),
		       (defined $wpt->HiddenAttributes ? $wpt->DumpHiddenAttributes : ()),
		      )
		. "\n";
	}
    } else {
	die "NYI!";
    }
    $s;
}

sub as_string {
    my $self = shift;
    my $s = $self->header_as_string;
    $s .= $self->body_as_string;
    $s;
}

# return always the points reference, regardless of Waypoints, Track, Route...
sub Points {
    my $self = shift;
    if ($self->Type eq TYPE_WAYPOINT) {
	$self->Waypoints;
    } elsif ($self->Type eq TYPE_TRACK || $self->Type eq TYPE_ROUTE) {
	$self->Track;
    } else {
	warn "Can't determine type in Points method (neither waypoint nor track, type is <" . $self->Type . ">)";
	[];
    }
}

{
    my %number_to_monthabbrev =
	(
	  1 => 'Jan',
	  2 => 'Feb',
	  3 => 'Mar',
	  4 => 'Apr',
	  5 => 'May',
	  6 => 'Jun',
	  7 => 'Jul',
	  8 => 'Aug',
	  9 => 'Sep',
	 10 => 'Oct',
	 11 => 'Nov',
	 12 => 'Dec',
	);

    sub _unixtime_to_gpsmantime {
	my($epoch, $timeoffset) = @_;
	if (defined $timeoffset) {
	    $epoch += $timeoffset*3600;
	}
	my($S,$M,$H,$d,$m,$y) = gmtime $epoch;
	$m++;
	$y+=1900;
	sprintf "%02d-%s-%04d %02d:%02d:%02d", $d, $number_to_monthabbrev{$m}, $y, $H, $M, $S;
    }
}

# REPO BEGIN
# REPO NAME monthabbrev_number /home/e/eserte/src/repository 
# REPO MD5 5dc25284d4ffb9a61c486e35e84f0662

sub monthabbrev_number {
    my $mon = shift;
    +{'Jan' => 1,
      'JAN' => 1,
      'Feb' => 2,
      'FEB' => 2,
      'Mar' => 3,
      'MAR' => 3,
      'Apr' => 4,
      'APR' => 4,
      'May' => 5,
      'MAY' => 5,
      'Jun' => 6,
      'JUN' => 6,
      'Jul' => 7,
      'JUL' => 7,
      'Aug' => 8,
      'AUG' => 8,
      'Sep' => 9,
      'SEP' => 9,
      'Oct' => 10,
      'OCT' => 10,
      'Nov' => 11,
      'NOV' => 11,
      'Dec' => 12,
      'DEC' => 12,
     }->{$mon};
}
# REPO END

# REPO BEGIN
# REPO NAME clone /home/e/eserte/src/repository 
# REPO MD5 038173e70538a6c17d85319189d4e9d8

sub clone {
    my $orig = shift;
    my $clone;
    eval {
	require Data::Dumper;
        my $dd = new Data::Dumper([$orig], ['clone']);
        $dd->Indent(0);
        $dd->Purity(1);
        my $evals = $dd->Dumpxs;
        eval $evals;
    };
    die $@ if $@;
    $clone;
}
# REPO END

sub _eliminate_illegal_characters {
    my $s = shift;
    $s = uc($s);
    $s =~ s/[^-A-Z0-9 ]/ /g;
    $s;
}

# in m/s
sub wpt_velocity {
    my($self, $wpt0, $wpt1) = @_;
    my $time0 = $wpt0->Comment_to_unixtime($self);
    my $time1 = $wpt1->Comment_to_unixtime($self);
    my $delta_time = abs($time1 - $time0);
    return undef if !$delta_time; # should never happen...
    my $delta_dist = $self->wpt_dist($wpt0, $wpt1);
    $delta_dist / $delta_time;
}

# in m
sub wpt_dist {
    my($self, $wpt0, $wpt1) = @_;
    require Math::Trig;
    my $lon0 = Math::Trig::deg2rad($wpt0->Longitude);
    my $lat0 = Math::Trig::deg2rad($wpt0->Latitude);
    my $lon1 = Math::Trig::deg2rad($wpt1->Longitude);
    my $lat1 = Math::Trig::deg2rad($wpt1->Latitude);
    Math::Trig::great_circle_distance($lon0, Math::Trig::pi()/2 - $lat0,
				      $lon1, Math::Trig::pi()/2 - $lat1, 6372795);
}

package GPS::GpsmanMultiData;
# holds multiple GPS tracks/routes

BEGIN {
    # This used Class::Accessor, but unfortunately I don't want to
    # depend on a non-core module.
    no strict 'refs';
    for (qw(File)) {
	my $acc = $_;
	*{$acc} = sub {
	    my $self = shift;
	    if (@_) {
		$self->{$acc} = $_[0];
	    }
	    $self->{$acc};
	};
    }
}

# predeclare
{ package GPS::GpsmanData::LineInfo; }

sub new {
    my($class, %args) = @_;
    my $editable = delete $args{-editable};
    die "Unhandled arguments: " . join(" ", %args) if %args;
    my $self = { Chunks => [] };
    if ($editable) {
	require GPS::GpsmanData::DirectEdit;
	$self->{LineInfo} = GPS::GpsmanData::LineInfo::->new;
    }
    bless $self, $class;
    $self;
}

sub load {
    my($self, $file) = @_;
    open my $F, $file
	or die "Can't open $file: $!";
    local $/ = undef;
    my $buf = <$F>;
    close $F;

    if ($buf =~ m{^\x1f\x8b}) {
	$self->_gunzip(\$buf);
    }

    $self->parse($buf);
    $self->File($file);
    1;
}

sub _gunzip {
    my($self, $bufref) = @_;
    my $out;
    require IO::Uncompress::Gunzip;
    IO::Uncompress::Gunzip::gunzip($bufref => \$out)
        or do {
	    no warnings 'once';
	    die "Cannot gunzip file: " . $IO::Uncompress::Gunzip::GunzipError;
	};
    $$bufref = $out;
}

sub reload {
    my($self) = @_;
    my $file = $self->File;
    die "Cannot reload, no File available"
	if !defined $file;
    $self->{Chunks} = [];
    if ($self->{LineInfo}) {
	$self->{LineInfo} = GPS::GpsmanData::LineInfo::->new;
    }
    $self->load($file);
}

sub parse {
    my($self, $buf) = @_;
    my $begin = 0;
    my $old_gps_o;
    while(1) {
	my $gps_o = GPS::GpsmanData->new;
	if ($old_gps_o) {
	    # "sticky" attributes
	    for my $member (qw(DatumFormat TimeOffset PositionFormat Creation CurrentConverter)) {
		$gps_o->$member($old_gps_o->$member());
	    }
	}
	$gps_o->LineInfo($self->{LineInfo}) if $self->{LineInfo};
	my $old_begin = $begin;
	$gps_o->parse($buf, -multiple => 1, -begin => \$begin);
	push @{ $self->{Chunks} }, $gps_o;
	if ($old_begin == $begin) {
	    # last track/route/... read
	    last;
	}
	$old_gps_o = $gps_o;
    }
}

sub Chunks { shift->{Chunks} }

sub LineInfo { shift->{LineInfo} }

sub convert_to_route {
    my($self, $file, %args) = @_;

    $self = __PACKAGE__->new if !ref $self;
    $self->load($file);

    my @res;
    for my $chunk (@{ $self->Chunks }) {
	if ($chunk->Type eq $chunk->TYPE_TRACK ||
	    $chunk->Type eq $chunk->TYPE_ROUTE
	   ) {
	    push @res, $chunk->do_convert_to_route(%args);
	}
    }
    @res;
}

use constant GPXX_NS => 'http://www.garmin.com/xmlschemas/GpxExtensions/v3';

# Options:
#   symtocmt => $bool: hack to put symbol name into comment, for gpx
#                      renderers not dealing the sym tag (e.g. merkaartor)
#   skipcmt => $bool: hack to skip creation of comment elements
#   autoskipcmt => $bool: skip creation of comment elements if recognized as
#                         a date/time element; by default set to a true value
sub as_gpx {
    my($self, %args) = @_;

    my $sym_to_cmt = delete $args{symtocmt};
    my $skip_cmt = $sym_to_cmt ? 1 : delete $args{skipcmt};
    my $auto_skip_cmt = exists $args{autoskipcmt} ? delete $args{autoskipcmt} : 1;
    my $do_gpxx = exists $args{gpxx} ? delete $args{gpxx} : 1;
    die "Unhandled arguments: " . join(" ", %args) if %args;

    my @std_wpt_as_gpx_args = (symtocmt => $sym_to_cmt, skipcmt => $skip_cmt, autoskipcmt => $auto_skip_cmt);

    require GPS::GpsmanData::GarminGPX;
    require XML::LibXML;
    my $dom = XML::LibXML::Document->new('1.0', 'utf-8');
    my $gpx = $dom->createElement("gpx");
    $dom->setDocumentElement($gpx);
    $gpx->setAttribute("version", "1.1");
    $gpx->setNamespace("http://www.w3.org/2001/XMLSchema-instance","xsi");
    if ($do_gpxx) {
	$gpx->setNamespace(GPXX_NS,'gpxx');
    }
    $gpx->setNamespace("http://www.topografix.com/GPX/1/1"); # last namespace is the default one
    $gpx->setAttribute("xsi:schemaLocation",
		       "http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd" .
		       ($do_gpxx ? ' ' . GPXX_NS . ' http://www8.garmin.com/xmlschemas/GpxExtensionsv3.xsd' : '')
		      );

    my $creator;
    my $current_trk;
    for my $chunk (@{ $self->Chunks }) {

	my $add_name = sub {
	    my $elem = shift;
	    my $name = $chunk->Name;
	    if (defined $name && length $name) {
		my $namexml = $elem->addNewChild(undef, 'name');
		$namexml->appendText($name);
	    }
	};

	my $trk_attrs = $chunk->TrackAttrs;
	if ($trk_attrs->{'srt:device'}) {
	    $creator = $trk_attrs->{'srt:device'};
	}
	if ($trk_attrs->{'srt:garmin_userdef_symbols_set'}) {
	    push @std_wpt_as_gpx_args, garmin_userdef_symbols_set => $trk_attrs->{'srt:garmin_userdef_symbols_set'};
	}

	if ($chunk->Type eq $chunk->TYPE_WAYPOINT) {
	    # No name handling for waypoints, waypoints have their own idents
	    for my $wpt (@{ $chunk->Waypoints }) {
		my $wptxml = $gpx->addNewChild(undef, "wpt");
		$wpt->as_gpx($wptxml, $chunk, @std_wpt_as_gpx_args);
	    }
	} elsif ($chunk->Type eq $chunk->TYPE_TRACK) {
	    if ($chunk->IsTrackSegment) {
		if (!$current_trk) {
		    die "Invalid: track segment without a track";
		}
	    } else {
		my $trkxml = $gpx->addNewChild(undef, "trk");
		$add_name->($trkxml);
		if ($trk_attrs) {
		    if ($do_gpxx) {
			if ($trk_attrs->{colour}) {
			    my $garmin_color = GPS::GpsmanData::GarminGPX::gpsman_to_garmin_color($trk_attrs->{colour});
			    my $extensionsxml = $trkxml->addNewChild(undef, 'extensions');
			    my $trackextensionxml = $extensionsxml->addNewChild(GPXX_NS, 'TrackExtension');
			    my $displaycolorxml = $trackextensionxml->addNewChild(GPXX_NS, 'DisplayColor');
			    $displaycolorxml->appendText($garmin_color);
			}
		    }
		}
		$current_trk = $trkxml;
	    }
	    my $trksegxml = $current_trk->addNewChild(undef, "trkseg");
	    for my $wpt (@{ $chunk->Track }) {
		my $trkptxml = $trksegxml->addNewChild(undef, "trkpt");
		$wpt->as_gpx($trkptxml, $chunk, @std_wpt_as_gpx_args);
	    }
	} elsif ($chunk->Type eq $chunk->TYPE_ROUTE) {
	    my $rtexml = $gpx->addNewChild(undef, 'rte');
	    $add_name->($rtexml);
	    for my $wpt (@{ $chunk->Track }) {
		my $rteptxml = $rtexml->addNewChild(undef, 'rtept');
		$wpt->as_gpx($rteptxml, $chunk, @std_wpt_as_gpx_args);
	    }
	}
    }

    if (!defined $creator) {
	$creator = "GPS::GpsmanData $GPS::GpsmanData::VERSION - http://www.bbbike.de";
    }
    $gpx->setAttribute("creator", $creator);

    require Encode;
    Encode::encode("utf-8", $dom->toString);
}

sub has_track {
    my($self) = @_;
    for my $chunk (@{ $self->Chunks }) {
	return 1 if ($chunk->Type eq $chunk->TYPE_TRACK);
    }
    0;
}

sub has_route {
    my($self) = @_;
    for my $chunk (@{ $self->Chunks }) {
	return 1 if ($chunk->Type eq $chunk->TYPE_ROUTE);
    }
    0;
}

sub push_chunk {
    my($self, $chunk) = @_;
    if (!$self->Chunks) {
	$self->Chunks([]);
    }
    push @{ $self->Chunks }, $chunk;
}

sub as_string {
    my $self = shift;
    if (!@{ $self->Chunks || [] }) {
	die "Cannot write as string, no chunks in object";
    }
    my $s = $self->Chunks->[0]->header_as_string;
    for my $chunk (@{ $self->Chunks }) {
	$s .= $chunk->body_as_string;
    }
    $s;
}

sub write {
    my($self, $file) = @_;
    open my $F, "> $file"
	or die "Can't write to $file: $!";
    print $F $self->as_string;
    close $F
	or die "Error while writing to $file: $!";
}

sub wpt_dist { shift->GPS::GpsmanData::wpt_dist(@_) }

sub flat_track {
    my($self) = @_;
    my @track;
    for my $chunk (@{ $self->Chunks }) {
	for my $wpt (@{ $chunk->Track || [] }) {
	    push @track, $wpt;
	}
    }
    @track;
}

1;

__END__
