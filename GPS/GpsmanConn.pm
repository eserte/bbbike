#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: GpsmanConn.pm,v 1.15 2007/05/24 22:43:26 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

# package to connect to a GPS receiver and up/download data in the
# gpsman format

package GPS::GpsmanConn;
use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.15 $ =~ /(\d+)\.(\d+)/);
use Config;

# XXX should go away some day...
BEGIN {
 SEARCH_FOR_BBBIKE_DIRS: {
	foreach my $dir (@INC) {
	    if (-r "$dir/Karte/Polar.pm") {
		last SEARCH_FOR_BBBIKE_DIRS;
	    }
	}
	if (!caller(2)) {
	    require FindBin;
	    eval 'use lib ("$FindBin::RealBin/..",
			   "$FindBin::RealBin/../lib",
			   "$FindBin::RealBin/../data",
			  )';
	}
	eval 'use lib qw(/home/e/eserte/src/bbbike
	                 /home/e/eserte/src/bbbike/lib
	                 /home/e/eserte/src/bbbike/data)';
	eval 'use lib qw(/usr/local/bbbike
                         /usr/local/bbbike/lib
                         /usr/local/bbbike/data)';
    }
 SEARCH_FOR_GARMIN: {
	# Debugging only:
	if (-e "/home/e/eserte/work/perl-GPS/blib") {
	    # Use the new perl-GPS repository. If upload/downloads fail,
	    # comment this line to get the old prod.perl-GPS
	    eval 'use blib "/home/e/eserte/work/perl-GPS"';
	    if ($@) {
		warn $@;
	    } else {
		last SEARCH_FOR_GARMIN;
	    }
	}
	foreach my $dir (@INC) {
	    if (-r "$dir/GPS/Garmin.pm") {
		last SEARCH_FOR_GARMIN;
	    }
	}
	if (-e "/tmp/prod.perl-GPS") {
	    eval 'use blib "/tmp/prod.perl-GPS"'; warn $@ if $@;
	} elsif (-e "/usr/local/prod.perl-GPS") {
	    eval 'use blib "/usr/local/prod.perl-GPS"'; warn $@ if $@;
	} else {
	    eval 'use blib "/home/e/eserte/work/prod.perl-GPS"';
	}
    }
    require Config;
#XXX    if ($Config::Config{archname} eq 'arm-linux') {
#	eval 'use GPS::GarminX'; die $@ if $@;
#    } else {
	eval 'use GPS::Garmin'; die $@ if $@; # 0.12 plus
#    }
}
use GPS::Garmin::Handler;

use constant MIN_TIME => 633826800; # 1990-01-01, see also GPS::Garmin::Constant::GRMN_UTC_DIFF

use vars qw(%garminsymbol_to_id %id_to_garminsymbol $default_garminsymbol
	    %id_to_garmindisplay);

$default_garminsymbol = 'WP_dot';

# List taken from gpsman's garmin_symbols.tcl
%garminsymbol_to_id = qw(
	anchor             0
	bell               1
	diamond_green      2
	diamond_red        3
	diver_down_1       4
	diver_down_2       5
	dollar             6
	fish               7
	fuel               8
	horn               9
	house             10
	knife_fork        11
	light             12
	mug               13
	skull             14
	square_green      15
	square_red        16
	WP_buoy_white     17
	WP_dot            18
	wreck             19
	null              20
	MOB               21
	buoy_amber        22
	buoy_black        23
	buoy_blue         24
	buoy_green        25
	buoy_green_red    26
	buoy_green_white  27
	buoy_orange       28
	buoy_red          29
	buoy_red_green    30
	buoy_red_white    31
	buoy_violet       32
	buoy_white        33
	buoy_white_green  34
	buoy_white_red    35
	dot               36
	radio_beacon      37
	boat_ramp        150
	camping          151
	restrooms        152
	showers          153
	drinking_water   154
	phone            155
	1st_aid          156
	info             157
	parking          158
	park             159
	picnic           160
	scenic           161
	skiing           162
	swimming         163
	dam              164
	controlled       165
	danger           166
	restricted       167
	null_2           168
	ball             169
	car              170
	deer             171
	shopping_cart    172
	lodging          173
	mine             174
	trail_head       175
	truck_stop       176
	exit             177
	flag             178
	circle_x         179
	is_highway      8192
	us_highway      8193
	st_highway      8194
	mile_marker     8195
	traceback       8196
	golf            8197
	small_city      8198
	medium_city     8199
	large_city      8200
	freeway         8201
	ntl_highway     8202
	capitol_city    8203
	amusement_park  8204
	bowling         8205
	car_rental      8206
	car_repair      8207
	fastfood        8208
	fitness         8209
	movie           8210
	museum          8211
	pharmacy        8212
	pizza           8213
	post_office     8214
	RV_park         8215
	school          8216
	stadium         8217
	store           8218
	zoo             8219
	fuel_store      8220
	theater         8221
	ramp_int        8222
	street_int      8223
	weight_station  8226
	toll            8227
	elevation       8228
	exit_no_serv    8229
	geo_name_man    8230
	geo_name_water  8231
	geo_name_land   8232
	bridge          8233
	building        8234
	cemetery        8235
	church          8236
	civil           8237
	crossing        8238
	monument        8239
	levee           8240
	military        8241
	oil_field       8242
	tunnel          8243
	beach           8244
	tree            8245
	summit          8246
	large_ramp_int  8247
	large_exit_ns   8248
	police          8249
	casino          8250
	snow_skiing     8251
	ice_skating     8252
	tow_truck       8253
	border          8254
	geocache        8255
	geocache_fnd    8256
	airport         16384
	intersection    16385
	avn_ndb         16386
	avn_vor         16387
	heliport        16388
	private         16389
	soft_field      16390
	tall_tower      16391
	short_tower     16392
	glider          16393
	ultralight      16394
	parachute       16395
	avn_vortac      16396
	avn_vordme      16397
	avn_faf         16398
	avn_lom         16399
	avn_map         16400
	avn_tacan       16401
	seaplane        16402
);

%id_to_garmindisplay = qw(0 s_name
			  1 symbol
			  2 s_comment);

use Karte::Polar;

{
    package GPS::Test;
    sub new { bless {}, shift }
    sub prepare_transfer {
	my($w, $type) = @_;
	$w->{Type} = $type;
	$w->{Records} = 50;
	$w->{_First} = 1;
	$w->{WaypointIndex} = 0;
	$w->{Desc} = "";
	@{$w}{qw(Lat Lon Time Alt Depth IsFirst)}
	    = (52.663844, 13.548460, time, 30, 0, 0);
    }
    sub get_reply { }
    sub records { shift->{Records} }
    sub grab {
	my $w = shift;
	# XXX check type
	$w->{Records}--;
	$w->{Lat} += rand(0.0001)-0.00002;
	$w->{Lon} += rand(0.0001)-0.00002;
	if ($w->{Type} eq 'trk') {
	    $w->{Time} = int($w->{Time} + rand(60));
	    $w->{Alt} += rand(2)-1;
	    if ($w->{_First}) {
		$w->{IsFirst} = 1;
		$w->{_First} = 0;
	    } else {
		$w->{IsFirst} = (rand(100) <= 2 ? 1 : 0);
	    }
	    @{$w}{qw(Lat Lon Time Alt Depth IsFirst)};
	} elsif ($w->{Type} eq 'wpt') {
	    $w->{WaypointIndex}++;
	    @{$w}{qw(WaypointIndex Lat Lon Desc)};
	} else {
	    die "Unknown type $w->{Type}";
	}
    }
}

sub new {
    my($class, %args) = @_;
    my $self = {};
    $self->{GPS} = $args{GPS};
    if (!$self->{GPS}) {
	#XXX require GPS::Garmin;
	GPS::Garmin->VERSION(0.14); # extended return
	# XXX Windows? HKEY_LOCAL_MACHINE\HARDWARE\DEVICEMAP\SERIALCOMM
	# XXX Linux: /dev/ttyS0 or ttyS1
	my $port = $args{Port} || ($Config::Config{archname} eq 'arm-linux'   ? '/dev/ttySA0' :
				   $Config::Config{archname} =~ /^i.86-linux/ ? '/dev/ttyS0'  :
				   $^O eq 'MSWin32' ? 'COM1:' :
				   '/dev/cuaa0'); # more distinctions
	my $baud = $args{Baud} || 9600;
	$self->{GPS} = new GPS::Garmin('Port' => $port,
				       'Baud' => $baud,
				       verbose => $args{Verbose} > 1,
				       Return => 'hash',
				      );
	die "Can't create GPS object" if !$self->{GPS};
    }
    $self->{Verbose} = $args{Verbose};
    bless $self, $class;
}

# XXX Shouldn't be necessary, but it seems it is...
sub DESTROY {
    my($self) = @_;
    warn "Calling Destructor of $self";
    if ($self->{GPS}) {
	if ($self->{GPS}->{serial}) {
	    warn "close serial";
	    $self->{GPS}->{serial}->close;
	}
    }
}

sub _time_to_gpsman {
    my $time = shift;
    $time = MIN_TIME if $time < MIN_TIME;
    my @l = localtime $time;
    sprintf "%02d-%s-%04d %02d:%02d:%02d",
	$l[3],
	[qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)]->[$l[4]],
	$l[5]+1900,
	@l[2,1,0];
}

sub _ddd_to_dms {
    my($ddd, $is_lat) = @_;
    my($d,$m,$s) = Karte::Polar::ddd2dms($ddd);
    if ($s >= 59.95) {
	$s = 0;
	$m++;
	if ($m >= 60) {
	    $m = 0;
	    if ($d > 0) {
		$d++;
	    } else {
		$d--;
	    }
	}
    }
    my $prefix;
    if ($is_lat) {
	if ($d > 0) {
	    $prefix = 'N';
	} else {
	    $prefix = 'S';
	    $d = -$d;
	}
    } else {
	if ($d > 0) {
	    $prefix = 'E';
	} else {
	    $prefix = 'W';
	    $d = -$d;
	}
    }
    sprintf "%s%02d %02d %04.1f",
	$prefix,
	$d, $m, $s;
}

sub header {
    my $self = shift;
    <<EOF;
% Written by @{[ __PACKAGE__  ]}/$VERSION @{[scalar localtime]}

!Format: DMS 1 WGS 84

EOF
}

sub get_tracks {
    my($self) = @_;
    my $gps = $self->{GPS};
    $gps->prepare_transfer("trk");
    my @r;
    my $r = "";

    my $write_header = sub {
	$r .= $self->header . <<EOF;
!T:	ACTIVE LOG
EOF
    };

    $write_header->();

    my $numr = $gps->records;
    warn "records to read: $numr\n" if $self->{Verbose};
    $gps->get_reply; # overread header --- XXX valuable info here! (name etc?)
    my $r_i = 0;
    while ($gps->records) {
	my(%res) = $gps->grab;
	#XXX use Hash::Util qw(lock_keys); lock_keys %res; # XXX
	my($lat,$lon,$time,$alt,$depth,$isfirst) = @res{qw{lat lon time alt depth new_trk}};
	if (0 && $isfirst) { # XXX ignore isfirst
	    if ($r ne "") {
		push @r, $r;
		$r = "";
	    }
	    $write_header->();
	}
	#XXX ? $r .= "!TS:\n" if $isfirst;
	$r .= join("\t",
		   "",
		   _time_to_gpsman($time),
		   _ddd_to_dms($lat, 1),
		   _ddd_to_dms($lon, 0),
		   $alt
		  ) . "\n";
	$r_i++;
	printf STDERR "Records read: %d%% (%d/%d)    \r", $r_i/$numr*100, $r_i, $numr
	    if $self->{Verbose};
    }
    printf STDERR "\n" if $self->{Verbose};
    push @r, $r;
    @r;
}

sub write_tracks {
    my($self, $tracks_ref, $directory, %opt) = @_;
    if (!-d $directory || !-w $directory) {
	die "Non-existing or non-writable directory $directory";
    }
    foreach my $track (@$tracks_ref) {
	# hack: search for first date
	my $date;
	my($Y,$M,$D,$h,$m,$s);
	foreach my $l (split /\n/, $track) {
	    if ($l =~ /^\t(\d{2})-([^-]+)-(\d{4})\s+(\d{2}):(\d{2}):(\d{2})/) {
		($D,$M,$Y,$h,$m,$s) = ($1,sprintf("%02d", monthabbrev_number($2)),$3,$4,$5,$6);
		last;
	    }
	}
	if (!defined $Y || !defined $M) {
	    die "Can't parse track for date";
	}
	my $out;
	if (!$opt{-filefmt}) {
	    $out = "$directory/$Y-$M-$D"."_$h:$m:$s.trk";
	} else {
	    my %d = (Y=>$Y,M=>$M,D=>$D,h=>$h,m=>$m,s=>$s);
	    my $replace = sub {
		my $out;
		($out = $opt{-filefmt}) =~ s/%([YMDhmsc])/$d{$1}/g;
		$out;
	    };
	    my $c = ""; # extra character
	    while (1) {
		$d{c} = $c;
		$out = $replace->();
		$out = "$directory/$out";
		if (-e $out) {
		    if ($opt{-filefmt} =~ /%c/) {
			if ($c eq '') {
			    $c = "b";
			} elsif ($c eq 'z') {
			    warn "Won't overwrite $out with -filefmt option, write to $out~";
			    $out = "$out~";
			    last;
			} else {
			    $c = chr(ord($c)+1);
			}
		    } else {
			warn "Won't overwrite $out with -filefmt option, write to $out~";
			$out = "$out~";
			last;
		    }
		} else {
		    last;
		}
	    }
	}
	open(F, ">$out") or die "Can't write to $out: $!";
	print F $track;
	close F;
    }
}

sub get_waypoints {
    my($self) = @_;
    my $gps = $self->{GPS};
    my $r = $self->header . <<EOF;
!W:
EOF
    $gps->prepare_transfer("wpt");
    my $numr = $gps->records;
    warn "records to read: $numr\n" if $self->{Verbose};
    my $r_i = 0;
    while ($gps->records) {
	my(%res) = $gps->grab;
	#XXX use Hash::Util qw(lock_keys); lock_keys %res; # XXX
	#require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([\%res],[])->Indent(1)->Useqq(1)->Dump; # XXX
	my($title,$lat,$lon,$desc) = @res{qw{ident lat lon comment}};

	my @extra;
	if (defined $res{alt}) {
	    push @extra, "alt=$res{alt}";
	}
	if (defined $res{dspl}) {
	    my $displayname = $id_to_garmindisplay{$res{dspl}};
	    if (defined $displayname) {
		push @extra, "dispopt=$displayname";
	    }
	}
	if (defined $res{smbl}) {
	    my $symbolname = id_to_garminsymbol($res{smbl});
	    if (defined $symbolname) {
		if ($symbolname ne $default_garminsymbol) {
		    push @extra, "symbol=$symbolname";
		}
	    } else {
		push @extra, "symbol=$res{smbl}"; # use id instead
	    }
	}

	$r .= join("\t",
		   ($title||""),
		   ($desc||""),
		   _ddd_to_dms($lat, 1),
		   _ddd_to_dms($lon, 0),
		   @extra,
		   ) . "\n";
	$r_i++;
	printf STDERR "Records read: %d%% (%d/%d)    \r", $r_i/$numr*100, $r_i, $numr
	    if $self->{Verbose};
    }
    printf STDERR "\n" if $self->{Verbose};
    $r;
}

sub write_waypoints {
    my($self, $w, $file) = @_;
    open(F, ">$file") or die "Can't write to $file: $!";
    print F $w;
    close F;
}

sub put_route_from_bbd {
    my($self, $bbd_file, %args) = @_;
    my $gps = $self->{GPS};
    my $number = $args{-number};
    if (!defined $number) { $number = 1 }
    my $comment = $args{-comment};
    if (!defined $comment) { $comment = "Route $number" }
    require Strassen;
    require Karte;
    require Karte::Standard;
    my @d;
    my $handler = $gps->can("handler") ? $gps->handler : $gps;
    push @d,
	[$gps->GRMN_RTE_HDR, $handler->pack_Rte_hdr({nmbr => $number, cmnt => $comment})];
    my $s = new Strassen $bbd_file or die "Can't open $bbd_file: $!";
    $s->init;
    my $r = $s->next;
    my $first = 1;
    my $i=0;
    foreach my $p (@{ $r->[Strassen::COORDS()] }) {
	my($lon,$lat) = split /,/, $p;
	($lon,$lat) = $Karte::map{'polar'}->standard2map($lon,$lat);
	unless ($first) {
	    push @d, [$gps->GRMN_RTE_LINK_DATA, $handler->pack_Rte_link_data];
	}
	push @d, [$gps->GRMN_RTE_WPT_DATA, $handler->pack_Rte_wpt_data({lat => $lat, lon => $lon, ident => "I".(++$i)})];
	$first = 0;
    }
    if ($gps->can("upload_data2")) {
	$gps->upload_data2(\@d);
    } else {
	$gps->upload_data(\@d);
    }
}

# REPO BEGIN
# REPO NAME monthabbrev_number /home/e/eserte/src/repository 
# REPO MD5 5dc25284d4ffb9a61c486e35e84f0662
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

BEGIN {
    if ($GPS::Garmin::Handler::VERSION < 0.13) {
	eval q{
# XXX should be moved to prod code, but is already in "new" code...
package GPS::Garmin::Handler;

sub Trk_data {
    my $self = shift;
	$self->{records}--;
	my ($data) = $self->read_packet;
	my (@ident,@comm,$lt,$ln);

	# D300 Track Point Datatype
#	my ($lat,$lon,$time,$is_first) = unpack('llLb',$data);	
	# D301 Track Point Datatype
	my ($lat,$lon,$time,$alt,$dpth,$is_first) = unpack('llLffb',$data);	
    $lat = $self->semicirc_deg($lat);
    $lon = $self->semicirc_deg($lon);
#warn "$lat $lon $alt $dpth $time @{[ scalar localtime $time ]}\n";
	if ($time == 0xffffffff) { # XXX check
		undef $time;
	} else {
		$time += GPS::Garmin::Constant::GRMN_UTC_DIFF();
	}
#warn "$time @{[ scalar localtime $time ]}\n";

#XXX	$res = new GPS::Garmin::D301_Trk_data_Type;

	$self->send_packet(GPS::Garmin::Constant::GRMN_ACK());
	if($self->{records} == 0) { $self->get_reply; }
	return($lat,$lon,$time,$alt,$dpth,$is_first);
}

sub pack_Trk_hdr {
	my $self = shift;
	my $d = shift || {};
	my %d = %$d;
	$d{dspl} = 0 unless defined $d{dspl};
	$d{color} = 255 unless defined $d{color};
	if (!defined $d{ident}) {
		die "ident is required";
	}
	# D310
	my $s = pack("cC", $d{dspl}, $d{color});
	$s .= $d{ident}."\0";
	$s;
}

sub pack_Trk_data {
	my $self = shift;
	my $d = shift || {};
	my %d = %$d;
	if (!exists $d{lat} || !exists $d{lon}) {
		die "lat and lon required!";
	}
	$d{lat} = $self->deg_semicirc($d{lat});
	$d{lon} = $self->deg_semicirc($d{lon});
	$d{'time'} = 0 unless defined $d{'time'}; # XXX can't upload anyway
	$d{'alt'} = 0 unless defined $d{'alt'}; # XXX set to undef?
	$d{'dpth'} = 0 unless defined $d{'dpth'}; # XXX set to undef?
	$d{'is_first'} = 0 unless defined $d{'is_first'};
	# D301
	my $s = pack("llLffb", $d{lat}, $d{lon}, $d{'time'}, $d{'alt'},
				 $d{'dpth'}, $d{'is_first'});
	$s;
}

};
        die $@ if $@;
    }
}

return 1 if caller;

# XXX command line

my %opt;
require Getopt::Long;
if (!Getopt::Long::GetOptions(\%opt,
			      "v+",
			      "test!", "dir|directory=s", "file=s",
			      "filefmt=s")) {
    usage();
}
my $action = shift or usage();

my $gpsconn;
if ($opt{test}) {
    $gpsconn = GPS::GpsmanConn->new(Verbose => $opt{'v'},
				    GPS => GPS::Test->new);
} else {
    $gpsconn = GPS::GpsmanConn->new(Verbose => $opt{'v'},
				   );
}

if ($action eq 'gettrk') {
    if (defined $opt{file}) {
	die "-file option is meaningless with gettrk, use -dir instead";
    }
    my @t = $gpsconn->get_tracks;
    if (@t && $opt{dir}) {
	$gpsconn->write_tracks(\@t, $opt{dir}, -filefmt => $opt{filefmt});
    } else {
	print join("\n", @t);
    }
} elsif ($action eq 'getwpt') {
    if (defined $opt{dir}) {
	die "-dir option is meaningless with getwpt, use -file instead";
    }
    my $w = $gpsconn->get_waypoints;
    if ($opt{file}) {
	$gpsconn->write_waypoints($w, $opt{file});
    } else {
	print $w;
    }
} else {
    warn "Unknown action $action";
    usage();
}

sub usage {
    die <<EOF
usage: $0 [-test] [-file file] [-filefmt fmt] [-dir directory] action

where action is one of:
gettrk getwpt

EOF
}

sub id_to_garminsymbol {
    my($id) = @_;
    if (!keys %id_to_garminsymbol) {
	while(my($symbol,$id) = each %garminsymbol_to_id) {
	    $id_to_garminsymbol{$id} = $symbol;
	}
    }
    $id_to_garminsymbol{$id};
}

__END__
