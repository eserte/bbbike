# -*- perl -*-

#
# $Id: GpsmanData.pm,v 1.23 2003/06/02 23:24:35 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
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
	    Track
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

use vars qw($VERSION);
$VERSION = sprintf("%d.%03d", q$Revision: 1.23 $ =~ /(\d+)\.(\d+)/);

use constant TYPE_WAYPOINT => 0;
use constant TYPE_TRACK    => 1;

use GPS::Util; # for eliminate_umlauts

use Class::Struct;
struct('GPS::Gpsman::Waypoint' =>
       [map {($_ => "\$")}
	qw(Ident Comment Latitude Longitude Altitude NewTrack Symbol)
       ]
      );
{
    package GPS::Gpsman::Waypoint;

    sub Comment_to_unixtime {
	my $wpt = shift;
	if ($wpt->Comment =~ /^(\d{1,2})-([^-]{3})-(\d{4})\s+(\d{1,2}):(\d{2}):(\d{2})/) {
	    my($d,$m_name,$y, $H,$M,$S) = ($1,$2,$3,$4,$5,$6);
	    my $m = GPS::GpsmanData::monthabbrev_number($m_name);
	    return undef if !defined $m;
	    require Time::Local;
	    Time::Local::timelocal($S,$M,$H,$d,$m-1,$y-1900);
	} else {
	    undef;
	}
    }

}

# for GPS.pm
sub check {
    my($self, $file, %args) = @_;
    open(F, $file) or die "Can't open file $file: $!";
    my $max_lines = 10;
    my $check = 0;
    while(<F>) {
	next if /^%/ || /^\s*$/;
	if (/!Format: (DMS|DDD) 1 (WGS 84)/) {
	    if (ref $self) {
		$self->PositionFormat($1);
		$self->DatumFormat($2);
	    }
	    $check = 1;
	    last;
	}
	$max_lines--;
	last if ($max_lines <= 0);
    }
    close F;
    $check;
}

sub convert_to_route {
    my($self, $file, %args) = @_;

    $self = __PACKAGE__->new if !ref $self;
    $self->load($file);

    require Karte::Polar;
    my $obj = $Karte::Polar::obj;

    my @res;

    my $converter = _get_converter($self->PositionFormat, "DDD");
    foreach my $wpt (@{ $self->Track }) {
	my($x,$y) = $obj->map2standard(map { $converter->($_) }
				           $wpt->Longitude, $wpt->Latitude);
	if (!@res || ($x != $res[-1]->[0] ||
		      $y != $res[-1]->[1])) {
	    push @res, [$x, $y];
	}
    }

    @res;
}

# XXX maybe better use a route instead of a tracklog
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
	    @path = $route->path_list_max($net, 20);
	} else {
	    @path = $route->path_list;
	}
	$obj_type = 'route';
    }

    my $n = 0;
    foreach my $xy (@path) {
	my $xy_string = join ",", @$xy;
	my($polar_x, $polar_y) = $obj->standard2map(@$xy);
	my($lat,$long) = convert_lat_long_to_gpsman($polar_y, $polar_x);
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
#	$wpt->Ident($point_number);
	$wpt->Ident("");
#	$wpt->Comment($comment);
	$wpt->Comment("20-Jan-2002 14:20:16");
#XXX del:
#  	$wpt->Latitude(sprintf "%s%d %02d %04.1f", $NS, $ns_deg, $ns_min, $ns_sec);
#  	$wpt->Longitude(sprintf "%s%d %02d %04.1f", $EW, $ew_deg, $ew_min, $ew_sec);
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
    $self->PositionFormat("DMS");
    $self->DatumFormat("WGS 84");

    $self;
}

sub load {
    my($self, $file) = @_;
    open(F, $file) or die "Can't open $file: $!";
    local $/ = undef;
    my $buf = <F>;
    close F;
    $self->parse($buf);
    $self->File($file);
    1;
}

# argument: line in $_
# return value: Waypoint object
sub parse_waypoint {
    my @f = split /\t/;
    my $wpt = GPS::Gpsman::Waypoint->new;
    $wpt->Ident($f[0]);
    $wpt->Comment($f[1]);
    $wpt->Latitude($f[2]);
    $wpt->Longitude($f[3]);
    if ($#f > 3) {
	for (@f[4 .. $#f]) {
	    if (/^alt=(.*)/) {
		$wpt->Altitude($1);
	    } elsif (/^symbol=(.*)/) {
		$wpt->Symbol($1);
	    } else {
		warn "Ignore $_" if $^W;
	    }
	}
    }
    $wpt;
}

# argument: line in $_
# return value: Waypoint object
sub parse_track {
    my @f = split /\t/;
    my $wpt = GPS::Gpsman::Waypoint->new;
    $wpt->Ident($f[0]);
    $wpt->Comment($f[1]);
    $wpt->Latitude($f[2]);
    $wpt->Longitude($f[3]);
    $wpt->Altitude($f[4]); # this is the only diff to TYPE_WAYPOINT
    $wpt;
}

sub parse {
    my($self, $buf) = @_;
    my $type;
    my @lines = split /\n/, $buf;
    my $i = 0;

    my %parse =
	(TYPE_WAYPOINT() => \&parse_waypoint,
	 TYPE_TRACK()    => \&parse_track,
	);

    my @data;

    while($i <= $#lines) {
	local $_ = $lines[$i];
	next if /^%/; # comment
	next if /^\s*$/;
	if (defined $type) {
	    if (/^!/) {
		# XXX ignore for now
		# XXX for tracks, some kind of signalling a new route should be possible...
	    } else {
		push @data, $parse{$type}->();
	    }
	} elsif (/^!Format:\s+(\S+)\s+(\S+)\s+(.*)$/) {
	    $self->PositionFormat($1);
	    $self->DatumFormat($3);
	} elsif (/^!W:/) {
	    $self->Type(TYPE_WAYPOINT);
	    $type = TYPE_WAYPOINT; # performance
	} elsif (/^!(T:.*)/) {
	    my @l = split /\t/, $1;
	    $self->Name($l[1]);
	    $self->Type(TYPE_TRACK);
	    $type = TYPE_TRACK;
	} elsif (/^!/) {
	    # ignore
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
    }
}

# XXX only waypoints and tracks
sub convert_all {
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
    my $sub = 'convert_' . $from . '_to_' . $to;
    #warn $sub;
    my $converter = eval '\&'.$sub;
    if (ref $converter ne 'CODE') {
	die "Subroutine $sub is not defined";
    }
    $converter;
}

sub convert_DMS_to_DDD {
    my($in) = @_;
    if ($in =~ /^([NESW])(\d+)\s(\d+)\s(\d+\.?\d*)$/) {
	my($dir,$deg,$min,$sec) = ($1,$2,$3,$4);
	if ($dir =~ /[SW]/) {
	    $deg *= -1;
	}
	$deg += $min/60 + $sec/3600;
	return $deg;
    } else {
	warn "Can't parse $in, should be in `N52 30 23.8' format";
    }
}

# set sign for S and W
sub convert_DDD_to_DDD {
    my($in) = @_;
    if ($in =~ /^([NESW])(\d+\.?\d*)$/) {
	my($dir,$ddd) = ($1,$2,$3,$4);
	if ($dir =~ /[SW]/) {
	    $ddd *= -1;
	}
	return $ddd;
    } else {
	warn "Can't parse $in, should be in `N52.49857' format";
    }
}

sub convert_lat_long_to_gpsman {
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

# XXX only waypoints/tracks, no ident clash check
sub merge {
    my($self, $another, %args) = @_;
    die "Types do not match"
	if ($self->Type ne $another->Type);
    die "PositionFormats do not match"
	if ($self->PositionFormat ne $another->PositionFormat);
    die "DatumFormats do not match"
	if ($self->DatumFormat ne $another->DatumFormat);
    if ($another->Type == TYPE_WAYPOINT || $another->Type == TYPE_TRACK) {
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
    open(F, ">$file") or die "Can't write to $file: $!";
    print F $self->as_string;
    close F;
}

# XXX not complete, only waypoints/tracks
sub as_string {
    my $self = shift;
    my $s = "% Written by $0 [" . __PACKAGE__ . "]\n\n";
    # XXX:
    $s .= "!Format: " . $self->PositionFormat . " 1 " . $self->DatumFormat . "
!Creation: no

";
    if ($self->Type == TYPE_WAYPOINT) {
	$s .= "!W:\n";
	foreach my $wpt (@{ $self->Waypoints }) {
	    $s .= join("\t",
		       $wpt->Ident,
		       (defined $wpt->Comment ? $wpt->Comment : ""),
		       $wpt->Latitude, $wpt->Longitude,
		       (defined $wpt->Altitude ? "alt=".$wpt->Altitude : ()),
		       (defined $wpt->Symbol ? "symbol=".$wpt->Symbol : ()),
		      )
		. "\n";
	}
    } elsif ($self->Type == TYPE_TRACK) {
	$s .= "!T:";
	if (defined $self->Name) {
	    $s .= "\t" . $self->Name;
	}
	$s .= "\n";
	foreach my $wpt (@{ $self->Track }) {
	    $s .= join("\t",
		       $wpt->Ident,
		       (defined $wpt->Comment ? $wpt->Comment : ""),
		       $wpt->Latitude, $wpt->Longitude,
		       (defined $wpt->Altitude ? $wpt->Altitude : ""))
		. "\n";
	}
    } else {
	die "NYI!";
    }
    $s;
}

# return always the points reference, regardless of Waypoints, Track, Route...
sub Points {
    my $self = shift;
    if ($self->Type eq TYPE_WAYPOINT) {
	$self->Waypoints;
    } elsif ($self->Type eq TYPE_TRACK) {
	$self->Track;
    } else {
	die;
    }
}

# REPO BEGIN
# REPO NAME monthabbrev_number /home/e/eserte/src/repository 
# REPO MD5 5dc25284d4ffb9a61c486e35e84f0662

=head2 monthabbrev_number($mon)

=for category Date

Return the number for the (English) abbreviated month name (e.g. "Sep"
=> 9).

=cut

sub monthabbrev_number {
    my $mon = shift;
    +{'Jan' => 1,
      'Feb' => 2,
      'Mar' => 3,
      'Apr' => 4,
      'May' => 5,
      'Jun' => 6,
      'Jul' => 7,
      'Aug' => 8,
      'Sep' => 9,
      'Oct' => 10,
      'Nov' => 11,
      'Dec' => 12,
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

1;

__END__
